import 'package:flutter/material.dart';

import 'package:health_app/models/metric_type.dart';

/// Personal details and Medical ID information.
@immutable
class UserProfile {
  const UserProfile({
    this.name = '',
    this.birthDate,
    this.sex = '',
    this.heightCm,
    this.bloodType = '',
    this.allergies = '',
    this.conditions = '',
    this.medications = '',
    this.emergencyName = '',
    this.emergencyPhone = '',
  });

  final String name;
  final DateTime? birthDate;
  final String sex;
  final double? heightCm;
  final String bloodType;
  final String allergies;
  final String conditions;
  final String medications;
  final String emergencyName;
  final String emergencyPhone;

  int? ageOn(DateTime today) {
    final birth = birthDate;
    if (birth == null) return null;
    var age = today.year - birth.year;
    final hadBirthday =
        today.month > birth.month ||
        (today.month == birth.month && today.day >= birth.day);
    if (!hadBirthday) age--;
    return age;
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  UserProfile copyWith({
    String? name,
    DateTime? birthDate,
    String? sex,
    double? heightCm,
    String? bloodType,
    String? allergies,
    String? conditions,
    String? medications,
    String? emergencyName,
    String? emergencyPhone,
  }) {
    return UserProfile(
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      sex: sex ?? this.sex,
      heightCm: heightCm ?? this.heightCm,
      bloodType: bloodType ?? this.bloodType,
      allergies: allergies ?? this.allergies,
      conditions: conditions ?? this.conditions,
      medications: medications ?? this.medications,
      emergencyName: emergencyName ?? this.emergencyName,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
    );
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'birthDate': birthDate?.toIso8601String(),
    'sex': sex,
    'heightCm': heightCm,
    'bloodType': bloodType,
    'allergies': allergies,
    'conditions': conditions,
    'medications': medications,
    'emergencyName': emergencyName,
    'emergencyPhone': emergencyPhone,
  };

  factory UserProfile.fromJson(Map<String, Object?> json) {
    String str(String key) => switch (json[key]) {
      final String value => value,
      _ => '',
    };
    final height = json['heightCm'];
    return UserProfile(
      name: str('name'),
      birthDate: DateTime.tryParse(str('birthDate')),
      sex: str('sex'),
      heightCm: height is num ? height.toDouble() : null,
      bloodType: str('bloodType'),
      allergies: str('allergies'),
      conditions: str('conditions'),
      medications: str('medications'),
      emergencyName: str('emergencyName'),
      emergencyPhone: str('emergencyPhone'),
    );
  }
}

/// Daily targets used for the activity rings and progress bars.
@immutable
class Goals {
  const Goals({
    this.steps = 8000,
    this.activeEnergy = 500,
    this.exerciseMinutes = 30,
    this.water = 2000,
    this.sleep = 8,
    this.mindfulMinutes = 10,
    this.weightKg,
  });

  final double steps;
  final double activeEnergy;
  final double exerciseMinutes;
  final double water;
  final double sleep;
  final double mindfulMinutes;

  /// Target body weight, if set (shown as a line on the weight chart).
  final double? weightKg;

  Goals withWeight(double? kg) => Goals(
    steps: steps,
    activeEnergy: activeEnergy,
    exerciseMinutes: exerciseMinutes,
    water: water,
    sleep: sleep,
    mindfulMinutes: mindfulMinutes,
    weightKg: kg,
  );

  /// Goal for a metric, or null if the metric has no daily goal.
  double? forMetric(MetricType type) => switch (type) {
    MetricType.steps => steps,
    MetricType.activeEnergy => activeEnergy,
    MetricType.exerciseMinutes => exerciseMinutes,
    MetricType.water => water,
    MetricType.sleep => sleep,
    MetricType.mindfulMinutes => mindfulMinutes,
    _ => null,
  };

  Goals withMetric(MetricType type, double value) => Goals(
    steps: type == MetricType.steps ? value : steps,
    activeEnergy: type == MetricType.activeEnergy ? value : activeEnergy,
    exerciseMinutes: type == MetricType.exerciseMinutes
        ? value
        : exerciseMinutes,
    water: type == MetricType.water ? value : water,
    sleep: type == MetricType.sleep ? value : sleep,
    mindfulMinutes: type == MetricType.mindfulMinutes ? value : mindfulMinutes,
    weightKg: weightKg,
  );

  static const goalMetrics = [
    MetricType.steps,
    MetricType.activeEnergy,
    MetricType.exerciseMinutes,
    MetricType.water,
    MetricType.sleep,
    MetricType.mindfulMinutes,
  ];

  Map<String, Object?> toJson() => {
    for (final type in goalMetrics) type.name: forMetric(type),
    'weightGoal': ?weightKg,
  };

  factory Goals.fromJson(Map<String, Object?> json) {
    var goals = const Goals();
    for (final type in goalMetrics) {
      final value = json[type.name];
      if (value is num && value > 0) {
        goals = goals.withMetric(type, value.toDouble());
      }
    }
    final w = json['weightGoal'];
    return w is num && w > 0 ? goals.withWeight(w.toDouble()) : goals;
  }
}
