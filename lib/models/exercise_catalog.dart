import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:health_app/models/muscles.dart';

/// One exercise: from the bundled library (MIT exercise text, no media),
/// one of the app's own, or created by the user.
@immutable
class CatalogExercise {
  const CatalogExercise({
    required this.id,
    required this.name,
    required this.bodyPart,
    required this.equipment,
    required this.target,
    this.secondary = const [],
    this.steps = const [],
    this.custom = false,
    this.timed = false,
    this.perSide = false,
  });

  final String id;
  final String name;

  /// Dataset body part, e.g. "chest", "upper legs".
  final String bodyPart;

  /// e.g. "barbell", "dumbbell", "body weight".
  final String equipment;
  final String target;
  final List<String> secondary;
  final List<String> steps;
  final bool custom;

  /// Logged as time held (planks, hangs) rather than reps.
  final bool timed;

  /// Reps counted for each side (lunges, single-arm work).
  final bool perSide;

  bool get bodyweight => equipment == 'body weight' || equipment == 'assisted';

  List<Muscle> get primaryMuscles => [?Muscle.fromName(target)];

  List<Muscle> get secondaryMuscles =>
      {for (final s in secondary) ?Muscle.fromName(s)}
          .difference(primaryMuscles.toSet())
          .toList();

  Set<Muscle> get muscles => {...primaryMuscles, ...secondaryMuscles};

  Map<String, Object?> toJson() => {
    'id': id,
    'n': name,
    'b': bodyPart,
    'e': equipment,
    't': target,
    if (secondary.isNotEmpty) 's': secondary,
    if (steps.isNotEmpty) 'i': steps,
    if (custom) 'custom': true,
    if (timed) 'timed': true,
    if (perSide) 'side': true,
  };

  static CatalogExercise? fromJson(
    Map<String, Object?> json, {
    bool titleCase = false,
  }) {
    final id = json['id'],
        n = json['n'],
        b = json['b'],
        e = json['e'],
        t = json['t'];
    if (id is! String ||
        n is! String ||
        b is! String ||
        e is! String ||
        t is! String) {
      return null;
    }
    List<String> list(Object? v) =>
        v is List ? v.whereType<String>().toList() : const [];
    return CatalogExercise(
      id: id,
      name: titleCase ? _title(n) : n,
      bodyPart: b,
      equipment: e,
      target: t,
      secondary: list(json['s']),
      steps: list(json['i']),
      custom: json['custom'] == true,
      timed: json['timed'] == true,
      perSide: json['side'] == true,
    );
  }

  /// "barbell bench press" → "Barbell Bench Press" (keeps "EZ", "(with rope)").
  static String _title(String s) => s
      .split(' ')
      .map(
        (w) => w.isEmpty || w.startsWith('(')
            ? w
            : w[0].toUpperCase() + w.substring(1),
      )
      .join(' ')
      .replaceAll('Ez ', 'EZ ');
}

/// All exercises the app knows. Ids saved by earlier versions (such as
/// "bench_press") are never rewritten; they resolve through [aliases].
class ExerciseCatalog {
  ExerciseCatalog._(this.builtIn, this.customExercises)
    : _byId = {
        for (final e in builtIn) e.id: e,
        for (final e in customExercises) e.id: e,
      };

  /// Loaded at startup; until then names fall back to the app's own list.
  static ExerciseCatalog instance = ExerciseCatalog._(extras, const []);

  /// Old exercise ids → the matching exercise in the bundled library.
  static const aliases = {
    'bench_press': '0025',
    'incline_db_press': '0314',
    'push_up': '0662',
    'chest_fly': '0227',
    'dip': '0251',
    'deadlift': '0032',
    'pull_up': '0652',
    'barbell_row': '0027',
    'lat_pulldown': '2330',
    'seated_row': '0861',
    'squat': '0043',
    'front_squat': '0042',
    'leg_press': '0739',
    'rdl': '0085',
    'lunge': '1460',
    'leg_curl': '0586',
    'calf_raise': '0605',
    'hip_thrust': '1409',
    'lateral_raise': '0334',
    'face_pull': '0203',
    'bicep_curl': '0294',
    'hammer_curl': '0313',
    'tricep_pushdown': '0201',
    'skull_crusher': '0060',
    'crunch': '0274',
    'hanging_leg_raise': '0472',
    'russian_twist': '0687',
    'kettlebell_swing': '0549',
    'burpee': '1160',
    'clean_press': '0028',
  };

  /// The app's own exercises (no exact match in the bundled library).
  static const extras = [
    CatalogExercise(
      id: 'ohp',
      name: 'Overhead Press',
      bodyPart: 'shoulders',
      equipment: 'barbell',
      target: 'delts',
      secondary: ['triceps', 'upper chest', 'core'],
      steps: [
        'Stand with the bar on your front shoulders, hands just outside shoulder width.',
        'Brace your core and squeeze your glutes.',
        'Press the bar straight up, moving your head back slightly to clear it.',
        'Lock out overhead with the bar over your mid-foot.',
        'Lower under control to your shoulders.',
      ],
    ),
    CatalogExercise(
      id: 'plank',
      name: 'Plank',
      bodyPart: 'waist',
      equipment: 'body weight',
      target: 'abs',
      secondary: ['obliques', 'shoulders', 'glutes'],
      timed: true,
      steps: [
        'Rest on your forearms with elbows under your shoulders.',
        'Step your feet back so your body forms a straight line.',
        'Brace your abs and squeeze your glutes.',
        'Hold without letting your hips sag or rise.',
      ],
    ),
  ];

  final List<CatalogExercise> builtIn;
  final List<CatalogExercise> customExercises;
  final Map<String, CatalogExercise> _byId;

  List<CatalogExercise> get all => [...customExercises, ...builtIn];

  /// Parses the bundled JSON asset (adds the app's own exercises).
  factory ExerciseCatalog.fromBundledJson(String json) {
    final decoded = jsonDecode(json);
    final list = decoded is List
        ? decoded
              .whereType<Map<String, Object?>>()
              .map((e) => CatalogExercise.fromJson(e, titleCase: true))
              .nonNulls
              .toList()
        : <CatalogExercise>[];
    return ExerciseCatalog._([...extras, ...list], const []);
  }

  static Future<ExerciseCatalog> loadBundled([AssetBundle? bundle]) async {
    final json = await (bundle ?? rootBundle).loadString(
      'assets/data/exercises.json',
    );
    return compute(ExerciseCatalog.fromBundledJson, json);
  }

  ExerciseCatalog withCustom(List<CatalogExercise> custom) =>
      ExerciseCatalog._(builtIn, custom);

  /// The id records are grouped by (old ids map to their library entry).
  static String canonical(String id) => aliases[id] ?? id;

  CatalogExercise? byId(String id) => _byId[canonical(id)];

  String nameOf(String id) => byId(id)?.name ?? 'Exercise';

  /// Body parts in the library, for filter chips.
  List<String> get bodyParts =>
      {for (final e in builtIn) e.bodyPart}.toList()..sort();

  List<String> get equipmentTypes =>
      {for (final e in all) e.equipment}.toList()..sort();

  static const _commonEquipment = [
    'barbell',
    'dumbbell',
    'body weight',
    'cable',
    'leverage machine',
    'smith machine',
    'kettlebell',
    'ez barbell',
  ];

  static int _equipmentRank(CatalogExercise e) {
    if (e.custom) return 0;
    final i = _commonEquipment.indexOf(e.equipment);
    return i < 0 ? _commonEquipment.length : i;
  }

  /// Matching exercises, best match first. Every word of [query] must
  /// appear in the name; names starting with the query rank first.
  List<CatalogExercise> search({
    String query = '',
    String? bodyPart,
    Muscle? muscle,
    Set<String>? equipment,
  }) {
    final q = query.trim().toLowerCase();
    final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final results = <(int, CatalogExercise)>[];
    for (final e in all) {
      if (bodyPart != null && e.bodyPart != bodyPart) continue;
      if (muscle != null && !e.muscles.contains(muscle)) continue;
      if (equipment != null && !equipment.contains(e.equipment)) continue;
      final name = e.name.toLowerCase();
      if (!words.every(name.contains)) continue;
      final score = q.isEmpty
          ? 2
          : name == q
          ? 0
          : name.contains(q)
          ? 1
          : 2;
      // Common equipment first, then shorter names (usually the basic
      // version of a movement).
      results.add((score * 10000 + _equipmentRank(e) * 100 + name.length, e));
    }
    // Browsing (no search) reads best in alphabetical order.
    if (q.isEmpty) {
      results.sort((a, b) => a.$2.name.compareTo(b.$2.name));
    } else {
      results.sort((a, b) => a.$1.compareTo(b.$1));
    }
    return [for (final r in results) r.$2];
  }
}
