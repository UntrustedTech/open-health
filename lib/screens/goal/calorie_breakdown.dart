import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;

import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/body_goal.dart';
import 'package:health_app/nutrition/calorie_estimate.dart';
import 'package:health_app/screens/food/food_cards.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/ios.dart';

/// How a suggested calorie goal is made up: resting energy, activity and
/// the goal's deficit or surplus. Without the details it needs, says
/// which are missing and offers to add them.
class CalorieBreakdown extends StatelessWidget {
  const CalorieBreakdown({
    super.key,
    required this.estimate,
    required this.goal,
    required this.missing,
    this.onAddDetails,
    this.footer,
  });

  final CalorieEstimate? estimate;
  final BodyGoal goal;
  final List<MissingDetail> missing;
  final VoidCallback? onAddDetails;

  /// Shown under the total, e.g. a "use as goal" button.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final e = estimate;
    if (e == null) return _missing(context);
    final orange = context.resolve(foodOrange);
    final activityLabel = e.countsExercise
        ? 'Digestion'
        : 'Activity · ${e.level?.label ?? ActivityLevel.low.label}';
    final activityNote = e.countsExercise
        ? 'Exercise is added each day as you move'
        : switch (e.source) {
            ActivitySource.measured => 'From your recent steps',
            ActivitySource.chosen => 'As you chose',
            ActivitySource.assumed => 'Assumed until there\'s step data',
          };
    final rate = Units.weight(goal.safeRate(e.weightKg), decimals: 2);
    final goalLabel = switch (goal.objective) {
      GoalObjective.lose => 'Lose $rate a week',
      GoalObjective.gain => 'Gain $rate a week',
      _ => goal.objective.label,
    };
    return IosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconTile(
                icon: Icons.local_fire_department_rounded,
                color: foodOrange,
                size: 34,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SUGGESTED DAILY GOAL',
                      style: context.caption2.copyWith(
                        color: context.secondaryLabel,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Text(
                      '${kcalText(e.target)} Cal',
                      style: context.title2.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Line(
            label: 'Resting Energy',
            note: 'Mifflin-St Jeor, from your age, height and weight',
            value: kcalText(e.bmr),
          ),
          _Line(
            label: activityLabel,
            note: activityNote,
            value: '+${kcalText(e.activityKcal)}',
          ),
          _Line(
            label: 'Goal · $goalLabel',
            note: goal.safeRate(e.weightKg) < goal.weeklyRateKg
                ? 'Capped at 1% of your weight a week'
                : goal.objective.detail,
            value: switch (e.goalChange.round()) {
              0 => '±0',
              final c when c < 0 => '−${kcalText(-c.toDouble())}',
              final c => '+${kcalText(c.toDouble())}',
            },
            color: e.goalChange == 0 ? null : orange,
          ),
          if (e.atFloor)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Raised to ${kcalText(e.target)} Cal, the lowest goal '
                'advised without a doctor.',
                style: context.footnote.copyWith(color: orange),
              ),
            ),
          ?footer,
        ],
      ),
    );
  }

  Widget _missing(BuildContext context) {
    final names = missing.map((m) => m.label.toLowerCase()).toList();
    final list = switch (names.length) {
      0 => 'a few details',
      1 => 'your ${names.first}',
      _ =>
        'your ${names.sublist(0, names.length - 1).join(', ')} and '
            '${names.last}',
    };
    final add = onAddDetails;
    return IosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconTile(
                icon: Icons.calculate_rounded,
                color: foodOrange,
                size: 34,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Get a Personal Calorie Goal',
                  style: context.headline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Add $list and Health works out how much you burn and what to '
            'eat for your goal. Until then, 2,000 Cal is used as a '
            'general guide.',
            style: context.subheadline.copyWith(color: context.secondaryLabel),
          ),
          if (add != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: CupertinoButton.filled(
                borderRadius: BorderRadius.circular(22),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                onPressed: add,
                child: const Text(
                  'Add Health Details',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.note,
    required this.value,
    this.color,
  });

  final String label;
  final String note;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.subheadline),
              Text(
                note,
                style: context.caption1.copyWith(color: context.secondaryLabel),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: context.subheadline.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

/// "How active are you?": automatic (from steps) or a chosen level.
class ActivityLevelSection extends StatelessWidget {
  const ActivityLevelSection({
    super.key,
    required this.value,
    required this.measured,
    required this.onChanged,
    this.exerciseCounted = false,
  });

  /// True when each day's measured exercise is added to the food budget,
  /// so the level here isn't used.
  final bool exerciseCounted;

  /// The chosen level; null for automatic.
  final ActivityLevel? value;

  /// The level from recent steps, if there's enough data.
  final ActivityLevel? measured;
  final ValueChanged<ActivityLevel?> onChanged;

  @override
  Widget build(BuildContext context) {
    final tint = context.tint;
    Widget check(bool on) => on
        ? Icon(Icons.check_rounded, color: tint, size: 22)
        : const SizedBox(width: 22);
    final m = measured;
    return GroupedSection(
      header: 'How Active Are You?',
      footer: exerciseCounted
          ? 'Not used right now: your measured exercise is added to your '
                'food budget each day (Food Settings > Add Exercise '
                'Calories).'
          : 'Used for your calorie goal. Automatic uses your average steps '
                'over the last two weeks.',
      hasLeading: false,
      children: [
        Semantics(
          selected: value == null,
          inMutuallyExclusiveGroup: true,
          child: InfoRow(
            title: 'Automatic',
            subtitle: m == null
                ? 'Needs a few days of steps; lightly active until then'
                : 'From your steps: ${m.label}',
            trailing: check(value == null),
            onTap: () => onChanged(null),
          ),
        ),
        for (final level in ActivityLevel.values)
          Semantics(
            selected: value == level,
            inMutuallyExclusiveGroup: true,
            child: InfoRow(
              title: level.label,
              subtitle: level.detail,
              trailing: check(value == level),
              onTap: () => onChanged(level),
            ),
          ),
      ],
    );
  }
}
