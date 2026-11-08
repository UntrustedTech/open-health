import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/sync/health_sample.dart';
import 'package:health_app/sync/health_source.dart';
import 'package:health_app/sync/health_sync_service.dart';

import 'fake_health_source.dart';

void main() {
  var now = DateTime(2026, 10, 11, 15, 30);
  late InMemoryHealthRepository repo;
  late HealthStore store;
  late FakeHealthSource source;
  late HealthSyncService sync;

  HealthSample steps(double value, DateTime at) =>
      HealthSample(type: MetricType.steps, value: value, start: at, end: at);

  HealthSyncService newService() => HealthSyncService(
    source: source,
    store: store,
    repo: repo,
    clock: () => now,
  );

  setUp(() async {
    now = DateTime(2026, 10, 11, 15, 30);
    repo = InMemoryHealthRepository();
    store = HealthStore(repo, clock: () => now);
    await store.load();
    source = FakeHealthSource();
    sync = newService();
    await sync.init();
  });

  test('connect imports a year of history when allowed', () async {
    source.samples
      ..add(steps(4000, DateTime(2025, 11, 1, 9)))
      ..add(steps(500, DateTime(2026, 10, 11, 9)));

    final ok = await sync.connect();
    await sync.sync();

    expect(ok, isTrue);
    expect(sync.connected, isTrue);
    expect(sync.granted, {MetricType.steps, MetricType.weight});
    expect(store.dailyValue(MetricType.steps, DateTime(2025, 11, 1)), 4000);
    expect(store.todayValue(MetricType.steps), 500);
    expect(sync.lastSync, now);
  });

  group('Apple Health that never asked', () {
    setUp(() async {
      source.samples.add(steps(500, DateTime(2026, 10, 11, 9)));
      await sync.connect();
      await sync.sync();
      source.needsRequest = true;
    });

    test('sync says so rather than finding nothing', () async {
      source.reads.clear();

      await sync.sync(force: true);

      expect(source.reads, isEmpty);
      expect(sync.error, contains("hasn't been allowed yet"));
      expect(sync.recentAccess.first.ok, isFalse);
    });

    test('Manage Permissions asks instead of opening the Health app', () async {
      await sync.openPermissionSettings();

      expect(source.permissionSettingsOpened, 0);
      expect(source.needsRequest, isFalse);
      expect(await sync.needsAccessRequest(), isFalse);
    });

    test('once asked, Manage Permissions opens the Health app', () async {
      source.needsRequest = false;

      await sync.openPermissionSettings();

      expect(source.permissionSettingsOpened, 1);
    });
  });

  test('connect imports only 30 days without history access', () async {
    source.historyAllowed = false;
    source.samples
      ..add(steps(4000, DateTime(2026, 8, 1, 9)))
      ..add(steps(500, DateTime(2026, 10, 1, 9)));

    await sync.connect();
    await sync.sync();

    expect(store.dailyValue(MetricType.steps, DateTime(2026, 8, 1)), isNull);
    expect(store.dailyValue(MetricType.steps, DateTime(2026, 10, 1)), 500);
  });

  test('connect fails gracefully when nothing is allowed', () async {
    source.grant = {};

    final ok = await sync.connect();

    expect(ok, isFalse);
    expect(sync.connected, isFalse);
    expect(sync.error, isNotNull);
  });

  test('resync re-reads the last 7 days and picks up changes', () async {
    source.samples.add(steps(500, DateTime(2026, 10, 9, 9)));
    await sync.connect();
    await sync.sync();

    now = DateTime(2026, 10, 12, 9);
    source.samples
      ..clear()
      ..add(steps(800, DateTime(2026, 10, 9, 9)));
    source.reads.clear();
    await sync.sync(force: true);

    expect(store.dailyValue(MetricType.steps, DateTime(2026, 10, 9)), 800);
    final earliest = source.reads
        .map((r) => r.$2)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    expect(earliest.isBefore(DateTime(2026, 10, 5)), isTrue);
    expect(earliest.isAfter(DateTime(2026, 10, 1)), isTrue);
  });

  test('checks while open re-read only since the last sync and a day, '
      'keeping older days', () async {
    source.samples.add(steps(500, DateTime(2026, 10, 9, 9)));
    await sync.connect();
    await sync.sync();

    now = DateTime(2026, 10, 11, 15, 32);
    source.reads.clear();
    await sync.pollWhileOpen();

    final earliest = source.reads
        .map((r) => r.$2)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    expect(earliest, DateTime(2026, 10, 10));
    // Days before the short window keep what was imported.
    expect(store.dailyValue(MetricType.steps, DateTime(2026, 10, 9)), 500);
  });

  test('a record overlapping the read window leaves earlier days\' heart '
      'rate zones whole', () async {
    HealthSample hr(double bpm, DateTime at) => HealthSample(
      type: MetricType.heartRate,
      value: bpm,
      start: at,
      end: at,
    );
    source.grant = {MetricType.heartRate};
    for (var m = 0; m < 30; m++) {
      source.samples.add(hr(150, DateTime(2026, 10, 9, 9, m)));
    }
    await sync.connect();
    await sync.sync();
    final before = store.heartBinsOn(DateTime(2026, 10, 9))!;

    // The short check reads from Oct 10; a record started Oct 9 at 23:59.
    source.spill.add(hr(60, DateTime(2026, 10, 9, 23, 59)));
    now = DateTime(2026, 10, 11, 15, 32);
    await sync.pollWhileOpen();

    expect(store.heartBinsOn(DateTime(2026, 10, 9)), before);
  });

  test('connecting also turns on checks in the background', () async {
    await sync.connect();
    expect(source.backgroundRequested, isTrue);
    expect(sync.backgroundSync, isTrue);
  });

  test('automatic syncs are throttled, forced syncs are not', () async {
    await sync.connect();
    await sync.sync();
    source.reads.clear();

    now = now.add(const Duration(seconds: 30));
    await sync.sync();
    expect(source.reads, isEmpty);

    await sync.sync(force: true);
    expect(source.reads, isNotEmpty);
  });

  test('heart rate added in Health Connect shows after returning to the '
      'app a couple of minutes later', () async {
    source.grant = {MetricType.heartRate};
    await sync.connect();
    await sync.sync();
    expect(store.todayValue(MetricType.heartRate), 0);

    // Added in Health Connect, then back to the app.
    source.samples.add(
      HealthSample(
        type: MetricType.heartRate,
        value: 92,
        start: now.add(const Duration(minutes: 1)),
        end: now.add(const Duration(minutes: 1)),
      ),
    );
    now = now.add(const Duration(minutes: 2));
    await sync.sync();

    expect(store.todayValue(MetricType.heartRate), 92);
  });

  test('overlapping sync calls share one run', () async {
    await sync.connect();
    await sync.sync();
    source.reads.clear();

    await Future.wait([sync.sync(force: true), sync.sync(force: true)]);

    final stepReads = source.reads.where((r) => r.$1 == MetricType.steps);
    expect(stepReads.length, 1);
  });

  test('a failing type keeps its old data and reports an error', () async {
    source.samples.add(steps(500, DateTime(2026, 10, 10, 9)));
    await sync.connect();
    await sync.sync();

    source.failing.add(MetricType.steps);
    await sync.sync(force: true);

    expect(store.dailyValue(MetricType.steps, DateTime(2026, 10, 10)), 500);
    expect(sync.error, isNotNull);
  });

  test('disconnect removes imported data and revokes access', () async {
    source.samples.add(steps(500, DateTime(2026, 10, 10, 9)));
    await sync.connect();
    await sync.sync();

    await sync.disconnect();

    expect(store.hasImportedData, isFalse);
    expect(sync.connected, isFalse);
    expect(source.revoked, isTrue);
  });

  test('connection state survives a restart', () async {
    await sync.connect();
    await sync.sync();

    final restarted = newService();
    await restarted.init();

    expect(restarted.connected, isTrue);
    expect(restarted.lastSync, now);
  });

  test('reports when Health Connect must be installed', () async {
    source.currentStatus = SourceStatus.needsInstall;

    await sync.init();

    expect(sync.status, SourceStatus.needsInstall);
  });

  test('disconnecting while a sync starts leaves no imported data', () async {
    source.samples.add(steps(500, DateTime(2026, 10, 10, 9)));
    await sync.connect();
    await sync.sync();

    final pending = sync.sync(force: true);
    final disconnecting = sync.disconnect();
    await Future.wait([pending, disconnecting]);
    await sync.sync(force: true);

    expect(store.hasImportedData, isFalse);
    expect(sync.connected, isFalse);
    final restarted = newService();
    await restarted.init();
    expect(restarted.connected, isFalse);
  });

  test('a newly allowed type imports its full history', () async {
    source.samples.add(
      HealthSample(
        type: MetricType.sleep,
        value: 8,
        start: DateTime(2026, 6, 1, 23),
        end: DateTime(2026, 6, 2, 7),
      ),
    );
    await sync.connect();
    await sync.sync();
    expect(store.entriesFor(MetricType.sleep), isEmpty);

    now = DateTime(2026, 10, 12, 9);
    source.grant = {...source.grant, MetricType.sleep};
    await sync.changePermissions();
    await sync.sync();

    expect(store.dailyValue(MetricType.sleep, DateTime(2026, 6, 2)), 8);
  });

  test('data for a type no longer allowed is removed', () async {
    source.samples.add(steps(500, DateTime(2026, 10, 10, 9)));
    await sync.connect();
    await sync.sync();

    source.grant = {MetricType.weight};
    await sync.changePermissions();
    await sync.sync();

    expect(store.entriesFor(MetricType.steps), isEmpty);
  });

  test('a failed permission check never removes imported data', () async {
    source.samples.add(steps(500, DateTime(2026, 10, 10, 9)));
    await sync.connect();
    await sync.sync();
    expect(store.entriesFor(MetricType.steps), isNotEmpty);

    // A fresh start (nothing known yet) where the check also fails.
    final again = newService();
    source.permissionCheckFails = true;
    await again.init();
    await again.sync(force: true);

    expect(store.entriesFor(MetricType.steps), isNotEmpty);
  });

  test('connect returns before the import finishes', () async {
    source.samples.add(steps(500, DateTime(2026, 10, 10, 9)));

    final ok = await sync.connect();

    expect(ok, isTrue);
    expect(sync.syncing, isTrue);
    await sync.sync();
    expect(store.hasImportedData, isTrue);
  });

  test('workouts from other apps appear in workout history', () async {
    final workouts = WorkoutStore(repo, store, clock: () => now);
    await workouts.load();
    source.grant = {MetricType.exerciseMinutes};
    source.workouts.add(
      WorkoutSession(
        id: 'hc-1',
        type: WorkoutType.cycle,
        start: DateTime(2026, 10, 10, 18),
        end: DateTime(2026, 10, 10, 19),
        activeSeconds: 3600,
        distanceMeters: 25000,
        source: WorkoutSource.healthConnect,
      ),
    );
    final s = HealthSyncService(
      source: source,
      store: store,
      repo: repo,
      workouts: workouts,
      clock: () => now,
    );
    await s.init();

    await s.connect();
    await s.sync();
    expect(workouts.all.single.type, WorkoutType.cycle);
    // Imported workouts add no linked entries (their minutes come from HC).
    expect(store.hasImportedData, isFalse);

    await s.disconnect();
    expect(workouts.all, isEmpty);
  });
}
