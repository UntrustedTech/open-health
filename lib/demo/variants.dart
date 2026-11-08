import 'dart:ui';

import 'package:health_app/demo/exercise_description.dart';
import 'package:health_app/demo/figure.dart';
import 'package:health_app/demo/movement.dart';

/// Ways a movement is changed to follow an exercise's description: one
/// side only, taking turns, on an incline or a ball, at its pace.
abstract final class Variants {
  /// [p] with some limbs replaced.
  static Pose _with(
    Pose p, {
    Limb? arm,
    Limb? armFar,
    Limb? leg,
    Limb? legFar,
    Offset? at,
  }) => Pose(
    root: p.root,
    at: at ?? p.at,
    torso: p.torso,
    head: p.head,
    arm: arm ?? p.arm,
    armFar: armFar ?? p.armFar,
    leg: leg ?? p.leg,
    legFar: legFar ?? p.legFar,
    lift: p.lift,
  );

  /// Whether both [limbs] move together in [m] and are what it works, so
  /// it can be split into one side (not a twist or a sit-up, where the
  /// whole body turns).
  static bool _paired(Movement m, Limbs limbs) =>
      m.focus.contains(limbs == Limbs.arms ? Seg.arms : Seg.legs) &&
      m.poses.every(
        (p) => limbs == Limbs.arms
            ? identical(p.armFar, p.arm)
            : identical(p.legFar, p.leg),
      );

  /// Only the near arm (or leg) moves; the other keeps its starting place.
  static Movement oneSide(Movement m, Limbs limbs) {
    if (!_paired(m, limbs) || m.poses.length < 2) return m;
    final start = m.poses.first;
    return m.copyWith(
      id: '${m.id}~one_${limbs.name}',
      poses: [
        for (final p in m.poses)
          limbs == Limbs.arms
              ? _with(p, armFar: start.armFar)
              : _with(p, legFar: start.legFar),
      ],
    );
  }

  /// The near arm (or leg) works, then the far one: start, near, start,
  /// far, as a loop.
  static Movement alternating(Movement m, Limbs limbs) {
    if (!_paired(m, limbs) || m.poses.length != 2) return oneSide(m, limbs);
    final [start, work] = m.poses;
    final arms = limbs == Limbs.arms;
    final near = arms
        ? _with(work, armFar: start.armFar)
        : _with(work, legFar: start.legFar);
    final far = arms
        ? _with(start, armFar: work.armFar)
        : _with(start, legFar: work.legFar);
    final pace = m.pace;
    return m.copyWith(
      id: '${m.id}~alt_${limbs.name}',
      poses: [start, near, start, far],
      loop: true,
      seconds: m.seconds * 2,
      pace: pace == null || pace.length != 2 ? null : [...pace, ...pace],
    );
  }

  /// Whether [m] is done lying on the back on a flat bench.
  static bool _onFlatBench(Movement m) =>
      m.poses.every((p) => p.root == Root.hip && (p.torso + 90).abs() < 12) &&
      m.scenery.any(
        (s) => s is Surface && (s.a.dy - s.b.dy).abs() < 0.01 && s.a.dy < -0.3,
      );

  /// A lying-on-the-back movement moved onto an incline (head up) or a
  /// decline (head down) bench: the upper body and the bench under it turn
  /// about the hips.
  static Movement onBench(Movement m, BenchAngle angle) {
    if (!_onFlatBench(m)) return m;
    final degrees = switch (angle) {
      BenchAngle.incline => 32.0,
      BenchAngle.decline => -22.0,
      BenchAngle.flat || BenchAngle.none => 0.0,
    };
    if (degrees == 0) return m;
    final hip = m.poses.first.at;
    return m.copyWith(
      id: '${m.id}~${angle.name}',
      upperTilt: degrees,
      scenery: [
        for (final s in m.scenery)
          if (s is Surface && (s.a.dy - s.b.dy).abs() < 0.01)
            _tiltedBench(s, hip, degrees)
          else
            s,
      ],
    );
  }

  /// [bench]'s head end turned [degrees] about a point under the hips.
  static Surface _tiltedBench(Surface bench, Offset hip, double degrees) {
    final pivot = Offset(hip.dx + 0.04, bench.a.dy);
    final head = bench.a.dx < bench.b.dx ? bench.a : bench.b;
    final foot = bench.a.dx < bench.b.dx ? bench.b : bench.a;
    final turned = Skeleton({
      J.pelvis: pivot,
      J.neck: head,
    }, front: false).withUpperTilt(degrees)[J.neck];
    return Surface(turned, foot, legs: bench.legs);
  }

  /// A movement on a bench or seat moved onto a stability ball: lying,
  /// the ball under the upper back; seated, under the hips.
  static Movement onBall(Movement m) {
    if (_onFlatBench(m)) {
      final hip = m.poses.first.at;
      const radius = 0.2;
      return m.copyWith(
        id: '${m.id}~ball',
        scenery: [
          for (final s in m.scenery)
            if (s is! Surface) s,
          Ball(Offset(hip.dx - 0.15, hip.dy + 0.03 + radius), radius),
        ],
      );
    }
    final seat = m.scenery.whereType<Surface>().where(
      (s) => (s.a.dy - s.b.dy).abs() < 0.01 && s.a.dy > -0.3,
    );
    if (seat.isEmpty) return m;
    final top = seat.first.a.dy;
    final hipX = m.poses.first.at.dx;
    final radius = -top / 2;
    return m.copyWith(
      id: '${m.id}~ball',
      scenery: [
        for (final s in m.scenery)
          if (!seat.contains(s)) s,
        Ball(Offset(hipX - 0.01, top + radius), radius),
      ],
    );
  }

  /// A movement on the hands (push-ups, planks) with the hands raised on
  /// a bosu dome.
  static Movement handsOnDome(Movement m) {
    if (!m.poses.every((p) => p.root == Root.hands)) return m;
    const lift = 0.1;
    final hands = m.poses.first.at;
    return m.copyWith(
      id: '${m.id}~bosu',
      poses: [
        for (final p in m.poses) _with(p, at: p.at + const Offset(0, -lift)),
      ],
      scenery: [...m.scenery, Dome(Offset(hands.dx, 0), lift / 0.6)],
    );
  }

  /// [m] at the pace its description asks for: a slow lowering, an
  /// explosive drive, or both. Which step lowers is read from the poses.
  static Movement paced(
    Movement m, {
    bool slowLowering = false,
    bool explosive = false,
  }) {
    if ((!slowLowering && !explosive) || m.loop || m.poses.length != 2) {
      return m;
    }
    final down = m.lowersFirst;
    final drive = explosive ? 0.6 : 1.0;
    final lower = slowLowering ? 1.7 : 1.0;
    return m.copyWith(
      id: '${m.id}~paced',
      pace: down ? [lower, drive] : [drive, lower],
      seconds: m.seconds * (slowLowering ? 1.15 : 1),
    );
  }

  /// The arms go overhead in the working position (a lunge with an
  /// overhead reach).
  static Movement reachingUp(Movement m) {
    if (m.poses.length < 2) return m;
    const up = Limb(172, 178);
    return m.copyWith(
      id: '${m.id}~reach',
      poses: [
        m.poses.first,
        for (final p in m.poses.skip(1)) _with(p, arm: up, armFar: up),
      ],
      slot: Slot.none,
    );
  }
}
