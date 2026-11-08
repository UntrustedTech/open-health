import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Icons;

import 'package:health_app/models/activity_level.dart';

/// What the user wants from Health overall.
enum GoalObjective {
  lose(
    'Lose Weight',
    'Eat a little less than you burn',
    Icons.trending_down_rounded,
  ),
  maintain('Stay Healthy', 'Keep your weight steady', Icons.balance_rounded),
  gain(
    'Gain Weight',
    'Build muscle with a small surplus',
    Icons.trending_up_rounded,
  ),
  fitness('Get Fitter', 'Move more and build stamina', Icons.bolt_rounded);

  const GoalObjective(this.label, this.detail, this.icon);

  final String label;
  final String detail;
  final IconData icon;

  /// Whether the goal changes body weight (and so has a target and pace).
  bool get changesWeight => this == lose || this == gain;

  static GoalObjective fromName(Object? name) => values.firstWhere(
    (o) => o.name == name,
    orElse: () => GoalObjective.maintain,
  );
}

/// The user's overall goal: what they want, how fast, and where they
/// started. The target weight itself lives in `Goals.weightKg`.
@immutable
class BodyGoal {
  const BodyGoal({
    this.objective = GoalObjective.maintain,
    this.weeklyRateKg = 0.5,
    this.startKg,
    this.startDate,
    this.activity,
    this.checkedIn,
  });

  /// Paces offered for [objective], in kg a week. Gaining is slower: a
  /// small surplus keeps the gain mostly muscle.
  static List<double> ratesFor(GoalObjective objective) =>
      objective == GoalObjective.gain
      ? const [0.1, 0.25, 0.5]
      : const [0.25, 0.5, 0.75];

  /// Fastest pace advised, as a share of body weight a week.
  static const maxWeeklyShare = 0.01;

  /// [weeklyRateKg], capped at [maxWeeklyShare] of [weightKg].
  double safeRate(double? weightKg) {
    if (weightKg == null) return weeklyRateKg;
    final cap = weightKg * maxWeeklyShare;
    return weeklyRateKg > cap ? cap : weeklyRateKg;
  }

  /// Energy in a kilogram of body fat (kcal).
  static const kcalPerKg = 7700.0;

  final GoalObjective objective;
  final double weeklyRateKg;

  /// Weight when the goal was set, for progress.
  final double? startKg;
  final DateTime? startDate;

  /// How active the user says they are; null to work it out from their
  /// steps.
  final ActivityLevel? activity;

  /// The last weekly check-in.
  final DateTime? checkedIn;

  /// Daily calorie change for the goal: a deficit to lose, a surplus to
  /// gain, nothing otherwise.
  double get dailyKcalChange => dailyKcalChangeFor(null);

  /// The daily change with the pace capped for someone of [weightKg].
  double dailyKcalChangeFor(double? weightKg) => switch (objective) {
    GoalObjective.lose => -safeRate(weightKg) * kcalPerKg / 7,
    GoalObjective.gain => safeRate(weightKg) * kcalPerKg / 7,
    _ => 0,
  };

  BodyGoal copyWith({
    GoalObjective? objective,
    double? weeklyRateKg,
    double? startKg,
    DateTime? startDate,
    ActivityLevel? activity,
    bool autoActivity = false,
    DateTime? checkedIn,
  }) => BodyGoal(
    objective: objective ?? this.objective,
    weeklyRateKg: weeklyRateKg ?? this.weeklyRateKg,
    startKg: startKg ?? this.startKg,
    startDate: startDate ?? this.startDate,
    activity: autoActivity ? null : activity ?? this.activity,
    checkedIn: checkedIn ?? this.checkedIn,
  );

  Map<String, Object?> toJson() => {
    'objective': objective.name,
    'rate': weeklyRateKg,
    'startKg': ?startKg,
    'startDate': ?startDate?.toIso8601String(),
    'activity': ?activity?.name,
    'checkedIn': ?checkedIn?.toIso8601String(),
  };

  factory BodyGoal.fromJson(Map<String, Object?> json) {
    final rate = json['rate'];
    final start = json['startKg'];
    return BodyGoal(
      objective: GoalObjective.fromName(json['objective']),
      weeklyRateKg: rate is num && rate >= 0.1 && rate <= 1.0
          ? rate.toDouble()
          : 0.5,
      startKg: start is num && start >= 2 && start <= 635
          ? start.toDouble()
          : null,
      startDate: DateTime.tryParse('${json['startDate']}'),
      activity: ActivityLevel.fromName(json['activity']),
      checkedIn: DateTime.tryParse('${json['checkedIn']}'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BodyGoal &&
      other.objective == objective &&
      other.weeklyRateKg == weeklyRateKg &&
      other.startKg == startKg &&
      other.startDate == startDate &&
      other.activity == activity &&
      other.checkedIn == checkedIn;

  @override
  int get hashCode => Object.hash(
    objective,
    weeklyRateKg,
    startKg,
    startDate,
    activity,
    checkedIn,
  );
}
