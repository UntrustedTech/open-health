import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// A jointed figure for exercise demonstrations, in world units: the figure
/// stands about 0.85 tall, the floor is y = 0 and y grows downwards.
///
/// Segment angles are in degrees, measured from straight down and turning
/// towards the way the figure faces: 0 = down, 90 = forward, 180 = up,
/// -90 = backward. In the front view "forward" means away from the body's
/// centre line, for each side.
abstract final class Body {
  static const torso = 0.26;
  static const neck = 0.075;
  static const headRadius = 0.052;
  static const upperArm = 0.15;
  static const forearm = 0.14;
  static const thigh = 0.21;
  static const shin = 0.20;
  static const foot = 0.06;

  /// Ankle height when standing, so the foot rests on the floor.
  static const ankleHeight = 0.025;

  /// Front view: half the shoulder and hip widths.
  static const shoulderHalf = 0.088;
  static const hipHalf = 0.045;

  /// A standing figure's ankle, at the origin.
  static const standing = Offset(0, -ankleHeight);
}

/// Unit vector for a segment angle (see [Body]).
Offset direction(double degrees) {
  final r = degrees * math.pi / 180;
  return Offset(math.sin(r), math.cos(r));
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Which point of the figure stays put; the rest hangs off it.
enum Root {
  /// The near ankle.
  feet,

  /// The near toes (calf raises, push-ups from the feet).
  toes,

  /// The hips (lying, seated).
  hip,

  /// The near wrist (hanging, push-ups).
  hands,

  /// The shoulders (bridges).
  shoulders,
}

/// Where an arm or leg reaches for, when it is placed by its end point.
enum Frame { world, shoulder, hip }

/// An arm or leg: two segment angles (plus the foot), or a point its end
/// reaches for with the middle joint bending to one side.
@immutable
class Limb {
  const Limb(this.upper, this.lower, [this.end = 90])
    : target = null,
      frame = Frame.world,
      bend = 1;

  const Limb.to(
    Offset this.target, {
    this.frame = Frame.world,
    this.bend = 1,
    this.end = 90,
  }) : upper = 0,
       lower = 0;

  final double upper;
  final double lower;

  /// The foot's angle (legs only).
  final double end;
  final Offset? target;
  final Frame frame;

  /// Which way the elbow or knee points: 1 or -1.
  final int bend;

  static const down = Limb(0, 0);

  Limb lerp(Limb other, double t) {
    final a = target, b = other.target;
    if (a != null && b != null) {
      return Limb.to(
        Offset.lerp(a, b, t)!,
        frame: t < 0.5 ? frame : other.frame,
        bend: t < 0.5 ? bend : other.bend,
        end: _lerp(end, other.end, t),
      );
    }
    return Limb(
      _lerp(upper, other.upper, t),
      _lerp(lower, other.lower, t),
      _lerp(end, other.end, t),
    );
  }
}

/// One position of the figure.
@immutable
class Pose {
  const Pose({
    this.root = Root.feet,
    this.at = Body.standing,
    this.torso = 180,
    this.head,
    this.arm = Limb.down,
    Limb? armFar,
    this.leg = Limb.down,
    Limb? legFar,
    this.lift = 0,
    // Named parameters can't be private; these default to the near side.
    // ignore: prefer_initializing_formals
  }) : _armFar = armFar,
       // ignore: prefer_initializing_formals
       _legFar = legFar;

  final Root root;

  /// Where the [root] point is.
  final Offset at;

  /// Hip → shoulder angle.
  final double torso;

  /// Shoulder → head angle; follows the torso when null.
  final double? head;
  final Limb arm;
  final Limb leg;
  final Limb? _armFar;
  final Limb? _legFar;

  /// Raises the shoulders along the torso (shrugs).
  final double lift;

  Limb get armFar => _armFar ?? arm;
  Limb get legFar => _legFar ?? leg;

  /// Like [lerp], with each part of the body at its own point of the way:
  /// the root and torso ([body]), the arms, the legs and the head. Lets
  /// parts lead and follow one another (overlapping action), and go a
  /// little past either end (anticipation and follow-through).
  Pose blend(
    Pose o, {
    required double body,
    required double arms,
    required double legs,
    required double head,
    double breath = 0,
  }) {
    assert(root == o.root, 'Poses in one movement share a root');
    return Pose(
      root: root,
      at: Offset.lerp(at, o.at, body)!,
      torso: _lerp(torso, o.torso, body),
      head: _lerp(this.head ?? torso, o.head ?? o.torso, head),
      arm: arm.lerp(o.arm, arms),
      armFar: armFar.lerp(o.armFar, arms),
      leg: leg.lerp(o.leg, legs),
      legFar: legFar.lerp(o.legFar, legs),
      lift: _lerp(lift, o.lift, body) + breath,
    );
  }

  Pose lerp(Pose o, double t) {
    assert(root == o.root, 'Poses in one movement share a root');
    return Pose(
      root: root,
      at: Offset.lerp(at, o.at, t)!,
      torso: _lerp(torso, o.torso, t),
      head: _lerp(head ?? torso, o.head ?? o.torso, t),
      arm: arm.lerp(o.arm, t),
      armFar: armFar.lerp(o.armFar, t),
      leg: leg.lerp(o.leg, t),
      legFar: legFar.lerp(o.legFar, t),
      lift: _lerp(lift, o.lift, t),
    );
  }
}

/// Joints of a solved figure.
enum J {
  pelvis,
  neck,
  head,
  hipN,
  hipF,
  shoulderN,
  shoulderF,
  elbowN,
  wristN,
  elbowF,
  wristF,
  kneeN,
  ankleN,
  toeN,
  kneeF,
  ankleF,
  toeF,
}

/// Joint positions for a pose.
@immutable
class Skeleton {
  const Skeleton(this.joints, {required this.front});

  final Map<J, Offset> joints;
  final bool front;

  Offset operator [](J j) => joints[j]!;

  Iterable<Offset> get points => joints.values;

  /// The upper body turned [degrees] about the pelvis (see
  /// [Movement.upperTilt]); the legs stay where they are.
  Skeleton withUpperTilt(double degrees) {
    final r = degrees * math.pi / 180;
    final c = math.cos(r), s = math.sin(r);
    final o = joints[J.pelvis]!;
    Offset turn(Offset p) {
      final d = p - o;
      return o + Offset(d.dx * c - d.dy * s, d.dx * s + d.dy * c);
    }

    const upper = {
      J.neck,
      J.head,
      J.shoulderN,
      J.shoulderF,
      J.elbowN,
      J.elbowF,
      J.wristN,
      J.wristF,
    };
    return Skeleton({
      for (final MapEntry(:key, :value) in joints.entries)
        key: upper.contains(key) ? turn(value) : value,
    }, front: front);
  }

  /// Solves [pose] for the side view (or the front view when [front]).
  factory Skeleton.solve(Pose pose, {bool front = false}) {
    final up = direction(pose.torso);
    final torsoLen = Body.torso + pose.lift;
    // Perpendicular to the torso, towards the near side (front view).
    final side = Offset(-up.dy, up.dx);
    final shoulderOffset = front ? side * Body.shoulderHalf : Offset.zero;
    final hipOffset = front ? side * Body.hipHalf : Offset.zero;

    // Mirrors a front-view angle for the far side.
    Offset dirN(double a) => direction(a);
    Offset dirF(double a) {
      final d = direction(a);
      return front ? Offset(-d.dx, d.dy) : d;
    }

    // Facing us, legs left hanging straight stand a little apart, about
    // shoulder width, as a figure is drawn standing.
    Limb stance(Limb l) =>
        front && l.target == null && l.upper == 0 && l.lower == 0
        ? Limb(6, 3, l.end)
        : l;
    final legN = stance(pose.leg), legF = stance(pose.legFar);

    // Near-side chain from the root back to the pelvis.
    final Offset pelvis;
    switch (pose.root) {
      case Root.hip:
        pelvis = pose.at;
      case Root.shoulders:
        pelvis = pose.at - up * torsoLen;
      case Root.feet || Root.toes:
        final leg = legN;
        final ankle = pose.root == Root.toes
            ? pose.at - dirN(leg.end) * Body.foot
            : pose.at;
        final knee = ankle - dirN(leg.lower) * Body.shin;
        pelvis = knee - dirN(leg.upper) * Body.thigh - hipOffset;
      case Root.hands:
        final arm = pose.arm;
        final elbow = pose.at - dirN(arm.lower) * Body.forearm;
        final shoulder = elbow - dirN(arm.upper) * Body.upperArm;
        pelvis = shoulder - shoulderOffset - up * torsoLen;
    }
    final neck = pelvis + up * torsoLen;
    final head = neck + direction(pose.head ?? pose.torso) * Body.neck;
    final j = <J, Offset>{
      J.pelvis: pelvis,
      J.neck: neck,
      J.head: head,
      J.hipN: pelvis + hipOffset,
      J.hipF: pelvis - hipOffset,
      J.shoulderN: neck + shoulderOffset,
      J.shoulderF: neck - shoulderOffset,
    };

    Offset resolve(Limb l, Offset base) {
      final t = l.target!;
      return switch (l.frame) {
        Frame.world => t,
        Frame.shoulder => j[J.shoulderN]! + t,
        Frame.hip => pelvis + t,
      };
    }

    void chain(
      Limb l,
      Offset base,
      double a,
      double b,
      Offset Function(double) dir,
      J mid,
      J end,
      int mirror,
    ) {
      if (l.target != null) {
        var target = resolve(l, base);
        // A far limb in the front view reaches for the mirrored point.
        if (mirror < 0) {
          target = Offset(2 * pelvis.dx - target.dx, target.dy);
        }
        j[mid] = _bendJoint(base, target, a, b, l.bend * mirror);
        j[end] = _reach(base, target, a + b);
      } else {
        j[mid] = base + dir(l.upper) * a;
        j[end] = j[mid]! + dir(l.lower) * b;
      }
    }

    final m = front ? -1 : 1;
    chain(
      pose.arm,
      j[J.shoulderN]!,
      Body.upperArm,
      Body.forearm,
      dirN,
      J.elbowN,
      J.wristN,
      1,
    );
    chain(
      pose.armFar,
      j[J.shoulderF]!,
      Body.upperArm,
      Body.forearm,
      dirF,
      J.elbowF,
      J.wristF,
      m,
    );
    chain(legN, j[J.hipN]!, Body.thigh, Body.shin, dirN, J.kneeN, J.ankleN, 1);
    chain(legF, j[J.hipF]!, Body.thigh, Body.shin, dirF, J.kneeF, J.ankleF, m);
    j[J.toeN] = j[J.ankleN]! + dirN(legN.end) * Body.foot;
    j[J.toeF] = j[J.ankleF]! + dirF(legF.end) * Body.foot;
    return Skeleton(Map.unmodifiable(j), front: front);
  }
}

/// The furthest point towards [target] a limb of [length] can reach.
Offset _reach(Offset base, Offset target, double length) {
  final d = target - base;
  final dist = d.distance;
  if (dist <= length || dist == 0) return target;
  return base + d / dist * length;
}

/// Two-bone reach: where the middle joint goes so the end touches
/// [target] (or points at it when out of reach).
Offset _bendJoint(Offset base, Offset target, double a, double b, int bend) {
  final d = target - base;
  final dist = d.distance.clamp((a - b).abs() + 1e-6, a + b - 1e-6);
  final unit = d.distance == 0 ? const Offset(0, 1) : d / d.distance;
  final cosA = ((a * a + dist * dist - b * b) / (2 * a * dist)).clamp(-1, 1);
  final angle = math.acos(cosA) * bend;
  final c = math.cos(angle), s = math.sin(angle);
  final rotated = Offset(unit.dx * c - unit.dy * s, unit.dx * s + unit.dy * c);
  return base + rotated * a;
}
