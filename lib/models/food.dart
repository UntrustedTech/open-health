import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;

import 'package:health_app/models/micronutrient.dart';
import 'package:health_app/utils/units.dart';

/// Nutrition for some amount of food. Energy in kcal, masses in grams,
/// sodium in milligrams, vitamins and minerals in their own units. Unknown
/// values are 0 (vitamins and minerals: left out).
@immutable
class Nutrients {
  const Nutrients({
    this.kcal = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.sugar = 0,
    this.saturatedFat = 0,
    this.sodiumMg = 0,
    this.micros = const {},
  });

  static const zero = Nutrients();

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double saturatedFat;
  final double sodiumMg;

  /// Vitamins and minerals that are known, in each one's unit.
  final Map<Micronutrient, double> micros;

  /// False if any value is NaN or infinite (never stored).
  bool get isFinite => [
    kcal,
    protein,
    carbs,
    fat,
    fiber,
    sugar,
    saturatedFat,
    sodiumMg,
    ...micros.values,
  ].every((v) => v.isFinite);

  Nutrients operator *(double f) => Nutrients(
    kcal: kcal * f,
    protein: protein * f,
    carbs: carbs * f,
    fat: fat * f,
    fiber: fiber * f,
    sugar: sugar * f,
    saturatedFat: saturatedFat * f,
    sodiumMg: sodiumMg * f,
    micros: {for (final e in micros.entries) e.key: e.value * f},
  );

  Nutrients operator +(Nutrients o) => Nutrients(
    kcal: kcal + o.kcal,
    protein: protein + o.protein,
    carbs: carbs + o.carbs,
    fat: fat + o.fat,
    fiber: fiber + o.fiber,
    sugar: sugar + o.sugar,
    saturatedFat: saturatedFat + o.saturatedFat,
    sodiumMg: sodiumMg + o.sodiumMg,
    micros: {
      for (final m in {...micros.keys, ...o.micros.keys})
        m: (micros[m] ?? 0) + (o.micros[m] ?? 0),
    },
  );

  Map<String, Object?> toJson() => {
    'kcal': _r(kcal),
    if (protein > 0) 'p': _r(protein),
    if (carbs > 0) 'c': _r(carbs),
    if (fat > 0) 'f': _r(fat),
    if (fiber > 0) 'fi': _r(fiber),
    if (sugar > 0) 's': _r(sugar),
    if (saturatedFat > 0) 'sf': _r(saturatedFat),
    if (sodiumMg > 0) 'na': _r(sodiumMg),
    if (micros.isNotEmpty)
      'm': {
        for (final e in micros.entries)
          if (e.value > 0) e.key.key: _r3(e.value),
      },
  };

  static double _r(double v) => (v * 100).roundToDouble() / 100;

  // Some are tiny (0.002 mg); kept to 3 decimals.
  static double _r3(double v) => (v * 1000).roundToDouble() / 1000;

  /// Vitamins and minerals from their saved form (`{"c": 12.5}`); bad or
  /// unknown entries are left out.
  static Map<Micronutrient, double> microsFromJson(Object? json) {
    if (json is! Map) return const {};
    return {
      for (final e in json.entries)
        if (e.key is String)
          if (Micronutrient.byKey(e.key as String) case final m?)
            if (e.value case final num v
                when v.isFinite && v > 0 && v <= m.maxPer100g * 100)
              m: v.toDouble(),
    };
  }

  static Nutrients fromJson(Object? json) {
    if (json is! Map<String, Object?>) return zero;
    double n(String k, double max) => switch (json[k]) {
      final num v when v.isFinite && v >= 0 => v.toDouble().clamp(0, max),
      _ => 0,
    };
    return Nutrients(
      kcal: n('kcal', 20000),
      protein: n('p', 2000),
      carbs: n('c', 2000),
      fat: n('f', 2000),
      fiber: n('fi', 2000),
      sugar: n('s', 2000),
      saturatedFat: n('sf', 2000),
      sodiumMg: n('na', 100000),
      micros: microsFromJson(json['m']),
    );
  }
}

/// Where a food came from.
/// [database]: the Health food database on GitHub (see FoodDatabase).
enum FoodSource { openFoodFacts, custom, quickAdd, database }

/// A food with its nutrition per serving.
@immutable
class Food {
  const Food({
    required this.id,
    required this.name,
    required this.perServing,
    this.brand = '',
    this.barcode,
    this.servingLabel = '1 serving',
    this.servingGrams,
    this.source = FoodSource.custom,
    this.liquid = false,
  });

  /// A drink: amounts are millilitres rather than grams (and fluid ounces
  /// for imperial users).
  final bool liquid;

  /// The serving in the user's units ("250 ml" → "8.5 fl oz").
  String get displayServing => localizeVolume(servingLabel);

  /// "g" or "ml".
  String get measureUnit => liquid ? 'ml' : 'g';

  final String id;
  final String name;
  final String brand;
  final String? barcode;

  /// e.g. "1 bar (40 g)" or "100 g".
  final String servingLabel;

  /// Grams (millilitres for a drink) in one serving, when known (lets
  /// amounts be entered by weight or volume).
  final double? servingGrams;
  final Nutrients perServing;
  final FoodSource source;

  String get subtitle =>
      [if (brand.isNotEmpty) brand, displayServing].join(' · ');

  /// Nutrition for [amount] servings, or grams when [inGrams].
  Nutrients nutrientsFor(double amount, {bool inGrams = false}) {
    final grams = servingGrams;
    if (inGrams) {
      // Without a serving weight grams can't be converted; never read
      // "150 g" as 150 servings.
      if (grams == null || grams <= 0) return const Nutrients();
      return perServing * (amount / grams);
    }
    return perServing * amount;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    if (brand.isNotEmpty) 'brand': brand,
    'barcode': ?barcode,
    'serving': servingLabel,
    'grams': ?servingGrams,
    'n': perServing.toJson(),
    'src': source.name,
    if (liquid) 'liq': true,
  };

  static Food? tryFromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'], name = json['name'];
    if (id is! String || id.isEmpty || id.length > 80) return null;
    if (name is! String || name.trim().isEmpty) return null;
    String text(String k, int max) => switch (json[k]) {
      final String s => s.length > max ? s.substring(0, max) : s,
      _ => '',
    };
    final grams = json['grams'];
    final code = json['barcode'];
    return Food(
      id: id,
      name: name.length > 100 ? name.substring(0, 100) : name,
      brand: text('brand', 80),
      barcode: code is String && validBarcode(code) ? code : null,
      servingLabel: text('serving', 60).isEmpty
          ? '1 serving'
          : text('serving', 60),
      // Anything a saved food can have, e.g. a recipe's large serving, so
      // an entry logged in grams is never dropped for it.
      servingGrams: grams is num && grams.isFinite && grams > 0 && grams <= 1e5
          ? grams.toDouble()
          : null,
      perServing: Nutrients.fromJson(json['n']),
      source: FoodSource.values.firstWhere(
        (s) => s.name == json['src'],
        orElse: () => FoodSource.custom,
      ),
      liquid: json['liq'] == true,
    );
  }
}

final _volume = RegExp(r'(\d+(?:[.,]\d+)?)\s*(ml|mL|ML|cl|cL|CL|l|L)\b');

/// Volumes in [text] in the user's units: "250 ml" stays for metric and
/// becomes "8.5 fl oz" for imperial (cl and l too).
String localizeVolume(String text) {
  if (!Units.imperial) return text;
  return text.replaceAllMapped(_volume, (m) {
    final n = double.tryParse(m[1]!.replaceAll(',', '.'));
    if (n == null) return m[0]!;
    final ml = switch (m[2]!.toLowerCase()) {
      'cl' => n * 10,
      'l' => n * 1000,
      _ => n,
    };
    return formatFluidOunces(ml);
  });
}

/// "8.5 fl oz", or "34 fl oz" for larger amounts.
String formatFluidOunces(double ml) {
  final oz = ml / Units.mlPerFlOz;
  final shown = oz >= 20 ? oz.round().toString() : oz.toStringAsFixed(1);
  return '${shown.endsWith('.0') ? shown.substring(0, shown.length - 2) : shown} fl oz';
}

/// EAN-8, UPC-A (12), EAN-13 or GTIN-14 digits.
bool validBarcode(String code) => RegExp(r'^\d{8,14}$').hasMatch(code);

enum Meal {
  breakfast('Breakfast', Icons.wb_twilight_rounded),
  lunch('Lunch', Icons.wb_sunny_rounded),
  dinner('Dinner', Icons.nights_stay_rounded),
  snack('Snacks', Icons.cookie_rounded);

  const Meal(this.label, this.icon);

  final String label;
  final IconData icon;

  /// A sensible meal for the time of day.
  static Meal at(DateTime t) => switch (t.hour) {
    < 11 => breakfast,
    < 15 => lunch,
    >= 17 && < 22 => dinner,
    _ => snack,
  };

  static Meal fromName(Object? n) =>
      values.firstWhere((m) => m.name == n, orElse: () => Meal.snack);
}

/// One food eaten: what, how much, when and in which meal.
@immutable
class FoodEntry {
  const FoodEntry({
    required this.id,
    required this.food,
    required this.amount,
    required this.date,
    required this.meal,
    this.inGrams = false,
  });

  final String id;

  /// A copy of the food as logged, so later edits don't change history.
  final Food food;
  final double amount;
  final bool inGrams;
  final DateTime date;
  final Meal meal;

  Nutrients get nutrients => food.nutrientsFor(amount, inGrams: inGrams);

  /// "1.5 servings" / "150 g".
  String get amountLabel {
    final n = amount == amount.roundToDouble()
        ? '${amount.round()}'
        : amount.toStringAsFixed(1);
    String measure(double v) {
      if (food.liquid && Units.imperial) return formatFluidOunces(v);
      final shown = v == v.roundToDouble()
          ? '${v.round()}'
          : v.toStringAsFixed(1);
      return '$shown ${food.measureUnit}';
    }

    if (inGrams) return measure(amount);
    // "1.5 × 100 g" reads better as "150 g".
    final grams = food.servingGrams;
    if (grams != null &&
        RegExp(r'^[\d.]+ ?(g|ml)$').hasMatch(food.servingLabel)) {
      return measure(amount * grams);
    }
    return amount == 1 ? food.displayServing : '$n × ${food.displayServing}';
  }

  FoodEntry copyWith({double? amount, bool? inGrams, Meal? meal}) => FoodEntry(
    id: id,
    food: food,
    amount: amount ?? this.amount,
    inGrams: inGrams ?? this.inGrams,
    date: date,
    meal: meal ?? this.meal,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'food': food.toJson(),
    'amount': amount,
    if (inGrams) 'g': true,
    'date': date.toIso8601String(),
    'meal': meal.name,
  };

  static FoodEntry? tryFromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'], amount = json['amount'];
    final food = Food.tryFromJson(json['food']);
    final date = DateTime.tryParse('${json['date']}');
    if (id is! String || id.isEmpty || id.length > 80) return null;
    if (food == null || date == null) return null;
    if (amount is! num || !amount.isFinite || amount <= 0 || amount > 10000) {
      return null;
    }
    final inGrams = json['g'] == true;
    // An amount in grams needs the food's serving weight.
    if (inGrams && food.servingGrams == null) return null;
    return FoodEntry(
      id: id,
      food: food,
      amount: amount.toDouble(),
      inGrams: inGrams,
      date: date,
      meal: Meal.fromName(json['meal']),
    );
  }
}

/// Daily calorie and macro targets. Macros are shares of calories.
@immutable
class NutritionGoals {
  const NutritionGoals({
    this.kcal = 2000,
    this.proteinShare = 0.30,
    this.carbsShare = 0.40,
    this.fatShare = 0.30,
    this.addExercise = true,
    this.includesActivity,
  });

  final double kcal;
  final double proteinShare;
  final double carbsShare;
  final double fatShare;

  /// Calories burned by moving add to the day's budget.
  final bool addExercise;

  /// Whether [kcal] already allows for everyday activity (an activity
  /// level). Then only workouts add to the budget, so movement isn't
  /// counted twice; otherwise all measured active energy does. Null for
  /// goals saved before this was known (worked out when loading).
  final bool? includesActivity;

  // 4 kcal per gram of protein or carbohydrate, 9 per gram of fat.
  double get proteinGrams => kcal * proteinShare / 4;
  double get carbsGrams => kcal * carbsShare / 4;
  double get fatGrams => kcal * fatShare / 9;

  NutritionGoals copyWith({
    double? kcal,
    double? proteinShare,
    double? carbsShare,
    double? fatShare,
    bool? addExercise,
    bool? includesActivity,
  }) => NutritionGoals(
    kcal: kcal ?? this.kcal,
    proteinShare: proteinShare ?? this.proteinShare,
    carbsShare: carbsShare ?? this.carbsShare,
    fatShare: fatShare ?? this.fatShare,
    addExercise: addExercise ?? this.addExercise,
    includesActivity: includesActivity ?? this.includesActivity,
  );

  Map<String, Object?> toJson() => {
    'kcal': kcal,
    'p': proteinShare,
    'c': carbsShare,
    'f': fatShare,
    'ex': addExercise,
    'ia': ?includesActivity,
  };

  static NutritionGoals fromJson(Object? json) {
    if (json is! Map<String, Object?>) return const NutritionGoals();
    double share(String k, double d) => switch (json[k]) {
      final num v when v.isFinite && v >= 0 && v <= 1 => v.toDouble(),
      _ => d,
    };
    final kcal = json['kcal'];
    final g = NutritionGoals(
      kcal: kcal is num && kcal >= 500 && kcal <= 10000
          ? kcal.toDouble()
          : 2000,
      proteinShare: share('p', 0.3),
      carbsShare: share('c', 0.4),
      fatShare: share('f', 0.3),
      addExercise: json['ex'] != false,
      includesActivity: switch (json['ia']) {
        final bool b => b,
        _ => null,
      },
    );
    final total = g.proteinShare + g.carbsShare + g.fatShare;
    // Shares must add up to 100%.
    return (total - 1).abs() < 0.02
        ? g
        : g.copyWith(proteinShare: 0.3, carbsShare: 0.4, fatShare: 0.3);
  }
}
