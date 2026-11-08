import 'dart:math';

import 'package:health_app/insights/training_stats.dart';
import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/workout/workout_stats.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Weeks in a row with at least one workout, up to this week (or last
/// week, so the streak isn't lost before this week's first workout).
/// Weeks begin on [firstDay].
int weekStreak(
  Iterable<WorkoutSession> workouts,
  DateTime today, {
  int firstDay = DateTime.monday,
}) {
  final weeks = {
    for (final w in workouts) weekStart(w.start, firstDay: firstDay),
  };
  var week = weekStart(today, firstDay: firstDay);
  if (!weeks.contains(week)) {
    week = DateTime(week.year, week.month, week.day - 7);
  }
  var streak = 0;
  while (weeks.contains(week)) {
    streak++;
    week = DateTime(week.year, week.month, week.day - 7);
  }
  return streak;
}

/// Workouts started in the calendar month of [today].
int workoutsThisMonth(Iterable<WorkoutSession> workouts, DateTime today) =>
    workouts
        .where(
          (w) => w.start.year == today.year && w.start.month == today.month,
        )
        .length;

/// Chart time ranges.
enum ProgressRange {
  month('1M', 1),
  quarter('3M', 3),
  year('1Y', 12),
  all('All', null);

  const ProgressRange(this.label, this.months);

  final String label;
  final int? months;

  /// First day shown, or null for everything.
  DateTime? from(DateTime today) => switch (months) {
    final m? => _monthsBefore(today, m),
    null => null,
  };

  List<DatedValue> clip(List<DatedValue> points, DateTime today) {
    final start = from(today);
    return start == null
        ? points
        : points.where((p) => !p.date.isBefore(start)).toList();
  }
}

/// What the exercise progress chart shows.
enum ExerciseMetric {
  oneRepMax('Est. 1RM'),
  heaviest('Heaviest'),
  volume('Volume');

  const ExerciseMetric(this.label);

  final String label;
}

/// One point per session for [exerciseId], oldest first.
List<DatedValue> exerciseSeries(
  Iterable<WorkoutSession> workouts,
  String exerciseId,
  ExerciseMetric metric,
) {
  if (metric == ExerciseMetric.oneRepMax) {
    return oneRepMaxSeries(workouts, exerciseId);
  }
  final id = ExerciseCatalog.canonical(exerciseId);
  final out = <DatedValue>[];
  for (final w in workouts) {
    double? value;
    for (final e in w.exercises) {
      if (ExerciseCatalog.canonical(e.exerciseId) != id) continue;
      for (final s in e.sets) {
        if (!s.done || !s.type.counts || s.weightKg <= 0) continue;
        value = metric == ExerciseMetric.heaviest
            ? max(value ?? 0, s.weightKg)
            : (value ?? 0) + s.weightKg * s.reps;
      }
    }
    if (value != null) out.add((date: w.start, value: value));
  }
  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}

/// Change in a daily series over the last [days] days: the latest value
/// minus the latest one on or before the start. Null without both.
double? changeOver(List<DatedValue> points, DateTime today, {int days = 30}) {
  if (points.isEmpty) return null;
  final start = DateTime(today.year, today.month, today.day - days);
  final before = points.where((p) => !_day(p.date).isAfter(start)).lastOrNull;
  // Without data that old, compare with the first reading in the window.
  final base = before ?? (points.length > 1 ? points.first : null);
  if (base == null || identical(base, points.last)) return null;
  return points.last.value - base.value;
}

/// The same kind of workout done most recently before [session].
WorkoutSession? previousOfType(
  Iterable<WorkoutSession> workouts,
  WorkoutSession session,
) {
  WorkoutSession? best;
  for (final w in workouts) {
    if (w.id == session.id || w.type != session.type) continue;
    if (!w.start.isBefore(session.start)) continue;
    if (best == null || w.start.isAfter(best.start)) best = w;
  }
  return best;
}

/// Best estimated one-rep max per exercise in one session.
Map<String, double> sessionBests(WorkoutSession s) {
  final out = <String, double>{};
  for (final e in s.exercises) {
    final id = ExerciseCatalog.canonical(e.exerciseId);
    for (final set in e.sets) {
      if (!set.done || !set.type.counts || set.weightKg <= 0) continue;
      final v = epley(set.weightKg, set.reps);
      if (v > (out[id] ?? 0)) out[id] = v;
    }
  }
  return out;
}

/// Exercises in [session] whose best set beat every earlier session.
Set<String> sessionRecords(
  Iterable<WorkoutSession> workouts,
  WorkoutSession session,
) {
  final mine = sessionBests(session);
  if (mine.isEmpty) return const {};
  final before = <String, double>{};
  for (final w in workouts) {
    if (w.id == session.id || !w.start.isBefore(session.start)) continue;
    for (final MapEntry(:key, :value) in sessionBests(w).entries) {
      if (value > (before[key] ?? 0)) before[key] = value;
    }
  }
  return {
    for (final MapEntry(:key, :value) in mine.entries)
      // A first-ever attempt isn't a record yet.
      if (before[key] case final b? when value > b + 0.01) key,
  };
}

/// The same day [months] months before [day], or the month's last day if
/// it's shorter (31 March minus a month is 28 or 29 February, not 3 March).
DateTime _monthsBefore(DateTime day, int months) {
  final lastDay = DateTime(day.year, day.month - months + 1, 0).day;
  return DateTime(
    day.year,
    day.month - months,
    day.day > lastDay ? lastDay : day.day,
  );
}
