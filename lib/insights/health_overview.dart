import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:health_app/models/body_goal.dart';
import 'package:health_app/models/cycle.dart' show daysBetween;
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/user_profile.dart';

/// The stretch of time the Summary looks back over.
enum SummaryPeriod {
  today('Today', 'day', 1),
  week('Week', 'week', 7),
  month('Month', 'month', 30),
  quarter('3 Months', 'few months', 91),
  year('Year', 'year', 365);

  const SummaryPeriod(this.label, this.noun, this.days);

  /// Short name for the period switch.
  final String label;

  /// The period in a sentence: "a good week", "a quiet few months".
  final String noun;

  /// Days covered, ending today.
  final int days;
}

/// One area of health on the Summary.
enum Pillar {
  activity('Activity'),
  sleep('Sleep'),
  heart('Heart'),
  nutrition('Nutrition'),
  body('Body');

  const Pillar(this.label);

  final String label;
}

/// A pillar's score (0–100) and the numbers behind it.
@immutable
class PillarResult {
  const PillarResult({
    required this.pillar,
    required this.score,
    required this.value,
    this.secondary,
    this.days = 1,
    this.spanDays,
  });

  final Pillar pillar;
  final int score;

  /// The main number: steps a day, hours of sleep, resting bpm, kcal a day,
  /// or weight change in kg.
  final double value;

  /// A second number: active kcal a day (activity), the kcal budget
  /// (nutrition), the latest weight in kg (body).
  final double? secondary;

  /// Days with data behind this result.
  final int days;

  /// For the body pillar: days between the first and last weigh-in.
  final int? spanDays;
}

/// How a metric moved against the period before.
@immutable
class Change {
  const Change({
    required this.type,
    required this.current,
    required this.previous,
  });

  final MetricType type;
  final double current;
  final double previous;

  double get fraction => previous == 0 ? 0 : (current - previous) / previous;

  /// Whether the change is good news (a lower resting heart rate is).
  bool get isGood => type == MetricType.restingHeartRate
      ? current < previous
      : current > previous;
}

/// The Summary's verdict for a period: an overall score, one per pillar,
/// a sentence about the user's goal and the biggest changes. A
/// motivational summary, not a medical one.
@immutable
class HealthOverview {
  const HealthOverview._({
    required this.period,
    required this.pillars,
    required this.objective,
    required this.changes,
  });

  final SummaryPeriod period;
  final GoalObjective objective;

  /// Pillars with enough data, in [Pillar] order.
  final List<PillarResult> pillars;

  /// The biggest changes against the period before, largest first.
  final List<Change> changes;

  bool get isEmpty => pillars.isEmpty;

  PillarResult? operator [](Pillar p) =>
      pillars.where((r) => r.pillar == p).firstOrNull;

  /// The pillars weighted by what matters most for [objective], 0–100.
  int? get score {
    if (pillars.isEmpty) return null;
    final weights = weightsFor(objective);
    var sum = 0.0, total = 0.0;
    for (final r in pillars) {
      final w = weights[r.pillar] ?? 0;
      sum += w * r.score;
      total += w;
    }
    return total == 0 ? null : (sum / total).round().clamp(0, 100);
  }

  String get rating => switch (score) {
    null => 'No Data Yet',
    >= 85 => 'Excellent',
    >= 70 => 'Good',
    >= 50 => 'Fair',
    _ => 'Needs Attention',
  };

  /// One or two sentences on how the period went for the user's goal.
  String get verdict {
    final score = this.score;
    if (score == null) {
      return 'Not enough data yet. Log a few days or connect your phone '
          'to see how you\'re doing.';
    }
    final when = period.noun;
    final body = this[Pillar.body]?.score;
    final activity = this[Pillar.activity]?.score;
    final lead = switch (objective) {
      GoalObjective.lose ||
      GoalObjective.gain when body != null => switch (body) {
        >= 75 => 'You\'re on track to ${_aim(objective)}.',
        >= 55 => 'Progress toward your goal is slow but steady.',
        _ => 'Your weight is moving the wrong way for your goal.',
      },
      GoalObjective.fitness when activity != null => switch (activity) {
        >= 80 => 'You\'re getting fitter: a very active $when.',
        >= 55 => 'A steadily active $when. Keep building.',
        _ => 'A quiet $when. More movement will help you get fitter.',
      },
      _ => switch (score) {
        >= 85 => 'A great, well-balanced $when.',
        >= 70 => 'A good $when overall.',
        >= 50 => 'A fair $when, with room to improve.',
        _ => 'A tough $when. Small steps will help.',
      },
    };
    final weakest = pillars.reduce((a, b) => b.score < a.score ? b : a);
    if (weakest.score >= 60 || pillars.length < 2) return lead;
    return '$lead ${_tip(weakest.pillar)}';
  }

  static String _aim(GoalObjective o) =>
      o == GoalObjective.lose ? 'lose weight' : 'gain weight';

  static String _tip(Pillar p) => switch (p) {
    Pillar.activity => 'More movement would lift your score most.',
    Pillar.sleep => 'More sleep would lift your score most.',
    Pillar.heart => 'Rest and lighter days can help your resting heart rate.',
    Pillar.nutrition => 'Eating closer to your calorie goal would help.',
    Pillar.body => 'Your weight trend needs the most attention.',
  };

  /// How much each pillar counts for [objective].
  static Map<Pillar, double> weightsFor(GoalObjective objective) =>
      switch (objective) {
        GoalObjective.lose || GoalObjective.gain => const {
          Pillar.activity: 0.25,
          Pillar.sleep: 0.2,
          Pillar.heart: 0.15,
          Pillar.nutrition: 0.2,
          Pillar.body: 0.2,
        },
        GoalObjective.fitness => const {
          Pillar.activity: 0.35,
          Pillar.sleep: 0.2,
          Pillar.heart: 0.25,
          Pillar.nutrition: 0.1,
          Pillar.body: 0.1,
        },
        GoalObjective.maintain => const {
          Pillar.activity: 0.25,
          Pillar.sleep: 0.25,
          Pillar.heart: 0.2,
          Pillar.nutrition: 0.15,
          Pillar.body: 0.15,
        },
      };

  /// Days the body pillar looks back over, at least, for a weight trend.
  static const minBodyDays = 14;

  /// The usual weekly pace for a weight goal when none is set, in kg.
  static const defaultWeeklyRateKg = 0.5;

  /// Builds the overview for [period] ending [today].
  ///
  /// [food] gives what was eaten and the budget on a day, or null when
  /// nothing was logged.
  static HealthOverview build({
    required SummaryPeriod period,
    required DateTime today,
    required double? Function(MetricType type, DateTime day) dailyValue,
    required Goals goals,
    required BodyGoal bodyGoal,
    required ({double eaten, double budget})? Function(DateTime day) food,
    DateTime? now,
  }) {
    final days = _days(today, period.days);
    final share = now == null ? 1.0 : dayShare(now);
    return HealthOverview._(
      period: period,
      objective: bodyGoal.objective,
      pillars: List.unmodifiable([
        ?_activity(days, today, share, dailyValue, goals),
        ?_sleep(days, dailyValue, goals),
        ?_heart(days, today, dailyValue),
        ?_nutrition(days, today, share, food, bodyGoal.objective),
        ?_body(today, period, dailyValue, bodyGoal),
      ]),
      changes: List.unmodifiable(_changes(today, period, dailyValue)),
    );
  }

  /// Waking hours, when activity is expected to happen.
  static const _wakeHour = 7, _wakingHours = 15;

  /// How much of the waking day has passed at [now], 0.2–1: today's
  /// goals are judged against this share, so a morning isn't a failure.
  static double dayShare(DateTime now) =>
      ((now.hour + now.minute / 60 - _wakeHour) / _wakingHours).clamp(0.2, 1);

  /// The [count] days ending [today], oldest first.
  static List<DateTime> _days(DateTime today, int count) => [
    for (var i = count - 1; i >= 0; i--)
      DateTime(today.year, today.month, today.day - i),
  ];

  static const _rings = [
    MetricType.activeEnergy,
    MetricType.exerciseMinutes,
    MetricType.steps,
  ];

  static PillarResult? _activity(
    List<DateTime> days,
    DateTime today,
    double share,
    double? Function(MetricType, DateTime) value,
    Goals goals,
  ) {
    if (!_rings.any((t) => (goals.forMetric(t) ?? 0) > 0)) return null;
    // Longer periods count finished days, so a morning doesn't pull the
    // average down; today counts alone only when it's all there is.
    bool active(DateTime d) => _rings.any((t) => (value(t, d) ?? 0) > 0);
    final finished = days.length == 1
        ? days
        : days.where((d) => d != today).toList();
    final pool = finished.any(active) ? finished : days;
    // Today is judged against the share of the day that has passed.
    double target(DateTime d) => d == today ? share : 1;
    // Counted from the first day with any activity, so a new user's empty
    // months don't drag the score down.
    final first = pool.indexWhere(active);
    if (first < 0) return null;
    final counted = pool.sublist(first);
    var progress = 0.0, steps = 0.0, kcal = 0.0;
    for (final d in counted) {
      final parts = [
        for (final t in _rings)
          if (goals.forMetric(t) case final g? when g > 0)
            ((value(t, d) ?? 0) / (g * target(d))).clamp(0.0, 1.0),
      ];
      if (parts.isNotEmpty) {
        progress += parts.reduce((a, b) => a + b) / parts.length;
      }
      steps += value(MetricType.steps, d) ?? 0;
      kcal += value(MetricType.activeEnergy, d) ?? 0;
    }
    final n = counted.length;
    return PillarResult(
      pillar: Pillar.activity,
      score: (progress / n * 100).round().clamp(0, 100),
      value: steps / n,
      secondary: kcal / n,
      days: n,
    );
  }

  static PillarResult? _sleep(
    List<DateTime> days,
    double? Function(MetricType, DateTime) value,
    Goals goals,
  ) {
    final nights = [
      for (final d in days)
        if (value(MetricType.sleep, d) case final h? when h > 0) h,
    ];
    if (nights.isEmpty) return null;
    final avg = nights.reduce((a, b) => a + b) / nights.length;
    final goal = goals.sleep > 0 ? goals.sleep : 8.0;
    // Short of the goal costs points; well over it costs a few too.
    final over = math.max(0.0, avg - goal - 1.5);
    final score = 100 * math.min(avg / goal, 1.0) - over * 10;
    return PillarResult(
      pillar: Pillar.sleep,
      score: score.round().clamp(0, 100),
      value: avg,
      days: nights.length,
    );
  }

  static PillarResult? _heart(
    List<DateTime> days,
    DateTime today,
    double? Function(MetricType, DateTime) value,
  ) {
    // Today looks back a few days, since resting heart rate comes in late.
    final range = days.length == 1 ? _days(today, 3) : days;
    final readings = [
      for (final d in range) ?value(MetricType.restingHeartRate, d),
    ];
    if (readings.isEmpty) return null;
    final avg = readings.reduce((a, b) => a + b) / readings.length;
    // Against the user's own baseline from the weeks before, when known.
    final baseLength = math.max(range.length, 14);
    final before = [
      for (var i = 1; i <= baseLength; i++)
        ?value(
          MetricType.restingHeartRate,
          DateTime(range.first.year, range.first.month, range.first.day - i),
        ),
    ];
    final double score;
    if (before.length >= 3) {
      final baseline = before.reduce((a, b) => a + b) / before.length;
      // Calm hearts score well; a drop below baseline adds a little.
      score = math.min(_absoluteHeart(avg) + (baseline - avg) * 4, 100);
    } else {
      score = _absoluteHeart(avg);
    }
    return PillarResult(
      pillar: Pillar.heart,
      score: score.round().clamp(0, 100),
      value: avg,
      days: readings.length,
    );
  }

  /// A score from typical adult resting heart rate bands.
  static double _absoluteHeart(double bpm) => switch (bpm) {
    < 60 => 92,
    < 70 => 85,
    < 80 => 72,
    < 90 => 55,
    _ => 40,
  };

  static PillarResult? _nutrition(
    List<DateTime> days,
    DateTime today,
    double share,
    ({double eaten, double budget})? Function(DateTime) food,
    GoalObjective objective,
  ) {
    final single = days.length == 1;
    // Today is still going, so longer periods count only finished days.
    final counted = single ? days : days.where((d) => d != today);
    var closeness = 0.0, eaten = 0.0, budget = 0.0;
    var n = 0;
    for (final d in counted) {
      final f = food(d);
      if (f == null || f.eaten <= 0 || f.budget <= 0) continue;
      n++;
      eaten += f.eaten;
      budget += f.budget;
      closeness += single && f.eaten <= f.budget && share < _eveningShare
          // Partway through today, under budget is on track.
          ? 1
          : _closeness(f.eaten, f.budget, objective);
    }
    if (n == 0) return null;
    return PillarResult(
      pillar: Pillar.nutrition,
      score: (closeness / n * 100).round().clamp(0, 100),
      value: eaten / n,
      secondary: budget / n,
      days: n,
    );
  }

  /// From this share of the day on, today's eating is judged as a whole.
  static const _eveningShare = 0.85;

  /// How close a day's eating was to its budget, 0–1. A little under
  /// suits losing weight; a little over suits gaining.
  static double _closeness(
    double eaten,
    double budget,
    GoalObjective objective,
  ) {
    final off = (eaten - budget) / budget;
    final allowance = switch (objective) {
      GoalObjective.lose when off < 0 => 0.15,
      GoalObjective.gain when off > 0 => 0.15,
      _ => 0.05,
    };
    final miss = math.max(0.0, off.abs() - allowance);
    return (1 - miss * 2).clamp(0.0, 1.0);
  }

  static PillarResult? _body(
    DateTime today,
    SummaryPeriod period,
    double? Function(MetricType, DateTime) value,
    BodyGoal goal,
  ) {
    final days = _days(today, math.max(period.days, minBodyDays));
    final weighIns = [
      for (final d in days)
        if (value(MetricType.weight, d) case final kg?) (d, kg),
    ];
    if (weighIns.length < 2) return null;
    final (firstDay, firstKg) = weighIns.first;
    final (lastDay, lastKg) = weighIns.last;
    final spanDays = daysBetween(firstDay, lastDay);
    // Under a week, water weight swamps any real trend.
    if (spanDays < minSpanDays) return null;
    final change = lastKg - firstKg;
    final weekly = change / spanDays * 7;
    final rate = goal.weeklyRateKg > 0
        ? goal.weeklyRateKg
        : defaultWeeklyRateKg;
    final double score = switch (goal.objective) {
      GoalObjective.lose => _towards(-weekly, rate),
      GoalObjective.gain => _towards(weekly, rate),
      // Staying steady is the aim: within a quarter kilo a week is ideal.
      GoalObjective.maintain || GoalObjective.fitness =>
        (95 - math.max(0.0, weekly.abs() - 0.25) * 80).clamp(30, 95),
    };
    return PillarResult(
      pillar: Pillar.body,
      score: score.round().clamp(0, 100),
      value: change,
      secondary: lastKg,
      days: weighIns.length,
      spanDays: spanDays,
    );
  }

  /// Shortest stretch between weigh-ins that counts as a trend.
  static const minSpanDays = 7;

  /// Weekly change, in kg, small enough to count as holding steady.
  static const steadyKg = 0.1;

  /// Scores moving [weekly] kg a week in the wanted direction against a
  /// planned [rate]: on pace scores 100, standing still 60, the wrong way
  /// lower.
  static double _towards(double weekly, double rate) => weekly >= -steadyKg
      ? 60 + 40 * math.min(math.max(weekly, 0) / rate, 1)
      : (55 - (-weekly - steadyKg) / rate * 25).clamp(10, 55);

  /// Metrics compared with the period before.
  static const compared = [
    MetricType.steps,
    MetricType.exerciseMinutes,
    MetricType.sleep,
    MetricType.restingHeartRate,
    MetricType.activeEnergy,
  ];

  /// Metrics complete by the morning, so today can be compared.
  static const _completeEarly = {MetricType.sleep, MetricType.restingHeartRate};

  /// Smallest change worth mentioning.
  static const minChange = 0.08;

  /// Fewest days with data on each side of a comparison.
  static const minCompareDays = 3;

  static List<Change> _changes(
    DateTime today,
    SummaryPeriod period,
    double? Function(MetricType, DateTime) value,
  ) {
    final n = period.days;
    final single = n == 1;
    // Longer periods compare finished days (ending yesterday) with the
    // same stretch before; today is compared with the week before it.
    final end = single
        ? today
        : DateTime(today.year, today.month, today.day - 1);
    final current = _days(end, n);
    final prevEnd = DateTime(end.year, end.month, end.day - n);
    final previous = _days(prevEnd, single ? 7 : n);
    double? avg(MetricType t, List<DateTime> days, int minDays) {
      final v = [
        for (final d in days)
          if (value(t, d) case final x? when x > 0) x,
      ];
      return v.length < minDays ? null : v.reduce((a, b) => a + b) / v.length;
    }

    final list = [
      for (final t in compared)
        if (!single || _completeEarly.contains(t))
          if ((
                avg(t, current, single ? 1 : minCompareDays),
                avg(t, previous, minCompareDays),
              )
              case (final c?, final p?))
            Change(type: t, current: c, previous: p),
    ]..removeWhere((c) => c.fraction.abs() < minChange);
    list.sort((a, b) => b.fraction.abs().compareTo(a.fraction.abs()));
    return list.take(3).toList();
  }
}
