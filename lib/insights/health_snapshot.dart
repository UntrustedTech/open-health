import 'package:health_app/models/metric_type.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/utils/units.dart';

/// How a stat compares with general guidelines.
enum Standing {
  good('Healthy'),
  fair('Fair'),
  attention('Check'),
  info('');

  const Standing(this.label);

  final String label;
}

/// One stat of the [HealthSnapshot].
class SnapshotStat {
  const SnapshotStat({
    required this.title,
    required this.value,
    required this.unit,
    required this.standing,
    required this.note,
    required this.metric,
  });

  final String title;

  /// The number, formatted.
  final String value;
  final String unit;
  final Standing standing;

  /// The guideline it's compared with, in a few words.
  final String note;

  /// Where tapping the stat leads.
  final MetricType metric;
}

/// Key health numbers over the last week compared with widely used
/// guidelines (WHO, CDC, AHA, the National Sleep Foundation). A general
/// guide only, not a diagnosis.
abstract final class HealthSnapshot {
  /// Days averaged.
  static const days = 7;

  /// Days with data needed for an average.
  static const minDays = 3;

  /// Weekly moderate activity recommended by the WHO, in minutes.
  static const weeklyActiveMinutes = 150.0;

  /// The stats that have enough data, most important first.
  static List<SnapshotStat> build({
    required double? Function(MetricType type, DateTime day) dailyValue,
    required DateTime today,
    required double? weightKg,
    required double? heightCm,
    int? age,
  }) {
    // Complete days, except sleep, where today's value is last night.
    double? average(MetricType type) {
      final first = type == MetricType.sleep ? 0 : 1;
      final values = [
        for (var i = first; i < first + days; i++)
          ?dailyValue(type, DateTime(today.year, today.month, today.day - i)),
      ].where((v) => v > 0).toList();
      if (values.length < minDays) return null;
      return values.reduce((a, b) => a + b) / values.length;
    }

    // The last 7 complete days; null when none of them has data.
    double? weekTotal(MetricType type) {
      final values = [
        for (var i = 1; i <= days; i++)
          ?dailyValue(type, DateTime(today.year, today.month, today.day - i)),
      ];
      return values.isEmpty ? null : values.fold<double>(0, (a, b) => a + b);
    }

    final stats = <SnapshotStat>[];
    // Adult BMI ranges don't apply to children and teens.
    final adult = age == null || age >= 18;
    if (bmi(weightKg, heightCm) case final b? when adult) {
      stats.add(
        SnapshotStat(
          title: 'BMI',
          value: b.toStringAsFixed(1),
          unit: '',
          standing: switch (b) {
            < 18.5 => Standing.fair,
            < 25 => Standing.good,
            < 30 => Standing.fair,
            _ => Standing.attention,
          },
          note: switch (b) {
            < 18.5 => 'Below 18.5–24.9',
            < 25 => 'Within 18.5–24.9',
            _ => 'Above 18.5–24.9',
          },
          metric: MetricType.weight,
        ),
      );
    }
    if (average(MetricType.restingHeartRate) case final hr?) {
      stats.add(
        SnapshotStat(
          title: 'Resting HR',
          value: hr.round().toString(),
          unit: 'bpm',
          standing: switch (hr) {
            < 40 => Standing.fair,
            <= 80 => Standing.good,
            <= 100 => Standing.fair,
            _ => Standing.attention,
          },
          note: 'Typical 60–100',
          metric: MetricType.restingHeartRate,
        ),
      );
    }
    if (average(MetricType.sleep) case final h?) {
      stats.add(
        SnapshotStat(
          title: 'Sleep',
          value: h.toStringAsFixed(1),
          unit: 'hr',
          standing: switch (h) {
            >= 7 && <= 9 => Standing.good,
            >= 6 && < 7 || > 9 && <= 10 => Standing.fair,
            _ => Standing.attention,
          },
          note: 'Adults: 7–9 hr',
          metric: MetricType.sleep,
        ),
      );
    }
    if (average(MetricType.steps) case final s?) {
      stats.add(
        SnapshotStat(
          title: 'Steps',
          value: s.round().toString(),
          unit: 'a day',
          standing: switch (s) {
            >= 7500 => Standing.good,
            >= 5000 => Standing.fair,
            _ => Standing.attention,
          },
          note: 'Active: 7,500+',
          metric: MetricType.steps,
        ),
      );
    }
    if (weekTotal(MetricType.exerciseMinutes) case final active?) {
      stats.add(
        SnapshotStat(
          title: 'Active Minutes',
          value: active.round().toString(),
          unit: 'last 7 days',
          standing: active >= weeklyActiveMinutes
              ? Standing.good
              : active >= weeklyActiveMinutes / 2
              ? Standing.fair
              : Standing.attention,
          note: 'WHO: 150+',
          metric: MetricType.exerciseMinutes,
        ),
      );
    }
    if (average(MetricType.bloodOxygen) case final o?) {
      stats.add(
        SnapshotStat(
          title: 'Blood Oxygen',
          value: o.round().toString(),
          unit: '%',
          standing: switch (o) {
            >= 95 => Standing.good,
            >= 90 => Standing.fair,
            _ => Standing.attention,
          },
          note: 'Typical 95–100%',
          metric: MetricType.bloodOxygen,
        ),
      );
    }
    final sys = average(MetricType.bloodPressureSystolic);
    final dia = average(MetricType.bloodPressureDiastolic);
    if (sys != null && dia != null) {
      stats.add(
        SnapshotStat(
          title: 'Blood Pressure',
          value: '${sys.round()}/${dia.round()}',
          unit: 'mmHg',
          standing: bloodPressureStanding(sys, dia),
          note: 'Normal under 120/80',
          metric: MetricType.bloodPressureSystolic,
        ),
      );
    }
    if (average(MetricType.bloodGlucose) case final g?) {
      stats.add(
        SnapshotStat(
          title: 'Blood Glucose',
          value: formatValue(MetricType.bloodGlucose, g),
          unit: Units.glucoseUnit,
          standing: glucoseStanding(g),
          note: Units.imperial ? 'Typical 70–140' : 'Typical 3.9–7.8',
          metric: MetricType.bloodGlucose,
        ),
      );
    }
    return stats;
  }

  /// American Heart Association categories: normal under 120/80,
  /// elevated 120–129 over under 80, high from 130 or 80.
  static Standing bloodPressureStanding(double systolic, double diastolic) {
    if (systolic >= 140 || diastolic >= 90 || systolic < 90) {
      return Standing.attention;
    }
    if (systolic >= 120 || diastolic >= 80) return Standing.fair;
    return Standing.good;
  }

  /// A general guide for readings at any time of day (mg/dL): 70–140 is
  /// typical; low or high readings deserve attention.
  static Standing glucoseStanding(double mgDl) => switch (mgDl) {
    < 54 || >= 250 => Standing.attention,
    < 70 || > 140 => Standing.fair,
    _ => Standing.good,
  };

  /// Body mass index, or null without both measurements.
  static double? bmi(double? weightKg, double? heightCm) {
    if (weightKg == null || heightCm == null || heightCm < 50) return null;
    final m = heightCm / 100;
    return weightKg / (m * m);
  }
}

/// Progress toward a target weight.
abstract final class WeightProgress {
  /// Days of weigh-ins used for the trend.
  static const trendDays = 28;

  /// A trend needs this many weigh-ins spread over at least a week.
  static const minPoints = 3;
  static const minSpanDays = 7;

  /// Change in kg a week from the weigh-ins of the last [trendDays] (least
  /// squares), or null with too few.
  static double? weeklyTrend(
    Iterable<(DateTime, double)> weighIns,
    DateTime today,
  ) {
    final from = DateTime(today.year, today.month, today.day - trendDays);
    final points = [
      for (final (d, kg) in weighIns)
        if (!d.isBefore(from)) (d.difference(from).inHours / 24, kg),
    ];
    if (points.length < minPoints) return null;
    final xs = points.map((p) => p.$1);
    final span =
        xs.reduce((a, b) => a > b ? a : b) - xs.reduce((a, b) => a < b ? a : b);
    if (span < minSpanDays) return null;
    final n = points.length;
    final mx = xs.reduce((a, b) => a + b) / n;
    final my = points.map((p) => p.$2).reduce((a, b) => a + b) / n;
    var num = 0.0, den = 0.0;
    for (final (x, y) in points) {
      num += (x - mx) * (y - my);
      den += (x - mx) * (x - mx);
    }
    if (den == 0) return null;
    return num / den * 7;
  }

  /// Share of the way from [startKg] to [targetKg], 0..1.
  static double fraction(double startKg, double currentKg, double targetKg) {
    final total = targetKg - startKg;
    if (total.abs() < 0.05) return 1;
    return ((currentKg - startKg) / total).clamp(0.0, 1.0);
  }
}
