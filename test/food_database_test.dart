import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/models/food.dart';
import 'package:health_app/models/micronutrient.dart';
import 'package:health_app/nutrition/food_database.dart';
import 'package:health_app/nutrition/open_food_facts.dart';

String _db(List<Map<String, Object?>> foods) =>
    jsonEncode({'format': 1, 'foods': foods});

final _foods = [
  {
    'id': 'usda-1',
    'name': 'Apples, raw, with skin',
    'cat': 'Fruits and Fruit Juices',
    'n': {
      'kcal': 52,
      'c': 13.8,
      'm': {'c': 4.6, 'k+': 107},
    },
    'p': [
      ['1 medium', 182],
    ],
  },
  {
    'id': 'usda-2',
    'name': 'Pie, apple, commercially prepared',
    'cat': 'Baked Products',
    'n': {'kcal': 237},
  },
  {
    'id': 'usda-3',
    'name': 'Milk, whole',
    'cat': 'Beverages',
    'n': {
      'kcal': 61,
      'm': {'ca': 113, 'd': 1.3},
    },
  },
  {'id': 'bad', 'name': 'No calories', 'n': {}},
];

void main() {
  group('Vitamins and minerals', () {
    test('are kept, added and scaled with the rest', () {
      const a = Nutrients(
        kcal: 100,
        micros: {Micronutrient.vitaminC: 10, Micronutrient.iron: 2},
      );
      const b = Nutrients(kcal: 50, micros: {Micronutrient.vitaminC: 5});
      final sum = (a + b) * 2;
      expect(sum.micros[Micronutrient.vitaminC], 30);
      expect(sum.micros[Micronutrient.iron], 4);
      final back = Nutrients.fromJson(a.toJson());
      expect(back.micros, a.micros);
    });

    test('bad saved values are dropped', () {
      final n = Nutrients.fromJson({
        'kcal': 10,
        'm': {'c': -1, 'fe': double.nan, 'zz': 3, 'zn': 2},
      });
      expect(n.micros, {Micronutrient.zinc: 2});
    });

    test('are read from Open Food Facts, which stores grams', () {
      final food = OpenFoodFacts.parseProduct({
        'code': '3017620422003',
        'product_name': 'Juice',
        'nutriments': {
          'energy-kcal_100g': 45,
          'vitamin-c_100g': 0.03,
          'calcium_100g': '0.12',
          'iron_100g': 50,
        },
      })!;
      expect(food.perServing.micros[Micronutrient.vitaminC], closeTo(30, 1e-9));
      expect(food.perServing.micros[Micronutrient.calcium], closeTo(120, 1e-9));
      // 50 g of iron in 100 g is bad data.
      expect(food.perServing.micros, isNot(contains(Micronutrient.iron)));
    });

    test('share of the Daily Value', () {
      expect(Micronutrient.vitaminC.share(45), 0.5);
      expect(Micronutrient.byKey('k+'), Micronutrient.potassium);
    });
  });

  group('FoodDatabase', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('foods'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('downloads, searches and keeps a copy', () async {
      var calls = 0;
      FoodDatabase make() => FoodDatabase(
        directory: () async => dir,
        fetch: (_, _) async {
          calls++;
          return FoodDownloadBody(_db(_foods), 'v1');
        },
      );
      final now = DateTime(2026, 10, 25);
      final db = make();
      await db.refresh(now: now);
      expect(db.count, 3);
      expect(db.search('apple').map((f) => f.id), ['usda-1', 'usda-2']);
      expect(db.search('raw apple').single.id, 'usda-1');
      expect(db.search('xyz'), isEmpty);

      final apple = db.search('apples').first.toFood();
      expect(apple.servingLabel, '1 medium (182 g)');
      expect(apple.perServing.kcal, closeTo(52 * 1.82, 1e-9));
      expect(
        apple.perServing.micros[Micronutrient.potassium],
        closeTo(194.74, 0.01),
      );
      expect(apple.source, FoodSource.database);
      expect(db.search('milk').single.toFood().liquid, isTrue);

      // A new start reads the copy and doesn't download again this week.
      final again = make();
      await again.load(now: now.add(const Duration(days: 1)));
      await pumpEventQueue();
      expect(again.count, 3);
      expect(calls, 1);
    });

    test('keeps what it has when offline or unchanged', () async {
      FoodDownload answer = FoodDownloadBody(_db(_foods), null);
      final db = FoodDatabase(
        directory: () async => dir,
        fetch: (_, _) async => answer,
      );
      await db.refresh();
      answer = const FoodDownloadFailed();
      await db.refresh(force: true);
      expect(db.count, 3);
      expect(db.failed, isTrue);
      answer = const FoodDownloadUnchanged();
      await db.refresh(force: true);
      expect(db.count, 3);
      expect(db.failed, isFalse);
      // A broken file doesn't replace a good one.
      answer = const FoodDownloadBody('{"format": 2}', null);
      await db.refresh(force: true);
      expect(db.count, 3);
    });
  });
}
