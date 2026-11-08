import 'dart:math';

import 'package:health_app/models/exercise_library.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/workout/progression.dart';

/// One exercise ready to train, with a short note on where its numbers
/// came from (shown above its sets).
typedef PlannedExercise = ({ExerciseLog log, String? hint});

/// Builds a workout from [routine]: targets from each exercise's
/// progression rule, otherwise last time's sets, otherwise the routine's
/// own numbers; plus warm-up sets, rest times and supersets.
List<PlannedExercise> buildSession(
  Routine routine, {
  required List<List<SetLog>> Function(String exerciseId) recentSets,
  bool Function(String exerciseId)? isTimed,
}) {
  return [
    for (final item in routine.items)
      _plan(item, recentSets(item.exerciseId), isTimed),
  ];
}

PlannedExercise _plan(
  RoutineItem item,
  List<List<SetLog>> history,
  bool Function(String)? isTimed,
) {
  final timed = isTimed?.call(item.exerciseId) ?? false;
  final last = history.firstOrNull?.where((s) => s.type.counts).toList();
  String? hint;
  List<SetLog> working;

  if (timed) {
    working = [
      for (var i = 0; i < item.sets; i++)
        SetLog(
          reps: 0,
          weightKg: item.weightKg,
          seconds: last?.elementAtOrNull(i)?.seconds ?? item.reps,
        ),
    ];
  } else if (item.progression.kind == ProgressionKind.none &&
      last != null &&
      last.isNotEmpty) {
    working = [
      for (var i = 0; i < max(item.sets, last.length); i++)
        (last.elementAtOrNull(i) ?? last.last).copyWith(
          done: false,
          type: SetType.normal,
          clearRpe: true, // effort is entered fresh each time
        ),
    ];
  } else {
    final target = suggestNext(
      rule: item.progression,
      targetReps: item.reps,
      history: history,
      fallbackKg: item.weightKg,
    );
    working = [
      for (var i = 0; i < item.sets; i++)
        SetLog(reps: target.reps, weightKg: target.weightKg),
    ];
    if (history.isNotEmpty) hint = target.explanation;
  }

  final top = working.isEmpty
      ? 0.0
      : working.map((s) => s.weightKg).reduce(max);
  final warmups = [
    for (var i = 0; i < item.warmupSets; i++)
      SetLog(
        reps: 8 - 2 * min(i, 2),
        // Ramp up: 40%, 60%, 80% of the working weight.
        weightKg: _round(top * (0.4 + 0.2 * min(i, 2))),
        type: SetType.warmup,
      ),
  ];
  return (
    log: ExerciseLog(
      exerciseId: item.exerciseId,
      sets: [...warmups, ...working],
      restSeconds: item.restSeconds,
      superset: item.superset,
    ),
    hint: hint,
  );
}

double _round(double kg) => (kg / 2.5).round() * 2.5;
