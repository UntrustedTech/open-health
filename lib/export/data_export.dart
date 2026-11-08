import 'dart:convert';

import 'package:health_app/models/exercise_library.dart';
import 'package:health_app/models/health_entry.dart';
import 'package:health_app/models/workout.dart';

/// Everything the app stores, as one readable JSON document (for backups
/// or moving to another app). Note: the file itself isn't encrypted.
String exportAllData({
  required DateTime exportedAt,
  required List<HealthEntry> entries,
  required List<WorkoutSession> workouts,
  required List<Routine> routines,
  required Map<String, Map<String, Object?>> documents,
}) => const JsonEncoder.withIndent('  ').convert({
  'app': 'Health',
  'version': 1,
  'exportedAt': exportedAt.toIso8601String(),
  'entries': [for (final e in entries) e.toJson()],
  'workouts': [for (final w in workouts) w.toJson()],
  'routines': [for (final r in routines) r.toJson()],
  'documents': documents,
});
