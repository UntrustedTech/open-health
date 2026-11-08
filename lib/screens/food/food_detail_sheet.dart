import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/widgets/number_input.dart';
import 'package:health_app/models/food.dart';
import 'package:health_app/models/meal_template.dart';
import 'package:health_app/screens/food/add_food_sheet.dart';
import 'package:health_app/screens/food/food_cards.dart';
import 'package:health_app/screens/food/micronutrient_widgets.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/nutrition_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/app_segmented.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/widgets/sheet_scaffold.dart';

/// A food's nutrition facts, how much was eaten and in which meal.
class FoodDetailSheet extends StatefulWidget {
  const FoodDetailSheet({
    super.key,
    required this.food,
    required this.meal,
    required this.day,
    required this.controller,
    this.entry,
    this.picking = false,
  });

  /// Choosing an amount for a recipe or meal template: the sheet returns
  /// a [FoodPortion] instead of logging the food.
  final bool picking;

  final Food food;
  final Meal meal;
  final DateTime day;
  final ScrollController controller;

  /// When editing an entry already in the diary.
  final FoodEntry? entry;

  /// Returns true when the food was added.
  static Future<bool> add(
    BuildContext context, {
    required Food food,
    required Meal meal,
    required DateTime day,
  }) async =>
      await showCupertinoSheet<bool>(
        context: context,
        scrollableBuilder: (context, controller) => FoodDetailSheet(
          food: food,
          meal: meal,
          day: day,
          controller: controller,
        ),
      ) ??
      false;

  /// Asks how much of [food] (for a recipe or template). Null if
  /// cancelled.
  static Future<FoodPortion?> pick(BuildContext context, Food food) =>
      showCupertinoSheet<FoodPortion>(
        context: context,
        scrollableBuilder: (context, controller) => FoodDetailSheet(
          food: food,
          meal: Meal.snack,
          day: DateTime(2000),
          controller: controller,
          picking: true,
        ),
      );

  static Future<void> edit(BuildContext context, FoodEntry entry) =>
      showCupertinoSheet<bool>(
        context: context,
        scrollableBuilder: (context, controller) => FoodDetailSheet(
          food: entry.food,
          meal: entry.meal,
          day: entry.date,
          entry: entry,
          controller: controller,
        ),
      );

  @override
  State<FoodDetailSheet> createState() => _FoodDetailSheetState();
}

class _FoodDetailSheetState extends State<FoodDetailSheet> {
  late bool _grams = widget.entry?.inGrams ?? false;
  late double _amount = widget.entry?.amount ?? 1;
  late Meal _meal = widget.meal;
  late final _amountText = TextEditingController(text: _fmt(_shown));

  /// Set while saving or deleting, so a double tap acts once.
  bool _busy = false;

  Food get food => widget.food;
  bool get _canGrams => food.servingGrams != null;

  /// Drinks in fluid ounces for imperial users; amounts are kept in ml.
  bool get _ounces => _grams && food.liquid && Units.imperial;

  /// Base units (g or ml) per unit shown.
  double get _factor => _ounces ? Units.mlPerFlOz : 1;

  /// [_amount] in the units shown.
  double get _shown => _amount / _factor;

  /// How much the − and + buttons change the base amount.
  double get _step =>
      _grams ? (_ounces ? Units.mlPerFlOz : 10) : (_amount > 1 ? 1 : 0.25);

  String get _measureName => !food.liquid
      ? 'Grams'
      : Units.imperial
      ? 'Fl Oz'
      : 'Millilitres';

  static String _fmt(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

  @override
  void dispose() {
    _amountText.dispose();
    super.dispose();
  }

  void _setAmount(double v, {bool updateText = true}) {
    final max = _grams ? 5000.0 : 50.0;
    final clamped = v.clamp(0, max).toDouble();
    setState(() => _amount = clamped);
    // Typed values over the limit are corrected in the field too, so it
    // never shows an amount other than the one that will be logged.
    if (updateText || clamped != v) _amountText.text = _fmt(_shown);
  }

  void _switchUnit(bool grams) {
    if (grams == _grams) return;
    final g = food.servingGrams ?? 100;
    // Keep the same quantity of food when switching.
    final next = grams ? _amount * g : _amount / g;
    setState(() => _grams = grams);
    // Fluid ounces keep the exact amount (shown to one decimal), so
    // switching back and forth never changes what's logged.
    final rounded = _ounces
        ? next
        : double.parse(next.toStringAsFixed(grams ? 0 : 2));
    _setAmount(rounded);
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_amount <= 0) {
      HapticFeedback.heavyImpact();
      await showMessage(
        context,
        title: 'Enter an Amount',
        message: 'Enter how much you had, more than zero.',
      );
      return;
    }
    if (widget.picking) {
      HapticFeedback.selectionClick();
      Navigator.of(context)
          .pop(FoodPortion(food: food, amount: _amount, inGrams: _grams));
      return;
    }
    setState(() => _busy = true);
    final store = context.read<NutritionStore>();
    final navigator = Navigator.of(context);
    HapticFeedback.mediumImpact();
    final entry = widget.entry;
    final now = context.read<HealthStore>().now;
    try {
      if (entry != null) {
        await store.update(
          entry.copyWith(amount: _amount, inGrams: _grams, meal: _meal),
        );
      } else {
        await store.add(
          FoodEntry(
            id: store.newId('f'),
            food: food,
            amount: _amount,
            inGrams: _grams,
            date: mealTime(_meal, widget.day, now),
            meal: _meal,
          ),
        );
      }
    } finally {
      // A failed save leaves the sheet usable to try again.
      if (mounted) setState(() => _busy = false);
    }
    // Swiped away meanwhile: popping now would close the screen below.
    if (mounted) navigator.pop(true);
  }

  Future<void> _delete() async {
    final entry = widget.entry;
    if (entry == null || _busy) return;
    setState(() => _busy = true);
    final store = context.read<NutritionStore>();
    final navigator = Navigator.of(context);
    try {
      await store.delete(entry.id);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) navigator.pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NutritionStore>();
    final n = food.nutrientsFor(_amount, inGrams: _grams);
    final editing = widget.entry != null;
    final picking = widget.picking;
    return SheetScaffold(
      title: picking
          ? 'Add Ingredient'
          : editing
          ? 'Edit Food'
          : 'Add Food',
      controller: widget.controller,
      leading: SheetAction(
        label: 'Cancel',
        onPressed: () => Navigator.of(context).pop(picking ? null : false),
      ),
      trailing: SheetAction(
        label: editing ? 'Save' : 'Add',
        primary: true,
        onPressed: _busy ? null : _save,
      ),
      children: [
        _FoodHero(
          food: food,
          nutrients: n,
          favorite: store.isFavorite(food),
          onFavorite: food.source == FoodSource.quickAdd
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  store.toggleFavorite(food);
                },
        ),
        const BlockLabel('Amount'),
        IosCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              if (_canGrams) ...[
                AppSegmented<bool>(
                  groupValue: _grams,
                  children: {
                    false: const Text('Servings'),
                    true: Text(_measureName),
                  },
                  onValueChanged: (g) => _switchUnit(g ?? false),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  _RoundButton(
                    icon: Icons.remove_rounded,
                    label: 'Less',
                    onTap: () => _setAmount(_amount - _step),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        CupertinoTextField.borderless(
                          controller: _amountText,
                          textAlign: TextAlign.center,
                          style: context.number(34, weight: FontWeight.w700),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: numberInput(),
                          onChanged: (t) => _setAmount(
                            (double.tryParse(t.replaceAll(',', '.')) ?? 0) *
                                _factor,
                            updateText: false,
                          ),
                        ),
                        Text(
                          _grams
                              ? (_ounces
                                    ? 'fl oz'
                                    : food.liquid
                                    ? 'ml'
                                    : 'grams')
                              : '× ${food.displayServing}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.footnote.copyWith(
                            color: context.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _RoundButton(
                    icon: Icons.add_rounded,
                    label: 'More',
                    onTap: () => _setAmount(
                      _amount + (_grams ? _step : (_amount >= 1 ? 1 : 0.25)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!picking) ...[
          const BlockLabel('Meal'),
          Row(
            children: [
              for (final (i, m) in Meal.values.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _MealChoice(
                    meal: m,
                    selected: m == _meal,
                    onTap: () => setState(() => _meal = m),
                  ),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 16),
        NutritionFacts(nutrients: n, accent: context.resolve(foodOrange)),
        if (n.micros.isNotEmpty) ...[
          const SizedBox(height: 12),
          MicronutrientCard(amounts: n.micros),
        ],
        if (food.source == FoodSource.database)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Text(
              'From the Health food database (USDA FoodData Central). '
              'Values are typical; brands and recipes vary.',
              style: context.footnote.copyWith(color: context.secondaryLabel),
            ),
          ),
        if (food.source == FoodSource.openFoodFacts)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Text(
              'From Open Food Facts, which anyone can edit, so it may be '
              'wrong. Always check the label, especially for allergens.',
              style: context.footnote.copyWith(color: context.secondaryLabel),
            ),
          ),
        if (editing)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: CupertinoButton(
              onPressed: _busy ? null : _delete,
              child: Text(
                'Remove from Diary',
                style: context.subheadline.copyWith(
                  color: context.destructive,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The food's name, brand and favourite star, with the calories and
/// macro split for the amount chosen.
class _FoodHero extends StatelessWidget {
  const _FoodHero({
    required this.food,
    required this.nutrients,
    required this.favorite,
    required this.onFavorite,
  });

  final Food food;
  final Nutrients nutrients;
  final bool favorite;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    final n = nutrients;
    final onFavorite = this.onFavorite;
    final yellow = context.resolve(Palette.yellow);
    return IosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(food.name, style: context.title2),
                    if (food.brand.isNotEmpty)
                      Text(
                        food.brand,
                        style: context.subheadline.copyWith(
                          color: context.secondaryLabel,
                        ),
                      ),
                    if (food.barcode case final b?)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Icon(
                              Icons.qr_code_scanner_rounded,
                              size: 14,
                              color: context.tertiaryLabel,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Barcode $b',
                                style: context.caption1.copyWith(
                                  color: context.tertiaryLabel,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (onFavorite != null)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size.square(AppTheme.minTapTarget),
                  onPressed: onFavorite,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: ShapeDecoration(
                      color: favorite
                          ? yellow.withValues(alpha: 0.18)
                          : context.fillColor,
                      shape: const CircleBorder(),
                    ),
                    child: Icon(
                      favorite ? Icons.star_rounded : Icons.star_border_rounded,
                      color: favorite ? yellow : context.secondaryLabel,
                      semanticLabel: favorite
                          ? 'Remove from favorites'
                          : 'Add to favorites',
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                kcalText(n.kcal),
                style: context.number(40, weight: FontWeight.w700),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 7),
                child: Text(
                  'Cal',
                  style: context.subheadline.copyWith(
                    color: context.secondaryLabel,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          MacroSplit(nutrients: n),
        ],
      ),
    );
  }
}

/// Grams to one decimal, or whole grams from 10.
String _gramsText(double v) =>
    v >= 10 ? '${v.round()} g' : '${v.toStringAsFixed(1)} g';

/// Where the calories come from: a bar split by protein, carbs and fat,
/// with each one's grams underneath.
class MacroSplit extends StatelessWidget {
  const MacroSplit({super.key, required this.nutrients});

  final Nutrients nutrients;

  @override
  Widget build(BuildContext context) {
    final n = nutrients;
    // Calories per gram: protein and carbs 4, fat 9.
    final parts = [
      ('Protein', n.protein, n.protein * 4, context.resolve(proteinColor)),
      ('Carbs', n.carbs, n.carbs * 4, context.resolve(carbsColor)),
      ('Fat', n.fat, n.fat * 9, context.resolve(fatColor)),
    ];
    final total = parts.fold<double>(0, (s, p) => s + p.$3);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: total <= 0
                ? ColoredBox(color: context.fillColor)
                : Row(
                    children: [
                      for (final (i, (_, _, kcal, color)) in parts.indexed)
                        if (kcal > 0)
                          Expanded(
                            flex: (kcal / total * 1000).round().clamp(1, 1000),
                            child: Container(
                              margin: EdgeInsets.only(left: i > 0 ? 2 : 0),
                              color: color,
                            ),
                          ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (label, grams, _, color) in parts)
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '$label ${_gramsText(grams)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.caption1.copyWith(
                          color: context.secondaryLabel,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// A meal to log to: its icon and name, filled with its colour when
/// chosen.
class _MealChoice extends StatelessWidget {
  const _MealChoice({
    required this.meal,
    required this.selected,
    required this.onTap,
  });

  final Meal meal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.resolve(meal.color);
    void tap() {
      HapticFeedback.selectionClick();
      onTap();
    }

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: meal.label,
      onTap: tap,
      excludeSemantics: true,
      child: Pressable(
        onTap: tap,
        child: AnimatedContainer(
          duration: Motion.reduced(context) ? Duration.zero : Motion.fast,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: ShapeDecoration(
            color: selected
                ? color.withValues(alpha: context.isDark ? 0.22 : 0.16)
                : context.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: selected ? color : context.separatorColor,
                width: selected ? 1.5 : 0.8,
              ),
            ),
          ),
          child: Column(
            children: [
              Icon(
                meal.icon,
                size: 22,
                color: selected ? color : context.secondaryLabel,
              ),
              const SizedBox(height: 4),
              Text(
                meal.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.caption1.copyWith(
                  color: selected ? color : context.secondaryLabel,
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

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = context.tint;
    void tap() {
      HapticFeedback.selectionClick();
      onTap();
    }

    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: tap,
      excludeSemantics: true,
      child: Pressable(
        onTap: tap,
        child: Container(
          width: 48,
          height: 48,
          decoration: ShapeDecoration(
            color: tint.withValues(alpha: context.isDark ? 0.16 : 0.12),
            shape: CircleBorder(
              side: BorderSide(color: tint.withValues(alpha: 0.35)),
            ),
          ),
          child: Icon(icon, color: tint),
        ),
      ),
    );
  }
}

/// The food's nutrition label, grouped like the one on the package.
class NutritionFacts extends StatelessWidget {
  const NutritionFacts({
    super.key,
    required this.nutrients,
    required this.accent,
  });

  final Nutrients nutrients;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final n = nutrients;
    Widget row(
      String label,
      String value, {
      bool bold = false,
      bool indent = false,
      Color? dot,
    }) => Padding(
      padding: EdgeInsets.fromLTRB(indent ? 18 : 0, 9, 0, 9),
      child: Row(
        children: [
          if (dot != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: context.resolve(dot),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: (indent ? context.footnote : context.subheadline).copyWith(
                color: indent ? context.secondaryLabel : null,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: context.subheadline.copyWith(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    Widget line() => Container(height: 0.6, color: context.separatorColor);
    return Semantics(
      label:
          'Nutrition facts: ${n.kcal.round()} calories, ${_gramsText(n.protein)} protein, '
          '${_gramsText(n.carbs)} carbohydrates, ${_gramsText(n.fat)} fat',
      excludeSemantics: true,
      child: IosCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconTile(
                  icon: Icons.receipt_long_rounded,
                  color: accent,
                  size: 32,
                ),
                const SizedBox(width: 10),
                Text('Nutrition Facts', style: context.headline),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: ShapeDecoration(
                color: accent.withValues(alpha: context.isDark ? 0.14 : 0.10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Calories',
                      style: context.headline.copyWith(color: accent),
                    ),
                  ),
                  Text(
                    '${n.kcal.round()}',
                    style: context
                        .number(28, weight: FontWeight.w700)
                        .copyWith(color: accent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            row('Total Fat', _gramsText(n.fat), bold: true, dot: fatColor),
            row('Saturated Fat', _gramsText(n.saturatedFat), indent: true),
            line(),
            row(
              'Total Carbohydrate',
              _gramsText(n.carbs),
              bold: true,
              dot: carbsColor,
            ),
            row('Dietary Fiber', _gramsText(n.fiber), indent: true),
            row('Total Sugars', _gramsText(n.sugar), indent: true),
            line(),
            row(
              'Protein',
              _gramsText(n.protein),
              bold: true,
              dot: proteinColor,
            ),
            line(),
            row('Sodium', '${n.sodiumMg.round()} mg', bold: true),
          ],
        ),
      ),
    );
  }
}
