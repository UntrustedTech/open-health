import 'package:flutter/foundation.dart';

/// How the body is placed for an exercise.
enum Posture {
  standing,
  seated,
  kneeling,

  /// On the back (on the floor, a bench or a ball).
  lyingBack,

  /// Face down.
  lyingFace,

  /// Push-up position.
  plank,
  hanging,
  handstand,
  unknown,
}

enum BenchAngle { none, flat, incline, decline }

/// Whether both sides work together, one side only, or taking turns.
enum Sides { both, single, alternating }

/// Which limbs a one-sided exercise uses.
enum Limbs { arms, legs }

enum Grip { normal, wide, close }

/// Things the description says to use, besides the weight.
enum Prop { stabilityBall, bosu, wall, box, parallelBars }

/// What an exercise's name and instructions say about how it's done, read
/// so its animation can follow them: how the body is placed, on what, with
/// one side or both, and at what pace.
@immutable
class ExerciseDescription {
  const ExerciseDescription({
    this.posture = Posture.unknown,
    this.bench = BenchAngle.none,
    this.sides = Sides.both,
    this.limbs = Limbs.arms,
    this.grip = Grip.normal,
    this.props = const {},
    this.slowLowering = false,
    this.explosive = false,
  });

  final Posture posture;
  final BenchAngle bench;
  final Sides sides;
  final Limbs limbs;
  final Grip grip;
  final Set<Prop> props;

  /// The instructions ask for a slow, controlled return.
  final bool slowLowering;

  /// The instructions ask for an explosive drive.
  final bool explosive;

  static final _cache = <String, ExerciseDescription>{};

  static ExerciseDescription read(String name, List<String> steps) =>
      _cache.putIfAbsent(
        '$name|${steps.join('|')}',
        () =>
            _read(name.toLowerCase(), [for (final s in steps) s.toLowerCase()]),
      );

  static ExerciseDescription _read(String name, List<String> steps) {
    final all = steps.join(' ');
    final setup = steps.take(2).join(' ');
    bool has(String text, String pattern) => RegExp(pattern).hasMatch(text);

    final alternating =
        has(name, r'alternat') ||
        has(
          all,
          r'\balternat(e|ing)\b (arms|legs|sides|between)|'
          r'continue alternating',
        );
    final singleArm = has(name, r'\b(one|single)[ -]?(arm|hand)|unilateral');
    final singleLeg = has(name, r'\b(one|single)[ -]?leg|pistol');
    final sides = alternating
        ? Sides.alternating
        : singleArm || singleLeg
        ? Sides.single
        : Sides.both;
    final limbs =
        singleLeg ||
            (alternating &&
                has('$name $all', r'\b(legs?|lunge|step)\b') &&
                !has('$name $all', r'\b(arms?|curl|press|row|raise)\b'))
        ? Limbs.legs
        : Limbs.arms;

    final bench = has(all, r'decline bench|head lower than')
        ? BenchAngle.decline
        : has(all, r'incline bench|incline\b.*\bbench') ||
              has(name, r'\bincline\b')
        ? BenchAngle.incline
        : has(name, r'\bdecline\b')
        ? BenchAngle.decline
        : has(all, r'flat bench|on a bench')
        ? BenchAngle.flat
        : BenchAngle.none;

    final props = {
      if (has(
        '$name $all',
        r'stability ball|exercise ball|swiss ball|'
            r'physio ball|on (a|the) ball',
      ))
        Prop.stabilityBall,
      if (has('$name $all', r'\bbosu\b')) Prop.bosu,
      if (has(all, r'\bwall\b') || has(name, r'\bwall\b')) Prop.wall,
      if (has(all, r'parallel bars|dip bars|dip station')) Prop.parallelBars,
      if (has(
        setup,
        r'\b(on|onto|off|in front of|facing) (a|the|an) (sturdy |raised |'
        r'elevated |low |high )?(box|step|platform|block)\b|plyo box',
      ))
        Prop.box,
    };

    return ExerciseDescription(
      posture: _posture(name, setup, all),
      bench: bench,
      sides: sides,
      limbs: limbs,
      grip: has(name, r'wide')
          ? Grip.wide
          : has(name, r'close|narrow')
          ? Grip.close
          : Grip.normal,
      props: props,
      slowLowering: has(
        all,
        r'(slowly|controlled?|with control)[^.]*\b(lower|return|release)|'
        r'\b(lower|return)[^.]*\b(slowly|with control|controlled)',
      ),
      explosive: has(all, r'explosive|explosively|powerfully|quickly drive'),
    );
  }

  static Posture _posture(String name, String setup, String all) {
    bool has(String text, String p) => RegExp(p).hasMatch(text);
    if (has('$name $setup', r'handstand')) return Posture.handstand;
    if (has(setup, r'face down|prone|lie on your (stomach|front)')) {
      return Posture.lyingFace;
    }
    // Rolled out until the back rests on a ball: lying, whatever the
    // first step says.
    if (has(
      all,
      r'(supported|resting) (on|by|against) the (exercise |stability )?ball|'
      r'roll (your body )?(down|out) until|lower back is supported',
    )) {
      return Posture.lyingBack;
    }
    // Hanging from a bar, often set up over a few steps (stand, grab,
    // hang); not weights or heels that "hang".
    if (has(name, r'^(?!.*(calf|curl|row|shrug)).*\bhanging\b') ||
        has(
          all,
          r'hang(ing)? (freely )?from (the|a|an|two) |dead hang|'
          r'(grab|grip|grasp|hold) (onto )?(the|a) (pull-?up|chin-?up|high) '
          r'bar',
        )) {
      return Posture.hanging;
    }
    if (has(setup, r'push-?up position|high plank|plank position')) {
      return Posture.plank;
    }
    if (has(setup, r'\blie\b|lying')) return Posture.lyingBack;
    if (has(setup, r'\bkneel|on your knees')) return Posture.kneeling;
    if (has(setup, r'\bsit\b|\bseated\b|sit on')) return Posture.seated;
    if (has(setup, r'\bstand\b|standing')) return Posture.standing;
    return Posture.unknown;
  }
}
