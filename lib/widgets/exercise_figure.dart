import 'package:flutter/cupertino.dart' hide Text;
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/demo/demo_matcher.dart';
import 'package:health_app/demo/framing.dart' show BodyStyle;
import 'package:health_app/demo/illustration_painter.dart';
import 'package:health_app/demo/workout_scene.dart';
import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/models/exercise_media.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';
import 'package:health_app/widgets/exercise_clip.dart';
import 'package:health_app/widgets/app_segmented.dart';

/// The dark card the drawings sit on, in light and dark mode alike.
const artPaper = IllustrationColors.paper;

/// Whether exercise demonstrations move. Off for now: each shows its
/// working position as a still, and photo demos show both positions side
/// by side. Turning it back on brings back the looping animations.
const demoAnimations = false;

/// The colour of an exercise's picture, by the part of the body it works.
Color exerciseAccent(String exerciseId) =>
    switch (ExerciseCatalog.instance.byId(exerciseId)?.bodyPart) {
      'chest' => const Color(0xFFFF6B5E),
      'back' => const Color(0xFF4F8DF7),
      'shoulders' => const Color(0xFFB07CFF),
      'upper arms' || 'lower arms' => const Color(0xFFFF9F43),
      'upper legs' || 'lower legs' => const Color(0xFF2FC9A5),
      'waist' => const Color(0xFFF5C542),
      'cardio' => const Color(0xFFFF5C9A),
      _ => const Color(0xFF7C8CF8),
    };

/// The exercise as a still in the workout pictures' style: the figure in
/// flat colour, in the gym, holding what it uses.
class _ExerciseScene extends StatelessWidget {
  const _ExerciseScene({required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: WorkoutScenePainter(
          spec: WorkoutScenes.forExercise(exerciseId),
          accent: exerciseAccent(exerciseId),
          body: _bodyOf(context),
        ),
      ),
    );
  }
}

/// The figure matches the user: male, female, or neutral for "Other" or
/// when not set.
BodyStyle _bodyOf(BuildContext context) {
  try {
    return BodyStyle.fromSex(
      context.select<HealthStore, String>((h) => h.profile.sex),
    );
  } on ProviderNotFoundException {
    // Outside the app (previews): the neutral figure.
    return BodyStyle.neutral;
  }
}

/// An animated figure performing the exercise, drawn live. Tap to pause or
/// play; starts paused when the system asks for reduced motion.
class ExerciseFigure extends StatefulWidget {
  const ExerciseFigure({
    super.key,
    required this.exerciseId,
    this.aspectRatio = 3 / 2,
    this.interactive = true,
  });

  final String exerciseId;
  final double aspectRatio;

  /// Off for small previews (e.g. a grid card): no pause badge or tap.
  final bool interactive;

  @override
  State<ExerciseFigure> createState() => _ExerciseFigureState();
}

class _ExerciseFigureState extends State<ExerciseFigure>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this);
  late Demo _demo = DemoMatcher.forId(widget.exerciseId);
  bool _paused = false;
  bool _started = false;

  Duration get _period =>
      Duration(milliseconds: (_demo.movement.seconds * 1000).round());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _controller.duration = _period;
    _paused =
        !demoAnimations ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (_paused) {
      // Show the working position rather than the start.
      _controller.value = _demo.movement.timeOf(1);
    } else {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(ExerciseFigure old) {
    super.didUpdateWidget(old);
    if (old.exerciseId == widget.exerciseId) return;
    _demo = DemoMatcher.forId(widget.exerciseId);
    _controller.duration = _period;
    if (_paused) {
      _controller.value = _demo.movement.timeOf(1);
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _controller.stop();
    } else {
      _controller.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = ExerciseCatalog.instance.nameOf(widget.exerciseId);
    if (!widget.interactive || !demoAnimations) {
      return Semantics(
        image: true,
        label: 'Illustration of $name',
        excludeSemantics: true,
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: widget.interactive
              ? ClipPath(
                  clipper: ShapeBorderClipper(
                    shape: AppTheme.squircle(
                      context.innerRadius(AppTheme.radius, 6),
                    ),
                  ),
                  child: _ExerciseScene(exerciseId: widget.exerciseId),
                )
              : _ExerciseScene(exerciseId: widget.exerciseId),
        ),
      );
    }
    return Semantics(
      container: true,
      label: 'Animation of $name',
      hint: _paused ? 'Double tap to play' : 'Double tap to pause',
      button: true,
      onTap: _toggle,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _toggle,
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: artPaper,
              shape: AppTheme.squircle(context.innerRadius(AppTheme.radius, 6)),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    painter: IllustrationPainter(
                      movement: _demo.movement,
                      hold: _demo.hold,
                      body: _bodyOf(context),
                      t: () => _controller.value,
                      repaint: _controller,
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: PlayBadge(paused: _paused),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A still of the exercise in its working position, in the scene style.
class FigureThumb extends StatelessWidget {
  const FigureThumb({super.key, required this.exerciseId, this.size = 44});

  final String exerciseId;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: _ExerciseScene(exerciseId: exerciseId),
    );
  }
}

/// The exercise's demonstration: the animated figure, plus the photo clip
/// when there is one.
class ExerciseDemo extends StatefulWidget {
  const ExerciseDemo({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  State<ExerciseDemo> createState() => _ExerciseDemoState();
}

enum _Source { animation, photos }

class _ExerciseDemoState extends State<ExerciseDemo> {
  _Source _source = _Source.animation;

  @override
  Widget build(BuildContext context) {
    final hasPhotos = ExerciseMedia.instance.has(widget.exerciseId);
    final source = hasPhotos ? _source : _Source.animation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: source == _Source.photos
              ? ExerciseClip(
                  key: const ValueKey('photos'),
                  exerciseId: widget.exerciseId,
                )
              : ExerciseFigure(
                  key: const ValueKey('animation'),
                  exerciseId: widget.exerciseId,
                ),
        ),
        if (hasPhotos) ...[
          const SizedBox(height: 8),
          AppSegmented<_Source>(
            groupValue: source,
            children: const {
              _Source.animation: Text(demoAnimations ? 'Animation' : 'Drawing'),
              _Source.photos: Text('Photos'),
            },
            onValueChanged: (s) =>
                setState(() => _source = s ?? _Source.animation),
          ),
        ],
      ],
    );
  }
}
