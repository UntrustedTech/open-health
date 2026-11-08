import 'package:flutter/foundation.dart';

import 'package:health_app/models/food.dart';

/// A food and how much of it, as part of a template or recipe.
@immutable
class FoodPortion {
  const FoodPortion({
    required this.food,
    required this.amount,
    this.inGrams = false,
  });

  final Food food;

  /// Servings, or grams (millilitres) when [inGrams].
  final double amount;
  final bool inGrams;

  Nutrients get nutrients => food.nutrientsFor(amount, inGrams: inGrams);

  /// Grams (or ml) in this portion, when known.
  double? get grams {
    if (inGrams) return amount;
    final g = food.servingGrams;
    return g == null ? null : g * amount;
  }

  Map<String, Object?> toJson() => {
    'food': food.toJson(),
    'amount': amount,
    if (inGrams) 'g': true,
  };

  static FoodPortion? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final food = Food.tryFromJson(json['food']);
    final amount = json['amount'];
    if (food == null || amount is! num || !amount.isFinite) return null;
    if (amount <= 0 || amount > 10000) return null;
    final inGrams = json['g'] == true;
    if (inGrams && food.servingGrams == null) return null;
    return FoodPortion(food: food, amount: amount.toDouble(), inGrams: inGrams);
  }
}

/// A saved meal ("My usual breakfast"): several foods logged in one tap.
@immutable
class MealTemplate {
  const MealTemplate({
    required this.id,
    required this.name,
    required this.items,
  });

  static const maxItems = 30;

  final String id;
  final String name;
  final List<FoodPortion> items;

  Nutrients get total =>
      items.fold(Nutrients.zero, (sum, i) => sum + i.nutrients);

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'items': [for (final i in items) i.toJson()],
  };

  static MealTemplate? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'], name = json['name'], items = json['items'];
    if (id is! String || id.isEmpty || name is! String || items is! List) {
      return null;
    }
    final portions = items
        .map(FoodPortion.fromJson)
        .nonNulls
        .take(maxItems)
        .toList();
    if (portions.isEmpty) return null;
    return MealTemplate(
      id: id,
      name: name.trim().isEmpty ? 'Meal' : name.trim(),
      items: List.unmodifiable(portions),
    );
  }
}

/// A home-made dish: ingredients that make a number of servings. Saved as
/// a food whose serving is one portion of the dish.
@immutable
class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.servings,
    required this.ingredients,
  });

  static const maxIngredients = 50;
  static const maxServings = 100;

  final String id;
  final String name;
  final int servings;
  final List<FoodPortion> ingredients;

  Nutrients get total =>
      ingredients.fold(Nutrients.zero, (sum, i) => sum + i.nutrients);

  Nutrients get perServing => total * (1 / servings);

  /// Weight of one serving, when every ingredient's weight is known.
  double? get servingGrams {
    var grams = 0.0;
    for (final i in ingredients) {
      final g = i.grams;
      if (g == null) return null;
      grams += g;
    }
    return grams <= 0 ? null : grams / servings;
  }

  /// The food logged from this recipe (same id, so it updates in place).
  Food toFood() {
    final g = servingGrams;
    return Food(
      id: id,
      name: name,
      perServing: perServing,
      servingLabel: g == null ? '1 serving' : '1 serving (${g.round()} g)',
      servingGrams: g,
      brand: 'Recipe',
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'servings': servings,
    'items': [for (final i in ingredients) i.toJson()],
  };

  static Recipe? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'], name = json['name'];
    final servings = json['servings'], items = json['items'];
    if (id is! String || id.isEmpty || name is! String) return null;
    if (servings is! int || servings < 1 || servings > maxServings) return null;
    if (items is! List) return null;
    final list = items
        .map(FoodPortion.fromJson)
        .nonNulls
        .take(maxIngredients)
        .toList();
    if (list.isEmpty) return null;
    return Recipe(
      id: id,
      name: name.trim().isEmpty ? 'Recipe' : name.trim(),
      servings: servings,
      ingredients: List.unmodifiable(list),
    );
  }
}
