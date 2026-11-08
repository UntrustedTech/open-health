import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/sync/health_sample.dart';
import 'package:health_app/sync/health_sync_service.dart';

import 'fake_health_source.dart';

HealthSample _hr(double bpm, DateTime at) =>
    HealthSample(type: MetricType.heartRate, value: bpm, start: at, end: at);

void main() {
  var now = DateTime(2026, 10, 19, 15, 30);
  late InMemoryHealthRepository repo;
  late HealthStore store;
  late FakeHealthSource source;
  late HealthSyncService sync;

  HealthSyncService newService() => HealthSyncService(
    source: source,
    store: store,
    repo: repo,
    clock: () => now,
  );

  setUp(() async {
    now = DateTime(2026, 10, 19, 15, 30);
    repo = InMemoryHealthRepository();
    store = HealthStore(repo, clock: () => now);
    await store.load();
    source = FakeHealthSource(grant: {MetricType.heartRate});
    sync = newService();
    await sync.init();
    await sync.connect();
    // Connecting starts the first sync; let it finish.
    await sync.sync();
  });

  group('the latest heart rate', () {
    test('is the newest reading, not the day\'s average', () async {
      source.samples.addAll([
        _hr(60, DateTime(2026, 10, 19, 8)),
        _hr(70, DateTime(2026, 10, 19, 9)),
        _hr(95, DateTime(2026, 10, 19, 15, 10)),
      ]);

      await sync.sync(force: true);

      expect(store.latestReading(MetricType.heartRate)?.value, 95);
      // Charts still use the day's average.
      expect(
        store.dailyValue(MetricType.heartRate, DateTime(2026, 10, 19)),
        75,
      );
    });

    test('updates with each sync', () async {
      source.samples.add(_hr(64, DateTime(2026, 10, 19, 15)));
      await sync.sync(force: true);
      expect(store.latestReading(MetricType.heartRate)?.value, 64);

      now = now.add(const Duration(minutes: 10));
      source.samples.add(_hr(88, DateTime(2026, 10, 19, 15, 38)));
      await sync.sync(force: true);

      expect(store.latestReading(MetricType.heartRate)?.value, 88);
    });

    test('an older reading never replaces a newer one', () async {
      source.samples.add(_hr(88, DateTime(2026, 10, 19, 15)));
      await sync.sync(force: true);

      await store.setLiveReadings({
        MetricType.heartRate: (at: DateTime(2026, 10, 19, 9), value: 61),
      });

      expect(store.latestReading(MetricType.heartRate)?.value, 88);
    });

    test('is kept after the app restarts', () async {
      source.samples.add(_hr(91, DateTime(2026, 10, 19, 15)));
      await sync.sync(force: true);

      final again = HealthStore(repo, clock: () => now);
      await again.load();

      expect(again.latestReading(MetricType.heartRate)?.value, 91);
    });

    test('yesterday\'s reading doesn\'t stand in for today', () async {
      source.samples.add(_hr(77, DateTime(2026, 10, 18, 22)));
      await sync.sync(force: true);

      final r = store.latestReading(MetricType.heartRate);
      expect(r?.day, DateTime(2026, 10, 18));
      expect(r?.value, 77);
    });

    test('is removed when heart rate is no longer shared', () async {
      source.samples.add(_hr(91, DateTime(2026, 10, 19, 15)));
      await sync.sync(force: true);

      source.grant = {};
      await sync.changePermissions();
      await sync.sync(force: true);

      expect(store.latestReading(MetricType.heartRate), isNull);
    });
  });

  group('while the app is open', () {
    test('it waits for the chosen interval between checks', () async {
      await sync.setOpenInterval(const Duration(minutes: 10));
      source.reads.clear();

      now = now.add(const Duration(minutes: 5));
      await sync.pollWhileOpen();
      expect(source.reads, isEmpty);

      now = now.add(const Duration(minutes: 5));
      await sync.pollWhileOpen();
      expect(source.reads, isNotEmpty);
    });

    test('every minute when set to 1 minute, even a little early', () async {
      await sync.setOpenInterval(const Duration(minutes: 1));
      source.reads.clear();

      // Timers fire a little early or late.
      now = now.add(const Duration(seconds: 58));
      await sync.pollWhileOpen();

      expect(source.reads, isNotEmpty);
    });

    test('the interval is kept', () async {
      await sync.setOpenInterval(const Duration(minutes: 2));

      final again = newService();
      await again.init();

      expect(again.openInterval, const Duration(minutes: 2));
    });

    test('defaults to 5 minutes', () {
      expect(sync.openInterval, HealthSyncService.whileOpen);
    });

    test('it checks for new data every few minutes', () async {
      source.reads.clear();
      now = now.add(HealthSyncService.whileOpen);

      await sync.pollWhileOpen();

      expect(source.reads, isNotEmpty);
      expect(sync.recentAccess.first.trigger, SyncTrigger.periodic);
    });

    test('not when syncing on open is off', () async {
      await sync.setSyncOnOpen(false);
      source.reads.clear();
      now = now.add(HealthSyncService.whileOpen);

      await sync.pollWhileOpen();

      expect(source.reads, isEmpty);
    });
  });
}
