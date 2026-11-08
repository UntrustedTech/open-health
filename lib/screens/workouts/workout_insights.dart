import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/insights/progress_stats.dart';
import 'package:health_app/insights/training_stats.dart';
import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/models/muscles.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/screens/workouts/exercise_detail_screen.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/body_map.dart';
import 'package:health_app/widgets/exercise_clip.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/workout/workout_stats.dart';

/// How this workout compares with the last one of the same kind.
class ComparisonCard extends StatelessWidget {
  const ComparisonCard({super.key, required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkoutStore>();
    final prev = previousOfType(store.all, session);
    if (prev == null) return const SizedBox.shrink();
    final s = session;
    final rows =
        <
          ({
            String label,
            String now,
            double delta,
            bool higherIsBetter,
            String change,
          })
        >[];
    void add(
      String label,
      double a,
      double b,
      String Function(double) fmt, {
      bool higherIsBetter = true,
    }) {
      if (a <= 0 && b <= 0) return;
      final d = a - b;
      rows.add((
        label: label,
        now: fmt(a),
        delta: d,
        higherIsBetter: higherIsBetter,
        change: '${d >= 0 ? '+' : '−'}${fmt(d.abs())}',
      ));
    }

    add(
      'Time',
      s.activeSeconds.toDouble(),
      prev.activeSeconds.toDouble(),
      (v) => formatMinutes(Duration(seconds: v.round())),
    );
    if (s.distanceMeters >= 10 || prev.distanceMeters >= 10) {
      add('Distance', s.distanceMeters, prev.distanceMeters, formatDistance);
      final a = s.paceSecondsPerKm, b = prev.paceSecondsPerKm;
      if (a != null && b != null) {
        // Lower pace is faster.
        add(
          'Pace',
          a,
          b,
          (v) => '${formatPace(v)}${Units.paceUnit}',
          higherIsBetter: false,
        );
      }
    }
    if (s.exercises.isNotEmpty || prev.exercises.isNotEmpty) {
      add(
        'Volume',
        s.volumeKg,
        prev.volumeKg,
        (v) => Units.weight(v, decimals: 0),
      );
      add(
        'Sets',
        s.completedSets.toDouble(),
        prev.completedSets.toDouble(),
        (v) => '${v.round()}',
      );
    }
    add('Energy', s.activeKcal, prev.activeKcal, (v) => '${v.round()} Cal');
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: IosCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Compared with Last Time', style: context.headline),
            Text(
              formatDay(prev.start, store.today),
              style: context.footnote.copyWith(color: context.secondaryLabel),
            ),
            const SizedBox(height: 10),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(child: Text(r.label, style: context.body)),
                    Text(
                      r.now,
                      style: context.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 104,
                      child: _Delta(
                        text: r.change,
                        delta: r.delta,
                        higherIsBetter: r.higherIsBetter,
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

class _Delta extends StatelessWidget {
  const _Delta({
    required this.text,
    required this.delta,
    required this.higherIsBetter,
  });

  final String text;
  final double delta;
  final bool higherIsBetter;

  @override
  Widget build(BuildContext context) {
    final same = delta.abs() < 1e-6;
    final good = (delta > 0) == higherIsBetter;
    final color = context.resolve(
      same
          ? Palette.grey
          : good
          ? Palette.green
          : Palette.orange,
    );
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: ShapeDecoration(
          color: color.withValues(alpha: 0.15),
          shape: const StadiumBorder(),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            same ? 'Same' : text,
            style: context.footnote.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// One card per exercise: sets, the best set, records and volume share.
class ExerciseBreakdown extends StatelessWidget {
  const ExerciseBreakdown({super.key, required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkoutStore>();
    final records = sessionRecords(store.all, session);
    final total = session.volumeKg;
    final color = session.type.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Exercises'),
        for (final e in session.exercises) ...[
          _ExerciseCard(
            log: e,
            record: records.contains(ExerciseCatalog.canonical(e.exerciseId)),
            share: total <= 0
                ? 0
                : e.sets
                          .where((s) => s.done)
                          .fold<double>(0, (a, s) => a + s.volume) /
                      total,
            color: color,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.log,
    required this.record,
    required this.share,
    required this.color,
  });

  final ExerciseLog log;
  final bool record;
  final double share;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final done = [
      for (final (i, s) in log.sets.indexed)
        if (s.done) (n: i + 1, s: s),
    ];
    final best = done
        .where((d) => d.s.type.counts && d.s.weightKg > 0)
        .fold<({int n, SetLog s})?>(
          null,
          (b, d) =>
              b == null ||
                  epley(d.s.weightKg, d.s.reps) > epley(b.s.weightKg, b.s.reps)
              ? d
              : b,
        );
    final gold = context.resolve(Palette.yellow);
    return IosCard(
      onTap: () => ExerciseDetailScreen.open(context, log.exerciseId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExerciseThumb(exerciseId: log.exerciseId, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ExerciseCatalog.instance.nameOf(log.exerciseId),
                  style: context.headline,
                ),
              ),
              if (record)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: ShapeDecoration(
                    color: gold.withValues(alpha: 0.18),
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        size: 14,
                        color: gold,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'PR',
                        style: context.caption1.copyWith(
                          color: gold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (done.isEmpty)
            Text(
              'No completed sets',
              style: context.subheadline.copyWith(
                color: context.secondaryLabel,
              ),
            )
          else
            for (final d in done)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        switch (d.s.type) {
                          SetType.warmup => 'W',
                          SetType.drop => 'D',
                          SetType.failure => 'F',
                          _ => '${d.n}',
                        },
                        style: context.subheadline.copyWith(
                          color: context.secondaryLabel,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        d.s.seconds != null && d.s.reps == 0
                            ? '${d.s.seconds} s'
                            : d.s.weightKg > 0
                            ? '${Units.weight(d.s.weightKg)} × ${d.s.reps}'
                            : '${d.s.reps} reps',
                        style: context.subheadline.copyWith(
                          fontWeight: identical(d, best)
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (identical(d, best))
                      Text(
                        'Best · 1RM ${Units.weight(epley(d.s.weightKg, d.s.reps), decimals: 0)}',
                        style: context.caption1.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
          if (share > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CapsuleProgress(value: share, color: color, height: 6),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(share * 100).round()}% of volume',
                  style: context.caption1.copyWith(
                    color: context.secondaryLabel,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Front and back body maps side by side.
class BodyMapPair extends StatelessWidget {
  const BodyMapPair({
    super.key,
    required this.height,
    required this.intensity,
    this.color,
  });

  final double height;
  final Map<Muscle, double> intensity;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Row(
      children: [
        for (final side in BodySide.values) ...[
          if (side != BodySide.front) const SizedBox(width: 8),
          Expanded(
            child: BodyMap(side: side, intensity: intensity, color: color),
          ),
        ],
      ],
    ),
  );
}

/// Front and back body maps lit by this workout's sets.
class SessionMuscles extends StatelessWidget {
  const SessionMuscles({super.key, required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final map = muscleVolume([session], now: session.end, days: 1);
    if (map.isEmpty) return const SizedBox.shrink();
    final top =
        (map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .take(4)
            .map((e) => e.key.label)
            .join(', ');
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: IosCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Muscles Worked', style: context.headline),
            Text(
              top,
              style: context.footnote.copyWith(color: context.secondaryLabel),
            ),
            const SizedBox(height: 10),
            BodyMapPair(height: 220, intensity: map, color: session.type.color),
          ],
        ),
      ),
    );
  }
}
