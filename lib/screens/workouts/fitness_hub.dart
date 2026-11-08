import 'dart:math' as math;

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/insights/training_stats.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/screens/workouts/workout_launcher.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/workout_art.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/widgets/progress_ring.dart';
import 'package:health_app/workout/intervals.dart';
import 'package:health_app/workout/workout_stats.dart';

/// Fitness green, as on the Exercise ring. Adapts to light and dark mode.
const fitnessGreen = Palette.mint;

/// "Training Pulse": the week's minutes against the goal, a column for
/// each day, and the week's totals.
class TrainingPulseCard extends StatelessWidget {
  const TrainingPulseCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkoutStore>();
    final week = store.thisWeek;
    final goal = store.settings.weeklyGoalMinutes;
    final today = store.today;
    final from = weekStart(today, firstDay: store.plan.weekStart);
    final byDay = activityByDay(store.all, today: today);
    final days = [
      for (var i = 0; i < 7; i++) DateTime(from.year, from.month, from.day + i),
    ];
    final minutes = [for (final d in days) byDay[d] ?? 0];
    final tallest = math.max(30, minutes.reduce(math.max));
    final progress = goal > 0 ? week.minutes / goal : 0.0;
    final green = context.resolve(fitnessGreen);
    final streak = store.streak;
    return Semantics(
      container: true,
      label:
          'This week: ${week.minutes}${goal > 0 ? ' of $goal' : ''} minutes, '
          '${week.count} workouts',
      child: IosCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        tint: fitnessGreen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'THIS WEEK',
                        style: context.overline.copyWith(
                          color: context.secondaryLabel,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          AnimatedNumber(
                            value: week.minutes.toDouble(),
                            format: (v) => '${v.round()}',
                            style: context.number(40, weight: FontWeight.w800),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              goal > 0 ? 'of $goal min' : 'min',
                              style: context.subheadline.copyWith(
                                color: context.secondaryLabel,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        goal <= 0
                            ? 'No weekly goal set'
                            : progress >= 1
                            ? 'Weekly goal reached'
                            : '${goal - week.minutes} min to your weekly goal',
                        style: context.caption1.copyWith(
                          color: context.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
                if (goal > 0)
                  ProgressRing(
                    progress: progress,
                    color: green,
                    size: 64,
                    stroke: 7,
                    child: Text(
                      '${(progress * 100).clamp(0, 999).round()}%',
                      style: context.number(14, weight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
            if (streak > 0) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: ShapeDecoration(
                    color: context
                        .resolve(Palette.orange)
                        .withValues(alpha: 0.16),
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.whatshot_rounded,
                        size: 14,
                        color: context.resolve(Palette.orange),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        streak == 1 ? '1 day streak' : '$streak day streak',
                        style: context.caption1.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 72,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (i, d) in days.indexed)
                    Expanded(
                      child: _DayColumn(
                        day: d,
                        minutes: minutes[i],
                        share: minutes[i] / tallest,
                        isToday: d == today,
                        future: d.isAfter(today),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Stat(
                  icon: Icons.fitness_center_rounded,
                  color: Palette.mint,
                  value: '${week.count}',
                  label: week.count == 1 ? 'Workout' : 'Workouts',
                ),
                const SizedBox(width: 8),
                _Stat(
                  icon: Icons.route_rounded,
                  color: Palette.blue,
                  value: Units.distanceOut(week.kilometres).toStringAsFixed(1),
                  label: Units.distanceUnit,
                ),
                const SizedBox(width: 8),
                _Stat(
                  icon: Icons.local_fire_department_rounded,
                  color: Palette.red,
                  value: '${week.kcal.round()}',
                  label: 'Cal',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.minutes,
    required this.share,
    required this.isToday,
    required this.future,
  });

  final DateTime day;
  final int minutes;
  final double share;
  final bool isToday;
  final bool future;

  @override
  Widget build(BuildContext context) {
    final letter = DateFormat('EEEEE').format(day);
    final green = context.resolve(fitnessGreen);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: share.clamp(0.0, 1.0)),
              duration: Motion.reduced(context) ? Duration.zero : Motion.slow,
              curve: Motion.curve,
              builder: (context, v, _) => FractionallySizedBox(
                heightFactor: minutes == 0 ? 0.06 : math.max(0.12, v),
                child: Container(
                  width: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: minutes == 0 ? context.fillColor : null,
                    gradient: minutes == 0
                        ? null
                        : LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [green, green.withValues(alpha: 0.45)],
                          ),
                    boxShadow: isToday && minutes > 0
                        ? [
                            BoxShadow(
                              color: green.withValues(alpha: 0.45),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          letter,
          style: context.caption2.copyWith(
            color: isToday
                ? context.labelColor
                : future
                ? context.tertiaryLabel
                : context.secondaryLabel,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// A value and caption in a small tinted chip, sharing a row with others.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.resolve(color);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: ShapeDecoration(
          color: c.withValues(alpha: context.isDark ? 0.12 : 0.08),
          shape: AppTheme.squircle(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: c),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: context.number(18, weight: FontWeight.w800),
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.caption1.copyWith(color: context.secondaryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Start a Workout on the Fitness tab: the four workouts the user does
/// most (or popular ones to begin with), and a way to every other one.
class QuickStart extends StatelessWidget {
  const QuickStart({super.key});

  static const _starters = [
    WorkoutType.run,
    WorkoutType.walk,
    WorkoutType.strength,
    WorkoutType.cycle,
  ];

  /// The four most-done types, most first, topped up with [_starters].
  static List<WorkoutType> favourites(Iterable<WorkoutSession> workouts) {
    final counts = <WorkoutType, int>{};
    for (final w in workouts) {
      counts[w.type] = (counts[w.type] ?? 0) + 1;
    }
    final done = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return [
      ...done,
      for (final t in _starters)
        if (!counts.containsKey(t)) t,
    ].take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final types = favourites(context.watch<WorkoutStore>().all);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ActivityGrid(types: types),
        const SizedBox(height: 10),
        IosCard(
          onTap: () => AllWorkoutsScreen.open(context),
          child: Row(
            children: [
              const IconTile(icon: Icons.apps_rounded, color: fitnessGreen),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'All Workouts',
                  style: context.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${WorkoutType.values.length}',
                style: context.subheadline.copyWith(
                  color: context.secondaryLabel,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: context.tertiaryLabel,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Every workout, by category.
class AllWorkoutsScreen extends StatelessWidget {
  const AllWorkoutsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(
      title: 'All Workouts',
      builder: (_) => const AllWorkoutsScreen(),
    ),
  );

  @override
  Widget build(BuildContext context) => LargeTitlePage(
    title: 'All Workouts',
    children: [
      for (final c in WorkoutCategory.values) ...[
        SectionTitle(c.label, top: c.index == 0 ? 0 : 26),
        _ActivityGrid(
          types: [
            for (final t in WorkoutType.values)
              if (t.category == c) t,
          ],
        ),
      ],
    ],
  );
}

/// [types] as a grid, two to a row.
class _ActivityGrid extends StatelessWidget {
  const _ActivityGrid({required this.types});

  final List<WorkoutType> types;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final w = (c.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final t in types)
            SizedBox(
              width: w,
              child: _ActivityTile(type: t),
            ),
        ],
      );
    },
  );
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.type});

  final WorkoutType type;

  @override
  Widget build(BuildContext context) {
    final flows = IntervalProgram.forType(type).length;
    final detail = switch (type.kind) {
      WorkoutKind.gps => 'GPS route & pace',
      WorkoutKind.strength => 'Sets & reps',
      WorkoutKind.intervals => 'Timed intervals',
      WorkoutKind.timed when flows > 0 =>
        flows == 1 ? '1 guided flow' : '$flows guided flows',
      WorkoutKind.timed => 'Time & calories',
    };
    return Semantics(
      button: true,
      label: '${type.label}, $detail',
      excludeSemantics: true,
      onTap: () => WorkoutLauncher.showSetup(context, type),
      // The picture on top, the name and what's tracked under it.
      child: IosCard(
        padding: const EdgeInsets.all(8),
        tint: type.color,
        onTap: () => WorkoutLauncher.showSetup(context, type),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: WorkoutArt(
                type: type,
                radius: context.innerRadius(AppTheme.radius, 8),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.footnote.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.caption2.copyWith(
                      color: context.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
