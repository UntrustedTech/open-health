import 'package:flutter/foundation.dart';

import 'package:health_app/models/metric_type.dart';
import 'package:health_app/sync/health_sample.dart';

/// Average, lowest and highest of some heart rate readings.
@immutable
class HeartStats {
  const HeartStats({
    required this.count,
    required this.average,
    required this.lowest,
    required this.highest,
  });

  final int count;
  final double average;
  final HealthSample lowest;
  final HealthSample highest;

  /// Null when there are no readings.
  static HeartStats? of(List<HealthSample> readings) {
    if (readings.isEmpty) return null;
    var lowest = readings.first, highest = readings.first;
    var sum = 0.0;
    for (final r in readings) {
      sum += r.value;
      if (r.value < lowest.value) lowest = r;
      if (r.value > highest.value) highest = r;
    }
    return HeartStats(
      count: readings.length,
      average: sum / readings.length,
      lowest: lowest,
      highest: highest,
    );
  }
}

enum MomentKind { workout, sleep }

/// A workout or a sleep, with the heart rate measured during it.
@immutable
class HeartMoment {
  const HeartMoment({
    required this.label,
    required this.kind,
    required this.start,
    required this.end,
    required this.stats,
  });

  final String label;
  final MomentKind kind;
  final DateTime start;
  final DateTime end;

  /// Null when nothing was recorded during it (e.g. watch off).
  final HeartStats? stats;

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);
}

/// One day's heart rate readings, linked to the workouts and sleep in it.
@immutable
class HeartDay {
  const HeartDay({
    required this.readings,
    required this.moments,
    required this.all,
    required this.rest,
  });

  /// Every plausible reading, oldest first.
  final List<HealthSample> readings;

  /// Oldest first.
  final List<HeartMoment> moments;
  final HeartStats? all;

  /// Readings outside every workout and sleep.
  final HeartStats? rest;

  /// Each hour of [day] from midnight (24 of them): its readings' stats,
  /// null where there were none.
  List<HeartStats?> hourly(DateTime day) {
    final hours = List.generate(24, (_) => <HealthSample>[]);
    for (final r in readings) {
      final t = r.start;
      if (t.year == day.year && t.month == day.month && t.day == day.day) {
        hours[t.hour].add(r);
      }
    }
    return [for (final h in hours) HeartStats.of(h)];
  }

  /// Sleep that reaches into the day starting at [from], one stretch per
  /// sleep: sessions less than [gap] apart (a night split in two) are joined.
  static List<({DateTime start, DateTime end})> sleepFor(
    Iterable<({DateTime start, DateTime end})> sessions,
    DateTime from, {
    Duration gap = const Duration(minutes: 30),
  }) {
    final sorted = [
      for (final s in sessions)
        if (s.end.isAfter(from)) s,
    ]..sort((a, b) => a.start.compareTo(b.start));
    final out = <({DateTime start, DateTime end})>[];
    for (final s in sorted) {
      final last = out.lastOrNull;
      if (last != null && !s.start.isAfter(last.end.add(gap))) {
        out.last = (
          start: last.start,
          end: s.end.isAfter(last.end) ? s.end : last.end,
        );
      } else {
        out.add(s);
      }
    }
    return out;
  }

  static HeartDay of(
    Iterable<HealthSample> samples, {
    List<({String label, DateTime start, DateTime end})> workouts = const [],
    List<({DateTime start, DateTime end})> sleep = const [],
  }) {
    const hr = MetricType.heartRate;
    final readings =
        samples
            .where((s) => s.value.isFinite && s.value >= hr.min)
            .where((s) => s.value <= hr.max)
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    HeartMoment moment(String label, MomentKind kind, DateTime s, DateTime e) {
      final inside = [
        for (final r in readings)
          if (!r.start.isBefore(s) && r.start.isBefore(e)) r,
      ];
      return HeartMoment(
        label: label,
        kind: kind,
        start: s,
        end: e,
        stats: HeartStats.of(inside),
      );
    }

    final moments = [
      for (final w in workouts)
        moment(w.label, MomentKind.workout, w.start, w.end),
      for (final s in sleep) moment('Asleep', MomentKind.sleep, s.start, s.end),
    ]..sort((a, b) => a.start.compareTo(b.start));
    return HeartDay(
      readings: readings,
      moments: moments,
      all: HeartStats.of(readings),
      rest: HeartStats.of([
        for (final r in readings)
          if (!moments.any((m) => m.contains(r.start))) r,
      ]),
    );
  }
}
