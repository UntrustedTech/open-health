import 'dart:math' as math;

import 'package:health_app/models/body_goal.dart';
import 'package:health_app/insights/health_snapshot.dart';
import 'package:health_app/models/cycle.dart' as cycle show daysBetween;

/// Smooths weigh-ins into a trend: an exponential moving average that
/// moves 10% of the way toward each day's weight (as in The Hacker's
/// Diet), so water and salt swings don't hide the real direction. Gaps
/// between weigh-ins count as that many days. Points must be in date
/// order; the result has one value per point.
List<double> smoothWeights(List<(DateTime, double)> points) {
  if (points.isEmpty) return const [];
  final out = <double>[points.first.$2];
  for (var i = 1; i < points.length; i++) {
    final days = math.max(
      1,
      points[i].$1.difference(points[i - 1].$1).inHours / 24,
    );
    final keep = math.pow(1 - WeeklyCheckIn.dailyWeight, days).toDouble();
    out.add(out.last * keep + points[i].$2 * (1 - keep));
  }
  return out;
}

/// The trend (from all of [weighIns], oldest first) as it stood at the
/// end of each day in [days]; days before the first weigh-in take the
/// first weight.
List<double> trendOn(List<(DateTime, double)> weighIns, List<DateTime> days) {
  if (weighIns.isEmpty) return const [];
  final smooth = smoothWeights(weighIns);
  var i = -1;
  return [
    for (final d in days)
      () {
        final end = DateTime(d.year, d.month, d.day + 1);
        while (i + 1 < weighIns.length && weighIns[i + 1].$1.isBefore(end)) {
          i++;
        }
        return i < 0 ? weighIns.first.$2 : smooth[i];
      }(),
  ];
}

/// How the last week went against the plan.
enum CheckInStatus {
  /// Within a small margin of the planned pace.
  onTrack,

  /// Changing in the right direction but slower than planned.
  slower,

  /// Changing faster than planned.
  faster,

  /// Moving away from the goal.
  wrongWay,
}

/// A week's check-in: planned against actual pace, and a calorie goal
/// that would close the gap.
class CheckInResult {
  const CheckInResult({
    required this.plannedKgPerWeek,
    required this.actualKgPerWeek,
    required this.status,
    required this.suggestedKcal,
  });

  /// Negative to lose, positive to gain, 0 to hold steady.
  final double plannedKgPerWeek;
  final double actualKgPerWeek;
  final CheckInStatus status;

  /// A new daily calorie goal, or null when the current one is fine.
  final double? suggestedKcal;
}

/// Once a week, compares the weight trend with the goal's pace and
/// suggests a small calorie change when they've drifted apart.
abstract final class WeeklyCheckIn {
  /// Share of each day's weight the trend takes in.
  static const dailyWeight = 0.1;

  /// Days between check-ins.
  static const everyDays = 7;

  /// Pace differences smaller than this (kg a week) count as on track.
  static const tolerance = 0.15;

  /// Largest change suggested at once, kcal a day.
  static const maxStep = 250.0;

  /// Whether a check-in is due: a week after the goal started or the last
  /// check-in. Goals without a weight target ("Get Fitter") have none.
  static bool isDue(BodyGoal goal, DateTime today) {
    if (goal.objective == GoalObjective.fitness) return false;
    final from = goal.checkedIn ?? goal.startDate;
    if (from == null) return false;
    return daysBetween(from, today) >= everyDays;
  }

  /// Whole calendar days from [a] to [b], ignoring times and DST.
  static int daysBetween(DateTime a, DateTime b) => cycle.daysBetween(a, b);

  /// Answered within the last [everyDays].
  static bool answered(BodyGoal goal, DateTime today) {
    final c = goal.checkedIn;
    return c != null && daysBetween(c, today) < everyDays;
  }

  /// The check-in for [weighIns], or null without enough of them for a
  /// trend. [currentKcal] is today's food goal; [floorKcal] the lowest
  /// goal ever suggested.
  static CheckInResult? evaluate({
    required BodyGoal goal,
    required Iterable<(DateTime, double)> weighIns,
    required DateTime today,
    required double currentKcal,
    required double floorKcal,
  }) {
    if (goal.objective == GoalObjective.fitness) return null;
    // Only this goal's weigh-ins; after a check-in, the last two weeks, so
    // a calorie change shows up quickly.
    final start = goal.startDate;
    final checked = goal.checkedIn?.subtract(const Duration(days: everyDays));
    final from = start == null
        ? checked
        : checked == null || checked.isBefore(start)
        ? start
        : checked;
    final fromDay = from == null
        ? null
        : DateTime(from.year, from.month, from.day);
    weighIns = [
      for (final w in weighIns)
        if (fromDay == null || !w.$1.isBefore(fromDay)) w,
    ];
    final actual = WeightProgress.weeklyTrend(weighIns, today);
    if (actual == null) return null;
    final latest = weighIns.isEmpty ? null : weighIns.last.$2;
    final planned = switch (goal.objective) {
      GoalObjective.lose => -goal.safeRate(latest),
      GoalObjective.gain => goal.safeRate(latest),
      _ => 0.0,
    };
    final diff = actual - planned;
    final CheckInStatus status;
    if (diff.abs() <= tolerance) {
      status = CheckInStatus.onTrack;
    } else if (actual * planned <= 0) {
      // Includes holding steady (planned 0) and drifting.
      status = CheckInStatus.wrongWay;
    } else if (actual.abs() < planned.abs()) {
      status = CheckInStatus.slower;
    } else {
      status = CheckInStatus.faster;
    }
    double? suggested;
    if (status != CheckInStatus.onTrack) {
      // Each kg a week is about 1,100 kcal a day.
      final change = (-diff * BodyGoal.kcalPerKg / 7).clamp(-maxStep, maxStep);
      final next = (((currentKcal + change) / 10).round() * 10).toDouble();
      // The floor only limits cuts; it never turns a cut into a raise.
      final floored = change < 0 ? math.max(next, floorKcal) : next;
      final cutBlocked = change < 0 && floored >= currentKcal;
      if (!cutBlocked && (floored - currentKcal).abs() >= 10) {
        suggested = floored;
      }
    }
    return CheckInResult(
      plannedKgPerWeek: planned,
      actualKgPerWeek: actual,
      status: status,
      suggestedKcal: suggested,
    );
  }
}
