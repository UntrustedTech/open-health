import 'dart:math';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:intl/intl.dart' show DateFormat;

import 'package:health_app/l10n/text.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/chart_paint.dart';
import 'package:health_app/widgets/motion.dart';

/// A smooth trend line with dots, a soft fill and min/max labels.
class TrendLineChart extends StatelessWidget {
  const TrendLineChart({
    super.key,
    required this.points,
    required this.color,
    required this.format,
    this.height = 180,
    this.goal,
    this.emptyText = 'Log this exercise twice to see a trend.',
    this.minSpan = 0,
    this.trend,
  });

  /// A smoothed line drawn over the points (one value per point); the
  /// points then show faintly behind it.
  final List<double>? trend;

  /// Draws a dashed target line (e.g. goal weight).
  final double? goal;
  final String emptyText;

  final List<({DateTime date, double value})> points;
  final Color color;
  final String Function(double) format;
  final double height;

  /// The smallest range the value axis shows, so small day-to-day
  /// wobbles don't look like big swings.
  final double minSpan;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            emptyText,
            style: context.footnote.copyWith(color: context.secondaryLabel),
          ),
        ),
      );
    }
    final values = points.map((p) => p.value).toList();
    final smooth = trend != null && trend!.length == values.length
        ? trend
        : null;
    final shown = smooth ?? values;
    return Semantics(
      label: 'Trend from ${format(shown.first)} to ${format(shown.last)}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: height,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Motion.slow,
              curve: Curves.easeOutQuart,
              builder: (context, t, _) => CustomPaint(
                painter: _LinePainter(
                  values: values,
                  minSpan: minSpan,
                  color: color,
                  grid: context.separatorColor,
                  label: context.caption2.copyWith(
                    color: context.secondaryLabel,
                  ),
                  format: format,
                  t: t,
                  goal: goal,
                  trend: smooth,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final d in [points.first.date, points.last.date])
                Text(
                  DateFormat.MMMd().format(d),
                  style: context.caption2.copyWith(
                    color: context.secondaryLabel,
                  ),
                ),
            ],
          ),
          if (smooth != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _Key(color: color.withValues(alpha: 0.45), dot: true),
                const SizedBox(width: 6),
                Text('Weigh-ins', style: context.caption1),
                const SizedBox(width: 16),
                _Key(color: color, dot: false),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Trend ${format(smooth.last)}',
                    style: context.caption1.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.color, required this.dot});

  final Color color;
  final bool dot;

  @override
  Widget build(BuildContext context) => Container(
    width: dot ? 8 : 16,
    height: dot ? 8 : 3,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    this.trend,
    required this.values,
    required this.minSpan,
    required this.color,
    required this.grid,
    required this.label,
    required this.format,
    required this.t,
    required this.goal,
  });

  final double? goal;
  final List<double>? trend;

  final List<double> values;
  final Color color;
  final double minSpan;
  final Color grid;
  final TextStyle label;
  final String Function(double) format;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const axis = 44.0;
    final w = size.width - axis;
    final g = goal;
    final all = [...values, ...?trend];
    var lo = min(all.reduce(min), g ?? double.infinity);
    var hi = max(all.reduce(max), g ?? double.negativeInfinity);
    if (hi - lo < minSpan) {
      final mid = (hi + lo) / 2;
      lo = mid - minSpan / 2;
      hi = mid + minSpan / 2;
    }
    final span = hi - lo == 0 ? 1 : hi - lo;
    final top = 8.0, bottom = size.height - 8;
    Offset atValue(int i, double v) => Offset(
      w * i / (values.length - 1),
      bottom - (bottom - top) * ((v - lo) / span) * t,
    );
    Offset at(int i) => atValue(i, values[i]);
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 0.5;
    for (final (y, v) in [(top, hi), (bottom, lo)]) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: format(v), style: label),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(w + 6, y - tp.height / 2));
    }
    if (g != null) {
      final y = bottom - (bottom - top) * ((g - lo) / span);
      final dash = Paint()
        ..color = color.withValues(alpha: 0.8)
        ..strokeWidth = 1.2;
      drawDashedLine(canvas, Offset(0, y), Offset(w, y), dash);
      final tp = TextPainter(
        text: TextSpan(
          text: 'Goal ${format(g)}',
          style: label.copyWith(color: color),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(4, y - tp.height - 2));
    }
    Path curve(Offset Function(int i) pt) {
      final path = Path()..moveTo(pt(0).dx, pt(0).dy);
      for (var i = 1; i < values.length; i++) {
        final p0 = pt(i - 1), p1 = pt(i);
        final mid = (p0.dx + p1.dx) / 2;
        path.cubicTo(mid, p0.dy, mid, p1.dy, p1.dx, p1.dy);
      }
      return path;
    }

    final tr = trend;
    // With a trend, the trend is the main line and the weigh-ins sit
    // faintly behind it.
    final main = tr == null ? curve(at) : curve((i) => atValue(i, tr[i]));
    final mainAt = tr == null ? at : (int i) => atValue(i, tr[i]);
    final fill = Path.from(main)
      ..lineTo(mainAt(values.length - 1).dx, bottom)
      ..lineTo(0, bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, top, w, bottom - top)),
    );
    if (tr != null) {
      canvas.drawPath(
        curve(at),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color.withValues(alpha: 0.35),
      );
      for (var i = 0; i < values.length; i++) {
        canvas.drawCircle(
          at(i),
          2.5,
          Paint()..color = color.withValues(alpha: 0.55),
        );
      }
    }
    canvas.drawPath(
      main,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = tr == null ? 2.5 : 3
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    if (tr == null) {
      for (var i = 0; i < values.length; i++) {
        canvas.drawCircle(
          at(i),
          i == values.length - 1 ? 4.5 : 3,
          Paint()..color = color,
        );
      }
    } else {
      canvas.drawCircle(mainAt(values.length - 1), 4.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.t != t ||
      old.values != values ||
      old.color != color ||
      old.goal != goal ||
      old.trend != trend;
}
