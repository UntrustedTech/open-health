import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/insights/health_snapshot.dart';
import 'package:health_app/models/body_goal.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/screens/goal/body_goal_editor.dart';
import 'package:health_app/screens/goal/body_goal_screen.dart';
import 'package:health_app/screens/metric_detail_screen.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';

/// Progress toward the user's goal: weight toward the target with the
/// trend and an expected date, or this week's activity for fitness goals.
class GoalCard extends StatelessWidget {
  const GoalCard({super.key});

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthStore>();
    final goal = health.bodyGoal;
    final color = goalColor(goal.objective);
    if (goal.startDate == null) return _SetGoal(color: color);
    final body = goal.objective == GoalObjective.fitness
        ? const _FitnessGoal()
        : _WeightGoal(goal: goal);
    return IosCard(
      onTap: () => BodyGoalScreen.open(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(icon: goal.objective.icon, color: color, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(goal.objective.label, style: context.headline),
              ),
              Text('YOUR GOAL', style: context.overline),
            ],
          ),
          const SizedBox(height: 14),
          body,
        ],
      ),
    );
  }
}

class _SetGoal extends StatelessWidget {
  const _SetGoal({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => IosCard(
    onTap: () => BodyGoalScreen.open(context),
    child: Row(
      children: [
        IconTile(icon: Icons.flag_rounded, color: color, size: 40),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Set Your Goal', style: context.headline),
              Text(
                'Lose, keep or gain weight, or get fitter. Your calorie goal '
                'and Summary follow from it.',
                style: context.footnote.copyWith(color: context.secondaryLabel),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: context.tertiaryLabel),
      ],
    ),
  );
}

class _WeightGoal extends StatelessWidget {
  const _WeightGoal({required this.goal});

  final BodyGoal goal;

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthStore>();
    final latest = health.latestReading(MetricType.weight)?.value;
    final target = goal.objective.changesWeight ? health.goals.weightKg : null;
    final start = health.goalStartKg ?? latest;
    final trend = WeightProgress.weeklyTrend([
      for (final e in health.entriesFor(MetricType.weight)) (e.date, e.value),
    ], health.today);
    final color = context.resolve(goalColor(goal.objective));
    if (latest == null) {
      return _Hint(
        'Log your weight to follow your progress.',
        onTap: () => MetricDetailScreen.open(context, MetricType.weight),
      );
    }
    final lines = <String>[];
    final losing = goal.objective == GoalObjective.lose;
    final wrongSide =
        target != null &&
        start != null &&
        (losing ? target >= start : target <= start);
    if (wrongSide) {
      lines.add(
        'Your target is ${losing ? 'above' : 'below'} where you started. '
        'Tap to update it.',
      );
    } else if (target != null && start != null) {
      final left = (target - latest).abs();
      final reached = losing ? latest <= target : latest >= target;
      if (reached) {
        lines.add('Target reached.');
      } else {
        lines.add('${Units.weight(left)} to go');
        final rightWay = trend != null && (losing ? trend < 0 : trend > 0);
        if (rightWay && trend.abs() >= 0.05) {
          final weeks = (left / trend.abs()).ceil();
          // Beyond a year a date says little; show one only when near.
          if (weeks <= 52) {
            final day = health.today.add(Duration(days: weeks * 7));
            final fmt = weeks > 26 ? DateFormat.yMMMd() : DateFormat.MMMd();
            lines.add('On track for ${fmt.format(day)}');
          }
        }
      }
    } else if (start != null) {
      final change = latest - start;
      lines.add(
        change.abs() < 1
            ? 'Within ${Units.weight(1)} of where you started'
            : '${change > 0 ? '+' : '−'}${Units.weight(change.abs())} since '
                  '${DateFormat.MMMd().format(goal.startDate!)}',
      );
    }
    if (trend != null) {
      lines.add(
        'Trend ${trend >= 0 ? '+' : '−'}'
        '${Units.weight(trend.abs(), decimals: 2)} a week',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Units.weight(latest),
              style: context.number(32, weight: FontWeight.w700),
            ),
            if (target != null) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '→ ${Units.weight(target)}',
                  style: context.subheadline.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (target != null && start != null) ...[
          const SizedBox(height: 10),
          CapsuleProgress(
            value: WeightProgress.fraction(start, latest, target),
            color: color,
          ),
        ],
        const SizedBox(height: 8),
        Text(
          lines.join(' · '),
          style: context.footnote.copyWith(color: context.secondaryLabel),
        ),
      ],
    );
  }
}

class _FitnessGoal extends StatelessWidget {
  const _FitnessGoal();

  @override
  Widget build(BuildContext context) {
    final workouts = context.watch<WorkoutStore>();
    final week = workouts.thisWeek;
    final goal = workouts.settings.weeklyGoalMinutes;
    final color = context.resolve(Palette.violet);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${week.minutes}',
              style: context.number(32, weight: FontWeight.w700),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 5),
              child: Text(
                goal > 0 ? 'of $goal min this week' : 'min this week',
                style: context.subheadline.copyWith(
                  color: context.secondaryLabel,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (goal > 0) ...[
          const SizedBox(height: 10),
          CapsuleProgress(value: week.minutes / goal, color: color),
        ],
        const SizedBox(height: 8),
        Text(
          '${week.count} ${week.count == 1 ? 'workout' : 'workouts'} · '
          '${workouts.streak}-day streak',
          style: context.footnote.copyWith(color: context.secondaryLabel),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text, {required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: text,
    child: Text(text, style: context.subheadline.copyWith(color: context.tint)),
  );
}

/// Key numbers of the last week against general guidelines.
class HealthSnapshotCard extends StatelessWidget {
  const HealthSnapshotCard({super.key});

  static Color _color(Standing s) => switch (s) {
    Standing.good => Palette.green,
    Standing.fair => Palette.yellow,
    Standing.attention => Palette.orange,
    Standing.info => Palette.grey,
  };

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthStore>();
    final stats = HealthSnapshot.build(
      dailyValue: health.dailyValue,
      today: health.today,
      weightKg: health.latestReading(MetricType.weight)?.value,
      heightCm: health.profile.heightCm,
      age: health.profile.ageOn(health.today),
    );
    if (stats.isEmpty) return const SizedBox.shrink();
    final good = stats.where((s) => s.standing == Standing.good).length;
    return IosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(
                icon: Icons.health_and_safety_rounded,
                color: context.resolve(Palette.green),
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text('Health Snapshot', style: context.headline),
                    ),
                    Text(
                      '$good of ${stats.length} in a healthy range',
                      style: context.footnote.copyWith(
                        color: context.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final w = (c.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final s in stats)
                    SizedBox(
                      width: w,
                      child: _StatTile(stat: s, color: _color(s.standing)),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            'Last 7 days against WHO, CDC and AHA guidelines. A general '
            'guide, not medical advice.',
            style: context.caption1.copyWith(color: context.tertiaryLabel),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat, required this.color});

  final SnapshotStat stat;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.resolve(color);
    final value = stat.title == 'Steps'
        ? NumberFormat.decimalPattern().format(int.parse(stat.value))
        : stat.value;
    return Pressable(
      semanticLabel:
          '${stat.title}: $value ${stat.unit}, ${stat.standing.label}. '
          '${stat.note}',
      onTap: () => MetricDetailScreen.open(context, stat.metric),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: ShapeDecoration(
          // Neutral tile; the dot and the word say how it stands.
          color: context.cardRaised,
          shape: AppTheme.squircle(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    stat.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.caption1.copyWith(
                      color: context.secondaryLabel,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: context.number(20, weight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: ' ${stat.unit}',
                    style: context.caption1.copyWith(
                      color: context.secondaryLabel,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            if (stat.standing != Standing.info)
              Text(
                stat.standing.label,
                maxLines: 1,
                style: context.caption1.copyWith(
                  color: stat.standing == Standing.good
                      ? c
                      : context.labelColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            Text(
              stat.note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.caption2.copyWith(color: context.secondaryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
