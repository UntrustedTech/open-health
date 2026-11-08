import 'dart:ui';

import 'package:health_app/demo/figure.dart';
import 'package:health_app/demo/movement.dart';

// Keyframes for every demonstrated movement. Side views face right; a
// figure lying on its back has its head to the left. Angles: see [Body].

const _shoulder = Frame.shoulder;
const _hip = Frame.hip;

// Hands resting on the upper back (back squats, good mornings).
const _barOnBack = Limb.to(Offset(-0.05, 0.03), frame: _shoulder, bend: -1);
// Hands in front of the chest (front and goblet squats).
const _atChest = Limb.to(Offset(0.07, 0.07), frame: _shoulder, bend: -1);
const _rack = Limb(30, 170);
const _overhead = Limb(178, 180);

// Lying on a flat bench, hips at the origin's right.
const _benchTop = -0.36;
const _lyingHip = Offset(0.05, _benchTop - 0.045);
const _flatBench = Surface(Offset(-0.55, _benchTop), Offset(0.12, _benchTop));
const _feetOnFloor = Limb.to(Offset(0.25, -0.025), bend: -1);

// Seated on a box seat with feet flat.
const _seatTop = -0.2;
const _seatedHip = Offset(0, _seatTop - 0.035);
const _seat = Surface(Offset(-0.14, _seatTop), Offset(0.1, _seatTop));
const _seatedLegs = Limb(90, 0);

// Lying on the floor.
const _floorHip = Offset(0, -0.05);

// Standing hip height, for moves where a standing leg lifts away.
const _standingHip = Offset(0, -(Body.ankleHeight + Body.thigh + Body.shin));

abstract final class Movements {
  // ---------------------------------------------------------------- Legs

  static const squat = Movement(
    'squat',
    [
      Pose(arm: Limb(90, 90)),
      Pose(torso: 145, leg: Limb(82, -30), arm: Limb(95, 95)),
    ],
    focus: {Seg.legs},
  );

  static const backSquat = Movement(
    'back_squat',
    [
      Pose(arm: _barOnBack),
      Pose(torso: 140, leg: Limb(82, -32), arm: _barOnBack),
    ],
    slot: Slot.shoulders,
    focus: {Seg.legs},
  );

  static const frontSquat = Movement(
    'front_squat',
    [Pose(arm: _atChest), Pose(torso: 155, leg: Limb(86, -36), arm: _atChest)],
    focus: {Seg.legs},
  );

  static const jumpSquat = Movement(
    'jump_squat',
    [
      Pose(torso: 145, leg: Limb(80, -30), arm: Limb(-30, -20)),
      Pose(at: Offset(0, -0.12), leg: Limb(0, 0, 30), arm: Limb(170, 175)),
    ],
    focus: {Seg.legs},
    seconds: 1.6,
  );

  static const deadlift = Movement(
    'deadlift',
    [Pose(torso: 118, leg: Limb(60, -22)), Pose()],
    focus: {Seg.legs, Seg.torso},
  );

  static const romanianDeadlift = Movement(
    'rdl',
    [Pose(), Pose(torso: 100, leg: Limb(18, -8))],
    focus: {Seg.legs},
  );

  static const goodMorning = Movement(
    'good_morning',
    [
      Pose(arm: _barOnBack),
      Pose(torso: 100, leg: Limb(15, -6), arm: _barOnBack),
    ],
    slot: Slot.shoulders,
    focus: {Seg.legs, Seg.torso},
  );

  static const _backFoot = Limb.to(Offset(-0.24, -0.05), bend: -1, end: 50);

  static const lunge = Movement(
    'lunge',
    [
      Pose(at: Offset(0.18, -0.025), leg: Limb(20, 12), legFar: _backFoot),
      Pose(at: Offset(0.18, -0.025), leg: Limb(88, 0), legFar: _backFoot),
    ],
    focus: {Seg.legs},
  );

  static const barbellLunge = Movement(
    'barbell_lunge',
    [
      Pose(
        at: Offset(0.18, -0.025),
        leg: Limb(20, 12),
        legFar: _backFoot,
        arm: _barOnBack,
      ),
      Pose(
        at: Offset(0.18, -0.025),
        leg: Limb(88, 0),
        legFar: _backFoot,
        arm: _barOnBack,
      ),
    ],
    slot: Slot.shoulders,
    focus: {Seg.legs},
  );

  static const stepUp = Movement(
    'step_up',
    [
      Pose(
        at: Offset(0.2, -0.305),
        torso: 170,
        leg: Limb(70, -15),
        legFar: Limb.to(Offset(-0.06, -0.025), bend: -1),
      ),
      Pose(
        at: Offset(0.2, -0.305),
        leg: Limb(0, 0),
        legFar: Limb.to(Offset(0.12, -0.33), bend: -1),
      ),
    ],
    scenery: [Block(Rect.fromLTRB(0.04, -0.28, 0.4, 0))],
    focus: {Seg.legs},
  );

  static const calfRaise = Movement(
    'calf_raise',
    [
      Pose(root: Root.toes, at: Offset(0.06, -0.025)),
      Pose(root: Root.toes, at: Offset(0.06, -0.025), leg: Limb(0, 0, 40)),
    ],
    focus: {Seg.legs},
    seconds: 2,
  );

  static const legPress = Movement(
    'leg_press',
    [
      Pose(
        root: Root.hip,
        at: Offset(0, -0.3),
        torso: -140,
        arm: Limb(40, 60),
        leg: Limb.to(Offset(0.17, -0.5), bend: -1, end: 160),
      ),
      Pose(
        root: Root.hip,
        at: Offset(0, -0.3),
        torso: -140,
        arm: Limb(40, 60),
        leg: Limb.to(Offset(0.33, -0.66), bend: -1, end: 150),
      ),
    ],
    fixed: Hold.platform,
    scenery: [Surface(Offset(0.04, -0.26), Offset(-0.22, -0.48))],
    focus: {Seg.legs},
  );

  static const legExtension = Movement(
    'leg_extension',
    [
      Pose(
        root: Root.hip,
        at: _seatedHip,
        torso: 182,
        leg: Limb(90, 5),
        arm: Limb(10, 20),
      ),
      Pose(
        root: Root.hip,
        at: _seatedHip,
        torso: 182,
        leg: Limb(90, 86),
        arm: Limb(10, 20),
      ),
    ],
    fixed: Hold.pad,
    scenery: [_seat],
    focus: {Seg.legs},
  );

  static const legCurl = Movement(
    'leg_curl',
    [
      Pose(
        root: Root.hip,
        at: _lyingHip,
        torso: -90,
        head: -100,
        leg: Limb(90, 90),
        arm: Limb(-10, 20),
      ),
      Pose(
        root: Root.hip,
        at: _lyingHip,
        torso: -90,
        head: -100,
        leg: Limb(90, 172),
        arm: Limb(-10, 20),
      ),
    ],
    fixed: Hold.pad,
    scenery: [Surface(Offset(-0.5, _benchTop), Offset(0.25, _benchTop))],
    focus: {Seg.legs},
  );

  static const seatedLegCurl = Movement(
    'seated_leg_curl',
    [
      Pose(
        root: Root.hip,
        at: _seatedHip,
        torso: 182,
        leg: Limb(90, 70),
        arm: Limb(10, 20),
      ),
      Pose(
        root: Root.hip,
        at: _seatedHip,
        torso: 182,
        leg: Limb(90, -15),
        arm: Limb(10, 20),
      ),
    ],
    fixed: Hold.pad,
    scenery: [_seat],
    focus: {Seg.legs},
  );

  static const abduction = Movement(
    'abduction',
    [
      Pose(root: Root.hip, at: Offset(0, -0.435), arm: Limb(10, 10)),
      Pose(
        root: Root.hip,
        at: Offset(0, -0.435),
        arm: Limb(10, 10),
        leg: Limb(38, 38),
        legFar: Limb(0, 0),
      ),
    ],
    view: View.front,
    focus: {Seg.legs},
  );

  static const bridge = Movement(
    'bridge',
    [
      Pose(
        root: Root.shoulders,
        at: Offset(-0.25, -0.04),
        torso: -90,
        head: -90,
        arm: Limb(90, 90),
        leg: Limb.to(Offset(0.2, -0.025), bend: -1),
      ),
      // Hips driven up until shoulders, hips and knees line up.
      Pose(
        root: Root.shoulders,
        at: Offset(-0.25, -0.04),
        torso: -62,
        head: -90,
        arm: Limb(90, 90),
        leg: Limb.to(Offset(0.2, -0.025), bend: -1),
      ),
    ],
    focus: {Seg.legs},
  );

  static const hipThrust = Movement(
    'hip_thrust',
    [
      Pose(
        root: Root.shoulders,
        at: Offset(-0.25, -0.32),
        torso: -140,
        arm: Limb.to(Offset(0, -0.04), frame: _hip),
        leg: Limb.to(Offset(0.24, -0.025), bend: -1),
      ),
      Pose(
        root: Root.shoulders,
        at: Offset(-0.25, -0.32),
        torso: -95,
        arm: Limb.to(Offset(0, -0.04), frame: _hip),
        leg: Limb.to(Offset(0.24, -0.025), bend: -1),
      ),
    ],
    scenery: [Surface(Offset(-0.5, -0.28), Offset(-0.22, -0.28))],
    focus: {Seg.legs},
  );

  // --------------------------------------------------------------- Chest

  static const benchPress = Movement(
    'bench_press',
    [
      Pose(
        root: Root.hip,
        at: _lyingHip,
        torso: -90,
        leg: _feetOnFloor,
        arm: Limb.to(Offset(0.01, -0.28), frame: _shoulder),
      ),
      Pose(
        root: Root.hip,
        at: _lyingHip,
        torso: -90,
        leg: _feetOnFloor,
        arm: Limb.to(Offset(0.05, -0.07), frame: _shoulder),
      ),
    ],
    scenery: [_flatBench],
    focus: {Seg.arms, Seg.torso},
  );

  static const inclinePress = Movement(
    'incline_press',
    [
      Pose(
        root: Root.hip,
        at: Offset(0.05, -0.38),
        torso: -125,
        leg: _feetOnFloor,
        arm: Limb.to(Offset(0.04, -0.28), frame: _shoulder),
      ),
      Pose(
        root: Root.hip,
        at: Offset(0.05, -0.38),
        torso: -125,
        leg: _feetOnFloor,
        arm: Limb.to(Offset(0.07, -0.06), frame: _shoulder),
      ),
    ],
    scenery: [Surface(Offset(0.1, -0.34), Offset(-0.22, -0.56))],
    focus: {Seg.arms, Seg.torso},
  );

  static const declinePress = Movement(
    'decline_press',
    [
      Pose(
        root: Root.hip,
        at: Offset(0.05, -0.45),
        torso: -68,
        leg: Limb.to(Offset(0.3, -0.28), bend: -1),
        arm: Limb.to(Offset(-0.02, -0.28), frame: _shoulder),
      ),
      Pose(
        root: Root.hip,
        at: Offset(0.05, -0.45),
        torso: -68,
        leg: Limb.to(Offset(0.3, -0.28), bend: -1),
        arm: Limb.to(Offset(0.03, -0.07), frame: _shoulder),
      ),
    ],
    scenery: [Surface(Offset(0.12, -0.41), Offset(-0.3, -0.24))],
    focus: {Seg.arms, Seg.torso},
  );

  static const floorPress = Movement(
    'floor_press',
    [
      Pose(
        root: Root.hip,
        at: _floorHip,
        torso: -90,
        leg: Limb.to(Offset(0.26, -0.025), bend: -1),
        arm: Limb.to(Offset(0.01, -0.28), frame: _shoulder),
      ),
      Pose(
        root: Root.hip,
        at: _floorHip,
        torso: -90,
        leg: Limb.to(Offset(0.26, -0.025), bend: -1),
        arm: Limb.to(Offset(0.05, -0.05), frame: _shoulder),
      ),
    ],
    focus: {Seg.arms, Seg.torso},
  );

  static const pushUp = Movement(
    'push_up',
    [
      Pose(
        root: Root.hands,
        at: Offset(0.3, -0.02),
        torso: 112,
        arm: Limb(0, 0),
        leg: Limb.to(Offset(-0.36, -0.05), bend: -1, end: 20),
      ),
      Pose(
        root: Root.hands,
        at: Offset(0.3, -0.02),
        torso: 101,
        arm: Limb(-70, 30),
        leg: Limb.to(Offset(-0.36, -0.05), bend: -1, end: 20),
      ),
    ],
    slot: Slot.none,
    focus: {Seg.arms, Seg.torso},
  );

  static const fly = Movement(
    'fly',
    [Pose(arm: Limb(95, 92)), Pose(arm: Limb(-12, -22))],
    view: View.front,
    anchor: Offset(0.55, -0.85),
    focus: {Seg.arms, Seg.torso},
  );

  static const pullover = Movement(
    'pullover',
    [
      Pose(
        root: Root.hip,
        at: _lyingHip,
        torso: -90,
        leg: _feetOnFloor,
        arm: Limb(180, 180),
      ),
      Pose(
        root: Root.hip,
        at: _lyingHip,
        torso: -90,
        leg: _feetOnFloor,
        arm: Limb(275, 275),
      ),
    ],
    scenery: [_flatBench],
    focus: {Seg.arms, Seg.torso},
  );

  static const dip = Movement(
    'dip',
    [
      Pose(
        root: Root.hands,
        at: Offset(0, -0.62),
        torso: 175,
        leg: Limb(0, -60),
      ),
      Pose(
        root: Root.hands,
        at: Offset(0, -0.62),
        torso: 160,
        arm: Limb(-100, 40),
        leg: Limb(0, -60),
      ),
    ],
    slot: Slot.none,
    scenery: [Bar(Offset(0, -0.62))],
    focus: {Seg.arms},
  );

  // ---------------------------------------------------------------- Back

  static const pullUp = Movement(
    'pull_up',
    [
      Pose(
        root: Root.hands,
        at: Offset(0, -1),
        arm: Limb(180, 180),
        leg: Limb(10, -30),
      ),
      Pose(
        root: Root.hands,
        at: Offset(0, -1),
        torso: 175,
        arm: Limb(25, 175),
        leg: Limb(10, -30),
      ),
    ],
    slot: Slot.none,
    scenery: [Bar(Offset(0, -1))],
    focus: {Seg.arms, Seg.torso},
  );

  static const pulldown = Movement(
    'pulldown',
    [
      Pose(
        root: Root.hip,
        at: _seatedHip,
        torso: 188,
        leg: _seatedLegs,
        arm: Limb(182, 180),
      ),
      Pose(
        root: Root.hip,
        at: _seatedHip,
        torso: 192,
        leg: _seatedLegs,
        arm: Limb(20, 170),
      ),
    ],
    anchor: Offset(0.02, -1.08),
    scenery: [_seat],
    focus: {Seg.arms, Seg.torso},
  );

  static const row = Movement(
    'row',
    [
      Pose(torso: 115, leg: Limb(25, -12)),
      Pose(torso: 115, leg: Limb(25, -12), arm: Limb(-50, 0)),
    ],
    focus: {Seg.arms, Seg.torso},
  );

  static const seatedRow = Movement(
    'seated_row',
    [
      Pose(
        root: Root.hip,
        at: _floorHip,
        torso: 160,
        leg: Limb(80, 95),
        arm: Limb(95, 95),
      ),
      Pose(
        root: Root.hip,
        at: _floorHip,
        torso: 186,
        leg: Limb(80, 95),
        arm: Limb(-25, 90),
      ),
    ],
    anchor: Offset(0.72, -0.12),
    focus: {Seg.arms, Seg.torso},
  );

  // Seen from the front so the elbows can lead out and up, above the
  // hands, as the bar rises close to the body to the chest.
  static const uprightRow = Movement(
    'upright_row',
    [Pose(arm: Limb(-4, -4)), Pose(arm: Limb(112, -62))],
    view: View.front,
    focus: {Seg.arms},
  );

  static const reverseFly = Movement(
    'reverse_fly',
    [
      Pose(torso: 100, leg: Limb(20, -10), arm: Limb(5, 5)),
      Pose(torso: 100, leg: Limb(20, -10), arm: Limb(-65, -60)),
    ],
    focus: {Seg.arms, Seg.torso},
  );

  static const facePull = Movement(
    'face_pull',
    [Pose(arm: Limb(95, 95)), Pose(arm: Limb(80, 175))],
    anchor: Offset(0.7, -0.62),
    focus: {Seg.arms},
  );

  static const shrug = Movement(
    'shrug',
    [Pose(), Pose(lift: 0.04)],
    focus: {Seg.torso},
    seconds: 2,
  );

  static const backExtension = Movement(
    'back_extension',
    [
      Pose(
        root: Root.hip,
        at: Offset(0, -0.55),
        torso: 25,
        arm: Limb(15, 15),
        leg: Limb(-40, -40, -40),
      ),
      Pose(
        root: Root.hip,
        at: Offset(0, -0.55),
        torso: 125,
        arm: Limb(15, 15),
        leg: Limb(-40, -40, -40),
      ),
    ],
    slot: Slot.none,
    scenery: [
      Surface(Offset(-0.02, -0.51), Offset(0.1, -0.53)),
      Surface(Offset(-0.36, -0.2), Offset(-0.22, -0.27)),
    ],
    focus: {Seg.torso},
  );

  static const superman = Movement(
    'superman',
    [
      Pose(
        root: Root.hip,
        at: _floorHip,
        torso: -90,
        arm: Limb(-90, -90),
        leg: Limb(90, 90),
      ),
      Pose(
        root: Root.hip,
        at: _floorHip,
        torso: -102,
        arm: Limb(-104, -106),
        leg: Limb(100, 100),
      ),
    ],
    slot: Slot.none,
    focus: {Seg.torso},
  );

  // ----------------------------------------------------------- Shoulders

  // Facing us, as presses are usually shown: elbows out under the bar,
  // then arms straight overhead.
  static const overheadPress = Movement(
    'overhead_press',
    [Pose(arm: Limb(72, 166)), Pose(arm: Limb(132, 174))],
    view: View.front,
    focus: {Seg.arms},
  );

  static const seatedPress = Movement(
    'seated_press',
    [
      Pose(root: Root.hip, at: _seatedHip, leg: _seatedLegs, arm: _rack),
      Pose(root: Root.hip, at: _seatedHip, leg: _seatedLegs, arm: _overhead),
    ],
    scenery: [_seat],
    focus: {Seg.arms},
  );

  static const lateralRaise = Movement(
    'lateral_raise',
    [Pose(arm: Limb(12, 12)), Pose(arm: Limb(88, 88))],
    view: View.front,
    anchor: Offset(-0.15, -0.02),
    focus: {Seg.arms},
  );

  static const frontRaise = Movement(
    'front_raise',
    [Pose(arm: Limb(5, 5)), Pose(arm: Limb(92, 92))],
    focus: {Seg.arms},
  );

  // ---------------------------------------------------------------- Arms

  static const curl = Movement(
    'curl',
    [Pose(arm: Limb(0, 0)), Pose(arm: Limb(-5, 150))],
    anchor: Offset(0.22, -0.04),
    focus: {Seg.arms},
  );

  static const pushdown = Movement(
    'pushdown',
    [Pose(torso: 172, arm: Limb(-5, 140)), Pose(torso: 172, arm: Limb(-5, 5))],
    anchor: Offset(0.14, -1.02),
    focus: {Seg.arms},
  );

  static const overheadExtension = Movement(
    'overhead_extension',
    [Pose(arm: Limb(170, -20)), Pose(arm: Limb(172, 178))],
    anchor: Offset(-0.3, -0.05),
    focus: {Seg.arms},
  );

  static const skullCrusher = Movement(
    'skull_crusher',
    [
      Pose(
        root: Root.hip,
        at: _lyingHip,
        torso: -90,
        leg: _feetOnFloor,
        arm: Limb(190, 190),
      ),
      Pose(
        root: Root.hip,
        at: _lyingHip,
        torso: -90,
        leg: _feetOnFloor,
        arm: Limb(195, 295),
      ),
    ],
    scenery: [_flatBench],
    focus: {Seg.arms},
  );

  static const kickback = Movement(
    'kickback',
    [
      Pose(torso: 105, leg: Limb(20, -10), arm: Limb(-70, 0)),
      Pose(torso: 105, leg: Limb(20, -10), arm: Limb(-70, -72)),
    ],
    focus: {Seg.arms},
  );

  // ---------------------------------------------------------------- Core

  static const crunch = Movement(
    'crunch',
    [
      Pose(
        root: Root.hip,
        at: _floorHip,
        torso: -92,
        arm: Limb.to(Offset(-0.08, -0.06), frame: _shoulder),
        leg: Limb.to(Offset(0.3, -0.03), bend: -1),
      ),
      Pose(
        root: Root.hip,
        at: _floorHip,
        torso: -125,
        arm: Limb.to(Offset(-0.03, -0.11), frame: _shoulder),
        leg: Limb.to(Offset(0.3, -0.03), bend: -1),
      ),
    ],
    slot: Slot.none,
    focus: {Seg.torso},
    seconds: 2.2,
  );

  static const sitUp = Movement(
    'sit_up',
    [
      Pose(
        root: Root.hip,
        at: _floorHip,
        torso: -92,
        arm: Limb.to(Offset(-0.08, -0.06), frame: _shoulder),
        leg: Limb.to(Offset(0.3, -0.03), bend: -1),
      ),
      Pose(
        root: Root.hip,
        at: _floorHip,
        torso: -172,
        arm: Limb.to(Offset(0.02, -0.12), frame: _shoulder),
        leg: Limb.to(Offset(0.3, -0.03), bend: -1),
      ),
    ],
    slot: Slot.none,
    focus: {Seg.torso},
  );

  static const legRaise = Movement(
    'leg_raise',
    [
      Pose(
        root: Root.hip,
        at: _floorHip,
        torso: -90,
        arm: Limb(90, 90),
        leg: Limb(88, 88),
      ),
      Pose(
        root: Root.hip,
        at: _floorHip,
        torso: -90,
        arm: Limb(90, 90),
        leg: Limb(176, 176),
      ),
    ],
    slot: Slot.none,
    focus: {Seg.torso},
  );

  static const hangingLegRaise = Movement(
    'hanging_leg_raise',
    [
      Pose(root: Root.hands, at: Offset(0, -1), arm: Limb(180, 180)),
      Pose(
        root: Root.hands,
        at: Offset(0, -1),
        arm: Limb(180, 180),
        leg: Limb(92, 92),
      ),
    ],
    slot: Slot.none,
    scenery: [Bar(Offset(0, -1))],
    focus: {Seg.torso},
  );

  static const hangingKneeRaise = Movement(
    'hanging_knee_raise',
    [
      Pose(root: Root.hands, at: Offset(0, -1), arm: Limb(180, 180)),
      Pose(
        root: Root.hands,
        at: Offset(0, -1),
        arm: Limb(180, 180),
        leg: Limb(105, 0),
      ),
    ],
    slot: Slot.none,
    scenery: [Bar(Offset(0, -1))],
    focus: {Seg.torso},
  );

  static const plank = Movement(
    'plank',
    [
      Pose(
        root: Root.hands,
        at: Offset(0.4, -0.02),
        torso: 100,
        arm: Limb(0, 90),
        leg: Limb.to(Offset(-0.4, -0.05), bend: -1, end: 20),
      ),
      Pose(
        root: Root.hands,
        at: Offset(0.4, -0.02),
        torso: 101.5,
        arm: Limb(0, 90),
        leg: Limb.to(Offset(-0.4, -0.05), bend: -1, end: 20),
      ),
    ],
    slot: Slot.none,
    focus: {Seg.torso},
    seconds: 4,
  );

  static const twist = Movement(
    'twist',
    [
      Pose(
        root: Root.hip,
        at: _floorHip,
        torso: 200,
        head: 190,
        leg: Limb(125, 65),
        arm: Limb.to(Offset(0.2, 0.1), frame: _shoulder),
      ),
      Pose(
        root: Root.hip,
        at: _floorHip,
        torso: 200,
        head: 190,
        leg: Limb(125, 65),
        arm: Limb.to(Offset(0.04, 0.17), frame: _shoulder),
      ),
    ],
    focus: {Seg.torso},
    seconds: 1.8,
  );

  static const woodChop = Movement(
    'wood_chop',
    [
      Pose(
        arm: Limb.to(Offset(0.25, -0.62), frame: _hip),
        armFar: Limb.to(Offset(-0.25, -0.62), frame: _hip),
      ),
      Pose(
        arm: Limb.to(Offset(-0.2, -0.06), frame: _hip),
        armFar: Limb.to(Offset(0.2, -0.06), frame: _hip),
      ),
    ],
    view: View.front,
    focus: {Seg.torso},
  );

  static const sideBend = Movement(
    'side_bend',
    [
      Pose(arm: Limb(4, 4)),
      Pose(torso: 162, arm: Limb(-12, -12), armFar: Limb(25, 25)),
    ],
    view: View.front,
    focus: {Seg.torso},
  );

  static const mountainClimber = Movement(
    'mountain_climber',
    [
      Pose(
        root: Root.hands,
        at: Offset(0.3, -0.02),
        torso: 110,
        arm: Limb(5, 5),
        leg: Limb(30, -60, 20),
        legFar: Limb(-72, -72, 20),
      ),
      Pose(
        root: Root.hands,
        at: Offset(0.3, -0.02),
        torso: 110,
        arm: Limb(5, 5),
        leg: Limb(-72, -72, 20),
        legFar: Limb(30, -60, 20),
      ),
    ],
    slot: Slot.none,
    focus: {Seg.torso, Seg.legs},
    seconds: 1,
  );

  // -------------------------------------------------------- Full body

  static const kettlebellSwing = Movement(
    'swing',
    [
      Pose(torso: 118, leg: Limb(45, -18), arm: Limb(-15, -15)),
      Pose(arm: Limb(92, 92)),
    ],
    focus: {Seg.legs, Seg.torso},
    seconds: 1.8,
  );

  static const clean = Movement(
    'clean',
    [Pose(torso: 118, leg: Limb(60, -22)), Pose(arm: _rack)],
    focus: {Seg.legs, Seg.torso},
  );

  static const cleanAndPress = Movement(
    'clean_press',
    [
      Pose(torso: 118, leg: Limb(60, -22)),
      Pose(arm: _rack),
      Pose(arm: _overhead),
    ],
    focus: {Seg.legs, Seg.arms},
    seconds: 3.6,
  );

  static const snatch = Movement(
    'snatch',
    [Pose(torso: 118, leg: Limb(60, -22)), Pose(arm: _overhead)],
    focus: {Seg.legs, Seg.arms},
  );

  static const thruster = Movement(
    'thruster',
    [Pose(torso: 155, leg: Limb(86, -36), arm: _rack), Pose(arm: _overhead)],
    focus: {Seg.legs, Seg.arms},
  );

  static const burpee = Movement(
    'burpee',
    [
      Pose(),
      Pose(torso: 125, leg: Limb(95, -40), arm: Limb(10, 10)),
      Pose(
        at: Offset(-0.45, -0.045),
        torso: 112,
        leg: Limb(-72, -72, 20),
        arm: Limb(10, 10),
      ),
      Pose(torso: 125, leg: Limb(95, -40), arm: Limb(10, 10)),
      Pose(at: Offset(0, -0.12), leg: Limb(0, 0, 30), arm: Limb(170, 175)),
    ],
    loop: true,
    slot: Slot.none,
    focus: {Seg.legs, Seg.arms},
    seconds: 4,
  );

  static const jumpingJack = Movement(
    'jumping_jack',
    [
      Pose(root: Root.hip, at: Offset(0, -0.435), arm: Limb(8, 8)),
      Pose(
        root: Root.hip,
        at: Offset(0, -0.44),
        arm: Limb(160, 170),
        leg: Limb(18, 18),
      ),
    ],
    view: View.front,
    slot: Slot.none,
    seconds: 1.2,
  );

  // ----------------------------------------------------------- Cardio

  // A running stride in four keyframes, as animators draw it: contact
  // (front foot reaching, back foot pushing off), passing (the back knee
  // driving through high under the body, the body at its highest), and the
  // same on the other side. Arms swing against the legs.
  static const run = Movement(
    'run',
    [
      Pose(
        root: Root.hip,
        at: Offset(0, -0.42),
        torso: 170,
        leg: Limb(42, 12, 96),
        legFar: Limb(-28, -72, 40),
        arm: Limb(-42, 40),
        armFar: Limb(42, 122),
      ),
      Pose(
        root: Root.hip,
        at: Offset(0, -0.455),
        torso: 170,
        leg: Limb(-8, -22, 76),
        legFar: Limb(62, -28, 80),
        arm: Limb(-12, 78),
        armFar: Limb(14, 98),
      ),
      Pose(
        root: Root.hip,
        at: Offset(0, -0.42),
        torso: 170,
        leg: Limb(-28, -72, 40),
        legFar: Limb(42, 12, 96),
        arm: Limb(42, 122),
        armFar: Limb(-42, 40),
      ),
      Pose(
        root: Root.hip,
        at: Offset(0, -0.455),
        torso: 170,
        leg: Limb(62, -28, 80),
        legFar: Limb(-8, -22, 76),
        arm: Limb(14, 98),
        armFar: Limb(-12, 78),
      ),
    ],
    loop: true,
    slot: Slot.none,
    focus: {Seg.legs},
    seconds: 0.9,
  );

  // A walk in four keyframes: contact (heel down ahead, back heel lifting,
  // body lowest), passing (the back leg swinging through with a bent knee,
  // body highest), and the same on the other side.
  static const walk = Movement(
    'walk',
    [
      Pose(
        root: Root.hip,
        at: Offset(0, -0.428),
        leg: Limb(22, 10, 94),
        legFar: Limb(-20, -26, 66),
        arm: Limb(-15, -10),
        armFar: Limb(15, 26),
      ),
      Pose(
        root: Root.hip,
        at: Offset(0, -0.442),
        leg: Limb(-2, -4, 90),
        legFar: Limb(18, -24, 84),
        arm: Limb(0, 6),
        armFar: Limb(0, 6),
      ),
      Pose(
        root: Root.hip,
        at: Offset(0, -0.428),
        leg: Limb(-20, -26, 66),
        legFar: Limb(22, 10, 94),
        arm: Limb(15, 26),
        armFar: Limb(-15, -10),
      ),
      Pose(
        root: Root.hip,
        at: Offset(0, -0.442),
        leg: Limb(18, -24, 84),
        legFar: Limb(-2, -4, 90),
        arm: Limb(0, 6),
        armFar: Limb(0, 6),
      ),
    ],
    loop: true,
    focus: {Seg.legs},
    seconds: 1.3,
  );

  static const jump = Movement(
    'jump',
    [
      Pose(arm: Limb(-15, 50)),
      Pose(at: Offset(0, -0.08), leg: Limb(0, 0, 35), arm: Limb(-15, 50)),
    ],
    slot: Slot.none,
    focus: {Seg.legs},
    seconds: 0.8,
  );

  static const _pedal = Offset(0.14, -0.14);
  static const _r = 0.09;

  static Limb _pedalAt(double dx, double dy) =>
      Limb.to(Offset(_pedal.dx + dx, _pedal.dy + dy), bend: -1, end: 95);

  static final cycling = Movement(
    'cycling',
    [
      for (final (dx, dy) in [(0.0, -_r), (_r, 0.0), (0.0, _r), (-_r, 0.0)])
        Pose(
          root: Root.hip,
          at: const Offset(0, -0.48),
          torso: 150,
          arm: const Limb(110, 95),
          leg: _pedalAt(dx, dy),
          legFar: _pedalAt(-dx, -dy),
        ),
    ],
    loop: true,
    slot: Slot.none,
    scenery: const [
      Bike(
        seat: Offset(0, -0.45),
        crank: _pedal,
        handlebar: Offset(0.41, -0.77),
      ),
    ],
    focus: {Seg.legs},
    seconds: 1.4,
  );

  // ---------------------------------------------------- Stretch, other

  static const forwardFold = Movement(
    'forward_fold',
    // Reaching up, then folding to touch the floor ahead of the toes.
    [Pose(arm: Limb(175, 178)), Pose(torso: 42, head: 28, arm: Limb(30, 26))],
    slot: Slot.none,
    seconds: 4.4,
  );

  // Standing on the far leg; the near hand holds the near foot to the
  // glutes, so the stretched leg is in front.
  static const quadStretch = Movement(
    'quad_stretch',
    [
      Pose(
        root: Root.hip,
        at: Offset(0, -0.435),
        leg: Limb(-18, 176),
        legFar: Limb.down,
        arm: Limb(-22, 8),
        armFar: Limb(40, 60),
      ),
      Pose(
        root: Root.hip,
        at: Offset(0, -0.435),
        leg: Limb(-26, 182),
        legFar: Limb.down,
        arm: Limb(-30, 4),
        armFar: Limb(40, 60),
      ),
    ],
    slot: Slot.none,
    focus: {Seg.legs},
    seconds: 4,
  );

  static const reach = Movement(
    'reach',
    [
      Pose(arm: Limb(10, 10)),
      Pose(torso: 168, arm: Limb(150, 160), armFar: Limb(165, 170)),
    ],
    view: View.front,
    slot: Slot.none,
    seconds: 4,
  );

  static const neck = Movement(
    'neck',
    [Pose(), Pose(head: 150)],
    slot: Slot.none,
    seconds: 3,
  );

  static const stand = Movement(
    'stand',
    [Pose(), Pose(lift: 0.008)],
    slot: Slot.none,
    seconds: 4,
  );

  // ------------------------------------------------- Core and forearms

  // Pallof press: side-on to a cable at chest height (drawn behind), the
  // hands press straight out from the chest and back, resisting the twist.
  static const pallofPress = Movement(
    'pallof_press',
    [
      // Angles at both ends, so the press blends in a straight line.
      Pose(torso: 176, leg: Limb(12, -6), arm: Limb(25, 155)),
      Pose(torso: 176, leg: Limb(12, -6), arm: Limb(88, 90)),
    ],
    anchor: Offset(-0.5, -0.6),
    focus: {Seg.torso},
    seconds: 3,
  );

  // Wrist curl: seated, forearms along the thighs; the wrists curl the
  // weight up and lower it.
  static const wristCurl = Movement(
    'wrist_curl',
    [
      Pose(
        root: Root.hip,
        at: _seatedHip,
        // Leaning in, elbows on the thighs, wrists just past the knees.
        torso: 130,
        leg: _seatedLegs,
        arm: Limb(10, 96),
      ),
      Pose(
        root: Root.hip,
        at: _seatedHip,
        torso: 130,
        leg: _seatedLegs,
        arm: Limb(10, 118),
      ),
    ],
    scenery: [_seat],
    focus: {Seg.arms},
    seconds: 1.8,
  );

  // Ab wheel rollout: kneeling, roll the wheel out until the body is long
  // and low, then pull back with the abs.
  static const abRollout = Movement(
    'ab_rollout',
    [
      Pose(
        root: Root.hip,
        at: Offset(0.105, -0.212),
        torso: 125,
        leg: Limb(-30, -90, 0),
        arm: Limb.to(Offset(0.34, -0.07)),
      ),
      Pose(
        root: Root.hip,
        at: Offset(0.197, -0.102),
        torso: 100,
        leg: Limb(-70, -90, 0),
        arm: Limb.to(Offset(0.73, -0.07)),
      ),
    ],
    fixed: Hold.ball,
    focus: {Seg.torso},
    seconds: 3.2,
  );

  // Reverse crunch: lying with knees bent in the air, curl the hips off
  // the floor bringing the knees towards the chest.
  static const reverseCrunch = Movement(
    'reverse_crunch',
    [
      Pose(
        root: Root.hip,
        at: _floorHip,
        torso: -92,
        arm: Limb(90, 90),
        leg: Limb(180, 90),
      ),
      Pose(
        root: Root.hip,
        at: Offset(0, -0.09),
        torso: -78,
        arm: Limb(90, 90),
        // 220° is up and back towards the chest; written past 180 so the
        // blend from 180 turns the short way.
        leg: Limb(220, 168),
      ),
    ],
    slot: Slot.none,
    focus: {Seg.torso},
    seconds: 2.4,
  );

  // Bicycle crunch: shoulders curled up, hands by the head, the legs
  // cycling: one knee in while the other leg reaches long.
  static const bicycleCrunch = Movement(
    'bicycle_crunch',
    [
      Pose(
        root: Root.hip,
        at: _floorHip,
        torso: -122,
        arm: Limb.to(Offset(-0.03, -0.11), frame: _shoulder),
        leg: Limb(212, 150),
        legFar: Limb(105, 95),
      ),
      Pose(
        root: Root.hip,
        at: _floorHip,
        torso: -122,
        arm: Limb.to(Offset(-0.03, -0.11), frame: _shoulder),
        leg: Limb(105, 95),
        legFar: Limb(212, 150),
      ),
    ],
    slot: Slot.none,
    focus: {Seg.torso, Seg.legs},
    seconds: 1.6,
  );

  // Seated calf raise: knees bent at the seat, heels rise off the floor
  // as the weight on the knees lifts.
  static const seatedCalfRaise = Movement(
    'seated_calf_raise',
    [
      Pose(
        root: Root.hip,
        at: _seatedHip,
        torso: 172,
        leg: _seatedLegs,
        arm: Limb(40, 100),
      ),
      Pose(
        root: Root.hip,
        at: Offset(0, _seatTop - 0.035),
        torso: 172,
        leg: Limb(99, -4, 45),
        arm: Limb(44, 100),
      ),
    ],
    slot: Slot.none,
    scenery: [_seat],
    focus: {Seg.legs},
    seconds: 2,
  );

  // Kneeling cable crunch: hands by the head, the trunk curls down
  // towards the thighs while the hips stay put.
  static const kneelingCrunch = Movement(
    'kneeling_crunch',
    [
      Pose(
        root: Root.hip,
        at: Offset(0, -0.23),
        torso: 170,
        leg: Limb(0, -90, -90),
        arm: Limb.to(Offset(0.03, -0.1), frame: _shoulder, bend: -1),
      ),
      Pose(
        root: Root.hip,
        at: Offset(0, -0.23),
        torso: 108,
        leg: Limb(0, -90, -90),
        arm: Limb.to(Offset(0.03, -0.1), frame: _shoulder, bend: -1),
      ),
    ],
    slot: Slot.none,
    anchor: Offset(0.12, -0.95),
    focus: {Seg.torso},
    seconds: 2.4,
  );

  // V-sit / L-sit hold: balanced on the seat bones, legs long and lifted,
  // arms reaching forward; a gentle sway shows it is held.
  static const vSit = Movement(
    'v_sit',
    [
      Pose(
        root: Root.hip,
        at: _floorHip,
        torso: 215,
        head: 200,
        leg: Limb(128, 128),
        arm: Limb(118, 118),
      ),
      Pose(
        root: Root.hip,
        at: _floorHip,
        torso: 212,
        head: 198,
        leg: Limb(132, 132),
        arm: Limb(122, 122),
      ),
    ],
    slot: Slot.none,
    focus: {Seg.torso},
    seconds: 3.6,
  );

  // Finger / forearm curls: the forearm rests along the thigh and only the
  // hand and fingers roll the weight up.
  static const fingerCurl = Movement(
    'finger_curl',
    [
      Pose(
        root: Root.hip,
        at: _seatedHip,
        torso: 130,
        leg: _seatedLegs,
        arm: Limb(10, 86),
      ),
      Pose(
        root: Root.hip,
        at: _seatedHip,
        torso: 130,
        leg: _seatedLegs,
        arm: Limb(10, 104),
      ),
    ],
    scenery: [_seat],
    focus: {Seg.arms},
    seconds: 1.6,
  );

  // Glute kickback / hip extension: hinged slightly forward, the working
  // leg drives straight back from the hip, knee nearly locked.
  static const gluteKickback = Movement(
    'glute_kickback',
    [
      Pose(
        root: Root.hip,
        at: _standingHip,
        torso: 160,
        leg: Limb(6, 10),
        legFar: Limb.down,
        arm: Limb(20, 20),
      ),
      Pose(
        root: Root.hip,
        at: _standingHip,
        torso: 155,
        leg: Limb(-46, -40),
        legFar: Limb.down,
        arm: Limb(24, 24),
      ),
    ],
    slot: Slot.none,
    anchor: Offset(0.45, -0.03),
    focus: {Seg.legs},
    seconds: 2.2,
  );

  // ------------------------------------------------- Arm variations

  // Seated curl: sitting tall on a bench, elbows pinned at the sides.
  static const seatedCurl = Movement(
    'seated_curl',
    [
      Pose(root: Root.hip, at: _seatedHip, leg: _seatedLegs, arm: Limb(0, 0)),
      Pose(
        root: Root.hip,
        at: _seatedHip,
        leg: _seatedLegs,
        arm: Limb(-5, 150),
      ),
    ],
    scenery: [_seat],
    focus: {Seg.arms},
  );

  // Preacher curl: upper arm rests forward on the angled pad, so only the
  // forearm moves, from nearly straight to fully curled.
  static const preacherCurl = Movement(
    'preacher_curl',
    [
      Pose(
        root: Root.hip,
        at: _seatedHip,
        torso: 165,
        leg: _seatedLegs,
        arm: Limb(48, 70),
      ),
      Pose(
        root: Root.hip,
        at: _seatedHip,
        torso: 165,
        leg: _seatedLegs,
        arm: Limb(48, 168),
      ),
    ],
    scenery: [
      _seat,
      Surface(Offset(0.07, -0.47), Offset(0.2, -0.38), legs: false),
    ],
    focus: {Seg.arms},
  );

  // Concentration curl: seated and leaning in, the elbow braced against
  // the inner thigh; the hand curls towards the shoulder.
  static const concentrationCurl = Movement(
    'concentration_curl',
    [
      Pose(
        root: Root.hip,
        at: _seatedHip,
        torso: 128,
        leg: _seatedLegs,
        arm: Limb(4, 6),
      ),
      Pose(
        root: Root.hip,
        at: _seatedHip,
        torso: 128,
        leg: _seatedLegs,
        arm: Limb(4, 158),
      ),
    ],
    scenery: [_seat],
    focus: {Seg.arms},
  );

  // Incline curl: lying back on an incline bench, arms hanging straight
  // down behind the body for a long stretch, then curled up.
  static const inclineCurl = Movement(
    'incline_curl',
    [
      Pose(
        root: Root.hip,
        at: Offset(0.05, -0.38),
        torso: -125,
        leg: _feetOnFloor,
        arm: Limb(0, 0),
      ),
      Pose(
        root: Root.hip,
        at: Offset(0.05, -0.38),
        torso: -125,
        leg: _feetOnFloor,
        arm: Limb(-2, 145),
      ),
    ],
    scenery: [Surface(Offset(0.1, -0.34), Offset(-0.22, -0.56))],
    focus: {Seg.arms},
  );

  // Spider / prone incline curl: chest down on an incline bench, upper
  // arms hanging straight down; the forearms curl up in front.
  static const spiderCurl = Movement(
    'spider_curl',
    [
      Pose(torso: 128, leg: Limb(22, 4), arm: Limb(0, 0)),
      Pose(torso: 128, leg: Limb(22, 4), arm: Limb(0, 150)),
    ],
    scenery: [Surface(Offset(-0.12, -0.42), Offset(0.12, -0.58))],
    focus: {Seg.arms},
  );

  // Seated overhead triceps extension: upper arms stay pointing up by the
  // ears while the weight lowers behind the head and presses back up.
  static const seatedOverheadExtension = Movement(
    'seated_overhead_extension',
    [
      Pose(
        root: Root.hip,
        at: _seatedHip,
        leg: _seatedLegs,
        arm: Limb(172, 178),
      ),
      Pose(
        root: Root.hip,
        at: _seatedHip,
        leg: _seatedLegs,
        arm: Limb(170, -20),
      ),
    ],
    scenery: [_seat],
    focus: {Seg.arms},
  );

  // Bench dip: hands on a bench behind the hips, legs out in front; the
  // elbows bend straight back as the hips sink, then press up.
  static const benchDip = Movement(
    'bench_dip',
    [
      Pose(
        root: Root.hands,
        at: Offset(-0.12, -0.37),
        torso: 176,
        arm: Limb(-12, -12),
        leg: Limb.to(Offset(0.42, -0.025), bend: -1),
      ),
      Pose(
        root: Root.hands,
        at: Offset(-0.12, -0.37),
        torso: 172,
        arm: Limb(-75, 6),
        leg: Limb.to(Offset(0.42, -0.025), bend: -1),
      ),
    ],
    slot: Slot.none,
    scenery: [Surface(Offset(-0.45, -0.37), Offset(-0.08, -0.37))],
    focus: {Seg.arms},
  );

  // Inverted (body) row: hanging under a low bar with a straight body,
  // heels on the floor; the chest pulls up to the bar.
  static const invertedRow = Movement(
    'inverted_row',
    [
      Pose(
        root: Root.hands,
        at: Offset(-0.2, -0.5),
        torso: -104,
        arm: Limb(180, 180),
        leg: Limb.to(Offset(0.5, -0.025), bend: -1),
      ),
      Pose(
        root: Root.hands,
        at: Offset(-0.2, -0.5),
        torso: -98,
        arm: Limb(150, -150),
        leg: Limb.to(Offset(0.5, -0.025), bend: -1),
      ),
    ],
    slot: Slot.none,
    scenery: [Bar(Offset(-0.2, -0.5))],
    focus: {Seg.arms, Seg.torso},
  );

  // Wall push-up: leaning into a wall with straight arms, the chest moves
  // towards the wall and back.
  static const wallPushUp = Movement(
    'wall_push_up',
    [
      Pose(torso: 158, arm: Limb.to(Offset(0.44, -0.6))),
      Pose(torso: 140, arm: Limb.to(Offset(0.44, -0.6))),
    ],
    slot: Slot.none,
    scenery: [Block(Rect.fromLTWH(0.45, -1.0, 0.05, 1.0))],
    focus: {Seg.arms, Seg.torso},
  );

  // Kneeling push-up: a push-up from the knees, body straight from knees
  // to shoulders.
  static const kneelingPushUp = Movement(
    'kneeling_push_up',
    [
      Pose(
        root: Root.hands,
        at: Offset(0.28, -0.02),
        torso: 128,
        arm: Limb(0, 0),
        leg: Limb(-52, -95, -100),
      ),
      Pose(
        root: Root.hands,
        at: Offset(0.28, -0.02),
        torso: 108,
        arm: Limb(-70, 30),
        leg: Limb(-74, -95, -100),
      ),
    ],
    slot: Slot.none,
    focus: {Seg.arms, Seg.torso},
  );

  // Seated hip abduction machine (front view): seated, knees push apart
  // against the pads and return.
  static const seatedAbduction = Movement(
    'seated_abduction',
    [
      Pose(
        root: Root.hip,
        at: Offset(0, -0.27),
        arm: Limb(18, 18),
        leg: Limb(8, 0),
      ),
      Pose(
        root: Root.hip,
        at: Offset(0, -0.27),
        arm: Limb(18, 18),
        leg: Limb(38, 0),
      ),
    ],
    view: View.front,
    slot: Slot.none,
    scenery: [Surface(Offset(-0.12, -0.24), Offset(0.12, -0.24))],
    focus: {Seg.legs},
  );

  // ------------------------------------------- Seated & kneeling forms
  //
  // Many standing exercises are also done sitting on a bench or kneeling.
  // These keep the same arm and trunk motion with the lower body placed
  // on a seat, or on the knees with the shins along the floor.

  static Movement _seatedOf(Movement m) => Movement(
    '${m.id}_seated',
    [
      for (final p in m.poses)
        Pose(
          root: Root.hip,
          at: m.front ? const Offset(0, -0.27) : _seatedHip,
          torso: p.torso,
          head: p.head,
          arm: p.arm,
          armFar: p.armFar,
          leg: m.front ? const Limb(8, 0) : _seatedLegs,
          legFar: m.front ? const Limb(8, 0) : _seatedLegs,
          lift: p.lift,
        ),
    ],
    view: m.view,
    slot: m.slot,
    fixed: m.fixed,
    anchor: m.anchor,
    scenery: [
      if (m.front)
        const Surface(Offset(-0.12, -0.24), Offset(0.12, -0.24))
      else
        _seat,
    ],
    focus: m.focus,
    seconds: m.seconds,
  );

  static Movement _kneelingOf(Movement m) => Movement(
    '${m.id}_kneeling',
    [
      for (final p in m.poses)
        Pose(
          root: Root.hip,
          at: const Offset(0, -(Body.thigh + 0.035)),
          torso: p.torso,
          head: p.head,
          arm: p.arm,
          armFar: p.armFar,
          leg: const Limb(0, -90, -90),
          legFar: const Limb(0, -90, -90),
          lift: p.lift,
        ),
    ],
    slot: m.slot,
    fixed: m.fixed,
    anchor: m.anchor,
    focus: m.focus,
    seconds: m.seconds,
  );

  static final seatedLateralRaise = _seatedOf(lateralRaise);
  static final seatedFrontRaise = _seatedOf(frontRaise);
  static final seatedReverseFly = _seatedOf(reverseFly);
  static final seatedKickback = _seatedOf(kickback);
  static final seatedShrug = _seatedOf(shrug);
  static final seatedSideBend = _seatedOf(sideBend);
  static final seatedGoodMorning = _seatedOf(goodMorning);
  static final seatedStretch = _seatedOf(reach);
  static final seatedChestPress = _seatedOf(standingChestPress);
  static final kneelingCurl = _kneelingOf(curl);
  static final kneelingRow = _kneelingOf(row);
  static final kneelingReverseFly = _kneelingOf(reverseFly);
  static final kneelingOverheadExtension = _kneelingOf(overheadExtension);
  static final kneelingStretch = _kneelingOf(reach);

  /// The seated or kneeling form of [m], when there is one.
  static Movement? seatedFormOf(Movement m) => switch (m.id) {
    'lateral_raise' => seatedLateralRaise,
    'front_raise' => seatedFrontRaise,
    'reverse_fly' => seatedReverseFly,
    'kickback' => seatedKickback,
    'shrug' => seatedShrug,
    'side_bend' => seatedSideBend,
    'good_morning' => seatedGoodMorning,
    'reach' || 'forward_fold' => seatedStretch,
    'curl' => seatedCurl,
    'overhead_press' => seatedPress,
    'overhead_extension' => seatedOverheadExtension,
    'row' => seatedRow,
    'standing_chest_press' => seatedChestPress,
    'dip' => benchDip,
    _ => null,
  };

  static Movement? kneelingFormOf(Movement m) => switch (m.id) {
    'curl' => kneelingCurl,
    'row' => kneelingRow,
    'reverse_fly' => kneelingReverseFly,
    'overhead_extension' => kneelingOverheadExtension,
    'reach' || 'forward_fold' => kneelingStretch,
    'crunch' => kneelingCrunch,
    'push_up' => kneelingPushUp,
    _ => null,
  };

  // ------------------------------------------------ More body positions

  // Chest-supported row: lying face down on an incline bench, the
  // weights row up from straight arms.
  static const chestSupportedRow = Movement(
    'chest_supported_row',
    [
      Pose(torso: 128, leg: Limb(22, 4), arm: Limb(0, 0)),
      Pose(torso: 128, leg: Limb(22, 4), arm: Limb(-62, 6)),
    ],
    scenery: [Surface(Offset(-0.12, -0.42), Offset(0.12, -0.58))],
    focus: {Seg.arms, Seg.torso},
  );

  // Standing chest press (cable, band or medicine ball): hands start at
  // the chest and press straight forward.
  static const standingChestPress = Movement(
    'standing_chest_press',
    [
      Pose(torso: 172, leg: Limb(6, -4), arm: Limb(-55, 95)),
      Pose(torso: 172, leg: Limb(6, -4), arm: Limb(88, 90)),
    ],
    anchor: Offset(-0.45, -0.55),
    focus: {Seg.arms, Seg.torso},
  );

  // Straight-arm pulldown: arms stay long and sweep from overhead down to
  // the thighs, the trunk hinged slightly forward.
  static const straightArmPulldown = Movement(
    'straight_arm_pulldown',
    [
      Pose(torso: 165, leg: Limb(8, -4), arm: Limb(150, 150)),
      Pose(torso: 165, leg: Limb(8, -4), arm: Limb(8, 8)),
    ],
    anchor: Offset(0.45, -1.0),
    focus: {Seg.arms, Seg.torso},
  );

  // Standing pulldown (band or cable): hands start overhead and the
  // elbows drive down to the sides.
  static const standingPulldown = Movement(
    'standing_pulldown',
    [
      Pose(torso: 172, arm: Limb(172, 176)),
      Pose(torso: 172, arm: Limb(-12, 160)),
    ],
    anchor: Offset(0.3, -1.05),
    focus: {Seg.arms, Seg.torso},
  );

  static final all = [
    squat,
    backSquat,
    frontSquat,
    jumpSquat,
    deadlift,
    romanianDeadlift,
    goodMorning,
    lunge,
    barbellLunge,
    stepUp,
    calfRaise,
    seatedCalfRaise,
    legPress,
    legExtension,
    legCurl,
    seatedLegCurl,
    abduction,
    seatedAbduction,
    gluteKickback,
    chestSupportedRow,
    standingChestPress,
    straightArmPulldown,
    standingPulldown,
    seatedLateralRaise,
    seatedFrontRaise,
    seatedReverseFly,
    seatedKickback,
    seatedShrug,
    seatedSideBend,
    seatedGoodMorning,
    seatedStretch,
    seatedChestPress,
    kneelingCurl,
    kneelingRow,
    kneelingReverseFly,
    kneelingOverheadExtension,
    kneelingStretch,
    bridge,
    hipThrust,
    benchPress,
    inclinePress,
    declinePress,
    floorPress,
    pushUp,
    wallPushUp,
    kneelingPushUp,
    fly,
    pullover,
    dip,
    benchDip,
    pullUp,
    pulldown,
    row,
    invertedRow,
    seatedRow,
    uprightRow,
    reverseFly,
    facePull,
    shrug,
    backExtension,
    superman,
    overheadPress,
    seatedPress,
    lateralRaise,
    frontRaise,
    curl,
    seatedCurl,
    preacherCurl,
    concentrationCurl,
    inclineCurl,
    spiderCurl,
    pushdown,
    overheadExtension,
    seatedOverheadExtension,
    skullCrusher,
    kickback,
    crunch,
    kneelingCrunch,
    vSit,
    sitUp,
    legRaise,
    hangingLegRaise,
    hangingKneeRaise,
    plank,
    twist,
    woodChop,
    sideBend,
    mountainClimber,
    kettlebellSwing,
    clean,
    cleanAndPress,
    snatch,
    thruster,
    burpee,
    jumpingJack,
    run,
    walk,
    jump,
    cycling,
    forwardFold,
    quadStretch,
    pallofPress,
    wristCurl,
    fingerCurl,
    abRollout,
    reverseCrunch,
    bicycleCrunch,
    reach,
    neck,
    stand,
  ];
}
