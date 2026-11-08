import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

enum PlanMode {
  /// A routine on fixed weekdays.
  weekday,

  /// Routines in order (A, B, C, A…); the next is the one after the last
  /// completed, however the week went.
  rotation,
}

/// The user's training schedule.
@immutable
class TrainingPlan {
  const TrainingPlan({
    this.mode = PlanMode.weekday,
    this.days = const {},
    this.rotation = const [],
    this.overrides = const {},
    this.weekStart = DateTime.monday,
  });

  static final _key = DateFormat('yyyy-MM-dd');

  final PlanMode mode;

  /// Weekday ([DateTime.monday]…) → routine id.
  final Map<int, String> days;
  final List<String> rotation;

  /// One-off changes by date ("yyyy-MM-dd"): a routine id, or null for rest.
  final Map<String, String?> overrides;

  /// [DateTime.monday] or [DateTime.sunday].
  final int weekStart;

  bool get isEmpty =>
      mode == PlanMode.weekday ? days.isEmpty : rotation.isEmpty;

  static String dateKey(DateTime d) => _key.format(d);

  TrainingPlan copyWith({
    PlanMode? mode,
    Map<int, String>? days,
    List<String>? rotation,
    Map<String, String?>? overrides,
    int? weekStart,
  }) => TrainingPlan(
    mode: mode ?? this.mode,
    days: days ?? this.days,
    rotation: rotation ?? this.rotation,
    overrides: overrides ?? this.overrides,
    weekStart: weekStart ?? this.weekStart,
  );

  /// Moves the session planned on [from] to [to] without changing the
  /// weekly plan. Pass the [routineId] the scheduler resolved for [from]
  /// (rotation plans don't store one per weekday).
  TrainingPlan moveSession({
    required DateTime from,
    required DateTime to,
    String? routineId,
  }) {
    final routine =
        routineId ??
        (overrides.containsKey(dateKey(from))
            ? overrides[dateKey(from)]
            : mode == PlanMode.weekday
            ? days[from.weekday]
            : null);
    return copyWith(
      overrides: {...overrides, dateKey(from): null, dateKey(to): routine},
    );
  }

  /// Removes routine ids that no longer exist.
  TrainingPlan withoutRoutine(String id) => copyWith(
    days: {
      for (final e in days.entries)
        if (e.value != id) e.key: e.value,
    },
    rotation: rotation.where((r) => r != id).toList(),
    overrides: {
      for (final e in overrides.entries) e.key: e.value == id ? null : e.value,
    },
  );

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'days': {for (final e in days.entries) '${e.key}': e.value},
    'rotation': rotation,
    'overrides': overrides,
    'weekStart': weekStart,
  };

  factory TrainingPlan.fromJson(Map<String, Object?> json) {
    final days = json['days'];
    final rotation = json['rotation'];
    final overrides = json['overrides'];
    final start = json['weekStart'];
    return TrainingPlan(
      mode: json['mode'] == PlanMode.rotation.name
          ? PlanMode.rotation
          : PlanMode.weekday,
      days: days is Map
          ? {
              for (final e in days.entries)
                if (int.tryParse('${e.key}') case final d?
                    when d >= 1 && d <= 7 && e.value is String)
                  d: e.value as String,
            }
          : const {},
      rotation: rotation is List
          ? rotation.whereType<String>().toList()
          : const [],
      overrides: overrides is Map
          ? {
              for (final e in overrides.entries)
                if (e.key is String)
                  e.key as String: e.value is String ? e.value as String : null,
            }
          : const {},
      weekStart: start == DateTime.sunday ? DateTime.sunday : DateTime.monday,
    );
  }
}
