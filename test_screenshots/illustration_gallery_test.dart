// Renders movements as illustrations, to check them by eye:
//   flutter test test_screenshots/illustration_gallery_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/demo/illustration_painter.dart';
import 'package:health_app/demo/more_movements.dart';
import 'package:health_app/demo/movement.dart';
import 'package:health_app/demo/movements.dart';
import 'package:health_app/demo/workout_movements.dart';
import 'package:health_app/models/workout.dart';

Hold _holdFor(Movement m) =>
    m.fixed ??
    switch (m.slot) {
      Slot.none => Hold.none,
      Slot.shoulders => Hold.barbell,
      Slot.hands when m.anchor != null => Hold.cable,
      Slot.hands => Hold.dumbbells,
    };

Widget _cell(
  Movement m,
  double t,
  String label, {
  double size = 280,
  Hold? hold,
}) => Container(
  width: size,
  height: size * 1.1,
  margin: const EdgeInsets.all(4),
  decoration: BoxDecoration(
    color: IllustrationColors.paper,
    borderRadius: BorderRadius.circular(size * 0.08),
  ),
  child: Column(
    children: [
      const SizedBox(height: 6),
      Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          color: Color(0xFF999999),
        ),
      ),
      Expanded(
        child: CustomPaint(
          size: Size.infinite,
          painter: IllustrationPainter(
            movement: m,
            hold: hold ?? _holdFor(m),
            t: () => t,
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
  });

  Future<void> page(
    WidgetTester tester,
    String name,
    Iterable<Widget> cells, {
    Size size = const Size(1760, 1400),
  }) async {
    tester.view.physicalSize = size;
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
      matchesGoldenFile('shots/illustration_$name.png'),
    );
  }

  testWidgets('reference pose', (tester) async {
    final m = Movements.overheadPress;
    await page(tester, 'reference', [
      _cell(
        m,
        m.timeOf(1),
        'overhead press (barbell)',
        size: 820,
        hold: Hold.barbell,
      ),
      _cell(Movements.squat, Movements.squat.timeOf(1), 'squat', size: 820),
    ], size: const Size(1700, 940));
  });

  testWidgets('featured', (tester) async {
    await page(tester, 'featured', [
      for (final m in [
        Movements.overheadPress,
        Movements.curl,
        Movements.deadlift,
        Movements.benchPress,
        Movements.pushUp,
        Movements.lunge,
        Movements.lateralRaise,
        Movements.row,
        Movements.run,
        Movements.cycling,
        MoreMovements.inchworm,
        Movements.backSquat,
      ])
        _cell(m, m.timeOf(1), m.id, size: 420),
    ], size: const Size(1760, 1440));
  });

  for (final (n, types) in [
    (1, WorkoutType.values.take(12)),
    (2, WorkoutType.values.skip(12)),
  ]) {
    testWidgets('workout types $n', (tester) async {
      await page(tester, 'workouts_$n', [
        for (final type in types)
          for (final k in [0.0, 0.25, 0.5])
            _cell(
              WorkoutMovements.of(type).$1,
              k,
              '${type.name} ${k.toStringAsFixed(2)}',
              size: 190,
              hold: WorkoutMovements.of(type).$2,
            ),
      ]);
    });
  }
}
