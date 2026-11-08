import 'dart:async';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/food.dart';
import 'package:health_app/models/meal_template.dart';
import 'package:health_app/nutrition/food_database.dart';
import 'package:health_app/nutrition/open_food_facts.dart';
import 'package:health_app/screens/food/barcode_scanner_screen.dart';
import 'package:health_app/screens/food/custom_food_sheet.dart';
import 'package:health_app/screens/food/food_cards.dart';
import 'package:health_app/screens/food/food_detail_sheet.dart';
import 'package:health_app/screens/food/meal_editors.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/nutrition_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/log.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/widgets/app_segmented.dart';
import 'package:health_app/widgets/sheet_scaffold.dart';

/// When a meal logged for an earlier day is timed.
DateTime mealTime(Meal meal, DateTime day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  if (day == today) return now;
  final (h, m) = switch (meal) {
    Meal.breakfast => (8, 0),
    Meal.lunch => (12, 30),
    Meal.dinner => (19, 0),
    Meal.snack => (15, 30),
  };
  return DateTime(day.year, day.month, day.day, h, m);
}

enum _List { recent, favorites, mine, meals }

/// Find a food to log: search, scan a barcode, saved foods or quick add.
class AddFoodSheet extends StatefulWidget {
  const AddFoodSheet({
    super.key,
    required this.meal,
    required this.day,
    required this.controller,
    this.picking = false,
  });

  final Meal meal;
  final DateTime day;
  final ScrollController controller;

  /// Choosing a food for a recipe or meal template: the sheet returns a
  /// [FoodPortion] instead of logging it.
  final bool picking;

  /// Search, scan or choose a food and amount, for a recipe or template.
  static Future<FoodPortion?> pick(BuildContext context) =>
      showCupertinoSheet<FoodPortion>(
        context: context,
        scrollableBuilder: (context, controller) => AddFoodSheet(
          meal: Meal.snack,
          day: DateTime(2000),
          controller: controller,
          picking: true,
        ),
      );

  static Future<void> show(
    BuildContext context, {
    required Meal meal,
    required DateTime day,
  }) => showCupertinoSheet<void>(
    context: context,
    scrollableBuilder: (context, controller) =>
        AddFoodSheet(meal: meal, day: day, controller: controller),
  );

  @override
  State<AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<AddFoodSheet> {
  String _query = '';
  _List _list = _List.recent;
  List<Food>? _online;
  bool _searching = false;
  String? _error;
  int _searchId = 0;

  /// Searches online once typing pauses, so Enter isn't needed. Long
  /// enough apart to stay under Open Food Facts' 10 searches a minute.
  Timer? _typing;
  static const _typingPause = Duration(milliseconds: 900);

  @override
  void dispose() {
    _typing?.cancel();
    super.dispose();
  }

  Future<void> _search() async {
    _typing?.cancel();
    final q = _query.trim();
    if (q.length < 2) return;
    final id = ++_searchId;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final found = await context.read<OpenFoodFacts>().search(q);
      if (!mounted || id != _searchId) return;
      setState(() => _online = found);
    } on FoodLookupException catch (e) {
      logError('Food search failed: $e');
      if (!mounted || id != _searchId) return;
      setState(() {
        _online = const [];
        _error = 'Couldn\'t search Open Food Facts. Check your connection.';
      });
    } finally {
      if (mounted && id == _searchId) setState(() => _searching = false);
    }
  }

  Future<void> _open(Food food) async {
    if (widget.picking) {
      final portion = await FoodDetailSheet.pick(context, food);
      if (portion != null && mounted) Navigator.of(context).pop(portion);
      return;
    }
    final added = await FoodDetailSheet.add(
      context,
      food: food,
      meal: widget.meal,
      day: widget.day,
    );
    if (added && mounted) Navigator.of(context).pop();
  }

  Future<void> _scan() async {
    final food = await BarcodeScannerScreen.scan(context);
    if (food != null && mounted) await _open(food);
  }

  Future<void> _create({bool quick = false}) async {
    final food = await CustomFoodSheet.show(context, quickAdd: quick);
    if (food != null && mounted) await _open(food);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NutritionStore>();
    final q = _query.trim().toLowerCase();
    final saved = {
      for (final f in [...store.custom, ...store.recent]) f.id: f,
    }.values;
    final local = q.isEmpty
        ? const <Food>[]
        : [
            for (final f in saved)
              if ('${f.name} ${f.brand}'.toLowerCase().contains(q)) f,
          ];
    // Instant, from the food database on the phone.
    final database = _database(context);
    final common = q.length < 2 || database == null
        ? const <Food>[]
        : [for (final f in database.search(q, limit: 15)) f.toFood()];
    final list = switch (_list) {
      _List.recent => store.recent,
      _List.favorites => store.favorites,
      _List.mine => store.custom,
      _List.meals => const <Food>[],
    };
    return SheetScaffold(
      title: widget.picking ? 'Choose a Food' : 'Add to ${widget.meal.label}',
      controller: widget.controller,
      trailing: SheetAction(
        label: 'Done',
        onPressed: () => Navigator.of(context).pop(),
      ),
      children: [
        CupertinoSearchTextField(
          placeholder: tr('Search foods'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: context.cardBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.separatorColor),
          ),
          onChanged: (v) => setState(() {
            _query = v;
            _online = null;
            _error = null;
            // A search still running is for the old text: drop it.
            _searchId++;
            _searching = false;
            _typing?.cancel();
            _typing = Timer(_typingPause, _search);
          }),
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final (i, (icon, color, label, onTap)) in [
              (Icons.qr_code_scanner_rounded, foodOrange, 'Scan', _scan),
              (
                Icons.bolt_rounded,
                Palette.yellow,
                'Quick Add',
                () => _create(quick: true),
              ),
              (Icons.edit_note_rounded, Palette.violet, 'Create', _create),
            ].indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: IosCard(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  onTap: onTap,
                  child: Column(
                    children: [
                      IconTile(icon: icon, color: color, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.footnote.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        if (q.isNotEmpty) ...[
          if (local.isNotEmpty) ...[
            const BlockLabel('Your Foods'),
            _FoodList(foods: local, onTap: _open),
          ],
          if (common.isNotEmpty) ...[
            const BlockLabel('Common Foods'),
            _FoodList(foods: common, onTap: _open),
          ],
          if (_online == null && !_searching)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: CupertinoButton.filled(
                borderRadius: BorderRadius.circular(24),
                onPressed: _search,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.travel_explore_rounded, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Search Open Food Facts for "${_query.trim()}"',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CupertinoActivityIndicator(),
            ),
          if (_error case final e?)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                e,
                textAlign: TextAlign.center,
                style: context.subheadline.copyWith(
                  color: context.secondaryLabel,
                ),
              ),
            ),
          if (_online case final found? when !_searching && _error == null) ...[
            const BlockLabel('Open Food Facts'),
            if (found.isEmpty)
              _Hint(
                'No matches. Try other words, scan the barcode, or create '
                'the food yourself.',
              )
            else
              _FoodList(foods: found, onTap: _open),
          ],
        ] else ...[
          const SizedBox(height: 16),
          AppSegmented<_List>(
            groupValue: _list,
            children: {
              _List.recent: const Text('Recent'),
              _List.favorites: const Text('Favorites'),
              _List.mine: const Text('My Foods'),
              if (!widget.picking) _List.meals: const Text('Meals'),
            },
            onValueChanged: (l) => setState(() => _list = l ?? _List.recent),
          ),
          const SizedBox(height: 12),
          if (_list == _List.meals)
            _SavedMeals(meal: widget.meal, day: widget.day)
          else if (list.isEmpty)
            _Hint(switch (_list) {
              _List.recent => 'Foods you log appear here.',
              _List.favorites => 'Tap the star on a food to keep it here.',
              _List.mine => 'Foods you create appear here.',
              _List.meals => '',
            })
          else
            _FoodList(foods: list, onTap: _open),
        ],
      ],
    );
  }
}

/// Saved meals, logged in one tap, each editable.
class _SavedMeals extends StatelessWidget {
  const _SavedMeals({required this.meal, required this.day});

  final Meal meal;
  final DateTime day;

  Future<void> _log(BuildContext context, MealTemplate t) async {
    final store = context.read<NutritionStore>();
    final navigator = Navigator.of(context);
    final date = mealTime(meal, day, context.read<HealthStore>().now);
    HapticFeedback.mediumImpact();
    // Closed first: a closing sheet ignores taps, so a quick second tap
    // can't log the meal twice.
    navigator.pop();
    await store.logTemplate(t, meal: meal, date: date);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NutritionStore>();
    Widget edit(VoidCallback onTap, String name) => CupertinoButton(
      padding: const EdgeInsets.only(left: 8),
      minimumSize: const Size.square(AppTheme.minTapTarget),
      onPressed: onTap,
      child: Icon(
        Icons.edit_rounded,
        size: 20,
        color: context.secondaryLabel,
        semanticLabel: tr('Edit $name'),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupedSection(
          header: 'Saved Meals',
          hasLeading: false,
          footer: store.templates.isEmpty
              ? 'Save foods you often eat together and log them in one tap.'
              : 'Tap a meal to add all of it to ${meal.label}.',
          children: [
            for (final t in store.templates)
              InfoRow(
                title: t.name,
                subtitle:
                    '${t.items.length} '
                    '${t.items.length == 1 ? 'food' : 'foods'} · '
                    '${kcalText(t.total.kcal)} Cal',
                onTap: () => _log(context, t),
                trailing: edit(
                  () => MealTemplateEditor.show(context, template: t),
                  t.name,
                ),
              ),
            InfoRow(
              title: 'New Meal',
              titleColor: context.tint,
              onTap: () => MealTemplateEditor.show(context),
            ),
          ],
        ),
      ],
    );
  }
}

/// A quiet message where a list would be.
class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: context.subheadline.copyWith(color: context.secondaryLabel),
    ),
  );
}

/// The food database, or null where there's none (tests, previews).
FoodDatabase? _database(BuildContext context) {
  try {
    return context.watch<FoodDatabase>();
  } on ProviderNotFoundException {
    return null;
  }
}

/// Foods in one card, each with its initial, details and calories.
class _FoodList extends StatelessWidget {
  const _FoodList({required this.foods, required this.onTap});

  final List<Food> foods;
  final ValueChanged<Food> onTap;

  @override
  Widget build(BuildContext context) => IosCard(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      children: [
        for (final (i, f) in foods.indexed) ...[
          if (i > 0)
            Container(
              height: 0.6,
              margin: const EdgeInsets.only(left: 62),
              color: context.separatorColor,
            ),
          _FoodRow(food: f, onTap: () => onTap(f)),
        ],
      ],
    ),
  );
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({required this.food, required this.onTap});

  final Food food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final orange = context.resolve(foodOrange);
    final name = food.name.trim();
    final kcal = kcalText(food.perServing.kcal);
    return Semantics(
      container: true,
      button: true,
      label: '$name, ${food.subtitle}, $kcal Cal',
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
          child: Row(
            children: [
              FoodAvatar(name: name, color: orange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      // Database names run long ("Apples, raw, with skin").
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.subheadline.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      food.subtitle,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    kcal,
                    style: context.subheadline.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Cal',
                    style: context.caption2.copyWith(
                      color: context.secondaryLabel,
                    ),
                  ),
                ],
              ),
              Icon(Icons.chevron_right_rounded, color: context.tertiaryLabel),
            ],
          ),
        ),
      ),
    );
  }
}
