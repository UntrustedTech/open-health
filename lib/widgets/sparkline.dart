import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// A tiny line of recent values for small tiles. Missing days (null) are
/// skipped; the last point gets a dot.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.width = 64,
    this.height = 30,
  });

  final List<double?> values;
  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: width,
      height: height,
      // Resolved here: a painter would otherwise use a dynamic colour's
      // light-mode value in dark mode.
      // Its own layer, so scrolling the list around it doesn't repaint it.
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _SparkPainter(
            values,
            CupertinoDynamicColor.resolve(color, context),
          ),
        ),
      ),
    ),
  );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color);

  final List<double?> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = [
      for (var i = 0; i < values.length; i++)
        if (values[i] case final v?) (i, v),
    ];
    if (pts.isEmpty) return;
    final lo = pts.map((p) => p.$2).reduce(math.min);
    final hi = pts.map((p) => p.$2).reduce(math.max);
    final span = hi - lo == 0 ? 1 : hi - lo;
    final n = math.max(1, values.length - 1);
    Offset at((int, double) p) => Offset(
      size.width * p.$1 / n,
      size.height - 3 - (size.height - 6) * (p.$2 - lo) / span,
    );
    final path = Path()..moveTo(at(pts.first).dx, at(pts.first).dy);
    for (var i = 1; i < pts.length; i++) {
      final a = at(pts[i - 1]), b = at(pts[i]);
      final mid = (a.dx + b.dx) / 2;
      path.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    canvas.drawCircle(at(pts.last), 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      // Compared by content: each rebuild makes a new list of the same days.
      old.color != color || !listEquals(old.values, values);
}
