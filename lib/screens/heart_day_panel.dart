import 'dart:math';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/l10n/language.dart';
import 'package:flutter/services.dart';

import 'package:health_app/insights/heart_trends.dart';
import 'package:health_app/insights/heart_zones.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/health_entry.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/personalization.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/sync/health_sample.dart';
import 'package:health_app/sync/health_sync_service.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/widgets/detail_cards.dart';
import 'package:health_app/widgets/ios.dart';

/// The Heart Rate page's Day tab: every heart rate reading of a day, read
/// live from Health Connect plus any added by hand, with the workouts and
/// sleep in it.
class HeartDayPanel extends StatefulWidget {
  const HeartDayPanel({super.key});

  static const workoutColor = Palette.orange;
  static const sleepColor = Palette.iris;

  @override
  State<HeartDayPanel> createState() => _HeartDayPanelState();
}

typedef _Read = ({List<HealthSample> heart, List<HealthSample> sleep});

class _HeartDayPanelState extends State<HeartDayPanel> {
  late DateTime _day = context.read<HealthStore>().today;
  late Future<_Read> _read = _load();

  DateTime get _end => DateTime(_day.year, _day.month, _day.day + 1);

  Future<_Read> _load() async {
    final sync = context.read<HealthSyncService>();
    // Readings added by hand; imported entries are daily averages (the live
    // read has their readings) and demo ones would mix with real data.
    final added = [
      for (final e in context.read<HealthStore>().entriesFor(
        MetricType.heartRate,
      ))
        if (e.source == EntrySource.manual &&
            !e.date.isBefore(_day) &&
            e.date.isBefore(_end))
          HealthSample(
            type: MetricType.heartRate,
            value: e.value,
            start: e.date,
            end: e.date,
          ),
    ];
    // Last night began the evening before.
    final evening = DateTime(_day.year, _day.month, _day.day - 1, 12);
    final (heart, sleep) = await (
      sync.readAll(MetricType.heartRate, _day, _end),
      sync.readAll(MetricType.sleep, evening, _end),
    ).wait;
    return (heart: [...heart, ...added], sleep: sleep);
  }

  void _move(int days) => setState(() {
    _day = DateTime(_day.year, _day.month, _day.day + days);
    _read = _load();
  });

  @override
  Widget build(BuildContext context) {
    final today = context.watch<HealthStore>().today;
    final workouts = [
      for (final w in context.watch<WorkoutStore>().all)
        if (w.end.isAfter(_day) && w.start.isBefore(_end))
          (label: w.type.label, start: w.start, end: w.end),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Chevron(
              icon: Icons.chevron_left_rounded,
              label: 'Previous day',
              onTap: () => _move(-1),
            ),
            Expanded(
              child: Text(
                formatDay(_day, today),
                textAlign: TextAlign.center,
                style: context.headline,
              ),
            ),
            _Chevron(
              icon: Icons.chevron_right_rounded,
              label: 'Next day',
              onTap: _day.isBefore(today) ? () => _move(1) : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder(
          future: _read,
          builder: (context, snap) {
            if (snap.hasError) {
              return _Note(
                'Couldn\'t read ${context.read<HealthSyncService>().sourceName}. '
                'Try again in a moment.',
              );
            }
            final read = snap.data;
            if (read == null) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: CupertinoActivityIndicator(),
              );
            }
            final day = HeartDay.of(
              read.heart,
              workouts: workouts,
              sleep: HeartDay.sleepFor([
                for (final s in read.sleep) (start: s.start, end: s.end),
              ], _day),
            );
            return _DayView(day: day, from: _day, to: _end);
          },
        ),
      ],
    );
  }
}

class _DayView extends StatelessWidget {
  const _DayView({required this.day, required this.from, required this.to});

  final HeartDay day;
  final DateTime from;
  final DateTime to;

  String _bpm(double v) => '${v.round()} bpm';

  // Last night's sleep began the day before, so it says which day.
  String _span(HeartMoment m) =>
      '${m.start.isBefore(from) ? '${DateFormat.E().format(m.start)} ' : ''}'
      '${formatTime(m.start)} – ${formatTime(m.end)}';

  /// "during Run" when [r] falls in a workout or sleep.
  String _when(HealthSample r) {
    final m = day.moments.where((m) => m.contains(r.start)).firstOrNull;
    return m == null
        ? formatTime(r.start)
        : '${formatTime(r.start)} · ${m.label}';
  }

  @override
  Widget build(BuildContext context) {
    final all = day.all;
    if (all == null) {
      return const _Note(
        'No heart rate readings this day. They appear when your watch or '
        'another app saves them to Health Connect.',
      );
    }
    final rest = day.rest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IosCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Every Reading', style: context.headline),
                        Text(
                          '${all.count} readings · average '
                          '${_bpm(all.average)}',
                          style: context.footnote.copyWith(
                            color: context.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size.square(AppTheme.minTapTarget),
                    onPressed: () =>
                        _ReadingsScreen.open(context, day, from, to),
                    child: Icon(
                      Icons.open_in_full_rounded,
                      size: 20,
                      semanticLabel: tr('Expand Chart'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Semantics(
                label:
                    'Heart rate through the day, from '
                    '${_bpm(all.lowest.value)} to ${_bpm(all.highest.value)}',
                excludeSemantics: true,
                child: SizedBox(
                  height: 180,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _DayPainter(
                      day: day,
                      from: from,
                      to: to,
                      line: context.resolve(MetricType.heartRate.color),
                      workout: context.resolve(HeartDayPanel.workoutColor),
                      sleep: context.resolve(HeartDayPanel.sleepColor),
                      grid: context.separatorColor,
                      label: context.caption2.copyWith(
                        color: context.secondaryLabel,
                      ),
                      dots:
                          context.select<HealthStore, ChartStyle>(
                            (s) => s.personalization.chartStyle,
                          ) ==
                          ChartStyle.dots,
                    ),
                  ),
                ),
              ),
              if (day.moments.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  children: [
                    if (day.moments.any((m) => m.kind == MomentKind.workout))
                      const _Key(HeartDayPanel.workoutColor, 'Workout'),
                    if (day.moments.any((m) => m.kind == MomentKind.sleep))
                      const _Key(HeartDayPanel.sleepColor, 'Asleep'),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (HeartBins.fromSamples(day.readings)[from] case final bins?)
          HeartZonesCard(day: bins),
        const SizedBox(height: 12),
        _HourCard(hours: day.hourly(from)),
        const SizedBox(height: 24),
        GroupedSection(
          header: 'Highlights',
          hasLeading: false,
          children: [
            InfoRow(title: 'Average', value: _bpm(all.average)),
            InfoRow(
              title: 'Lowest',
              subtitle: _when(all.lowest),
              value: _bpm(all.lowest.value),
            ),
            InfoRow(
              title: 'Highest',
              subtitle: _when(all.highest),
              value: _bpm(all.highest.value),
            ),
          ],
        ),
        GroupedSection(
          header: 'Workouts and Sleep',
          footer:
              'Read from Health Connect each time you open this page. '
              'Workouts come from this app and Health Connect.',
          children: [
            for (final m in day.moments)
              InfoRow(
                leading: Icon(
                  m.kind == MomentKind.sleep
                      ? Icons.bedtime_rounded
                      : Icons.directions_run_rounded,
                  color: context.resolve(
                    m.kind == MomentKind.sleep
                        ? HeartDayPanel.sleepColor
                        : HeartDayPanel.workoutColor,
                  ),
                ),
                title: m.label,
                subtitle: switch (m.stats) {
                  final s? =>
                    '${_span(m)} · ${s.lowest.value.round()}–'
                        '${s.highest.value.round()}',
                  null => '${_span(m)} · no readings',
                },
                value: switch (m.stats) {
                  final s? => _bpm(s.average),
                  null => null,
                },
              ),
            if (rest != null)
              InfoRow(
                leading: Icon(
                  Icons.favorite_rounded,
                  color: context.resolve(MetricType.heartRate.color),
                ),
                title: 'Rest of the Day',
                subtitle:
                    '${rest.lowest.value.round()}–'
                    '${rest.highest.value.round()} bpm',
                value: _bpm(rest.average),
              ),
          ],
        ),
      ],
    );
  }
}

/// Round bpm values to mark between [lo] and [hi]: about four of them.
List<int> _ticks(double lo, double hi) {
  final step = [
    10,
    20,
    25,
    50,
  ].firstWhere((s) => (hi - lo) / s <= 4, orElse: () => 100);
  return [for (var v = (lo / step).ceil() * step; v <= hi; v += step) v];
}

TextPainter _labelPainter(String text, TextStyle style) => TextPainter(
  text: TextSpan(text: text, style: style),
  textDirection: TextDirection.ltr,
)..layout();

/// Faint lines at round bpm values between [lo] and [hi], labelled at the
/// right edge (as on the week chart) unless [labels] is false. Returns the
/// width the labels take.
double _bpmScale(
  Canvas canvas,
  double width,
  double lo,
  double hi,
  double Function(double) y,
  Color grid,
  TextStyle label, {
  bool labels = true,
}) {
  final painters = [
    for (final v in _ticks(lo, hi))
      (v, labels ? _labelPainter('$v', label) : null),
  ];
  final gutter = labels
      ? painters.fold(0.0, (m, p) => max(m, p.$2!.width)) + 6
      : 0.0;
  final line = Paint()
    ..color = grid
    ..strokeWidth = 0.5;
  for (final (v, tp) in painters) {
    final dy = y(v.toDouble());
    canvas.drawLine(Offset(0, dy), Offset(width - gutter, dy), line);
    tp?.paint(canvas, Offset(width - tp.width, dy - tp.height / 2));
  }
  return gutter;
}

/// The bpm range a day's chart spans, a little beyond its readings.
(double, double) _dayRange(HeartStats all) =>
    ((all.lowest.value - 10).clamp(30, 200).toDouble(), all.highest.value + 10);

/// Heart rate over the day, with workouts and sleep shaded behind it.
class _DayPainter extends CustomPainter {
  _DayPainter({
    required this.day,
    required this.from,
    required this.to,
    required this.line,
    required this.workout,
    required this.sleep,
    required this.grid,
    required this.label,
    required this.dots,
    this.scale = true,
    this.picked,
  });

  final HeartDay day;
  final DateTime from;
  final DateTime to;
  final Color line;
  final Color workout;
  final Color sleep;
  final Color grid;
  final TextStyle label;

  /// Only dots, no line (the Dots chart style).
  final bool dots;

  /// Labels the bpm lines; off when they're drawn beside a scrolling chart.
  final bool scale;

  /// A reading the user tapped, marked with a line and a ring.
  final HealthSample? picked;

  /// Readings further apart than this aren't joined (watch off).
  static const _gap = Duration(minutes: 10);
  static const _axis = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height - _axis;
    final (lo, hi) = _dayRange(day.all!);
    double y(double v) => h - (v - lo) / (hi - lo) * h;
    final w =
        size.width -
        _bpmScale(canvas, size.width, lo, hi, y, grid, label, labels: scale);
    final span = to.difference(from).inSeconds;
    double x(DateTime t) =>
        (t.difference(from).inSeconds / span).clamp(0, 1) * w;

    for (final m in day.moments) {
      final color = m.kind == MomentKind.sleep ? sleep : workout;
      canvas.drawRect(
        Rect.fromLTRB(x(m.start), 0, x(m.end), h),
        Paint()..color = color.withValues(alpha: 0.18),
      );
    }

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 0.5;
    // Hours marked as often as there's room for, when zoomed in.
    final step = [1, 2, 3].firstWhere((s) => w / 24 * s >= 56, orElse: () => 6);
    for (var hour = 0; hour <= 24; hour += step) {
      final t = DateTime(from.year, from.month, from.day, hour);
      final dx = x(t);
      canvas.drawLine(Offset(dx, 0), Offset(dx, h), gridPaint);
      if (hour == 24) continue;
      _labelPainter(
        DateFormat.j().format(t),
        label,
      ).paint(canvas, Offset(dx + 2, h + 2));
    }

    final path = Path();
    HealthSample? prev;
    for (final r in day.readings) {
      final p = Offset(x(r.start), y(r.value));
      if (prev == null || r.start.difference(prev.start) > _gap) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
      prev = r;
    }
    if (!dots) {
      canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.round,
      );
    }
    // Lone readings (no neighbour within the gap) still show as dots.
    final dot = Paint()..color = line;
    for (final r in day.readings) {
      canvas.drawCircle(Offset(x(r.start), y(r.value)), dots ? 2 : 1.5, dot);
    }
    if (picked case final p?) {
      final at = Offset(x(p.start), y(p.value));
      canvas.drawLine(
        Offset(at.dx, 0),
        Offset(at.dx, h),
        Paint()
          ..color = line.withValues(alpha: 0.6)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(at, 6, Paint()..color = line);
      canvas.drawCircle(
        at,
        6,
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_DayPainter old) =>
      old.day != day ||
      old.line != line ||
      old.grid != grid ||
      old.dots != dots ||
      old.picked != picked;
}

/// The day's readings full screen: zoom in, scroll through the day and tap
/// a point to read it.
class _ReadingsScreen extends StatefulWidget {
  const _ReadingsScreen({
    required this.day,
    required this.from,
    required this.to,
  });

  final HeartDay day;
  final DateTime from;
  final DateTime to;

  static Future<void> open(
    BuildContext context,
    HeartDay day,
    DateTime from,
    DateTime to,
  ) => Navigator.of(context).push(
    AppRoute<void>(
      title: 'Every Reading',
      builder: (_) => _ReadingsScreen(day: day, from: from, to: to),
    ),
  );

  @override
  State<_ReadingsScreen> createState() => _ReadingsScreenState();
}

class _ReadingsScreenState extends State<_ReadingsScreen> {
  static const _maxZoom = 16.0;
  static const _scaleWidth = 36.0;

  /// How many view widths the day spans, and how far it's panned.
  double _zoom = 1;
  double _shift = 0;
  double _lastScale = 1;
  HealthSample? _picked;

  /// Zooms to [to], keeping the point at [focus] (in the view) still.
  void _zoomAround(double to, double focus, double view) {
    final next = to.clamp(1.0, _maxZoom);
    final shift = (_shift + focus) * next / _zoom - focus;
    setState(() {
      _zoom = next;
      _shift = shift.clamp(0, view * next - view);
    });
  }

  void _pan(double dx, double view) =>
      setState(() => _shift = (_shift - dx).clamp(0, view * _zoom - view));

  /// The reading nearest [dx] across a chart [width] wide.
  void _pick(double dx, double width) {
    final span = widget.to.difference(widget.from).inSeconds;
    final at = widget.from.add(Duration(seconds: (dx / width * span).round()));
    HealthSample? best;
    for (final r in widget.day.readings) {
      if (best == null ||
          r.start.difference(at).abs() < best.start.difference(at).abs()) {
        best = r;
      }
    }
    HapticFeedback.selectionClick();
    setState(() => _picked = best);
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final all = day.all!;
    final p = _picked;
    final m = p == null
        ? null
        : day.moments.where((m) => m.contains(p.start)).firstOrNull;
    final labelStyle = context.caption2.copyWith(color: context.secondaryLabel);
    return CupertinoPageScaffold(
      backgroundColor: context.groupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Every Reading'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.margin, 12, 8, 16),
          child: LayoutBuilder(
            builder: (context, box) {
              final view = box.maxWidth - _scaleWidth;
              final width = view * _zoom;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: p == null
                              ? Text(
                                  'Tap the chart to read a value. Pinch to '
                                  'zoom in and see each minute.',
                                  style: context.subheadline.copyWith(
                                    color: context.secondaryLabel,
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${p.value.round()} bpm',
                                      style: context.title2.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      m == null
                                          ? formatTime(p.start)
                                          : '${formatTime(p.start)} · '
                                                '${m.label}',
                                      style: context.subheadline.copyWith(
                                        color: context.secondaryLabel,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size.square(AppTheme.minTapTarget),
                        onPressed: _zoom <= 1
                            ? null
                            : () => _zoomAround(_zoom / 2, view / 2, view),
                        child: Icon(
                          Icons.zoom_out_rounded,
                          semanticLabel: tr('Zoom Out'),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size.square(AppTheme.minTapTarget),
                        onPressed: _zoom >= _maxZoom
                            ? null
                            : () => _zoomAround(_zoom * 2, view / 2, view),
                        child: Icon(
                          Icons.zoom_in_rounded,
                          semanticLabel: tr('Zoom In'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Semantics(
                      label:
                          '${tr('Heart rate through the day')}, '
                          '${all.lowest.value.round()}–'
                          '${all.highest.value.round()} bpm',
                      child: Row(
                        children: [
                          Expanded(
                            // One scale gesture: pinch zooms around the
                            // fingers, one finger pans, a tap reads a value.
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (d) =>
                                  _pick(d.localPosition.dx + _shift, width),
                              onScaleStart: (_) => _lastScale = 1,
                              onScaleUpdate: (d) {
                                if (d.pointerCount > 1) {
                                  _zoomAround(
                                    _zoom * d.horizontalScale / _lastScale,
                                    d.localFocalPoint.dx,
                                    view,
                                  );
                                  _lastScale = d.horizontalScale;
                                }
                                _pan(d.focalPointDelta.dx, view);
                              },
                              child: ClipRect(
                                child: OverflowBox(
                                  alignment: Alignment.centerLeft,
                                  minWidth: width,
                                  maxWidth: width,
                                  child: Transform.translate(
                                    offset: Offset(-_shift, 0),
                                    child: CustomPaint(
                                      size: Size(width, box.maxHeight),
                                      painter: _DayPainter(
                                        day: day,
                                        from: widget.from,
                                        to: widget.to,
                                        line: context.resolve(
                                          MetricType.heartRate.color,
                                        ),
                                        workout: context.resolve(
                                          HeartDayPanel.workoutColor,
                                        ),
                                        sleep: context.resolve(
                                          HeartDayPanel.sleepColor,
                                        ),
                                        grid: context.separatorColor,
                                        label: labelStyle,
                                        dots:
                                            context.select<
                                              HealthStore,
                                              ChartStyle
                                            >(
                                              (s) =>
                                                  s.personalization.chartStyle,
                                            ) ==
                                            ChartStyle.dots,
                                        scale: false,
                                        picked: p,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: _scaleWidth,
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: _ScalePainter(
                                range: _dayRange(all),
                                label: labelStyle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The bpm labels beside a scrolling day chart, so they stay in view.
class _ScalePainter extends CustomPainter {
  _ScalePainter({required this.range, required this.label});

  final (double, double) range;
  final TextStyle label;

  @override
  void paint(Canvas canvas, Size size) {
    final (lo, hi) = range;
    final h = size.height - _DayPainter._axis;
    for (final v in _ticks(lo, hi)) {
      final tp = _labelPainter('$v', label);
      final dy = h - (v - lo) / (hi - lo) * h;
      tp.paint(canvas, Offset(size.width - tp.width, dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_ScalePainter old) =>
      old.range != range || old.label != label;
}

/// Each hour's lowest to highest reading, with its average marked.
class _HourCard extends StatelessWidget {
  const _HourCard({required this.hours});

  final List<HeartStats?> hours;

  @override
  Widget build(BuildContext context) {
    final shown = hours.nonNulls.toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return IosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hour by Hour', style: context.headline),
          Text(
            'Lowest to highest each hour, average marked',
            style: context.footnote.copyWith(color: context.secondaryLabel),
          ),
          const SizedBox(height: 12),
          Semantics(
            label:
                'Heart rate by hour, ${shown.length} hours with readings, '
                'from ${shown.map((h) => h.lowest.value).reduce(min).round()} '
                'to ${shown.map((h) => h.highest.value).reduce(max).round()} '
                'bpm',
            excludeSemantics: true,
            child: SizedBox(
              height: 140,
              child: CustomPaint(
                size: Size.infinite,
                painter: _HourPainter(
                  hours: hours,
                  color: context.resolve(MetricType.heartRate.color),
                  grid: context.separatorColor,
                  label: context.caption2.copyWith(
                    color: context.secondaryLabel,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HourPainter extends CustomPainter {
  _HourPainter({
    required this.hours,
    required this.color,
    required this.grid,
    required this.label,
  });

  final List<HeartStats?> hours;
  final Color color;
  final Color grid;
  final TextStyle label;

  static const _axis = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height - _axis;
    final shown = hours.nonNulls;
    final lo = shown.map((s) => s.lowest.value).reduce(min) - 5;
    final hi = shown.map((s) => s.highest.value).reduce(max) + 5;
    double y(double v) => h - (v - lo) / (hi - lo) * h;
    final w =
        size.width - _bpmScale(canvas, size.width, lo, hi, y, grid, label);
    final slot = w / hours.length;
    final width = (slot * 0.5).clamp(2.0, 10.0);

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 0.5;
    canvas.drawLine(Offset(0, h), Offset(w, h), gridPaint);
    for (var hour = 0; hour < 24; hour += 6) {
      final tp = TextPainter(
        text: TextSpan(
          text: DateFormat.j().format(DateTime(2000, 1, 1, hour)),
          style: label,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(slot * hour, h + 2));
    }

    final range = Paint()..color = color.withValues(alpha: 0.35);
    final mark = Paint()..color = color;
    for (final (i, s) in hours.indexed) {
      if (s == null) continue;
      final cx = slot * i + slot / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            cx - width / 2,
            y(s.highest.value) - width / 2,
            cx + width / 2,
            y(s.lowest.value) + width / 2,
          ),
          Radius.circular(width / 2),
        ),
        range,
      );
      canvas.drawCircle(Offset(cx, y(s.average)), width / 2 + 1, mark);
    }
  }

  @override
  bool shouldRepaint(_HourPainter old) =>
      old.hours != hours || old.color != color || old.grid != grid;
}

class _Key extends StatelessWidget {
  const _Key(this.color, this.text);

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: context.resolve(color).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(text, style: context.footnote),
    ],
  );
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: context.subheadline.copyWith(color: context.secondaryLabel),
    ),
  );
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: const Size.square(AppTheme.minTapTarget),
    onPressed: onTap,
    child: Icon(
      icon,
      semanticLabel: label,
      color: onTap == null ? context.tertiaryLabel : context.labelColor,
    ),
  );
}
