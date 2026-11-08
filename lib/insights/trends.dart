import 'package:flutter/foundation.dart';

import 'package:health_app/models/metric_type.dart';

enum Trend { up, down, steady }

/// A long-term change, like Apple Health Trends: the last 90 days compared
/// with the year before them.
@immutable
class LongTrend {
  const LongTrend({
    required this.type,
    required this.recent,
    required this.baseline,
    required this.trend,
  });

  final MetricType type;

  /// Average per day with data over the last [recentDays] days.
  final double recent;

  /// Average per day with data over the [baselineDays] days before that.
  final double baseline;
  final Trend trend;

  double get change => baseline == 0 ? 0 : (recent - baseline) / baseline;

  /// Whether the change is good news (null when neither, like weight).
  bool? get isGood => switch (trend) {
    Trend.steady => null,
    _ => switch (_better[type]) {
      null => null,
      final up => (trend == Trend.up) == up,
    },
  };
}

const recentDays = 90;
const baselineDays = 275;

/// Changes smaller than this read as steady.
const _steadyBelow = 0.03;

/// Days with data needed in each period.
const _minRecent = 20;
const _minBaseline = 21;

/// true: higher is better; false: lower is better; missing: neither.
const _better = {
  MetricType.steps: true,
  MetricType.distance: true,
  MetricType.activeEnergy: true,
  MetricType.exerciseMinutes: true,
  MetricType.restingHeartRate: false,
  MetricType.hrv: true,
  MetricType.bloodOxygen: true,
  MetricType.bloodPressureSystolic: false,
  MetricType.bloodPressureDiastolic: false,
  MetricType.sleep: true,
  MetricType.sleepDeep: true,
  MetricType.sleepRem: true,
  MetricType.sleepAwake: false,
  MetricType.water: true,
  MetricType.mindfulMinutes: true,
};

/// Every metric with enough history, biggest changes first; steady ones
/// last.
List<LongTrend> buildTrends({
  required double? Function(MetricType type, DateTime day) dailyValue,
  required DateTime today,
}) {
  double? average(MetricType type, int from, int days) {
    final values = [
      for (var i = from; i < from + days; i++)
        dailyValue(type, DateTime(today.year, today.month, today.day - i)),
    ].nonNulls.toList();
    final needed = days == recentDays ? _minRecent : _minBaseline;
    if (values.length < needed) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  final out = <LongTrend>[];
  for (final type in MetricType.values) {
    // Today isn't over yet.
    final recent = average(type, 1, recentDays);
    final baseline = average(type, 1 + recentDays, baselineDays);
    if (recent == null || baseline == null || baseline == 0) continue;
    final change = (recent - baseline) / baseline;
    out.add(
      LongTrend(
        type: type,
        recent: recent,
        baseline: baseline,
        trend: change.abs() < _steadyBelow
            ? Trend.steady
            : change > 0
            ? Trend.up
            : Trend.down,
      ),
    );
  }
  int rank(LongTrend t) => t.trend == Trend.steady ? 1 : 0;
  out.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    return r != 0 ? r : b.change.abs().compareTo(a.change.abs());
  });
  return out;
}
