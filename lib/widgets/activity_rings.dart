import 'dart:math';

import 'package:flutter/cupertino.dart';

import 'package:health_app/widgets/motion.dart';

class RingData {
  const RingData({required this.progress, required this.color});

  /// 1.0 means the goal is met; values above 1 draw a second lap.
  final double progress;
  final Color color;
}

/// Concentric progress rings in the style of Apple's Activity rings:
/// gradient arcs and a shadowed head once a ring passes 100%. Rings
/// animate in when first shown.
class ActivityRings extends StatelessWidget {
  const ActivityRings({
    super.key,
    required this.rings,
    this.size = 140,
    this.strokeWidth = 16,
  });

  final List<RingData> rings;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      label: 'Activity rings',
      value: [for (final r in rings) '${(r.progress * 100).round()}%']
          .join(', '),
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: reduced ? 1 : 0, end: 1),
          duration: Motion.slow,
          curve: Curves.easeOutQuart,
          builder: (context, t, _) => CustomPaint(
            painter: _RingsPainter(
              // Ring colours may adapt to light and dark mode.
              rings: [
                for (final r in rings)
                  RingData(
                    progress: r.progress,
                    color: CupertinoDynamicColor.resolve(r.color, context),
                  ),
              ],
              strokeWidth: strokeWidth,
              t: t,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({
    required this.rings,
    required this.strokeWidth,
    required this.t,
  });

  static const _start = -pi / 2;

  final List<RingData> rings;
  final double strokeWidth;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final gap = strokeWidth * 0.18;
    for (var i = 0; i < rings.length; i++) {
      final radius = size.width / 2 - strokeWidth / 2 - i * (strokeWidth + gap);
      if (radius <= 0) break;
      _paintRing(canvas, center, radius, rings[i]);
    }
  }

  void _paintRing(Canvas canvas, Offset c, double r, RingData ring) {
    final rect = Rect.fromCircle(center: c, radius: r);
    final dark = Color.lerp(ring.color, const Color(0xFF000000), 0.22)!;
    final light = Color.lerp(ring.color, const Color(0xFFFFFFFF), 0.08)!;

    // Track.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = ring.color.withValues(alpha: 0.2),
    );

    final sweep = 2 * pi * ring.progress.clamp(0.0, 3.0) * t;
    if (sweep <= 0.001) return;

    Offset at(double angle) =>
        c + Offset(cos(_start + angle) * r, sin(_start + angle) * r);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    if (sweep < 2 * pi) {
      // Butt-ended gradient arc with separate round caps, so the gradient
      // never wraps around onto the start cap.
      stroke.shader = SweepGradient(
        endAngle: sweep,
        colors: [dark, light],
        transform: const GradientRotation(_start),
      ).createShader(rect);
      canvas
        ..drawArc(rect, _start, sweep, false, stroke)
        ..drawCircle(at(0), strokeWidth / 2, Paint()..color = dark)
        ..drawCircle(at(sweep), strokeWidth / 2, Paint()..color = light);
      return;
    }

    // Past 100%: a full gradient ring rotated so its seam (darkest meets
    // lightest) sits exactly under the head, which casts a shadow forward
    // onto the lap beneath, like the Fitness app.
    final head = sweep % (2 * pi);
    stroke.shader = SweepGradient(
      colors: [dark, light],
      transform: GradientRotation(_start + head),
    ).createShader(rect);
    canvas.drawCircle(c, r, stroke);

    final tip = at(head);
    final ahead = Offset(-sin(_start + head), cos(_start + head));
    canvas
      ..drawCircle(
        tip + ahead * (strokeWidth * 0.15),
        strokeWidth / 2,
        Paint()
          ..color = const Color(0x80000000)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 0.2),
      )
      ..drawCircle(tip, strokeWidth / 2, Paint()..color = light);
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.t != t || old.rings != rings || old.strokeWidth != strokeWidth;
}
