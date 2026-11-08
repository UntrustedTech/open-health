import 'dart:math' as math;

import 'package:health_app/models/metric_type.dart';

/// How ready the body is for training today.
enum ReadinessLevel {
  ready('Ready', 'Good day for a hard workout.'),
  steady('Steady', 'A moderate session suits you today.'),
  rest('Rest', 'Take it easy: mobility, a walk or a day off.');

  const ReadinessLevel(this.label, this.advice);

  final String label;
  final String advice;
}

/// One signal behind the [Readiness] score.
enum ReadinessSignal {
  hrv('Heart Rate Variability', 0.4),
  restingHeart('Resting Heart Rate', 0.3),
  sleep('Sleep', 0.3);

  const ReadinessSignal(this.label, this.weight);

  final String label;

  /// Share of the score when every signal has data.
  final double weight;
}

/// A signal's score (0..100) and a plain-language comparison with the
/// user's own normal, e.g. "12% above your normal".
typedef SignalScore = ({double score, String detail});

/// Readiness: this morning's HRV and resting heart rate against the
/// user's own 30-day normal, and last night's sleep against their goal.
/// Signals without data are left out and the rest re-weighted; at least
/// two are needed. A training guide, not medical advice.
class Readiness {
  const Readiness._(this.signals);

  /// Days the personal normal is taken from (today excluded).
  static const baselineDays = 30;

  /// Readings needed before a baseline is trusted.
  static const minBaselineDays = 7;

  /// Signals needed for a score.
  static const minSignals = 2;

  /// Score when a signal matches the personal normal.
  static const neutral = 70.0;

  /// Points per 1% of HRV above (or below) normal.
  static const pointsPerHrvPercent = 1.5;

  /// Points per bpm of resting heart rate below (or above) normal.
  static const pointsPerBpm = 6.0;

  static const readyFrom = 75;
  static const steadyFrom = 55;

  final Map<ReadinessSignal, SignalScore> signals;

  /// Null when fewer than [minSignals] signals have data.
  static Readiness? compute({
    required double? Function(MetricType type, DateTime day) dailyValue,
    required DateTime today,
    double sleepGoalHours = 8,
  }) {
    final signals = <ReadinessSignal, SignalScore>{
      ReadinessSignal.hrv: ?_hrv(dailyValue, today),
      ReadinessSignal.restingHeart: ?_restingHeart(dailyValue, today),
      ReadinessSignal.sleep: ?_sleep(dailyValue, today, sleepGoalHours),
    };
    if (signals.length < minSignals) return null;
    return Readiness._(Map.unmodifiable(signals));
  }

  /// The weighted score, 0..100.
  int get score {
    final weight = signals.keys.fold(0.0, (s, k) => s + k.weight);
    final sum = signals.entries.fold(
      0.0,
      (s, e) => s + e.key.weight * e.value.score,
    );
    return (sum / weight).round().clamp(0, 100);
  }

  ReadinessLevel get level => switch (score) {
    >= readyFrom => ReadinessLevel.ready,
    >= steadyFrom => ReadinessLevel.steady,
    _ => ReadinessLevel.rest,
  };

  /// This morning's reading: today's, else yesterday's (watches often
  /// write overnight values against the previous day).
  static double? _latest(
    double? Function(MetricType, DateTime) value,
    MetricType type,
    DateTime today,
  ) =>
      value(type, today) ??
      value(type, DateTime(today.year, today.month, today.day - 1));

  /// The average of up to [baselineDays] days before today, or null with
  /// fewer than [minBaselineDays] readings.
  static double? baseline(
    double? Function(MetricType, DateTime) value,
    MetricType type,
    DateTime today,
  ) {
    final readings = _readings(value, type, today);
    if (readings.length < minBaselineDays) return null;
    return readings.reduce((a, b) => a + b) / readings.length;
  }

  static List<double> _readings(
    double? Function(MetricType, DateTime) value,
    MetricType type,
    DateTime today,
  ) => [
    for (var i = 1; i <= baselineDays; i++)
      ?value(type, DateTime(today.year, today.month, today.day - i)),
  ];

  /// How far, 0..1, the HRV or resting heart rate normal is towards the
  /// [minBaselineDays] it needs, for showing progress before a score.
  static double baselineProgress(
    double? Function(MetricType, DateTime) value,
    DateTime today,
  ) {
    final days = [
      for (final t in [MetricType.hrv, MetricType.restingHeartRate])
        _readings(value, t, today).length,
    ].reduce((a, b) => a > b ? a : b);
    return (days / minBaselineDays).clamp(0, 1).toDouble();
  }

  static SignalScore? _hrv(
    double? Function(MetricType, DateTime) value,
    DateTime today,
  ) {
    final now = value(MetricType.hrv, today);
    final normal = baseline(value, MetricType.hrv, today);
    if (now == null || normal == null || normal <= 0) return null;
    final pct = (now / normal - 1) * 100;
    return (
      score: (neutral + pct * pointsPerHrvPercent).clamp(0, 100).toDouble(),
      detail: _percentDetail(pct),
    );
  }

  static SignalScore? _restingHeart(
    double? Function(MetricType, DateTime) value,
    DateTime today,
  ) {
    final now = _latest(value, MetricType.restingHeartRate, today);
    final normal = baseline(value, MetricType.restingHeartRate, today);
    if (now == null || normal == null) return null;
    final below = normal - now;
    final bpm = below.abs().round();
    return (
      score: (neutral + below * pointsPerBpm).clamp(0, 100).toDouble(),
      detail: bpm == 0
          ? 'Right at your normal'
          : '$bpm bpm ${below > 0 ? 'below' : 'above'} your normal',
    );
  }

  static SignalScore? _sleep(
    double? Function(MetricType, DateTime) value,
    DateTime today,
    double goal,
  ) {
    final hours = value(MetricType.sleep, today);
    if (hours == null || goal <= 0) return null;
    final share = hours / goal;
    // Full marks at the goal; short nights cost more than long ones gain.
    final score = share >= 1 ? 100.0 : math.max(0.0, 100 - (1 - share) * 160);
    final total = (hours * 60).round();
    final h = total ~/ 60, m = total % 60;
    return (
      score: score,
      detail: '${h}h ${m.toString().padLeft(2, '0')}m of your ${_hours(goal)}',
    );
  }

  static String _hours(double h) =>
      h == h.roundToDouble() ? '${h.round()}h goal' : '${h}h goal';

  static String _percentDetail(double pct) {
    final p = pct.abs().round();
    if (p == 0) return 'Right at your normal';
    return '$p% ${pct > 0 ? 'above' : 'below'} your normal';
  }
}
