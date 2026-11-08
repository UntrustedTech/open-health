import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/insights/readiness.dart';
import 'package:health_app/models/metric_type.dart';

void main() {
  final today = DateTime(2026, 10, 15);

  /// [normal] on each of the 30 days before today, [now] today.
  double? Function(MetricType, DateTime) data(
    Map<MetricType, (double normal, double? now)> values,
  ) => (type, day) {
    final v = values[type];
    if (v == null) return null;
    return day == today ? v.$2 : v.$1;
  };

  test('needs at least two signals', () {
    final r = Readiness.compute(
      dailyValue: data({MetricType.sleep: (8, 8)}),
      today: today,
    );
    expect(r, isNull);
  });

  test('values at the personal normal and a full night are Ready', () {
    final r = Readiness.compute(
      dailyValue: data({
        MetricType.hrv: (50, 50),
        MetricType.restingHeartRate: (60, 60),
        MetricType.sleep: (8, 8),
      }),
      today: today,
    )!;
    // 0.4·70 + 0.3·70 + 0.3·100 = 79.
    expect(r.score, 79);
    expect(r.level, ReadinessLevel.ready);
    expect(r.signals[ReadinessSignal.hrv]!.detail, 'Right at your normal');
  });

  test('high HRV and a low resting heart rate raise the score', () {
    final r = Readiness.compute(
      dailyValue: data({
        MetricType.hrv: (50, 60),
        MetricType.restingHeartRate: (60, 56),
      }),
      today: today,
    )!;
    // HRV +20% → 100; RHR 4 below → 94. (0.4·100 + 0.3·94) / 0.7 = 97.
    expect(r.score, 97);
    expect(r.signals[ReadinessSignal.hrv]!.detail, '20% above your normal');
    expect(
      r.signals[ReadinessSignal.restingHeart]!.detail,
      '4 bpm below your normal',
    );
  });

  test('poor recovery and a short night mean Rest', () {
    final r = Readiness.compute(
      dailyValue: data({
        MetricType.hrv: (50, 35),
        MetricType.restingHeartRate: (60, 67),
        MetricType.sleep: (8, 5),
      }),
      today: today,
    )!;
    expect(r.level, ReadinessLevel.rest);
    expect(r.signals[ReadinessSignal.sleep]!.detail, '5h 00m of your 8h goal');
  });

  test('a baseline needs a week of readings', () {
    double? few(MetricType type, DateTime day) {
      if (type == MetricType.sleep) return 8;
      final ago = today.difference(day).inDays;
      return ago <= 3 ? 50 : null;
    }

    expect(Readiness.baseline(few, MetricType.hrv, today), isNull);
    expect(Readiness.compute(dailyValue: few, today: today), isNull);
  });

  test('before a score, progress counts the days of resting heart rate', () {
    final today = DateTime(2026, 11, 6);
    double? value(MetricType t, DateTime d) =>
        t == MetricType.restingHeartRate && today.difference(d).inDays <= 3
        ? 60
        : null;
    expect(Readiness.baselineProgress(value, today), closeTo(3 / 7, 1e-9));
    expect(Readiness.baselineProgress((_, _) => 60, today), 1);
  });
}
