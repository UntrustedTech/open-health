import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/screens/metric_detail_screen.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/metric_chip.dart';
import 'package:health_app/widgets/motion.dart';

/// Every metric the app tracks, grouped by category, with a search field.
class AllHealthDataScreen extends StatefulWidget {
  const AllHealthDataScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(
      title: 'All Health Data',
      builder: (_) => const AllHealthDataScreen(),
    ),
  );

  @override
  State<AllHealthDataScreen> createState() => _AllHealthDataScreenState();
}

class _AllHealthDataScreenState extends State<AllHealthDataScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: context.groupedBackground,
    navigationBar: CupertinoNavigationBar(
      middle: Text('All Health Data'),
      previousPageTitle: tr('Health'),
    ),
    child: PageList(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.margin,
        12,
        AppTheme.margin,
        40,
      ),
      children: [
        CupertinoSearchTextField(
          placeholder: tr('Search'),
          onChanged: (v) => setState(() => _query = v),
        ),
        // No flying chips here: the Health tab's widgets share them.
        ...MetricGroups.of(context, _query, hero: false),
      ],
    ),
  );
}

/// Metrics grouped under their category, each group a card of rows. Used
/// by All Health Data and by the Health tab's search.
abstract final class MetricGroups {
  /// [hero] lets each row's chip fly into its detail screen.
  static List<Widget> of(
    BuildContext context,
    String query, {
    bool hero = true,
    bool showEmpty = true,
  }) {
    final q = query.trim().toLowerCase();
    // In English and in the app's language, as the names are shown.
    bool has(String name) =>
        name.toLowerCase().contains(q) || tr(name).toLowerCase().contains(q);
    bool matches(MetricType t) =>
        q.isEmpty || has(t.label) || has(t.category.label);
    final groups = [
      for (final c in HealthCategory.values)
        (c, MetricType.values.where((t) => t.category == c && matches(t))),
    ].where((g) => g.$2.isNotEmpty).toList();
    if (groups.isEmpty) {
      if (!showEmpty) return const [];
      return [
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Text(
            'No Results for "$query"',
            textAlign: TextAlign.center,
            style: context.headline.copyWith(color: context.secondaryLabel),
          ),
        ),
      ];
    }
    return [
      for (final (i, (category, metrics)) in groups.indexed) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
          child: Row(
            children: [
              IconTile(icon: category.icon, color: category.color, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(category.label, style: context.headline),
                ),
              ),
            ],
          ),
        ),
        Appear(
          index: i,
          child: Container(
            decoration: cardSurface(context, radius: AppTheme.listRadius),
            child: Column(
              children: [
                for (final (j, t) in metrics.indexed) ...[
                  if (j > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 58),
                      child: Container(
                        height: 0.5,
                        color: context.separatorColor,
                      ),
                    ),
                  MetricRow(type: t, hero: hero),
                ],
              ],
            ),
          ),
        ),
      ],
    ];
  }
}

/// A metric's chip, name and when it was last recorded, with its latest
/// value on the right. Opens the metric's detail.
class MetricRow extends StatelessWidget {
  const MetricRow({super.key, required this.type, this.hero = true});

  final MetricType type;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final reading = store.latestReading(type);
    final value = reading == null
        ? null
        : '${formatValue(type, reading.value)} ${unitLabel(type)}'.trim();
    return Pressable(
      semanticLabel: value == null
          ? '${type.label}, no data'
          : '${type.label}, $value',
      onTap: () => MetricDetailScreen.open(context, type),
      scale: 0.98,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            MetricChip(type: type, size: 32, hero: hero),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type.label, style: context.body),
                  Text(
                    reading == null
                        ? 'No data yet'
                        : formatDay(reading.day, store.today),
                    style: context.footnote.copyWith(
                      color: context.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
            if (value != null)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.38,
                ),
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.headline,
                ),
              ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: context.tertiaryLabel,
            ),
          ],
        ),
      ),
    );
  }
}
