import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/nutrition/food_database.dart';
import 'package:health_app/models/body_goal.dart';
import 'package:health_app/models/food.dart';
import 'package:health_app/nutrition/calorie_estimate.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/notifications/notification_controller.dart';
import 'package:health_app/notifications/reminder_plan.dart';
import 'package:health_app/screens/goal/body_goal_screen.dart';
import 'package:health_app/screens/food/saved_foods_screen.dart';
import 'package:health_app/screens/notification_settings_screen.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/nutrition_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/glow_tile.dart';
import 'package:health_app/screens/food/food_cards.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/widgets/sheet_scaffold.dart';

/// Macro splits to choose from: (name, protein, carbs, fat).
const macroPresets = [
  ('Balanced', 0.30, 0.40, 0.30),
  ('High Protein', 0.40, 0.30, 0.30),
  ('Low Carb', 0.35, 0.20, 0.45),
  ('Endurance', 0.20, 0.55, 0.25),
];

/// The suggested daily calorie goal for the user's details, recent
/// activity and overall goal; null without a weight, height and age.
CalorieEstimate? suggestCalories(
  HealthStore health, {
  required bool exerciseAdded,
}) {
  final activity = health.recentActivity();
  return CalorieEstimate.estimate(
    profile: health.profile,
    weightKg: health.latestReading(MetricType.weight)?.value,
    today: health.today,
    goal: health.bodyGoal,
    exerciseAdded: exerciseAdded,
    averageSteps: activity.averageSteps,
    activeDays: activity.activeDays,
  );
}

/// How a suggested goal was worked out, in a sentence or two.
String explainEstimate(CalorieEstimate e, BodyGoal goal) {
  final base = e.countsExercise
      ? 'You burn about ${kcalText(e.maintenance)} Cal a day at rest; '
            'each day\'s measured activity is added as you move.'
      : 'About ${kcalText(e.maintenance)} Cal a day keeps your weight '
            'steady (${e.level?.label.toLowerCase() ?? 'lightly active'}).';
  final weight = e.weightKg;
  final change = goal.dailyKcalChangeFor(weight).abs();
  final rate = Units.weight(goal.safeRate(weight), decimals: 2);
  final capped = goal.safeRate(weight) < goal.weeklyRateKg
      ? ' (capped at 1% of your weight a week)'
      : '';
  final aim = switch (goal.objective) {
    GoalObjective.lose =>
      ' ${kcalText(change)} Cal less a day should lose about $rate a '
          'week$capped.',
    GoalObjective.gain =>
      ' ${kcalText(change)} Cal more a day should gain about $rate a '
          'week$capped.',
    _ => '',
  };
  final floor = e.atFloor
      ? ' Raised to ${kcalText(e.target)} Cal, the lowest goal advised '
            'without a doctor.'
      : '';
  return '$base$aim$floor';
}

/// Food settings: calorie goal, macros, meal reminders and saved foods.
class FoodSettingsScreen extends StatelessWidget {
  const FoodSettingsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(
      title: 'Food Settings',
      builder: (_) => const FoodSettingsScreen(),
    ),
  );

  Future<void> _editKcal(BuildContext context, NutritionGoals g) async {
    final store = context.read<NutritionStore>();
    final text = await showTextPrompt(
      context,
      title: 'Daily Calories',
      confirm: 'Save',
      initial: '${g.kcal.round()}',
      textAlign: TextAlign.center,
      suffix: 'Cal',
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    );
    final v = double.tryParse(text ?? '');
    if (v == null) return;
    if (v < 500 || v > 10000) {
      if (context.mounted) {
        await showMessage(
          context,
          title: 'Check Your Goal',
          message: 'Enter between 500 and 10,000 Cal.',
        );
      }
      return;
    }
    await store.setGoals(g.copyWith(kcal: v));
  }

  static int _mealHour((int, int, int) h, int i) => switch (i) {
    0 => h.$1,
    1 => h.$2,
    _ => h.$3,
  };

  static (int, int, int) _withMealHour((int, int, int) h, int i, int v) =>
      switch (i) {
        0 => (v, h.$2, h.$3),
        1 => (h.$1, v, h.$3),
        _ => (h.$1, h.$2, v),
      };

  Future<void> _applyReminders(
    BuildContext context,
    NotificationSettings next,
  ) async {
    final ok = await context.read<NotificationController>().update(next);
    if (!ok && context.mounted) {
      await showMessage(
        context,
        title: 'Notifications Are Off',
        message:
            'Allow notifications for Health in your phone\'s Settings to get '
            'meal reminders.',
      );
    }
  }

  Future<void> _clearRecent(BuildContext context) async {
    final store = context.read<NutritionStore>();
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Clear Recent Foods?'),
        content: const Text('Favorites and saved foods are kept.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok ?? false) await store.clearRecent();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NutritionStore>();
    final health = context.watch<HealthStore>();
    final g = store.goals;
    final suggestion = suggestCalories(health, exerciseAdded: g.addExercise);
    final estimate = suggestion?.target;
    final reminders = context.watch<NotificationController>().settings;
    return LargeTitlePage(
      title: 'Food Settings',
      children: [
        const SettingsHero(
          icon: Icons.restaurant_rounded,
          color: foodOrange,
          title: 'Food',
          subtitle: 'Your calorie budget, macros and meal reminders.',
        ),
        GroupedSection(
          footer: suggestion == null
              ? 'Add your height, birthday and weight to get a suggested '
                    'goal.'
              : explainEstimate(suggestion, health.bodyGoal),
          children: [
            InfoRow(
              leading: IconTile(
                icon: Icons.local_fire_department_rounded,
                color: context.resolve(foodOrange),
              ),
              title: 'Daily Calories',
              value: '${kcalText(g.kcal)} Cal',
              chevron: true,
              onTap: () => _editKcal(context, g),
            ),
            if (estimate != null && estimate != g.kcal)
              CupertinoListTile(
                leading: IconTile(
                  icon: Icons.auto_awesome_rounded,
                  color: context.tint,
                ),
                title: Text(
                  'Use Suggested (${kcalText(estimate)} Cal)',
                  style: TextStyle(color: context.tint),
                ),
                onTap: () => store.setGoals(
                  g.copyWith(
                    kcal: estimate,
                    includesActivity: !(suggestion?.countsExercise ?? false),
                  ),
                ),
              ),
            InfoRow(
              leading: IconTile(
                icon: Icons.calculate_rounded,
                color: context.resolve(Palette.teal),
              ),
              title: suggestion == null
                  ? 'Get a Suggested Goal'
                  : 'How It\'s Worked Out',
              chevron: true,
              onTap: () => BodyGoalScreen.open(context),
            ),
            CupertinoListTile(
              leading: IconTile(
                icon: Icons.directions_run_rounded,
                color: context.resolve(Palette.pink),
              ),
              title: const Text('Add Exercise Calories'),
              subtitle: Text(
                store.goalIncludesActivity
                    ? 'Workouts raise the day\'s budget (your goal already '
                          'covers everyday activity)'
                    : 'All measured activity raises the day\'s budget',
              ),
              trailing: CupertinoSwitch(
                value: g.addExercise,
                onChanged: (v) => store.setGoals(g.copyWith(addExercise: v)),
              ),
            ),
          ],
        ),
        const BlockLabel('Macros'),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // Tiles grow with the text size rather than overflowing.
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: MediaQuery.textScalerOf(context).scale(112),
          ),
          children: [
            for (final (name, p, c, f) in macroPresets)
              _PresetCard(
                name: name,
                shares: (p, c, f),
                selected:
                    (g.proteinShare - p).abs() < 0.01 &&
                    (g.carbsShare - c).abs() < 0.01,
                onTap: () => store.setGoals(
                  g.copyWith(proteinShare: p, carbsShare: c, fatShare: f),
                ),
              ),
          ],
        ),
        const BlockLabel('Daily Targets'),
        IosCard(
          child: Row(
            children: [
              for (final (label, grams, color) in [
                ('Protein', g.proteinGrams, proteinColor),
                ('Carbs', g.carbsGrams, carbsColor),
                ('Fat', g.fatGrams, fatColor),
              ])
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${grams.round()} g',
                        style: context.number(22, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: context.footnote.copyWith(
                          color: context.resolve(color),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        GroupedSection(
          header: 'Meal Reminders',
          footer: reminders.meals
              ? 'A reminder to log each meal, every day.'
              : 'Get a nudge to log breakfast, lunch and dinner.',
          children: [
            CupertinoListTile(
              leading: IconTile(
                icon: Icons.notifications_rounded,
                color: context.resolve(Palette.red),
              ),
              title: const Text('Remind Me to Log Meals'),
              trailing: CupertinoSwitch(
                value: reminders.meals,
                onChanged: (v) =>
                    _applyReminders(context, reminders.copyWith(meals: v)),
              ),
            ),
            if (reminders.meals)
              for (final (i, meal) in const [
                Meal.breakfast,
                Meal.lunch,
                Meal.dinner,
              ].indexed)
                InfoRow(
                  leading: IconTile(
                    icon: meal.icon,
                    color: context.resolve(meal.color),
                  ),
                  title: meal.label,
                  value: TimeOfDayFormat.format(
                    context,
                    _mealHour(reminders.mealHours, i),
                  ),
                  chevron: true,
                  onTap: () => NotificationSettingsScreen.pickHour(
                    context,
                    _mealHour(reminders.mealHours, i),
                    (h) => _applyReminders(
                      context,
                      reminders.copyWith(
                        mealHours: _withMealHour(reminders.mealHours, i, h),
                      ),
                    ),
                  ),
                ),
          ],
        ),
        GroupedSection(
          header: 'Foods',
          children: [
            InfoRow(
              leading: IconTile(
                icon: Icons.star_rounded,
                color: context.resolve(Palette.yellow),
              ),
              title: 'Saved Foods',
              value:
                  '${{
                    for (final f in [...store.custom, ...store.favorites]) f.id,
                  }.length}',
              chevron: true,
              onTap: () => SavedFoodsScreen.open(context),
            ),
            CupertinoListTile(
              leading: IconTile(
                icon: Icons.schedule_rounded,
                color: context.resolve(Palette.grey),
              ),
              title: const Text('Clear Recent Foods'),
              onTap: store.recent.isEmpty ? null : () => _clearRecent(context),
            ),
          ],
        ),
        const _FoodDatabaseSection(),
      ],
    );
  }
}

/// The food database on GitHub: how many foods, when it was updated, and
/// a way to update it now.
class _FoodDatabaseSection extends StatelessWidget {
  const _FoodDatabaseSection();

  @override
  Widget build(BuildContext context) {
    final FoodDatabase db;
    try {
      db = context.watch<FoodDatabase>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    final updated = db.updated;
    return GroupedSection(
      header: 'Food Database',
      footer:
          'Everyday foods with vitamins and minerals, from USDA FoodData '
          'Central and the Health community. Kept on your phone and updated '
          'weekly from GitHub; nothing about you is sent.',
      children: [
        InfoRow(
          leading: IconTile(
            icon: Icons.menu_book_rounded,
            color: context.resolve(Palette.green),
          ),
          title: 'Foods',
          value: db.isEmpty
              ? (db.updating ? 'Downloading…' : 'Not downloaded')
              : NumberFormat.decimalPattern().format(db.count),
        ),
        if (updated != null)
          InfoRow(
            leading: IconTile(
              icon: Icons.history_rounded,
              color: context.resolve(Palette.grey),
            ),
            title: 'Last Updated',
            value: DateFormat.yMMMd().format(updated),
          ),
        CupertinoListTile(
          leading: IconTile(
            icon: Icons.refresh_rounded,
            color: context.resolve(Palette.blue),
          ),
          title: Text(db.updating ? 'Updating…' : 'Update Now'),
          subtitle: db.failed && !db.updating
              ? const Text('Couldn\'t update. Check your connection.')
              : null,
          onTap: db.updating ? null : () => db.refresh(force: true),
        ),
      ],
    );
  }
}

/// A macro split to choose: its name, a bar of the three shares and the
/// percentages, outlined in the accent when chosen.
class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.name,
    required this.shares,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final (double, double, double) shares;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (p, c, f) = shares;
    final tint = context.tint;
    final parts = [
      (p, context.resolve(proteinColor)),
      (c, context.resolve(carbsColor)),
      (f, context.resolve(fatColor)),
    ];
    String pct(double v) => '${(v * 100).round()}';
    void tap() {
      HapticFeedback.selectionClick();
      onTap();
    }

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: '$name: protein ${pct(p)}%, carbs ${pct(c)}%, fat ${pct(f)}%',
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
                    tint.withValues(alpha: context.isDark ? 0.16 : 0.10),
                    context.cardBackground,
                  )
                : context.cardBackground,
            shape: context.choiceShape(selected: selected, color: tint),
            shadows: context.skinShadows,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.subheadline.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle_rounded, color: tint, size: 20),
                ],
              ),
              const Spacer(),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      for (final (i, (share, color)) in parts.indexed)
                        Expanded(
                          flex: (share * 100).round(),
                          child: Container(
                            margin: EdgeInsets.only(left: i > 0 ? 2 : 0),
                            color: color,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'P ${pct(p)} · C ${pct(c)} · F ${pct(f)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.caption1.copyWith(
                  color: context.secondaryLabel,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
