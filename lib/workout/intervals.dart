import 'package:flutter/foundation.dart';

import 'package:health_app/models/workout.dart';

enum PhaseKind { warmup, work, rest, cooldown }

/// One move of a guided flow.
typedef FlowMove = ({String name, Duration duration});

@immutable
class IntervalPhase {
  const IntervalPhase(this.kind, this.duration, {this.round = 0, this.name});

  final PhaseKind kind;
  final Duration duration;

  /// 1-based round number for work and rest phases.
  final int round;

  /// A guided flow's move ("Roll-Up"), or what's next during a transition.
  final String? name;

  String get label =>
      name ??
      switch (kind) {
        PhaseKind.warmup => 'Warm Up',
        PhaseKind.work => 'Work',
        PhaseKind.rest => 'Rest',
        PhaseKind.cooldown => 'Cool Down',
      };
}

/// A timed work/rest program such as Tabata.
@immutable
class IntervalProgram {
  const IntervalProgram({
    required this.name,
    required this.work,
    required this.rest,
    required this.rounds,
    this.warmup = Duration.zero,
    this.cooldown = Duration.zero,
    this.moves = const [],
    this.types = const {WorkoutType.hiit},
    this.workLabel,
    this.restLabel,
  });

  /// A guided flow: named moves one after another, with a short pause to
  /// get into each.
  const IntervalProgram.flow({
    required this.name,
    required this.moves,
    required this.types,
    this.warmup = Duration.zero,
    this.cooldown = Duration.zero,
    Duration transition = const Duration(seconds: 8),
  }) : work = Duration.zero,
       rest = transition,
       rounds = 0,
       workLabel = null,
       restLabel = null;

  /// One week of Couch to 5K: 5 minutes of walking either side of the runs.
  const IntervalProgram._c25k(
    int week,
    this.work,
    this.rest,
    this.rounds, {
    this.restLabel = 'Walk',
  }) : name = 'C25K Week $week',
       warmup = const Duration(minutes: 5),
       cooldown = const Duration(minutes: 5),
       moves = const [],
       types = const {WorkoutType.run},
       workLabel = 'Run';

  /// Names for work and rest phases ("Run", "Walk"); Work and Rest when
  /// null.
  final String? workLabel;
  final String? restLabel;

  /// The flow's moves, in order (empty for interval programs).
  final List<FlowMove> moves;

  /// Workouts this program is offered for.
  final Set<WorkoutType> types;

  bool get isFlow => moves.isNotEmpty;

  /// Rounds, or moves for a flow.
  int get roundCount => isFlow ? moves.length : rounds;

  /// The program called [name]: a preset or a Couch to 5K run.
  static IntervalProgram? byName(Object? name) =>
      [...presets, ...couchTo5k].where((p) => p.name == name).firstOrNull;

  /// Couch to 5K: one run per week, done three times, based on the NHS
  /// plan: a 5-minute brisk walk, alternating running and walking, and a
  /// 5-minute walk to finish.
  static const couchTo5k = [
    IntervalProgram._c25k(1, Duration(seconds: 60), Duration(seconds: 90), 8),
    IntervalProgram._c25k(2, Duration(seconds: 90), Duration(minutes: 2), 6),
    IntervalProgram._c25k(3, Duration(minutes: 3), Duration(seconds: 90), 4),
    IntervalProgram._c25k(4, Duration(minutes: 5), Duration(seconds: 150), 3),
    IntervalProgram._c25k(5, Duration(minutes: 8), Duration(minutes: 5), 2),
    IntervalProgram._c25k(6, Duration(minutes: 10), Duration(minutes: 3), 2),
    IntervalProgram._c25k(
      7,
      Duration(minutes: 25),
      Duration.zero,
      1,
      restLabel: null,
    ),
    IntervalProgram._c25k(
      8,
      Duration(minutes: 28),
      Duration.zero,
      1,
      restLabel: null,
    ),
    IntervalProgram._c25k(
      9,
      Duration(minutes: 30),
      Duration.zero,
      1,
      restLabel: null,
    ),
  ];

  /// Programs for [type].
  static List<IntervalProgram> forType(WorkoutType type) => [
    for (final p in presets)
      if (p.types.contains(type)) p,
  ];

  static const presets = [
    IntervalProgram(
      name: 'Tabata',
      work: Duration(seconds: 20),
      rest: Duration(seconds: 10),
      rounds: 8,
      warmup: Duration(minutes: 1),
    ),
    IntervalProgram(
      name: 'HIIT 30/30',
      work: Duration(seconds: 30),
      rest: Duration(seconds: 30),
      rounds: 10,
      warmup: Duration(minutes: 2),
      cooldown: Duration(minutes: 2),
    ),
    IntervalProgram(
      name: 'EMOM 40/20',
      work: Duration(seconds: 40),
      rest: Duration(seconds: 20),
      rounds: 12,
    ),
    IntervalProgram(
      name: 'Pyramid Sprints',
      work: Duration(seconds: 60),
      rest: Duration(seconds: 90),
      rounds: 6,
      warmup: Duration(minutes: 5),
      cooldown: Duration(minutes: 5),
    ),
    ...flows,
  ];

  /// Guided flows for Pilates, barre, mobility, yoga and tai chi. Moves
  /// follow the classical sequences (e.g. Joseph Pilates' mat order).
  static const flows = [
    IntervalProgram.flow(
      name: 'Classical Pilates Mat',
      types: {WorkoutType.pilates},
      warmup: Duration(seconds: 60),
      cooldown: Duration(seconds: 60),
      moves: [
        (name: 'The Hundred', duration: Duration(seconds: 60)),
        (name: 'Roll-Up', duration: Duration(seconds: 45)),
        (name: 'Leg Circles · Right', duration: Duration(seconds: 30)),
        (name: 'Leg Circles · Left', duration: Duration(seconds: 30)),
        (name: 'Rolling Like a Ball', duration: Duration(seconds: 40)),
        (name: 'Single-Leg Stretch', duration: Duration(seconds: 45)),
        (name: 'Double-Leg Stretch', duration: Duration(seconds: 45)),
        (name: 'Spine Stretch Forward', duration: Duration(seconds: 40)),
        (name: 'Saw', duration: Duration(seconds: 45)),
        (name: 'Swan', duration: Duration(seconds: 40)),
        (name: 'Side Kicks · Right', duration: Duration(seconds: 40)),
        (name: 'Side Kicks · Left', duration: Duration(seconds: 40)),
        (name: 'Teaser', duration: Duration(seconds: 40)),
        (name: 'Seal', duration: Duration(seconds: 30)),
      ],
    ),
    IntervalProgram.flow(
      name: 'Pilates Core 15',
      types: {WorkoutType.pilates},
      warmup: Duration(seconds: 45),
      cooldown: Duration(seconds: 45),
      moves: [
        (name: 'The Hundred', duration: Duration(seconds: 60)),
        (name: 'Criss-Cross', duration: Duration(seconds: 45)),
        (name: 'Single-Straight-Leg Stretch', duration: Duration(seconds: 45)),
        (name: 'Double-Leg Stretch', duration: Duration(seconds: 45)),
        (name: 'Toe Taps', duration: Duration(seconds: 45)),
        (name: 'Plank', duration: Duration(seconds: 45)),
        (name: 'Side Plank · Right', duration: Duration(seconds: 30)),
        (name: 'Side Plank · Left', duration: Duration(seconds: 30)),
        (name: 'Swimming', duration: Duration(seconds: 40)),
        (name: 'Teaser', duration: Duration(seconds: 40)),
        (name: 'Roll-Up', duration: Duration(seconds: 45)),
      ],
    ),
    IntervalProgram.flow(
      name: 'Barre Sculpt',
      types: {WorkoutType.barre},
      warmup: Duration(seconds: 60),
      cooldown: Duration(seconds: 60),
      moves: [
        (name: 'Pliés', duration: Duration(seconds: 60)),
        (name: 'Relevés', duration: Duration(seconds: 45)),
        (name: 'Plié Pulses', duration: Duration(seconds: 45)),
        (name: 'Arabesque Lifts · Right', duration: Duration(seconds: 40)),
        (name: 'Arabesque Lifts · Left', duration: Duration(seconds: 40)),
        (name: 'Curtsy Lunges', duration: Duration(seconds: 45)),
        (name: 'Arm Circles', duration: Duration(seconds: 45)),
        (name: 'Tricep Dips', duration: Duration(seconds: 45)),
        (name: 'Seat Work · Right', duration: Duration(seconds: 40)),
        (name: 'Seat Work · Left', duration: Duration(seconds: 40)),
        (name: 'Calf Raises', duration: Duration(seconds: 45)),
      ],
    ),
    IntervalProgram.flow(
      name: 'Morning Mobility',
      types: {WorkoutType.stretching, WorkoutType.yoga},
      moves: [
        (name: 'Cat-Cow', duration: Duration(seconds: 45)),
        (name: 'Thread the Needle · Right', duration: Duration(seconds: 30)),
        (name: 'Thread the Needle · Left', duration: Duration(seconds: 30)),
        (
          name: "World's Greatest Stretch · Right",
          duration: Duration(seconds: 40),
        ),
        (
          name: "World's Greatest Stretch · Left",
          duration: Duration(seconds: 40),
        ),
        (name: 'Hip Flexor Stretch · Right', duration: Duration(seconds: 40)),
        (name: 'Hip Flexor Stretch · Left', duration: Duration(seconds: 40)),
        (name: 'Hamstring Stretch', duration: Duration(seconds: 45)),
        (name: 'Thoracic Rotations', duration: Duration(seconds: 40)),
        (name: "Child's Pose", duration: Duration(seconds: 45)),
      ],
    ),
    IntervalProgram.flow(
      name: 'Sun Salutation',
      types: {WorkoutType.yoga},
      transition: Duration(seconds: 3),
      cooldown: Duration(seconds: 60),
      moves: [
        (name: 'Mountain Pose', duration: Duration(seconds: 20)),
        (name: 'Upward Salute', duration: Duration(seconds: 15)),
        (name: 'Forward Fold', duration: Duration(seconds: 20)),
        (name: 'Halfway Lift', duration: Duration(seconds: 15)),
        (name: 'Plank', duration: Duration(seconds: 20)),
        (name: 'Chaturanga', duration: Duration(seconds: 15)),
        (name: 'Upward-Facing Dog', duration: Duration(seconds: 20)),
        (name: 'Downward-Facing Dog', duration: Duration(seconds: 40)),
        (name: 'Forward Fold', duration: Duration(seconds: 20)),
        (name: 'Upward Salute', duration: Duration(seconds: 15)),
        (name: 'Mountain Pose', duration: Duration(seconds: 20)),
      ],
    ),
    IntervalProgram.flow(
      name: 'Tai Chi Basics',
      types: {WorkoutType.taiChi},
      transition: Duration(seconds: 5),
      moves: [
        (name: 'Commencement', duration: Duration(seconds: 60)),
        (name: "Part the Wild Horse's Mane", duration: Duration(seconds: 90)),
        (
          name: 'White Crane Spreads Its Wings',
          duration: Duration(seconds: 60),
        ),
        (name: 'Brush Knee and Push', duration: Duration(seconds: 90)),
        (name: 'Repulse Monkey', duration: Duration(seconds: 90)),
        (name: 'Cloud Hands', duration: Duration(seconds: 90)),
        (name: 'Closing', duration: Duration(seconds: 60)),
      ],
    ),
  ];

  final String name;
  final Duration work;
  final Duration rest;
  final int rounds;
  final Duration warmup;
  final Duration cooldown;

  /// No rest after the final round.
  List<IntervalPhase> get phases => isFlow ? _flowPhases : _intervalPhases;

  List<IntervalPhase> get _flowPhases => [
    if (warmup > Duration.zero)
      IntervalPhase(PhaseKind.warmup, warmup, name: 'Breathe & Center'),
    for (final (i, m) in moves.indexed) ...[
      if (i > 0 && rest > Duration.zero)
        IntervalPhase(
          PhaseKind.rest,
          rest,
          round: i + 1,
          name: 'Next: ${m.name}',
        ),
      IntervalPhase(PhaseKind.work, m.duration, round: i + 1, name: m.name),
    ],
    if (cooldown > Duration.zero)
      IntervalPhase(PhaseKind.cooldown, cooldown, name: 'Relax & Breathe'),
  ];

  List<IntervalPhase> get _intervalPhases => [
    if (warmup > Duration.zero) IntervalPhase(PhaseKind.warmup, warmup),
    for (var r = 1; r <= rounds; r++) ...[
      IntervalPhase(PhaseKind.work, work, round: r, name: workLabel),
      if (r < rounds && rest > Duration.zero)
        IntervalPhase(PhaseKind.rest, rest, round: r, name: restLabel),
    ],
    if (cooldown > Duration.zero) IntervalPhase(PhaseKind.cooldown, cooldown),
  ];

  Duration get total =>
      phases.fold(Duration.zero, (sum, p) => sum + p.duration);

  /// The phase running at [elapsed], or null once the program is over.
  ({int index, IntervalPhase phase, Duration remaining})? phaseAt(
    Duration elapsed,
  ) {
    var end = Duration.zero;
    final list = phases;
    for (var i = 0; i < list.length; i++) {
      end += list[i].duration;
      if (elapsed < end) {
        return (index: i, phase: list[i], remaining: end - elapsed);
      }
    }
    return null;
  }

  String get summary {
    if (isFlow) return '${moves.length} moves';
    String s(Duration d) => d.inSeconds % 60 == 0 && d.inMinutes > 0
        ? '${d.inMinutes} min'
        : '${d.inSeconds}s';
    return '$rounds × ${s(work)} work / ${s(rest)} rest';
  }
}
