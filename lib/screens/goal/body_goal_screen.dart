import 'package:flutter/cupertino.dart' hide Text;
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/body_goal.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/nutrition/calorie_estimate.dart';
import 'package:health_app/screens/edit_profile_screen.dart';
import 'package:health_app/screens/food/food_cards.dart';
import 'package:health_app/screens/food/food_settings_screen.dart';
import 'package:health_app/screens/goal/body_goal_editor.dart';
import 'package:health_app/screens/goal/calorie_breakdown.dart';
import 'package:health_app/screens/goal/check_in_card.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/nutrition_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/sheet_scaffold.dart';

/// The user's overall goal and the calorie goal that follows from it.
class BodyGoalScreen extends StatelessWidget {
  const BodyGoalScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(title: 'Your Goal', builder: (_) => const BodyGoalScreen()),
  );

  /// Saves a new goal. A different goal starts from today's weight.
  static Future<void> apply(
    HealthStore health,
    BodyGoal next, {
    double? targetKg,
  }) async {
    final current = health.latestReading(MetricType.weight)?.value;
    final restart = next.objective != health.bodyGoal.objective;
    await health.setBodyGoal(
      restart || next.startDate == null
          ? BodyGoal(
              objective: next.objective,
              weeklyRateKg: next.weeklyRateKg,
              startKg: current,
              startDate: health.today,
              activity: next.activity,
            )
          : next,
    );
    if (!next.objective.changesWeight) return;
    // A new direction starts from a fresh target on the right side.
    final keep = restart ? null : health.goals.weightKg;
    await health.setWeightGoal(
      targetKg ?? keep ?? BodyGoalEditor.defaultTarget(next.objective, current),
    );
  }

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthStore>();
    final nutrition = context.watch<NutritionStore>();
    final goal = health.bodyGoal;
    final suggestion = suggestCalories(
      health,
      exerciseAdded: nutrition.goals.addExercise,
    );
    return LargeTitlePage(
      title: 'Your Goal',
      children: [
        BodyGoalEditor(
          goal: goal,
          targetKg: health.goals.weightKg,
          currentKg: health.latestReading(MetricType.weight)?.value,
          today: health.today,
          onGoal: (g) => apply(health, g),
          onTarget: health.setWeightGoal,
        ),
        const Padding(padding: EdgeInsets.only(top: 16), child: CheckInCard()),
        ActivityLevelSection(
          exerciseCounted: suggestion?.countsExercise ?? false,
          value: goal.activity,
          measured: switch (health.recentActivity().averageSteps) {
            final s? => ActivityLevel.fromSteps(s),
            null => null,
          },
          onChanged: (level) => health.setBodyGoal(
            goal.copyWith(activity: level, autoActivity: level == null),
          ),
        ),
        const BlockLabel('Calories'),
        CalorieBreakdown(
          estimate: suggestion,
          goal: goal,
          missing: CalorieEstimate.missingFor(
            health.profile,
            health.latestReading(MetricType.weight)?.value,
            health.today,
          ),
          onAddDetails: () => EditProfileScreen.open(context),
          footer: suggestion == null
              ? null
              : (nutrition.goals.kcal - suggestion.target).abs() >= 10
              ? Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(22),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    onPressed: () => nutrition.setGoals(
                      nutrition.goals.copyWith(
                        kcal: suggestion.target,
                        includesActivity: !suggestion.countsExercise,
                      ),
                    ),
                    child: Text(
                      'Use as Food Goal (now '
                      '${kcalText(nutrition.goals.kcal)})',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'This is your Food goal.',
                    style: context.footnote.copyWith(
                      color: context.resolve(Palette.green),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
          child: Text(
            'Estimates use the Mifflin-St Jeor equation and your recent '
            'activity. Everyone is different: adjust if your weight moves '
            'faster or slower than planned. Not medical advice.',
            style: context.caption1.copyWith(color: context.tertiaryLabel),
          ),
        ),
      ],
    );
  }
}
