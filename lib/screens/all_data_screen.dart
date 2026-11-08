import 'package:flutter/cupertino.dart' hide Text;
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/health_entry.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/sync/health_sync_service.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';

/// Every recorded value for one metric, newest first. Entries you added can
/// be swiped to delete; imported entries are managed in Health Connect.
class AllDataScreen extends StatelessWidget {
  const AllDataScreen({super.key, required this.type});

  final MetricType type;

  static const _pageSize = 200;

  static Future<void> open(BuildContext context, MetricType type) =>
      Navigator.of(context).push(
        AppRoute<void>(
          title: 'All Data',
          builder: (_) => AllDataScreen(type: type),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<HealthStore>().entriesFor(type);
    final shown = entries.take(_pageSize).toList();
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('All Recorded Data'),
      ),
      child: SafeArea(
        bottom: false,
        child: entries.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        type.icon,
                        size: 44,
                        color: context.resolve(type.color),
                      ),
                      const SizedBox(height: 12),
                      Text('No Data', style: context.title3),
                      const SizedBox(height: 6),
                      Text(
                        'Values you add or sync will appear here.',
                        textAlign: TextAlign.center,
                        style: context.subheadline.copyWith(
                          color: context.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : PageList(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.margin,
                  8,
                  AppTheme.margin,
                  40,
                ),
                children: [
                  GroupedSection(
                    hasLeading: false,
                    footer: entries.length > _pageSize
                        ? 'Showing the latest $_pageSize of '
                              '${entries.length} entries.'
                        : null,
                    children: [for (final e in shown) _EntryTile(entry: e)],
                  ),
                ],
              ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final HealthEntry entry;

  @override
  Widget build(BuildContext context) {
    final store = context.read<HealthStore>();
    final note = entry.note;
    final source = switch (entry.source) {
      EntrySource.healthConnect => context.read<HealthSyncService>().sourceName,
      EntrySource.sample => 'Sample Data',
      EntrySource.workout => 'Workout',
      EntrySource.food => 'Food Diary',
      EntrySource.plugin => 'Other',
      EntrySource.manual => null,
    };
    final when = entry.isImported
        ? formatDay(entry.date, store.today)
        : '${formatDay(entry.date, store.today)}, ${formatTime(entry.date)}';
    final tile = CupertinoListTile(
      title: Text(
        '${formatValue(entry.type, entry.value)} ${unitLabel(entry.type)}'
            .trim(),
      ),
      subtitle: Text([when, ?source, ?note].join(' · ')),
    );
    // Imported data is managed in Health Connect, workout data with the
    // workout itself.
    if (entry.isImported || entry.isFromWorkout || entry.isFromFood) {
      return tile;
    }
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: ColoredBox(
        color: context.destructive,
        child: const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: 20),
            child: Text(
              'Delete',
              style: TextStyle(
                color: CupertinoColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
      confirmDismiss: (_) => confirmDestructive(
        context,
        message: 'This data will be deleted from Health.',
        action: 'Delete',
      ),
      onDismissed: (_) => store.deleteEntry(entry.id),
      child: tile,
    );
  }
}
