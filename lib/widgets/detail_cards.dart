import 'package:flutter/cupertino.dart' hide Text;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/insights/heart_zones.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';

/// Last night's sleep stages as one bar, then the past week stacked.
class SleepStagesCard extends StatelessWidget {
  const SleepStagesCard({super.key});

  static const _stages = MetricType.sleepStages;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final today = store.today;
    final days = [
      for (var i = 6; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i),
    ];
    List<double> stagesOn(DateTime d) => [
      for (final s in _stages) store.dailyValue(s, d) ?? 0,
    ];
    // The most recent night with stage data.
    final last = days.reversed
        .map((d) => (day: d, v: stagesOn(d)))
        .where((n) => n.v.any((x) => x > 0))
        .firstOrNull;
    if (last == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: IosCard(
          child: Text(
            'Sleep stages appear here when your watch or phone records '
            'them in Health Connect, or when you add them yourself.',
            style: context.subheadline.copyWith(color: context.secondaryLabel),
          ),
        ),
      );
    }
    final total = last.v.fold<double>(0, (a, b) => a + b);
    final weekMax = days
        .map((d) => stagesOn(d).fold<double>(0, (a, b) => a + b))
        .reduce((a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: IosCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Sleep Stages', style: context.headline)),
                Text(
                  formatDay(last.day, today),
                  style: context.footnote.copyWith(
                    color: context.secondaryLabel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Bar(
              parts: [
                for (final (i, s) in _stages.indexed)
                  (value: last.v[i], color: context.resolve(s.color)),
              ],
              height: 14,
            ),
            const SizedBox(height: 12),
            for (final (i, s) in _stages.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: context.resolve(s.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.label
                            .replaceAll(' Sleep', '')
                            .replaceAll(' in Bed', ''),
                        style: context.subheadline,
                      ),
                    ),
                    Text(
                      formatHours(last.v[i]),
                      style: context.subheadline.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        total > 0
                            ? '${(last.v[i] / total * 100).round()}%'
                            : '',
                        textAlign: TextAlign.right,
                        style: context.footnote.copyWith(
                          color: context.secondaryLabel,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'PAST 7 NIGHTS',
              style: context.caption1.copyWith(
                color: context.secondaryLabel,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 96,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in days)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: weekMax > 0
                                    ? (stagesOn(d).fold<double>(
                                                0,
                                                (a, b) => a + b,
                                              ) /
                                              weekMax)
                                          .clamp(0.0, 1.0)
                                    : 0,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  child: _Bar(
                                    vertical: true,
                                    parts: [
                                      for (final (i, s) in _stages.indexed)
                                        (
                                          value: stagesOn(d)[i],
                                          color: context.resolve(s.color),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('EEEEE').format(d),
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
          ],
        ),
      ),
    );
  }
}

/// Segments in proportion to their values, with rounded ends.
class _Bar extends StatelessWidget {
  const _Bar({required this.parts, this.height, this.vertical = false});

  final List<({double value, Color color})> parts;
  final double? height;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final shown = parts.where((p) => p.value > 0).toList();
    final children = [
      for (final p in vertical ? shown.reversed : shown)
        Expanded(
          flex: (p.value * 1000).round().clamp(1, 1 << 30),
          child: ColoredBox(color: p.color),
        ),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(vertical ? 4 : 7),
      child: SizedBox(
        height: height,
        child: vertical
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              )
            : Row(children: children),
      ),
    );
  }
}

/// Time in each heart rate zone over the past week, or in [day]'s bins on
/// the Day tab.
class HeartZonesCard extends StatelessWidget {
  const HeartZonesCard({super.key, this.day});

  final List<double>? day;

  static const _colors = [
    Palette.teal,
    Palette.green,
    Palette.yellow,
    Palette.orange,
    Palette.red,
  ];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final today = store.today;
    final age = store.profile.ageOn(today);
    final maxHr = maxHeartRate(age);
    final one = day;
    final days = one != null
        ? [one]
        : [
            for (var i = 0; i < 7; i++)
              ?store.heartBinsOn(
                DateTime(today.year, today.month, today.day - i),
              ),
          ];
    final zones = ZoneMinutes.of(days, maxHr);
    final most = zones.minutes.values.fold<double>(0, (a, b) => a > b ? a : b);
    final reduce = Motion.reduced(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: IosCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Heart Rate Zones', style: context.headline),
            Text(
              one != null
                  ? 'This day · max heart rate ${maxHr.round()} bpm'
                  : 'Past 7 days · max heart rate ${maxHr.round()} bpm',
              style: context.footnote.copyWith(color: context.secondaryLabel),
            ),
            const SizedBox(height: 12),
            if (days.isEmpty)
              Text(
                'Zones appear when heart rate readings come in from your '
                'watch through Health Connect.',
                style: context.subheadline.copyWith(
                  color: context.secondaryLabel,
                ),
              )
            else
              for (final (i, z) in HeartZone.values.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            z.label,
                            style: context.subheadline.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.resolve(_colors[i]),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${z.effort} · ${z.range(maxHr)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.footnote.copyWith(
                                color: context.secondaryLabel,
                              ),
                            ),
                          ),
                          Text(
                            formatMinutes(
                              Duration(minutes: zones.minutes[z]!.round()),
                            ),
                            style: context.subheadline,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TweenAnimationBuilder<double>(
                        tween: Tween(
                          end: most > 0 ? zones.minutes[z]! / most : 0,
                        ),
                        duration: reduce ? Duration.zero : Motion.slow,
                        curve: Motion.curve,
                        builder: (context, v, _) => CapsuleProgress(
                          value: v,
                          color: context.resolve(_colors[i]),
                          height: 8,
                        ),
                      ),
                    ],
                  ),
                ),
            Text(
              age == null
                  ? 'Zones use 220 minus your age. Add your birthday in Health '
                        'Details to personalise them.'
                  : 'Zones use 220 minus your age.',
              style: context.caption1.copyWith(color: context.tertiaryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
