import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/models/exercise_library.dart';
import 'package:health_app/models/health_entry.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/starter_plans.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/workout/geo.dart';

void main() {
  final now = DateTime(2026, 10, 11, 15);
  late InMemoryHealthRepository repo;
  late HealthStore health;
  late WorkoutStore workouts;

  WorkoutSession run(String id, {DateTime? start}) {
    final s = start ?? DateTime(2026, 10, 11, 7);
    return WorkoutSession(
      id: id,
      type: WorkoutType.run,
      start: s,
      end: s.add(const Duration(minutes: 31)),
      activeSeconds: 1800,
      distanceMeters: 5000,
      activeKcal: 320,
      splits: const [360, 360, 360, 360, 360],
      hasRoute: true,
    );
  }

  final route = [
    GeoPoint(lat: 51.5, lng: -0.1, time: DateTime(2026, 10, 11, 7)),
    GeoPoint(lat: 51.51, lng: -0.1, time: DateTime(2026, 10, 11, 7, 30)),
  ];

  Future<WorkoutStore> reload() async {
    final h = HealthStore(repo, clock: () => now);
    await h.load();
    final w = WorkoutStore(repo, h, clock: () => now);
    await w.load();
    return w;
  }

  setUp(() async {
    repo = InMemoryHealthRepository();
    health = HealthStore(repo, clock: () => now);
    await health.load();
    workouts = WorkoutStore(repo, health, clock: () => now);
    await workouts.load();
  });

  test('saving a workout adds its minutes, energy and distance', () async {
    await workouts.save(run('w1'), route: route);

    expect(workouts.all.single.id, 'w1');
    expect(health.todayValue(MetricType.exerciseMinutes), 30);
    expect(health.todayValue(MetricType.activeEnergy), 320);
    expect(health.todayValue(MetricType.distance), 5);
    final linked = health.entriesFor(MetricType.distance).single;
    expect(linked.source, EntrySource.workout);
  });

  test('workouts and routes survive a restart', () async {
    await workouts.save(run('w1'), route: route);

    final again = await reload();

    expect(again.all.single.distanceMeters, 5000);
    final loaded = await again.routeOf('w1');
    expect(loaded, hasLength(2));
    expect(loaded.last.lat, closeTo(51.51, 1e-5));
  });

  test('deleting a workout removes its linked data and route', () async {
    await workouts.save(run('w1'), route: route);

    await workouts.delete('w1');

    expect(workouts.all, isEmpty);
    expect(health.todayValue(MetricType.activeEnergy), 0);
    expect(await workouts.routeOf('w1'), isEmpty);
  });

  test('linked data without a workout is cleaned up on load', () async {
    await health.addEntries([
      HealthEntry(
        id: 'wk:gone:activeEnergy',
        type: MetricType.activeEnergy,
        value: 100,
        date: now,
        source: EntrySource.workout,
      ),
    ]);

    await reload();
    final h = HealthStore(repo, clock: () => now);
    await h.load();

    expect(h.todayValue(MetricType.activeEnergy), 0);
  });

  test('notes and effort can be edited', () async {
    await workouts.save(run('w1'));

    await workouts.update(workouts.all.single.copyWith(notes: 'Windy', rpe: 8));

    final again = await reload();
    expect(again.all.single.notes, 'Windy');
    expect(again.all.single.rpe, 8);
  });

  test('routines: presets plus saved ones', () async {
    const mine = Routine(
      id: 'r1',
      name: 'Arms',
      items: [RoutineItem('bicep_curl')],
    );
    await workouts.saveRoutine(mine);

    final again = await reload();
    expect(again.routines.map((r) => r.name), contains('Arms'));
    expect(again.routines.map((r) => r.name), contains('Push Day'));

    await again.deleteRoutine('r1');
    expect(again.routines.map((r) => r.name), isNot(contains('Arms')));
  });

  test('previous sets for an exercise come from the last workout', () async {
    await workouts.save(
      WorkoutSession(
        id: 's1',
        type: WorkoutType.strength,
        start: DateTime(2026, 10, 9, 18),
        end: DateTime(2026, 10, 9, 19),
        activeSeconds: 3600,
        exercises: const [
          ExerciseLog(
            exerciseId: 'squat',
            sets: [
              SetLog(reps: 5, weightKg: 100, done: true),
              // Planned but never done: not "last time".
              SetLog(reps: 5, weightKg: 100),
            ],
          ),
        ],
      ),
    );

    expect(workouts.previousSets('squat').single.weightKg, 100);
    expect(workouts.recentSets('squat').single, hasLength(1));
    expect(workouts.previousSets('bench_press'), isEmpty);
  });

  test('settings and checkpoints persist', () async {
    await workouts.updateSettings(
      workouts.settings.copyWith(
        mapStyle: MapStyle.street,
        saveToHealthConnect: true,
        weeklyGoalMinutes: 200,
      ),
    );
    await workouts.saveCheckpoint({'type': 'run'});

    final again = await reload();
    expect(again.settings.mapStyle, MapStyle.street);
    expect(again.settings.saveToHealthConnect, isTrue);
    expect(again.settings.weeklyGoalMinutes, 200);
    expect(await again.loadCheckpoint(), {'type': 'run'});

    await again.clearCheckpoint();
    expect(await again.loadCheckpoint(), isNull);
  });

  test('a save queued before Erase All does not come back', () async {
    final pending = workouts.save(run('w1'), route: route);
    await health.eraseAll();
    workouts.reset();
    await pending;

    final again = await reload();
    expect(again.all, isEmpty);
  });

  test('linked data is kept if the workout list could not be read', () async {
    await workouts.save(run('w1'));
    final broken = _UnreadableWorkouts();
    await broken.copyFrom(repo);
    final h = HealthStore(broken, clock: () => now);
    await h.load();

    await WorkoutStore(broken, h, clock: () => now).load();

    expect(h.todayValue(MetricType.activeEnergy), 320);
  });

  test('editing a workout moves and updates its linked data', () async {
    await workouts.save(run('w1'));
    final edited = WorkoutSession(
      id: 'w1',
      type: WorkoutType.run,
      start: DateTime(2026, 10, 9, 7),
      end: DateTime(2026, 10, 9, 8),
      activeSeconds: 3600,
      distanceMeters: 8000,
      activeKcal: 500,
    );

    await workouts.update(edited, relink: true);

    expect(health.todayValue(MetricType.distance), 0);
    expect(health.dailyValue(MetricType.distance, DateTime(2026, 10, 9)), 8);
    expect(
      health.dailyValue(MetricType.exerciseMinutes, DateTime(2026, 10, 9)),
      60,
    );
  });

  test('imported workouts are added once and add no activity data', () async {
    WorkoutSession imported(String id) => WorkoutSession(
      id: id,
      type: WorkoutType.strength,
      start: DateTime(2026, 10, 11, 7),
      end: DateTime(2026, 10, 11, 8),
      activeSeconds: 3600,
      source: WorkoutSource.imported,
    );

    final first = await workouts.importSessions([
      imported('imp-1'),
      imported('imp-2'),
    ]);
    final again = await workouts.importSessions([imported('imp-1')]);

    expect(first, 2);
    expect(again, 0);
    expect(workouts.all, hasLength(2));
    expect(health.todayValue(MetricType.exerciseMinutes), 0);
    expect((await reload()).all, hasLength(2));
  });

  test('importing this app\'s own export adds no duplicates', () async {
    const squat = [
      ExerciseLog(
        exerciseId: 'squat',
        sets: [SetLog(reps: 5, weightKg: 100, done: true)],
      ),
    ];
    await workouts.save(
      WorkoutSession(
        id: 'mine',
        type: WorkoutType.strength,
        start: DateTime(2026, 10, 9, 18, 0, 42),
        end: DateTime(2026, 10, 9, 19),
        activeSeconds: 3500,
        exercises: squat,
      ),
    );
    // The export keeps the minute; the importer makes its own id.
    final added = await workouts.importSessions([
      WorkoutSession(
        id: 'imp-strong-1',
        type: WorkoutType.strength,
        start: DateTime(2026, 10, 9, 18),
        end: DateTime(2026, 10, 9, 19),
        activeSeconds: 3600,
        source: WorkoutSource.imported,
        exercises: squat,
      ),
    ]);
    expect(added, 0);
    expect(workouts.all, hasLength(1));
  });

  test(
    'a skipped workout\'s restored entries are dropped, not doubled',
    () async {
      await workouts.save(
        WorkoutSession(
          id: 'mine',
          type: WorkoutType.walk,
          start: DateTime(2026, 10, 9, 18),
          end: DateTime(2026, 10, 9, 19),
          activeSeconds: 3600,
        ),
      );
      final linked = health.allEntries.where((e) => e.isFromWorkout).toList();
      expect(linked, isNotEmpty);
      // A restore brought the same entries back under another workout's id.
      await health.restoreEntries([
        for (final e in linked)
          HealthEntry(
            id: e.id.replaceFirst('wk:mine:', 'wk:other:'),
            type: e.type,
            value: e.value,
            date: e.date,
            source: e.source,
          ),
      ], replace: false);

      await workouts.dropEntriesOfMissing(['mine', 'other']);

      expect(
        health.allEntries.where((e) => e.isFromWorkout).map((e) => e.id),
        unorderedEquals(linked.map((e) => e.id)),
      );
    },
  );

  test(
    'editing an imported workout keeps it imported, without activity',
    () async {
      final start = DateTime(2026, 10, 11, 7);
      await workouts.importSessions([
        WorkoutSession(
          id: 'imp-1',
          type: WorkoutType.strength,
          start: start,
          end: start.add(const Duration(hours: 1)),
          activeSeconds: 3600,
          source: WorkoutSource.imported,
        ),
      ]);

      // The edit screen rebuilds the session without its source.
      await workouts.update(
        WorkoutSession(
          id: 'imp-1',
          type: WorkoutType.strength,
          start: start,
          end: start.add(const Duration(minutes: 45)),
          activeSeconds: 2700,
          activeKcal: 200,
        ),
        relink: true,
      );

      expect(workouts.all.single.source, WorkoutSource.imported);
      expect(health.todayValue(MetricType.exerciseMinutes), 0);
      expect(health.todayValue(MetricType.activeEnergy), 0);
    },
  );

  group('training plan', () {
    test('applying a starter plan copies its routines and days', () async {
      await workouts.applyStarter(StarterPlan.pushPullLegs);

      final names = workouts.routines.map((r) => r.name);
      expect(names, containsAll(['Push', 'Pull', 'Legs']));
      final mondayId = workouts.plan.days[DateTime.monday];
      expect(
        workouts.routines.firstWhere((r) => r.id == mondayId).name,
        'Push',
      );
      expect(mondayId, isNot('ppl_push')); // a fresh, editable copy

      final again = await reload();
      expect(again.plan.days[DateTime.monday], mondayId);
    });

    test('today follows the plan and completed workouts', () async {
      await workouts.applyStarter(StarterPlan.pushPullLegs);
      // `now` is Sunday: a rest day; Monday is next.
      expect(workouts.todaySession().isRest, isTrue);
      expect(workouts.nextPlanned()?.date.weekday, DateTime.monday);

      final pushId = workouts.plan.days[DateTime.monday]!;
      await workouts.setPlan(
        workouts.plan.copyWith(days: {DateTime.sunday: pushId}),
      );
      expect(workouts.todaySession().routineId, pushId);

      await workouts.save(
        WorkoutSession(
          id: 'done',
          type: WorkoutType.strength,
          start: DateTime(2026, 10, 11, 9),
          end: DateTime(2026, 10, 11, 10),
          activeSeconds: 3600,
          routineId: pushId,
        ),
      );
      expect(workouts.todaySession().done, isTrue);
    });

    test('deleting a routine removes it from the plan', () async {
      await workouts.applyStarter(StarterPlan.pushPullLegs);
      final pushId = workouts.plan.days[DateTime.monday]!;

      await workouts.deleteRoutine(pushId);

      expect(workouts.plan.days.containsKey(DateTime.monday), isFalse);
    });
  });
}

class _UnreadableWorkouts extends InMemoryHealthRepository {
  Future<void> copyFrom(InMemoryHealthRepository other) async {
    await saveEntries(await other.loadEntries());
  }

  @override
  Future<Map<String, Object?>?> loadDocument(String key) async {
    if (key == 'workouts') throw const UnreadableDataException('workouts');
    return super.loadDocument(key);
  }
}
