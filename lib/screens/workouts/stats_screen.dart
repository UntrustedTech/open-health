import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/insights/progress_stats.dart';
import 'package:health_app/insights/training_stats.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/screens/add_entry_sheet.dart';
import 'package:health_app/screens/workouts/workout_history_screen.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/area_chart.dart';
import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/models/muscles.dart';
import 'package:health_app/screens/workouts/records_screen.dart';
import 'package:health_app/screens/workouts/workout_insights.dart'
    show BodyMapPair;
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/activity_heatmap.dart';
import 'package:health_app/widgets/bar_chart.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/utils/units.dart';

enum _MapMode { volume, recovering, untrained }

/// Workout progress & history: headline numbers, a year of activity,
/// body weight, exercise progress, volume, muscles and strength balance.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(AppRoute<void>(title: 'Stats', builder: (_) => const StatsScreen()));

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

/// The training green used across Stats (like the Exercise ring).
Color statsGreen(BuildContext context) => context.resolve(Palette.green);

class _StatsScreenState extends State<StatsScreen> {
  _MapMode _mode = _MapMode.volume;
  String? _exercise;
  ProgressRange _weightRange = ProgressRange.quarter;
  ProgressRange _liftRange = ProgressRange.all;
  ExerciseMetric _metric = ExerciseMetric.oneRepMax;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkoutStore>();
    final health = context.watch<HealthStore>();
    final workouts = store.all;
    final today = store.today;
    final green = statsGreen(context);
    var i = 0;

    return LargeTitlePage(
      title: 'Stats',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundButton(
            icon: Icons.workspace_premium_rounded,
            label: 'Personal Records',
            onTap: () => RecordsScreen.open(context),
          ),
          const SizedBox(width: 8),
          _RoundButton(
            icon: Icons.access_time_rounded,
            label: 'History',
            onTap: () => WorkoutHistoryScreen.open(context),
          ),
        ],
      ),
      children: [
        Text(
          'Progress & history',
          style: context.title3.copyWith(
            color: context.secondaryLabel,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Appear(
          index: i++,
          child: _Headline(health: health, store: store),
        ),
        const SizedBox(height: 12),
        Appear(
          index: i++,
          child: IosCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Activity', style: context.headline),
                Text(
                  'Last 12 months · by time trained',
                  style: context.footnote.copyWith(
                    color: context.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 12),
                ActivityHeatmap(
                  minutesByDay: activityByDay(workouts, today: today),
                  today: today,
                  color: green,
                  weekStart: store.plan.weekStart,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Appear(
          index: i++,
          child: _WeightCard(
            range: _weightRange,
            onRange: (r) => setState(() => _weightRange = r),
          ),
        ),
        const SizedBox(height: 12),
        Appear(
          index: i++,
          child: _ExerciseCard(
            exercise: _exercise,
            metric: _metric,
            range: _liftRange,
            onExercise: (id) => setState(() => _exercise = id),
            onMetric: (m) => setState(() => _metric = m),
            onRange: (r) => setState(() => _liftRange = r),
          ),
        ),
        const SizedBox(height: 12),
        Appear(
          index: i++,
          child: _VolumeCard(workouts: workouts, today: today),
        ),
        const SizedBox(height: 12),
        Appear(index: i++, child: _musclesCard(context, workouts)),
        ..._balance(store),
      ],
    );
  }

  Widget _musclesCard(BuildContext context, List<WorkoutSession> workouts) {
    final now = DateTime.now();
    final Map<Muscle, double> map;
    final Color mapColor;
    final String mapNote;
    switch (_mode) {
      case _MapMode.volume:
        map = muscleVolume(workouts, now: now);
        mapColor = context.tint;
        mapNote = 'Where your sets went in the last 7 days.';
      case _MapMode.recovering:
        map = muscleRecovery(workouts, now: now);
        mapColor = Palette.orange;
        mapNote = 'Trained in the last 48 hours. Brighter means more recent.';
      case _MapMode.untrained:
        map = {for (final m in untrainedMuscles(workouts, now: now)) m: 1.0};
        mapColor = Palette.blue;
        mapNote = map.isEmpty
            ? 'Every major muscle was trained this week.'
            : 'Not trained in 7 days: ${map.keys.map((m) => m.label).join(', ')}.';
    }
    return IosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Muscles', style: context.headline),
          const SizedBox(height: 10),
          RangePicker<_MapMode>(
            values: _MapMode.values,
            selected: _mode,
            label: (m) => switch (m) {
              _MapMode.volume => 'Volume',
              _MapMode.recovering => 'Recovering',
              _MapMode.untrained => 'Untrained',
            },
            onChanged: (m) => setState(() => _mode = m),
          ),
          const SizedBox(height: 12),
          BodyMapPair(height: 260, intensity: map, color: mapColor),
          const SizedBox(height: 8),
          Text(
            mapNote,
            style: context.footnote.copyWith(color: context.secondaryLabel),
          ),
        ],
      ),
    );
  }

  List<Widget> _balance(WorkoutStore store) {
    final ratios = strengthRatios(store.records.bestLifts);
    if (ratios.isEmpty) return const [];
    return [
      GroupedSection(
        header: 'Strength Balance',
        footer:
            'Rules of thumb for balanced strength, from your estimated '
            'one-rep maxes.',
        hasLeading: false,
        children: [for (final r in ratios) _RatioRow(ratio: r)],
      ),
    ];
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    semanticLabel: label,
    onTap: onTap,
    child: Container(
      width: AppTheme.minTapTarget,
      height: AppTheme.minTapTarget,
      decoration: BoxDecoration(
        color: context.cardBackground,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: context.labelColor),
    ),
  );
}

/// Workouts, this month, week streak and 30-day weight change.
class _Headline extends StatelessWidget {
  const _Headline({required this.health, required this.store});

  final HealthStore health;
  final WorkoutStore store;

  @override
  Widget build(BuildContext context) {
    final today = store.today;
    final weights = weightSeries(health);
    final change = changeOver(weights, today);
    final goal = health.goals.weightKg;
    // Green when heading towards the goal (or down, without one).
    final good = change == null || change.abs() < 0.05
        ? null
        : goal == null
        ? change < 0
        : (weights.last.value - goal).abs() <
              (weights.last.value - change - goal).abs();
    final changeText = change == null
        ? '–'
        : '${change > 0
                  ? '+'
                  : change < 0
                  ? '−'
                  : ''}'
              '${Units.weight(change.abs())}';
    final tiles = [
      (
        Icons.sports_outlined,
        'Workouts',
        '${store.all.length}',
        null as Color?,
      ),
      (
        Icons.calendar_month_rounded,
        'This month',
        '${workoutsThisMonth(store.all, today)}',
        null,
      ),
      (
        Icons.local_fire_department_outlined,
        'Week streak',
        '${weekStreak(store.all, today, firstDay: store.plan.weekStart)}',
        null,
      ),
      (
        Icons.speed_rounded,
        'Weight 30d',
        changeText,
        switch (good) {
          true => statsGreen(context),
          false => context.resolve(Palette.orange),
          null => null,
        },
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (icon, label, value, color) in tiles)
              SizedBox(
                width: w,
                child: Semantics(
                  label: '$label: $value',
                  excludeSemantics: true,
                  child: IosCard(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(icon, size: 16, color: context.secondaryLabel),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.subheadline.copyWith(
                                  color: context.secondaryLabel,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            value,
                            style: context
                                .number(34, weight: FontWeight.w700)
                                .copyWith(color: color),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Body weight, one point per day, oldest first.
List<DatedValue> weightSeries(HealthStore health) {
  final days = <DateTime>{
    for (final e in health.entriesFor(MetricType.weight))
      DateTime(e.date.year, e.date.month, e.date.day),
  }.toList()..sort();
  return [
    for (final d in days)
      if (health.dailyValue(MetricType.weight, d) case final v?)
        (date: d, value: v),
  ];
}

class _WeightCard extends StatelessWidget {
  const _WeightCard({required this.range, required this.onRange});

  final ProgressRange range;
  final ValueChanged<ProgressRange> onRange;

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthStore>();
    final goal = health.goals.weightKg;
    final points = range.clip(weightSeries(health), health.today);
    final green = statsGreen(context);
    const gold = Color(0xFFFFCF3D);
    return IosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Body weight', style: context.headline)),
              if (goal != null) ...[
                const Icon(Icons.track_changes_rounded, size: 18, color: gold),
                const SizedBox(width: 4),
                Text(
                  Units.weight(goal),
                  style: context.subheadline.copyWith(
                    color: context.resolve(
                      const CupertinoDynamicColor.withBrightness(
                        color: Color(0xFFB38F00),
                        darkColor: gold,
                      ),
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size.square(AppTheme.minTapTarget),
                onPressed: () => AddEntrySheet.show(context, MetricType.weight),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 18, color: green),
                    const SizedBox(width: 2),
                    Text(
                      'Log',
                      style: context.subheadline.copyWith(
                        color: green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RangePicker<ProgressRange>(
            values: ProgressRange.values,
            selected: range,
            label: (r) => r.label,
            onChanged: onRange,
          ),
          const SizedBox(height: 12),
          AreaChart(
            points: points,
            color: green,
            goal: goal,
            format: Units.weight,
            emptyText: 'Log your weight on two days to see a trend.',
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.metric,
    required this.range,
    required this.onExercise,
    required this.onMetric,
    required this.onRange,
  });

  final String? exercise;
  final ExerciseMetric metric;
  final ProgressRange range;
  final ValueChanged<String> onExercise;
  final ValueChanged<ExerciseMetric> onMetric;
  final ValueChanged<ProgressRange> onRange;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkoutStore>();
    final best = store.records.bestLifts;
    final lifted = best.keys.toList()
      ..sort(
        (a, b) =>
            best[b]!.estimatedOneRepMax.compareTo(best[a]!.estimatedOneRepMax),
      );
    final id = exercise ?? lifted.firstOrNull;
    final green = statsGreen(context);
    if (id == null) {
      return IosCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exercise progress', style: context.headline),
            const SizedBox(height: 8),
            Text(
              'Log a strength workout to follow each lift over time.',
              style: context.subheadline.copyWith(
                color: context.secondaryLabel,
              ),
            ),
          ],
        ),
      );
    }
    final all = exerciseSeries(store.all, id, metric);
    final points = range.clip(all, store.today);
    final record = best[id];
    String fmt(double v) =>
        Units.weight(v, decimals: metric == ExerciseMetric.volume ? 0 : 1);
    final gain = points.length >= 2
        ? points.last.value - points.first.value
        : null;
    return IosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Exercise progress', style: context.headline),
          const SizedBox(height: 8),
          Pressable(
            semanticLabel: tr('Choose exercise'),
            onTap: () => _pick(context, lifted),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: ShapeDecoration(
                color: context.fillColor,
                shape: AppTheme.squircle(12),
              ),
              child: Row(
                children: [
                  Text(
                    'Exercise',
                    style: context.subheadline.copyWith(
                      color: context.secondaryLabel,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ExerciseCatalog.instance.nameOf(id),
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.subheadline.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.unfold_more_rounded,
                    size: 14,
                    color: context.secondaryLabel,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          RangePicker<ExerciseMetric>(
            values: ExerciseMetric.values,
            selected: metric,
            label: (m) => m.label,
            onChanged: onMetric,
          ),
          const SizedBox(height: 8),
          RangePicker<ProgressRange>(
            values: ProgressRange.values,
            selected: range,
            label: (r) => r.label,
            onChanged: onRange,
          ),
          const SizedBox(height: 12),
          AreaChart(
            points: points,
            color: green,
            format: fmt,
            emptyText: 'Log this exercise twice in this period to see a trend.',
          ),
          if (record != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: _Fact(
                    label: 'Best set',
                    value: '${Units.weight(record.weightKg)} × ${record.reps}',
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: _Fact(
                    label: 'Est. 1RM',
                    value: Units.weight(record.estimatedOneRepMax, decimals: 0),
                  ),
                ),
                if (gain != null)
                  Expanded(
                    flex: 3,
                    child: _Fact(
                      label: 'Change',
                      value: '${gain >= 0 ? '+' : '−'}${fmt(gain.abs())}',
                      color: gain > 0 ? green : null,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context, List<String> ids) async {
    final picked = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Exercise'),
        actions: [
          for (final id in ids.take(25))
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, id),
              child: Text(ExerciseCatalog.instance.nameOf(id)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (picked != null) onExercise(picked);
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.caption1.copyWith(color: context.secondaryLabel),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: context.headline.copyWith(color: color)),
        ),
      ],
    ),
  );
}

class _VolumeCard extends StatelessWidget {
  const _VolumeCard({required this.workouts, required this.today});

  final List<WorkoutSession> workouts;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final volume = weeklyVolume(
      workouts,
      today: today,
      firstDay: context.select<WorkoutStore, int>((s) => s.plan.weekStart),
    );
    return IosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly volume', style: context.headline),
          Text(
            'Weight lifted per week (working sets)',
            style: context.footnote.copyWith(color: context.secondaryLabel),
          ),
          const SizedBox(height: 10),
          BarChart(
            values: [for (final w in volume) Units.weightOut(w.kg)],
            labels: [
              for (final (j, w) in volume.indexed)
                j % 3 == 0 ? DateFormat.MMMd().format(w.weekStart) : '',
            ],
            color: statsGreen(context),
            height: 160,
            axisLabel: (v) => NumberFormat.compact().format(v),
          ),
        ],
      ),
    );
  }
}

class _RatioRow extends StatelessWidget {
  const _RatioRow({required this.ratio});

  final StrengthRatio ratio;

  @override
  Widget build(BuildContext context) {
    final r = ratio;
    final off = (r.actual - r.target) / r.target;
    final color = context.resolve(
      off.abs() <= 0.1
          ? Palette.green
          : off.abs() <= 0.2
          ? Palette.orange
          : Palette.red,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(r.label, style: context.body)),
              Text(
                '${(r.actual * 100).round()}%',
                style: context.number(17).copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          CapsuleProgress(
            value: (r.actual / (r.target * 1.5)).clamp(0, 1),
            color: color,
          ),
          const SizedBox(height: 4),
          Text(
            'Target about ${(r.target * 100).round()}%',
            style: context.footnote.copyWith(color: context.secondaryLabel),
          ),
        ],
      ),
    );
  }
}
