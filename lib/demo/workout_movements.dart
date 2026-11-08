import 'dart:math' as math;
import 'dart:ui';

import 'package:health_app/demo/figure.dart';
import 'package:health_app/demo/movement.dart';
import 'package:health_app/demo/movements.dart';
import 'package:health_app/models/workout.dart';

/// The movement that pictures each kind of workout, and what's held.
abstract final class WorkoutMovements {
  static (Movement, Hold) of(WorkoutType type) => switch (type) {
    WorkoutType.run => (Movements.run, Hold.none),
    WorkoutType.walk => (Movements.walk, Hold.none),
    WorkoutType.hike => (hike, Hold.none),
    WorkoutType.cycle => (Movements.cycling, Hold.none),
    WorkoutType.strength => (Movements.deadlift, Hold.barbell),
    WorkoutType.hiit => (Movements.jumpingJack, Hold.none),
    WorkoutType.swim => (swim, Hold.none),
    WorkoutType.row => (row, Hold.none),
    WorkoutType.elliptical => (elliptical, Hold.none),
    WorkoutType.yoga => (yoga, Hold.none),
    WorkoutType.dance => (dance, Hold.none),
    WorkoutType.indoorRun => (treadmill, Hold.none),
    WorkoutType.indoorCycle => (Movements.cycling, Hold.none),
    WorkoutType.stairs => (Movements.stepUp, Hold.none),
    WorkoutType.jumpRope => (Movements.jump, Hold.none),
    WorkoutType.boxing => (boxing, Hold.none),
    WorkoutType.martialArts => (kick, Hold.none),
    WorkoutType.climbing => (climb, Hold.none),
    WorkoutType.pilates => (Movements.vSit, Hold.none),
    WorkoutType.barre => (plie, Hold.none),
    WorkoutType.stretching => (Movements.forwardFold, Hold.none),
    WorkoutType.taiChi => (taiChi, Hold.none),
    WorkoutType.tennis => (tennis, Hold.none),
    WorkoutType.aerialSilks ||
    WorkoutType.poleFitness => (Movements.pullUp, Hold.none),
    WorkoutType.aerialHoop ||
    WorkoutType.paragliding => (Movements.reach, Hold.none),
    WorkoutType.trampoline ||
    WorkoutType.parkour => (Movements.jump, Hold.none),
    WorkoutType.surfing ||
    WorkoutType.skiing ||
    WorkoutType.snowboarding ||
    WorkoutType.skateboarding => (Movements.squat, Hold.none),
    WorkoutType.paddleboard || WorkoutType.kayaking => (row, Hold.none),
    WorkoutType.openWaterSwim => (swim, Hold.none),
    WorkoutType.fencing => (Movements.lunge, Hold.none),
    WorkoutType.golf => (Movements.woodChop, Hold.none),
    WorkoutType.other => (Movements.reach, Hold.none),
  };

  // A long stride uphill, leaning in, arms pumping: the walk's four
  // keyframes (contact, passing, and the other side) with a forward lean.
  static final hike = Movement(
    'hike',
    [
      for (final p in Movements.walk.poses)
        Pose(
          root: p.root,
          at: p.at + const Offset(0, 0.01),
          torso: 164,
          head: 172,
          arm: Limb(p.arm.upper * 1.8, p.arm.lower * 1.8 + 20),
          armFar: Limb(p.armFar.upper * 1.8, p.armFar.lower * 1.8 + 20),
          leg: Limb(p.leg.upper * 1.25, p.leg.lower, p.leg.end),
          legFar: Limb(p.legFar.upper * 1.25, p.legFar.lower, p.legFar.end),
        ),
    ],
    loop: true,
    slot: Slot.none,
    focus: {Seg.legs},
    seconds: 1.5,
  );

  // Front crawl, side on: lying along the water, one arm reaching ahead
  // as the other pulls through, legs fluttering.
  static final swim = Movement(
    'swim',
    [
      for (var k = 0; k < 4; k++)
        Pose(
          root: Root.hip,
          at: const Offset(0, -0.3),
          torso: 92,
          head: 96,
          arm: _stroke(k * 90),
          armFar: _stroke(k * 90 + 180),
          leg: Limb(-88 + (k.isEven ? 8 : -8), -88 + (k.isEven ? 4 : -4)),
          legFar: Limb(-88 + (k.isEven ? -8 : 8), -88 + (k.isEven ? -4 : 4)),
        ),
    ],
    loop: true,
    slot: Slot.none,
    focus: {Seg.arms},
    seconds: 1.8,
  );

  /// An arm on the crawl's circle: 0 reaching ahead, 90 pulling down,
  /// 180 pushing back past the hip, 270 recovering over the water.
  static Limb _stroke(double degrees) {
    final a = degrees % 360;
    // Angles are in the world (0 down, 90 ahead): the swimmer lies along
    // the water facing ahead.
    return switch (a) {
      < 45 => const Limb(94, 92),
      < 135 => const Limb(30, 40),
      < 225 => const Limb(-70, -85),
      _ => const Limb(-160, 130),
    };
  }

  // A rowing machine: legs drive back, then the arms draw the handle in.
  static const _rail = Surface(
    Offset(-0.42, -0.12),
    Offset(0.42, -0.12),
    legs: false,
  );
  static const row = Movement(
    'rowing',
    [
      Pose(
        root: Root.hip,
        at: Offset(0.12, -0.16),
        torso: 158,
        leg: Limb.to(Offset(0.36, -0.15), bend: -1, end: 60),
        arm: Limb(95, 95),
      ),
      Pose(
        root: Root.hip,
        at: Offset(-0.12, -0.16),
        torso: 195,
        leg: Limb.to(Offset(0.36, -0.15), bend: -1, end: 60),
        arm: Limb(20, 105),
      ),
    ],
    slot: Slot.none,
    scenery: [_rail],
    focus: {Seg.legs, Seg.arms},
    seconds: 2.2,
  );

  // Elliptical: feet trace ovals on the pedals while the arms push and
  // pull the handles.
  static const _footPath = Offset(0.05, -0.12);
  static Limb _foot(double angle) => Limb.to(
    Offset(
      _footPath.dx + 0.13 * math.cos(angle),
      _footPath.dy + 0.04 * math.sin(angle),
    ),
    bend: -1,
    end: 92,
  );

  static final elliptical = Movement(
    'elliptical',
    [
      for (var k = 0; k < 4; k++)
        Pose(
          root: Root.hip,
          at: const Offset(0, -0.58),
          torso: 176,
          leg: _foot(k * math.pi / 2),
          legFar: _foot(k * math.pi / 2 + math.pi),
          arm: Limb(k.isEven ? 25 : 55, 100),
          armFar: Limb(k.isEven ? 55 : 25, 100),
        ),
    ],
    loop: true,
    slot: Slot.none,
    scenery: const [Block(Rect.fromLTRB(-0.2, -0.07, 0.3, 0))],
    focus: {Seg.legs},
    seconds: 1.6,
  );

  // Yoga, facing us: tree pose, the arms rising overhead and back.
  static const yoga = Movement(
    'yoga',
    [
      Pose(legFar: Limb(52, -62), arm: Limb(20, 160)),
      Pose(legFar: Limb(52, -62), arm: Limb(168, 178)),
    ],
    view: View.front,
    slot: Slot.none,
    focus: {Seg.torso},
    seconds: 5,
  );

  // Dance, facing us: a side-to-side groove with the arms swapping.
  static const dance = Movement(
    'dance',
    [
      Pose(
        root: Root.hip,
        at: Offset(-0.03, -0.43),
        torso: 174,
        head: 170,
        arm: Limb(150, 170),
        armFar: Limb(40, 110),
        leg: Limb(14, 4),
        legFar: Limb(4, -8),
      ),
      Pose(
        root: Root.hip,
        at: Offset(0.03, -0.43),
        torso: 186,
        head: 190,
        arm: Limb(40, 110),
        armFar: Limb(150, 170),
        leg: Limb(4, -8),
        legFar: Limb(14, 4),
      ),
    ],
    view: View.front,
    loop: true,
    slot: Slot.none,
    seconds: 1.1,
  );

  // Running on a treadmill's belt.
  static final treadmill = Movement(
    'treadmill',
    Movements.run.poses,
    loop: true,
    slot: Slot.none,
    scenery: const [Block(Rect.fromLTRB(-0.42, -0.035, 0.42, 0))],
    focus: {Seg.legs},
    seconds: 0.9,
  );

  // Boxing, side on: guard up, then a straight jab.
  static const _guard = Limb(25, 165);
  static const boxing = Movement(
    'boxing',
    [
      Pose(
        torso: 174,
        arm: _guard,
        armFar: Limb(35, 160),
        legFar: Limb(-14, -14),
      ),
      Pose(
        torso: 170,
        arm: Limb(86, 88),
        armFar: Limb(35, 160),
        legFar: Limb(-14, -14),
      ),
    ],
    slot: Slot.none,
    focus: {Seg.arms},
    seconds: 0.9,
  );

  // A front kick, guard held.
  static const kick = Movement(
    'kick',
    [
      Pose(torso: 178, arm: _guard, armFar: _guard, legFar: Limb(-8, -8)),
      Pose(torso: 192, arm: _guard, armFar: _guard, legFar: Limb(96, 92, 150)),
    ],
    slot: Slot.none,
    focus: {Seg.legs},
    seconds: 1.3,
  );

  // Climbing a wall: reaching up one hand at a time, knees stepping high.
  static const _wall = Block(Rect.fromLTRB(0.075, -1.25, 0.4, 0));
  static const climb = Movement(
    'climbing',
    [
      Pose(
        root: Root.hip,
        at: Offset(0.0, -0.5),
        torso: 172,
        arm: Limb(168, 176),
        armFar: Limb(120, 60),
        leg: Limb(70, -20),
        legFar: Limb(15, -10),
      ),
      Pose(
        root: Root.hip,
        at: Offset(0.0, -0.58),
        torso: 174,
        arm: Limb(120, 60),
        armFar: Limb(168, 176),
        leg: Limb(15, -10),
        legFar: Limb(70, -20),
      ),
    ],
    loop: true,
    slot: Slot.none,
    scenery: [_wall],
    focus: {Seg.arms, Seg.legs},
    seconds: 2.4,
  );

  // Barre, facing us: a wide plié, arms open in second position.
  static const plie = Movement(
    'plie',
    [
      Pose(
        root: Root.hip,
        at: Offset(0, -0.45),
        leg: Limb(22, 12),
        arm: Limb(70, 85),
      ),
      Pose(
        root: Root.hip,
        at: Offset(0, -0.36),
        leg: Limb(55, -8),
        arm: Limb(110, 140),
      ),
    ],
    view: View.front,
    slot: Slot.none,
    focus: {Seg.legs},
    seconds: 3.2,
  );

  // Tai chi, facing us: a slow sink as the arms float up and settle.
  static const taiChi = Movement(
    'tai_chi',
    [
      Pose(
        root: Root.hip,
        at: Offset(0, -0.43),
        leg: Limb(16, 4),
        arm: Limb(10, 30),
      ),
      Pose(
        root: Root.hip,
        at: Offset(0, -0.39),
        leg: Limb(26, -6),
        arm: Limb(70, 100),
      ),
    ],
    view: View.front,
    slot: Slot.none,
    seconds: 5.5,
  );

  // A forehand: racket arm back, then swung across in front.
  static const tennis = Movement(
    'tennis',
    [
      Pose(
        torso: 176,
        arm: Limb(-70, -40),
        armFar: Limb(70, 80),
        legFar: Limb(-16, -10),
      ),
      Pose(
        torso: 170,
        arm: Limb(120, 150),
        armFar: Limb(10, 40),
        legFar: Limb(-16, -10),
      ),
    ],
    slot: Slot.none,
    focus: {Seg.arms},
    seconds: 1.4,
  );

  static List<Movement> get all => [
    plie,
    taiChi,
    tennis,
    hike,
    swim,
    row,
    elliptical,
    yoga,
    dance,
    treadmill,
    boxing,
    kick,
    climb,
  ];
}
