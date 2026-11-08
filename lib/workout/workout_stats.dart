import 'dart:math';

import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/models/workout.dart';

typedef WeekSummary = ({
  int count,
  int minutes,
  double kilometres,
  double kcal,
});

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// First day of the week containing [day]; weeks start on [firstDay]
/// (a [DateTime.weekday], Monday by default).
DateTime weekStart(DateTime day, {int firstDay = DateTime.monday}) {
  final d = _day(day);
  final back = (d.weekday - firstDay) % 7;
  return DateTime(d.year, d.month, d.day - back);
}

/// Totals for the week containing [today], starting on [firstDay].
WeekSummary weekSummary(
  Iterable<WorkoutSession> workouts,
  DateTime today, {
  int firstDay = DateTime.monday,
}) {
  final from = weekStart(today, firstDay: firstDay);
  final to = DateTime(from.year, from.month, from.day + 7);
  var count = 0, seconds = 0;
  var meters = 0.0, kcal = 0.0;
  for (final w in workouts) {
    if (w.start.isBefore(from) || !w.start.isBefore(to)) continue;
    count++;
    seconds += w.activeSeconds;
    meters += w.distanceMeters;
    kcal += w.activeKcal;
  }
  return (
    count: count,
    minutes: seconds ~/ 60,
    kilometres: meters / 1000,
    kcal: kcal,
  );
}

/// Consecutive days with a workout, ending today (or yesterday, so the
/// streak isn't lost before today's workout).
int dayStreak(Iterable<WorkoutSession> workouts, DateTime today) {
  final days = {for (final w in workouts) _day(w.start)};
  var day = _day(today);
  if (!days.contains(day)) day = DateTime(day.year, day.month, day.day - 1);
  var streak = 0;
  while (days.contains(day)) {
    streak++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return streak;
}

typedef LiftRecord = ({
  double weightKg,
  int reps,
  double estimatedOneRepMax,
  DateTime date,
});

typedef PersonalRecords = ({
  int? fastestKmSeconds,
  int? fastest5kSeconds,
  double? longestRunMeters,
  double? longestRideMeters,
  int? longestWorkoutSeconds,
  double? biggestVolumeKg,
  Map<String, LiftRecord> bestLifts,
});

/// Estimated one-rep max by the Epley formula.
double epley(double weightKg, int reps) =>
    reps <= 1 ? weightKg : weightKg * (1 + reps / 30);

/// Best efforts across all workouts, derived on demand.
PersonalRecords personalRecords(Iterable<WorkoutSession> workouts) {
  int? fastestKm, fastest5k, longest;
  double? longestRun, longestRide, volume;
  final lifts = <String, LiftRecord>{};

  int? minOf(int? a, int? b) => a == null ? b : (b == null ? a : min(a, b));

  for (final w in workouts) {
    longest = max(longest ?? 0, w.activeSeconds);
    if (w.type == WorkoutType.run) {
      longestRun = max(longestRun ?? 0, w.distanceMeters);
      if (w.splits.isNotEmpty) {
        fastestKm = minOf(fastestKm, w.splits.reduce(min));
      }
      for (var i = 0; i + 5 <= w.splits.length; i++) {
        final five = w.splits.sublist(i, i + 5).reduce((a, b) => a + b);
        fastest5k = minOf(fastest5k, five);
      }
    }
    if (w.type == WorkoutType.cycle) {
      longestRide = max(longestRide ?? 0, w.distanceMeters);
    }
    if (w.volumeKg > 0) volume = max(volume ?? 0, w.volumeKg);
    for (final e in w.exercises) {
      for (final s in e.sets.where(
        (s) => s.done && s.weightKg > 0 && s.type.counts,
      )) {
        // Old and new ids for the same exercise share one record.
        final id = ExerciseCatalog.canonical(e.exerciseId);
        final best = lifts[id];
        final orm = epley(s.weightKg, s.reps);
        if (best == null || orm > best.estimatedOneRepMax) {
          lifts[id] = (
            weightKg: s.weightKg,
            reps: s.reps,
            estimatedOneRepMax: orm,
            date: w.start,
          );
        }
      }
    }
  }
  return (
    fastestKmSeconds: fastestKm,
    fastest5kSeconds: fastest5k,
    longestRunMeters: longestRun,
    longestRideMeters: longestRide,
    longestWorkoutSeconds: longest,
    biggestVolumeKg: volume,
    bestLifts: lifts,
  );
}

/// True if [set] beats the previous best for its exercise (a heavier weight
/// or a higher estimated one-rep max). The very first set of an exercise
/// isn't celebrated, and warm-ups never count.
bool isPersonalRecord(SetLog set, LiftRecord? best) {
  if (best == null || !set.done || !set.type.counts || set.weightKg <= 0) {
    return false;
  }
  return set.weightKg > best.weightKg ||
      epley(set.weightKg, set.reps) > best.estimatedOneRepMax + 0.01;
}
