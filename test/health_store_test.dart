import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/models/health_entry.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/state/health_store.dart';

void main() {
  final now = DateTime(2026, 10, 11, 15, 30);
  late InMemoryHealthRepository repo;
  late HealthStore store;

  setUp(() async {
    repo = InMemoryHealthRepository();
    store = HealthStore(repo, clock: () => now);
    await store.load();
  });

  group('daily aggregation', () {
    test('sums summed metrics within a day', () async {
      await store.addEntry(
        MetricType.water,
        250,
        date: DateTime(2026, 10, 11, 9),
      );
      await store.addEntry(
        MetricType.water,
        500,
        date: DateTime(2026, 10, 11, 13),
      );
      await store.addEntry(
        MetricType.water,
        300,
        date: DateTime(2026, 10, 10, 13),
      );

      expect(store.dailyValue(MetricType.water, DateTime(2026, 10, 11)), 750);
      expect(store.todayValue(MetricType.water), 750);
    });

    test('averages averaged metrics within a day', () async {
      await store.addEntry(
        MetricType.heartRate,
        60,
        date: DateTime(2026, 10, 11, 8),
      );
      await store.addEntry(
        MetricType.heartRate,
        90,
        date: DateTime(2026, 10, 11, 12),
      );

      expect(
        store.dailyValue(MetricType.heartRate, DateTime(2026, 10, 11)),
        75,
      );
    });

    test('uses the most recent value for latest metrics', () async {
      await store.addEntry(
        MetricType.weight,
        80,
        date: DateTime(2026, 10, 11, 20),
      );
      await store.addEntry(
        MetricType.weight,
        79,
        date: DateTime(2026, 10, 11, 7),
      );

      expect(store.dailyValue(MetricType.weight, DateTime(2026, 10, 11)), 80);
    });

    test('returns null for days without data', () {
      expect(
        store.dailyValue(MetricType.steps, DateTime(2026, 10, 11)),
        isNull,
      );
      expect(store.todayValue(MetricType.steps), 0);
    });
  });

  group('series and stats', () {
    test('dailySeries covers consecutive days ending on end date', () async {
      await store.addEntry(
        MetricType.steps,
        1000,
        date: DateTime(2026, 10, 5, 12),
      );
      await store.addEntry(
        MetricType.steps,
        3000,
        date: DateTime(2026, 10, 11, 12),
      );

      final series = store.dailySeries(MetricType.steps, end: now, days: 7);

      expect(series, [1000, null, null, null, null, null, 3000]);
      final stats = HealthStore.statsOf(series);
      expect(stats?.average, 2000);
      expect(stats?.min, 1000);
      expect(stats?.max, 3000);
      expect(stats?.daysWithData, 2);
    });

    test('monthlySeries averages daily values per month', () async {
      await store.addEntry(MetricType.steps, 1000, date: DateTime(2026, 9, 1));
      await store.addEntry(MetricType.steps, 3000, date: DateTime(2026, 9, 2));
      await store.addEntry(MetricType.steps, 500, date: DateTime(2026, 10, 1));

      final series = store.monthlySeries(MetricType.steps, end: now, months: 3);

      expect(series, [null, 2000, 500]);
    });

    test('latestReading finds the most recent day with data', () async {
      await store.addEntry(
        MetricType.sleep,
        7.5,
        date: DateTime(2026, 10, 8, 7),
      );
      await store.addEntry(MetricType.sleep, 6, date: DateTime(2026, 10, 3, 7));

      final reading = store.latestReading(MetricType.sleep);

      expect(reading?.day, DateTime(2026, 10, 8));
      expect(reading?.value, 7.5);
    });

    test('statsOf returns null when there is no data', () {
      expect(HealthStore.statsOf([null, null]), isNull);
    });
  });

  test('weight goal persists without becoming a daily goal', () async {
    await store.setWeightGoal(70);

    final reloaded = HealthStore(repo, clock: () => now);
    await reloaded.load();

    expect(reloaded.goals.weightKg, 70);
    expect(reloaded.goalProgress(MetricType.weight), isNull);
  });

  group('goals', () {
    test('goalProgress reflects today against the goal', () async {
      await store.updateGoal(MetricType.steps, 10000);
      await store.addEntry(MetricType.steps, 2500, date: now);

      expect(store.goalProgress(MetricType.steps), 0.25);
      expect(store.goalProgress(MetricType.heartRate), isNull);
    });
  });

  group('persistence', () {
    test('entries, goals and settings survive a reload', () async {
      await store.addEntry(MetricType.water, 250, note: 'Morning');
      await store.updateGoal(MetricType.water, 3000);
      await store.setThemeMode(ThemeMode.dark);
      await store.togglePinned(MetricType.water);
      await store.completeOnboarding(name: 'Alex', withSampleData: false);

      final reloaded = HealthStore(repo, clock: () => now);
      await reloaded.load();

      expect(reloaded.todayValue(MetricType.water), 250);
      expect(reloaded.entriesFor(MetricType.water).single.note, 'Morning');
      expect(reloaded.goals.water, 3000);
      expect(reloaded.themeMode, ThemeMode.dark);
      expect(reloaded.isPinned(MetricType.water), isTrue);
      expect(reloaded.onboarded, isTrue);
      expect(reloaded.profile.name, 'Alex');
    });

    test('delete and restore an entry', () async {
      final entry = await store.addEntry(MetricType.steps, 500);
      await store.deleteEntry(entry.id);
      expect(store.entriesFor(MetricType.steps), isEmpty);

      await store.restoreEntry(entry);
      expect(store.entriesFor(MetricType.steps).single.id, entry.id);
    });

    test('removing sample data keeps user entries', () async {
      await store.addEntry(MetricType.steps, 1234, date: DateTime(2026, 10, 1));
      await store.loadSampleData();
      expect(store.hasSampleData, isTrue);

      await store.removeSampleData();

      expect(store.hasSampleData, isFalse);
      expect(store.entriesFor(MetricType.steps).single.value, 1234);
    });

    test('eraseAll resets to onboarding', () async {
      await store.completeOnboarding(name: 'Alex', withSampleData: true);
      await store.eraseAll();

      expect(store.isEmpty, isTrue);
      expect(store.onboarded, isFalse);
      expect(store.profile.name, isEmpty);
    });
  });

  group('imported data', () {
    HealthEntry imported(MetricType type, double value, DateTime date) =>
        HealthEntry(
          id: 'hc:${type.name}:${date.month}-${date.day}',
          type: type,
          value: value,
          date: date,
          source: EntrySource.healthConnect,
        );

    test('replaceImported swaps only the window and types given', () async {
      await store.addEntry(MetricType.steps, 50, date: DateTime(2026, 10, 11));
      await store.replaceImported(
        from: DateTime(2026, 10, 1),
        types: {MetricType.steps, MetricType.weight},
        entries: [
          imported(MetricType.steps, 900, DateTime(2026, 9, 20)),
          imported(MetricType.steps, 1000, DateTime(2026, 10, 10)),
          imported(MetricType.weight, 80, DateTime(2026, 10, 10)),
        ],
      );

      // Resync: Oct 10 steps changed, weight was deleted in Health Connect.
      await store.replaceImported(
        from: DateTime(2026, 10, 5),
        types: {MetricType.steps, MetricType.weight},
        entries: [imported(MetricType.steps, 1200, DateTime(2026, 10, 10))],
      );

      expect(store.dailyValue(MetricType.steps, DateTime(2026, 9, 20)), 900);
      expect(store.dailyValue(MetricType.steps, DateTime(2026, 10, 10)), 1200);
      expect(store.dailyValue(MetricType.steps, DateTime(2026, 10, 11)), 50);
      expect(store.entriesFor(MetricType.weight), isEmpty);
    });

    test('estimates are only replaced along with heart rate', () async {
      final estimate = HealthEntry(
        id: '${HealthEntry.estimatePrefix}restingHeartRate:9-20',
        type: MetricType.restingHeartRate,
        value: 58,
        date: DateTime(2026, 9, 20),
        source: EntrySource.healthConnect,
      );
      await store.replaceImported(
        from: DateTime(2026, 9, 1),
        types: {MetricType.heartRate},
        entries: [estimate],
      );

      // Resting heart rate's own history import leaves the estimate alone.
      await store.replaceImported(
        from: DateTime(2025, 10, 1),
        types: {MetricType.restingHeartRate},
        entries: const [],
      );
      expect(store.entriesFor(MetricType.restingHeartRate), hasLength(1));

      await store.replaceImported(
        from: DateTime(2026, 9, 1),
        types: {MetricType.heartRate},
        entries: const [],
      );
      expect(store.entriesFor(MetricType.restingHeartRate), isEmpty);
    });

    test('removeImported keeps manual and sample entries', () async {
      await store.addEntry(MetricType.steps, 50);
      await store.loadSampleData();
      await store.replaceImported(
        from: DateTime(2026, 10, 1),
        types: {MetricType.steps},
        entries: [imported(MetricType.steps, 1000, DateTime(2026, 10, 10))],
      );
      expect(store.hasImportedData, isTrue);

      await store.removeImported();

      expect(store.hasImportedData, isFalse);
      expect(store.hasSampleData, isTrue);
      expect(
        store.entriesFor(MetricType.steps).any((e) => e.value == 50),
        isTrue,
      );
    });

    test('removing sample data keeps imported entries', () async {
      await store.loadSampleData();
      await store.replaceImported(
        from: DateTime(2026, 10, 1),
        types: {MetricType.steps},
        entries: [imported(MetricType.steps, 1000, DateTime(2026, 10, 10))],
      );

      await store.removeSampleData();

      expect(store.hasImportedData, isTrue);
    });
  });

  test('tryFromJson skips malformed records', () {
    expect(HealthEntry.tryFromJson({'type': 'nope', 'value': 1}), isNull);
    expect(
      HealthEntry.tryFromJson({
        'id': 'a',
        'type': 'steps',
        'value': 10,
        'date': '2026-10-11T10:00:00.000',
      })?.value,
      10,
    );
  });

  test('tryFromJson skips values that could never be saved again', () {
    Map<String, Object?> row(Object value, [String date = '2026-10-11']) => {
      'id': 'a',
      'type': 'steps',
      'value': value,
      'date': date,
    };
    expect(HealthEntry.tryFromJson(row(double.infinity)), isNull);
    expect(HealthEntry.tryFromJson(row(double.nan)), isNull);
    expect(HealthEntry.tryFromJson(row(5, '0001-01-01')), isNull);
    expect(HealthEntry.tryFromJson(row(5))?.value, 5);
  });

  test(
    'a restore saves even when the stored entries were unreadable',
    () async {
      final repo = _FlakyRepository()..failReads = true;
      final s = HealthStore(repo, clock: () => now);
      await s.load();
      repo.failReads = false;

      await s.restoreEntries([
        HealthEntry(id: 'r1', type: MetricType.steps, value: 1234, date: now),
      ], replace: true);

      expect((await repo.loadEntries()).map((e) => e.id), ['r1']);
    },
  );

  group('robustness', () {
    test('a failed save is reported and cleared by the next success', () async {
      final failing = _FlakyRepository()..failWrites = true;
      final s = HealthStore(failing, clock: () => now);
      await s.load();

      await s.addEntry(MetricType.steps, 100);
      expect(s.saveFailed, isTrue);
      expect(s.todayValue(MetricType.steps), 100); // kept in memory

      failing.failWrites = false;
      await s.addEntry(MetricType.steps, 50);
      expect(s.saveFailed, isFalse);
      expect((await failing.loadEntries()).length, 2);
    });

    test('a load failure still finishes loading with defaults', () async {
      final s = HealthStore(
        _FlakyRepository()..failReads = true,
        clock: () => now,
      );
      await s.load();

      expect(s.loaded, isTrue);
      expect(s.isEmpty, isTrue);
    });

    test('writes are applied in order, so erase is never undone', () async {
      await store.addEntry(MetricType.steps, 100);
      final pending = store.addEntry(MetricType.steps, 200);
      await store.eraseAll();
      await pending;

      expect(await repo.loadEntries(), isEmpty);
    });
  });

  group('workouts and Health Connect together', () {
    HealthEntry e(String id, double v, EntrySource source) => HealthEntry(
      id: id,
      type: MetricType.activeEnergy,
      value: v,
      date: DateTime(2026, 10, 11, 12),
      source: source,
    );

    test('a workout also seen by Health Connect counts once', () async {
      await store.replaceImported(
        from: DateTime(2026, 10, 11),
        types: {MetricType.activeEnergy},
        entries: [e('hc', 500, EntrySource.healthConnect)],
      );
      await store.addEntries([e('wk', 300, EntrySource.workout)]);
      await store.addEntry(
        MetricType.activeEnergy,
        20,
        date: DateTime(2026, 10, 11, 18),
      );

      // max(500 imported, 300 workout) + 20 logged by hand.
      expect(store.todayValue(MetricType.activeEnergy), 520);
    });

    test('workout totals win when larger than the imported total', () async {
      await store.replaceImported(
        from: DateTime(2026, 10, 11),
        types: {MetricType.activeEnergy},
        entries: [e('hc', 100, EntrySource.healthConnect)],
      );
      await store.addEntries([e('wk', 300, EntrySource.workout)]);

      expect(store.todayValue(MetricType.activeEnergy), 300);
    });

    test('removeEntriesWithPrefix deletes linked workout entries', () async {
      await store.addEntries([
        e('wk:1:activeEnergy', 300, EntrySource.workout),
        e('wk:2:activeEnergy', 200, EntrySource.workout),
      ]);

      await store.removeEntriesWithPrefix('wk:1:');

      expect(store.todayValue(MetricType.activeEnergy), 200);
    });
  });

  group('sample data', () {
    test('never blends with real readings on the same day', () async {
      await store.completeOnboarding(name: 'Alex', withSampleData: true);
      final sample = store.todayValue(MetricType.heartRate);
      expect(sample, greaterThan(0));

      await store.addEntry(MetricType.heartRate, 120);

      expect(store.todayValue(MetricType.heartRate), 120);
      // Days without real readings still show the samples.
      expect(store.hasSampleData, isTrue);
    });
  });
}

class _FlakyRepository extends InMemoryHealthRepository {
  bool failWrites = false;
  bool failReads = false;

  @override
  Future<List<HealthEntry>> loadEntries() async {
    if (failReads) throw Exception('read failed');
    return super.loadEntries();
  }

  @override
  Future<void> saveEntries(List<HealthEntry> entries) async {
    if (failWrites) throw Exception('disk full');
    return super.saveEntries(entries);
  }
}
