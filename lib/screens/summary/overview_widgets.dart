import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/insights/health_overview.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/user_profile.dart';
import 'package:health_app/screens/food/food_diary_screen.dart'
    show FoodDiaryScreen, foodOrange, kcalText;
import 'package:health_app/screens/goal/body_goal_screen.dart';
import 'package:health_app/screens/metric_detail_screen.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/activity_rings.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/widgets/progress_ring.dart';
import 'package:health_app/widgets/sparkline.dart';

/// Today, Week, Month, 3 Months or Year, as a row of pills with a
/// sliding highlight.
class PeriodSwitch extends StatelessWidget {
  const PeriodSwitch({super.key, required this.value, required this.onChanged});

  final SummaryPeriod value;
  final ValueChanged<SummaryPeriod> onChanged;

  static String _short(SummaryPeriod p) =>
      p == SummaryPeriod.quarter ? '3M' : p.label;

  @override
  Widget build(BuildContext context) {
    final tint = context.tint;
    final duration = Motion.reduced(context) ? Duration.zero : Motion.medium;
    const periods = SummaryPeriod.values;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: context.fillColor,
        shape: const StadiumBorder(),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / periods.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: duration,
                curve: Motion.curve,
                left: w * value.index,
                top: 0,
                bottom: 0,
                width: w,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: tint,
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final p in periods)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: p == value,
                        label: p.label,
                        excludeSemantics: true,
                        onTap: () => onChanged(p),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (p == value) return;
                            HapticFeedback.selectionClick();
                            onChanged(p);
                          },
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: AppTheme.minTapTarget - 8,
                            ),
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: duration,
                                style: context.subheadline.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: p == value
                                      ? context.onColor(tint)
                                      : context.secondaryLabel,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(_short(p), maxLines: 1),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Data the Summary's cards draw from, so they stay free of stores.
class OverviewData {
  const OverviewData({
    required this.overview,
    required this.today,
    required this.dailyValue,
    required this.goals,
    required this.eatenOn,
  });

  final HealthOverview overview;
  final DateTime today;
  final double? Function(MetricType type, DateTime day) dailyValue;
  final Goals goals;

  /// Calories eaten on a day, or null when nothing was logged.
  final double? Function(DateTime day) eatenOn;

  SummaryPeriod get period => overview.period;
  bool get isToday => period == SummaryPeriod.today;

  /// Days a chart covers: the period, or the past week for today.
  List<DateTime> get chartDays {
    final n = isToday ? 7 : period.days;
    return [
      for (var i = n - 1; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i),
    ];
  }

  /// [values] for each chart day, as weekly averages past six weeks so a
  /// long period still draws a clean line.
  List<double?> series(double? Function(DateTime day) values) {
    final days = chartDays;
    final raw = [for (final d in days) values(d)];
    if (days.length <= 42) return raw;
    return [
      for (var i = 0; i < raw.length; i += 7)
        _average(raw.sublist(i, (i + 7).clamp(0, raw.length))),
    ];
  }

  static double? _average(List<double?> values) {
    final v = values.whereType<double>().where((x) => x > 0).toList();
    return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
  }

  /// [type] today, or its average a day over the period's finished days.
  double activityValue(MetricType type) {
    if (isToday) return dailyValue(type, today) ?? 0;
    final days = chartDays.where((d) => d != today).toList();
    return _average([for (final d in days) dailyValue(type, d)]) ?? 0;
  }
}

/// The overall score in a big ring, its rating and verdict, and a mini
/// ring for each area underneath.
class ScoreHero extends StatelessWidget {
  const ScoreHero({super.key, required this.data});

  final OverviewData data;

  @override
  Widget build(BuildContext context) {
    final overview = data.overview;
    final tint = context.tint;
    final score = overview.score;
    return Semantics(
      container: true,
      label:
          'Health score, ${score ?? 'not available'}, ${overview.rating}. '
          '${overview.verdict}',
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: ShapeDecoration(
          shape: context.cardShape(AppTheme.radius + 6),
          shadows: context.skinShadows,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                tint.withValues(alpha: context.isDark ? 0.18 : 0.13),
                context.cardBackground,
              ),
              context.cardBackground,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Row(
                children: [
                  ProgressRing(
                    progress: (score ?? 0) / 100,
                    color: tint,
                    size: 104,
                    stroke: 11,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedNumber(
                            value: (score ?? 0).toDouble(),
                            format: (v) =>
                                score == null ? '--' : '${v.round()}',
                            style: context.number(32, weight: FontWeight.w800),
                          ),
                          Text(
                            'of 100',
                            style: context.caption2.copyWith(
                              color: context.secondaryLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HEALTH SCORE',
                          style: context.overline.copyWith(
                            color: context.secondaryLabel,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          overview.rating,
                          style: context.title2.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          overview.verdict,
                          style: context.footnote.copyWith(
                            color: context.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final p in Pillar.values)
                  Expanded(
                    child: _MiniPillar(pillar: p, result: overview[p]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The look of each area: icon and colour.
(IconData, Color) pillarLook(Pillar p) => switch (p) {
  Pillar.activity => (Icons.local_fire_department_rounded, Palette.red),
  Pillar.sleep => (Icons.bedtime_rounded, Palette.indigo),
  Pillar.heart => (Icons.favorite_rounded, Palette.pink),
  Pillar.nutrition => (Icons.restaurant_rounded, foodOrange),
  Pillar.body => (Icons.monitor_weight_rounded, Palette.teal),
};

/// Opens the screen behind an area.
void openPillar(BuildContext context, Pillar p) => switch (p) {
  Pillar.activity => MetricDetailScreen.open(context, MetricType.activeEnergy),
  Pillar.sleep => MetricDetailScreen.open(context, MetricType.sleep),
  Pillar.heart => MetricDetailScreen.open(context, MetricType.restingHeartRate),
  Pillar.nutrition => FoodDiaryScreen.open(context),
  Pillar.body => BodyGoalScreen.open(context),
};

class _MiniPillar extends StatelessWidget {
  const _MiniPillar({required this.pillar, required this.result});

  final Pillar pillar;
  final PillarResult? result;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = pillarLook(pillar);
    final c = context.resolve(color);
    final r = result;
    return Semantics(
      button: true,
      label: '${pillar.label}, ${r == null ? 'no data' : 'score ${r.score}'}',
      excludeSemantics: true,
      onTap: () => openPillar(context, pillar),
      child: Pressable(
        onTap: () => openPillar(context, pillar),
        scale: 0.92,
        child: Column(
          children: [
            ProgressRing(
              progress: (r?.score ?? 0) / 100,
              color: r == null ? context.tertiaryLabel : c,
              size: 40,
              stroke: 4,
              child: Icon(icon, size: 17, color: c),
            ),
            const SizedBox(height: 5),
            Text(
              r == null ? '--' : '${r.score}',
              style: context
                  .number(14)
                  .copyWith(
                    color: r == null
                        ? context.tertiaryLabel
                        : context.labelColor,
                  ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                pillar.label,
                maxLines: 1,
                style: context.caption2.copyWith(color: context.secondaryLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The three activity rings: today's progress, or the average day over
/// a longer period, with a bar for each.
class ActivityHero extends StatelessWidget {
  const ActivityHero({super.key, required this.data});

  final OverviewData data;

  static const rings = [
    (MetricType.activeEnergy, 'Move', Palette.red),
    (MetricType.exerciseMinutes, 'Exercise', Palette.mint),
    (MetricType.steps, 'Steps', Palette.blue),
  ];

  @override
  Widget build(BuildContext context) {
    final values = {for (final (t, _, _) in rings) t: data.activityValue(t)};
    double progress(MetricType t) {
      final goal = data.goals.forMetric(t) ?? 0;
      return goal > 0 ? (values[t] ?? 0) / goal : 0;
    }

    final score = data.overview[Pillar.activity]?.score;
    return Pressable(
      onTap: () => openPillar(context, Pillar.activity),
      scale: 0.985,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: ShapeDecoration(
          shape: context.cardShape(AppTheme.radius),
          shadows: context.skinShadows,
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.4,
            colors: [
              Color.alphaBlend(
                context
                    .resolve(Palette.red)
                    .withValues(alpha: context.isDark ? 0.12 : 0.08),
                context.cardBackground,
              ),
              context.cardBackground,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Activity',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.headline,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _Pill(
                      text: data.isToday
                          ? (score == null ? 'Today' : 'Score $score')
                          : 'Average day',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                ActivityRings(
                  size: 124,
                  strokeWidth: 15,
                  rings: [
                    for (final (t, _, color) in rings)
                      RingData(progress: progress(t), color: color),
                  ],
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (t, label, color) in rings)
                        _RingLegend(
                          type: t,
                          label: label,
                          color: context.resolve(color),
                          value: values[t] ?? 0,
                          goal: data.goals.forMetric(t) ?? 0,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RingLegend extends StatelessWidget {
  const _RingLegend({
    required this.type,
    required this.label,
    required this.color,
    required this.value,
    required this.goal,
  });

  final MetricType type;
  final String label;
  final Color color;
  final double value;
  final double goal;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              flex: 2,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.caption1.copyWith(
                  color: context.secondaryLabel,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 3,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: AnimatedNumber(
                  value: value,
                  format: (v) =>
                      '${formatValue(type, v)}/${formatValue(type, goal)}',
                  style: context.number(17).copyWith(color: color),
                  suffix: ' ${Units.unitFor(type)}',
                  suffixStyle: context.caption1.copyWith(
                    color: context.secondaryLabel,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        _Bar(progress: goal > 0 ? value / goal : 0, color: color),
      ],
    ),
  );
}

/// An area of the overview as a tile: its value, a line for the period
/// and its score. Opens the area.
class PillarTile extends StatelessWidget {
  const PillarTile({super.key, required this.pillar, required this.data});

  final Pillar pillar;
  final OverviewData data;

  (String, String) _text() {
    final r = data.overview[pillar];
    if (r == null) {
      return switch (pillar) {
        Pillar.sleep => ('No Data', 'Sleep shows here once recorded'),
        Pillar.heart => ('No Data', 'Needs a resting heart rate'),
        Pillar.nutrition => ('Log a Meal', 'Nothing logged yet'),
        Pillar.body => ('Weigh In', 'Weigh in a week apart for a trend'),
        Pillar.activity => ('No Data', ''),
      };
    }
    final single = data.isToday;
    return switch (pillar) {
      Pillar.sleep => (
        formatHours(r.value),
        single ? 'last night' : 'a night on average',
      ),
      Pillar.heart => ('${r.value.round()} bpm', 'resting'),
      Pillar.nutrition => (
        '${kcalText(r.value)} Cal',
        single
            ? 'of ${kcalText(r.secondary ?? 0)} today'
            : 'a day · ${r.days} ${r.days == 1 ? 'day' : 'days'} logged',
      ),
      Pillar.body => (
        Units.weight(r.secondary ?? 0),
        '${r.value >= 0 ? '+' : '−'}${Units.weight(r.value.abs())} over '
            '${r.spanDays ?? r.days} days',
      ),
      Pillar.activity => ('', ''),
    };
  }

  List<double?> _series() => data.series(switch (pillar) {
    Pillar.sleep => (d) => data.dailyValue(MetricType.sleep, d),
    Pillar.heart => (d) => data.dailyValue(MetricType.restingHeartRate, d),
    Pillar.nutrition => data.eatenOn,
    Pillar.body => (d) => data.dailyValue(MetricType.weight, d),
    Pillar.activity => (d) => data.dailyValue(MetricType.steps, d),
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = pillarLook(pillar);
    final (value, caption) = _text();
    return SummaryTile(
      icon: icon,
      color: color,
      label: pillar.label,
      score: data.overview[pillar]?.score,
      series: _series(),
      value: value,
      caption: caption,
      onTap: () => openPillar(context, pillar),
    );
  }
}

/// Water drunk today against the goal, or a day on average over the
/// period. Opens Water.
class WaterTile extends StatelessWidget {
  const WaterTile({super.key, required this.data});

  final OverviewData data;

  @override
  Widget build(BuildContext context) {
    const type = MetricType.water;
    final goal = data.goals.water;
    final drunk = data.activityValue(type);
    final unit = unitLabel(type);
    final String caption;
    if (drunk <= 0) {
      caption = data.isToday ? 'Nothing logged yet today' : 'None logged';
    } else if (data.isToday) {
      caption = 'of ${formatValue(type, goal)} $unit today';
    } else {
      caption = 'a day on average';
    }
    return SummaryTile(
      icon: type.icon,
      color: type.color,
      label: 'Water',
      progress: goal > 0 ? (drunk / goal).clamp(0, 1).toDouble() : null,
      series: data.series((d) => data.dailyValue(type, d)),
      value: drunk <= 0 ? 'Log Water' : '${formatValue(type, drunk)} $unit',
      caption: caption,
      onTap: () => MetricDetailScreen.open(context, type),
    );
  }
}

/// The look shared by the Summary's tiles: an icon and label with the
/// score (or progress), a line over the period, the value and a caption.
class SummaryTile extends StatelessWidget {
  const SummaryTile({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.series,
    required this.value,
    required this.caption,
    required this.onTap,
    this.score,
    this.progress,
  });

  final IconData icon;
  final Color color;
  final String label;
  final List<double?> series;
  final String value;
  final String caption;
  final VoidCallback onTap;

  /// A 0–100 score shown as a pill, if the area is scored.
  final int? score;

  /// Progress to a goal (0–1), shown as a pill when there's no score.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final c = context.resolve(color);
    final hasLine = series.whereType<double>().length >= 2;
    final score = this.score, progress = this.progress;
    final pill = score != null
        ? '$score'
        : progress != null && progress > 0
        ? '${(progress * 100).round()}%'
        : null;
    return Semantics(
      button: true,
      label: '$label, $value, $caption${score == null ? '' : ', score $score'}',
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(
            minHeight: MediaQuery.textScalerOf(context).scale(132),
          ),
          padding: const EdgeInsets.all(14),
          decoration: ShapeDecoration(
            shape: context.cardShape(AppTheme.radius),
            shadows: context.skinShadows,
            gradient: RadialGradient(
              center: Alignment.topLeft,
              radius: 1.3,
              colors: [
                Color.alphaBlend(
                  c.withValues(alpha: context.isDark ? 0.14 : 0.10),
                  context.cardBackground,
                ),
                context.cardBackground,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.withValues(alpha: context.isDark ? 0.2 : 0.15),
                    ),
                    child: Icon(icon, color: c, size: 14),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.footnote.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // Shrinks rather than overflows at large text sizes.
                  if (pill != null)
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: _Pill(text: pill, color: c),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (hasLine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Sparkline(
                    values: series,
                    color: color,
                    width: double.infinity,
                    height: 26,
                  ),
                ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: context.title2.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Text(
                caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.caption1.copyWith(color: context.secondaryLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small rounded label.
class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: ShapeDecoration(
        color: c == null ? context.fillColor : c.withValues(alpha: 0.16),
        shape: const StadiumBorder(),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.caption1.copyWith(
          color: c ?? context.secondaryLabel,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// A thin capsule that fills to [progress].
class _Bar extends StatelessWidget {
  const _Bar({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: progress.clamp(0.0, 1.0)),
    duration: Motion.reduced(context)
        ? Duration.zero
        : const Duration(milliseconds: 900),
    curve: Curves.easeOutQuart,
    builder: (context, t, _) => Container(
      height: 5,
      alignment: Alignment.centerLeft,
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.18),
        shape: const StadiumBorder(),
      ),
      child: FractionallySizedBox(
        widthFactor: t,
        heightFactor: 1,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: color,
            shape: const StadiumBorder(),
          ),
        ),
      ),
    ),
  );
}

/// The biggest changes against the period before, as plain sentences.
class ChangeList extends StatelessWidget {
  const ChangeList({super.key, required this.overview});

  final HealthOverview overview;

  String _sentence(Change c) {
    final t = c.type;
    final diff = (c.current - c.previous).abs();
    final more = c.current > c.previous;
    final than = overview.period == SummaryPeriod.today
        ? 'your weekly average'
        : 'the ${overview.period == SummaryPeriod.week ? 'week' : 'period'} '
              'before';
    return switch (t) {
      MetricType.steps =>
        '${formatValue(t, diff)} ${more ? 'more' : 'fewer'} steps a day '
            'than $than',
      MetricType.sleep =>
        'Sleeping ${formatHours(diff)} ${more ? 'more' : 'less'} a night '
            'than $than',
      MetricType.restingHeartRate =>
        'Resting heart rate ${diff.round()} bpm ${more ? 'higher' : 'lower'} '
            'than $than',
      MetricType.exerciseMinutes =>
        '${diff.round()} ${more ? 'more' : 'fewer'} exercise minutes a day '
            'than $than',
      _ =>
        '${formatValue(t, diff)} ${more ? 'more' : 'fewer'} active Cal a '
            'day than $than',
    };
  }

  @override
  Widget build(BuildContext context) {
    final changes = overview.changes;
    final good = context.resolve(Palette.green);
    final bad = context.resolve(Palette.orange);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      decoration: ShapeDecoration(
        color: context.cardBackground,
        shape: context.cardShape(AppTheme.radius),
        shadows: context.skinShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Text(
              'What Changed',
              style: context.headline.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (changes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: context.tertiaryLabel,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Nothing changed much against '
                      '${overview.period == SummaryPeriod.today ? 'your weekly average' : 'the period before'}.',
                      style: context.subheadline.copyWith(
                        color: context.secondaryLabel,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          for (final c in changes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (c.isGood ? good : bad).withValues(alpha: 0.16),
                    ),
                    child: Icon(
                      c.current > c.previous
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: c.isGood ? good : bad,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_sentence(c), style: context.subheadline),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
