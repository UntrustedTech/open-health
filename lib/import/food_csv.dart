import 'package:csv/csv.dart';

import 'package:health_app/models/food.dart';

/// Reads MyFitnessPal's Nutrition Summary export (one row per meal per day,
/// with its totals) into diary entries, one per meal. Ids come from the day
/// and meal, so importing the same file again adds nothing new. Not that
/// file: an empty list.
List<FoodEntry> parseMyFitnessPalCsv(String text) {
  final rows = Csv().decode(text.replaceFirst('﻿', ''));
  if (rows.length < 2) return const [];
  final header = [for (final h in rows.first) '$h'.trim().toLowerCase()];
  int col(String name) => header.indexWhere((h) => h.startsWith(name));
  final date = col('date'), meal = col('meal'), kcal = col('calories');
  if (date < 0 || meal < 0 || kcal < 0) return const [];
  final protein = col('protein'), carbs = col('carbohydrates');
  final fat = header.indexWhere((h) => h == 'fat (g)' || h == 'fat');
  final fiber = col('fiber'), sugar = col('sugar');
  final saturated = col('saturated fat'), sodium = col('sodium');

  double value(List<dynamic> row, int i) {
    if (i < 0 || i >= row.length) return 0;
    final v = double.tryParse('${row[i]}'.replaceAll(',', '').trim()) ?? 0;
    return v.isFinite && v > 0 ? v : 0;
  }

  // Meals the app doesn't have ("Meal 5") join Snacks, so one day can have
  // several rows for the same meal: they're added together.
  final totals = <String, (DateTime, Meal, Nutrients)>{};
  for (final row in rows.skip(1)) {
    if (row.length <= kcal) continue;
    final day = DateTime.tryParse('${row[date]}'.trim());
    if (day == null) continue;
    final m = _meal('${row[meal]}');
    final n = Nutrients(
      kcal: value(row, kcal),
      protein: value(row, protein),
      carbs: value(row, carbs),
      fat: value(row, fat),
      fiber: value(row, fiber),
      sugar: value(row, sugar),
      saturatedFat: value(row, saturated),
      sodiumMg: value(row, sodium),
    );
    final key = '${day.year}-${day.month}-${day.day}-${m.name}';
    final held = totals[key];
    totals[key] = (day, m, held == null ? n : held.$3 + n);
  }
  return [
    for (final MapEntry(:key, value: (day, m, n)) in totals.entries)
      if (n.kcal > 0)
        FoodEntry(
          id: 'mfp-$key',
          food: Food(
            id: 'mfp-$key',
            name: '${m.label} (MyFitnessPal)',
            perServing: n,
            source: FoodSource.quickAdd,
          ),
          amount: 1,
          date: DateTime(day.year, day.month, day.day, _hour[m]!),
          meal: m,
        ),
  ];
}

Meal _meal(String name) {
  final n = name.trim().toLowerCase();
  for (final m in [Meal.breakfast, Meal.lunch, Meal.dinner]) {
    if (n.startsWith(m.name)) return m;
  }
  return Meal.snack;
}

/// When each imported meal is logged; the file only has the day.
const _hour = {
  Meal.breakfast: 8,
  Meal.lunch: 12,
  Meal.dinner: 18,
  Meal.snack: 15,
};
