import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/chart_paint.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/widgets/app_segmented.dart';

typedef ChartPoint = ({DateTime date, double value});

/// A line over time with a soft gradient fill, light gridlines, month
/// labels, an optional dashed goal line and the latest value marked.
/// Drag across it to read any point.
class AreaChart extends StatefulWidget {
  const AreaChart({
    super.key,
    required this.points,
    required this.color,
    required this.format,
    this.goal,
    this.goalColor = const Color(0xFFFFCF3D),
    this.height = 200,
    this.emptyText = 'Not enough data yet.',
  });

  /// Oldest first.
  final List<ChartPoint> points;
  final Color color;

  /// Value text, e.g. "74.2 kg" (axis labels drop the unit).
  final String Function(double) format;
  final double? goal;
  final Color goalColor;
  final double height;
  final String emptyText;

  @override
  State<AreaChart> createState() => _AreaChartState();
}

class _AreaChartState extends State<AreaChart> {
  int? _touched;

  void _touch(Offset local, double width) {
    final pts = widget.points;
    if (pts.length < 2) return;
    final g = _Geometry(pts, widget.goal, Size(width, widget.height));
    var best = 0;
    var bestDx = double.infinity;
    for (var i = 0; i < pts.length; i++) {
      final dx = (g.x(pts[i].date) - local.dx).abs();
      if (dx < bestDx) {
        bestDx = dx;
        best = i;
      }
    }
    if (best != _touched) {
      HapticFeedback.selectionClick();
      setState(() => _touched = best);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pts = widget.points;
    if (pts.length < 2) {
      return SizedBox(
        height: 100,
        child: Center(
          child: Text(
            widget.emptyText,
            textAlign: TextAlign.center,
            style: context.footnote.copyWith(color: context.secondaryLabel),
          ),
        ),
      );
    }
    final touched = _touched;
    final reduce = Motion.reduced(context);
    return Semantics(
      label:
          'Chart from ${widget.format(pts.first.value)} on '
          '${DateFormat.yMMMd().format(pts.first.date)} to '
          '${widget.format(pts.last.value)} on '
          '${DateFormat.yMMMd().format(pts.last.date)}',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, c) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) => _touch(d.localPosition, c.maxWidth),
          onHorizontalDragUpdate: (d) => _touch(d.localPosition, c.maxWidth),
          onHorizontalDragEnd: (_) => setState(() => _touched = null),
          onTapDown: (d) => _touch(d.localPosition, c.maxWidth),
          onTapUp: (_) => setState(() => _touched = null),
          // A page scroll that began on the chart wins the gesture: clear.
          onTapCancel: () => setState(() => _touched = null),
          onHorizontalDragCancel: () => setState(() => _touched = null),
          child: SizedBox(
            height: widget.height,
            width: c.maxWidth,
            child: TweenAnimationBuilder<double>(
              // Replays when the data changes (e.g. a new range).
              key: ValueKey((pts.length, pts.first.date, pts.last.value)),
              tween: Tween(begin: reduce ? 1 : 0, end: 1),
              duration: Motion.slow,
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => CustomPaint(
                painter: _AreaPainter(
                  points: pts,
                  color: widget.color,
                  goal: widget.goal,
                  goalColor: widget.goalColor,
                  grid: context.separatorColor,
                  label: context.caption2.copyWith(
                    color: context.secondaryLabel,
                  ),
                  valueLabel: context.caption1.copyWith(
                    color: widget.color,
                    fontWeight: FontWeight.w700,
                  ),
                  format: widget.format,
                  t: t,
                  touched: touched,
                  dot: context.cardBackground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Plot area and value↔pixel mapping, shared by painting and touch.
class _Geometry {
  _Geometry(this.points, double? goal, this.size) {
    final values = [for (final p in points) p.value, ?goal];
    var lo = values.reduce(min), hi = values.reduce(max);
    if (hi - lo < 1e-9) {
      lo -= 1;
      hi += 1;
    }
    final pad = (hi - lo) * 0.12;
    minY = lo - pad;
    maxY = hi + pad;
    first = points.first.date;
    spanMs = max(1, points.last.date.difference(first).inMilliseconds);
  }

  static const left = 34.0, right = 12.0, top = 28.0, bottom = 22.0;

  final List<ChartPoint> points;
  final Size size;
  late final double minY, maxY;
  late final DateTime first;
  late final int spanMs;

  double get plotW => size.width - left - right;
  double get plotH => size.height - top - bottom;

  double x(DateTime d) =>
      left + plotW * d.difference(first).inMilliseconds / spanMs;
  double y(double v) => top + plotH * (1 - (v - minY) / (maxY - minY));
}

class _AreaPainter extends CustomPainter {
  _AreaPainter({
    required this.points,
    required this.color,
    required this.goal,
    required this.goalColor,
    required this.grid,
    required this.label,
    required this.valueLabel,
    required this.format,
    required this.t,
    required this.touched,
    required this.dot,
  });

  final List<ChartPoint> points;
  final Color color;
  final double? goal;
  final Color goalColor;
  final Color grid;
  final TextStyle label;
  final TextStyle valueLabel;
  final String Function(double) format;
  final double t;
  final int? touched;
  final Color dot;

  void _text(Canvas c, String s, TextStyle style, Offset at, {double ax = 0}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(at.dx - tp.width * ax, at.dy - tp.height / 2));
  }

  /// Axis numbers without units, e.g. "76".
  String _axis(double v) {
    final s = format(v);
    final n = RegExp(r'^[-+−]?[\d.,]+').firstMatch(s)?.group(0);
    return n ?? s;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = _Geometry(points, goal, size);
    final dash = Paint()
      ..color = grid
      ..strokeWidth = 1;

    // Three horizontal gridlines with values.
    for (var i = 0; i < 3; i++) {
      final v = g.minY + (g.maxY - g.minY) * (0.15 + 0.35 * i);
      final yy = g.y(v);
      drawDashedLine(
        canvas,
        Offset(_Geometry.left, yy),
        Offset(size.width - _Geometry.right, yy),
        dash,
        on: 2,
        off: 4,
      );
      _text(canvas, _axis(v), label, Offset(_Geometry.left - 6, yy), ax: 1);
    }

    // Month labels (or days for short spans) along the bottom.
    final span = points.last.date.difference(points.first.date).inDays;
    final ticks = <DateTime>[];
    if (span <= 45) {
      final step = max(1, span ~/ 4);
      for (
        var d = points.first.date;
        !d.isAfter(points.last.date);
        d = DateTime(d.year, d.month, d.day + step)
      ) {
        ticks.add(d);
      }
    } else {
      final everyMonths = max(1, (span / 30 / 5).ceil());
      var m = DateTime(points.first.date.year, points.first.date.month + 1);
      while (!m.isAfter(points.last.date)) {
        ticks.add(m);
        m = DateTime(m.year, m.month + everyMonths);
      }
    }
    final fmt = span <= 45 ? DateFormat.MMMd() : DateFormat.MMM();
    for (final d in ticks) {
      final xx = g.x(d);
      drawDashedLine(
        canvas,
        Offset(xx, _Geometry.top),
        Offset(xx, size.height - _Geometry.bottom),
        dash,
        on: 2,
        off: 4,
      );
      _text(
        canvas,
        fmt.format(d),
        label,
        Offset(xx, size.height - _Geometry.bottom / 2 + 2),
        ax: 0.5,
      );
    }

    // Goal: dashed, with its value at the end.
    if (goal case final gv?) {
      final yy = g.y(gv);
      drawDashedLine(
        canvas,
        Offset(_Geometry.left, yy),
        Offset(size.width - _Geometry.right, yy),
        Paint()
          ..color = goalColor
          ..strokeWidth = 2,
        on: 8,
        off: 6,
      );
    }

    // The line, revealed left to right as [t] goes 0 → 1.
    final path = Path();
    final offsets = [for (final p in points) Offset(g.x(p.date), g.y(p.value))];
    path.moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 1; i < offsets.length; i++) {
      final a = offsets[i - 1], b = offsets[i];
      final mid = (a.dx + b.dx) / 2;
      path.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }
    final reveal = _Geometry.left + g.plotW * t + 1;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, reveal, size.height));
    final fill = Path.from(path)
      ..lineTo(offsets.last.dx, size.height - _Geometry.bottom)
      ..lineTo(offsets.first.dx, size.height - _Geometry.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, _Geometry.top),
          Offset(0, size.height - _Geometry.bottom),
          [color.withValues(alpha: 0.35), color.withValues(alpha: 0.02)],
        ),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();

    if (t < 1) return;
    final last = offsets.last;
    canvas.drawCircle(last, 6, Paint()..color = color);
    canvas.drawCircle(last, 2.5, Paint()..color = dot);
    if (touched == null) {
      // Above and to the left of the dot, clear of a rising line; below it
      // when there's no room above.
      final above = last.dy > 20;
      _text(
        canvas,
        format(points.last.value),
        valueLabel,
        Offset(last.dx, last.dy + (above ? -20 : 20)),
        ax: 1,
      );
    }

    final i = touched;
    if (i == null) return;
    final p = offsets[i];
    canvas.drawLine(
      Offset(p.dx, _Geometry.top),
      Offset(p.dx, size.height - _Geometry.bottom),
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(p, 7, Paint()..color = color);
    canvas.drawCircle(p, 3, Paint()..color = dot);
    final tip =
        '${format(points[i].value)} · ${DateFormat.MMMd().format(points[i].date)}';
    final tp = TextPainter(
      text: TextSpan(
        text: tip,
        style: valueLabel.copyWith(color: const Color(0xFFFFFFFF)),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final w = tp.width + 16, h = tp.height + 8;
    final bx = (p.dx - w / 2).clamp(0.0, size.width - w);
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(bx, 0, w, h),
      const Radius.circular(8),
    );
    canvas.drawRRect(box, Paint()..color = color);
    tp.paint(canvas, Offset(bx + 8, 4));
  }

  @override
  bool shouldRepaint(_AreaPainter old) =>
      old.t != t ||
      old.touched != touched ||
      old.points != points ||
      old.color != color ||
      old.goal != goal ||
      old.grid != grid;
}

/// Rounded chip-style range picker ("1M 3M 1Y All").
class RangePicker<T extends Object> extends StatelessWidget {
  const RangePicker({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: AppSegmented<T>(
      groupValue: selected,
      children: {
        for (final v in values)
          v: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(label(v)),
          ),
      },
      onValueChanged: (v) {
        if (v != null) onChanged(v);
      },
    ),
  );
}
