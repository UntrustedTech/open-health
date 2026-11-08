import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;

/// How multiple entries recorded on the same day combine into one daily value.
enum Aggregation {
  /// Values add up (steps, water, calories).
  sum,

  /// Values are averaged (heart rate, blood oxygen).
  average,

  /// The most recent value wins (weight).
  latest,
}

enum HealthCategory {
  // Apple Health's category colours (iOS system colours).
  activity('Activity', Icons.local_fire_department_rounded, Color(0xFFFF9447)),
  heart('Heart', Icons.favorite_rounded, Color(0xFFFF5C6C)),
  vitals('Vitals', Icons.monitor_heart_rounded, Color(0xFFFF4D8D)),
  sleep('Sleep', Icons.bed_rounded, Color(0xFF8C82FF)),
  body('Body Measurements', Icons.person_rounded, Color(0xFFC07CFF)),
  nutrition('Nutrition', Icons.restaurant_rounded, Color(0xFF4BE38F)),
  mindfulness('Mindfulness', Icons.auto_awesome_rounded, Color(0xFF3EF0CF));

  const HealthCategory(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

/// Every kind of data the app can track. Adding a metric here makes it
/// available in Browse, detail charts and manual entry automatically.
enum MetricType {
  steps(
    label: 'Steps',
    unit: 'steps',
    icon: Icons.directions_walk_rounded,
    category: HealthCategory.activity,
    aggregation: Aggregation.sum,
    decimals: 0,
    min: 0,
    max: 100000,
  ),
  distance(
    label: 'Walking + Running Distance',
    unit: 'km',
    icon: Icons.map_rounded,
    category: HealthCategory.activity,
    aggregation: Aggregation.sum,
    decimals: 2,
    min: 0,
    max: 300,
  ),
  activeEnergy(
    label: 'Active Energy',
    unit: 'kcal',
    icon: Icons.local_fire_department_rounded,
    category: HealthCategory.activity,
    aggregation: Aggregation.sum,
    decimals: 0,
    min: 0,
    max: 10000,
  ),
  restingEnergy(
    label: 'Resting Energy',
    unit: 'kcal',
    icon: Icons.bolt_rounded,
    category: HealthCategory.activity,
    aggregation: Aggregation.average,
    decimals: 0,
    min: 500,
    max: 5000,
  ),
  floorsClimbed(
    label: 'Floors Climbed',
    unit: 'floors',
    icon: Icons.stairs_rounded,
    category: HealthCategory.activity,
    aggregation: Aggregation.sum,
    decimals: 0,
    min: 0,
    max: 500,
  ),
  exerciseMinutes(
    label: 'Exercise Minutes',
    unit: 'min',
    icon: Icons.timer_rounded,
    category: HealthCategory.activity,
    aggregation: Aggregation.sum,
    decimals: 0,
    min: 0,
    max: 1440,
  ),
  heartRate(
    label: 'Heart Rate',
    unit: 'bpm',
    icon: Icons.favorite_rounded,
    category: HealthCategory.heart,
    aggregation: Aggregation.average,
    decimals: 0,
    min: 20,
    max: 250,
  ),
  restingHeartRate(
    label: 'Resting Heart Rate',
    unit: 'bpm',
    icon: Icons.favorite_border_rounded,
    category: HealthCategory.heart,
    aggregation: Aggregation.average,
    decimals: 0,
    min: 20,
    max: 200,
  ),
  hrv(
    label: 'Heart Rate Variability',
    unit: 'ms',
    icon: Icons.graphic_eq_rounded,
    category: HealthCategory.heart,
    aggregation: Aggregation.average,
    decimals: 0,
    min: 1,
    max: 300,
  ),
  bloodOxygen(
    label: 'Blood Oxygen',
    unit: '%',
    icon: Icons.air_rounded,
    category: HealthCategory.vitals,
    aggregation: Aggregation.average,
    decimals: 0,
    min: 50,
    max: 100,
  ),
  bloodPressureSystolic(
    label: 'Blood Pressure (Systolic)',
    unit: 'mmHg',
    icon: Icons.bloodtype_rounded,
    category: HealthCategory.vitals,
    aggregation: Aggregation.average,
    decimals: 0,
    min: 50,
    max: 260,
  ),
  bloodPressureDiastolic(
    label: 'Blood Pressure (Diastolic)',
    unit: 'mmHg',
    icon: Icons.bloodtype_outlined,
    category: HealthCategory.vitals,
    aggregation: Aggregation.average,
    decimals: 0,
    min: 30,
    max: 180,
  ),
  bloodGlucose(
    label: 'Blood Glucose',
    unit: 'mg/dL',
    icon: Icons.water_drop_outlined,
    category: HealthCategory.vitals,
    aggregation: Aggregation.average,
    decimals: 0,
    min: 20,
    max: 600,
  ),
  respiratoryRate(
    label: 'Respiratory Rate',
    unit: 'breaths/min',
    icon: Icons.air_rounded,
    category: HealthCategory.vitals,
    aggregation: Aggregation.average,
    decimals: 0,
    min: 4,
    max: 60,
  ),
  bodyTemperature(
    label: 'Body Temperature',
    unit: '°C',
    icon: Icons.thermostat_rounded,
    category: HealthCategory.vitals,
    aggregation: Aggregation.average,
    decimals: 1,
    min: 30,
    max: 45,
  ),
  skinTemperature(
    label: 'Skin Temperature',
    unit: '°C',
    icon: Icons.device_thermostat_rounded,
    category: HealthCategory.vitals,
    aggregation: Aggregation.average,
    decimals: 1,
    min: -5,
    max: 5,
  ),
  sleep(
    label: 'Sleep',
    unit: 'hr',
    icon: Icons.bed_rounded,
    category: HealthCategory.sleep,
    aggregation: Aggregation.sum,
    decimals: 1,
    min: 0,
    max: 24,
  ),
  sleepDeep(
    label: 'Deep Sleep',
    unit: 'hr',
    icon: Icons.bedtime_rounded,
    category: HealthCategory.sleep,
    tint: Color(0xFF3634A3),
    aggregation: Aggregation.sum,
    decimals: 2,
    min: 0,
    max: 24,
  ),
  sleepCore(
    label: 'Core Sleep',
    unit: 'hr',
    icon: Icons.dark_mode_rounded,
    category: HealthCategory.sleep,
    tint: Color(0xFF0A84FF),
    aggregation: Aggregation.sum,
    decimals: 2,
    min: 0,
    max: 24,
  ),
  sleepRem(
    label: 'REM Sleep',
    unit: 'hr',
    icon: Icons.auto_awesome_rounded,
    category: HealthCategory.sleep,
    tint: Color(0xFF4CC3FF),
    aggregation: Aggregation.sum,
    decimals: 2,
    min: 0,
    max: 24,
  ),
  sleepAwake(
    label: 'Awake in Bed',
    unit: 'hr',
    icon: Icons.wb_sunny_rounded,
    category: HealthCategory.sleep,
    tint: Color(0xFFFF9447),
    aggregation: Aggregation.sum,
    decimals: 2,
    min: 0,
    max: 24,
  ),
  weight(
    label: 'Weight',
    unit: 'kg',
    icon: Icons.monitor_weight_rounded,
    category: HealthCategory.body,
    aggregation: Aggregation.latest,
    decimals: 1,
    min: 2,
    max: 500,
  ),
  bodyFat(
    label: 'Body Fat',
    unit: '%',
    icon: Icons.accessibility_new_rounded,
    category: HealthCategory.body,
    aggregation: Aggregation.latest,
    decimals: 1,
    min: 2,
    max: 75,
  ),
  leanBodyMass(
    label: 'Lean Body Mass',
    unit: 'kg',
    icon: Icons.fitness_center_rounded,
    category: HealthCategory.body,
    aggregation: Aggregation.latest,
    decimals: 1,
    min: 10,
    max: 200,
  ),
  bodyWaterMass(
    label: 'Body Water Mass',
    unit: 'kg',
    icon: Icons.opacity_rounded,
    category: HealthCategory.body,
    aggregation: Aggregation.latest,
    decimals: 1,
    min: 5,
    max: 150,
  ),
  water(
    label: 'Water',
    unit: 'ml',
    icon: Icons.water_drop_rounded,
    category: HealthCategory.nutrition,
    tint: Color(0xFF4CC3FF),
    aggregation: Aggregation.sum,
    decimals: 0,
    min: 0,
    max: 10000,
  ),
  dietaryEnergy(
    label: 'Calories Eaten',
    unit: 'kcal',
    icon: Icons.local_fire_department_outlined,
    category: HealthCategory.nutrition,
    tint: Color(0xFFFF9447),
    aggregation: Aggregation.sum,
    decimals: 0,
    min: 0,
    max: 20000,
  ),
  protein(
    label: 'Protein',
    unit: 'g',
    icon: Icons.apps_rounded,
    category: HealthCategory.nutrition,
    tint: Color(0xFF3DD8EB),
    aggregation: Aggregation.sum,
    decimals: 0,
    min: 0,
    max: 1000,
  ),
  carbs(
    label: 'Carbohydrates',
    unit: 'g',
    icon: Icons.layers_rounded,
    category: HealthCategory.nutrition,
    tint: Color(0xFFFFCF3D),
    aggregation: Aggregation.sum,
    decimals: 0,
    min: 0,
    max: 2000,
  ),
  fat(
    label: 'Fat',
    unit: 'g',
    icon: Icons.opacity_rounded,
    category: HealthCategory.nutrition,
    tint: Color(0xFFC07CFF),
    aggregation: Aggregation.sum,
    decimals: 0,
    min: 0,
    max: 1000,
  ),
  mindfulMinutes(
    label: 'Mindful Minutes',
    unit: 'min',
    icon: Icons.auto_awesome_rounded,
    category: HealthCategory.mindfulness,
    aggregation: Aggregation.sum,
    decimals: 0,
    min: 0,
    max: 1440,
  );

  const MetricType({
    required this.label,
    required this.unit,
    required this.icon,
    required this.category,
    required this.aggregation,
    required this.decimals,
    required this.min,
    required this.max,
    this.tint,
  });

  final String label;
  final String unit;
  final IconData icon;
  final HealthCategory category;
  final Aggregation aggregation;

  /// Decimal places used when displaying and entering values.
  final int decimals;

  /// Accepted range for manual entry.
  final double min;
  final double max;

  /// Overrides the category colour (e.g. water is blue, not green).
  final Color? tint;

  Color get color => tint ?? category.color;

  /// Recorded in hours and shown as "7 hr 30 min".
  bool get isDuration => sleepStages.contains(this) || this == sleep;

  /// The parts of a night's sleep, deepest first.
  static const sleepStages = [sleepDeep, sleepCore, sleepRem, sleepAwake];

  static MetricType? fromName(String name) {
    for (final type in values) {
      if (type.name == name) return type;
    }
    return null;
  }
}
