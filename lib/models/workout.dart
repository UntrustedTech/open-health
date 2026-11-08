import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;

/// How a workout is recorded.
enum WorkoutKind {
  /// Outdoor distance with GPS (run, walk, ride…).
  gps,

  /// Time-based cardio without GPS (swim, rowing machine…).
  timed,

  /// Sets and reps.
  strength,

  /// Timed work/rest rounds.
  intervals,
}

/// Groups of workouts for browsing.
enum WorkoutCategory {
  cardio('Cardio', Icons.favorite_rounded, Color(0xFF55E3C8)),
  strength('Strength & Power', Icons.fitness_center_rounded, Color(0xFFFF9447)),
  mindBody('Mind & Body', Icons.self_improvement_rounded, Color(0xFFB98CFF)),
  play('Sports & Play', Icons.sports_tennis_rounded, Color(0xFFFF4D8D)),
  aerial(
    'Aerial & Acrobatic',
    Icons.sports_gymnastics_rounded,
    Color(0xFFFF8AC7),
  ),
  adventure('Water, Snow & Board', Icons.surfing_rounded, Color(0xFF4CC3FF));

  const WorkoutCategory(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

enum WorkoutType {
  run(
    'Outdoor Run',
    Icons.directions_run_rounded,
    Color(0xFF55E3C8),
    9.8,
    WorkoutKind.gps,
  ),
  walk(
    'Outdoor Walk',
    Icons.directions_walk_rounded,
    Color(0xFF55E3C8),
    3.5,
    WorkoutKind.gps,
  ),
  hike('Hike', Icons.hiking_rounded, Color(0xFF4BE38F), 6.0, WorkoutKind.gps),
  cycle(
    'Outdoor Cycle',
    Icons.directions_bike_rounded,
    Color(0xFF4CC3FF),
    7.5,
    WorkoutKind.gps,
  ),
  strength(
    'Strength Training',
    Icons.fitness_center_rounded,
    Color(0xFFFF9447),
    5.0,
    WorkoutKind.strength,
  ),
  hiit(
    'HIIT',
    Icons.bolt_rounded,
    Color(0xFFFF4D8D),
    8.0,
    WorkoutKind.intervals,
  ),
  swim(
    'Pool Swim',
    Icons.pool_rounded,
    Color(0xFF007AFF),
    7.0,
    WorkoutKind.timed,
  ),
  row(
    'Rowing',
    Icons.rowing_rounded,
    Color(0xFF4CC3FF),
    7.0,
    WorkoutKind.timed,
  ),
  elliptical(
    'Elliptical',
    Icons.directions_run_rounded,
    Color(0xFFC07CFF),
    5.0,
    WorkoutKind.timed,
  ),
  yoga(
    'Yoga',
    Icons.self_improvement_rounded,
    Color(0xFF3EF0CF),
    2.5,
    WorkoutKind.timed,
  ),
  dance(
    'Dance',
    Icons.music_note_rounded,
    Color(0xFFFF4D8D),
    5.5,
    WorkoutKind.timed,
  ),
  indoorRun(
    'Indoor Run',
    Icons.directions_run_rounded,
    Color(0xFF55E3C8),
    9.0,
    WorkoutKind.timed,
  ),
  indoorCycle(
    'Indoor Cycle',
    Icons.pedal_bike_rounded,
    Color(0xFF4CC3FF),
    6.8,
    WorkoutKind.timed,
  ),
  stairs(
    'Stair Climber',
    Icons.stairs_rounded,
    Color(0xFFFFCF3D),
    9.0,
    WorkoutKind.timed,
  ),
  jumpRope(
    'Jump Rope',
    Icons.cable_rounded,
    Color(0xFFFF9447),
    11.0,
    WorkoutKind.timed,
  ),
  boxing(
    'Boxing',
    Icons.sports_mma_rounded,
    Color(0xFFFF5C6C),
    7.0,
    WorkoutKind.timed,
  ),
  martialArts(
    'Martial Arts',
    Icons.sports_kabaddi_rounded,
    Color(0xFFFF5C6C),
    8.0,
    WorkoutKind.timed,
  ),
  climbing(
    'Climbing',
    Icons.terrain_rounded,
    Color(0xFFC59A6B),
    7.5,
    WorkoutKind.timed,
  ),
  pilates(
    'Pilates',
    Icons.accessibility_new_rounded,
    Color(0xFFB98CFF),
    3.0,
    WorkoutKind.timed,
  ),
  barre(
    'Barre',
    Icons.sports_gymnastics_rounded,
    Color(0xFFFF8AC7),
    3.5,
    WorkoutKind.timed,
  ),
  stretching(
    'Stretching & Mobility',
    Icons.airline_seat_flat_angled_rounded,
    Color(0xFF3EF0CF),
    2.3,
    WorkoutKind.timed,
  ),
  taiChi(
    'Tai Chi',
    Icons.spa_rounded,
    Color(0xFF4BE38F),
    3.0,
    WorkoutKind.timed,
  ),
  tennis(
    'Tennis',
    Icons.sports_tennis_rounded,
    Color(0xFFD7F25C),
    7.3,
    WorkoutKind.timed,
  ),
  aerialSilks(
    'Aerial Silks',
    Icons.sports_gymnastics_rounded,
    Color(0xFFFF8AC7),
    5.0,
    WorkoutKind.timed,
  ),
  aerialHoop(
    'Aerial Hoop',
    Icons.trip_origin_rounded,
    Color(0xFFC07CFF),
    5.0,
    WorkoutKind.timed,
  ),
  poleFitness(
    'Pole Fitness',
    Icons.height_rounded,
    Color(0xFFFF4D8D),
    5.0,
    WorkoutKind.timed,
  ),
  trampoline(
    'Trampoline',
    Icons.sports_gymnastics_rounded,
    Color(0xFFFFCF3D),
    4.5,
    WorkoutKind.timed,
  ),
  paragliding(
    'Paragliding',
    Icons.paragliding_rounded,
    Color(0xFFFF9447),
    3.5,
    WorkoutKind.gps,
  ),
  surfing(
    'Surfing',
    Icons.surfing_rounded,
    Color(0xFF3EF0CF),
    3.5,
    WorkoutKind.timed,
  ),
  paddleboard(
    'Paddleboarding',
    Icons.rowing_rounded,
    Color(0xFF4CC3FF),
    6.0,
    WorkoutKind.gps,
  ),
  kayaking(
    'Kayaking',
    Icons.kayaking_rounded,
    Color(0xFFFF9447),
    5.0,
    WorkoutKind.gps,
  ),
  skiing(
    'Skiing',
    Icons.downhill_skiing_rounded,
    Color(0xFF4CC3FF),
    7.0,
    WorkoutKind.gps,
  ),
  snowboarding(
    'Snowboarding',
    Icons.snowboarding_rounded,
    Color(0xFFC07CFF),
    5.3,
    WorkoutKind.gps,
  ),
  skateboarding(
    'Skateboarding',
    Icons.skateboarding_rounded,
    Color(0xFFFFCF3D),
    5.0,
    WorkoutKind.gps,
  ),
  parkour(
    'Parkour',
    Icons.sports_handball_rounded,
    Color(0xFFFF5C6C),
    8.0,
    WorkoutKind.timed,
  ),
  openWaterSwim(
    'Open Water Swim',
    Icons.waves_rounded,
    Color(0xFF007AFF),
    8.0,
    WorkoutKind.timed,
  ),
  fencing(
    'Fencing',
    Icons.sports_kabaddi_rounded,
    Color(0xFFE6E6E6),
    6.0,
    WorkoutKind.timed,
  ),
  golf(
    'Golf',
    Icons.sports_golf_rounded,
    Color(0xFF4BE38F),
    4.8,
    WorkoutKind.timed,
  ),
  other(
    'Other',
    Icons.favorite_rounded,
    Color(0xFF8792AA),
    4.0,
    WorkoutKind.timed,
  );

  const WorkoutType(this.label, this.icon, this.color, this.met, this.kind);

  final String label;
  final IconData icon;
  final Color color;

  /// Metabolic equivalent used for calorie estimates.
  final double met;
  final WorkoutKind kind;

  bool get usesGps => kind == WorkoutKind.gps;

  /// Shown as speed (km/h) rather than pace: everything on GPS but running,
  /// walking and hiking.
  bool get showsSpeed => usesGps && this != run && this != walk && this != hike;

  /// The group it's listed in when picking a workout.
  WorkoutCategory get category => switch (this) {
    run ||
    walk ||
    hike ||
    cycle ||
    swim ||
    row ||
    elliptical ||
    indoorRun ||
    indoorCycle ||
    stairs ||
    jumpRope => WorkoutCategory.cardio,
    strength ||
    hiit ||
    boxing ||
    martialArts ||
    climbing => WorkoutCategory.strength,
    yoga ||
    pilates ||
    barre ||
    stretching ||
    taiChi => WorkoutCategory.mindBody,
    dance || tennis || fencing || golf || other => WorkoutCategory.play,
    aerialSilks ||
    aerialHoop ||
    poleFitness ||
    trampoline ||
    paragliding => WorkoutCategory.aerial,
    surfing ||
    paddleboard ||
    kayaking ||
    skiing ||
    snowboarding ||
    skateboarding ||
    parkour ||
    openWaterSwim => WorkoutCategory.adventure,
  };

  /// Upper speed limit used to reject GPS glitches, in m/s.
  double get maxSpeedMps => switch (this) {
    cycle || skiing || snowboarding => 30,
    paragliding => 25,
    skateboarding => 15,
    _ => 12,
  };

  static WorkoutType? fromName(Object? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }
}

/// Where a workout came from.
enum WorkoutSource {
  app,

  /// Read from Health Connect (read-only).
  healthConnect,

  /// Imported from another app's export file (editable, adds no activity
  /// data so totals aren't inflated).
  imported,
}

@immutable
class Lap {
  const Lap({required this.seconds, required this.meters});

  final int seconds;
  final double meters;

  Map<String, Object?> toJson() => {'s': seconds, 'm': meters};

  static Lap? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final s = json['s'], m = json['m'];
    if (s is! int || m is! num) return null;
    return Lap(seconds: s, meters: m.toDouble());
  }
}

/// Kind of set. Only normal, drop and failure sets count towards
/// records, volume and progression; warm-ups don't.
enum SetType {
  normal('', 'Set'),
  warmup('W', 'Warm-up'),
  drop('D', 'Drop Set'),
  failure('F', 'To Failure');

  const SetType(this.badge, this.label);

  /// Short marker shown in the set column.
  final String badge;
  final String label;

  bool get counts => this != warmup;
}

@immutable
class SetLog {
  const SetLog({
    required this.reps,
    required this.weightKg,
    this.done = false,
    this.type = SetType.normal,
    this.seconds,
    this.rpe,
  });

  final int reps;
  final double weightKg;
  final bool done;
  final SetType type;

  /// Time held, for timed exercises (planks, hangs).
  final int? seconds;

  /// Rate of perceived exertion (6–10); "reps in reserve" is 10 − RPE.
  final double? rpe;

  double get volume => type.counts ? reps * weightKg : 0;

  SetLog copyWith({
    int? reps,
    double? weightKg,
    bool? done,
    SetType? type,
    int? seconds,
    double? rpe,
    bool clearRpe = false,
  }) => SetLog(
    reps: reps ?? this.reps,
    weightKg: weightKg ?? this.weightKg,
    done: done ?? this.done,
    type: type ?? this.type,
    seconds: seconds ?? this.seconds,
    rpe: clearRpe ? null : (rpe ?? this.rpe),
  );

  Map<String, Object?> toJson() => {
    'r': reps,
    'w': weightKg,
    'd': done,
    if (type != SetType.normal) 't': type.name,
    'sec': ?seconds,
    'rpe': ?rpe,
  };

  static SetLog? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final r = json['r'], w = json['w'];
    if (r is! int || w is! num) return null;
    final sec = json['sec'];
    final rpe = json['rpe'];
    return SetLog(
      reps: r,
      weightKg: w.toDouble(),
      done: json['d'] == true,
      type:
          SetType.values.where((t) => t.name == json['t']).firstOrNull ??
          SetType.normal,
      seconds: sec is int ? sec : null,
      rpe: rpe is num ? rpe.toDouble() : null,
    );
  }
}

@immutable
class ExerciseLog {
  const ExerciseLog({
    required this.exerciseId,
    required this.sets,
    this.restSeconds,
    this.superset,
  });

  final String exerciseId;
  final List<SetLog> sets;

  /// Rest after each set; null uses the workout default.
  final int? restSeconds;

  /// Exercises sharing a number are done back to back (rest after the last).
  final int? superset;

  ExerciseLog copyWith({List<SetLog>? sets}) => ExerciseLog(
    exerciseId: exerciseId,
    sets: sets ?? this.sets,
    restSeconds: restSeconds,
    superset: superset,
  );

  Map<String, Object?> toJson() => {
    'e': exerciseId,
    'sets': [for (final s in sets) s.toJson()],
    'rest': ?restSeconds,
    'ss': ?superset,
  };

  static ExerciseLog? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['e'], sets = json['sets'];
    if (id is! String || sets is! List) return null;
    final rest = json['rest'];
    final ss = json['ss'];
    return ExerciseLog(
      exerciseId: id,
      sets: sets.map(SetLog.tryFromJson).nonNulls.toList(),
      restSeconds: rest is int ? rest : null,
      superset: ss is int ? ss : null,
    );
  }
}

/// A finished workout. The GPS route is stored separately (see
/// `WorkoutStore`) so the workout list stays small.
@immutable
class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.type,
    required this.start,
    required this.end,
    required this.activeSeconds,
    this.distanceMeters = 0,
    this.activeKcal = 0,
    this.elevationGainMeters = 0,
    this.splits = const [],
    this.laps = const [],
    this.exercises = const [],
    this.intervalProgram,
    this.rpe,
    this.notes = '',
    this.hasRoute = false,
    this.source = WorkoutSource.app,
    this.routineId,
  });

  final String id;
  final WorkoutType type;
  final DateTime start;
  final DateTime end;

  /// Time spent moving, excluding pauses.
  final int activeSeconds;
  final double distanceMeters;
  final double activeKcal;
  final double elevationGainMeters;

  /// Seconds taken for each full kilometre.
  final List<int> splits;
  final List<Lap> laps;
  final List<ExerciseLog> exercises;

  /// Name of the interval program used, if any.
  final String? intervalProgram;

  /// Rate of perceived exertion, 1 (easy) to 10 (all out).
  final int? rpe;
  final String notes;
  final bool hasRoute;
  final WorkoutSource source;

  /// The routine this workout was started from, if any (for the plan).
  final String? routineId;

  Duration get activeDuration => Duration(seconds: activeSeconds);
  double get kilometres => distanceMeters / 1000;
  bool get isImported => source == WorkoutSource.healthConnect;

  /// Average pace in seconds per km, or null without distance.
  double? get paceSecondsPerKm =>
      distanceMeters < 10 ? null : activeSeconds / kilometres;

  /// Average speed in km/h, or null without distance.
  double? get speedKmh => distanceMeters < 10 || activeSeconds == 0
      ? null
      : kilometres / (activeSeconds / 3600);

  /// Total weight lifted in completed sets.
  double get volumeKg => exercises.fold(
    0,
    (sum, e) =>
        sum + e.sets.where((s) => s.done).fold(0, (a, s) => a + s.volume),
  );

  int get completedSets => exercises.fold(
    0,
    (sum, e) => sum + e.sets.where((s) => s.done && s.type.counts).length,
  );

  WorkoutSession copyWith({
    int? rpe,
    String? notes,
    List<Lap>? laps,
    WorkoutSource? source,
    bool clearRpe = false,
  }) => WorkoutSession(
    id: id,
    type: type,
    start: start,
    end: end,
    activeSeconds: activeSeconds,
    distanceMeters: distanceMeters,
    activeKcal: activeKcal,
    elevationGainMeters: elevationGainMeters,
    splits: splits,
    laps: laps ?? this.laps,
    exercises: exercises,
    intervalProgram: intervalProgram,
    rpe: clearRpe ? null : (rpe ?? this.rpe),
    notes: notes ?? this.notes,
    hasRoute: hasRoute,
    source: source ?? this.source,
    routineId: routineId,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'active': activeSeconds,
    'dist': distanceMeters,
    'kcal': activeKcal,
    if (elevationGainMeters > 0) 'elev': elevationGainMeters,
    if (splits.isNotEmpty) 'splits': splits,
    if (laps.isNotEmpty) 'laps': [for (final l in laps) l.toJson()],
    if (exercises.isNotEmpty) 'ex': [for (final e in exercises) e.toJson()],
    'program': ?intervalProgram,
    'rpe': ?rpe,
    if (notes.isNotEmpty) 'notes': notes,
    if (hasRoute) 'route': true,
    if (source != WorkoutSource.app) 'source': source.name,
    'routine': ?routineId,
  };

  /// Returns null for malformed rows instead of throwing.
  static WorkoutSession? tryFromJson(Map<String, Object?> json) {
    final id = json['id'];
    final type = WorkoutType.fromName(json['type']);
    final start = DateTime.tryParse('${json['start']}');
    final end = DateTime.tryParse('${json['end']}');
    final active = json['active'];
    if (id is! String || type == null || start == null || end == null) {
      return null;
    }
    if (active is! int) return null;
    double num0(Object? v) => v is num ? v.toDouble() : 0;
    final splits = json['splits'];
    final laps = json['laps'];
    final ex = json['ex'];
    final rpe = json['rpe'];
    final notes = json['notes'];
    final program = json['program'];
    final routine = json['routine'];
    return WorkoutSession(
      id: id,
      type: type,
      start: start,
      end: end,
      activeSeconds: active,
      distanceMeters: num0(json['dist']),
      activeKcal: num0(json['kcal']),
      elevationGainMeters: num0(json['elev']),
      splits: splits is List ? splits.whereType<int>().toList() : const [],
      laps: laps is List
          ? laps.map(Lap.tryFromJson).nonNulls.toList()
          : const [],
      exercises: ex is List
          ? ex.map(ExerciseLog.tryFromJson).nonNulls.toList()
          : const [],
      intervalProgram: program is String ? program : null,
      rpe: rpe is int ? rpe : null,
      notes: notes is String ? notes : '',
      hasRoute: json['route'] == true,
      source:
          WorkoutSource.values
              .where((v) => v.name == json['source'])
              .firstOrNull ??
          WorkoutSource.app,
      routineId: routine is String ? routine : null,
    );
  }
}
