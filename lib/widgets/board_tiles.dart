import 'dart:math' as math;

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/health_widget.dart';
import 'package:health_app/models/personalization.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/bar_chart.dart' show BarChart;
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/widgets/progress_ring.dart';
import 'package:health_app/widgets/sparkline.dart';
import 'package:health_app/widgets/widget_board.dart';

/// A labelled number about a widget ("Average 7,812"), shown beside a
/// medium widget's value and under a large one's.
typedef StatFact = ({String label, String value});

/// The shared shape of a board widget, so every one feels part of the same
/// family, in three purpose-built layouts:
///
/// * **Small**: half a row. The icon chip and name, then the value, a
///   caption, and a small visual along the bottom.
/// * **Medium**: the same, a whole row wide, with the first few [facts]
///   beside the value.
/// * **Large**: a whole row: the value on the left and a richer visual on
///   the right, then up to two rows of [facts], and the last 30 days of
///   [history] along the bottom.
///
/// Small and medium are the same height, so rows line up.
class StatWidget extends StatelessWidget {
  const StatWidget({
    super.key,
    required this.size,
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.semanticLabel,
    this.caption,
    this.smallVisual,
    this.wideVisual,
    this.facts = const [],
    this.history,
    this.leading,
    this.onTap,
  });

  /// The height each row of facts adds to a large widget.
  static const factsHeight = 64.0;

  /// The height the last 30 days add to a large widget.
  static const historyHeight = 64.0;

  /// Facts in each of a large widget's rows, and the rows it has at most.
  static const factsPerRow = 3;
  static const maxFactRows = 2;

  /// The facts a medium widget shows beside its value.
  static const mediumFacts = 3;

  final WidgetSize size;
  final IconData icon;
  final Color color;
  final String title;

  /// The headline: usually [StatValue].
  final Widget value;
  final String? caption;

  /// Along the bottom of the small and medium layouts (about 30 pt tall).
  final Widget? smallVisual;

  /// On the right of the large layout; the small visual is used if absent.
  final Widget? wideVisual;

  /// More about it, such as the week's average: the first few beside a
  /// medium widget's value, and up to six under a large one.
  final List<StatFact> facts;

  /// Daily values for the last 30 days, oldest first, drawn along the
  /// bottom of a large widget.
  final List<double?>? history;

  /// Replaces the icon chip (e.g. one that flies to a detail screen).
  final Widget? leading;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.resolve(color);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 3.2);
    final header = _header(context, c);
    final details = _details(context);
    final small = smallVisual;
    final rows = [
      for (var i = 0; i < facts.length; i += factsPerRow)
        facts.skip(i).take(factsPerRow).toList(),
    ].take(maxFactRows).toList();
    final history = this.history;
    final showHistory =
        history != null && history.whereType<double>().length >= 2;
    final body = switch (size) {
      WidgetSize.large => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(child: _besideVisual(details)),
          for (final row in rows) _Facts(facts: row),
          if (showHistory) _History(values: history, color: c),
        ],
      ),
      WidgetSize.medium when facts.isNotEmpty => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: details),
                const SizedBox(width: 14),
                Expanded(
                  child: _FactList(facts: facts.take(mediumFacts).toList()),
                ),
              ],
            ),
          ),
          if (small != null) ...[
            const SizedBox(height: 8),
            SizedBox(height: 30, child: small),
          ],
        ],
      ),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(child: details),
          if (small != null) ...[
            const SizedBox(height: 8),
            SizedBox(height: 30, child: small),
          ],
        ],
      ),
    };
    final height = size == WidgetSize.large
        ? WidgetBoard.smallHeight +
              rows.length * factsHeight +
              (showHistory ? historyHeight : 0)
        : WidgetBoard.smallHeight;
    return Pressable(
      semanticLabel: semanticLabel,
      onTap: onTap,
      scale: 0.96,
      child: Container(
        height: height * scale,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: cardSurface(context, tint: color),
        child: body,
      ),
    );
  }

  /// The icon chip and name, with an arrow on a full-row widget.
  Widget _header(BuildContext context, Color c) => Row(
    children: [
      leading ??
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.pastel(c),
            ),
            child: Icon(icon, color: c, size: 15),
          ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.footnote.copyWith(
            color: c,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      if (size.fullWidth && onTap != null)
        Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: context.tertiaryLabel,
        ),
    ],
  );

  /// The value and caption, at the bottom of the space they're given.
  Widget _details(BuildContext context) {
    final caption = this.caption;
    final details = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        value,
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.caption1.copyWith(
                color: context.secondaryLabel,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
    // The value sits at the bottom, and shrinks rather than spilling over
    // when a long prompt and a visual share a small widget.
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: LayoutBuilder(
        builder: (context, box) => Align(
          alignment: Alignment.bottomLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomLeft,
            child: SizedBox(width: box.maxWidth, child: details),
          ),
        ),
      ),
    );
  }

  /// [details] on the left and the richer visual on the right.
  Widget _besideVisual(Widget details) {
    final visual = wideVisual ?? smallVisual;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 5, child: details),
        if (visual != null) ...[
          const SizedBox(width: 14),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: visual,
            ),
          ),
        ],
      ],
    );
  }
}

/// A large widget's row of facts: each value over its label, split by
/// hairlines, under a hairline.
class _Facts extends StatelessWidget {
  const _Facts({required this.facts});

  final List<StatFact> facts;

  @override
  Widget build(BuildContext context) {
    final line = Container(width: 0.5, color: context.separatorColor);
    return SizedBox(
      height:
          StatWidget.factsHeight *
          MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 3.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Container(height: 0.5, color: context.separatorColor),
          Expanded(
            child: Row(
              children: [
                for (final (i, f) in facts.indexed) ...[
                  if (i > 0) ...[line, const SizedBox(width: 12)],
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(f.value, maxLines: 1, style: context.number(17)),
                          Text(
                            f.label,
                            maxLines: 1,
                            style: context.caption2.copyWith(
                              color: context.secondaryLabel,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A medium widget's facts: each label and value on a line, at the bottom
/// of the space beside the value.
class _FactList extends StatelessWidget {
  const _FactList({required this.facts});

  final List<StatFact> facts;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Align(
      alignment: Alignment.bottomRight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomRight,
        child: SizedBox(
          width: box.maxWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, f) in facts.indexed) ...[
                if (i > 0) const SizedBox(height: 5),
                Row(
                  children: [
                    // The label takes what's left after the value, which
                    // shrinks rather than taking more than 60%.
                    Expanded(
                      child: Text(
                        f.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.caption1.copyWith(
                          color: context.secondaryLabel,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: box.maxWidth * 0.6),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          f.value,
                          maxLines: 1,
                          style: context.footnote.copyWith(
                            color: context.labelColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// A large widget's last 30 days as a line, under a hairline.
class _History extends StatelessWidget {
  const _History({required this.values, required this.color});

  final List<double?> values;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height:
        StatWidget.historyHeight *
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 3.2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Container(height: 0.5, color: context.separatorColor),
        const SizedBox(height: 8),
        Text(
          'Last 30 Days',
          style: context.caption2.copyWith(
            color: context.secondaryLabel,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ExcludeSemantics(
            child: LayoutBuilder(
              builder: (context, box) => Sparkline(
                values: values,
                color: color,
                width: box.maxWidth,
                height: box.maxHeight,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// A value with a smaller unit after it, shrinking to fit its width.
class StatValue extends StatelessWidget {
  const StatValue(
    this.text, {
    super.key,
    this.unit,
    required this.size,
    this.placeholder = false,
  });

  final String text;
  final String? unit;
  final WidgetSize size;

  /// Shows [text] quietly, as a prompt rather than a number.
  final bool placeholder;

  /// How big a widget's headline number is at [size].
  static double fontSize(WidgetSize size) => switch (size) {
    WidgetSize.small => 26,
    WidgetSize.medium => 28,
    WidgetSize.large => 30,
  };

  @override
  Widget build(BuildContext context) {
    final unit = this.unit;
    final big = StatValue.fontSize(size);
    if (placeholder) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.headline.copyWith(color: context.labelColor),
      );
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: text, style: context.number(big)),
            if (unit != null && unit.isNotEmpty)
              TextSpan(
                text: ' $unit',
                style: context.subheadline.copyWith(
                  color: context.secondaryLabel,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        maxLines: 1,
      ),
    );
  }
}

/// A week of values as rounded bars, today's in full colour; with day
/// letters underneath when [labels] is set.
class WeekBars extends StatelessWidget {
  const WeekBars({
    super.key,
    required this.values,
    required this.color,
    required this.today,
    this.labels = true,
  });

  final List<double?> values;
  final Color color;
  final DateTime today;
  final bool labels;

  String _letter(int i) => DateFormat.E()
      .format(
        DateTime(today.year, today.month, today.day - (values.length - 1 - i)),
      )
      .characters
      .first;

  @override
  Widget build(BuildContext context) {
    final style = context.select<HealthStore, ChartStyle>(
      (s) => s.personalization.chartStyle,
    );
    // Other styles draw as on the metric pages, today's value picked out.
    if (style != ChartStyle.bars && style != ChartStyle.pills) {
      return ExcludeSemantics(
        child: IgnorePointer(
          child: LayoutBuilder(
            builder: (context, box) => BarChart(
              values: values,
              color: color,
              labels: labels
                  ? [for (var i = 0; i < values.length; i++) _letter(i)]
                  : const [],
              selected: values.length - 1,
              height: box.maxHeight.isFinite ? box.maxHeight : 60,
              style: style,
            ),
          ),
        ),
      );
    }
    final c = context.resolve(color);
    final present = values.whereType<double>();
    final top = present.isEmpty ? 0.0 : present.reduce(math.max);
    return ExcludeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, v) in values.indexed)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          end: v == null || top <= 0
                              ? 0.08
                              : math.max(0.1, v / top),
                        ),
                        duration: Motion.reduced(context)
                            ? Duration.zero
                            : Motion.slow + Motion.stagger * i,
                        curve: Curves.easeOutQuart,
                        builder: (context, f, _) => FractionallySizedBox(
                          heightFactor: f,
                          child: Container(
                            width: labels ? 10 : 7,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: i == values.length - 1
                                  ? c
                                  : c.withValues(alpha: 0.28),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (labels) ...[
                    const SizedBox(height: 4),
                    Text(
                      _letter(i),
                      style: context.caption2.copyWith(
                        color: i == values.length - 1
                            ? c
                            : context.tertiaryLabel,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The latest of [week] against the average of the days before it, as a
/// short line ("▲ 12% vs your week"), or null without enough data.
String? weekChange(List<double?> week) {
  final last = week.lastOrNull;
  final before = week.take(week.length - 1).whereType<double>().toList();
  if (last == null || before.isEmpty) return null;
  final avg = before.reduce((a, b) => a + b) / before.length;
  if (avg == 0) return null;
  final pct = ((last - avg) / avg * 100).round();
  if (pct == 0) return 'Level with your week';
  return '${pct > 0 ? '▲' : '▼'} ${pct.abs()}% vs your week';
}

/// A rounded bar filling to [progress], with an optional label above it.
class BarVisual extends StatelessWidget {
  const BarVisual({
    super.key,
    required this.progress,
    required this.color,
    this.label,
  });

  final double progress;
  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.caption2.copyWith(color: context.secondaryLabel),
            ),
          ),
        CapsuleProgress(value: progress, color: context.resolve(color)),
      ],
    );
  }
}

/// A big progress ring with [child] inside, for the right of a wide
/// widget.
class RingVisual extends StatelessWidget {
  const RingVisual({
    super.key,
    required this.progress,
    required this.color,
    this.child,
  });

  final double progress;
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Align(
      alignment: Alignment.center,
      child: ProgressRing(
        progress: progress,
        color: context.resolve(color),
        size: math.min(c.maxHeight, c.maxWidth).clamp(40, 96),
        stroke: 9,
        child: child,
      ),
    ),
  );
}

/// A large pastel disc with an icon, for wide widgets without a chart.
class IconDisc extends StatelessWidget {
  const IconDisc({super.key, required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.resolve(color);
    return LayoutBuilder(
      builder: (context, box) {
        final d = math.min(box.maxHeight, box.maxWidth).clamp(40.0, 88.0);
        return Center(
          child: Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.pastel(c),
            ),
            child: Icon(icon, color: c, size: d * 0.46),
          ),
        );
      },
    );
  }
}
