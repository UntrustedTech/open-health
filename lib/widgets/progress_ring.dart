import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/motion.dart';

/// A progress ring with a soft colour sweep on a faint track, with [child] centred inside.
/// Animates to new progress values.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.color,
    required this.size,
    this.stroke = 10,
    this.child,
  });

  /// 0..1; more is shown as a full ring.
  final double progress;
  final Color color;
  final double size;
  final double stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Semantics(
    // Whatever [child] says, plus how full the ring is.
    container: true,
    value: '${(progress.clamp(0.0, 1.0) * 100).round()}%',
    child: SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress.clamp(0.0, 1.0)),
        duration: Motion.reduced(context) ? Duration.zero : Motion.slow,
        curve: Motion.curve,
        builder: (context, p, _) => CustomPaint(
          painter: _RingPainter(
            progress: p,
            color: context.resolve(color),
            stroke: stroke,
            track: context.labelColor.withValues(alpha: 0.08),
          ),
          child: Padding(
            padding: EdgeInsets.all(stroke + 6),
            // Large text shrinks to fit inside the ring.
            child: FittedBox(fit: BoxFit.scaleDown, child: child),
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.stroke,
    required this.track,
  });

  final double progress;
  final Color color;
  final double stroke;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    if (progress <= 0) return;
    // A soft sweep from a lighter shade to the full colour, like the
    // health score ring in the design references.
    final sweep = math.pi * 2 * progress;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      // Opaque base colour: a shader is drawn at the paint colour's
      // opacity, which is still the faint track's.
      paint
        ..color = const Color(0xFF000000)
        ..shader = SweepGradient(
          endAngle: math.max(sweep, 0.01),
          colors: [Color.lerp(color, const Color(0xFFFFFFFF), 0.35)!, color],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.track != track ||
      old.color != color ||
      old.stroke != stroke;
}
