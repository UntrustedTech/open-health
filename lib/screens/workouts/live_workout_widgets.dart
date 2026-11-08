import 'dart:math';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_animate/flutter_animate.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/workout/intervals.dart';
import 'package:health_app/workout/workout_tracker.dart';

// Building blocks of the live workout screen.

class LiveTimer extends StatelessWidget {
  const LiveTimer({
    super.key,
    required this.elapsed,
    required this.paused,
    this.size = 84,
  });

  final Duration elapsed;
  final bool paused;

  /// Smaller for strength, where the sets matter more than the clock.
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: paused ? 0.45 : 1,
      duration: Motion.medium,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          formatClock(elapsed),
          semanticsLabel: 'Elapsed ${formatMinutes(elapsed)}',
          // Plain label colour: the clock is read at a glance mid-set, so
          // it gets the most contrast.
          style: context
              .number(size, weight: FontWeight.w700)
              .copyWith(color: context.labelColor),
        ),
      ),
    );
  }
}

class LiveMetricTile extends StatelessWidget {
  const LiveMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - 40 - 12) / 2;
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: ShapeDecoration(
        color: context.cardBackground,
        shape: context.cardShape(AppTheme.radius),
        shadows: context.skinShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.caption1.copyWith(
              color: context.secondaryLabel,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: context.title1.copyWith(
                color: context.labelColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LiveGoalBar extends StatelessWidget {
  const LiveGoalBar({
    super.key,
    required this.progress,
    required this.label,
    required this.color,
  });

  final double progress;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GOAL ${label.toUpperCase()} · ${(p * 100).round()}%',
          style: context.caption1.copyWith(
            color: context.secondaryLabel,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 8,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: color.withValues(alpha: 0.2)),
                AnimatedFractionallySizedBox(
                  duration: Motion.slow,
                  curve: Motion.curve,
                  alignment: Alignment.centerLeft,
                  widthFactor: p,
                  child: ColoredBox(color: color),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Big ring counting down the current interval phase.
class IntervalRingView extends StatelessWidget {
  const IntervalRingView({super.key, required this.tracker});

  final WorkoutTracker tracker;

  @override
  Widget build(BuildContext context) {
    final program = tracker.program;
    final now = tracker.phase;
    if (program == null) return const SizedBox.shrink();
    if (now == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Text(
          'Program complete.\nEnd the workout to save it.',
          textAlign: TextAlign.center,
          style: context.title2.copyWith(color: context.labelColor),
        ),
      );
    }
    final phase = now.phase;
    final color = switch (phase.kind) {
      PhaseKind.work => tracker.type.color,
      PhaseKind.rest => Palette.teal,
      PhaseKind.warmup || PhaseKind.cooldown => Palette.yellow,
    };
    final progress =
        1 - now.remaining.inMilliseconds / phase.duration.inMilliseconds;
    return Column(
      children: [
        SizedBox.square(
          dimension: 230,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: progress),
                duration: const Duration(milliseconds: 900),
                builder: (context, v, _) => CustomPaint(
                  size: const Size.square(230),
                  painter: _RingPainter(progress: v, color: color),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: Motion.medium,
                    child: SizedBox(
                      key: ValueKey(now.index),
                      width: 170,
                      child: Text(
                        program.isFlow
                            ? phase.label
                            : phase.label.toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.headline.copyWith(color: color),
                      ),
                    ),
                  ),
                  Text(
                    '${now.remaining.inSeconds + 1}',
                    style: TextStyle(
                      color: context.labelColor,
                      fontSize: 64,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (phase.round > 0)
                    Text(
                      '${program.isFlow ? 'Move' : 'Round'} ${phase.round} '
                      'of ${program.roundCount}',
                      style: context.subheadline.copyWith(
                        color: context.secondaryLabel,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${program.name} · ${tracker.activeKcal.round()} Cal',
          style: context.subheadline.copyWith(color: context.secondaryLabel),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
    final c = size.center(Offset.zero);
    final r = size.width / 2 - stroke / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color.withValues(alpha: 0.2),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -pi / 2,
      2 * pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

class LiveControls extends StatelessWidget {
  const LiveControls({
    super.key,
    required this.color,
    required this.running,
    required this.enabled,
    required this.showLap,
    required this.onLap,
    required this.onPause,
    required this.onEnd,
  });

  final Color color;
  final bool running;
  final bool enabled;
  final bool showLap;
  final VoidCallback onLap;
  final VoidCallback onPause;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        // Labels on one line, under discs of different sizes.
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _CircleButton(
            label: 'End',
            icon: Icons.close_rounded,
            color: Palette.red,
            onTap: enabled ? onEnd : null,
          ),
          _CircleButton(
            label: running ? 'Pause' : 'Resume',
            icon: running ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Palette.yellow,
            size: 84,
            onTap: enabled ? onPause : null,
          ),
          if (showLap)
            _CircleButton(
              label: 'Lap',
              icon: Icons.flag_rounded,
              color: color,
              onTap: enabled && running ? onLap : null,
            ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 64,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = context.resolve(this.color);
    // The whole button, label included, is one large tap target.
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      semanticLabel: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: Motion.fast,
            width: size,
            height: size,
            decoration: BoxDecoration(
              // A soft disc of the button's colour, as Apple's workout
              // controls have, in light and dark themes alike.
              color: onTap == null ? context.fillColor : context.pastel(color),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: onTap == null ? color.withValues(alpha: 0.4) : color,
              size: size * 0.42,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: context.footnote.copyWith(color: context.secondaryLabel),
          ),
        ],
      ),
    );
  }
}

class LiveToast extends StatelessWidget {
  const LiveToast({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child:
          Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: context.cardRaised,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Text(
                  text,
                  style: context.subheadline.copyWith(
                    color: context.labelColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: Motion.fast)
              .slideY(begin: Motion.reduced(context) ? 0 : -0.4, end: 0),
    );
  }
}

class StartCountdown extends StatelessWidget {
  const StartCountdown({super.key, required this.value, required this.color});

  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: context.groupedBackground.withValues(alpha: 0.94),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            // With Reduce Motion each number fades in without the zoom.
            transitionBuilder: (child, a) => ScaleTransition(
              scale: Tween(
                begin: Motion.reduced(context) ? 1.0 : 1.6,
                end: 1.0,
              ).animate(CurvedAnimation(parent: a, curve: Motion.curve)),
              child: FadeTransition(opacity: a, child: child),
            ),
            child: Text(
              '$value',
              key: ValueKey(value),
              style: TextStyle(
                color: color,
                fontSize: 160,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
