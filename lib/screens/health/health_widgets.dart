import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/insights/health_snapshot.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/screens/metric_detail_screen.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/widgets/progress_ring.dart';

String _amount(MetricType type, double v) =>
    '${formatValue(type, v)} ${unitLabel(type)}'.trim();

/// "Vitals": the resting heart rate, how many readings are in a healthy
/// range, and the latest HRV, blood oxygen and sleep in a quiet row.
class VitalsHero extends StatelessWidget {
  const VitalsHero({super.key});

  static Color _standing(Standing s) => switch (s) {
    Standing.good => Palette.green,
    Standing.fair => Palette.yellow,
    Standing.attention => Palette.orange,
    Standing.info => Palette.grey,
  };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final rhr = store.latestReading(MetricType.restingHeartRate)?.value;
    final stats = HealthSnapshot.build(
      dailyValue: store.dailyValue,
      today: store.today,
      weightKg: store.latestReading(MetricType.weight)?.value,
      heightCm: store.profile.heightCm,
      age: store.profile.ageOn(store.today),
    );
    final rated = stats.where((s) => s.standing != Standing.info).toList();
    final good = rated.where((s) => s.standing == Standing.good).length;
    final chips = [
      (MetricType.hrv, 'HRV', Icons.graphic_eq_rounded, Palette.teal),
      (MetricType.bloodOxygen, 'SpO₂', Icons.air_rounded, Palette.cyan),
      (MetricType.sleep, 'Sleep', Icons.bedtime_rounded, Palette.indigo),
    ];
    final heart = context.resolve(Palette.red);
    final rangeColor = context.resolve(
      good == rated.length
          ? Palette.green
          : good == 0
          ? Palette.orange
          : Palette.yellow,
    );
    return Semantics(
      container: true,
      label: [
        'Your vitals',
        if (rhr != null) 'resting heart rate ${rhr.round()} beats a minute',
        if (rated.isNotEmpty) '$good of ${rated.length} in a healthy range',
      ].join(', '),
      child: IosCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        tint: Palette.red,
        onTap: () =>
            MetricDetailScreen.open(context, MetricType.restingHeartRate),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(heart, const Color(0xFFFFFFFF), 0.2)!,
                        heart,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: heart.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFFFFFFFF),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RESTING HEART RATE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.overline.copyWith(
                          color: context.secondaryLabel,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              rhr == null ? '--' : '${rhr.round()}',
                              style: context.number(
                                40,
                                weight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'bpm',
                              style: context.subheadline.copyWith(
                                color: context.secondaryLabel,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (rated.isNotEmpty)
                  ProgressRing(
                    progress: good / rated.length,
                    color: rangeColor,
                    size: 72,
                    stroke: 6,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$good/${rated.length}',
                          style: context.number(14, weight: FontWeight.w800),
                        ),
                        Text(
                          'in range',
                          style: context.caption2.copyWith(
                            color: context.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final (i, (type, label, icon, color))
                    in chips.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _VitalStat(
                      type: type,
                      label: label,
                      icon: icon,
                      color: context.resolve(color),
                      dot: switch (stats
                          .where((s) => s.metric == type)
                          .firstOrNull) {
                        final s? => context.resolve(_standing(s.standing)),
                        null => null,
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// One vital in a small tinted tile: icon, label, latest value and a dot
/// for whether it's in a healthy range. Opens its detail.
class _VitalStat extends StatelessWidget {
  const _VitalStat({
    required this.type,
    required this.label,
    required this.icon,
    required this.color,
    this.dot,
  });

  final MetricType type;
  final String label;
  final IconData icon;
  final Color color;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final r = store.latestReading(type);
    return Pressable(
      onTap: () => MetricDetailScreen.open(context, type),
      scale: 0.95,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: ShapeDecoration(
          color: color.withValues(alpha: context.isDark ? 0.12 : 0.08),
          shape: AppTheme.squircle(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 5),
                Flexible(
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
                if (dot case final d?) ...[
                  const SizedBox(width: 5),
                  _Dot(color: d),
                ],
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                r == null ? '--' : _amount(type, r.value),
                style: context.number(16, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
