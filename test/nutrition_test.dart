import 'dart:convert';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/models/food.dart';
import 'package:health_app/models/meal_template.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/nutrition/open_food_facts.dart';
import 'package:health_app/screens/food/add_food_sheet.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/nutrition_store.dart';

import 'fake_food_server.dart';

final _now = DateTime(2026, 10, 11, 13, 0);

const _bar = Food(
  id: 'c1',
  name: 'Oat Bar',
  servingLabel: '1 bar',
  servingGrams: 40,
  perServing: Nutrients(kcal: 200, protein: 8, carbs: 24, fat: 7),
);

void main() {
  group('Open Food Facts', () {
    test('a product becomes a food per serving or per 100 g', () async {
      final calls = <Uri>[];
      final off = fakeOpenFoodFacts(calls: calls);
      final food = (await off.lookup('3017620422003'))!;
      expect(food.name, 'Nutella');
      expect(food.brand, 'Nutella');
      expect(food.barcode, '3017620422003');
      // No serving size in this record: per 100 g.
      expect(food.servingLabel, '100 g');
      expect(food.perServing.kcal, 539);
      expect(food.perServing.sodiumMg, closeTo(42.8, 0.1));
      expect(food.nutrientsFor(15, inGrams: true).kcal, closeTo(80.85, 0.01));
      expect(calls.single.queryParameters['fields'], contains('nutriments'));
      expect(await off.lookup('0000000000000'), isNull);
      expect(await off.lookup('12'), isNull, reason: 'not a barcode');
    });

    test('search results parse, brands as lists', () async {
      final found = await fakeOpenFoodFacts().search('greek yogurt');
      expect(found, isNotEmpty);
      expect(found.first.brand, 'Chobani');
      expect(found.first.perServing.protein, closeTo(9.41, 0.01));
      expect(await fakeOpenFoodFacts().search('a'), isEmpty);
    });

    test('the same product under two barcodes shows once', () async {
      Map<String, Object?> hit(String code, String name) => {
        'code': code,
        'product_name': name,
        'brands': ['Chobani'],
        'nutriments': {'energy-kcal_100g': 60, 'proteins_100g': 10},
      };
      final off = OpenFoodFacts(
        fetch: (_) async => jsonEncode({
          'hits': [
            hit('0818290011275', 'Greek Yogurt'),
            hit('0818290011282', 'Greek yogurt'),
            hit('0818290011299', 'Greek Yogurt Vanilla'),
          ],
        }),
      );
      final found = await off.search('greek yogurt');
      expect(found.map((f) => f.name), [
        'Greek Yogurt',
        'Greek Yogurt Vanilla',
      ]);
    });

    test('serving sizes, kJ-only energy and junk', () {
      final f = OpenFoodFacts.parseProduct({
        'code': '5000159484695',
        'product_name': 'Bar',
        'serving_size': '1 bar (40 g)',
        'serving_quantity': 40,
        'nutriments': {'energy_100g': 2092, 'proteins_100g': 5},
      })!;
      expect(f.servingLabel, '1 bar (40 g)');
      expect(f.perServing.kcal, closeTo(200, 0.5)); // 2092 kJ/100 g → 40 g
      expect(f.perServing.protein, closeTo(2, 1e-9));
      expect(OpenFoodFacts.parseProduct({'product_name': 'x'}), isNull);
      expect(
        OpenFoodFacts.parseProduct({
          'product_name': 'Water',
          'nutriments': {'energy-kcal_100g': 0},
        }),
        isNull,
      );
      expect(OpenFoodFacts.parseProduct('nope'), isNull);
    });

    test('garbled crowd data is ignored, never stored', () {
      final nan = OpenFoodFacts.parseProduct({
        'code': '5000159484695',
        'product_name': 'Odd',
        'nutriments': {'energy-kcal_100g': 'NaN'},
      });
      expect(nan, isNull);
      final huge = OpenFoodFacts.parseProduct({
        'code': {'not': 'a code'},
        'product_name': 'Big',
        'serving_quantity': '1e308',
        'nutriments': {'energy-kcal_100g': 100, 'proteins_100g': 'Infinity'},
      })!;
      expect(huge.servingLabel, '100 g', reason: 'silly serving ignored');
      expect(huge.perServing.protein, 0);
      expect(huge.barcode, isNull);
      expect(huge.id.length, lessThan(40));
      expect(Food.tryFromJson({'id': 'x' * 500, 'name': 'A'}), isNull);
    });

    test('network failures become FoodLookupException', () async {
      final off = OpenFoodFacts(fetch: (_) async => '<html>');
      await expectLater(
        off.lookup('3017620422003'),
        throwsA(isA<FoodLookupException>()),
      );
      expect(File('test/fixtures/off_product.json').existsSync(), isTrue);
    });
  });

  group('models', () {
    test('an entry in grams of a heavy recipe serving survives a reload', () {
      for (final grams in [6000.0, 0.5]) {
        final e = FoodEntry(
          id: 'e1',
          food: Food(
            id: 'rc1',
            name: 'Batch chili',
            perServing: const Nutrients(kcal: 3000),
            servingGrams: grams,
          ),
          amount: 300,
          inGrams: true,
          date: _now,
          meal: Meal.dinner,
        );
        expect(FoodEntry.tryFromJson(e.toJson()), isNotNull, reason: '$grams');
      }
    });

    test('foods and entries round-trip and reject junk', () {
      final e = FoodEntry(
        id: 'e1',
        food: _bar,
        amount: 60,
        inGrams: true,
        date: _now,
        meal: Meal.lunch,
      );
      final back = FoodEntry.tryFromJson(e.toJson())!;
      expect(back.nutrients.kcal, 300);
      expect(back.amountLabel, '60 g');
      expect(FoodEntry.tryFromJson({'id': 'x', 'amount': -1}), isNull);
      expect(Food.tryFromJson({'id': 'x', 'name': ' '}), isNull);
      expect(Meal.at(DateTime(2026, 1, 1, 8)), Meal.breakfast);
      expect(Meal.at(DateTime(2026, 1, 1, 19)), Meal.dinner);
    });

    test('goals: macros in grams, bad shares reset', () {
      const g = NutritionGoals(kcal: 2000);
      expect(g.proteinGrams, 150);
      expect(g.fatGrams, closeTo(66.7, 0.1));
      final odd = NutritionGoals.fromJson({'kcal': 2200, 'p': 0.9, 'c': 0.9});
      expect(odd.kcal, 2200);
      expect(odd.proteinShare, 0.3);
    });

    test('earlier days are logged at the meal\'s usual time', () {
      expect(mealTime(Meal.lunch, DateTime(2026, 10, 11), _now), _now);
      expect(
        mealTime(Meal.dinner, DateTime(2026, 10, 9), _now),
        DateTime(2026, 10, 9, 19),
      );
    });
  });

  group('NutritionStore', () {
    late HealthStore health;
    late NutritionStore store;

    setUp(() async {
      health = HealthStore(InMemoryHealthRepository(), clock: () => _now);
      await health.load();
      store = NutritionStore(health);
      await store.load();
    });

    FoodEntry entry(String id, {double amount = 1}) => FoodEntry(
      id: id,
      food: _bar,
      amount: amount,
      date: _now,
      meal: Meal.lunch,
    );

    test('importing adds new meals once, with their macros', () async {
      final meals = [entry('mfp-a'), entry('mfp-b')];
      expect(await store.importEntries(meals), 2);
      expect(await store.importEntries(meals), 0);
      expect(store.all, hasLength(2));
      expect(health.dailyValue(MetricType.dietaryEnergy, _now), isNotNull);
    });

    test('logging adds calories and macros to Health', () async {
      await store.add(entry('a', amount: 2));
      expect(health.todayValue(MetricType.dietaryEnergy), 400);
      expect(health.todayValue(MetricType.protein), 16);
      expect(store.totalOn(_now).kcal, 400);
      expect(store.recent.single.id, 'c1');

      await store.update(entry('a', amount: 1));
      expect(health.todayValue(MetricType.dietaryEnergy), 200);

      await store.delete('a');
      expect(health.todayValue(MetricType.dietaryEnergy), 0);
      expect(health.entriesFor(MetricType.fat), isEmpty);
    });

    test('an edited recipe logs its new nutrition from Recent', () async {
      Recipe recipe(int servings) => Recipe(
        id: 'rc1',
        name: 'Chili',
        servings: servings,
        ingredients: [FoodPortion(food: _bar, amount: 2)],
      );
      await store.saveRecipe(recipe(1));
      final food = store.recipeFor('rc1')!.toFood();
      await store.add(
        FoodEntry(id: 'e', food: food, amount: 1, date: _now, meal: Meal.lunch),
      );
      await store.toggleFavorite(food);

      await store.saveRecipe(recipe(2));
      expect(store.recent.single.perServing.kcal, 200);
      expect(store.favorites.single.perServing.kcal, 200);

      await store.deleteRecipe('rc1');
      expect(store.recent, isEmpty);
    });

    test('remaining = goal − food + exercise', () async {
      await health.addEntry(MetricType.activeEnergy, 300);
      await store.add(entry('a'));
      // A goal without an activity level: all measured activity counts.
      await store.setGoals(store.goals.copyWith(includesActivity: false));
      expect(store.remainingOn(_now), 2000 - 200 + 300);
      await store.setGoals(store.goals.copyWith(addExercise: false));
      expect(store.remainingOn(_now), 1800);
    });

    test('a goal that covers everyday activity adds only workouts', () async {
      await health.addEntry(MetricType.activeEnergy, 300);
      store.workoutKcalOn = (_) => 120;
      await store.setGoals(store.goals.copyWith(includesActivity: true));
      expect(store.burnedOn(_now), 120);
      expect(store.budgetOn(_now), 2120);
    });

    test('older goals are assumed to cover everyday activity', () async {
      // The 2,000 kcal default can't be matched to an estimate.
      expect(store.goalIncludesActivity, isTrue);
      expect(
        NutritionGoals.fromJson(const {'kcal': 1800}).includesActivity,
        isNull,
      );
    });

    test('saved foods, favorites and goals persist', () async {
      await store.saveCustom(_bar);
      await store.toggleFavorite(_bar);
      await store.add(entry('a'));
      final again = NutritionStore(health);
      await again.load();
      expect(again.custom.single.name, 'Oat Bar');
      expect(again.favorites.single.id, 'c1');
      expect(again.entriesOn(_now), hasLength(1));
    });
  });
}
