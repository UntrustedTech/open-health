import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/food.dart';
import 'package:health_app/models/meal_template.dart';
import 'package:health_app/screens/food/add_food_sheet.dart';
import 'package:health_app/screens/food/food_detail_sheet.dart';
import 'package:health_app/screens/food/meal_editors.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/nutrition_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/models/health_widget.dart';
import 'package:health_app/widgets/board_tiles.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/widgets/progress_ring.dart';
import 'package:health_app/workout/workout_stats.dart';

/// Food colours: the Food tab's own orange, and one per macro.
const foodOrange = Palette.orange;
const proteinColor = Palette.teal;
const carbsColor = Palette.yellow;
const fatColor = Palette.purple;

String kcalText(double v) => NumberFormat.decimalPattern().format(v.round());

extension MealLook on Meal {
  /// Each meal's own colour, so the diary reads at a glance.
  Color get color => switch (this) {
    Meal.breakfast => Palette.yellow,
    Meal.lunch => Palette.orange,
    Meal.dinner => Palette.indigo,
    Meal.snack => Palette.pink,
  };
}

/// Goal − Food + Exercise = Remaining, around a ring.
class CalorieBudgetCard extends StatelessWidget {
  const CalorieBudgetCard({super.key, required this.day, this.onTap});

  /// Text scale above which the ring and numbers stack.
  static const _stackScale = 1.3;

  final DateTime day;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NutritionStore>();
    // Rebuild when activity data changes.
    context.watch<HealthStore>();
    final goals = store.goals;
    final eaten = store.totalOn(day).kcal;
    final burned = store.burnedOn(day);
    final budget = store.budgetOn(day);
    final left = budget - eaten;
    final over = left < 0;
    final orange = context.resolve(foodOrange);
    final stacked = MediaQuery.textScalerOf(context).scale(1) > _stackScale;
    final ringColor = over ? context.resolve(Palette.red) : orange;
    return Semantics(
      container: true,
      label:
          'Calories: ${kcalText(eaten)} eaten of ${kcalText(budget)}, '
          '${kcalText(left.abs())} ${over ? 'over' : 'left'}',
      child: IosCard(
        onTap: onTap,
        tint: over ? Palette.red : foodOrange,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        // At large text sizes the ring sits above the numbers.
        child: Flex(
          direction: stacked ? Axis.vertical : Axis.horizontal,
          mainAxisSize: stacked ? MainAxisSize.min : MainAxisSize.max,
          children: [
            ProgressRing(
              progress: budget <= 0 ? 0 : eaten / budget,
              color: ringColor,
              size: 136,
              stroke: 13,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedNumber(
                    value: left.abs(),
                    format: kcalText,
                    style: context.number(30, weight: FontWeight.w800),
                  ),
                  Text(
                    over ? 'Cal over' : 'Cal left',
                    style: context.caption1.copyWith(
                      color: over ? ringColor : context.secondaryLabel,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18, height: 16),
            _expandedIf(
              !stacked,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CALORIES',
                    style: context.overline.copyWith(
                      color: context.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Term(
                    icon: Icons.flag_rounded,
                    color: Palette.grey,
                    label: 'Goal',
                    value: kcalText(goals.kcal),
                  ),
                  _Term(
                    icon: Icons.restaurant_rounded,
                    color: foodOrange,
                    label: 'Food',
                    value: kcalText(eaten),
                  ),
                  if (goals.addExercise)
                    _Term(
                      icon: Icons.local_fire_department_rounded,
                      color: Palette.pink,
                      label: store.goalIncludesActivity
                          ? 'Workouts'
                          : 'Exercise',
                      value: kcalText(burned),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [child] filling the rest of a row, or as it is in a column.
Widget _expandedIf(bool expand, Widget child) =>
    expand ? Expanded(child: child) : child;

class _Term extends StatelessWidget {
  const _Term({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.resolve(color);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
      decoration: ShapeDecoration(
        color: c.withValues(alpha: context.isDark ? 0.12 : 0.08),
        shape: AppTheme.squircle(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: c, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.footnote.copyWith(
                color: context.secondaryLabel,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(value, style: context.number(15, weight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// Protein, carbs and fat as three small glowing rings.
class MacrosCard extends StatelessWidget {
  const MacrosCard({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NutritionStore>();
    final n = store.totalOn(day);
    final g = store.goals;
    final macros = [
      ('Protein', n.protein, g.proteinGrams, proteinColor),
      ('Carbs', n.carbs, g.carbsGrams, carbsColor),
      ('Fat', n.fat, g.fatGrams, fatColor),
    ];
    return Row(
      children: [
        for (final (i, (label, have, want, color)) in macros.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              label: '$label ${have.round()} of ${want.round()} grams',
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
                decoration: cardSurface(context, tint: color),
                child: Column(
                  children: [
                    ProgressRing(
                      progress: want <= 0 ? 0 : have / want,
                      color: color,
                      size: 58,
                      stroke: 6,
                      child: Text(
                        '${have.round()}',
                        style: context.number(17, weight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.footnote.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      want <= 0
                          ? '${have.round()} g'
                          : have >= want
                          ? 'Goal met'
                          : '${(want - have).round()} g left',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.caption1.copyWith(
                        color: context.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A week of days to pick from, with a dot on days with food logged.
class DayStrip extends StatelessWidget {
  const DayStrip({
    super.key,
    required this.day,
    required this.today,
    required this.onSelect,
  });

  final DateTime day;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NutritionStore>();
    // Weeks start on the same day as the training plan's.
    final from = weekStart(
      day,
      firstDay: context.select<WorkoutStore, int>((w) => w.plan.weekStart),
    );
    final days = [
      for (var i = 0; i < 7; i++) DateTime(from.year, from.month, from.day + i),
    ];
    return Row(
      children: [
        for (final d in days)
          Expanded(
            child: _DayCell(
              day: d,
              selected: d == day,
              isToday: d == today,
              future: d.isAfter(today),
              logged: store.entriesOn(d).isNotEmpty,
              onTap: () => onSelect(d),
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.future,
    required this.logged,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool isToday;
  final bool future;
  final bool logged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = context.resolve(foodOrange);
    final accent = context.tint;
    final onThumb = context.onColor(accent);
    final fg = selected
        ? onThumb
        : future
        ? context.tertiaryLabel
        : context.labelColor;
    final VoidCallback? select = future || selected
        ? null
        : () {
            HapticFeedback.selectionClick();
            onTap();
          };
    return Semantics(
      container: true,
      button: !future,
      selected: selected,
      label: DateFormat.MMMMEEEEd().format(day),
      onTap: select,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: select,
        child: AnimatedContainer(
          duration: Motion.reduced(context) ? Duration.zero : Motion.fast,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: ShapeDecoration(
            shape: StadiumBorder(
              side: isToday && !selected
                  ? BorderSide(color: tint.withValues(alpha: 0.6))
                  : BorderSide.none,
            ),
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(accent, const Color(0xFFFFFFFF), 0.15)!,
                      accent,
                    ],
                  )
                : null,
            shadows: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(
                DateFormat('EEEEE').format(day),
                style: context.caption2.copyWith(
                  color: selected ? onThumb : context.secondaryLabel,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${day.day}',
                style: context
                    .number(16, weight: FontWeight.w700)
                    .copyWith(color: fg),
              ),
              const SizedBox(height: 3),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: !logged
                      ? const Color(0x00000000)
                      : selected
                      ? onThumb
                      : tint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One meal: its total, each food (swipe to delete) and an Add button.
class MealCard extends StatelessWidget {
  const MealCard({
    super.key,
    required this.meal,
    required this.day,
    required this.entries,
  });

  final Meal meal;
  final DateTime day;
  final List<FoodEntry> entries;

  @override
  Widget build(BuildContext context) {
    final store = context.read<NutritionStore>();
    final color = context.resolve(meal.color);
    final kcal = entries.fold<double>(0, (s, e) => s + e.nutrients.kcal);
    final count = entries.length;
    return IosCard(
      padding: EdgeInsets.zero,
      tint: meal.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                IconTile(icon: meal.icon, color: color, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(meal.label, style: context.headline),
                      ),
                      Text(
                        count == 0
                            ? 'Nothing logged yet'
                            : '$count ${count == 1 ? 'item' : 'items'}',
                        style: context.footnote.copyWith(
                          color: context.secondaryLabel,
                        ),
                      ),
                      if (count >= 2)
                        Semantics(
                          button: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => MealTemplateEditor.show(
                              context,
                              items: [
                                for (final e in entries)
                                  FoodPortion(
                                    food: e.food,
                                    amount: e.amount,
                                    inGrams: e.inGrams,
                                  ),
                              ],
                            ),
                            // A full-height tap area for the small link.
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight: AppTheme.minTapTarget,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                widthFactor: 1,
                                child: Text(
                                  'Save as Meal',
                                  style: context.footnote.copyWith(
                                    color: context.tint,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (count > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        kcalText(kcal),
                        style: context.number(22, weight: FontWeight.w800),
                      ),
                      Text(
                        'Cal',
                        style: context.caption2.copyWith(
                          color: context.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          for (final e in entries)
            Dismissible(
              key: ValueKey(e.id),
              direction: DismissDirection.endToStart,
              background: ColoredBox(
                color: context.destructive,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 20),
                    child: Icon(
                      Icons.delete_rounded,
                      color: CupertinoColors.white,
                      semanticLabel: tr('Delete'),
                    ),
                  ),
                ),
              ),
              onDismissed: (_) {
                HapticFeedback.mediumImpact();
                store.delete(e.id);
              },
              // Opaque, so the red only shows where the row has moved away.
              child: ColoredBox(
                color: Color.alphaBlend(
                  color.withValues(alpha: context.isDark ? 0.05 : 0.03),
                  context.cardBackground,
                ),
                child: _FoodRow(
                  entry: e,
                  color: color,
                  onTap: () => FoodDetailSheet.edit(context, e),
                ),
              ),
            ),
          Pressable(
            semanticLabel: tr('Add Food to ${meal.label}'),
            onTap: () => AddFoodSheet.show(context, meal: meal, day: day),
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: ShapeDecoration(
                color: color.withValues(alpha: context.isDark ? 0.16 : 0.12),
                shape: const StadiumBorder(),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: color, size: 20),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Add Food',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.subheadline.copyWith(
                        color: context.isDark ? color : context.labelColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({
    required this.entry,
    required this.color,
    required this.onTap,
  });

  final FoodEntry entry;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final name = e.food.name.trim();
    final kcal = kcalText(e.nutrients.kcal);
    return Semantics(
      container: true,
      button: true,
      label: '$name, ${e.amountLabel}, $kcal Cal',
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              // The food's initial, in the meal's colour.
              FoodAvatar(name: name, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.subheadline.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      [
                        if (e.food.brand.isNotEmpty) e.food.brand,
                        e.amountLabel,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.footnote.copyWith(
                        color: context.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                kcal,
                style: context.subheadline.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                ' Cal',
                style: context.caption1.copyWith(color: context.secondaryLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A food's first letter in a circle of [color], as a list row's leading.
class FoodAvatar extends StatelessWidget {
  const FoodAvatar({super.key, required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.resolve(color);
    final n = name.trim();
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: c.withValues(alpha: 0.14),
        shape: const CircleBorder(),
      ),
      child: Text(
        n.isEmpty ? '?' : n.characters.first.toUpperCase(),
        style: context.subheadline.copyWith(
          color: c,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Calories left (or over) for [day] as a small or medium widget, with a
/// bar of the budget eaten.
class CaloriesSmall extends StatelessWidget {
  const CaloriesSmall({
    super.key,
    required this.day,
    this.size = WidgetSize.small,
  });

  final DateTime day;
  final WidgetSize size;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NutritionStore>();
    context.watch<HealthStore>();
    final eaten = store.totalOn(day).kcal;
    final budget = store.budgetOn(day);
    final left = budget - eaten;
    final over = left < 0;
    final color = over ? Palette.red : foodOrange;
    final eatenShare = budget <= 0 ? 0.0 : eaten / budget;
    return StatWidget(
      size: size,
      icon: Icons.local_fire_department_rounded,
      color: color,
      title: 'Calories',
      semanticLabel:
          'Calories: ${kcalText(eaten)} eaten of ${kcalText(budget)}, '
          '${kcalText(left.abs())} ${over ? 'over' : 'left'}',
      value: StatValue(kcalText(left.abs()), unit: 'Cal', size: size),
      caption: over ? 'Over your budget' : 'Left of ${kcalText(budget)}',
      smallVisual: BarVisual(progress: eatenShare, color: color),
      facts: [
        (label: 'Eaten', value: kcalText(eaten)),
        (label: 'Burned', value: kcalText(store.burnedOn(day))),
        (label: 'Budget', value: kcalText(budget)),
      ],
    );
  }
}

/// Protein, carbs and fat for [day] as a small or medium widget: protein
/// as the headline, and a bar for each.
class MacrosSmall extends StatelessWidget {
  const MacrosSmall({
    super.key,
    required this.day,
    this.size = WidgetSize.small,
  });

  final DateTime day;
  final WidgetSize size;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NutritionStore>();
    final n = store.totalOn(day);
    final g = store.goals;
    final macros = [
      ('Protein', n.protein, g.proteinGrams, proteinColor),
      ('Carbs', n.carbs, g.carbsGrams, carbsColor),
      ('Fat', n.fat, g.fatGrams, fatColor),
    ];
    return StatWidget(
      size: size,
      icon: Icons.donut_small_rounded,
      color: proteinColor,
      title: 'Macros',
      semanticLabel:
          'Macros: protein ${n.protein.round()}, carbs ${n.carbs.round()}, '
          'fat ${n.fat.round()} grams',
      value: StatValue('${n.protein.round()}', unit: 'g protein', size: size),
      caption: 'Carbs ${n.carbs.round()} g · Fat ${n.fat.round()} g',
      facts: [
        for (final (name, have, want, _) in macros)
          (
            label: name,
            value: want <= 0
                ? '${have.round()} g'
                : '${have.round()}/${want.round()} g',
          ),
      ],
      smallVisual: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (final (i, (_, have, want, color)) in macros.indexed) ...[
            if (i > 0) const SizedBox(height: 4),
            CapsuleProgress(
              value: want <= 0 ? 0 : have / want,
              color: context.resolve(color),
              height: 5,
            ),
          ],
        ],
      ),
    );
  }
}

/// One meal on [day] as a small widget: its calories and items, and a
/// prompt to add food. Tapping adds food to it.
class MealSmall extends StatelessWidget {
  const MealSmall({
    super.key,
    required this.meal,
    required this.day,
    this.size = WidgetSize.small,
  });

  final Meal meal;
  final DateTime day;
  final WidgetSize size;

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final e in context.watch<NutritionStore>().entriesOn(day))
        if (e.meal == meal) e,
    ];
    double total(double Function(Nutrients n) of) =>
        entries.fold(0.0, (sum, e) => sum + of(e.nutrients));
    final kcal = total((n) => n.kcal);
    final protein = total((n) => n.protein);
    final carbs = total((n) => n.carbs);
    final fat = total((n) => n.fat);
    final c = context.resolve(meal.color);
    final addFood = Container(
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: context.pastel(c),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_rounded, size: 16, color: c),
          const SizedBox(width: 4),
          Text(
            'Add Food',
            style: context.footnote.copyWith(
              fontWeight: FontWeight.w700,
              color: context.labelColor,
            ),
          ),
        ],
      ),
    );
    return StatWidget(
      size: size,
      icon: meal.icon,
      color: meal.color,
      title: meal.label,
      semanticLabel:
          '${meal.label}, '
          '${entries.isEmpty ? 'nothing logged' : '${kcalText(kcal)} Cal'}. '
          'Add Food to ${meal.label}',
      onTap: () => AddFoodSheet.show(context, meal: meal, day: day),
      value: entries.isEmpty
          ? StatValue('Nothing yet', size: size, placeholder: true)
          : StatValue(kcalText(kcal), unit: 'Cal', size: size),
      caption: entries.isEmpty
          ? null
          : '${entries.length} ${entries.length == 1 ? 'item' : 'items'}',
      smallVisual: addFood,
      facts: entries.isEmpty
          ? const []
          : [
              (label: 'Protein', value: '${protein.round()} g'),
              (label: 'Carbs', value: '${carbs.round()} g'),
              (label: 'Fat', value: '${fat.round()} g'),
            ],
    );
  }
}
