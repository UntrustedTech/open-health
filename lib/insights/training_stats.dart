import 'dart:math';

import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/models/muscles.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/workout/workout_stats.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Active minutes per day over the last year (for the activity heatmap).
Map<DateTime, int> activityByDay(
  Iterable<WorkoutSession> workouts, {
  required DateTime today,
}) {
  final from = DateTime(today.year - 1, today.month, today.day + 1);
  final out = <DateTime, int>{};
  for (final w in workouts) {
    final day = _day(w.start);
    if (day.isBefore(from)) continue;
    out[day] = (out[day] ?? 0) + w.activeSeconds ~/ 60;
  }
  return out;
}

typedef DatedValue = ({DateTime date, double value});

/// Best estimated one-rep max per session for an exercise, oldest first.
List<DatedValue> oneRepMaxSeries(
  Iterable<WorkoutSession> workouts,
  String exerciseId,
) {
  final id = ExerciseCatalog.canonical(exerciseId);
  final out = <DatedValue>[];
  for (final w in workouts) {
    double? best;
    for (final e in w.exercises) {
      if (ExerciseCatalog.canonical(e.exerciseId) != id) continue;
      for (final s in e.sets) {
        if (!s.done || !s.type.counts || s.weightKg <= 0) continue;
        best = max(best ?? 0, epley(s.weightKg, s.reps));
      }
    }
    if (best != null) out.add((date: w.start, value: best));
  }
  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}

typedef WeekVolume = ({DateTime weekStart, double kg});

/// Weight lifted (done working sets) per week, oldest first, with weeks
/// beginning on [firstDay].
List<WeekVolume> weeklyVolume(
  Iterable<WorkoutSession> workouts, {
  required DateTime today,
  int weeks = 12,
  int firstDay = DateTime.monday,
}) {
  final current = weekStart(today, firstDay: firstDay);
  final starts = [
    for (var i = weeks - 1; i >= 0; i--)
      DateTime(current.year, current.month, current.day - 7 * i),
  ];
  final totals = List<double>.filled(weeks, 0);
  for (final w in workouts) {
    for (var i = 0; i < weeks; i++) {
      final end = DateTime(starts[i].year, starts[i].month, starts[i].day + 7);
      if (!w.start.isBefore(starts[i]) && w.start.isBefore(end)) {
        totals[i] += w.volumeKg;
      }
    }
  }
  return [
    for (var i = 0; i < weeks; i++) (weekStart: starts[i], kg: totals[i]),
  ];
}

typedef MusclesOf = ({List<Muscle> primary, List<Muscle> secondary}) Function(
  String id,
);

/// Muscles worked by an exercise in the library.
({List<Muscle> primary, List<Muscle> secondary}) catalogMuscles(String id) {
  final e = ExerciseCatalog.instance.byId(id);
  return (
    primary: e?.primaryMuscles ?? const [],
    secondary: e?.secondaryMuscles ?? const [],
  );
}

/// Working sets per muscle over the last [days] (secondary muscles count
/// half), scaled 0..1 against the busiest muscle.
Map<Muscle, double> muscleVolume(
  Iterable<WorkoutSession> workouts, {
  required DateTime now,
  MusclesOf musclesOf = catalogMuscles,
  int days = 7,
}) {
  final since = now.subtract(Duration(days: days));
  final sets = <Muscle, double>{};
  for (final w in workouts.where((w) => w.start.isAfter(since))) {
    for (final e in w.exercises) {
      final n = e.sets.where((s) => s.done && s.type.counts).length;
      if (n == 0) continue;
      final m = musclesOf(e.exerciseId);
      for (final p in m.primary) {
        sets[p] = (sets[p] ?? 0) + n;
      }
      for (final s in m.secondary) {
        sets[s] = (sets[s] ?? 0) + n / 2;
      }
    }
  }
  if (sets.isEmpty) return const {};
  final top = sets.values.reduce(max);
  return {for (final e in sets.entries) e.key: e.value / top};
}

/// How recovered each recently trained muscle still is not: 1 just after
/// training, fading to 0 at [window] (48 hours).
Map<Muscle, double> muscleRecovery(
  Iterable<WorkoutSession> workouts, {
  required DateTime now,
  MusclesOf musclesOf = catalogMuscles,
  Duration window = const Duration(hours: 48),
}) {
  final out = <Muscle, double>{};
  for (final w in workouts) {
    final age = now.difference(w.start);
    if (age.isNegative || age >= window) continue;
    final level = 1 - age.inMinutes / window.inMinutes;
    for (final e in w.exercises) {
      if (!e.sets.any((s) => s.done && s.type.counts)) continue;
      final m = musclesOf(e.exerciseId);
      for (final muscle in [...m.primary, ...m.secondary]) {
        out[muscle] = max(out[muscle] ?? 0, level);
      }
    }
  }
  return out;
}

/// Major muscles not trained in the last [days].
Set<Muscle> untrainedMuscles(
  Iterable<WorkoutSession> workouts, {
  required DateTime now,
  MusclesOf musclesOf = catalogMuscles,
  int days = 7,
}) {
  final trained = muscleVolume(
    workouts,
    now: now,
    musclesOf: musclesOf,
    days: days,
  ).keys;
  return {
    for (final m in Muscle.values)
      if (m != Muscle.neck && !trained.contains(m)) m,
  };
}

typedef StrengthRatio = ({String label, double actual, double target});

typedef LiftIds = ({
  String squat,
  String bench,
  String deadlift,
  String press,
  String row,
});

const defaultLiftIds = (
  squat: '0043',
  bench: '0025',
  deadlift: '0032',
  press: 'ohp',
  row: '0027',
);

/// Lift ratios against common rule-of-thumb targets for a balanced body
/// (bench ≈ 75% of squat, deadlift ≈ 120% of squat, overhead press ≈ 65%
/// of bench, row ≈ 80% of bench). Pairs without data are left out.
List<StrengthRatio> strengthRatios(
  Map<String, LiftRecord> best, {
  LiftIds ids = defaultLiftIds,
}) {
  double? orm(String id) =>
      best[ExerciseCatalog.canonical(id)]?.estimatedOneRepMax;
  final pairs = [
    ('Bench vs Squat', ids.bench, ids.squat, 0.75),
    ('Deadlift vs Squat', ids.deadlift, ids.squat, 1.2),
    ('Overhead Press vs Bench', ids.press, ids.bench, 0.65),
    ('Row vs Bench', ids.row, ids.bench, 0.8),
  ];
  return [
    for (final (label, a, b, target) in pairs)
      if ((orm(a), orm(b)) case (final x?, final y?) when y > 0)
        (label: label, actual: x / y, target: target),
  ];
}
