import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/insights/weight_trend.dart';
import 'package:health_app/models/body_goal.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/nutrition/calorie_estimate.dart';
import 'package:health_app/screens/food/food_cards.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/nutrition_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/ios.dart';

/// Weigh-ins oldest first, as (date, kg).
/// Weigh-ins oldest first, one a day (the day's last), as (date, kg).
List<(DateTime, double)> weighInsOf(HealthStore health) {
  final all = [
    for (final e in health.entriesFor(MetricType.weight)) (e.date, e.value),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  final byDay = <DateTime, (DateTime, double)>{};
  for (final w in all) {
    byDay[DateTime(w.$1.year, w.$1.month, w.$1.day)] = w;
  }
  return byDay.values.toList();
}

/// The check-in for the user's current data, or null without a trend.
CheckInResult? currentCheckIn(HealthStore health, NutritionStore nutrition) {
  final floor = switch (health.profile.sex.toLowerCase()) {
    'female' => CalorieEstimate.floorFemale,
    'male' => CalorieEstimate.floorMale,
    _ => CalorieEstimate.floorOther,
  };
  return WeeklyCheckIn.evaluate(
    goal: health.bodyGoal,
    weighIns: weighInsOf(health),
    today: health.today,
    currentKcal: nutrition.goals.kcal,
    floorKcal: floor,
  );
}

/// "Weekly Check-In": how the weight trend compares with the plan, with a
/// suggested calorie goal when they've drifted apart.
///
/// On Summary it shows only when a check-in is due ([dueOnly]) and goes
/// away once answered; on the goal screen it always shows.
class CheckInCard extends StatelessWidget {
  const CheckInCard({super.key, this.dueOnly = false});

  final bool dueOnly;

  static String _pace(double kgPerWeek) {
    if (kgPerWeek.abs() < 0.05) return 'steady';
    final sign = kgPerWeek < 0 ? '−' : '+';
    return '$sign${Units.weight(kgPerWeek.abs(), decimals: 1)} a week';
  }

  static String message(CheckInResult r, BodyGoal goal) {
    final kcal = r.suggestedKcal;
    final change = kcal == null
        ? ''
        : ' Try ${kcalText(kcal)} Cal a day for the next week.';
    return switch (r.status) {
      CheckInStatus.onTrack => switch (goal.objective) {
        GoalObjective.maintain => 'Your weight is holding steady.',
        _ => 'Right on plan. Keep doing what you\'re doing.',
      },
      CheckInStatus.slower =>
        'Progress is a little slower than planned.$change',
      CheckInStatus.faster =>
        'You\'re moving faster than planned. A gentler pace is easier '
            'to keep and protects muscle.$change',
      CheckInStatus.wrongWay => switch (goal.objective) {
        GoalObjective.maintain => 'Your weight is drifting.$change',
        _ => 'Your weight is moving away from your goal.$change',
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthStore>();
    final nutrition = context.watch<NutritionStore>();
    final goal = health.bodyGoal;
    if (dueOnly && !WeeklyCheckIn.isDue(goal, health.today)) {
      return const SizedBox.shrink();
    }
    final r = currentCheckIn(health, nutrition);
    if (r == null) return const SizedBox.shrink();
    final good = r.status == CheckInStatus.onTrack;
    final color = good ? Palette.green : Palette.orange;
    // Once answered, nothing more to apply until the next check-in.
    final answered = WeeklyCheckIn.answered(goal, health.today);
    final kcal = answered ? null : r.suggestedKcal;

    Future<void> answer({required bool apply}) async {
      if (apply && kcal != null) {
        await nutrition.setGoals(nutrition.goals.copyWith(kcal: kcal));
      }
      await health.setBodyGoal(goal.copyWith(checkedIn: health.today));
    }

    final card = IosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(
                icon: good
                    ? Icons.verified_rounded
                    : Icons.tips_and_updates_rounded,
                color: color,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('Weekly Check-In', style: context.headline)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Pace(label: 'PLAN', value: _pace(r.plannedKgPerWeek)),
              const SizedBox(width: 12),
              _Pace(
                label: 'YOUR TREND',
                value: _pace(r.actualKgPerWeek),
                color: context.resolve(color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            answered
                ? 'Checked in this week. Your next check-in is in '
                      '${WeeklyCheckIn.everyDays - WeeklyCheckIn.daysBetween(goal.checkedIn!, health.today)} '
                      'days.'
                : message(r, goal),
            style: context.subheadline.copyWith(color: context.secondaryLabel),
          ),
          if (dueOnly || kcal != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (kcal != null)
                  CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(22),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    onPressed: () => answer(apply: true),
                    child: Text(
                      'Use ${kcalText(kcal)} Cal',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                if (dueOnly)
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    onPressed: () => answer(apply: false),
                    child: Text(kcal == null ? 'Got It' : 'Keep Current'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
    return dueOnly
        ? Padding(padding: const EdgeInsets.only(bottom: 12), child: card)
        : card;
  }
}

class _Pace extends StatelessWidget {
  const _Pace({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: ShapeDecoration(
        color: context.cardBackground.withValues(alpha: 0.6),
        shape: AppTheme.squircle(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.caption2.copyWith(color: context.secondaryLabel),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: context.headline.copyWith(color: color)),
          ),
        ],
      ),
    ),
  );
}
