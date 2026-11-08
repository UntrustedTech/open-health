import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/insights/progress_stats.dart';
import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/workout/workout_tracker.dart';

WorkoutSession _lift(
  String id,
  DateTime start,
  double kg, {
  WorkoutType type = WorkoutType.strength,
}) => WorkoutSession(
  id: id,
  type: type,
  start: start,
  end: start.add(const Duration(minutes: 50)),
  activeSeconds: 3000,
  exercises: [
    ExerciseLog(
      exerciseId: 'squat',
      sets: [SetLog(reps: 5, weightKg: kg, done: true)],
    ),
  ],
);

void main() {
  test('previous workout of the same type', () {
    final a = _lift('a', DateTime(2026, 10, 1), 100);
    final b = _lift('b', DateTime(2026, 10, 5), 105);
    final run = _lift('r', DateTime(2026, 10, 6), 0, type: WorkoutType.run);
    final c = _lift('c', DateTime(2026, 10, 8), 110);
    expect(previousOfType([a, b, run, c], c)?.id, 'b');
    expect(previousOfType([a, b, c], a), isNull);
  });

  test('a session record beats every earlier session, not the first', () {
    final a = _lift('a', DateTime(2026, 10, 1), 100);
    final b = _lift('b', DateTime(2026, 10, 5), 95);
    final c = _lift('c', DateTime(2026, 10, 8), 110);
    final all = [a, b, c];
    expect(sessionRecords(all, a), isEmpty); // first ever
    expect(sessionRecords(all, b), isEmpty);
    expect(sessionRecords(all, c), {ExerciseCatalog.canonical('squat')});
  });

  group('tracker focus', () {
    late DateTime now;

    WorkoutTracker tracker() => WorkoutTracker(
      type: WorkoutType.strength,
      weightKg: 70,
      clock: () => now,
      exercises: const [
        ExerciseLog(
          exerciseId: 'squat',
          sets: [
            SetLog(reps: 5, weightKg: 100),
            SetLog(reps: 5, weightKg: 100),
          ],
        ),
      ],
    )..start();

    setUp(() => now = DateTime(2026, 10, 11, 8));

    test('next set moves on as sets are done', () {
      final t = tracker();
      expect(t.nextSet, (exercise: 0, set: 0));
      t.toggleSetDone(0, 0);
      expect(t.nextSet, (exercise: 0, set: 1));
      t.toggleSetDone(0, 1);
      expect(t.nextSet, isNull);
    });

    test('rest can be lengthened and shortened, not below 5 s', () {
      final t = tracker()..toggleSetDone(0, 0);
      expect(t.restRemaining, const Duration(seconds: 90));
      t.adjustRest(const Duration(seconds: 15));
      expect(t.restRemaining, const Duration(seconds: 105));
      expect(t.restTotal, const Duration(seconds: 105));
      t.adjustRest(const Duration(seconds: -200));
      expect(t.restRemaining, const Duration(seconds: 5));
    });
  });
}
