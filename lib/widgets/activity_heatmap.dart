import 'package:flutter/cupertino.dart' hide Text;
import 'package:intl/intl.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/theme/app_theme.dart';

/// A year of training as a grid of rounded squares, one column per week,
/// brighter for more time trained. Fills the width with the latest weeks
/// and scrolls back through the year.
class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({
    super.key,
    required this.minutesByDay,
    required this.today,
    required this.color,
    this.weekStart = DateTime.monday,
    this.showLegend = true,
    this.weeks = 53,
  });

  final Map<DateTime, int> minutesByDay;
  final DateTime today;
  final Color color;
  final int weekStart;
  final bool showLegend;

  /// How many weeks back the grid goes.
  final int weeks;

  static const _gap = 4.0;
  static const _monthRow = 20.0;

  /// Squares aim for about this size; the count fits the width exactly.
  static const _targetCell = 16.0;

  /// Minutes needed for each brighter level.
  static const levels = [1, 30, 45, 60];

  static int levelOf(int minutes) =>
      levels.lastIndexWhere((m) => minutes >= m) + 1;

  @override
  Widget build(BuildContext context) {
    final t = DateTime(today.year, today.month, today.day);
    final offset = (t.weekday - weekStart + 7) % 7;
    final lastStart = DateTime(t.year, t.month, t.day - offset);
    final first = DateTime(
      lastStart.year,
      lastStart.month,
      lastStart.day - 7 * (weeks - 1),
    );
    final empty = context.fillColor;
    Color shade(int level) => level == 0
        ? empty
        : Color.lerp(
            color.withValues(alpha: 0.30),
            color,
            (level - 1) / (levels.length - 1),
          )!;
    final active = minutesByDay.entries
        .where((e) => e.value > 0 && !e.key.isBefore(first))
        .length;

    return Semantics(
      label: weeks >= 52
          ? 'Activity: $active training days in the past year'
          : 'Activity: $active training days in the last $weeks weeks',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, c) {
          final cols = ((c.maxWidth + _gap) / (_targetCell + _gap))
              .floor()
              .clamp(8, weeks);
          final cell = (c.maxWidth - _gap * (cols - 1)) / cols;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _monthRow + 7 * (cell + _gap),
                // Each column carries a gap on its right; letting the
                // newest one's gap hang off the edge keeps whole columns.
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  maxWidth: c.maxWidth + _gap,
                  minWidth: c.maxWidth + _gap,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: weeks,
                    itemExtent: cell + _gap,
                    itemBuilder: (context, i) {
                      final week = weeks - 1 - i;
                      final start = DateTime(
                        first.year,
                        first.month,
                        first.day + 7 * week,
                      );
                      return _WeekColumn(
                        start: start,
                        today: t,
                        cell: cell,
                        showMonth: start.day <= 7,
                        levelOf: (day) => levelOf(minutesByDay[day] ?? 0),
                        shade: shade,
                        todayRing: color,
                      );
                    },
                  ),
                ),
              ),
              if (showLegend) ...[
                const SizedBox(height: 4),
                _Legend(shade: shade),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _WeekColumn extends StatelessWidget {
  const _WeekColumn({
    required this.start,
    required this.today,
    required this.cell,
    required this.showMonth,
    required this.levelOf,
    required this.shade,
    required this.todayRing,
  });

  final DateTime start;
  final DateTime today;
  final double cell;
  final bool showMonth;
  final int Function(DateTime) levelOf;
  final Color Function(int) shade;
  final Color todayRing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: ActivityHeatmap._monthRow,
          child: showMonth
              ? OverflowBox(
                  alignment: Alignment.topLeft,
                  maxWidth: 60,
                  child: Text(
                    DateFormat.MMM().format(start),
                    style: context.caption1.copyWith(
                      color: context.secondaryLabel,
                    ),
                  ),
                )
              : null,
        ),
        for (var d = 0; d < 7; d++)
          () {
            final day = DateTime(start.year, start.month, start.day + d);
            final future = day.isAfter(today);
            final isToday = day == today;
            return Container(
              width: cell,
              height: cell,
              margin: const EdgeInsets.only(bottom: ActivityHeatmap._gap),
              decoration: ShapeDecoration(
                color: future
                    ? shade(0).withValues(alpha: 0.35)
                    : shade(levelOf(day)),
                shape: AppTheme.squircle(
                  cell * 0.28,
                  side: isToday
                      ? BorderSide(color: todayRing, width: 2)
                      : BorderSide.none,
                ),
              ),
            );
          }(),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.shade});

  final Color Function(int) shade;

  @override
  Widget build(BuildContext context) {
    final style = context.caption1.copyWith(color: context.secondaryLabel);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('Less time', style: style),
        const SizedBox(width: 6),
        for (var l = 0; l <= ActivityHeatmap.levels.length; l++)
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(right: 3),
            decoration: ShapeDecoration(
              color: shade(l),
              shape: AppTheme.squircle(3.5),
            ),
          ),
        const SizedBox(width: 3),
        Text('More time', style: style),
      ],
    );
  }
}
