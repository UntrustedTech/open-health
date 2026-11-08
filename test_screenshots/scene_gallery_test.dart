// Renders every workout's still picture, for review:
//   flutter test test_screenshots/scene_gallery_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/demo/framing.dart';
import 'package:health_app/demo/workout_scene.dart';
import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/widgets/exercise_figure.dart' show exerciseAccent;

Widget _cell(WorkoutType type, {BodyStyle body = BodyStyle.male}) => Container(
  width: 300,
  height: 330,
  margin: const EdgeInsets.all(4),
  child: Column(
    children: [
      Text(
        type.name,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: Color(0xFFAAAAAA),
        ),
      ),
      const SizedBox(height: 4),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: CustomPaint(
            size: Size.infinite,
            painter: WorkoutScenePainter(
              spec: WorkoutScenes.of(type),
              accent: type.color,
              body: body,
            ),
          ),
        ),
      ),
    ],
  ),
);

Widget _exerciseCell(CatalogExercise e) => Container(
  width: 300,
  height: 250,
  margin: const EdgeInsets.all(4),
  child: Column(
    children: [
      Text(
        e.name,
        maxLines: 1,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: Color(0xFFAAAAAA),
        ),
      ),
      const SizedBox(height: 4),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: CustomPaint(
            size: Size.infinite,
            painter: WorkoutScenePainter(
              spec: WorkoutScenes.forExercise(e.id),
              accent: exerciseAccent(e.id),
            ),
          ),
        ),
      ),
    ],
  ),
);

void main() {
  setUpAll(() async {
    final loader = FontLoader('Inter')
      ..addFont(
        File('assets/fonts/Inter-Regular.ttf')
            .readAsBytes()
            .then((b) => ByteData.view(b.buffer)),
      );
    await loader.load();
    ExerciseCatalog.instance = await ExerciseCatalog.loadBundled(rootBundle);
  });

  Future<void> page(
    WidgetTester tester,
    String name,
    Iterable<Widget> cells,
  ) async {
    tester.view.physicalSize = const Size(1848, 1360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: const Color(0xFF111113),
          child: Wrap(children: [...cells]),
        ),
      ),
    );
    await expectLater(
      find.byType(Wrap),
      matchesGoldenFile('shots/scenes_$name.png'),
    );
  }

  const per = 24;
  for (var i = 0; i * per < WorkoutType.values.length; i++) {
    testWidgets('workout scenes ${i + 1}', (tester) async {
      await page(tester, '${i + 1}', [
        for (final t in WorkoutType.values.skip(i * per).take(per)) _cell(t),
      ]);
    });
  }

  testWidgets('workout scenes, female figure', (tester) async {
    await page(tester, 'female', [
      for (final t in [
        WorkoutType.run,
        WorkoutType.yoga,
        WorkoutType.aerialSilks,
        WorkoutType.cycle,
        WorkoutType.surfing,
        WorkoutType.golf,
      ])
        _cell(t, body: BodyStyle.female),
    ]);
  });

  testWidgets('exercise library scenes', (tester) async {
    // The first few of each kind of equipment.
    final seen = <String, int>{};
    final picks = [
      for (final e in ExerciseCatalog.instance.all)
        if ((seen[e.equipment] = (seen[e.equipment] ?? 0) + 1) <= 2) e,
    ].take(24);
    await page(tester, 'exercises', [for (final e in picks) _exerciseCell(e)]);
  });
}
