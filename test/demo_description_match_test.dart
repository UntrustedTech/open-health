import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/demo/demo_matcher.dart';
import 'package:health_app/demo/movement.dart';
import 'package:health_app/models/exercise_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ExerciseCatalog catalog;

  setUpAll(() async {
    catalog = await ExerciseCatalog.loadBundled(rootBundle);
    ExerciseCatalog.instance = catalog;
  });

  Movement demoOf(String name) =>
      DemoMatcher.forExercise(catalog.all.firstWhere((e) => e.name == name))
          .movement;

  group('animations follow the exercise descriptions', () {
    for (final (name, expected) in [
      ('Single Arm Push-up', 'one_arm_push_up'),
      ('Dumbbell Standing Alternate Overhead Press', 'overhead_press~alt_arms'),
      ('Kettlebell Alternating Press', 'overhead_press~alt_arms'),
      ('One Leg Squat', 'pistol_squat'),
      ('Handstand Push-up', 'handstand_push_up'),
      ('EZ Barbell Decline Triceps Extension', 'skull_crusher~decline'),
      ('Dumbbell Press On Exercise Ball', 'bench_press~ball'),
      ('Barbell Jefferson Squat', 'jefferson_squat'),
      ('Inchworm', 'inchworm'),
      ('Push-up (bosu Ball)', 'push_up~bosu'),
      (
        'Exercise Ball Back Extension With Hands Behind Head',
        'ball_back_extension',
      ),
      ('Kettlebell One Arm Row', 'row~one_arms'),
      ('Dumbbell Fly On Exercise Ball', 'bench_press~ball'),
      ('Crunch (on Stability Ball, Arms Straight)', 'ball_crunch'),
    ]) {
      test(name, () {
        expect(demoOf(name).id, startsWith(expected));
      });
    }

    test('a twist isn\'t split into one arm at a time', () {
      expect(demoOf('Russian Twist').id, isNot(contains('~alt')));
    });

    test('"slowly lower" makes the lowering the longer step', () {
      final curl = demoOf('Dumbbell Standing Biceps Curl');
      expect(curl.pace, isNotNull);
      // A curl raises first, then lowers slowly.
      expect(curl.pace!.last, greaterThan(curl.pace!.first));
    });

    test('every exercise still gets an animation that solves', () {
      for (final e in catalog.all) {
        final m = DemoMatcher.forExercise(e).movement;
        for (final t in [0.0, 0.37, 0.74]) {
          for (final p in m.skeletonAt(t).points) {
            expect(p.dx.isFinite && p.dy.isFinite, isTrue, reason: e.name);
          }
        }
      }
    });
  });
}
