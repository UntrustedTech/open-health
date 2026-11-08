import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/sync/background_scheduler.dart';
import 'package:health_app/sync/health_sample.dart';
import 'package:health_app/sync/health_sync_service.dart';

import 'fake_health_source.dart';

/// Records what the sync service asks of the background scheduler.
class FakeScheduler implements BackgroundScheduler {
  Duration? scheduled;
  int cancels = 0;

  /// Whether the last schedule replaced an existing one's timing.
  bool? replaced;

  @override
  Future<void> schedule(Duration every, {bool replace = true}) async {
    scheduled = every;
    replaced = replace;
  }

  @override
  Future<void> cancel() async {
    scheduled = null;
    cancels++;
  }
}

void main() {
  var now = DateTime(2026, 10, 11, 15, 30);
  late InMemoryHealthRepository repo;
  late HealthStore store;
  late FakeHealthSource source;
  late FakeScheduler scheduler;
  late HealthSyncService sync;

  HealthSyncService newService() => HealthSyncService(
    source: source,
    store: store,
    repo: repo,
    scheduler: scheduler,
    clock: () => now,
  );

  HealthSample steps(double value, DateTime at) =>
      HealthSample(type: MetricType.steps, value: value, start: at, end: at);

  setUp(() async {
    now = DateTime(2026, 10, 11, 15, 30);
    repo = InMemoryHealthRepository();
    store = HealthStore(repo, clock: () => now);
    await store.load();
    source = FakeHealthSource();
    scheduler = FakeScheduler();
    sync = newService();
    await sync.init();
    await sync.connect();
    await sync.sync();
  });

  Future<HealthSyncService> reloaded() async {
    final s = newService();
    await s.init();
    return s;
  }

  group('syncing when the app opens', () {
    test('is on by default and syncs on opening', () async {
      source.reads.clear();
      now = now.add(const Duration(minutes: 5));

      await sync.autoSync(SyncTrigger.resume);

      expect(sync.syncOnOpen, isTrue);
      expect(source.reads, isNotEmpty);
    });

    test('when off, opening the app doesn\'t sync but Sync Now does', () async {
      await sync.setSyncOnOpen(false);
      source.reads.clear();
      now = now.add(const Duration(minutes: 5));

      await sync.autoSync(SyncTrigger.launch);
      expect(source.reads, isEmpty);

      await sync.sync(force: true);
      expect(source.reads, isNotEmpty);
      expect((await reloaded()).syncOnOpen, isFalse);
    });
  });

  group('recent access', () {
    test(
      'logs each sync, newest first, with its trigger and readings',
      () async {
        source.samples
          ..add(steps(300, DateTime(2026, 10, 11, 9)))
          ..add(steps(200, DateTime(2026, 10, 10, 9)));
        now = now.add(const Duration(minutes: 5));

        await sync.autoSync(SyncTrigger.resume);

        final last = sync.recentAccess.first;
        expect(last.trigger, SyncTrigger.resume);
        expect(last.at, now);
        expect(last.ok, isTrue);
        expect(last.readings, 2);
        expect(sync.recentAccess[1].trigger, SyncTrigger.connect);
      },
    );

    test('logs a failed read with its error', () async {
      source.failing.add(MetricType.steps);

      await sync.sync(force: true);

      expect(sync.recentAccess.first.ok, isFalse);
      expect(sync.recentAccess.first.error, contains('Steps'));
    });

    test('keeps the latest 30 and survives a restart', () async {
      for (var i = 0; i < 35; i++) {
        now = now.add(const Duration(minutes: 2));
        await sync.sync(force: true);
      }

      expect(sync.recentAccess, hasLength(HealthSyncService.recentLimit));
      final again = await reloaded();
      expect(again.recentAccess, hasLength(HealthSyncService.recentLimit));
      expect(again.recentAccess.first.at, now);
    });
  });

  group('background sync', () {
    test('connecting turns it on, every 15 minutes', () {
      expect(sync.backgroundSync, isTrue);
      expect(scheduler.scheduled, const Duration(minutes: 15));
    });

    test('turning it on asks Health Connect and schedules checks', () async {
      final ok = await sync.setBackgroundSync(true);

      expect(ok, isTrue);
      expect(source.backgroundRequested, isTrue);
      expect(sync.backgroundSync, isTrue);
      expect(scheduler.scheduled, HealthSyncService.defaultInterval);
    });

    test('stays off when Health Connect doesn\'t allow it', () async {
      await sync.setBackgroundSync(false);
      source.backgroundAllowed = false;

      final ok = await sync.setBackgroundSync(true);

      expect(ok, isFalse);
      expect(sync.backgroundSync, isFalse);
      expect(sync.settingsError, isNotNull);
      expect(scheduler.scheduled, isNull);
    });

    test('changing the interval reschedules; turning off cancels', () async {
      await sync.setBackgroundSync(true);

      await sync.setBackgroundInterval(const Duration(hours: 6));
      expect(scheduler.scheduled, const Duration(hours: 6));

      await sync.setBackgroundSync(false);
      expect(scheduler.scheduled, isNull);
    });

    test('the setting survives a restart and is scheduled again', () async {
      await sync.setBackgroundSync(true);
      await sync.setBackgroundInterval(const Duration(minutes: 30));
      scheduler.scheduled = null;

      final again = await reloaded();

      expect(again.backgroundSync, isTrue);
      expect(again.backgroundInterval, const Duration(minutes: 30));
      expect(scheduler.scheduled, const Duration(minutes: 30));
    });

    test('disconnecting stops background checks', () async {
      await sync.setBackgroundSync(true);

      await sync.disconnect();

      expect(scheduler.scheduled, isNull);
      expect(sync.backgroundSync, isFalse);
    });

    test('a background run is logged as one', () async {
      now = now.add(const Duration(minutes: 30));

      await sync.sync(force: true, trigger: SyncTrigger.background);

      expect(sync.recentAccess.first.trigger, SyncTrigger.background);
    });
  });

  group('review fixes', () {
    test('only new or changed readings count as new', () async {
      source.samples.add(steps(300, DateTime(2026, 10, 11, 9)));
      now = now.add(const Duration(minutes: 2));
      await sync.sync(force: true);
      expect(sync.recentAccess.first.readings, 1);

      now = now.add(const Duration(minutes: 2));
      await sync.sync(force: true);
      expect(sync.recentAccess.first.readings, 0);
    });

    test(
      'opening the app keeps the background timer; changes replace it',
      () async {
        await sync.setBackgroundSync(true);
        expect(scheduler.replaced, isTrue);

        await reloaded();
        expect(scheduler.replaced, isFalse);
      },
    );

    test('a revoked background permission turns background sync off', () async {
      await sync.setBackgroundSync(true);
      source.backgroundAllowed = false;

      await sync.refreshPermissions();

      expect(sync.backgroundSync, isFalse);
      expect(scheduler.scheduled, isNull);
      expect(sync.settingsError, isNotNull);
    });

    test('settings problems don\'t clear or replace a sync error', () async {
      source.failing.add(MetricType.steps);
      await sync.sync(force: true);
      final syncError = sync.error;
      source.backgroundAllowed = false;

      await sync.setBackgroundSync(true);

      expect(sync.error, syncError);
      expect(sync.settingsError, isNotNull);
    });

    test('a device without background reads says so', () async {
      source.backgroundAvailable = false;

      await sync.setBackgroundSync(true);

      expect(sync.settingsError, contains("doesn't support"));
    });

    test('a guarded sync that can no longer save writes nothing', () async {
      source.samples.add(steps(700, DateTime(2026, 10, 11, 9)));
      now = now.add(const Duration(minutes: 2));
      final records = sync.recentAccess.length;

      await sync.sync(
        force: true,
        trigger: SyncTrigger.background,
        canSave: () async => false,
      );

      expect(store.todayValue(MetricType.steps), 0);
      expect(sync.recentAccess, hasLength(records));
    });

    test('background checks don\'t start a full history import', () async {
      source.grant = {MetricType.steps, MetricType.weight, MetricType.water};
      await sync.changePermissions();
      await sync.sync(force: true);
      source.grant = {...source.grant, MetricType.heartRate};
      // Granted outside the app; picked up by the next check.
      await sync.refreshPermissions();
      source.reads.clear();
      now = now.add(const Duration(minutes: 30));

      await sync.sync(force: true, trigger: SyncTrigger.background);

      expect(source.reads.where((r) => r.$1 == MetricType.heartRate), isEmpty);
    });

    test('disconnecting clears the recent access log', () async {
      await sync.disconnect();

      expect(sync.recentAccess, isEmpty);
    });

    test('reload picks up what a background check saved', () async {
      final background = newService();
      await background.init(schedule: false);
      source.samples.add(steps(900, DateTime(2026, 10, 11, 9)));
      now = now.add(const Duration(minutes: 2));
      await background.sync(force: true, trigger: SyncTrigger.background);

      await sync.reload();

      expect(sync.recentAccess.first.trigger, SyncTrigger.background);
    });
  });
}
