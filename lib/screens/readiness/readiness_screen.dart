import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/insights/readiness.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/screens/metric_detail_screen.dart';
import 'package:health_app/screens/readiness/suggestions.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/progress_ring.dart';
import 'package:health_app/sync/health_sync_service.dart';

/// Today's readiness, worked out from the store's data.
Readiness? readinessOf(HealthStore store) => Readiness.compute(
  dailyValue: store.dailyValue,
  today: store.today,
  sleepGoalHours: store.goals.sleep,
);

/// The colour of a readiness level.
Color readinessColor(ReadinessLevel level) => switch (level) {
  ReadinessLevel.ready => Palette.green,
  ReadinessLevel.steady => Palette.yellow,
  ReadinessLevel.rest => Palette.orange,
};

/// Readiness in detail: the score, what it means today, each signal
/// against the user's normal, and workouts that suit it.
class ReadinessScreen extends StatelessWidget {
  const ReadinessScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(title: 'Readiness', builder: (_) => const ReadinessScreen()),
  );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final r = readinessOf(store);
    return CupertinoPageScaffold(
      backgroundColor: context.groupedBackground,
      navigationBar: const CupertinoNavigationBar(middle: Text('Readiness')),
      child: PageList(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.margin,
          12,
          AppTheme.margin,
          32,
        ),
        children: [
          if (r == null) const _NotEnoughData() else ..._details(context, r),
          const SizedBox(height: 16),
          Text(
            'Readiness compares this morning\'s heart rate variability (40%) '
            'and resting heart rate (30%) with your own '
            '${Readiness.baselineDays}-day normal, and last night\'s sleep '
            '(30%) with your sleep goal. It needs at least two of the three '
            'and a week of history. It\'s a training guide, not medical '
            'advice, and it can\'t detect heart or other conditions.',
            style: context.footnote.copyWith(color: context.secondaryLabel),
          ),
        ],
      ),
    );
  }

  List<Widget> _details(BuildContext context, Readiness r) {
    final color = context.resolve(readinessColor(r.level));
    return [
      IosCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            ProgressRing(
              progress: r.score / 100,
              color: color,
              size: 96,
              child: Text(
                '${r.score}',
                style: context.number(30, weight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.level.label, style: context.title2),
                  const SizedBox(height: 4),
                  Text(
                    r.level.advice,
                    style: context.subheadline.copyWith(
                      color: context.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SectionTitle('What It\'s Based On'),
      GroupedSection(
        hasLeading: true,
        children: [
          for (final s in ReadinessSignal.values)
            InfoRow(
              leading: Icon(switch (s) {
                ReadinessSignal.hrv => Icons.graphic_eq_rounded,
                ReadinessSignal.restingHeart => Icons.favorite_rounded,
                ReadinessSignal.sleep => Icons.bed_rounded,
              }, color: context.secondaryLabel),
              title: s.label,
              subtitle: r.signals[s]?.detail ?? 'No data this morning',
              value: switch (r.signals[s]) {
                final v? => '${v.score.round()}',
                null => '–',
              },
              chevron: true,
              onTap: () => MetricDetailScreen.open(context, switch (s) {
                ReadinessSignal.hrv => MetricType.hrv,
                ReadinessSignal.restingHeart => MetricType.restingHeartRate,
                ReadinessSignal.sleep => MetricType.sleep,
              }),
            ),
        ],
      ),
      const SectionTitle('Suits You Today'),
      const SuggestionList(),
    ];
  }
}

class _NotEnoughData extends StatelessWidget {
  const _NotEnoughData();

  @override
  Widget build(BuildContext context) => IosCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Not Enough Data Yet', style: context.headline),
        const SizedBox(height: 6),
        Text(
          'Readiness needs a week of heart rate variability or resting '
          'heart rate, plus last night\'s sleep. Wear your watch to bed and '
          'connect ${context.read<HealthSyncService>().sourceName}, and it '
          'will appear here.',
          style: context.subheadline.copyWith(color: context.secondaryLabel),
        ),
      ],
    ),
  );
}

/// Readiness on the Summary: the score in a ring, the level and advice.
class ReadinessCard extends StatelessWidget {
  const ReadinessCard({super.key});

  @override
  Widget build(BuildContext context) {
    final r = readinessOf(context.watch<HealthStore>());
    final color = r == null
        ? context.tertiaryLabel
        : context.resolve(readinessColor(r.level));
    return Semantics(
      container: true,
      button: true,
      label: r == null
          ? 'Readiness, not enough data yet'
          : 'Readiness ${r.score}, ${r.level.label}. ${r.level.advice}',
      excludeSemantics: true,
      child: IosCard(
        onTap: () => ReadinessScreen.open(context),
        child: Row(
          children: [
            ProgressRing(
              progress: (r?.score ?? 0) / 100,
              color: color,
              size: 72,
              stroke: 8,
              child: Text(
                r == null ? '–' : '${r.score}',
                style: context.number(22, weight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Readiness',
                    style: context.footnote.copyWith(
                      color: context.secondaryLabel,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    r?.level.label ?? 'Not enough data',
                    style: context.title3,
                  ),
                  Text(
                    r?.level.advice ??
                        'Needs a week of HRV or resting heart rate.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
    );
  }
}
