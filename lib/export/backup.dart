import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:health_app/models/exercise_library.dart';
import 'package:health_app/models/health_entry.dart';
import 'package:health_app/models/workout.dart';

/// A parsed "Export All Data" file, validated and ready to restore.
@immutable
class Backup {
  const Backup({
    required this.exportedAt,
    required this.entries,
    required this.workouts,
    required this.routines,
    required this.documents,
    this.skipped = 0,
  });

  /// Storage key of a workout's GPS route.
  static String routeKey(String workoutId) => 'route.$workoutId';

  /// Route documents a backup holds for [workouts]; only the routes of
  /// workouts in the same backup are restored.
  static List<String> routeKeys(Iterable<WorkoutSession> workouts) => [
    for (final w in workouts)
      if (w.hasRoute) routeKey(w.id),
  ];

  /// Settings documents included in a backup; besides these, only the
  /// routes of the backup's own workouts are restored.
  static const documentKeys = [
    'profile',
    'goals',
    'bodyGoal',
    'settings',
    'workoutSettings',
    'trainingPlan',
    'customExercises',
    'equipmentOwned',
    'notificationSettings',
    'medications',
    'cycle',
    'achievements',
    'heartZones',
    'nutrition',
    'mood',
    'gym',
    'fasting',
    'sleepSchedule',
    'program',
    'themes',
  ];

  static final _presetIds = {for (final r in Routine.presets) r.id};

  final DateTime? exportedAt;
  final List<HealthEntry> entries;
  final List<WorkoutSession> workouts;
  final List<Routine> routines;
  final Map<String, Map<String, Object?>> documents;

  /// Records that couldn't be read (damaged, or from a newer app) or
  /// repeated an id, and so won't be restored.
  final int skipped;

  bool get isEmpty =>
      entries.isEmpty &&
      workouts.isEmpty &&
      routines.isEmpty &&
      documents.isEmpty;

  /// Reads a backup made by [exportAllData]. Unreadable records are
  /// skipped; throws [FormatException] if this isn't a Health backup.
  static Backup parse(String text) {
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      throw const FormatException('Not a Health backup');
    }
    if (root is! Map<String, Object?> || root['app'] != 'Health') {
      throw const FormatException('Not a Health backup');
    }
    if (root['version'] != 1) {
      throw const FormatException('Made by a newer version of Health');
    }
    var skipped = 0;
    List<Object?> raw(Object? v) => v is List ? v : const [];

    /// Parses each record, keeping the first of any repeated id.
    List<T> read<T>(
      Object? list,
      T? Function(Map<String, Object?>) parse,
      String Function(T) id,
    ) {
      final seen = <String>{};
      final out = <T>[];
      for (final item in raw(list)) {
        final value = item is Map<String, Object?> ? parse(item) : null;
        if (value == null || !seen.add(id(value))) {
          skipped++;
          continue;
        }
        out.add(value);
      }
      return out;
    }

    final docs = root['documents'];
    final entries = read(root['entries'], HealthEntry.tryFromJson, (e) => e.id);
    final workouts = read(
      root['workouts'],
      WorkoutSession.tryFromJson,
      (w) => w.id,
    );
    final routines = read(root['routines'], Routine.tryFromJson, (r) => r.id)
        // Built-in routines ship with the app.
        .where((r) => !r.builtIn && !_presetIds.contains(r.id))
        .toList();
    return Backup(
      exportedAt: DateTime.tryParse('${root['exportedAt']}'),
      entries: entries,
      workouts: workouts,
      routines: routines,
      skipped: skipped,
      documents: {
        if (docs is Map<String, Object?>)
          for (final key in [...documentKeys, ...routeKeys(workouts)])
            if (docs[key] case final Map<String, Object?> doc) key: doc,
      },
    );
  }
}
