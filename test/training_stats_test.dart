import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/insights/training_stats.dart';
import 'package:health_app/models/muscles.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/workout/workout_stats.dart';

WorkoutSession _w(
  String id,
  DateTime start, {
  int minutes = 60,
  List<ExerciseLog> exercises = const [],
}) => WorkoutSession(
  id: id,
  type: WorkoutType.strength,
  start: start,
  end: start.add(Duration(minutes: minutes)),
  activeSeconds: minutes * 60,
  exercises: exercises,
);

ExerciseLog _ex(
  String id,
  List<(double, int)> sets, {
  SetType type = SetType.normal,
}) => ExerciseLog(
  exerciseId: id,
  sets: [
    for (final (kg, r) in sets)
      SetLog(reps: r, weightKg: kg, done: true, type: type),
  ],
);

({List<Muscle> primary, List<Muscle> secondary}) _muscles(String id) =>
    switch (id) {
      'bench' => (primary: [Muscle.chest], secondary: [Muscle.triceps]),
      'squat' => (primary: [Muscle.quadriceps], secondary: [Muscle.glutes]),
      _ => (primary: const <Muscle>[], secondary: const <Muscle>[]),
    };

void main() {
  final now = DateTime(2026, 10, 11, 12);

  test('heatmap sums minutes per day', () {
    final map = activityByDay([
      _w('a', DateTime(2026, 10, 10, 8), minutes: 30),
      _w('b', DateTime(2026, 10, 10, 18), minutes: 20),
      _w('c', DateTime(2025, 1, 1)),
    ], today: now);
    expect(map[DateTime(2026, 10, 10)], 50);
    expect(map.containsKey(DateTime(2025, 1, 1)), isFalse); // older than a year
  });

  test('estimated 1RM per session, oldest first, ignoring warm-ups', () {
    final series = oneRepMaxSeries([
      _w(
        'b',
        DateTime(2026, 10, 8),
        exercises: [
          _ex('bench', [(100, 5)]),
        ],
      ),
      _w(
        'a',
        DateTime(2026, 10, 1),
        exercises: [
          _ex('bench', [(140, 5)], type: SetType.warmup),
          _ex('bench', [(90, 5), (80, 10)]),
        ],
      ),
    ], 'bench');
    expect(series.map((p) => p.date.day), [1, 8]);
    expect(series.first.value, closeTo(epley(80, 10), 0.01));
    expect(series.last.value, closeTo(epley(100, 5), 0.01));
  });

  test('weekly volume counts done working sets', () {
    final weeks = weeklyVolume(
      [
        _w(
          'a',
          DateTime(2026, 10, 6),
          exercises: [
            _ex('bench', [(100, 5), (100, 5)]),
          ],
        ),
        _w(
          'b',
          DateTime(2026, 9, 29),
          exercises: [
            _ex('bench', [(50, 10)]),
          ],
        ),
      ],
      today: now,
      weeks: 3,
    );
    expect(weeks.map((w) => w.kg), [0, 500, 1000]);
  });

  group('muscle map', () {
    final history = [
      _w(
        'a',
        DateTime(2026, 10, 10, 18),
        exercises: [
          _ex('bench', [(100, 5), (100, 5)]),
        ],
      ),
      _w(
        'b',
        DateTime(2026, 10, 2),
        exercises: [
          _ex('squat', [(100, 5)]),
        ],
      ),
    ];

    test('weekly volume: primary counts fully, secondary half', () {
      final v = muscleVolume(history, now: now, musclesOf: _muscles);
      expect(v[Muscle.chest], 1.0);
      expect(v[Muscle.triceps], 0.5);
      expect(v.containsKey(Muscle.quadriceps), isFalse); // 9 days ago
    });

    test('recovery fades over 48 hours', () {
      final r = muscleRecovery(history, now: now, musclesOf: _muscles);
      // Trained 18 hours ago: still recovering.
      expect(r[Muscle.chest], closeTo(1 - 18 / 48, 0.01));
      expect(r.containsKey(Muscle.quadriceps), isFalse);
    });

    test('untrained: nothing in the last 7 days', () {
      final u = untrainedMuscles(history, now: now, musclesOf: _muscles);
      expect(u, contains(Muscle.quadriceps));
      expect(u, isNot(contains(Muscle.chest)));
    });
  });

  test('strength ratios compare lifts with common targets', () {
    final ratios = strengthRatios(
      {
        'sq': (weightKg: 100.0, reps: 1, estimatedOneRepMax: 100.0, date: now),
        'bp': (weightKg: 70.0, reps: 1, estimatedOneRepMax: 70.0, date: now),
      },
      ids: (squat: 'sq', bench: 'bp', deadlift: 'dl', press: 'ohp', row: 'row'),
    );
    final bench = ratios.firstWhere((r) => r.label.startsWith('Bench'));
    expect(bench.actual, closeTo(0.70, 0.001));
    expect(bench.target, 0.75);
    // Lifts without data are left out.
    expect(ratios.any((r) => r.label.startsWith('Deadlift')), isFalse);
  });
}
