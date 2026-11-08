import 'package:flutter/foundation.dart';

import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/workout/progression.dart';

enum MuscleGroup {
  chest('Chest'),
  back('Back'),
  legs('Legs'),
  shoulders('Shoulders'),
  arms('Arms'),
  core('Core'),
  fullBody('Full Body');

  const MuscleGroup(this.label);

  final String label;
}

@immutable
class Exercise {
  const Exercise(this.id, this.name, this.muscle, {this.bodyweight = false});

  final String id;
  final String name;
  final MuscleGroup muscle;

  /// Logged by reps only (weight is optional extra load).
  final bool bodyweight;
}

/// Built-in exercises.
abstract final class ExerciseLibrary {
  static const all = [
    Exercise('bench_press', 'Bench Press', MuscleGroup.chest),
    Exercise('incline_db_press', 'Incline Dumbbell Press', MuscleGroup.chest),
    Exercise('push_up', 'Push-Up', MuscleGroup.chest, bodyweight: true),
    Exercise('chest_fly', 'Cable Fly', MuscleGroup.chest),
    Exercise('dip', 'Dip', MuscleGroup.chest, bodyweight: true),
    Exercise('deadlift', 'Deadlift', MuscleGroup.back),
    Exercise('pull_up', 'Pull-Up', MuscleGroup.back, bodyweight: true),
    Exercise('barbell_row', 'Barbell Row', MuscleGroup.back),
    Exercise('lat_pulldown', 'Lat Pulldown', MuscleGroup.back),
    Exercise('seated_row', 'Seated Cable Row', MuscleGroup.back),
    Exercise('squat', 'Back Squat', MuscleGroup.legs),
    Exercise('front_squat', 'Front Squat', MuscleGroup.legs),
    Exercise('leg_press', 'Leg Press', MuscleGroup.legs),
    Exercise('rdl', 'Romanian Deadlift', MuscleGroup.legs),
    Exercise('lunge', 'Walking Lunge', MuscleGroup.legs),
    Exercise('leg_curl', 'Leg Curl', MuscleGroup.legs),
    Exercise('calf_raise', 'Calf Raise', MuscleGroup.legs),
    Exercise('hip_thrust', 'Hip Thrust', MuscleGroup.legs),
    Exercise('ohp', 'Overhead Press', MuscleGroup.shoulders),
    Exercise('lateral_raise', 'Lateral Raise', MuscleGroup.shoulders),
    Exercise('face_pull', 'Face Pull', MuscleGroup.shoulders),
    Exercise('bicep_curl', 'Biceps Curl', MuscleGroup.arms),
    Exercise('hammer_curl', 'Hammer Curl', MuscleGroup.arms),
    Exercise('tricep_pushdown', 'Triceps Pushdown', MuscleGroup.arms),
    Exercise('skull_crusher', 'Skull Crusher', MuscleGroup.arms),
    Exercise('plank', 'Plank (seconds)', MuscleGroup.core, bodyweight: true),
    Exercise('crunch', 'Crunch', MuscleGroup.core, bodyweight: true),
    Exercise(
      'hanging_leg_raise',
      'Hanging Leg Raise',
      MuscleGroup.core,
      bodyweight: true,
    ),
    Exercise(
      'russian_twist',
      'Russian Twist',
      MuscleGroup.core,
      bodyweight: true,
    ),
    Exercise('kettlebell_swing', 'Kettlebell Swing', MuscleGroup.fullBody),
    Exercise('burpee', 'Burpee', MuscleGroup.fullBody, bodyweight: true),
    Exercise('clean_press', 'Clean and Press', MuscleGroup.fullBody),
  ];

  static final _byId = {for (final e in all) e.id: e};

  static Exercise? byId(String id) => _byId[id];

  /// Display name from the full catalog, falling back to this list while
  /// the catalog is still loading.
  static String nameOf(String id) =>
      ExerciseCatalog.instance.byId(id)?.name ?? _byId[id]?.name ?? 'Exercise';
}

@immutable
class RoutineItem {
  const RoutineItem(
    this.exerciseId, {
    this.sets = 3,
    this.reps = 10,
    this.weightKg = 0,
    this.warmupSets = 0,
    this.restSeconds,
    this.superset,
    this.progression = const ProgressionRule(),
  });

  final String exerciseId;
  final int sets;

  /// Target reps (or seconds, for timed exercises).
  final int reps;
  final double weightKg;
  final int warmupSets;

  /// Rest after each set; null uses the workout default.
  final int? restSeconds;

  /// Items sharing a number form a superset.
  final int? superset;
  final ProgressionRule progression;

  RoutineItem copyWith({
    int? sets,
    int? reps,
    double? weightKg,
    int? warmupSets,
    int? restSeconds,
    bool clearRest = false,
    int? superset,
    bool clearSuperset = false,
    ProgressionRule? progression,
  }) => RoutineItem(
    exerciseId,
    sets: sets ?? this.sets,
    reps: reps ?? this.reps,
    weightKg: weightKg ?? this.weightKg,
    warmupSets: warmupSets ?? this.warmupSets,
    restSeconds: clearRest ? null : (restSeconds ?? this.restSeconds),
    superset: clearSuperset ? null : (superset ?? this.superset),
    progression: progression ?? this.progression,
  );

  Map<String, Object?> toJson() => {
    'e': exerciseId,
    's': sets,
    'r': reps,
    'w': weightKg,
    if (warmupSets > 0) 'wu': warmupSets,
    'rest': ?restSeconds,
    'ss': ?superset,
    if (progression.kind != ProgressionKind.none) 'prog': progression.toJson(),
  };

  static RoutineItem? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final e = json['e'], s = json['s'], r = json['r'], w = json['w'];
    if (e is! String || s is! int || r is! int || w is! num) return null;
    final wu = json['wu'],
        rest = json['rest'],
        ss = json['ss'],
        prog = json['prog'];
    // Routines can come from shared files: keep every value sane.
    return RoutineItem(
      e,
      sets: s.clamp(1, 20),
      reps: r.clamp(1, 999),
      weightKg: w.toDouble().clamp(0, 1000),
      warmupSets: wu is int ? wu.clamp(0, 10) : 0,
      restSeconds: rest is int && rest >= 0 ? rest.clamp(0, 3600) : null,
      superset: ss is int && ss >= 1 && ss <= 9 ? ss : null,
      progression: prog is Map
          ? ProgressionRule.fromJson(prog)
          : const ProgressionRule(),
    );
  }
}

/// A saved list of exercises to start a strength workout from.
@immutable
class Routine {
  const Routine({
    required this.id,
    required this.name,
    required this.items,
    this.builtIn = false,
  });

  final String id;
  final String name;
  final List<RoutineItem> items;
  final bool builtIn;

  static const presets = [
    Routine(
      id: 'preset_push',
      name: 'Push Day',
      builtIn: true,
      items: [
        RoutineItem('bench_press', sets: 4, reps: 8),
        RoutineItem('ohp', reps: 8),
        RoutineItem('incline_db_press'),
        RoutineItem('lateral_raise', reps: 15),
        RoutineItem('tricep_pushdown', reps: 12),
      ],
    ),
    Routine(
      id: 'preset_pull',
      name: 'Pull Day',
      builtIn: true,
      items: [
        RoutineItem('deadlift', reps: 5),
        RoutineItem('pull_up', reps: 8),
        RoutineItem('barbell_row', reps: 8),
        RoutineItem('face_pull', reps: 15),
        RoutineItem('bicep_curl', reps: 12),
      ],
    ),
    Routine(
      id: 'preset_legs',
      name: 'Leg Day',
      builtIn: true,
      items: [
        RoutineItem('squat', sets: 4, reps: 6),
        RoutineItem('rdl', reps: 8),
        RoutineItem('leg_press', reps: 12),
        RoutineItem('leg_curl', reps: 12),
        RoutineItem('calf_raise', reps: 15),
      ],
    ),
    Routine(
      id: 'preset_full',
      name: 'Full Body',
      builtIn: true,
      items: [
        RoutineItem('squat', reps: 8),
        RoutineItem('bench_press', reps: 8),
        RoutineItem('barbell_row', reps: 8),
        RoutineItem('ohp', reps: 10),
        RoutineItem('plank', reps: 45),
      ],
    ),
    Routine(
      id: 'preset_core',
      name: 'Core Burner',
      builtIn: true,
      items: [
        RoutineItem('plank', reps: 60),
        RoutineItem('hanging_leg_raise', reps: 12),
        RoutineItem('russian_twist', reps: 20),
        RoutineItem('crunch', reps: 20),
      ],
    ),
  ];

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'items': [for (final i in items) i.toJson()],
  };

  static Routine? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], name = json['name'], items = json['items'];
    if (id is! String || name is! String || items is! List) return null;
    return Routine(
      id: id,
      name: name,
      items: items.map(RoutineItem.tryFromJson).nonNulls.toList(),
    );
  }
}
