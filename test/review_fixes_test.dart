import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/insights/progress_stats.dart';
import 'package:health_app/models/food.dart';
import 'package:health_app/workout/workout_stats.dart';

/// Regression tests for issues found in the full code review.
void main() {
  group('week start', () {
    final wednesday = DateTime(2026, 10, 14);

    test('defaults to Monday', () {
      expect(weekStart(wednesday), DateTime(2026, 10, 12));
    });

    test('follows a Sunday start', () {
      expect(
        weekStart(wednesday, firstDay: DateTime.sunday),
        DateTime(2026, 10, 11),
      );
      // A Sunday starts its own week.
      expect(
        weekStart(DateTime(2026, 10, 11, 9), firstDay: DateTime.sunday),
        DateTime(2026, 10, 11),
      );
    });
  });

  test('a month back from the 31st lands on the shorter month\'s end', () {
    expect(
      ProgressRange.month.from(DateTime(2026, 3, 31)),
      DateTime(2026, 2, 28),
    );
    expect(
      ProgressRange.month.from(DateTime(2026, 10, 12)),
      DateTime(2026, 9, 12),
    );
  });

  group('food amounts in grams', () {
    const nutrients = Nutrients(kcal: 200);
    const noWeight = Food(id: 'a', name: 'Soup', perServing: nutrients);

    test('without a serving weight never count as servings', () {
      expect(noWeight.nutrientsFor(150, inGrams: true).kcal, 0);
    });

    test('with a serving weight convert', () {
      const weighed = Food(
        id: 'b',
        name: 'Oats',
        perServing: nutrients,
        servingGrams: 50,
      );
      expect(weighed.nutrientsFor(100, inGrams: true).kcal, 400);
    });

    test('a saved gram entry for a food without a weight is rejected', () {
      final json = {
        'id': 'e1',
        'food': noWeight.toJson(),
        'amount': 150,
        'g': true,
        'date': DateTime(2026, 10, 12).toIso8601String(),
      };
      expect(FoodEntry.tryFromJson(json), isNull);
      expect(FoodEntry.tryFromJson({...json, 'g': false}), isNotNull);
    });
  });
}
