import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;

import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/models/exercise_media.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';
import 'package:health_app/widgets/exercise_figure.dart';
import 'package:health_app/widgets/ios.dart';

/// Loops an exercise's start and end photos as a short demonstration.
/// Tap to pause or play. Starts paused when the system asks for reduced
/// motion. Shows nothing when the exercise has no clip.
class ExerciseClip extends StatefulWidget {
  const ExerciseClip({
    super.key,
    required this.exerciseId,
    this.aspectRatio = 3 / 2,
  });

  final String exerciseId;
  final double aspectRatio;

  /// One full start → end → start cycle.
  static const period = Duration(milliseconds: 2600);

  /// How visible the end frame is at [t] (0–1 through a cycle): hold the
  /// start, blend to the end, hold it, blend back.
  static double endFrameOpacity(double t) {
    const hold = 0.38, blend = 0.12;
    if (t < hold) return 0;
    if (t < hold + blend) {
      return Curves.easeInOut.transform((t - hold) / blend);
    }
    if (t < 2 * hold + blend) return 1;
    final back = (t - 2 * hold - blend) / blend;
    return 1 - Curves.easeInOut.transform(back.clamp(0, 1));
  }

  @override
  State<ExerciseClip> createState() => _ExerciseClipState();
}

class _ExerciseClipState extends State<ExerciseClip>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: ExerciseClip.period,
  );
  bool _paused = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _paused =
        !demoAnimations ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (!_paused) _controller.repeat();
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
    final frames = ExerciseMedia.instance.framesFor(widget.exerciseId);
    if (frames == null) return const SizedBox.shrink();
    final name = ExerciseCatalog.instance.nameOf(widget.exerciseId);
    if (!demoAnimations) return _Stills(frames: frames, name: name);
    return Semantics(
      container: true,
      label: 'Demonstration of $name',
      hint: _paused ? 'Double tap to play' : 'Double tap to pause',
      button: true,
      onTap: _toggle,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _toggle,
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: ClipPath(
            clipper: ShapeBorderClipper(
              shape: AppTheme.squircle(context.innerRadius(AppTheme.radius, 6)),
            ),
            child: LayoutBuilder(
              builder: (context, box) {
                // Decode near display size: the frames are 400px wide.
                final px =
                    (box.maxWidth * MediaQuery.devicePixelRatioOf(context))
                        .round()
                        .clamp(1, 400);
                Widget frame(String path) => Image.asset(
                  path,
                  fit: BoxFit.cover,
                  cacheWidth: px,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) =>
                      ColoredBox(color: context.fillColor),
                );
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    frame(frames[0]),
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (_, child) => Opacity(
                        opacity: ExerciseClip.endFrameOpacity(
                          _controller.value,
                        ),
                        child: child,
                      ),
                      child: frame(frames[1]),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: PlayBadge(paused: _paused),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The start and finish photos side by side, while demonstrations are
/// stills (see [demoAnimations]).
class _Stills extends StatelessWidget {
  const _Stills({required this.frames, required this.name});

  final List<String> frames;
  final String name;

  @override
  Widget build(BuildContext context) {
    final radius = context.innerRadius(AppTheme.radius, 6);
    Widget frame(String path, String label) => Expanded(
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipPath(
              clipper: ShapeBorderClipper(shape: AppTheme.squircle(radius)),
              child: LayoutBuilder(
                builder: (context, box) => Image.asset(
                  path,
                  fit: BoxFit.cover,
                  // Decode near display size: the frames are 400px wide.
                  cacheWidth:
                      (box.maxWidth * MediaQuery.devicePixelRatioOf(context))
                          .round()
                          .clamp(1, 400),
                  errorBuilder: (_, _, _) =>
                      ColoredBox(color: context.fillColor),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: context.caption1.copyWith(color: context.secondaryLabel),
          ),
        ],
      ),
    );
    return Semantics(
      image: true,
      label: 'Photos of $name: start and finish',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          frame(frames[0], 'Start'),
          const SizedBox(width: 8),
          frame(frames[1], 'Finish'),
        ],
      ),
    );
  }
}

/// Small play/pause indicator over a demonstration.
class PlayBadge extends StatelessWidget {
  const PlayBadge({super.key, required this.paused});

  final bool paused;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Container(
        key: ValueKey(paused),
        width: 30,
        height: 30,
        decoration: const BoxDecoration(
          color: Color(0x8C000000),
          shape: BoxShape.circle,
        ),
        child: Icon(
          paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          size: 14,
          color: CupertinoColors.white,
        ),
      ),
    );
  }
}

/// A small still of the exercise's figure in its working position, for
/// lists.
class ExerciseThumb extends StatelessWidget {
  const ExerciseThumb({super.key, required this.exerciseId, this.size = 44});

  final String exerciseId;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: AppTheme.squircle(size * 0.26)),
        child: FigureThumb(exerciseId: exerciseId, size: size),
      ),
    );
  }
}

/// The demonstration with the exercise's steps, as a sheet (used mid-workout).
class ExerciseClipSheet extends StatelessWidget {
  const ExerciseClipSheet({
    super.key,
    required this.exerciseId,
    this.controller,
  });

  final String exerciseId;
  final ScrollController? controller;

  static Future<void> show(BuildContext context, String exerciseId) =>
      showCupertinoSheet<void>(
        context: context,
        scrollableBuilder: (context, controller) =>
            ExerciseClipSheet(exerciseId: exerciseId, controller: controller),
      );

  @override
  Widget build(BuildContext context) {
    final e = ExerciseCatalog.instance.byId(exerciseId);
    final steps = e?.steps ?? const <String>[];
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        // Sheets don't morph the title from the page below, as on iOS;
        // every bar shares one hero tag, so it would fly into the sheet.
        transitionBetweenRoutes: false,
        automaticallyImplyLeading: false,
        middle: Text(e?.name ?? 'Exercise'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Done',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      child: PageList(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          AppTheme.margin,
          12,
          AppTheme.margin,
          32,
        ),
        children: [
          ExerciseDemo(exerciseId: exerciseId),
          if (steps.isNotEmpty) ExerciseSteps(steps: steps),
        ],
      ),
    );
  }
}

/// Numbered "How To" steps.
class ExerciseSteps extends StatelessWidget {
  const ExerciseSteps({super.key, required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text('How To', style: context.title3)),
          const SizedBox(height: 12),
          for (final (i, step) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.fillColor,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: context.footnote.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        step,
                        style: context.body.copyWith(
                          color: context.secondaryLabel,
                          height: 1.45,
                        ),
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
}
