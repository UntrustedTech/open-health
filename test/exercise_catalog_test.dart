import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/models/muscles.dart';

void main() {
  late ExerciseCatalog catalog;

  setUpAll(() {
    catalog = ExerciseCatalog.fromBundledJson(
      File('assets/data/exercises.json').readAsStringSync(),
    );
  });

  test('loads the full bundled library plus the app\'s own extras', () {
    expect(catalog.builtIn.length, greaterThan(1300));
    final bench = catalog.byId('0025');
    expect(bench?.name, 'Barbell Bench Press');
    expect(bench?.equipment, 'barbell');
    expect(bench?.target, 'pectorals');
    expect(bench?.steps, isNotEmpty);
  });

  test('ids saved by older versions still resolve', () {
    expect(catalog.byId('bench_press')?.id, '0025');
    expect(catalog.nameOf('squat'), 'Barbell Full Squat');
    // Kept as the app's own exercises (no exact match in the dataset).
    expect(catalog.byId('plank')?.timed, isTrue);
    expect(catalog.nameOf('ohp'), 'Overhead Press');
    expect(catalog.nameOf('no-such-id'), 'Exercise');
  });

  test('search ranks names starting with the query first', () {
    final results = catalog.search(query: 'bench press');
    expect(results.first.name, 'Barbell Bench Press');
    expect(
      results.every((e) => e.name.toLowerCase().contains('bench')),
      isTrue,
    );
  });

  test('filters by body part, muscle and owned equipment', () {
    final chest = catalog.search(bodyPart: 'chest');
    expect(chest.every((e) => e.bodyPart == 'chest'), isTrue);

    final home = catalog.search(equipment: {'dumbbell', 'body weight'});
    expect(home, isNotEmpty);
    expect(
      home.every(
        (e) => e.equipment == 'dumbbell' || e.equipment == 'body weight',
      ),
      isTrue,
    );

    final quads = catalog.search(muscle: Muscle.quadriceps);
    expect(quads.every((e) => e.muscles.contains(Muscle.quadriceps)), isTrue);
    expect(quads, isNotEmpty);
  });

  test('custom exercises are found and round-trip through JSON', () {
    const mine = CatalogExercise(
      id: 'custom-1',
      name: 'Sandbag Carry',
      bodyPart: 'upper legs',
      equipment: 'other',
      target: 'quads',
      custom: true,
      timed: true,
    );
    final withCustom = catalog.withCustom([mine]);

    expect(withCustom.byId('custom-1')?.name, 'Sandbag Carry');
    expect(withCustom.search(query: 'sandbag').single.custom, isTrue);
    final back = CatalogExercise.fromJson(
      jsonDecode(jsonEncode(mine.toJson())) as Map<String, Object?>,
    );
    expect(back?.timed, isTrue);
    expect(back?.custom, isTrue);
  });

  test('muscles map dataset names onto body map regions', () {
    final bench = catalog.byId('0025')!;
    expect(bench.primaryMuscles, contains(Muscle.chest));
    expect(
      bench.secondaryMuscles,
      containsAll([Muscle.triceps, Muscle.deltoids]),
    );
    expect(Muscle.fromName('latissimus dorsi'), Muscle.upperBack);
    expect(Muscle.fromName('cardiovascular system'), isNull);
  });

  test('bodyweight exercises are recognised', () {
    expect(catalog.byId('push_up')?.bodyweight, isTrue);
    expect(catalog.byId('bench_press')?.bodyweight, isFalse);
  });
}
