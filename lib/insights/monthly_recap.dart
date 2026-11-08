import 'package:flutter/foundation.dart';

import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/workout.dart';

DateTime _localDay(DateTime t) {
  final local = t.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// A month in numbers, for the "Your October" recap.
@immutable
class MonthlyRecap {
  const MonthlyRecap({
    required this.month,
    required this.days,
    required this.steps,
    required this.activeKcal,
    required this.exerciseMinutes,
    required this.workouts,
    required this.workoutMinutes,
    required this.distanceKm,
    required this.bestStepDay,
    required this.bestSteps,
    required this.ringDays,
    required this.weightChangeKg,
    required this.averageSleep,
    required this.averageRestingHeart,
    required this.topWorkout,
    required this.activeDays,
  });

  /// The first day of the month.
  final DateTime month;

  /// Days counted (the whole month, or up to today for this month).
  final int days;
  final double steps;
  final double activeKcal;
  final double exerciseMinutes;
  final int workouts;
  final int workoutMinutes;
  final double distanceKm;
  final DateTime? bestStepDay;
  final double bestSteps;

  /// Days every activity goal was met.
  final int ringDays;

  /// Last weigh-in minus first, when there were two or more.
  final double? weightChangeKg;
  final double? averageSleep;
  final double? averageRestingHeart;

  /// The most-done workout type.
  final WorkoutType? topWorkout;

  /// Days with a workout or the exercise goal met.
  final int activeDays;

  bool get isEmpty => steps == 0 && workouts == 0 && averageSleep == null;

  /// Builds the recap for the month containing [month], counting days up
  /// to [today] for the current month.
  static MonthlyRecap build({
    required DateTime month,
    required DateTime today,
    required double? Function(MetricType type, DateTime day) dailyValue,
    required double? Function(MetricType type) goalFor,
    required Iterable<WorkoutSession> sessions,
  }) {
    final first = DateTime(month.year, month.month);
    final next = DateTime(month.year, month.month + 1);
    final last = next.isAfter(today)
        ? today
        : DateTime(next.year, next.month, next.day - 1);
    final dayList = [
      for (
        var d = first;
        !d.isAfter(last);
        d = DateTime(d.year, d.month, d.day + 1)
      )
        d,
    ];
    double sum(MetricType t) =>
        dayList.fold(0, (s, d) => s + (dailyValue(t, d) ?? 0));
    double? avg(MetricType t) {
      final v = [for (final d in dayList) ?dailyValue(t, d)];
      return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
    }

    DateTime? bestDay;
    var bestSteps = 0.0;
    var ringDays = 0;
    final rings = [
      MetricType.activeEnergy,
      MetricType.exerciseMinutes,
      MetricType.steps,
    ];
    for (final d in dayList) {
      final s = dailyValue(MetricType.steps, d) ?? 0;
      if (s > bestSteps) {
        bestSteps = s;
        bestDay = d;
      }
      final all = rings.every((t) {
        final goal = goalFor(t);
        return goal != null && goal > 0 && (dailyValue(t, d) ?? 0) >= goal;
      });
      if (all) ringDays++;
    }

    final weights = [
      for (final d in dayList) ?dailyValue(MetricType.weight, d),
    ];
    final inMonth = sessions.where((w) {
      final s = w.start.toLocal();
      return !s.isBefore(first) && s.isBefore(next);
    }).toList();
    final byType = <WorkoutType, int>{};
    for (final w in inMonth) {
      byType[w.type] = (byType[w.type] ?? 0) + 1;
    }
    final workoutDays = {for (final w in inMonth) _localDay(w.start)};
    final exerciseGoal = goalFor(MetricType.exerciseMinutes);
    final activeDays = {
      ...workoutDays,
      for (final d in dayList)
        if (exerciseGoal != null &&
            exerciseGoal > 0 &&
            (dailyValue(MetricType.exerciseMinutes, d) ?? 0) >= exerciseGoal)
          d,
    }.length;

    return MonthlyRecap(
      month: first,
      days: dayList.length,
      steps: sum(MetricType.steps),
      activeKcal: sum(MetricType.activeEnergy),
      exerciseMinutes: sum(MetricType.exerciseMinutes),
      workouts: inMonth.length,
      workoutMinutes: inMonth.fold(0, (m, w) => m + w.activeSeconds ~/ 60),
      distanceKm: inMonth.fold(0.0, (m, w) => m + w.distanceMeters / 1000),
      bestStepDay: bestDay,
      bestSteps: bestSteps,
      ringDays: ringDays,
      weightChangeKg: weights.length >= 2 ? weights.last - weights.first : null,
      averageSleep: avg(MetricType.sleep),
      averageRestingHeart: avg(MetricType.restingHeartRate),
      topWorkout: byType.isEmpty
          ? null
          : byType.entries.reduce((a, b) => b.value > a.value ? b : a).key,
      activeDays: activeDays,
    );
  }
}
