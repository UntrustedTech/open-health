import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The app's mark, as in its icon: one line round an open ring and in
/// through the middle as a pulse. Drawn in [color] to fill [size].
class AppMark extends StatelessWidget {
  const AppMark({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _AppMarkPainter(color));
}

/// The mark's line, centred on the origin, as in a 1024 px icon (see
/// tool/make_icon.py): it spans [AppMarkPath.box] and is [AppMarkPath.width]
/// wide.
abstract final class AppMarkPath {
  static const box = 590.0;
  static const width = 66.0;
  static const _radius = 262.0;
  static const _pulse = [
    Offset(-120, 0),
    Offset(-62, -118),
    Offset(12, 130),
    Offset(70, -40),
    Offset(104, 0),
    Offset(170, 0),
  ];

  static Path build() {
    const start = -118 * math.pi / 180;
    final path = Path()
      ..addArc(
        Rect.fromCircle(center: Offset.zero, radius: _radius),
        start,
        math.pi - start,
      );
    for (final p in _pulse) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  /// A stroke for the line, [width] wide.
  static Paint stroke(double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
}

class _AppMarkPainter extends CustomPainter {
  const _AppMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / AppMarkPath.box;
    canvas
      ..translate(size.width / 2, size.height / 2)
      ..scale(scale);
    canvas.drawPath(
      AppMarkPath.build(),
      AppMarkPath.stroke(AppMarkPath.width)..color = color,
    );
  }

  @override
  bool shouldRepaint(_AppMarkPainter old) => old.color != color;
}
