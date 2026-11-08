import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/demo/framing.dart';
import 'package:health_app/demo/illustration_painter.dart';
import 'package:health_app/demo/more_movements.dart';
import 'package:health_app/demo/movement.dart';
import 'package:health_app/demo/movements.dart';
import 'package:health_app/demo/workout_movements.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/widgets/workout_art.dart';

void paintCycle(Movement m, Hold hold, Size size, BodyStyle body) {
  for (final t in [0.0, 0.3, 0.6, 0.9]) {
    final recorder = ui.PictureRecorder();
    IllustrationPainter(
      movement: m,
      hold: hold,
      body: body,
      t: () => t,
    ).paint(Canvas(recorder), size);
    recorder.endRecording().dispose();
  }
}

Hold holdFor(Movement m) =>
    m.fixed ??
    switch (m.slot) {
      Slot.none => Hold.none,
      Slot.shoulders => Hold.barbell,
      Slot.hands when m.anchor != null => Hold.cable,
      Slot.hands => Hold.dumbbells,
    };

void main() {
  test('every movement is drawn, for every body, large and small', () {
    for (final m in [
      ...Movements.all,
      ...MoreMovements.all,
      ...WorkoutMovements.all,
    ]) {
      for (final body in BodyStyle.values) {
        paintCycle(m, holdFor(m), const Size(360, 300), body);
      }
      paintCycle(m, holdFor(m), const Size(40, 40), BodyStyle.male);
    }
  });

  test('every kind of equipment is drawn, facing us and side on', () {
    for (final hold in Hold.values) {
      for (final m in [Movements.overheadPress, Movements.row]) {
        paintCycle(m, hold, const Size(360, 300), BodyStyle.male);
      }
    }
  });

  test('every workout type has a drawing', () {
    for (final type in WorkoutType.values) {
      final (m, hold) = WorkoutMovements.of(type);
      paintCycle(m, hold, const Size(200, 200), BodyStyle.female);
    }
  });

  testWidgets('every workout has a still picture', (t) async {
    for (final type in WorkoutType.values) {
      await t.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 300,
            height: 200,
            child: WorkoutArt(type: type),
          ),
        ),
      );
      expect(t.takeException(), isNull, reason: type.name);
      expect(t.hasRunningAnimations, isFalse, reason: type.name);
      expect(find.bySemanticsLabel(type.label), findsOneWidget);
    }
  });
}
