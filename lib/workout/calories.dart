import 'dart:math';

/// Body weight used when none has been logged.
const defaultWeightKg = 70.0;

/// Active energy in kcal for an activity of the given MET. Resting energy
/// (1 MET) is excluded, matching "Active Energy" in Health.
double activeCalories({
  required double met,
  required double weightKg,
  required Duration duration,
}) => max(0, met - 1) * weightKg * duration.inSeconds / 3600;

/// Total energy in kcal including resting energy (for Health Connect).
double totalCalories({
  required double met,
  required double weightKg,
  required Duration duration,
}) => met * weightKg * duration.inSeconds / 3600;
