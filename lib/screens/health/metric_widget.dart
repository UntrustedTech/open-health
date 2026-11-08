import 'dart:math' as math;

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/board_catalog.dart';
import 'package:health_app/models/health_widget.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/screens/metric_detail_screen.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/widgets/board_tiles.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/metric_chip.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/widgets/sparkline.dart';
import 'package:health_app/widgets/widget_board.dart';

/// Board entries for metrics: one per metric in [categories] (every
/// metric when null), listed in the gallery under their category.
List<BoardEntry> metricEntries({Set<HealthCategory>? categories}) => [
  for (final t in MetricType.values)
    if (categories == null || categories.contains(t.category))
      BoardEntry(
        id: BoardIds.metric(t),
        label: t.label,
        icon: t.icon,
        color: t.color,
        group: '${t.category.label} Data',
        builder: (context, size) => MetricWidgetTile(type: t, size: size),
      ),
];

/// A metric as an iOS-style widget. Small: its latest value and a week's
/// trend line; medium adds the week's average, high and low beside it.
/// Large: the value and how today compares with the week next to a week
/// of bars, six facts about recent weeks, and the last 30 days. Opens the
/// metric.
class MetricWidgetTile extends StatelessWidget {
  const MetricWidgetTile({super.key, required this.type, required this.size});

  final MetricType type;
  final WidgetSize size;

  @override
  Widget build(BuildContext context) {
    // Only this metric's data (or the day) changing redraws it, not every
    // change to the store.
    context.select<HealthStore, Object?>(
      (s) => (s.revision, s.liveReading(type), s.today, Units.system),
    );
    final store = context.read<HealthStore>();
    final reading = store.latestReading(type);
    final week = store.dailySeries(type, end: store.today, days: 7);
    final value = reading == null
        ? null
        : '${formatValue(type, reading.value)} ${unitLabel(type)}'.trim();
    final when = reading == null ? null : formatDay(reading.day, store.today);
    final hasTrend = week.whereType<double>().length >= 2;
    return StatWidget(
      size: size,
      icon: type.icon,
      color: type.color,
      title: type.label,
      leading: MetricChip(type: type, hero: true),
      semanticLabel: value == null
          ? '${type.label}, no data yet'
          : '${type.label}, $value, $when',
      onTap: () => MetricDetailScreen.open(context, type),
      value: _Value(
        type: type,
        value: reading?.value,
        size: StatValue.fontSize(size),
      ),
      caption: reading == null
          ? 'Add data to see it here'
          : size.fullWidth
          ? weekChange(week) ?? when
          : when,
      smallVisual: hasTrend
          ? Sparkline(
              values: week,
              color: type.color,
              width: double.infinity,
              height: 30,
            )
          : null,
      wideVisual: WeekBars(values: week, color: type.color, today: store.today),
      facts: metricFacts(store, type),
      history: size == WidgetSize.large
          ? store.dailySeries(type, end: store.today, days: 30)
          : null,
    );
  }
}

/// What's known about [type] lately, for a widget: this week's average,
/// high and low; last week's and the last 30 days' averages; and how many
/// of the last 7 days have data.
List<StatFact> metricFacts(HealthStore store, MetricType type) {
  final month = store.dailySeries(type, end: store.today, days: 30);
  final week = month.sublist(month.length - 7);
  final lastWeek = month.sublist(month.length - 14, month.length - 7);
  String format(double v) =>
      '${formatValue(type, v)} ${unitLabel(type)}'.trim();
  String pick(List<double?> days, double Function(Iterable<double>) of) {
    final v = days.whereType<double>();
    return v.isEmpty ? '–' : format(of(v));
  }

  double average(Iterable<double> v) => v.reduce((a, b) => a + b) / v.length;
  return [
    (label: 'Average', value: pick(week, average)),
    (label: 'High', value: pick(week, (v) => v.reduce(math.max))),
    (label: 'Low', value: pick(week, (v) => v.reduce(math.min))),
    (label: 'Last Week', value: pick(lastWeek, average)),
    (label: '30-Day Average', value: pick(month, average)),
    (label: 'Days Logged', value: '${week.whereType<double>().length} of 7'),
  ];
}

/// The value with its unit, counting to new values.
class _Value extends StatelessWidget {
  const _Value({required this.type, required this.value, required this.size});

  final MetricType type;
  final double? value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null) {
      return Text(
        'No Data',
        style: context
            .number(size * 0.8)
            .copyWith(color: context.tertiaryLabel),
      );
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: AnimatedNumber(
        value: v,
        format: (x) => formatValue(type, x),
        style: context.number(size),
        suffix: unitLabel(type).isEmpty ? null : ' ${unitLabel(type)}',
        suffixStyle: context.subheadline.copyWith(
          color: context.secondaryLabel,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A link to every metric, by category.
class AllDataLink extends StatelessWidget {
  const AllDataLink({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IosCard(
    onTap: onTap,
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    child: Row(
      children: [
        IconTile(
          icon: Icons.format_list_bulleted_rounded,
          color: context.tint,
          size: 34,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('All Health Data', style: context.headline),
              Text(
                'Every metric, by category',
                style: context.footnote.copyWith(color: context.secondaryLabel),
              ),
            ],
          ),
        ),
        Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: context.tertiaryLabel,
        ),
      ],
    ),
  );
}
