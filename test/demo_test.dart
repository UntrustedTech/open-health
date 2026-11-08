import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/demo/demo_matcher.dart';
import 'package:health_app/demo/figure.dart';
import 'package:health_app/demo/framing.dart';
import 'package:health_app/demo/movement.dart';
import 'package:health_app/demo/more_movements.dart';
import 'package:health_app/demo/movements.dart';
import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/widgets/exercise_clip.dart';
import 'package:health_app/widgets/exercise_figure.dart';

void main() {
  final catalog = ExerciseCatalog.fromBundledJson(
    File('assets/data/exercises.json').readAsStringSync(),
  );

  group('Skeleton', () {
    test('a standing figure has its feet on the floor', () {
      final s = Skeleton.solve(const Pose());

      expect(s[J.ankleN].dy, closeTo(-Body.ankleHeight, 1e-9));
      expect(s[J.head].dy, lessThan(-0.75));
      expect(s[J.wristN].dy, greaterThan(s[J.shoulderN].dy));
    });

    test('a reaching limb keeps its bone lengths', () {
      final s = Skeleton.solve(
        const Pose(arm: Limb.to(Offset(0.1, -0.2), frame: Frame.shoulder)),
      );

      expect(
        (s[J.elbowN] - s[J.shoulderN]).distance,
        closeTo(Body.upperArm, 1e-6),
      );
      expect((s[J.wristN] - s[J.elbowN]).distance, closeTo(Body.forearm, 1e-6));
      expect(
        s[J.wristN],
        offsetMoreOrLessEquals(
          s[J.shoulderN] + const Offset(0.1, -0.2),
          epsilon: 1e-6,
        ),
      );
    });
  });

  group('Movements', () {
    for (final m in Movements.all) {
      test('${m.id} keeps its root still and stays solvable', () {
        final roots = {for (final p in m.poses) p.root};
        expect(roots, hasLength(1));

        Offset rootOf(Skeleton s) => switch (m.poses.first.root) {
          Root.feet => s[J.ankleN],
          Root.toes => s[J.toeN],
          Root.hip => s[J.pelvis],
          Root.hands => s[J.wristN],
          Root.shoulders => s[J.neck],
        };
        final fixedRoot = {for (final p in m.poses) p.at}.length == 1;
        final first = rootOf(m.skeletonAt(0));
        for (var i = 0; i <= 40; i++) {
          final s = m.skeletonAt(i / 40);
          for (final p in s.points) {
            expect(p.dx.isFinite && p.dy.isFinite, isTrue);
          }
          expect((s[J.kneeN] - s[J.hipN]).distance, closeTo(Body.thigh, 1e-6));
          if (fixedRoot) {
            expect(rootOf(s), offsetMoreOrLessEquals(first, epsilon: 1e-6));
          }
        }
        final bounds = Framing.boundsOf(m, Hold.none);
        expect(bounds.isFinite, isTrue);
      });
    }

    test('keyframes are reached exactly', () {
      final m = Movements.squat;
      expect(
        m.skeletonAt(m.timeOf(1))[J.kneeN],
        offsetMoreOrLessEquals(Skeleton.solve(m.poses[1])[J.kneeN]),
      );
    });
  });

  group('DemoMatcher', () {
    Demo demo(String id) => DemoMatcher.forExercise(catalog.byId(id)!);

    test('every exercise gets a demonstration', () {
      final ids = {
        for (final m in [...Movements.all, ...MoreMovements.all]) m.id,
      };
      for (final e in catalog.all) {
        expect(ids, contains(_base(DemoMatcher.forExercise(e).movement)));
      }
    });

    test('common lifts get the right movement and equipment', () {
      expect(_base(demo('bench_press').movement), Movements.benchPress.id);
      expect(demo('bench_press').hold, Hold.barbell);
      expect(_base(demo('squat').movement), Movements.backSquat.id);
      expect(_base(demo('deadlift').movement), Movements.deadlift.id);
      expect(_base(demo('pull_up').movement), Movements.pullUp.id);
      expect(_base(demo('ohp').movement), Movements.overheadPress.id);
      expect(_base(demo('plank').movement), Movements.plank.id);
      expect(demo('bicep_curl').hold, Hold.dumbbells);
      expect(demo('tricep_pushdown').hold, Hold.cable);
      expect(demo('leg_press').hold, Hold.platform);
    });

    test('attachment notes in brackets do not decide the movement', () {
      final e = catalog.all.firstWhere(
        (e) => e.name == 'Cable Pushdown (with Rope Attachment)',
      );
      expect(_base(DemoMatcher.forExercise(e).movement), Movements.pushdown.id);
    });

    test('look-alike names get the right movement', () {
      Movement of(String name) =>
          DemoMatcher.forExercise(catalog.all.firstWhere((e) => e.name == name))
              .movement;
      expect(
        _base(of('Band Horizontal Pallof Press')),
        Movements.pallofPress.id,
      );
      expect(
        _base(of('Dumbbell Over Bench Wrist Curl')),
        Movements.wristCurl.id,
      );
      expect(
        _base(of('Cable Two Arm Curl On Incline Bench')),
        Movements.inclineCurl.id,
      );
      expect(_base(of('Dumbbell Reverse Fly')), Movements.reverseFly.id);
      expect(
        _base(of('Cable Rope Crossover Seated Row')),
        Movements.seatedRow.id,
      );
      expect(_base(of('Lying Leg Raise Flat Bench')), Movements.legRaise.id);
      expect(
        _base(of('Weighted Close Grip Chin-up On Dip Cage')),
        Movements.pullUp.id,
      );
      expect(_base(of('Air Bike')), Movements.bicycleCrunch.id);
      expect(
        _base(of('Band Assisted Wheel Rollerout')),
        Movements.abRollout.id,
      );
      expect(_base(of('Hanging Leg Hip Raise')), Movements.hangingLegRaise.id);
      expect(
        _base(of('Dumbbell Bicep Curl On Exercise Ball With Leg Raised')),
        Movements.seatedCurl.id,
      );
      expect(
        _base(of('Barbell Lying Close-grip Press')),
        Movements.benchPress.id,
      );
    });

    test('every movement has a cycle that moves and stays in view', () {
      for (final m in Movements.all) {
        expect(m.poses, isNotEmpty, reason: m.id);
        final bounds = Framing.boundsOf(m, Hold.none);
        expect(bounds.isFinite, isTrue, reason: m.id);
      }
      expect({
        for (final m in Movements.all) m.id,
      }, hasLength(Movements.all.length));
    });

    test('custom exercises fall back to their target muscle', () {
      const e = CatalogExercise(
        id: 'c_1',
        name: 'Sandbag Thing',
        bodyPart: 'upper legs',
        equipment: 'other',
        target: 'hamstrings',
        custom: true,
      );
      expect(
        _base(DemoMatcher.forExercise(e).movement),
        Movements.romanianDeadlift.id,
      );
    });
  });

  group('ExerciseFigure', () {
    setUp(() => ExerciseCatalog.instance = catalog);

    Widget host({bool reduceMotion = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: const CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 300,
            child: ExerciseFigure(exerciseId: 'squat'),
          ),
        ),
      ),
    );

    testWidgets('is a still while demonstrations are stills', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump(const Duration(seconds: 1));

      expect(tester.hasRunningAnimations, isFalse);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
      expect(find.bySemanticsLabel(RegExp('^Illustration of')), findsOneWidget);
    }, skip: demoAnimations);

    testWidgets('animates and pauses on tap', skip: !demoAnimations, (
      tester,
    ) async {
      await tester.pumpWidget(host());
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      await tester.tap(find.byType(ExerciseFigure));
      await tester.pump();
      // Let the badge's cross-fade finish.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('starts paused with reduce motion', skip: !demoAnimations, (
      tester,
    ) async {
      await tester.pumpWidget(host(reduceMotion: true));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('demo card offers photos only when there are some', (
      tester,
    ) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: SingleChildScrollView(
            child: ExerciseDemo(exerciseId: 'c_none'),
          ),
        ),
      );
      expect(find.byType(ExerciseFigure), findsOneWidget);
      expect(find.text('Photos'), findsNothing);
      expect(find.byType(ExerciseClip), findsNothing);
    });
  });
}

/// The movement an exercise's demonstration is built on, before its
/// description shapes it (one side, a ball, its pace...).
String _base(Movement m) => m.id.split('~').first;
