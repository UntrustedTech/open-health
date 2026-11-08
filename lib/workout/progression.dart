import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:health_app/utils/units.dart';
import 'package:health_app/models/workout.dart';

enum ProgressionKind {
  /// Keep last time's weight and reps.
  none('Repeat Last'),

  /// Add weight whenever every set hit its reps.
  linear('Linear'),

  /// Add reps within a range, then add weight and start again at the bottom.
  double('Double Progression');

  const ProgressionKind(this.label);

  final String label;
}

/// How an exercise's next target is worked out.
@immutable
class ProgressionRule {
  const ProgressionRule({
    this.kind = ProgressionKind.none,
    this.increment = 2.5,
    this.repMin = 8,
    this.repMax = 12,
    this.stallLimit = 3,
  });

  final ProgressionKind kind;

  /// Weight added each step, in kg.
  final double increment;
  final int repMin;
  final int repMax;

  /// Sessions without progress before a deload.
  final int stallLimit;

  Map<String, Object?> toJson() => {
    'k': kind.name,
    'inc': increment,
    if (kind == ProgressionKind.double) ...{'min': repMin, 'max': repMax},
  };

  factory ProgressionRule.fromJson(Map<dynamic, dynamic> json) {
    final inc = json['inc'], min = json['min'], max = json['max'];
    final lo = min is int ? min.clamp(1, 100) : 8;
    final hi = max is int ? max.clamp(1, 100) : 12;
    return ProgressionRule(
      kind:
          ProgressionKind.values
              .where((k) => k.name == json['k'])
              .firstOrNull ??
          ProgressionKind.none,
      increment: inc is num && inc > 0 && inc <= 50 ? inc.toDouble() : 2.5,
      repMin: lo,
      repMax: hi < lo ? lo : hi,
    );
  }
}

/// A suggested target for the next session, with the reason for it.
typedef ProgressionTarget = ({
  double weightKg,
  int reps,
  String explanation,
  bool deload,
});

/// A weight in the user's units, e.g. "60 kg" or "132.3 lb".
String _kg(double v) => Units.weight(v);

double _roundTo(double v, double step) => (v / step).round() * step;

/// Works out the next target from past sessions (most recent first; each a
/// list of that session's sets for the exercise). Warm-ups are ignored and
/// missed reps never add weight.
ProgressionTarget suggestNext({
  required ProgressionRule rule,
  required int targetReps,
  required List<List<SetLog>> history,
  double fallbackKg = 0,
}) {
  final sessions = [
    for (final s in history)
      [
        for (final set in s)
          if (set.done && set.type.counts) set,
      ],
  ].where((s) => s.isNotEmpty).toList();

  if (sessions.isEmpty) {
    return (
      weightKg: fallbackKg,
      reps: rule.kind == ProgressionKind.double ? rule.repMin : targetReps,
      explanation: 'First time: pick a weight you can lift with good form.',
      deload: false,
    );
  }

  final last = sessions.first;
  final weight = last.map((s) => s.weightKg).reduce(max);

  switch (rule.kind) {
    case ProgressionKind.none:
      return (
        weightKg: weight,
        reps: last.map((s) => s.reps).reduce(max),
        explanation: 'Same as last time: ${_kg(weight)}.',
        deload: false,
      );
    case ProgressionKind.linear:
      final hit = last.every((s) => s.reps >= targetReps);
      if (hit) {
        return (
          weightKg: weight + rule.increment,
          reps: targetReps,
          explanation:
              'All ${last.length}×$targetReps at ${_kg(weight)} done → '
              '+${_kg(rule.increment)}.',
          deload: false,
        );
      }
      // Stalled: the same weight missed in each of the last N sessions.
      final recent = sessions.take(rule.stallLimit).toList();
      final stalled =
          recent.length >= rule.stallLimit &&
          recent.every(
            (s) =>
                s.map((x) => x.weightKg).reduce(max) == weight &&
                s.any((x) => x.reps < targetReps),
          );
      if (stalled) {
        final deload = max(0.0, _roundTo(weight * 0.9, rule.increment));
        return (
          weightKg: deload,
          reps: targetReps,
          explanation:
              '${rule.stallLimit} sessions stuck at ${_kg(weight)} → '
              'Deload 10% to ${_kg(deload)} and build back up.',
          deload: true,
        );
      }
      return (
        weightKg: weight,
        reps: targetReps,
        explanation: 'Missed reps last time → Repeat ${_kg(weight)}.',
        deload: false,
      );
    case ProgressionKind.double:
      final atTop = last.every((s) => s.reps >= rule.repMax);
      if (atTop) {
        return (
          weightKg: weight + rule.increment,
          reps: rule.repMin,
          explanation:
              'Hit ${rule.repMax} reps on every set → +${_kg(rule.increment)}, '
              'back to ${rule.repMin} reps.',
          deload: false,
        );
      }
      final best = last.map((s) => s.reps).reduce(min);
      final next = (best + 1).clamp(rule.repMin, rule.repMax);
      return (
        weightKg: weight,
        reps: next,
        explanation:
            'Aim for $next reps at ${_kg(weight)} '
            '(range ${rule.repMin}–${rule.repMax}).',
        deload: false,
      );
  }
}
