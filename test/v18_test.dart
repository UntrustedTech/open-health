import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/models/food.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/nutrition/open_food_facts.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/workout/intervals.dart';

void main() {
  tearDown(() => Units.system = UnitSystem.metric);

  group('food accuracy', () {
    Map<String, Object?> product(
      Map<String, Object?> nutriments, {
      Map<String, Object?> extra = const {},
    }) => {
      'code': '5000112637922',
      'product_name': 'Test',
      'nutriments': nutriments,
      ...extra,
    };

    test('kJ typed into the kcal field is corrected', () {
      final f = OpenFoodFacts.parseProduct(
        product({
          'energy-kcal_100g': 1550, // really kJ
          'proteins_100g': 10,
          'carbohydrates_100g': 60,
          'fat_100g': 10,
        }),
      )!;
      // 4×10 + 4×60 + 9×10 = 370 kcal from the macros.
      expect(f.perServing.kcal, closeTo(370, 15));
    });

    test('drinks with alcohol keep their calories', () {
      // A liqueur: 20 g sugar, ~280 kcal (alcohol isn't in the macros).
      final f = OpenFoodFacts.parseProduct(
        product({
          'energy-kcal_100g': 280,
          'energy-kj_100g': 1172,
          'carbohydrates_100g': 20,
        }),
      )!;
      expect(f.perServing.kcal, 280);
    });

    test('real kcal values are kept', () {
      final f = OpenFoodFacts.parseProduct(
        product({
          'energy-kcal_100g': 539,
          'proteins_100g': 6.3,
          'carbohydrates_100g': 57.5,
          'fat_100g': 30.9,
        }),
      )!;
      expect(f.perServing.kcal, 539);
    });

    test('only kJ, or only macros, still give calories', () {
      expect(
        OpenFoodFacts.parseProduct(product({'energy_100g': 418.4}))!
            .perServing
            .kcal,
        closeTo(100, 0.01),
      );
      expect(
        OpenFoodFacts.parseProduct(
          product({'proteins_100g': 10, 'fat_100g': 10}),
        )!.perServing.kcal,
        130,
      );
    });

    test('sodium comes from salt when missing', () {
      final f = OpenFoodFacts.parseProduct(
        product({'energy-kcal_100g': 100, 'salt_100g': 1.0}),
      )!;
      expect(f.perServing.sodiumMg, closeTo(400, 0.01));
    });

    test('drinks are measured in ml', () {
      final cola = OpenFoodFacts.parseProduct(
        product(
          {'energy-kcal_100g': 42},
          extra: {
            'serving_quantity': 330,
            'serving_quantity_unit': 'ml',
            'serving_size': '1 can (330 ml)',
          },
        ),
      )!;
      expect(cola.liquid, isTrue);
      expect(cola.servingGrams, 330);
      expect(cola.perServing.kcal, closeTo(138.6, 0.01));

      final bar = OpenFoodFacts.parseProduct(
        product(
          {'energy-kcal_100g': 400},
          extra: {'serving_quantity': 40, 'serving_size': '1 bar (40 g)'},
        ),
      )!;
      expect(bar.liquid, isFalse);

      final noServing = OpenFoodFacts.parseProduct(
        product({'energy-kcal_100g': 45}, extra: {'quantity': '1 l'}),
      )!;
      expect(noServing.liquid, isTrue);
      expect(noServing.servingLabel, '100 ml');
    });

    test('drinks show in fluid ounces for imperial users', () {
      const juice = Food(
        id: 'j',
        name: 'Juice',
        perServing: Nutrients(kcal: 110),
        servingLabel: '250 ml',
        servingGrams: 250,
        liquid: true,
      );
      expect(juice.displayServing, '250 ml');
      Units.system = UnitSystem.imperial;
      expect(juice.displayServing, '8.5 fl oz');
      expect(localizeVolume('1 bottle (1.5 l)'), '1 bottle (51 fl oz)');
      final entry = FoodEntry(
        id: 'e',
        food: juice,
        amount: 2,
        date: DateTime(2026, 10, 15),
        meal: Meal.lunch,
      );
      expect(entry.amountLabel, '16.9 fl oz');
      expect(Food.tryFromJson(juice.toJson())!.liquid, isTrue);
    });
  });

  group('workouts', () {
    test('every workout has a category', () {
      for (final c in WorkoutCategory.values) {
        expect(WorkoutType.values.where((t) => t.category == c), isNotEmpty);
      }
      expect(WorkoutType.pilates.category, WorkoutCategory.mindBody);
      expect(WorkoutType.boxing.category, WorkoutCategory.strength);
      expect(WorkoutType.fromName('pilates'), WorkoutType.pilates);
    });

    test('guided flows name each move with a pause between', () {
      final mat = IntervalProgram.forType(WorkoutType.pilates).first;
      expect(mat.isFlow, isTrue);
      final work = mat.phases.where((p) => p.kind == PhaseKind.work).toList();
      expect(work.first.label, 'The Hundred');
      expect(work, hasLength(mat.roundCount));
      final pause = mat.phases.firstWhere((p) => p.kind == PhaseKind.rest);
      expect(pause.label, startsWith('Next: '));
      expect(mat.summary, '${mat.moves.length} moves');
      // Each flow is offered for its own workouts; HIIT keeps its timers.
      expect(
        IntervalProgram.forType(WorkoutType.hiit).any((p) => p.isFlow),
        isFalse,
      );
      expect(IntervalProgram.forType(WorkoutType.taiChi), isNotEmpty);
      expect(IntervalProgram.forType(WorkoutType.barre), isNotEmpty);
    });
  });
}
