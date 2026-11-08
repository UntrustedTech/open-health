import 'package:flutter/foundation.dart';

import 'package:health_app/utils/units.dart';
import 'package:health_app/utils/format.dart';

enum GoalKind { open, time, distance, calories }

/// Optional target for a live workout.
@immutable
class WorkoutGoal {
  const WorkoutGoal(this.kind, [this.target = 0]);

  static const open = WorkoutGoal(GoalKind.open);

  final GoalKind kind;

  /// Minutes, kilometres or kcal depending on [kind].
  final double target;

  /// Progress 0..1 given the current values, or null for open goals.
  double? progress({
    required Duration elapsed,
    required double meters,
    required double kcal,
  }) => switch (kind) {
    GoalKind.open => null,
    GoalKind.time => elapsed.inSeconds / (target * 60),
    GoalKind.distance => meters / (target * 1000),
    GoalKind.calories => kcal / target,
  };

  String get label => switch (kind) {
    GoalKind.open => 'Open Goal',
    GoalKind.time => formatMinutes(Duration(minutes: target.round())),
    GoalKind.distance => _distanceLabel(Units.distanceOut(target)),
    GoalKind.calories => '${target.round()} Cal',
  };
}

/// "5 km", "3.5 mi": whole numbers without decimals.
String _distanceLabel(double shown) {
  final rounded = (shown * 10).round() / 10;
  return '${rounded.toStringAsFixed(rounded % 1 == 0 ? 0 : 1)} '
      '${Units.distanceUnit}';
}
