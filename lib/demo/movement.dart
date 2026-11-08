import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import 'package:health_app/demo/figure.dart';

enum View { side, front }

/// Where held equipment sits.
enum Slot { none, hands, shoulders }

/// Equipment drawn with the figure.
enum Hold {
  none,
  barbell,
  dumbbells,
  kettlebell,
  ball,
  cable,
  band,

  /// Leg press footplate, at the toes.
  platform,

  /// Machine roller pad, at the ankles.
  pad,
}

/// Parts of the figure that can be highlighted as doing the work.
enum Seg { arms, legs, torso }

/// Fixed equipment drawn behind the figure, in world units.
sealed class Scenery {
  const Scenery();

  Iterable<Offset> get points;
}

/// A bench, seat or pad top from [a] to [b], with legs to the floor.
class Surface extends Scenery {
  const Surface(this.a, this.b, {this.legs = true});

  final Offset a;
  final Offset b;
  final bool legs;

  @override
  Iterable<Offset> get points => [a, b, if (legs) Offset(a.dx, 0)];
}

/// A pull-up or dip bar seen end-on.
class Bar extends Scenery {
  const Bar(this.at);

  final Offset at;

  @override
  Iterable<Offset> get points => [at];
}

/// A stability ball resting on the floor, [radius] around [center].
class Ball extends Scenery {
  const Ball(this.center, this.radius);

  final Offset center;
  final double radius;

  @override
  Iterable<Offset> get points => [
    center + Offset(-radius, 0),
    center + Offset(radius, 0),
    center + Offset(0, -radius),
    Offset(center.dx, 0),
  ];
}

/// A bosu: a half ball, dome up, on the floor at [center], [radius] wide.
class Dome extends Scenery {
  const Dome(this.center, this.radius);

  final Offset center;
  final double radius;

  @override
  Iterable<Offset> get points => [
    center + Offset(-radius, 0),
    center + Offset(radius, 0),
    center + Offset(0, -radius * 0.6),
  ];
}

/// A bicycle, side on: [seat] top, pedal crank centre and handlebar
/// grips. Wheels stand on the floor.
class Bike extends Scenery {
  const Bike({
    required this.seat,
    required this.crank,
    required this.handlebar,
  });

  final Offset seat;
  final Offset crank;
  final Offset handlebar;

  /// Wheel radius.
  static const wheel = 0.2;

  Offset get rearHub => Offset(seat.dx - 0.24, -wheel);
  Offset get frontHub => Offset(handlebar.dx + 0.1, -wheel);

  @override
  Iterable<Offset> get points => [
    seat,
    handlebar,
    rearHub - const Offset(wheel, 0),
    frontHub + const Offset(wheel, 0),
  ];
}

/// A box or step.
class Block extends Scenery {
  const Block(this.rect);

  final Rect rect;

  @override
  Iterable<Offset> get points => [rect.topLeft, rect.bottomRight];
}

/// A repeating exercise movement: keyframe poses played as a loop.
@immutable
class Movement {
  const Movement(
    this.id,
    this.poses, {
    this.view = View.side,
    this.loop = false,
    this.slot = Slot.hands,
    this.fixed,
    this.anchor,
    this.scenery = const [],
    this.focus = const {},
    this.seconds = 2.6,
    this.pace,
    this.upperTilt = 0,
  });

  final String id;
  final List<Pose> poses;
  final View view;

  /// Plays poses in order and wraps (running); otherwise there and back.
  final bool loop;

  /// Where equipment from the exercise is held.
  final Slot slot;

  /// Equipment always shown, whatever the exercise uses.
  final Hold? fixed;

  /// Where a cable or band is attached.
  final Offset? anchor;
  final List<Scenery> scenery;
  final Set<Seg> focus;

  /// Length of one full cycle.
  final double seconds;

  /// How long each step of the cycle takes, relative to the others (one
  /// per step: there and back for a non-looping movement). Even when null.
  /// A slow lowering, say, is `[1, 1.8]`.
  final List<double>? pace;

  /// Degrees the upper body (and everything it holds) turns about the
  /// hips, the legs staying put: positive lifts the head of a figure lying
  /// with its head to the left (an incline bench), negative lowers it.
  final double upperTilt;

  /// A variant of this movement.
  Movement copyWith({
    String? id,
    List<Pose>? poses,
    View? view,
    bool? loop,
    Slot? slot,
    Hold? fixed,
    Offset? anchor,
    List<Scenery>? scenery,
    Set<Seg>? focus,
    double? seconds,
    List<double>? pace,
    double? upperTilt,
  }) => Movement(
    id ?? this.id,
    poses ?? this.poses,
    view: view ?? this.view,
    loop: loop ?? this.loop,
    slot: slot ?? this.slot,
    fixed: fixed ?? this.fixed,
    anchor: anchor ?? this.anchor,
    scenery: scenery ?? this.scenery,
    focus: focus ?? this.focus,
    seconds: seconds ?? this.seconds,
    pace: pace ?? this.pace,
    upperTilt: upperTilt ?? this.upperTilt,
  );

  bool get front => view == View.front;

  /// Share of each step of a rep spent holding still before moving: the
  /// pause at the start, and the squeeze at the top.
  static const _hold = 0.18;

  // How each step of a rep moves (slow in / slow out, with anticipation):
  // the effort drives out of a small counter-move and eases into its end;
  // an explosive effort winds up more and drives harder; a lowering is
  // smooth and controlled; anything else eases both ways.
  static const _effort = Cubic(0.5, -0.1, 0.25, 1);
  static const _explosiveEffort = Cubic(0.55, -0.3, 0.18, 1);
  static const _lowering = Cubic(0.42, 0, 0.3, 1);
  static const _neutral = Cubic(0.45, -0.05, 0.35, 1);

  /// Parts that aren't doing the work trail the ones that are, and settle
  /// a touch past the end before coming to rest (follow-through).
  static const _follow = Cubic(0.3, 0, 0.2, 1.08);
  static const _lag = 0.1;
  static const _headLag = 0.16;

  /// In flowing loops (running, cycling), how far behind in the cycle the
  /// trailing parts are.
  static const _loopLag = 0.03;

  /// How far the shoulders rise with each breath (secondary action).
  static const _breath = 0.005;

  static const _explosiveIds = {
    'jump',
    'jump_squat',
    'clean',
    'clean_press',
    'snatch',
    'kettlebell_swing',
    'swing',
    'burpee',
    'thruster',
    'jumping_jack',
    'wood_chop',
    'boxing',
    'kick',
    'tennis',
  };

  bool get _explosive =>
      _explosiveIds.contains(id.split('~').first) ||
      (pace != null && pace!.isNotEmpty && pace!.reduce(math.min) < 0.8);

  /// Whether going from the first pose to the second lowers the weight or
  /// the body (a squat) rather than raising it (a curl).
  bool get lowersFirst => _lowersFirst[this] ??= () {
    if (poses.length < 2) return false;
    final a = Skeleton.solve(poses.first, front: front);
    final b = Skeleton.solve(poses.last, front: front);
    double height(Skeleton s) =>
        s[J.wristN].dy + s[J.wristF].dy + s[J.neck].dy * 2;
    return height(b) > height(a) + 0.01;
  }();

  static final _lowersFirst = Expando<bool>();

  List<Pose> get _sequence =>
      loop ? [...poses, poses.first] : [...poses, ...poses.reversed.skip(1)];

  /// Where each step starts in the cycle (0–1), then a final 1.
  List<double> get _starts {
    final steps = _sequence.length - 1;
    final p = pace;
    final weights = [
      for (var i = 0; i < steps; i++)
        p != null && p.isNotEmpty ? p[i % p.length] : 1.0,
    ];
    final total = weights.fold(0.0, (a, b) => a + b);
    final starts = <double>[0];
    for (final w in weights) {
      starts.add(starts.last + w / total);
    }
    starts[starts.length - 1] = 1;
    return starts;
  }

  /// How step [i] of a rep moves: the effort, the lowering, or neither.
  Curve _curveOf(int i) {
    if (poses.length != 2) return _neutral;
    // Step 0 goes to the working pose, step 1 comes back.
    final lowering = (i == 0) == lowersFirst;
    if (lowering) return _lowering;
    return _explosive ? _explosiveEffort : _effort;
  }

  /// The pose [t] (0–1) of the way through a cycle.
  Pose poseAt(double t) {
    final seq = _sequence;
    if (seq.length == 1) return seq.first;
    final x = t % 1;
    // Breathing in as the weight lowers, out on the effort.
    final breath = _breath * (0.5 - 0.5 * math.cos(2 * math.pi * x));
    if (loop) return _flowing(x, breath);
    final starts = _starts;
    var i = 0;
    while (i < seq.length - 2 && x >= starts[i + 1]) {
      i++;
    }
    final span = starts[i + 1] - starts[i];
    final local = span <= 0 ? 0.0 : (x - starts[i]) / span;
    final move = local <= _hold ? 0.0 : (local - _hold) / (1 - _hold);
    final main = _curveOf(i).transform(move);
    double trailing(double lag) =>
        _follow.transform(((move - lag) / (1 - lag)).clamp(0.0, 1.0));
    return seq[i].blend(
      seq[i + 1],
      body: main,
      arms: focus.contains(Seg.arms) || focus.isEmpty ? main : trailing(_lag),
      legs: focus.contains(Seg.legs) || focus.isEmpty ? main : trailing(_lag),
      head: trailing(_headLag),
      breath: breath,
    );
  }

  /// A looping movement (running, cycling) as one smooth, unbroken flow
  /// through its poses, the trailing parts a little behind.
  Pose _flowing(double x, double breath) {
    final lead = _spline(x);
    final trail = _spline(x - _loopLag);
    final head = _spline(x - _loopLag * 1.5);
    final arms = focus.contains(Seg.arms) || focus.isEmpty;
    final legs = focus.contains(Seg.legs) || focus.isEmpty;
    return Pose(
      root: lead.root,
      at: lead.at,
      torso: lead.torso,
      head: head.head,
      arm: arms ? lead.arm : trail.arm,
      armFar: arms ? lead.armFar : trail.armFar,
      leg: legs ? lead.leg : trail.leg,
      legFar: legs ? lead.legFar : trail.legFar,
      lift: lead.lift + breath * 0.6,
    );
  }

  /// The pose [x] of the way round a loop, on a Catmull-Rom curve through
  /// its keyframes: every part travels in smooth arcs, never stopping.
  Pose _spline(double x) {
    final n = poses.length;
    final u = (x % 1) * n;
    final i = u.floor() % n;
    final f = u - u.floor();
    Pose at(int k) => poses[k % n];
    final p0 = at(i - 1 + n), p1 = at(i), p2 = at(i + 1), p3 = at(i + 2);
    // Barry and Goldman's form: Catmull-Rom from straight-line blends.
    final a1 = p0.lerp(p1, f + 1);
    final a2 = p1.lerp(p2, f);
    final a3 = p2.lerp(p3, f - 1);
    final b1 = a1.lerp(a2, (f + 1) / 2);
    final b2 = a2.lerp(a3, f / 2);
    return b1.lerp(b2, f);
  }

  /// When keyframe [k] is reached in the cycle.
  double timeOf(int k) {
    final steps = _sequence.length - 1;
    if (steps == 0) return 0;
    return _starts[k.clamp(0, steps)];
  }

  Skeleton skeletonAt(double t) {
    final s = Skeleton.solve(poseAt(t), front: front);
    return upperTilt == 0 ? s : s.withUpperTilt(upperTilt);
  }
}
