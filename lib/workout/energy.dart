import 'package:health_app/models/workout.dart';

/// Intensity (MET) of a workout from how it was actually done, where that
/// can be told: running and walking from speed and climbing (the ACSM
/// metabolic equations), cycling from speed (Compendium of Physical
/// Activities). Other types use their typical value.
///
/// [metersPerSecond] is the average moving speed; [grade] the average
/// climb (elevation gained per metre covered, 0.05 = 5%).
double metFor(WorkoutType type, {double? metersPerSecond, double grade = 0}) {
  final v = metersPerSecond;
  if (v == null || v <= 0 || !v.isFinite) return type.met;
  final g = grade.isFinite ? grade.clamp(0.0, maxGrade) : 0.0;
  final met = switch (type) {
    WorkoutType.run || WorkoutType.walk => _onFoot(v, g),
    // Rough ground costs more than a pavement walk.
    WorkoutType.hike => _onFoot(v, g) * hikeTerrain,
    WorkoutType.cycle => _cycling(v * 3.6),
    _ => type.met,
  };
  return met.clamp(minMet, maxMet).toDouble();
}

/// Climb above which GPS altitude is more likely noise than a real hill.
const maxGrade = 0.15;

/// Extra effort of uneven trails over a smooth path.
const hikeTerrain = 1.15;
const minMet = 1.5;
const maxMet = 20.0;

/// Speed (m/s) from which on-foot movement is treated as running.
const runFromMps = 2.2;

/// ACSM: oxygen use in ml/kg/min from speed in m/min and grade, as METs
/// (3.5 ml/kg/min each).
double _onFoot(double mps, double grade) {
  final mPerMin = mps * 60;
  final vo2 = mps >= runFromMps
      ? 0.2 * mPerMin + 0.9 * mPerMin * grade + 3.5
      : 0.1 * mPerMin + 1.8 * mPerMin * grade + 3.5;
  return vo2 / 3.5;
}

/// Compendium of Physical Activities (2011) bicycling, by km/h.
double _cycling(double kmh) => switch (kmh) {
  < 16 => 4.0,
  < 19 => 6.8,
  < 22 => 8.0,
  < 25 => 10.0,
  < 30 => 12.0,
  _ => 15.8,
};

/// Average moving speed and climb for [metFor]; null speed when there's
/// too little distance or time to trust it.
({double? metersPerSecond, double grade}) paceOf({
  required double distanceMeters,
  required Duration active,
  double elevationGainMeters = 0,
}) {
  final seconds = active.inSeconds;
  if (distanceMeters < minDistance || seconds < minSeconds) {
    return (metersPerSecond: null, grade: 0);
  }
  return (
    metersPerSecond: distanceMeters / seconds,
    grade: elevationGainMeters / distanceMeters,
  );
}

/// Distance and time below which speed isn't used.
const minDistance = 200.0;
const minSeconds = 60;
