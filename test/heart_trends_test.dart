import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/insights/heart_trends.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/sync/health_sample.dart';

HealthSample _hr(int hour, int minute, double bpm) {
  final t = DateTime(2026, 11, 1, hour, minute);
  return HealthSample(type: MetricType.heartRate, value: bpm, start: t, end: t);
}

void main() {
  test('links readings to the run and the night, the rest counted apart', () {
    final day = HeartDay.of(
      [
        _hr(3, 0, 52),
        _hr(5, 0, 48),
        _hr(7, 30, 150),
        _hr(7, 45, 170),
        _hr(12, 0, 80),
        _hr(13, 0, 0), // broken reading
      ],
      workouts: [
        (
          label: 'Run',
          start: DateTime(2026, 11, 1, 7, 15),
          end: DateTime(2026, 11, 1, 8),
        ),
        (
          label: 'Swim',
          start: DateTime(2026, 11, 1, 18),
          end: DateTime(2026, 11, 1, 19),
        ),
      ],
      sleep: [
        (start: DateTime(2026, 10, 31, 23), end: DateTime(2026, 11, 1, 6)),
      ],
    );

    expect(day.readings, hasLength(5));
    expect(day.moments.map((m) => m.label), ['Asleep', 'Run', 'Swim']);
    final sleep = day.moments[0].stats!;
    expect(sleep.average, 50);
    expect(sleep.lowest.value, 48);
    final run = day.moments[1].stats!;
    expect(run.highest.value, 170);
    expect(run.highest.start, DateTime(2026, 11, 1, 7, 45));
    expect(day.moments[2].stats, isNull);
    expect(day.rest!.count, 1);
    expect(day.rest!.average, 80);
    expect(day.all!.highest.value, 170);
  });

  test('no readings: no stats', () {
    final day = HeartDay.of(const []);
    expect(day.all, isNull);
    expect(day.rest, isNull);
    expect(day.moments, isEmpty);
  });

  test('hourly groups readings by hour of that day only', () {
    final late = DateTime(2026, 11, 2, 0, 5);
    final day = HeartDay.of([
      _hr(7, 10, 60),
      _hr(7, 50, 80),
      _hr(9, 0, 70),
      HealthSample(
        type: MetricType.heartRate,
        value: 90,
        start: late,
        end: late,
      ),
    ]);

    final hours = day.hourly(DateTime(2026, 11, 1));

    expect(hours, hasLength(24));
    expect(hours[7]!.average, 70);
    expect(hours[7]!.lowest.value, 60);
    expect(hours[9]!.count, 1);
    expect(hours[0], isNull); // the next day's reading is left out
    expect(hours.nonNulls, hasLength(2));
  });

  test(
    'a night split in two is one sleep; sleep that ended yesterday is gone',
    () {
      final day = DateTime(2026, 11, 6);
      DateTime at(int h, [int m = 0]) => DateTime(2026, 11, 5, h, m);
      final sleep = HeartDay.sleepFor([
        (start: at(26), end: at(29, 50)), // 2:00–5:50 AM
        (start: at(23, 10), end: at(25, 40)), // 11:10 PM–1:40 AM
        (start: at(14), end: at(15)), // yesterday's nap
      ], day);
      expect(sleep, [(start: at(23, 10), end: at(29, 50))]);
    },
  );
}
