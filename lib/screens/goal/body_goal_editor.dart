import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/body_goal.dart';
import 'package:health_app/screens/onboarding/setup_page.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/app_segmented.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/widgets/sheet_scaffold.dart';

/// Colour of each goal.
Color goalColor(GoalObjective o) => switch (o) {
  GoalObjective.lose => Palette.teal,
  GoalObjective.maintain => Palette.green,
  GoalObjective.gain => Palette.orange,
  GoalObjective.fitness => Palette.violet,
};

/// Choose a goal; for weight goals, a target weight and pace too. A
/// controlled widget: it shows [goal] and [targetKg] and reports changes.
class BodyGoalEditor extends StatelessWidget {
  const BodyGoalEditor({
    super.key,
    required this.goal,
    required this.targetKg,
    required this.currentKg,
    required this.today,
    required this.onGoal,
    required this.onTarget,
  });

  final BodyGoal goal;
  final double? targetKg;

  /// The latest weight, if known: the starting point for a target.
  final double? currentKg;
  final DateTime today;
  final ValueChanged<BodyGoal> onGoal;
  final ValueChanged<double> onTarget;

  /// Step of the target weight: half a kilo, or a pound.
  static double get _step => Units.imperial ? 1 / Units.lbPerKg : 0.5;

  /// A sensible first target for [objective] from [currentKg].
  static double defaultTarget(GoalObjective objective, double? currentKg) {
    final now = currentKg ?? 70;
    final t = switch (objective) {
      GoalObjective.lose => now - 5,
      GoalObjective.gain => now + 3,
      _ => now,
    };
    return (t * 2).round() / 2;
  }

  @override
  Widget build(BuildContext context) {
    final target = targetKg ?? defaultTarget(goal.objective, currentKg);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ObjectiveGrid(
          selected: goal.objective,
          onSelect: (o) {
            // Keep the pace if the new goal offers it, else the middle one.
            final rates = BodyGoal.ratesFor(o);
            onGoal(
              goal.copyWith(
                objective: o,
                weeklyRateKg: rates.contains(goal.weeklyRateKg)
                    ? goal.weeklyRateKg
                    : rates[1],
              ),
            );
          },
        ),
        if (goal.objective.changesWeight) ...[
          const BlockLabel('Target'),
          IosCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                SetupStepper(
                  icon: goal.objective.icon,
                  color: goalColor(goal.objective),
                  title: 'Target Weight',
                  value: Units.weight(target),
                  onMinus: target > 30 ? () => onTarget(target - _step) : null,
                  onPlus: target < 300 ? () => onTarget(target + _step) : null,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                  child: AppSegmented<double>(
                    groupValue: goal.weeklyRateKg,
                    children: {
                      for (final r in BodyGoal.ratesFor(goal.objective))
                        r: Text(
                          '${_paceName(r)} · ${Units.weight(r, decimals: 2)}',
                        ),
                    },
                    onValueChanged: (r) =>
                        onGoal(goal.copyWith(weeklyRateKg: r)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              _projection(target),
              style: context.footnote.copyWith(color: context.secondaryLabel),
            ),
          ),
        ],
      ],
    );
  }

  String _paceName(double rate) =>
      ['Gentle', 'Steady', 'Faster'][BodyGoal.ratesFor(goal.objective)
          .indexOf(rate)
          .clamp(0, 2)];

  /// When the target is reached at the chosen pace, or why it can't be.
  String _projection(double target) {
    final now = currentKg;
    if (now == null) {
      return 'Add your weight to see when you\'ll reach your target.';
    }
    final diff = target - now;
    final wrongWay = goal.objective == GoalObjective.lose
        ? diff >= 0
        : diff <= 0;
    if (wrongWay) {
      return goal.objective == GoalObjective.lose
          ? 'Choose a target below your current ${Units.weight(now)}.'
          : 'Choose a target above your current ${Units.weight(now)}.';
    }
    final weeks = (diff.abs() / goal.safeRate(now)).ceil();
    final when = DateTime(today.year, today.month, today.day + weeks * 7);
    return 'From ${Units.weight(now)}, about $weeks '
        '${weeks == 1 ? 'week' : 'weeks'}: around '
        '${DateFormat.yMMMd().format(when)}. Steady changes are the '
        'easiest to keep.';
  }
}

class _ObjectiveGrid extends StatelessWidget {
  const _ObjectiveGrid({required this.selected, required this.onSelect});

  final GoalObjective selected;
  final ValueChanged<GoalObjective> onSelect;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return GridView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 120 * scale.clamp(1.0, 1.8),
      ),
      children: [
        for (final o in GoalObjective.values)
          _ObjectiveCard(
            objective: o,
            selected: o == selected,
            onTap: () => onSelect(o),
          ),
      ],
    );
  }
}

class _ObjectiveCard extends StatelessWidget {
  const _ObjectiveCard({
    required this.objective,
    required this.selected,
    required this.onTap,
  });

  final GoalObjective objective;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.resolve(goalColor(objective));
    void tap() {
      HapticFeedback.selectionClick();
      onTap();
    }

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: '${objective.label}. ${objective.detail}',
      onTap: tap,
      excludeSemantics: true,
      child: Pressable(
        onTap: tap,
        child: AnimatedContainer(
          duration: Motion.reduced(context) ? Duration.zero : Motion.fast,
          padding: const EdgeInsets.all(14),
          decoration: ShapeDecoration(
            color: selected
                ? Color.alphaBlend(
                    color.withValues(alpha: context.isDark ? 0.18 : 0.12),
                    context.cardBackground,
                  )
                : context.cardBackground,
            shape: context.choiceShape(selected: selected, color: color),
            shadows: context.skinShadows,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon: objective.icon, color: color, size: 34),
              // The text keeps to the tile's height (taller theme fonts
              // lose the detail's second line rather than overflow).
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      objective.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.subheadline.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        objective.detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.caption1.copyWith(
                          color: context.secondaryLabel,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
