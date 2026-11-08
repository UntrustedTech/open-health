import 'package:flutter/foundation.dart';

import 'package:health_app/models/exercise_library.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/workout/intervals.dart';

/// One session of a [WorkoutProgram]: an interval run or guided flow, or a
/// strength routine.
@immutable
class ProgramSession {
  const ProgramSession.interval(IntervalProgram this.interval, this.type)
    : routineId = null;

  const ProgramSession.routine(String this.routineId)
    : interval = null,
      type = WorkoutType.strength;

  final IntervalProgram? interval;
  final String? routineId;
  final WorkoutType type;

  /// The routine, when this is a strength session.
  Routine? get routine => switch (routineId) {
    final id? => Routine.presets.where((r) => r.id == id).firstOrNull,
    null => null,
  };

  String get title => interval?.name ?? routine?.name ?? type.label;

  /// Roughly how long it takes, in minutes (null for routines).
  int? get minutes => switch (interval) {
    final p? => (p.total.inSeconds / 60).round(),
    null => null,
  };

  /// Whether [w] counts as doing this session.
  bool matches(WorkoutSession w) => switch (interval) {
    final p? => w.intervalProgram == p.name,
    null => w.routineId == routineId,
  };
}

/// A multi-week plan: a few sessions each week, getting harder.
@immutable
class WorkoutProgram {
  const WorkoutProgram({
    required this.id,
    required this.name,
    required this.summary,
    required this.weeks,
    required this.type,
  });

  final String id;
  final String name;
  final String summary;

  /// Each week's sessions, in order.
  final List<List<ProgramSession>> weeks;

  /// The kind of training, for the icon and colour.
  final WorkoutType type;

  /// Every session, in order.
  List<ProgramSession> get sessions => [for (final w in weeks) ...w];

  int get sessionCount => weeks.fold(0, (n, w) => n + w.length);
  int get sessionsPerWeek => weeks.first.length;

  static WorkoutProgram? byId(Object? id) =>
      all.where((p) => p.id == id).firstOrNull;

  static final all = [couchTo5k, beginnerStrength, mobilityCore];

  static final couchTo5k = WorkoutProgram(
    id: 'c25k',
    name: 'Couch to 5K',
    summary:
        'Nine weeks from walking to running 30 minutes, three runs a week.',
    type: WorkoutType.run,
    weeks: [
      for (final p in IntervalProgram.couchTo5k)
        [
          for (var i = 0; i < 3; i++)
            ProgramSession.interval(p, WorkoutType.run),
        ],
    ],
  );

  static final beginnerStrength = WorkoutProgram(
    id: 'beginner_strength',
    name: 'Beginner Strength',
    summary:
        'Six weeks, three sessions a week: full-body to start, then a '
        'push, pull and legs split. Weights go up as you get stronger.',
    type: WorkoutType.strength,
    weeks: [
      for (var w = 0; w < 3; w++)
        const [
          ProgramSession.routine('preset_full'),
          ProgramSession.routine('preset_full'),
          ProgramSession.routine('preset_full'),
        ],
      for (var w = 0; w < 3; w++)
        const [
          ProgramSession.routine('preset_push'),
          ProgramSession.routine('preset_pull'),
          ProgramSession.routine('preset_legs'),
        ],
    ],
  );

  static final mobilityCore = WorkoutProgram(
    id: 'mobility_core',
    name: 'Mobility & Core',
    summary:
        'Four weeks of mobility and Pilates, three short sessions a week. '
        'Good for recovery days or alongside other training.',
    type: WorkoutType.pilates,
    weeks: [
      for (var w = 0; w < 4; w++)
        [
          ProgramSession.interval(
            _flow('Morning Mobility'),
            WorkoutType.stretching,
          ),
          ProgramSession.interval(
            _flow('Pilates Core 15'),
            WorkoutType.pilates,
          ),
          ProgramSession.interval(
            _flow(w < 2 ? 'Sun Salutation' : 'Classical Pilates Mat'),
            w < 2 ? WorkoutType.yoga : WorkoutType.pilates,
          ),
        ],
    ],
  );

  static IntervalProgram _flow(String name) =>
      IntervalProgram.flows.firstWhere((f) => f.name == name);
}

/// Where the user is in a program: each session matched, in order, to a
/// workout done after the program started.
@immutable
class ProgramProgress {
  const ProgramProgress._(this.program, this.done);

  final WorkoutProgram program;

  /// The workout that completed each session so far, in order.
  final List<WorkoutSession> done;

  /// Matches workouts since [start] to the program's sessions in order:
  /// each session takes the first later workout that fits it.
  factory ProgramProgress.of(
    WorkoutProgram program,
    DateTime start,
    Iterable<WorkoutSession> workouts,
  ) {
    final sorted = workouts.where((w) => !w.start.isBefore(start)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final done = <WorkoutSession>[];
    var from = 0;
    for (final session in program.sessions) {
      final i = sorted.indexWhere(session.matches, from);
      if (i < 0) break;
      done.add(sorted[i]);
      from = i + 1;
    }
    return ProgramProgress._(program, List.unmodifiable(done));
  }

  int get completed => done.length;
  bool get finished => completed >= program.sessionCount;
  double get fraction => completed / program.sessionCount;

  /// The current week, 0-based (the last week once finished).
  int get week {
    var left = completed;
    for (final (i, w) in program.weeks.indexed) {
      if (left < w.length) return i;
      left -= w.length;
    }
    return program.weeks.length - 1;
  }

  /// Sessions done in the current week.
  int get doneThisWeek {
    var left = completed;
    for (final w in program.weeks.take(week)) {
      left -= w.length;
    }
    return left.clamp(0, program.weeks[week].length);
  }

  /// The next session to do, or null when finished.
  ProgramSession? get next => finished ? null : program.sessions[completed];
}
