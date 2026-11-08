import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/models/exercise_library.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/workout/progression.dart';
import 'package:health_app/workout/session_builder.dart';

void main() {
  List<List<SetLog>> none(String id) => const [];

  test("first time uses the routine's targets", () {
    final planned = buildSession(
      const Routine(
        id: 'r',
        name: 'R',
        items: [RoutineItem('0025', sets: 3, reps: 8, weightKg: 60)],
      ),
      recentSets: none,
    );
    final e = planned.single.log;
    expect(e.sets.length, 3);
    expect(e.sets.every((s) => s.weightKg == 60 && s.reps == 8), isTrue);
  });

  test("without a rule, last time's sets are pre-filled", () {
    final planned = buildSession(
      const Routine(
        id: 'r',
        name: 'R',
        items: [RoutineItem('0025', sets: 2, reps: 8)],
      ),
      recentSets: (_) => [
        const [
          SetLog(reps: 8, weightKg: 70, done: true, rpe: 8),
          SetLog(reps: 7, weightKg: 70, done: true, rpe: 9),
        ],
      ],
    );
    final sets = planned.single.log.sets;
    expect(sets.map((s) => s.weightKg), [70, 70]);
    expect(sets.map((s) => s.rpe), [null, null]);
    expect(sets.map((s) => s.reps), [8, 7]);
    expect(sets.every((s) => !s.done), isTrue);
    // The set table's Previous column already shows last time.
    expect(planned.single.hint, isNull);
  });

  test('a progression rule sets the target and explains it', () {
    final planned = buildSession(
      const Routine(
        id: 'r',
        name: 'R',
        items: [
          RoutineItem(
            '0043',
            sets: 3,
            reps: 5,
            progression: ProgressionRule(kind: ProgressionKind.linear),
          ),
        ],
      ),
      recentSets: (_) => [
        [
          for (var i = 0; i < 3; i++)
            const SetLog(reps: 5, weightKg: 100, done: true),
        ],
      ],
    );
    expect(planned.single.log.sets.every((s) => s.weightKg == 102.5), isTrue);
    expect(planned.single.hint, contains('+2.5'));
  });

  test('warm-ups, rest, supersets and timed exercises carry over', () {
    final planned = buildSession(
      const Routine(
        id: 'r',
        name: 'R',
        items: [
          RoutineItem(
            '0025',
            sets: 2,
            reps: 5,
            weightKg: 100,
            warmupSets: 2,
            restSeconds: 180,
            superset: 1,
          ),
          RoutineItem('plank', sets: 2, reps: 45),
        ],
      ),
      recentSets: none,
      isTimed: (id) => id == 'plank',
    );
    final bench = planned.first.log;
    expect(bench.sets.take(2).every((s) => s.type == SetType.warmup), isTrue);
    expect(bench.sets.first.weightKg, lessThan(100));
    expect(bench.restSeconds, 180);
    expect(bench.superset, 1);
    expect(planned.last.log.sets.first.seconds, 45);
  });
}
