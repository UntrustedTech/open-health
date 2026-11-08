import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/models/workout.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/workout/calories.dart';
import 'package:health_app/workout/energy.dart';
import 'package:health_app/workout/geo.dart';
import 'package:health_app/workout/intervals.dart';
import 'package:health_app/workout/workout_stats.dart';
import 'package:health_app/workout/workout_tracker.dart';

void main() {
  late DateTime now;
  void advance(int seconds) => now = now.add(Duration(seconds: seconds));

  /// A point [metersNorth] north of the start, stamped with the current time.
  GeoPoint at(double metersNorth) =>
      GeoPoint(lat: 51.5 + metersNorth / 111194.9, lng: -0.1, time: now);

  WorkoutTracker tracker(WorkoutType type, {IntervalProgram? program}) =>
      WorkoutTracker(
        type: type,
        weightKg: 70,
        program: program,
        clock: () => now,
      );

  setUp(() => now = DateTime(2026, 10, 11, 8));

  test('pauses are excluded from active time', () {
    final t = tracker(WorkoutType.yoga)..start();
    advance(60);
    t.pause();
    advance(30);
    t.resume();
    advance(30);

    expect(t.elapsed, const Duration(seconds: 90));
    expect(t.status, TrackerStatus.running);
  });

  test('altitude jitter on the flat adds no elevation; real climbs do', () {
    final t = tracker(WorkoutType.run)..start();
    GeoPoint high(double m, double altitude) => GeoPoint(
      lat: at(m).lat,
      lng: -0.1,
      time: now,
      accuracy: 5,
      altitude: altitude,
    );
    // ±2 m of noise around 50 m.
    for (final (i, alt) in <double>[50, 52, 49, 51, 48, 50, 52, 50].indexed) {
      t.addLocation(high(i * 20.0, alt));
      advance(6);
    }
    expect(t.elevationGainMeters, 0);

    // A steady 30 m climb.
    for (var i = 0; i <= 10; i++) {
      t.addLocation(high(200 + i * 20.0, 48 + i * 3.0));
      advance(6);
    }
    expect(t.elevationGainMeters, closeTo(30, 0.01));
  });

  test('kilometres crossed in one GPS gap share its time', () {
    final t = tracker(WorkoutType.cycle)..start();
    t.addLocation(at(0));
    advance(600);
    t.addLocation(at(3000));

    expect(t.splits, hasLength(3));
    expect(t.splits.every((s) => s >= 190), isTrue, reason: '${t.splits}');
    expect(t.splits.fold(0, (a, b) => a + b), 600);
  });

  test('distance, km splits and pause gaps from GPS', () {
    final t = tracker(WorkoutType.run)..start();
    for (var m = 0; m <= 1200; m += 100) {
      t.addLocation(at(m.toDouble()));
      advance(30); // 100 m every 30 s = 5:00/km
    }
    expect(t.distanceMeters, closeTo(1200, 5));
    expect(t.splits.single, closeTo(300, 2));

    t.pause();
    t.addLocation(at(5000)); // ignored while paused
    advance(60);
    t.resume();
    t.addLocation(at(1300)); // new segment: no jump from the last point
    advance(30);
    t.addLocation(at(1400));

    expect(t.distanceMeters, closeTo(1300, 5));
    expect(t.currentPaceSecondsPerKm, closeTo(300, 15));
  });

  test('laps record time and distance since the previous lap', () {
    final t = tracker(WorkoutType.run)..start();
    t.addLocation(at(0));
    advance(60);
    t.addLocation(at(200));
    t.lap();
    advance(60);
    t.addLocation(at(500));
    t.lap();

    expect(t.laps.map((l) => l.seconds), [60, 60]);
    expect(t.laps.last.meters, closeTo(300, 2));
  });

  test('interval phase changes are announced', () {
    const program = IntervalProgram(
      name: 'Test',
      work: Duration(seconds: 20),
      rest: Duration(seconds: 10),
      rounds: 2,
    );
    final changes = <PhaseKind?>[];
    final t = tracker(WorkoutType.hiit, program: program)
      ..onPhaseChange = ((p) => changes.add(p?.kind))
      ..start();

    for (var i = 0; i < 60; i++) {
      advance(1);
      t.tick();
    }

    expect(changes, [PhaseKind.rest, PhaseKind.work, null]);
    expect(t.programFinished, isTrue);
  });

  test('completing a set starts the rest timer', () {
    final t = tracker(WorkoutType.strength)..start();
    t.addExercise('squat');
    t.updateSet(0, 0, const SetLog(reps: 5, weightKg: 100));
    t.toggleSetDone(0, 0);
    advance(30);

    expect(t.exercises.single.sets.first.done, isTrue);
    expect(t.restRemaining, const Duration(seconds: 60));
    t.skipRest();
    expect(t.restRemaining, isNull);
  });

  test('finish produces a complete workout', () {
    final t = tracker(WorkoutType.run)..start();
    for (var m = 0; m <= 1000; m += 100) {
      t.addLocation(at(m.toDouble()));
      advance(30);
    }

    final (session, route) = t.finish(id: 'w1');

    expect(session.id, 'w1');
    expect(session.activeSeconds, 330);
    expect(session.distanceMeters, closeTo(1000, 5));
    expect(session.splits, hasLength(1));
    expect(session.hasRoute, isTrue);
    expect(route, isNotEmpty);
    expect(
      session.activeKcal,
      closeTo(
        // Intensity from the actual pace (1 km in 330 s).
        activeCalories(
          met: metFor(WorkoutType.run, metersPerSecond: 1000 / 330),
          weightKg: 70,
          duration: const Duration(seconds: 330),
        ),
        0.1,
      ),
    );
    expect(t.status, TrackerStatus.finished);
  });

  test('a checkpoint restores an interrupted workout', () {
    final t = tracker(WorkoutType.run)..start();
    t.addLocation(at(0));
    advance(120);
    t.addLocation(at(400));
    t.addExercise('squat');

    final restored = WorkoutTracker.fromCheckpoint(
      t.toCheckpoint(),
      clock: () => now,
    );

    expect(restored, isNotNull);
    expect(restored!.type, WorkoutType.run);
    expect(restored.status, TrackerStatus.paused);
    expect(restored.elapsed, const Duration(seconds: 120));
    expect(restored.distanceMeters, closeTo(400, 2));
    expect(restored.exercises.single.exerciseId, 'squat');
  });

  test('mile splits are timed from the last mile after a restore', () {
    Units.system = UnitSystem.imperial;
    addTearDown(() => Units.system = UnitSystem.metric);
    final t = tracker(WorkoutType.run)..start();
    t.addLocation(at(0));
    advance(300);
    t.addLocation(at(1000)); // 1 km at 5:00
    advance(180);
    t.addLocation(at(1700)); // past 1 mile at 8:00

    final restored = WorkoutTracker.fromCheckpoint(
      t.toCheckpoint(),
      clock: () => now,
    )!;
    final shown = <(int, int)>[];
    restored
      ..onSplit = ((n, s) => shown.add((n, s)))
      ..resume()
      // After a restore, the first fix starts a new stretch of route.
      ..addLocation(at(1700));
    advance(420);
    restored.addLocation(at(3300)); // past 2 miles at 15:00

    expect(shown, [(2, 420)]);
  });

  test('time the app spent closed counts when the workout was running', () {
    final t = tracker(WorkoutType.yoga)..start();
    advance(300);
    final saved = t.toCheckpoint();
    // Android stopped the app; it reopens 50 minutes later.
    advance(50 * 60);
    final restored = WorkoutTracker.fromCheckpoint(saved, clock: () => now)!;
    expect(restored.status, TrackerStatus.paused);
    expect(restored.elapsed, const Duration(minutes: 55));

    // Paused when saved: nothing more is added.
    final p = tracker(WorkoutType.yoga)..start();
    advance(60);
    p.pause();
    final pausedSave = p.toCheckpoint();
    advance(600);
    expect(
      WorkoutTracker.fromCheckpoint(pausedSave, clock: () => now)!.elapsed,
      const Duration(seconds: 60),
    );

    // A forgotten workout gains at most four hours.
    final f = tracker(WorkoutType.yoga)..start();
    final forgotten = f.toCheckpoint();
    advance(3 * 24 * 3600);
    expect(
      WorkoutTracker.fromCheckpoint(forgotten, clock: () => now)!.elapsed,
      const Duration(hours: 4),
    );
  });

  test('a rest that runs out is announced, and waits while paused', () {
    final t = WorkoutTracker(
      type: WorkoutType.strength,
      weightKg: 70,
      exercises: [
        ExerciseLog(
          exerciseId: 'squat',
          sets: [SetLog(reps: 5, weightKg: 100)],
        ),
      ],
      restDuration: const Duration(seconds: 60),
      clock: () => now,
    )..start();
    var over = 0;
    t.onRestComplete = () => over++;
    t.toggleSetDone(0, 0);
    expect(t.restRemaining, const Duration(seconds: 60));

    advance(20);
    t.pause();
    advance(300);
    t.tick();
    expect(over, 0, reason: 'paused, the rest waits');
    t.resume();
    expect(t.restRemaining, const Duration(seconds: 40));

    advance(40);
    t.tick();
    expect(over, 1);
    expect(t.restRemaining, isNull);
    t.tick();
    expect(over, 1, reason: 'announced once');
  });

  group('strength details', () {
    WorkoutTracker strength({
      List<ExerciseLog> exercises = const [],
      Map<String, LiftRecord> bests = const {},
    }) => WorkoutTracker(
      type: WorkoutType.strength,
      weightKg: 70,
      exercises: exercises,
      bests: bests,
      clock: () => now,
    )..start();

    test('rest follows the exercise\'s own rest time', () {
      final t = strength(
        exercises: const [
          ExerciseLog(
            exerciseId: '0025',
            restSeconds: 180,
            sets: [SetLog(reps: 5, weightKg: 100)],
          ),
        ],
      );
      t.toggleSetDone(0, 0);
      expect(t.restRemaining, const Duration(seconds: 180));
    });

    test('supersets rest only after the last exercise of the group', () {
      final t = strength(
        exercises: const [
          ExerciseLog(
            exerciseId: 'a',
            superset: 1,
            sets: [SetLog(reps: 10, weightKg: 20)],
          ),
          ExerciseLog(
            exerciseId: 'b',
            superset: 1,
            sets: [SetLog(reps: 10, weightKg: 20)],
          ),
        ],
      );
      t.toggleSetDone(0, 0);
      expect(t.restRemaining, isNull);
      t.toggleSetDone(1, 0);
      expect(t.restRemaining, isNotNull);
    });

    test('warm-up sets start no rest timer', () {
      final t = strength(
        exercises: const [
          ExerciseLog(
            exerciseId: 'a',
            sets: [SetLog(reps: 10, weightKg: 20, type: SetType.warmup)],
          ),
        ],
      );
      t.toggleSetDone(0, 0);
      expect(t.restRemaining, isNull);
    });

    test('a new best is announced once', () {
      final prs = <String>[];
      final t = strength(
        exercises: const [
          ExerciseLog(
            exerciseId: 'bench_press',
            sets: [
              SetLog(reps: 5, weightKg: 105),
              SetLog(reps: 5, weightKg: 105),
            ],
          ),
        ],
        bests: {
          '0025': (
            weightKg: 100.0,
            reps: 5,
            estimatedOneRepMax: epley(100, 5),
            date: DateTime(2026),
          ),
        },
      )..onPersonalRecord = ((id, set) => prs.add(id));

      t.toggleSetDone(0, 0);
      t.toggleSetDone(0, 1);

      expect(prs, ['bench_press']);
      expect(t.personalRecords, 1);
      // Unticked by mistake: the record goes; ticked again, it's back.
      t.toggleSetDone(0, 0);
      t.toggleSetDone(0, 1);
      expect(t.personalRecords, 0);
      t.toggleSetDone(0, 0);
      expect(t.personalRecords, 1);
      // Corrected to a lighter weight: no longer a record.
      t.updateSet(0, 0, const SetLog(reps: 5, weightKg: 90));
      expect(t.personalRecords, 0);
      expect(prs, hasLength(2));
    });

    test('a first-ever exercise records a PR on a heavier later set', () {
      final prs = <String>[];
      final t = strength(
        exercises: const [
          ExerciseLog(
            exerciseId: 'a',
            sets: [
              SetLog(reps: 5, weightKg: 50),
              SetLog(reps: 5, weightKg: 60),
            ],
          ),
        ],
      )..onPersonalRecord = ((id, set) => prs.add(id));

      t.toggleSetDone(0, 0);
      t.toggleSetDone(0, 1);

      expect(prs, ['a']);
    });

    test('a heavier single doesn\'t lower the best estimated max', () {
      final prs = <double>[];
      final t = strength(
        exercises: const [
          ExerciseLog(
            exerciseId: 'a',
            sets: [
              SetLog(reps: 1, weightKg: 105),
              SetLog(reps: 5, weightKg: 100),
            ],
          ),
        ],
        bests: {
          'a': (
            weightKg: 100.0,
            reps: 5,
            estimatedOneRepMax: epley(100, 5),
            date: DateTime(2026),
          ),
        },
      )..onPersonalRecord = ((id, set) => prs.add(set.weightKg));

      t.toggleSetDone(0, 0);
      t.toggleSetDone(0, 1);

      expect(prs, [105]); // the repeat of 100×5 is not a new record
    });

    test('a restored workout keeps records and rest time', () {
      final prs = <String>[];
      final t = strength(
        exercises: const [
          ExerciseLog(exerciseId: 'a', sets: [SetLog(reps: 5, weightKg: 110)]),
        ],
      );
      final restored = WorkoutTracker.fromCheckpoint(
        t.toCheckpoint(),
        clock: () => now,
        bests: {
          'a': (
            weightKg: 100.0,
            reps: 5,
            estimatedOneRepMax: epley(100, 5),
            date: DateTime(2026),
          ),
        },
        restDuration: const Duration(seconds: 150),
      )!..onPersonalRecord = ((id, set) => prs.add(id));

      restored
        ..resume()
        ..toggleSetDone(0, 0);

      expect(prs, ['a']);
      expect(restored.restRemaining, const Duration(seconds: 150));
    });

    test('copying a set inserts an undone copy after it', () {
      final t = strength(
        exercises: const [
          ExerciseLog(
            exerciseId: 'a',
            sets: [SetLog(reps: 8, weightKg: 50, done: true)],
          ),
        ],
      );
      t.copySet(0, 0);
      expect(t.exercises.single.sets.length, 2);
      expect(t.exercises.single.sets[1].weightKg, 50);
      expect(t.exercises.single.sets[1].done, isFalse);
    });
  });

  test('top speed comes from 15-second stretches and survives a restart', () {
    final t = tracker(WorkoutType.cycle)..start();
    expect(t.topSpeedMps, isNull);
    // 5 m/s for a minute, then 10 m/s for 30 seconds, then 5 again.
    var m = 0.0;
    for (final (secs, mps) in [(60, 5.0), (30, 10.0), (30, 5.0)]) {
      for (var i = 0; i < secs; i++) {
        advance(1);
        m += mps;
        t.addLocation(at(m));
      }
    }
    expect(t.topSpeedMps, closeTo(10, 0.2));
    expect(t.currentSpeedMps, closeTo(7.5, 1)); // half fast, half slow

    final again = WorkoutTracker.fromCheckpoint(
      t.toCheckpoint(),
      clock: () => now,
    );
    expect(again?.topSpeedMps, closeTo(10, 0.2));
  });

  test('a pause in the route is never a burst of speed', () {
    final route = [
      for (var s = 0; s <= 30; s++)
        GeoPoint(
          lat: 51.5 + s * 3 / 111194.9,
          lng: -0.1,
          time: now.add(Duration(seconds: s)),
        ),
      // Resumed 5 minutes later, 2 km further on.
      for (var s = 0; s <= 30; s++)
        GeoPoint(
          lat: 51.5 + (2000 + s * 3) / 111194.9,
          lng: -0.1,
          time: now.add(Duration(seconds: 330 + s)),
        ),
    ];
    expect(topSpeed(route), closeTo(3, 0.1));
    // The first seconds of each stretch are left out, not guessed.
    final speeds = rollingSpeeds(route);
    expect(speeds.first.time, now.add(const Duration(seconds: 8)));
    expect(topSpeed(route.take(3).toList()), isNull);
  });
}
