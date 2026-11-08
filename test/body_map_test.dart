import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/models/muscles.dart';
import 'package:health_app/widgets/body_map.dart';

void main() {
  late BodyMapData data;

  setUpAll(() {
    data = BodyMapData.parse(
      File('assets/data/body_paths.json').readAsStringSync(),
    );
  });

  test('loads front and back outlines for both figures', () {
    for (final figure in BodyFigure.values) {
      for (final side in BodySide.values) {
        expect(data.view(figure, side).parts, isNotEmpty);
      }
    }
  });

  test('every outline is either a muscle or a known body part', () {
    const neutral = {
      'head',
      'hair',
      'neck',
      'hands',
      'feet',
      'knees',
      'ankles',
    };
    for (final figure in BodyFigure.values) {
      for (final side in BodySide.values) {
        for (final p in data.view(figure, side).parts) {
          expect(
            Muscle.fromSlug(p.slug) != null || neutral.contains(p.slug),
            isTrue,
            reason: 'unmapped outline ${p.slug}',
          );
        }
      }
    }
  });

  test('a point inside the chest outline hits the chest', () {
    final view = data.view(BodyFigure.male, BodySide.front);
    final chest = view.parts.firstWhere((p) => p.slug == 'chest');
    final centre = chest.path.getBounds().center;

    // Pick a point that is inside one of the chest shapes.
    final hit = view.muscleAt(
      chest.path.contains(centre)
          ? centre
          : chest.path.getBounds().topLeft + const Offset(20, 40),
    );

    expect(hit, Muscle.chest);
  });
}
