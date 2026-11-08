import 'package:intl/intl.dart';

import 'package:health_app/models/health_entry.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/sync/health_sample.dart';

/// Metrics measured as time spans. Overlapping spans (e.g. the same night
/// recorded by a watch and a phone app) are merged so they count once.
const _durationMetrics = {
  MetricType.sleep: Duration(hours: 1),
  MetricType.sleepDeep: Duration(hours: 1),
  MetricType.sleepCore: Duration(hours: 1),
  MetricType.sleepRem: Duration(hours: 1),
  MetricType.sleepAwake: Duration(hours: 1),
  MetricType.exerciseMinutes: Duration(minutes: 1),
};

final _dayId = DateFormat('yyyy-MM-dd');

/// Combines raw samples into one imported entry per metric per local day,
/// using each metric's aggregation. Entries get stable ids so re-importing a
/// day replaces it instead of duplicating it.
List<HealthEntry> toDailyEntries(Iterable<HealthSample> samples) {
  final byType = <MetricType, List<HealthSample>>{};
  for (final s in samples) {
    byType.putIfAbsent(s.type, () => []).add(s);
  }
  return [
    for (final MapEntry(key: type, value: list) in byType.entries)
      ..._entriesFor(type, list),
  ];
}

List<HealthEntry> _entriesFor(MetricType type, List<HealthSample> samples) {
  final unit = _durationMetrics[type];
  final readings = unit == null ? samples : _mergeSpans(type, samples, unit);

  final byDay = <DateTime, List<HealthSample>>{};
  for (final r in readings) {
    if (r.value < type.min || r.value > type.max) continue;
    byDay.putIfAbsent(_dayOf(r), () => []).add(r);
  }

  return [
    for (final MapEntry(key: day, value: list) in byDay.entries)
      if (_combine(type, list) case final value?
          when value >= type.min && value <= type.max)
        HealthEntry(
          id: 'hc:${type.name}:${_dayId.format(day)}',
          type: type,
          value: double.parse(value.toStringAsFixed(type.decimals)),
          date: _timestampFor(type, list),
          source: EntrySource.healthConnect,
        ),
  ];
}

double? _combine(MetricType type, List<HealthSample> list) {
  if (list.isEmpty) return null;
  final total = list.fold<double>(0, (sum, s) => sum + s.value);
  return switch (type.aggregation) {
    Aggregation.sum => total,
    Aggregation.average => total / list.length,
    Aggregation.latest => _latest(list).value,
  };
}

/// Sleep (and its stages) counts toward the day you woke up; everything else the day it began.
DateTime _dayOf(HealthSample s) {
  final t = s.type.isDuration ? s.end : s.start;
  return DateTime(t.year, t.month, t.day);
}

/// Latest metrics keep the real reading time; others use the latest sample.
DateTime _timestampFor(MetricType type, List<HealthSample> list) {
  final latest = _latest(list);
  return type.isDuration ? latest.end : latest.start;
}

HealthSample _latest(List<HealthSample> list) =>
    list.reduce((a, b) => b.start.isAfter(a.start) ? b : a);

/// Merges overlapping or touching spans and recomputes each value from the
/// merged length, expressed in [unit].
List<HealthSample> _mergeSpans(
  MetricType type,
  List<HealthSample> samples,
  Duration unit,
) {
  final sorted = samples.where((s) => s.end.isAfter(s.start)).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  final merged = <({DateTime start, DateTime end})>[];
  for (final s in sorted) {
    final last = merged.lastOrNull;
    if (last != null && !s.start.isAfter(last.end)) {
      if (s.end.isAfter(last.end)) {
        merged[merged.length - 1] = (start: last.start, end: s.end);
      }
    } else {
      merged.add((start: s.start, end: s.end));
    }
  }
  return [
    for (final span in merged)
      HealthSample(
        type: type,
        value: span.end.difference(span.start).inSeconds / unit.inSeconds,
        start: span.start,
        end: span.end,
      ),
  ];
}

/// Readings a day needs before resting heart rate is estimated from it.
const _minRestingSamples = 20;

/// Resting heart rate worked out from a day's heart rate readings, for days
/// whose source records heart rate but not resting heart rate (many
/// watches and phone apps). It's the calm low end of the day: the 10th
/// percentile, which skips the odd low misreading but none of the rest.
List<HealthEntry> restingFromHeartRate(Iterable<HealthSample> samples) {
  final byDay = <DateTime, List<double>>{};
  final latest = <DateTime, DateTime>{};
  for (final s in samples) {
    if (s.type != MetricType.heartRate) continue;
    if (s.value < MetricType.heartRate.min ||
        s.value > MetricType.heartRate.max) {
      continue;
    }
    final day = _dayOf(s);
    byDay.putIfAbsent(day, () => []).add(s.value);
    final at = latest[day];
    if (at == null || s.start.isAfter(at)) latest[day] = s.start;
  }
  return [
    for (final MapEntry(key: day, value: bpm) in byDay.entries)
      if (bpm.length >= _minRestingSamples)
        HealthEntry(
          id: '${HealthEntry.estimatePrefix}restingHeartRate:${_dayId.format(day)}',
          type: MetricType.restingHeartRate,
          value: (bpm..sort())[(bpm.length * 0.1).floor()].roundToDouble(),
          date: latest[day]!,
          note: 'Estimated from your heart rate readings',
          source: EntrySource.healthConnect,
        ),
  ];
}
