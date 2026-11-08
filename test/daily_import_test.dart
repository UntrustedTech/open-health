import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/models/health_entry.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/sync/daily_import.dart';
import 'package:health_app/sync/health_sample.dart';

HealthSample _s(
  MetricType type,
  double value,
  DateTime start, [
  DateTime? end,
]) => HealthSample(type: type, value: value, start: start, end: end ?? start);

void main() {
  group('toDailyEntries', () {
    test('sums summed metrics per local day', () {
      final entries = toDailyEntries([
        _s(MetricType.steps, 1000, DateTime(2026, 10, 10, 9)),
        _s(MetricType.steps, 2500, DateTime(2026, 10, 10, 18)),
        _s(MetricType.steps, 400, DateTime(2026, 10, 11, 8)),
      ]);

      final byDay = {for (final e in entries) e.date.day: e.value};
      expect(byDay, {10: 3500, 11: 400});
    });

    test('averages averaged metrics per day', () {
      final entries = toDailyEntries([
        _s(MetricType.heartRate, 60, DateTime(2026, 10, 11, 8)),
        _s(MetricType.heartRate, 90, DateTime(2026, 10, 11, 12)),
      ]);

      expect(entries.single.value, 75);
    });

    test('keeps the most recent value for latest metrics', () {
      final entries = toDailyEntries([
        _s(MetricType.weight, 79, DateTime(2026, 10, 11, 20)),
        _s(MetricType.weight, 80, DateTime(2026, 10, 11, 7)),
      ]);

      expect(entries.single.value, 79);
    });

    test('attributes sleep to the day you woke up', () {
      final entries = toDailyEntries([
        _s(
          MetricType.sleep,
          7.5,
          DateTime(2026, 10, 10, 23),
          DateTime(2026, 10, 11, 6, 30),
        ),
      ]);

      expect(entries.single.date.day, 11);
      expect(entries.single.value, 7.5);
    });

    test('merges overlapping sessions from different apps', () {
      // Two apps recorded the same night; one also logged a short nap.
      final entries = toDailyEntries([
        _s(
          MetricType.sleep,
          8,
          DateTime(2026, 10, 10, 23),
          DateTime(2026, 10, 11, 7),
        ),
        _s(
          MetricType.sleep,
          7,
          DateTime(2026, 10, 10, 23, 30),
          DateTime(2026, 10, 11, 6, 30),
        ),
        _s(
          MetricType.sleep,
          0.5,
          DateTime(2026, 10, 11, 14),
          DateTime(2026, 10, 11, 14, 30),
        ),
        _s(
          MetricType.exerciseMinutes,
          30,
          DateTime(2026, 10, 11, 9),
          DateTime(2026, 10, 11, 9, 30),
        ),
        _s(
          MetricType.exerciseMinutes,
          30,
          DateTime(2026, 10, 11, 9, 15),
          DateTime(2026, 10, 11, 9, 45),
        ),
      ]);

      final sleep = entries.firstWhere((e) => e.type == MetricType.sleep);
      final exercise = entries.firstWhere(
        (e) => e.type == MetricType.exerciseMinutes,
      );
      expect(sleep.value, 8.5);
      expect(exercise.value, 45);
    });

    test('keeps the reading time for latest metrics', () {
      final entries = toDailyEntries([
        _s(MetricType.weight, 79, DateTime(2026, 10, 11, 7, 15)),
      ]);

      expect(entries.single.date, DateTime(2026, 10, 11, 7, 15));
    });

    test('creates one stable, marked entry per metric and day', () {
      final first = toDailyEntries([
        _s(MetricType.water, 250, DateTime(2026, 10, 11, 9)),
        _s(MetricType.steps, 100, DateTime(2026, 10, 11, 9)),
      ]);
      final again = toDailyEntries([
        _s(MetricType.water, 500, DateTime(2026, 10, 11, 10)),
      ]);

      expect(first, hasLength(2));
      expect(first.every((e) => e.source == EntrySource.healthConnect), isTrue);
      final water = first.firstWhere((e) => e.type == MetricType.water);
      expect(water.id, 'hc:water:2026-10-11');
      expect(again.single.id, water.id);
    });

    test('skips values outside the metric range', () {
      final entries = toDailyEntries([
        _s(MetricType.heartRate, 0, DateTime(2026, 10, 11, 9)),
        _s(MetricType.heartRate, 70, DateTime(2026, 10, 11, 10)),
        _s(MetricType.bloodOxygen, 140, DateTime(2026, 10, 11, 10)),
      ]);

      expect(entries.single.type, MetricType.heartRate);
      expect(entries.single.value, 70);
    });

    test('rounds values to the metric precision', () {
      final entries = toDailyEntries([
        _s(MetricType.distance, 1.23456, DateTime(2026, 10, 11, 9)),
      ]);

      expect(entries.single.value, 1.23);
    });
  });

  group('HealthEntry source', () {
    test('round-trips through JSON', () {
      final entry = HealthEntry(
        id: 'hc:steps:2026-10-11',
        type: MetricType.steps,
        value: 10,
        date: DateTime(2026, 10, 11, 12),
        source: EntrySource.healthConnect,
      );

      final back = HealthEntry.tryFromJson(entry.toJson())!;

      expect(back.source, EntrySource.healthConnect);
      expect(back.isSample, isFalse);
    });

    test('reads the legacy sample flag', () {
      final entry = HealthEntry.tryFromJson({
        'id': 'a',
        'type': 'steps',
        'value': 1,
        'date': '2026-10-11T10:00:00.000',
        'sample': true,
      })!;

      expect(entry.source, EntrySource.sample);
      expect(entry.isSample, isTrue);
    });
  });
}
