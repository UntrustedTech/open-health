import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import 'package:health_app/demo/framing.dart' show BodyStyle;
import 'package:health_app/demo/workout_scene.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/theme/app_theme.dart';

BodyStyle _bodyOf(BuildContext context) {
  try {
    return BodyStyle.fromSex(
      context.select<HealthStore, String>((h) => h.profile.sex),
    );
  } on ProviderNotFoundException {
    return BodyStyle.male;
  }
}

/// A kind of workout as a still picture: a person doing it, in flat
/// colour, with what they use and where (a bike on the road, a board on
/// a wave, silks hanging from above). See [WorkoutScenes].
class WorkoutArt extends StatelessWidget {
  const WorkoutArt({
    super.key,
    required this.type,
    this.radius = AppTheme.radius,
  });

  /// A small square for lists and tiles.
  const WorkoutArt.thumb({super.key, required this.type, this.radius = 10});

  final WorkoutType type;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: type.label,
      excludeSemantics: true,
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: AppTheme.squircle(radius)),
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: WorkoutScenePainter(
              spec: WorkoutScenes.of(type),
              accent: type.color,
              body: _bodyOf(context),
            ),
          ),
        ),
      ),
    );
  }
}
