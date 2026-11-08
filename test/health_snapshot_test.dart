import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/insights/health_snapshot.dart';
import 'package:health_app/models/metric_type.dart';

final _today = DateTime(2026, 10, 12);

double? Function(MetricType, DateTime) _week(Map<MetricType, double> v) =>
    (type, day) => _today.difference(day).inDays <= 7 ? v[type] : null;

void main() {
  group('HealthSnapshot', () {
    test('compares each stat with its guideline', () {
      final stats = HealthSnapshot.build(
        dailyValue: _week({
          MetricType.restingHeartRate: 58,
          MetricType.sleep: 6.5,
          MetricType.steps: 4000,
          MetricType.exerciseMinutes: 30,
          MetricType.bloodOxygen: 97,
        }),
        today: _today,
        weightKg: 80,
        heightCm: 180,
      );
      final by = {for (final s in stats) s.title: s};
      expect(by['BMI']!.value, '24.7');
      expect(by['BMI']!.standing, Standing.good);
      expect(by['Resting HR']!.standing, Standing.good);
      expect(by['Sleep']!.standing, Standing.fair);
      expect(by['Steps']!.standing, Standing.attention);
      // 7 days × 30 min = 210 ≥ 150.
      expect(by['Active Minutes']!.value, '210');
      expect(by['Active Minutes']!.standing, Standing.good);
      expect(by['Blood Oxygen']!.standing, Standing.good);
    });

    test('no exercise data means no Active Minutes; under-18s get no BMI', () {
      final stats = HealthSnapshot.build(
        dailyValue: _week({MetricType.steps: 9000}),
        today: _today,
        weightKg: 60,
        heightCm: 165,
        age: 15,
      );
      final titles = [for (final s in stats) s.title];
      expect(titles, isNot(contains('Active Minutes')));
      expect(titles, isNot(contains('BMI')));
      expect(titles, contains('Steps'));
    });

    test('stats without enough days are left out', () {
      final stats = HealthSnapshot.build(
        dailyValue: (type, day) =>
            type == MetricType.steps && day == _today ? 9000 : null,
        today: _today,
        weightKg: null,
        heightCm: 180,
      );
      expect(stats, isEmpty);
    });

    test('BMI bands', () {
      expect(HealthSnapshot.bmi(null, 180), isNull);
      expect(HealthSnapshot.bmi(100, 180), closeTo(30.9, 0.1));
    });
  });

  group('WeightProgress', () {
    test('trend is the weekly slope of recent weigh-ins', () {
      final trend = WeightProgress.weeklyTrend([
        for (var i = 0; i <= 21; i += 7)
          (DateTime(2026, 10, 12 - i), 80 + i / 7 * 0.5),
      ], _today);
      expect(trend, closeTo(-0.5, 0.001));
    });

    test('too few or too close weigh-ins give no trend', () {
      expect(
        WeightProgress.weeklyTrend([
          (DateTime(2026, 10, 12), 80),
          (DateTime(2026, 10, 11), 81),
        ], _today),
        isNull,
      );
      expect(
        WeightProgress.weeklyTrend([
          for (var i = 0; i < 4; i++) (DateTime(2026, 10, 12 - i), 80),
        ], _today),
        isNull,
      );
    });

    test('progress runs from start to target', () {
      expect(WeightProgress.fraction(85, 80, 75), 0.5);
      expect(WeightProgress.fraction(85, 90, 75), 0);
      expect(WeightProgress.fraction(70, 73, 76), 0.5);
    });
  });
}
