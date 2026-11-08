import 'package:health_app/models/activity_level.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/user_profile.dart';

/// The daily targets a goal preset sets.
typedef DailyTargets = ({
  double activeEnergy,
  double exerciseMinutes,
  double steps,
  double water,
});

/// The metrics a [DailyTargets] covers, in the order they're shown.
const dailyTargetMetrics = [
  MetricType.activeEnergy,
  MetricType.exerciseMinutes,
  MetricType.steps,
  MetricType.water,
];

double targetFor(DailyTargets t, MetricType type) => switch (type) {
  MetricType.activeEnergy => t.activeEnergy,
  MetricType.exerciseMinutes => t.exerciseMinutes,
  MetricType.steps => t.steps,
  MetricType.water => t.water,
  _ => 0,
};

DailyTargets withTarget(DailyTargets t, MetricType type, double value) => (
  activeEnergy: type == MetricType.activeEnergy ? value : t.activeEnergy,
  exerciseMinutes: type == MetricType.exerciseMinutes
      ? value
      : t.exerciseMinutes,
  steps: type == MetricType.steps ? value : t.steps,
  water: type == MetricType.water ? value : t.water,
);

DailyTargets targetsOf(Goals goals) => (
  activeEnergy: goals.activeEnergy,
  exerciseMinutes: goals.exerciseMinutes,
  steps: goals.steps,
  water: goals.water,
);

/// Daily targets that suit someone at [level]: steps follow the
/// Tudor-Locke bands, exercise starts at the WHO's 150 minutes a week.
DailyTargets targetsForLevel(ActivityLevel level) => switch (level) {
  ActivityLevel.sedentary => (
    activeEnergy: 300,
    exerciseMinutes: 20,
    steps: 6000,
    water: 2000,
  ),
  ActivityLevel.low => (
    activeEnergy: 400,
    exerciseMinutes: 30,
    steps: 7500,
    water: 2000,
  ),
  ActivityLevel.moderate => (
    activeEnergy: 500,
    exerciseMinutes: 30,
    steps: 9000,
    water: 2500,
  ),
  ActivityLevel.active => (
    activeEnergy: 650,
    exerciseMinutes: 45,
    steps: 10000,
    water: 2500,
  ),
  ActivityLevel.veryActive => (
    activeEnergy: 800,
    exerciseMinutes: 60,
    steps: 12000,
    water: 3000,
  ),
};

/// Kinds of daily goal preset offered in setup.
enum GoalPresetKind { recommended, current, easier, harder, custom }

/// A named set of daily targets to pick from.
class GoalPreset {
  const GoalPreset({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.targets,
  });

  final GoalPresetKind kind;
  final String title;
  final String subtitle;
  final DailyTargets targets;
}

/// The presets to offer: recommended for the user's [level] (moderately
/// active when unknown), their [current] goals when they differ, a gentler
/// and a harder level, and custom (starting from the current goals).
List<GoalPreset> goalPresets({
  required ActivityLevel? level,
  required DailyTargets current,
}) {
  final base = level ?? ActivityLevel.moderate;
  final levels = ActivityLevel.values;
  final recommended = targetsForLevel(base);
  final easier = base.index > 0 ? levels[base.index - 1] : null;
  final harder = base.index < levels.length - 1 ? levels[base.index + 1] : null;
  return [
    GoalPreset(
      kind: GoalPresetKind.recommended,
      title: 'Recommended',
      subtitle: level == null
          ? 'A balanced start for most people'
          : 'Suits someone ${base.label.toLowerCase()}',
      targets: recommended,
    ),
    if (current != recommended)
      GoalPreset(
        kind: GoalPresetKind.current,
        title: 'Keep Current Goals',
        subtitle: 'The goals you have now',
        targets: current,
      ),
    if (easier != null)
      GoalPreset(
        kind: GoalPresetKind.easier,
        title: 'Easy Start',
        subtitle: 'Lighter targets to build the habit',
        targets: targetsForLevel(easier),
      ),
    if (harder != null)
      GoalPreset(
        kind: GoalPresetKind.harder,
        title: 'Push Harder',
        subtitle: 'For when you want more of a challenge',
        targets: targetsForLevel(harder),
      ),
    GoalPreset(
      kind: GoalPresetKind.custom,
      title: 'Custom',
      subtitle: 'Set each target yourself',
      targets: current,
    ),
  ];
}
