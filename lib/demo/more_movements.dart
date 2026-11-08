import 'dart:ui';

import 'package:health_app/demo/figure.dart';
import 'package:health_app/demo/movement.dart';

/// Movements for exercises the main set doesn't show the way their
/// instructions describe. Angles: see [Body].
abstract final class MoreMovements {
  // Upside down on the hands, heels against a wall behind: the head lowers
  // towards the floor and presses back up.
  static const handstandPushUp = Movement(
    'handstand_push_up',
    [
      Pose(
        root: Root.hands,
        at: Offset(0, -0.02),
        torso: 2,
        head: 0,
        arm: Limb(2, 0),
        leg: Limb(178, 180, 270),
      ),
      Pose(
        root: Root.hands,
        at: Offset(0, -0.02),
        torso: 8,
        head: 4,
        arm: Limb(-48, 42),
        leg: Limb(176, 180, 270),
      ),
    ],
    slot: Slot.none,
    scenery: [Block(Rect.fromLTRB(-0.16, -1.15, -0.1, 0))],
    focus: {Seg.arms},
  );

  // A single-leg squat: standing on one leg, the other held out in front,
  // sitting back and down.
  static const pistolSquat = Movement(
    'pistol_squat',
    [
      Pose(arm: Limb(70, 75), legFar: Limb(32, 32, 120)),
      Pose(
        torso: 140,
        leg: Limb(84, -34),
        legFar: Limb(84, 88, 160),
        arm: Limb(95, 95),
      ),
    ],
    focus: {Seg.legs},
  );

  // Inchworm: fold to the floor, walk the hands out to a plank, and back.
  static const inchworm = Movement(
    'inchworm',
    [
      Pose(arm: Limb(0, 0)),
      // Folded at the hips, hands reaching the floor ahead of the feet.
      Pose(torso: 45, head: 30, arm: Limb(32, 30)),
      Pose(
        root: Root.feet,
        torso: 70,
        head: 70,
        leg: Limb(-24, -24, 120),
        arm: Limb(18, 10),
      ),
      Pose(
        root: Root.feet,
        torso: 100,
        head: 104,
        leg: Limb(-56, -56, 150),
        arm: Limb(-4, -2),
      ),
    ],
    slot: Slot.none,
    focus: {Seg.torso, Seg.arms},
    seconds: 4.8,
  );

  // Jefferson squat: astride the bar, gripping it between the legs, and
  // squatting down with it.
  static const jeffersonSquat = Movement(
    'jefferson_squat',
    [
      Pose(torso: 172, arm: Limb(4, 0), legFar: Limb(-14, -10)),
      Pose(
        torso: 150,
        leg: Limb(78, -28),
        legFar: Limb(50, -40),
        arm: Limb(-2, -2),
      ),
    ],
    focus: {Seg.legs},
  );

  // One-arm push-up: feet wide, the free hand behind the back.
  static const oneArmPushUp = Movement(
    'one_arm_push_up',
    [
      Pose(
        root: Root.hands,
        at: Offset(0.3, -0.02),
        torso: 112,
        arm: Limb(0, 0),
        armFar: Limb(-70, -20),
        leg: Limb.to(Offset(-0.36, -0.05), bend: -1, end: 20),
      ),
      Pose(
        root: Root.hands,
        at: Offset(0.3, -0.02),
        torso: 101,
        arm: Limb(-70, 30),
        armFar: Limb(-110, -60),
        leg: Limb.to(Offset(-0.36, -0.05), bend: -1, end: 20),
      ),
    ],
    slot: Slot.none,
    focus: {Seg.arms, Seg.torso},
  );

  // Face down over a stability ball, feet on the floor: the chest lifts
  // off the ball and lowers.
  static const ballBackExtension = Movement(
    'ball_back_extension',
    [
      Pose(
        root: Root.hip,
        at: Offset(0, -0.38),
        torso: 40,
        head: 40,
        leg: Limb.to(Offset(-0.42, -0.025), bend: 1, end: 20),
        arm: Limb(40, 120),
      ),
      Pose(
        root: Root.hip,
        at: Offset(0, -0.38),
        torso: 100,
        head: 110,
        leg: Limb.to(Offset(-0.42, -0.025), bend: 1, end: 20),
        arm: Limb(150, 210),
      ),
    ],
    slot: Slot.none,
    scenery: [Ball(Offset(0.04, -0.17), 0.17)],
    focus: {Seg.torso},
  );

  // Lying back over a stability ball, feet on the floor: curling the
  // shoulders up off the ball.
  static const ballCrunch = Movement(
    'ball_crunch',
    [
      Pose(
        root: Root.hip,
        at: Offset(0.04, -0.4),
        torso: -100,
        head: -110,
        leg: Limb.to(Offset(0.34, -0.025), bend: -1, end: 95),
        arm: Limb(-150, -40),
      ),
      Pose(
        root: Root.hip,
        at: Offset(0.04, -0.4),
        torso: -140,
        head: -150,
        leg: Limb.to(Offset(0.34, -0.025), bend: -1, end: 95),
        arm: Limb(-175, -60),
      ),
    ],
    slot: Slot.none,
    scenery: [Ball(Offset(-0.06, -0.19), 0.19)],
    focus: {Seg.torso},
  );

  static const all = [
    ballCrunch,
    handstandPushUp,
    pistolSquat,
    inchworm,
    jeffersonSquat,
    oneArmPushUp,
    ballBackExtension,
  ];
}
