// Draws exercises as their descriptions now shape them, for review:
//   flutter test test_screenshots/demo_audit_gallery_test.dart --update-goldens
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/demo/demo_matcher.dart';
import 'package:health_app/demo/illustration_painter.dart';
import 'package:health_app/models/exercise_catalog.dart';

const _named = [
  'Single Arm Push-up',
  'Dumbbell Standing Alternate Overhead Press',
  'Kettlebell Alternating Press',
  'One Leg Squat',
  'Handstand Push-up',
  'EZ Barbell Decline Triceps Extension',
  'Dumbbell Press On Exercise Ball',
  'Barbell Jefferson Squat',
  'Inchworm',
  'Posterior Step To Overhead Reach',
  'Push-up (bosu Ball)',
  'Exercise Ball Back Extension With Hands Behind Head',
  'Dumbbell Alternate Biceps Curl',
  'Kettlebell One Arm Row',
  'Dumbbell Incline Curl',
  'One Arm Chin-up',
];

Widget _cell(CatalogExercise e) {
  final d = DemoMatcher.forExercise(e);
  final m = d.movement;
  final keys = [for (var k = 0; k < math.min(m.poses.length, 4); k++) k];
  return Container(
    width: 420,
    height: 200,
    margin: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFF2B2B2D),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        const SizedBox(height: 4),
        Text(
          '${e.name}  ·  ${m.id}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: Color(0xFFAAAAAA),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              for (final k in keys)
                Expanded(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: IllustrationPainter(
                      movement: m,
                      hold: d.hold,
                      t: () => m.timeOf(k),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

void main() {
  late ExerciseCatalog catalog;
  setUpAll(() async {
    final loader = FontLoader('Inter')
      ..addFont(
        File('assets/fonts/Inter-Regular.ttf')
            .readAsBytes()
            .then((b) => ByteData.view(b.buffer)),
      );
    await loader.load();
    catalog = await ExerciseCatalog.loadBundled(rootBundle);
    ExerciseCatalog.instance = catalog;
  });

  Future<void> page(
    WidgetTester t,
    String name,
    List<CatalogExercise> es,
  ) async {
    t.view.physicalSize = const Size(1770, 1450);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: const Color(0xFF111113),
          child: Wrap(children: [for (final e in es) _cell(e)]),
        ),
      ),
    );
    await expectLater(find.byType(Wrap), matchesGoldenFile('shots/$name.png'));
  }

  testWidgets('described exercises', (t) async {
    await page(t, 'audit_named', [
      for (final n in _named)
        ?catalog.all.where((e) => e.name == n).firstOrNull,
    ]);
  });

  for (var p = 0; p < 4; p++) {
    testWidgets('sample ${p + 1}', (t) async {
      final all = [...catalog.all]..shuffle(math.Random(7 + p));
      await page(t, 'audit_sample_${p + 1}', all.take(28).toList());
    });
  }
}
