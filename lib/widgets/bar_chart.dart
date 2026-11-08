import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/models/personalization.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/chart_paint.dart';
import 'package:health_app/widgets/motion.dart';

/// Apple Health-style bar chart: slim bars with lightly rounded tops, light
/// gridlines at round values with their labels on the right, and an
/// optional dashed goal line. Null values render as empty slots.
/// Tap or drag across the chart to select a bar; [onSelect] receives its index.
/// Drawn as bars, a line, dots or dashes: [style], or the user's choice in
/// Appearance.
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.values,
    required this.color,
    this.labels = const [],
    this.goal,
    this.selected,
    this.onSelect,
    this.axisLabel,
    this.height = 200,
    this.style,
  });

  final List<double?> values;
  final Color color;

  /// Optional x-axis labels; empty strings are skipped.
  final List<String> labels;

  /// Draws a dashed goal line when set.
  final double? goal;
  final int? selected;
  final ValueChanged<int?>? onSelect;

  /// Formats y-axis values; when null no y-axis is drawn.
  final String Function(double)? axisLabel;
  final double height;
  final ChartStyle? style;

  static const _axisWidth = 40.0;

  /// What VoiceOver reads: the number of bars and, with [axisLabel], the
  /// highest one and the selected one.
  String _describe() {
    final shown = values.nonNulls;
    final format = axisLabel;
    if (format == null || shown.isEmpty) return tr('${values.length} bars');
    final pick = selected;
    final picked = pick != null && pick < values.length ? values[pick] : null;
    return [
      tr('${values.length} bars, highest ${format(shown.reduce(max))}'),
      if (picked != null) tr('selected ${format(picked)}'),
    ].join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final grow = !Motion.reduced(context);
    final style =
        this.style ??
        context.select<HealthStore, ChartStyle>(
          (s) => s.personalization.chartStyle,
        );
    return Semantics(
      label: _describe(),
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final plotWidth =
              constraints.maxWidth - (axisLabel == null ? 0 : _axisWidth);
          void select(Offset local) {
            if (values.isEmpty || local.dx > plotWidth) return;
            final slot = plotWidth / values.length;
            final index = (local.dx / slot).floor().clamp(0, values.length - 1);
            onSelect?.call(index);
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => select(d.localPosition),
            onHorizontalDragUpdate: (d) => select(d.localPosition),
            child: TweenAnimationBuilder<double>(
              key: ValueKey(values.length),
              tween: Tween(begin: grow ? 0 : 1, end: 1),
              duration: grow ? Motion.slow : Duration.zero,
              curve: Curves.easeOutQuart,
              builder: (context, t, _) => CustomPaint(
                size: Size(constraints.maxWidth, height),
                painter: _BarPainter(
                  values: values,
                  labels: labels,
                  color: color,
                  goal: goal,
                  selected: selected,
                  gridColor: context.separatorColor,
                  labelStyle: context.caption2.copyWith(
                    color: context.secondaryLabel,
                  ),
                  axisLabel: axisLabel,
                  plotWidth: plotWidth,
                  t: t,
                  style: style,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Rounds [v] up to 1, 2, 2.5 or 5 times a power of ten.
double niceCeiling(double v) {
  if (v <= 0) return 1;
  final magnitude = pow(10, (log(v) / ln10).floor()).toDouble();
  final f = v / magnitude;
  final nice = f <= 1
      ? 1.0
      : f <= 2
      ? 2.0
      : f <= 2.5
      ? 2.5
      : f <= 5
      ? 5.0
      : 10.0;
  return nice * magnitude;
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.goal,
    required this.selected,
    required this.gridColor,
    required this.labelStyle,
    required this.axisLabel,
    required this.plotWidth,
    required this.t,
    required this.style,
  });

  final List<double?> values;
  final List<String> labels;
  final Color color;
  final double? goal;
  final int? selected;
  final Color gridColor;
  final TextStyle labelStyle;
  final String Function(double)? axisLabel;
  final double plotWidth;
  final double t;
  final ChartStyle style;

  static const _labelHeight = 18.0;

  void _text(Canvas canvas, String text, Offset at, {bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center ? at - Offset(tp.width / 2, 0) : at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = size.height - _labelHeight;
    final present = values.nonNulls;
    final maxValue = max(
      present.isEmpty ? 1.0 : present.reduce(max),
      goal ?? 0,
    );
    final scaleMax = niceCeiling(maxValue);

    // Gridlines at 0, half and the top, labelled on the right.
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;
    for (final f in const [0.0, 0.5, 1.0]) {
      final y = chartHeight - chartHeight * f;
      canvas.drawLine(Offset(0, y), Offset(plotWidth, y), grid);
      final label = axisLabel;
      if (label != null) {
        _text(canvas, label(scaleMax * f), Offset(plotWidth + 6, y - 7));
      }
    }

    final slot = plotWidth / max(values.length, 1);
    final barWidth = (slot * 0.56).clamp(2.0, 24.0);
    final radius = Radius.circular(min(barWidth * 0.3, 5));

    // Points of the line styles, in runs broken at empty days.
    final runs = <List<Offset>>[];
    var joined = false;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final x = slot * i + (slot - barWidth) / 2;
      final cx = x + barWidth / 2;
      if (v != null && v > 0) {
        final h = max(2.0, chartHeight * (v / scaleMax) * t);
        final top = chartHeight - h;
        final isSelected = selected == null || selected == i;
        final paint = Paint()
          ..color = isSelected ? color : color.withValues(alpha: 0.3);
        final dot = (barWidth / 2).clamp(2.5, 5.0);
        switch (style) {
          case ChartStyle.bars:
            canvas.drawRRect(
              RRect.fromRectAndCorners(
                Rect.fromLTWH(x, top, barWidth, h),
                topLeft: radius,
                topRight: radius,
              ),
              paint,
            );
          case ChartStyle.pills:
            final pill = max(h, barWidth);
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(x, chartHeight - pill, barWidth, pill),
                Radius.circular(barWidth / 2),
              ),
              paint,
            );
          case ChartStyle.dashes:
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(x, top - 2, barWidth, 4),
                const Radius.circular(2),
              ),
              paint,
            );
          case ChartStyle.dots:
            canvas.drawCircle(Offset(cx, top), dot, paint);
          case ChartStyle.stems:
            canvas.drawLine(
              Offset(cx, chartHeight),
              Offset(cx, top),
              Paint()
                ..color = paint.color.withValues(alpha: paint.color.a * 0.5)
                ..strokeWidth = 2
                ..strokeCap = StrokeCap.round,
            );
            canvas.drawCircle(Offset(cx, top), dot, paint);
          case ChartStyle.lines || ChartStyle.curve:
            if (!joined) runs.add([]);
            runs.last.add(Offset(cx, top));
            joined = true;
            // Dots too, so a day with no neighbours still shows.
            if (style == ChartStyle.lines || selected == i) {
              canvas.drawCircle(
                Offset(cx, top),
                selected == i ? 4 : 2.5,
                paint,
              );
            }
        }
      } else {
        // An empty day breaks the line rather than dropping it to zero.
        joined = false;
      }
      if (i < labels.length && labels[i].isNotEmpty) {
        _text(
          canvas,
          labels[i],
          Offset(slot * i + slot / 2, chartHeight + 4),
          center: true,
        );
      }
    }
    for (final run in runs) {
      _drawRun(canvas, run, chartHeight, smooth: style == ChartStyle.curve);
    }

    final g = goal;
    if (g != null && g > 0) {
      final y = chartHeight - chartHeight * (g / scaleMax);
      final dash = Paint()
        ..color = color.withValues(alpha: 0.9)
        ..strokeWidth = 1;
      drawDashedLine(canvas, Offset(0, y), Offset(plotWidth, y), dash);
    }
  }

  /// A line through [run] (smooth for Curve) with a soft fade beneath.
  void _drawRun(
    Canvas canvas,
    List<Offset> run,
    double bottom, {
    required bool smooth,
  }) {
    if (run.length < 2) {
      if (smooth) canvas.drawCircle(run.first, 3, Paint()..color = color);
      return;
    }
    final path = Path()..moveTo(run.first.dx, run.first.dy);
    for (var i = 1; i < run.length; i++) {
      final (a, b) = (run[i - 1], run[i]);
      if (smooth) {
        // Control points level with each end: no overshoot past a value.
        final mid = (a.dx + b.dx) / 2;
        path.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
      } else {
        path.lineTo(b.dx, b.dy);
      }
    }
    final area = Path.from(path)
      ..lineTo(run.last.dx, bottom)
      ..lineTo(run.first.dx, bottom)
      ..close();
    final top = run.map((p) => p.dy).reduce(min);
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: smooth ? 0.32 : 0.16),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTRB(0, top, plotWidth, bottom)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = smooth ? 2.5 : 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.t != t ||
      old.values != values ||
      old.selected != selected ||
      old.goal != goal ||
      old.color != color ||
      old.gridColor != gridColor ||
      old.plotWidth != plotWidth ||
      old.style != style;
}

/// Tiny trend line used on summary cards.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, required this.color});

  final List<double?> values;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      // Its own layer, so scrolling the list around it doesn't repaint it.
      RepaintBoundary(
        child: CustomPaint(
          painter: _SparkPainter(values, color),
          size: Size.infinite,
        ),
      );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color);

  final List<double?> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final present = values.nonNulls.toList();
    if (present.isEmpty) return;
    final lo = present.reduce(min);
    final hi = present.reduce(max);
    final span = hi - lo == 0 ? 1 : hi - lo;
    final step = values.length > 1 ? size.width / (values.length - 1) : 0.0;

    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        if (values[i] != null)
          Offset(
            i * step,
            size.height - 3 - (size.height - 6) * ((values[i]! - lo) / span),
          ),
    ];
    if (points.length == 1) {
      canvas.drawCircle(points.first, 3, Paint()..color = color);
      return;
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final fill = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.drawCircle(points.last, 3.2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      !listEquals(old.values, values) || old.color != color;
}
