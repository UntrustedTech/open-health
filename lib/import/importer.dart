import 'package:health_app/import/csv_formats.dart';
import 'package:health_app/models/workout.dart';

/// Turns parsed workouts into sessions. [exerciseIds] maps each name in
/// the file to an exercise id. Ids come from the file's own start times, so
/// importing the same file again finds the same workouts (no duplicates).
List<WorkoutSession> toSessions(
  ParsedCsv parsed,
  Map<String, String> exerciseIds,
) => [
  for (final w in parsed.workouts)
    WorkoutSession(
      id: 'imp-${parsed.format.name}-${w.start.millisecondsSinceEpoch}',
      type: WorkoutType.strength,
      start: w.start,
      end: w.start.add(w.duration),
      activeSeconds: w.duration.inSeconds,
      notes: w.title,
      source: WorkoutSource.imported,
      exercises: [
        for (final e in w.exercises)
          if (exerciseIds[e.name] case final id?)
            ExerciseLog(exerciseId: id, sets: e.sets),
      ],
    ),
];
