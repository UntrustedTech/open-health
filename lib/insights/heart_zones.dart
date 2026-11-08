import 'package:flutter/foundation.dart';

import 'package:health_app/sync/health_sample.dart';

/// Minutes spent in 10-bpm bands from [binLow] bpm, per day. Stored raw so
/// zones can follow the user's max heart rate as it changes with age.
abstract final class HeartBins {
  static const binLow = 40;
  static const binWidth = 10;
  static const count = 18; // 40–219 bpm

  /// A reading stands for the time until the next one, up to this long, so
  /// gaps (watch off) don't count.
  static const maxGap = Duration(minutes: 5);

  static int binOf(double bpm) =>
      ((bpm - binLow) ~/ binWidth).clamp(0, count - 1);

  /// Midpoint of a bin, in bpm.
  static double midOf(int bin) => binLow + binWidth * (bin + 0.5);

  /// Builds per-day bins from heart rate samples, by local day.
  static Map<DateTime, List<double>> fromSamples(
    Iterable<HealthSample> samples,
  ) {
    // A broken reading (NaN, infinite, zero) has no bin and is skipped.
    final sorted =
        samples.where((s) => s.value.isFinite && s.value > 0).toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final out = <DateTime, List<double>>{};
    for (var i = 0; i < sorted.length; i++) {
      final s = sorted[i];
      final next = i + 1 < sorted.length ? sorted[i + 1].start : null;
      var span = next == null
          ? const Duration(minutes: 1)
          : next.difference(s.start);
      if (span > maxGap) span = maxGap;
      if (span <= Duration.zero) continue;
      final day = DateTime(s.start.year, s.start.month, s.start.day);
      final bins = out.putIfAbsent(day, () => List.filled(count, 0));
      bins[binOf(s.value)] += span.inSeconds / 60;
    }
    return out;
  }
}

/// The five training zones, as a share of maximum heart rate.
enum HeartZone {
  z1('Zone 1', 'Very light', 0.50, 0.60),
  z2('Zone 2', 'Light', 0.60, 0.70),
  z3('Zone 3', 'Moderate', 0.70, 0.80),
  z4('Zone 4', 'Hard', 0.80, 0.90),
  z5('Zone 5', 'Maximum', 0.90, 1.01);

  const HeartZone(this.label, this.effort, this.low, this.high);

  final String label;
  final String effort;
  final double low;
  final double high;

  /// "114–133 bpm" for a max heart rate.
  String range(double maxHr) {
    final hi = this == z5 ? maxHr : maxHr * high - 1;
    return '${(maxHr * low).round()}–${hi.round()} bpm';
  }
}

/// Estimated max heart rate: 220 − age, or 190 when the age isn't known.
double maxHeartRate(int? age) =>
    age == null ? 190 : (220 - age).clamp(150, 210).toDouble();

/// Minutes in each zone over some days of [bins]. Time below Zone 1 (rest)
/// isn't counted.
@immutable
class ZoneMinutes {
  const ZoneMinutes(this.minutes);

  final Map<HeartZone, double> minutes;

  double get total => minutes.values.fold(0, (a, b) => a + b);

  static ZoneMinutes of(Iterable<List<double>> days, double maxHr) {
    final out = {for (final z in HeartZone.values) z: 0.0};
    for (final bins in days) {
      for (var b = 0; b < bins.length && b < HeartBins.count; b++) {
        final share = HeartBins.midOf(b) / maxHr;
        for (final z in HeartZone.values) {
          if (share >= z.low && share < z.high) {
            out[z] = out[z]! + bins[b];
            break;
          }
        }
        // Above Zone 5's range still counts as Zone 5.
        if (share >= HeartZone.z5.high) {
          out[HeartZone.z5] = out[HeartZone.z5]! + bins[b];
        }
      }
    }
    return ZoneMinutes(out);
  }
}
