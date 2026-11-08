import 'package:flutter/foundation.dart';

import 'package:health_app/models/food.dart';
import 'package:health_app/models/meal_template.dart';
import 'package:health_app/models/health_entry.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/nutrition/calorie_estimate.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/utils/log.dart';

/// The food diary: what was eaten, saved foods and calorie goals. Each
/// entry also adds its calories and macros to Health (as "Food Diary"
/// entries), so they appear in the Nutrition charts.
class NutritionStore extends ChangeNotifier {
  /// Changes on every update, so derived results can be cached.
  int get revision => _revision;
  int _revision = 0;

  @override
  void notifyListeners() {
    _revision++;
    super.notifyListeners();
  }

  NutritionStore(this._health);

  static const docKey = 'nutrition';

  /// Diary entries are kept this long.
  static const _keepDays = 400;
  static const _maxRecent = 40;

  final HealthStore _health;

  List<FoodEntry> _entries = [];
  List<Food> _recent = [];
  List<Food> _custom = [];
  List<MealTemplate> _templates = [];
  List<Recipe> _recipes = [];
  Set<String> _favorites = {};
  NutritionGoals _goals = const NutritionGoals();
  bool _readable = true;
  int _idCounter = 0;

  NutritionGoals get goals => _goals;
  List<Food> get recent => List.unmodifiable(_recent);
  List<Food> get custom => List.unmodifiable(_custom);
  List<MealTemplate> get templates => List.unmodifiable(_templates);
  List<Recipe> get recipes => List.unmodifiable(_recipes);

  Recipe? recipeFor(String foodId) =>
      _recipes.where((r) => r.id == foodId).firstOrNull;

  /// Favorite foods, each once (a food can be both saved and recent).
  List<Food> get favorites => {
    for (final f in [..._custom, ..._recent])
      if (_favorites.contains(f.id)) f.id: f,
  }.values.toList();
  bool isFavorite(Food f) => _favorites.contains(f.id);

  String newId(String prefix) =>
      '$prefix${_health.now.microsecondsSinceEpoch}${_idCounter++}';

  Future<void> load() async {
    _clear();
    try {
      final doc = await _health.loadDocument(docKey);
      List<Object?> list(String k) => switch (doc?[k]) {
        final List<Object?> l => l,
        _ => const [],
      };
      _entries = list('entries').map(FoodEntry.tryFromJson).nonNulls.toList();
      _recent = list('recent').map(Food.tryFromJson).nonNulls.toList();
      _custom = list('custom').map(Food.tryFromJson).nonNulls.toList();
      _favorites = list('favorites').whereType<String>().toSet();
      _templates = list('templates')
          .map(MealTemplate.fromJson)
          .nonNulls
          .toList();
      _recipes = list('recipes').map(Recipe.fromJson).nonNulls.toList();
      _goals = NutritionGoals.fromJson(doc?['goals']);
      if (_goals.includesActivity == null) {
        // Worked out once and saved, so the budget can't change from one
        // launch to the next.
        _goals = _goals.copyWith(includesActivity: _guessIncludesActivity());
        guessedIncludesActivity = true;
      }
    } on Exception catch (e) {
      _readable = false;
      logError('Nutrition: could not load: $e');
    }
    notifyListeners();
  }

  /// For goals saved before it was recorded: whether the goal is nearer
  /// the estimate that already counts everyday activity than the one that
  /// adds measured activity as it happens. A goal that can't be compared
  /// (e.g. the 2,000 kcal default) counts as including activity.
  bool _guessIncludesActivity() {
    final activity = _health.recentActivity();
    CalorieEstimate? estimate({required bool counted}) =>
        CalorieEstimate.estimate(
          profile: _health.profile,
          weightKg: _health.latestReading(MetricType.weight)?.value,
          today: _health.today,
          goal: _health.bodyGoal,
          exerciseAdded: counted,
          averageSteps: activity.averageSteps,
          activeDays: activity.activeDays,
        );
    final counting = estimate(counted: true);
    final level = estimate(counted: false);
    if (counting == null || level == null || !counting.countsExercise) {
      return true;
    }
    return (_goals.kcal - level.target).abs() <=
        (_goals.kcal - counting.target).abs();
  }

  /// Rebuilds budgets (e.g. after a workout is saved or deleted).
  void refresh() => notifyListeners();

  /// Set when [load] filled in includesActivity for an older goal; the app
  /// saves it once (see [saveGuessedGoal]).
  bool guessedIncludesActivity = false;

  /// Saves an includesActivity worked out while loading.
  Future<void> saveGuessedGoal() async {
    if (!guessedIncludesActivity || !_readable) return;
    guessedIncludesActivity = false;
    await _save();
  }

  /// Every logged entry (for achievements).
  List<FoodEntry> get all => List.unmodifiable(_entries);

  /// Entries on [day], in time order.
  List<FoodEntry> entriesOn(DateTime day) =>
      _entries
          .where(
            (e) =>
                e.date.year == day.year &&
                e.date.month == day.month &&
                e.date.day == day.day,
          )
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  Nutrients totalOn(DateTime day) =>
      entriesOn(day).fold(Nutrients.zero, (sum, e) => sum + e.nutrients);

  /// Calories burned in workouts on a day (set by the app; tests may
  /// leave it unset).
  double Function(DateTime day)? workoutKcalOn;

  /// Whether the calorie goal already covers everyday activity.
  bool get goalIncludesActivity => _goals.includesActivity ?? true;

  /// Calories added to [day]'s budget for moving: nothing when off; only
  /// workouts when the goal already allows for everyday activity; else
  /// all measured active energy.
  double burnedOn(DateTime day) {
    if (!_goals.addExercise) return 0;
    if (goalIncludesActivity) return workoutKcalOn?.call(day) ?? 0;
    return _health.dailyValue(MetricType.activeEnergy, day) ?? 0;
  }

  /// The day's calorie budget: goal plus [burnedOn].
  double budgetOn(DateTime day) => _goals.kcal + burnedOn(day);

  /// Calories still available on [day].
  double remainingOn(DateTime day) => budgetOn(day) - totalOn(day).kcal;

  Future<void> add(FoodEntry entry) async {
    // Defence in depth: never keep values that can't be saved.
    if (!entry.nutrients.isFinite) return;
    _entries = [..._entries, entry];
    _remember(entry.food);
    notifyListeners();
    // The diary first: if the app is closed between the two writes, the
    // food can still be found and deleted, with its linked entries.
    await _save();
    await _health.addEntries(_linked(entry));
  }

  /// Adds entries from another app in one save, skipping ones already
  /// here and ones older than the diary keeps. How many were added.
  Future<int> importEntries(List<FoodEntry> entries) async {
    final have = {for (final e in _entries) e.id};
    final now = _health.now;
    final oldest = DateTime(now.year, now.month, now.day - _keepDays);
    final added = [
      for (final e in entries)
        if (!have.contains(e.id) &&
            e.nutrients.isFinite &&
            e.date.isAfter(oldest))
          e,
    ];
    if (added.isEmpty) return 0;
    _entries = [..._entries, ...added];
    notifyListeners();
    await _save();
    await _health.addEntries([for (final e in added) ..._linked(e)]);
    return added.length;
  }

  Future<void> update(FoodEntry entry) async {
    if (!entry.nutrients.isFinite) return;
    _entries = [for (final e in _entries) e.id == entry.id ? entry : e];
    notifyListeners();
    await _save();
    await _health.removeEntriesWithPrefix(_prefix(entry.id));
    await _health.addEntries(_linked(entry));
  }

  Future<void> delete(String id) async {
    _entries = _entries.where((e) => e.id != id).toList();
    notifyListeners();
    await _health.removeEntriesWithPrefix(_prefix(id));
    await _save();
  }

  Future<void> saveCustom(Food food) async {
    if (!food.perServing.isFinite) return;
    _custom = [food, ..._custom.where((f) => f.id != food.id)];
    _replaceRecent(food);
    notifyListeners();
    await _save();
  }

  /// Recent (and so favorites and search) show the food as it is now.
  void _replaceRecent(Food food) {
    _recent = [for (final f in _recent) f.id == food.id ? food : f];
  }

  Future<void> deleteCustom(String id) async {
    _custom = _custom.where((f) => f.id != id).toList();
    // Gone from Recent too, so it can't be logged again by mistake.
    _recent = _recent.where((f) => f.id != id).toList();
    // A recipe's food goes with its recipe.
    _recipes = _recipes.where((r) => r.id != id).toList();
    _favorites = {..._favorites}..remove(id);
    notifyListeners();
    await _save();
  }

  /// Saves (or replaces) a meal template.
  Future<void> saveTemplate(MealTemplate template) async {
    _templates = [template, ..._templates.where((t) => t.id != template.id)];
    notifyListeners();
    await _save();
  }

  Future<void> deleteTemplate(String id) async {
    _templates = _templates.where((t) => t.id != id).toList();
    notifyListeners();
    await _save();
  }

  /// Logs every food in [template] to [meal] at [date].
  Future<void> logTemplate(
    MealTemplate template, {
    required Meal meal,
    required DateTime date,
  }) async {
    for (final item in template.items) {
      await add(
        FoodEntry(
          id: newId('f'),
          food: item.food,
          amount: item.amount,
          inGrams: item.inGrams,
          date: date,
          meal: meal,
        ),
      );
    }
  }

  /// Saves a recipe and the food logged from it (same id).
  Future<void> saveRecipe(Recipe recipe) async {
    final food = recipe.toFood();
    if (!food.perServing.isFinite) return;
    _recipes = [recipe, ..._recipes.where((r) => r.id != recipe.id)];
    _custom = [food, ..._custom.where((f) => f.id != food.id)];
    _replaceRecent(food);
    notifyListeners();
    await _save();
  }

  Future<void> deleteRecipe(String id) async {
    _recipes = _recipes.where((r) => r.id != id).toList();
    await deleteCustom(id);
  }

  Future<void> toggleFavorite(Food food) async {
    final next = {..._favorites};
    if (!next.remove(food.id)) {
      next.add(food.id);
      _remember(food);
    }
    _favorites = next;
    notifyListeners();
    await _save();
  }

  Future<void> setGoals(NutritionGoals goals) async {
    _goals = goals;
    notifyListeners();
    await _save();
  }

  /// Forgets recently eaten foods (favorites and saved foods stay).
  Future<void> clearRecent() async {
    _recent = _recent.where((f) => _favorites.contains(f.id)).toList();
    notifyListeners();
    await _save();
  }

  void _clear() {
    _entries = [];
    _recent = [];
    _custom = [];
    _templates = [];
    _recipes = [];
    _favorites = {};
    _goals = const NutritionGoals();
    _readable = true;
  }

  /// Clears memory after "Erase All".
  void reset() {
    _clear();
    notifyListeners();
  }

  void _remember(Food food) {
    if (food.source == FoodSource.quickAdd) return;
    _recent = [
      food,
      ..._recent.where((f) => f.id != food.id),
    ].take(_maxRecent).toList();
  }

  static String _prefix(String entryId) => 'food:$entryId:';

  /// Health entries carrying this food's calories and macros.
  List<HealthEntry> _linked(FoodEntry e) {
    final n = e.nutrients;
    HealthEntry h(MetricType t, double v) => HealthEntry(
      id: '${_prefix(e.id)}${t.name}',
      type: t,
      value: double.parse(v.toStringAsFixed(1)),
      date: e.date,
      source: EntrySource.food,
    );
    return [
      h(MetricType.dietaryEnergy, n.kcal),
      if (n.protein > 0) h(MetricType.protein, n.protein),
      if (n.carbs > 0) h(MetricType.carbs, n.carbs),
      if (n.fat > 0) h(MetricType.fat, n.fat),
    ];
  }

  Future<void> _save() async {
    if (!_readable) {
      logError('Nutrition: not saving over data that could not be read');
      return;
    }
    final now = _health.now;
    final oldest = DateTime(now.year, now.month, now.day - _keepDays);
    _entries = _entries.where((e) => e.date.isAfter(oldest)).toList();
    await _health.saveDocument(docKey, {
      'entries': [for (final e in _entries) e.toJson()],
      'recent': [for (final f in _recent) f.toJson()],
      'custom': [for (final f in _custom) f.toJson()],
      'templates': [for (final t in _templates) t.toJson()],
      'recipes': [for (final r in _recipes) r.toJson()],
      'favorites': _favorites.toList()..sort(),
      'goals': _goals.toJson(),
    });
  }
}
