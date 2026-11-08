import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/widgets/app_chip.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/screens/workouts/workout_edit_screen.dart';
import 'package:health_app/screens/workouts/workouts_screen.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/bar_chart.dart';
import 'package:health_app/workout/workout_stats.dart';

/// Every workout, grouped by month, filterable by type.
class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(
      title: 'History',
      builder: (_) => const WorkoutHistoryScreen(),
    ),
  );

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  WorkoutType? _filter;

  @override
  Widget build(BuildContext context) {
    final all = context.watch<WorkoutStore>().all;
    final types = {for (final w in all) w.type}.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final list = all.where((w) => _filter == null || w.type == _filter);
    final byMonth = <DateTime, List<WorkoutSession>>{};
    for (final w in list) {
      byMonth
          .putIfAbsent(DateTime(w.start.year, w.start.month), () => [])
          .add(w);
    }
    return LargeTitlePage(
      title: 'History',
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => WorkoutEditScreen.open(context),
        child: Icon(Icons.add_rounded, semanticLabel: tr('Log a past workout')),
      ),
      children: [
        if (types.length > 1)
          ChipRow(
            children: [
              AppChip(
                label: 'All',
                selected: _filter == null,
                onTap: () => setState(() => _filter = null),
              ),
              for (final t in types)
                AppChip(
                  label: t.label,
                  color: t.color,
                  selected: _filter == t,
                  onTap: () => setState(() => _filter = t),
                ),
            ],
          ),
        if (list.isNotEmpty) ...[
          const SizedBox(height: 12),
          _HistorySummary(
            workouts: list.toList(),
            today: context.read<WorkoutStore>().today,
            color: _filter?.color ?? context.tint,
          ),
        ],
        for (final MapEntry(key: month, value: items) in byMonth.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat.yMMMM().format(month), style: context.title3),
                Text(
                  _monthLine(items),
                  style: context.footnote.copyWith(
                    color: context.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          for (final w in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: WorkoutTile(session: w),
            ),
        ],
        if (byMonth.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Text(
              'No workouts yet',
              textAlign: TextAlign.center,
              style: context.title3.copyWith(color: context.secondaryLabel),
            ),
          ),
      ],
    );
  }
}

/// "6 workouts · 4 hr 10 min · 18.4 km" for a month.
String _monthLine(List<WorkoutSession> items) {
  final seconds = items.fold(0, (s, w) => s + w.activeSeconds);
  final meters = items.fold<double>(0, (s, w) => s + w.distanceMeters);
  return [
    '${items.length} ${items.length == 1 ? 'workout' : 'workouts'}',
    formatMinutes(Duration(seconds: seconds)),
    if (meters >= 100) formatDistance(meters),
  ].join(' · ');
}

/// Totals and the last 12 weeks of training time.
class _HistorySummary extends StatelessWidget {
  const _HistorySummary({
    required this.workouts,
    required this.today,
    required this.color,
  });

  final List<WorkoutSession> workouts;
  final DateTime today;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const weeks = 12;
    final firstDay = context.select<WorkoutStore, int>((s) => s.plan.weekStart);
    final current = weekStart(today, firstDay: firstDay);
    final minutes = List<double>.filled(weeks, 0);
    for (final w in workouts) {
      final i =
          weeks -
          1 -
          (current.difference(weekStart(w.start, firstDay: firstDay)).inDays /
                  7)
              .round();
      if (i >= 0 && i < weeks) minutes[i] += w.activeSeconds / 60;
    }
    final seconds = workouts.fold(0, (s, w) => s + w.activeSeconds);
    final meters = workouts.fold<double>(0, (s, w) => s + w.distanceMeters);
    final volume = workouts.fold<double>(0, (s, w) => s + w.volumeKg);
    final facts = [
      ('Workouts', '${workouts.length}'),
      (
        'Time',
        // Long totals in whole hours, so the numbers fit side by side.
        seconds >= 10 * 3600
            ? '${(seconds / 3600).round()} hr'
            : formatMinutes(Duration(seconds: seconds)),
      ),
      if (meters >= 100) ('Distance', formatDistance(meters)),
      if (volume > 0) ('Lifted', Units.weight(volume, decimals: 0)),
    ];
    return IosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final (label, value) in facts.take(3))
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            value,
                            style: context.number(22, weight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          label,
                          style: context.caption1.copyWith(
                            color: context.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'MINUTES PER WEEK',
            style: context.caption2.copyWith(
              color: context.secondaryLabel,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          BarChart(
            values: minutes,
            labels: [
              for (var i = 0; i < weeks; i++)
                i % 4 == 0
                    ? DateFormat.MMMd().format(
                        DateTime(
                          current.year,
                          current.month,
                          current.day - 7 * (weeks - 1 - i),
                        ),
                      )
                    : '',
            ],
            color: color,
            height: 120,
            axisLabel: (v) => '${v.round()}',
          ),
        ],
      ),
    );
  }
}
