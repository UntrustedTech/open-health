import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/screens/add_entry_sheet.dart';
import 'package:health_app/screens/metric_detail_screen.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/widgets/bar_chart.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';

/// Apple Health-style summary tile: the metric's latest daily value and a
/// 7-day trend.
class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.type});

  final MetricType type;

  @override
  Widget build(BuildContext context) {
    // Only this metric's data (or the day) changing redraws it, not every
    // change to the store.
    context.select<HealthStore, Object?>(
      (s) => (s.revision, s.liveReading(type), s.today, Units.system),
    );
    final store = context.read<HealthStore>();
    final reading = store.latestReading(type);
    final trend = store.dailySeries(type, end: store.today, days: 7);

    final card = IosCard(
      onTap: () => MetricDetailScreen.open(context, type),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(type.icon, color: context.resolve(type.color), size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  type.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.subheadline.copyWith(
                    color: context.labelColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (reading != null)
                Text(
                  formatDay(reading.day, store.today),
                  style: context.footnote.copyWith(
                    color: context.secondaryLabel,
                  ),
                ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 14,
                color: context.tertiaryLabel,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: reading == null
                    ? Text(
                        'No Data',
                        style: context.title3.copyWith(
                          color: context.secondaryLabel,
                        ),
                      )
                    : ValueText(type: type, value: reading.value),
              ),
              SizedBox(
                width: 84,
                height: 34,
                child: Sparkline(values: trend, color: type.color),
              ),
            ],
          ),
        ],
      ),
    );
    // Long-press for quick actions, as on iOS.
    return CupertinoContextMenu(
      enableHapticFeedback: true,
      actions: [
        _action(context, 'Show Details', Icons.bar_chart_rounded, () {
          MetricDetailScreen.open(context, type);
        }),
        _action(context, 'Add Data', Icons.add_rounded, () {
          AddEntrySheet.show(context, type);
        }),
      ],
      // Fixed to the width it has in the list, so the menu preview
      // keeps the same layout.
      child: LayoutBuilder(
        builder: (context, c) => SizedBox(width: c.maxWidth, child: card),
      ),
    );
  }

  static Widget _action(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback run,
  ) => CupertinoContextMenuAction(
    trailingIcon: icon,
    onPressed: () {
      Navigator.of(context, rootNavigator: true).pop();
      run();
    },
    child: Text(label),
  );
}

/// Large value followed by a smaller unit, e.g. "8,421 steps".
class ValueText extends StatelessWidget {
  const ValueText({
    super.key,
    required this.type,
    required this.value,
    this.large = false,
  });

  final MetricType type;
  final double value;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final valueStyle = (large ? context.largeTitle : context.title1).copyWith(
      fontWeight: FontWeight.w700,
    );
    final unit = unitLabel(type);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: Motion.reduced(context) ? Duration.zero : Motion.slow,
      curve: Motion.curve,
      builder: (context, v, _) => _text(context, v, valueStyle, unit),
    );
  }

  Widget _text(
    BuildContext context,
    double v,
    TextStyle valueStyle,
    String unit,
  ) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: formatValue(type, v), style: valueStyle),
          if (unit.isNotEmpty)
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
      overflow: TextOverflow.ellipsis,
    );
  }
}
