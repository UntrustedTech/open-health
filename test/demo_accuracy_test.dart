import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/demo/demo_matcher.dart';
import 'package:health_app/demo/figure.dart';
import 'package:health_app/demo/framing.dart';
import 'package:health_app/demo/movement.dart';
import 'package:health_app/demo/movements.dart';
import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/models/exercise_media.dart';

void main() {
  final catalog = ExerciseCatalog.fromBundledJson(
    File('assets/data/exercises.json').readAsStringSync(),
  );

  Movement movementFor(String name) => DemoMatcher.movementFor(
    catalog.builtIn.firstWhere(
      (e) => e.name.toLowerCase() == name.toLowerCase(),
      orElse: () => throw StateError('No exercise named $name'),
    ),
  );

  group('figures demonstrate the right body positions', () {
    test('a glute bridge lifts the hips above the shoulders', () {
      final top = Movements.bridge.skeletonAt(0.5);
      final bottom = Movements.bridge.skeletonAt(0);
      // y grows downwards: higher means smaller.
      expect(top[J.pelvis].dy, lessThan(bottom[J.pelvis].dy));
      expect(top[J.pelvis].dy, lessThan(top[J.shoulderN].dy));
      // The head stays on the floor, never below it.
      expect(top[J.head].dy, lessThan(0));
    });

    test('an upright row raises the elbows above the hands', () {
      final top = Movements.uprightRow.skeletonAt(0.5);
      expect(top[J.elbowN].dy, lessThan(top[J.wristN].dy));
      expect(top[J.elbowN].dy, lessThan(top[J.shoulderN].dy + 0.02));
    });

    test('a glute kickback keeps the standing foot on the floor', () {
      for (final t in [0.0, 0.25, 0.5]) {
        final s = Movements.gluteKickback.skeletonAt(t);
        expect(s[J.ankleF].dy, closeTo(-Body.ankleHeight, 0.01));
      }
      final top = Movements.gluteKickback.skeletonAt(0.5);
      // The working foot travels behind the hips.
      expect(top[J.ankleN].dx, lessThan(top[J.pelvis].dx - 0.1));
    });

    test('a preacher curl keeps the upper arm still on the pad', () {
      final a = Movements.preacherCurl.skeletonAt(0);
      final b = Movements.preacherCurl.skeletonAt(0.5);
      // Still but for breathing, which lifts the shoulders a touch.
      expect(b[J.elbowN], offsetMoreOrLessEquals(a[J.elbowN], epsilon: 0.006));
      expect(b[J.wristN].dy, lessThan(a[J.wristN].dy - 0.1));
    });

    test('a kneeling push-up rests on the knees', () {
      for (final t in [0.0, 0.5]) {
        final s = Movements.kneelingPushUp.skeletonAt(t);
        expect(s[J.kneeN].dy, closeTo(0, 0.07));
      }
    });

    test('an inverted row keeps the shoulders above the hips', () {
      final s = Movements.invertedRow.skeletonAt(0);
      expect(s[J.shoulderN].dy, lessThan(s[J.hipN].dy));
    });

    test('a kneeling crunch curls the trunk down towards the floor', () {
      final start = Movements.kneelingCrunch.skeletonAt(0);
      final end = Movements.kneelingCrunch.skeletonAt(0.5);
      expect(end[J.head].dy, greaterThan(start[J.head].dy + 0.05));
    });
  });

  group('exercises get a matching demonstration', () {
    final expected = {
      'Full Planche': Movements.plank,
      'Front Lever': Movements.plank,
      'Shoulder Tap Push-up': Movements.pushUp,
      'L-sit On Floor': Movements.vSit,
      'Dumbbell Biceps Curl V Sit On Bosu Ball': Movements.seatedCurl,
      'Kettlebell Windmill': Movements.sideBend,
      'Sledge Hammer': Movements.woodChop,
      'Medicine Ball Overhead Slam': Movements.woodChop,
      'Cable Kneeling Crunch': Movements.kneelingCrunch,
      'Hanging Pike': Movements.hangingLegRaise,
      'Wheel Rollerout': Movements.abRollout,
      'Dumbbell Finger Curls': Movements.fingerCurl,
      'Barbell Close-grip Bench Press': Movements.benchPress,
      'Lever Seated Calf Raise': Movements.seatedCalfRaise,
      'Cable Standing Hip Extension': Movements.gluteKickback,
      'Cable Pull Through (with Rope)': Movements.romanianDeadlift,
      'Tire Flip': Movements.deadlift,
      'Smith Sprint Lunge': Movements.lunge,
      'Dumbbell Standing Bent Over Two Arm Triceps Extension':
          Movements.kickback,
      'EZ Barbell Incline Triceps Extension': Movements.skullCrusher,
      'Barbell Preacher Curl': Movements.preacherCurl,
      'Dumbbell Concentration Curl': Movements.concentrationCurl,
      'Dumbbell Incline Curl': Movements.inclineCurl,
      'EZ Barbell Spider Curl': Movements.spiderCurl,
      'Dumbbell Seated Curl': Movements.seatedCurl,
      'Barbell Curl': Movements.curl,
      'Spider Crawl Push Up': Movements.pushUp,
      'Weighted Bench Dip': Movements.benchDip,
      'Chest Dip': Movements.dip,
      'Inverted Row Bent Knees': Movements.invertedRow,
      'Push-up (wall)': Movements.wallPushUp,
      'Kneeling Push-up': Movements.kneelingPushUp,
      'Lever Seated Hip Abduction': Movements.seatedAbduction,
      'Dumbbell Seated Triceps Extension': Movements.seatedOverheadExtension,
      'Dumbbell Seated Bent Over Triceps Extension': Movements.seatedKickback,
    };
    for (final MapEntry(key: name, value: movement) in expected.entries) {
      test(name, () => expect(movementFor(name).id, movement.id));
    }
  });

  test('every movement id is unique and listed', () {
    final ids = [for (final m in Movements.all) m.id];
    expect(ids.toSet().length, ids.length);
    for (final m in [
      Movements.seatedCalfRaise,
      Movements.kneelingCrunch,
      Movements.vSit,
      Movements.fingerCurl,
      Movements.gluteKickback,
      Movements.preacherCurl,
      Movements.benchDip,
      Movements.wallPushUp,
    ]) {
      expect(ids, contains(m.id));
    }
  });

  test('every mapped photo set is bundled', () {
    final media = ExerciseMedia.fromJson(
      File('assets/data/exercise_media.json').readAsStringSync(),
    );
    for (final e in catalog.builtIn) {
      for (final path in media.framesFor(e.id) ?? const <String>[]) {
        expect(File(path).existsSync(), isTrue, reason: '$path for ${e.name}');
      }
    }
  });

  group('the figure follows the profile', () {
    test('male, female, and neutral for other or unset', () {
      expect(BodyStyle.fromSex('Male'), BodyStyle.male);
      expect(BodyStyle.fromSex('female'), BodyStyle.female);
      expect(BodyStyle.fromSex('Other'), BodyStyle.neutral);
      expect(BodyStyle.fromSex(''), BodyStyle.neutral);
    });
  });

  group('instructions decide the body position', () {
    final positioned = {
      'Dumbbell Seated Lateral Raise': Movements.seatedLateralRaise,
      'Dumbbell Seated Front Raise': Movements.seatedFrontRaise,
      'Barbell Seated Good Morning': Movements.seatedGoodMorning,
      'Dumbbell Kneeling Bicep Curl Exercise Ball': Movements.kneelingCurl,
      'Cable High Row (kneeling)': Movements.kneelingRow,
      'Dumbbell Incline Shrug': Movements.chestSupportedRow,
      'Cable Straight Arm Pulldown': Movements.straightArmPulldown,
      'Band Underhand Pulldown': Movements.standingPulldown,
      'Cable Pulldown': Movements.pulldown,
      'Weighted Svend Press': Movements.standingChestPress,
      'Cable Seated Chest Press': Movements.seatedChestPress,
      'Band Bench Press': Movements.benchPress,
      'Cable Bench Press': Movements.benchPress,
      'Cable Incline Bench Press': Movements.inclinePress,
      'Triceps Dip (between Benches)': Movements.benchDip,
      'Assisted Lying Calves Stretch': Movements.legRaise,
      'Barbell Standing Concentration Curl': Movements.spiderCurl,
    };
    for (final MapEntry(key: name, value: m) in positioned.entries) {
      test(name, () => expect(movementFor(name).id, m.id));
    }

    test('seated forms keep the arm motion and add a seat', () {
      final standing = Movements.lateralRaise.poses.last;
      final seated = Movements.seatedLateralRaise.poses.last;
      expect(seated.arm.upper, standing.arm.upper);
      expect(seated.root, Root.hip);
      expect(Movements.seatedLateralRaise.scenery, isNotEmpty);
    });

    test('kneeling forms rest on the knees', () {
      final s = Movements.kneelingCurl.skeletonAt(0);
      expect(s[J.kneeN].dy, closeTo(-0.035, 0.03));
    });
  });
}
