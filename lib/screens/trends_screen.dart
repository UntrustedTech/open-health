import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/insights/trends.dart';
import 'package:health_app/screens/metric_detail_screen.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/bar_chart.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';

/// Long-term changes in your data: the last 90 days against the months
/// before.
class TrendsScreen extends StatelessWidget {
  const TrendsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(AppRoute<void>(title: 'Trends', builder: (_) => const TrendsScreen()));

  static ({
    HealthStore store,
    int revision,
    DateTime today,
    List<LongTrend> list,
  })?
  _cache;

  /// Trends only change with the data or the day, not on every rebuild.
  static List<LongTrend> trendsFor(HealthStore store) {
    final c = _cache;
    if (c != null &&
        identical(c.store, store) &&
        c.revision == store.revision &&
        c.today == store.today) {
      return c.list;
    }
    final list = buildTrends(dailyValue: store.dailyValue, today: store.today);
    _cache = (
      store: store,
      revision: store.revision,
      today: store.today,
      list: list,
    );
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final trends = trendsFor(store);
    final moving = trends.where((t) => t.trend != Trend.steady).toList();
    final steady = trends.where((t) => t.trend == Trend.steady).toList();
    return LargeTitlePage(
      title: 'Trends',
      children: [
        Text(
          'Your last 90 days compared with the months before.',
          style: context.subheadline.copyWith(color: context.secondaryLabel),
        ),
        if (trends.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Column(
              children: [
                Icon(Icons.insights_rounded, size: 44, color: context.tint),
                const SizedBox(height: 12),
                Text(
                  'Trends appear after a few months of data.',
                  textAlign: TextAlign.center,
                  style: context.headline,
                ),
              ],
            ),
          ),
        if (moving.isNotEmpty) const SectionTitle('Changing'),
        for (final (i, t) in moving.indexed) ...[
          Appear(
            index: i,
            child: TrendCard(trend: t),
          ),
          const SizedBox(height: 12),
        ],
        if (steady.isNotEmpty) const SectionTitle('Holding Steady'),
        for (final (i, t) in steady.indexed) ...[
          Appear(
            index: moving.length + i,
            child: TrendCard(trend: t),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class TrendCard extends StatelessWidget {
  const TrendCard({super.key, required this.trend});

  final LongTrend trend;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final t = trend;
    final type = t.type;
    String value(double v) =>
        '${formatValue(type, v)} ${unitLabel(type)}'.trim();
    final good = t.isGood;
    final arrowColor = context.resolve(switch (good) {
      true => Palette.green,
      false => Palette.orange,
      null => Palette.grey,
    });
    final verb = switch (t.trend) {
      Trend.up => 'up from',
      Trend.down => 'down from',
      Trend.steady => 'about the same as',
    };
    final pct = (t.change.abs() * 100).round();
    return IosCard(
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
                  style: context.subheadline.copyWith(
                    color: context.labelColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                switch (t.trend) {
                  Trend.up => Icons.north_east_rounded,
                  Trend.down => Icons.south_east_rounded,
                  Trend.steady => Icons.arrow_forward_rounded,
                },
                size: 16,
                color: arrowColor,
              ),
              if (t.trend != Trend.steady) ...[
                const SizedBox(width: 2),
                Text(
                  '$pct%',
                  style: context.footnote.copyWith(
                    color: arrowColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${value(t.recent)} a day on average, $verb ${value(t.baseline)}.',
            style: context.headline,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: Sparkline(
              values: store.monthlySeries(type, end: store.today, months: 12),
              color: type.color,
            ),
          ),
        ],
      ),
    );
  }
}
