import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/import/csv_formats.dart';
import 'package:health_app/import/food_csv.dart';
import 'package:health_app/import/importer.dart';
import 'package:health_app/import/name_matcher.dart';
import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/models/food.dart';
import 'package:health_app/models/workout.dart';

void main() {
  final catalog = ExerciseCatalog.fromBundledJson(
    File('assets/data/exercises.json').readAsStringSync(),
  );
  String read(String name) => File('test/fixtures/$name').readAsStringSync();

  group('MyFitnessPal', () {
    test('one entry per day and meal, with calories and macros', () {
      final entries = parseMyFitnessPalCsv(read('myfitnesspal.csv'));
      // Unknown meals join Snacks; bad numbers and dates are skipped.
      expect(entries, hasLength(3));
      final dinner = entries.firstWhere((e) => e.meal == Meal.dinner);
      expect(dinner.nutrients.kcal, 1050);
      expect(dinner.nutrients.protein, 70);
      expect(dinner.nutrients.carbs, 90);
      expect(dinner.nutrients.fat, 40);
      expect(dinner.nutrients.sodiumMg, 900);
      expect(dinner.date, DateTime(2026, 10, 1, 18));
      final snacks = entries.firstWhere((e) => e.meal == Meal.snack);
      expect(snacks.nutrients.kcal, 250);
      // The same file gives the same ids, so it can't be imported twice.
      expect(
        [for (final e in parseMyFitnessPalCsv(read('myfitnesspal.csv'))) e.id],
        [for (final e in entries) e.id],
      );
    });

    test('other files give nothing', () {
      expect(parseMyFitnessPalCsv(read('strong.csv')), isEmpty);
      expect(parseMyFitnessPalCsv(''), isEmpty);
    });
  });

  group('formats', () {
    test('Strong: groups workouts, keeps warm-ups, timed sets and RPE', () {
      final parsed = parseWorkoutCsv(read('strong.csv'));
      expect(parsed.format, CsvFormat.strong);
      expect(parsed.workouts, hasLength(2));
      final push = parsed.workouts.first;
      expect(push.title, 'Push Day');
      expect(push.start, DateTime(2026, 10, 1, 8, 30));
      expect(push.duration, const Duration(hours: 1, minutes: 5));
      final bench = push.exercises.first;
      expect(bench.name, 'Bench Press (Barbell)');
      expect(bench.sets.first.type, SetType.warmup);
      expect(bench.sets[1].weightKg, 80);
      expect(bench.sets[1].rpe, 8);
      expect(push.exercises.last.sets.single.seconds, 60);
    });

    test('Hevy: converts pounds and reads its dates', () {
      final parsed = parseWorkoutCsv(read('hevy.csv'));
      expect(parsed.format, CsvFormat.hevy);
      final w = parsed.workouts.single;
      expect(w.start, DateTime(2026, 10, 5, 7));
      expect(w.duration, const Duration(hours: 1));
      final lat = w.exercises.first;
      expect(lat.sets.first.type, SetType.warmup);
      expect(lat.sets[1].weightKg, closeTo(54.4, 0.1)); // 120 lb
    });

    test('FitNotes: one workout per day', () {
      final parsed = parseWorkoutCsv(read('fitnotes.csv'));
      expect(parsed.format, CsvFormat.fitNotes);
      expect(parsed.workouts, hasLength(2));
      expect(parsed.workouts.first.exercises.first.sets, hasLength(2));
    });

    test('rows without an exercise name are skipped', () {
      final parsed = parseWorkoutCsv(
        'Date,Exercise,Category,Weight (kg),Reps\n'
        '2026-10-01,,Chest,60,8\n'
        '2026-10-02,Bench Press,Chest,60,8\n',
      );
      expect(parsed.workouts, hasLength(1));
      expect(parsed.workouts.single.exercises.single.name, 'Bench Press');
      expect(parsed.workouts.single.duration, Duration.zero);
    });

    test('unknown files are reported, not guessed', () {
      expect(parseWorkoutCsv('a,b,c\n1,2,3').format, CsvFormat.unknown);
    });
  });

  group('exercise names', () {
    final matcher = NameMatcher(catalog);

    test('app-style names match library exercises', () {
      expect(matcher.match('Bench Press (Barbell)')?.id, '0025');
      expect(matcher.match('Squat (Barbell)')?.id, '0043');
      expect(matcher.match('Overhead Press (Barbell)')?.id, 'ohp');
      expect(matcher.match('Pull Up')?.id, '0652');
      expect(matcher.match('Deadlift')?.id, '0032');
      expect(matcher.match('Plank')?.id, 'plank');
    });

    test('unknown names are not forced onto a wrong exercise', () {
      expect(matcher.match('Zercher Yoke Walk'), isNull);
    });
  });

  test('every built-in name shortcut points at a real exercise', () {
    for (final id in NameMatcher.knownIds) {
      expect(catalog.byId(id), isNotNull, reason: id);
    }
  });

  test('converting is repeatable: same file, same workout ids', () {
    final parsed = parseWorkoutCsv(read('strong.csv'));
    final matcher = NameMatcher(catalog);
    final ids = {
      for (final w in parsed.workouts)
        for (final e in w.exercises)
          e.name: matcher.match(e.name)?.id ?? 'c_${e.name}',
    };

    final a = toSessions(parsed, ids);
    final b = toSessions(parsed, ids);

    expect(a.map((w) => w.id), b.map((w) => w.id));
    expect(a.first.exercises.first.exerciseId, '0025');
    expect(a.first.activeSeconds, 65 * 60);
    expect(a.last.exercises.last.exerciseId, 'c_Zercher Yoke Walk');
  });
}
