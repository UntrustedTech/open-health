import 'dart:math';

import 'package:health_app/models/health_entry.dart';
import 'package:health_app/models/metric_type.dart';

/// Generates realistic-looking demo data for the last [days] days so the app
/// can be explored before any real data exists. Every entry is flagged
/// [HealthEntry.isSample] so it can be removed later.
List<HealthEntry> generateSampleData({
  required DateTime now,
  int days = 120,
  int seed = 42,
}) {
  final rng = Random(seed);
  final entries = <HealthEntry>[];
  var counter = 0;
  var weight = 74.0 + rng.nextDouble() * 4;

  double jitter(double base, double spread) =>
      base + (rng.nextDouble() * 2 - 1) * spread;

  void add(MetricType type, double value, DateTime date) {
    entries.add(
      HealthEntry(
        id: 'sample-${counter++}',
        type: type,
        value: double.parse(value.toStringAsFixed(type.decimals)),
        date: date,
        source: EntrySource.sample,
      ),
    );
  }

  final today = DateTime(now.year, now.month, now.day);
  for (var i = days - 1; i >= 0; i--) {
    // Calendar arithmetic (not Duration) so DST changes never shift a day.
    final day = DateTime(today.year, today.month, today.day - i);
    // Timestamps on that day, never later than "now" for today's entries.
    DateTime at(int hour, [int minute = 0]) {
      final t = DateTime(day.year, day.month, day.day, hour, minute);
      return t.isAfter(now) ? now : t;
    }

    final isToday = i == 0;
    final weekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    // Today's totals only cover the part of the day that has passed.
    final dayFraction = isToday ? (now.hour + now.minute / 60) / 24 : 1.0;

    final steps =
        max(800.0, jitter(weekend ? 10500 : 8200, 3200)) *
        dayFraction.clamp(0.0, 1.0);
    add(MetricType.steps, steps, at(20));
    add(MetricType.distance, steps * 0.00072, at(20));
    add(MetricType.activeEnergy, steps * 0.045 + jitter(90, 60).abs(), at(20));
    add(
      MetricType.exerciseMinutes,
      max(0, jitter(weekend ? 45 : 28, 22)) * dayFraction,
      at(18),
    );

    for (final hour in [8, 13, 19]) {
      if (isToday && hour > now.hour) continue;
      add(MetricType.heartRate, jitter(76, 12), at(hour));
    }
    add(MetricType.restingHeartRate, jitter(60, 4), at(7));
    add(MetricType.bloodOxygen, jitter(97.5, 1.4).clamp(93, 100), at(3));
    // Every few days, without drawing on the shared random sequence so
    // the rest of the sample data stays the same.
    if (day.day % 3 == 0) {
      add(MetricType.bloodPressureSystolic, 113.0 + day.day * 7 % 10, at(8));
      add(MetricType.bloodPressureDiastolic, 72.0 + day.day * 5 % 8, at(8));
    }
    if (day.day % 4 == 0) {
      add(MetricType.bloodGlucose, 88.0 + day.day * 11 % 20, at(9));
    }

    final slept = jitter(weekend ? 8.1 : 7.1, 0.9).clamp(4.5, 10).toDouble();
    add(MetricType.sleep, slept, at(7));
    // A typical night: ~17% deep, ~22% REM, a few minutes awake.
    final deep = slept * jitter(0.17, 0.03);
    final rem = slept * jitter(0.22, 0.03);
    final awake = slept * jitter(0.06, 0.02);
    add(MetricType.sleepDeep, deep, at(7));
    add(MetricType.sleepRem, rem, at(7));
    add(MetricType.sleepAwake, awake, at(7));
    add(MetricType.sleepCore, slept - deep - rem - awake, at(7));
    add(MetricType.hrv, jitter(weekend ? 52 : 46, 9).clamp(20, 90), at(6));

    if (i % 3 == 0) {
      weight = (weight + jitter(-0.03, 0.35)).clamp(60, 95);
      add(MetricType.weight, weight, at(7, 15));
    }

    final glasses = isToday
        ? (now.hour / 3).floor().clamp(0, 6)
        : 5 + rng.nextInt(5);
    for (var g = 0; g < glasses; g++) {
      add(MetricType.water, 250, at(8 + g * 2));
    }

    if (rng.nextDouble() < 0.55 && !(isToday && now.hour < 21)) {
      add(
        MetricType.mindfulMinutes,
        (5 + rng.nextInt(4) * 5).toDouble(),
        at(21),
      );
    }
  }
  return entries;
}

/// Demo heart rate bands (minutes per 10-bpm band, see HeartBins) for the
/// last [days] days: mostly resting and light, with a workout most days.
Map<DateTime, List<double>> generateSampleHeartBins({
  required DateTime now,
  int days = 120,
  int seed = 7,
}) {
  final rng = Random(seed);
  final today = DateTime(now.year, now.month, now.day);
  return {
    for (var i = days - 1; i >= 0; i--)
      DateTime(today.year, today.month, today.day - i): [
        // 40–219 bpm in 10s: sleep, rest, daily life, then exercise.
        for (final base in const [
          30.0,
          160,
          300,
          260,
          180,
          90,
          40,
          20,
          14,
          10,
          6,
          2,
          0,
          0,
          0,
          0,
          0,
          0,
        ])
          (base *
                  (0.7 + rng.nextDouble() * 0.6) *
                  (i == 0 ? (now.hour + now.minute / 60) / 24 : 1))
              .roundToDouble(),
      ],
  };
}
