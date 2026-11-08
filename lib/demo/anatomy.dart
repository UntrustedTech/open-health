import 'dart:ui';

/// A point on a body part's outline: [t] of the way along its bone (0 at
/// the joint it hangs from, 1 at the next), and [w] figure units out from
/// the bone's line.
typedef Station = (double t, double w);

/// One body part's shape: its two outlines along the bone, and the muscle
/// lines drawn inside it, each a list of stations (w positive on side A).
class PartShape {
  const PartShape({required this.a, required this.b, this.lines = const []});

  /// The front of the part seen side on (biceps, quads), or the outer
  /// edge seen from the front (deltoid, the sweep of the thigh).
  final List<Station> a;

  /// The back (triceps, hamstrings, calf), or the inner edge.
  final List<Station> b;

  /// Muscle and bone lines inside the part, w measured toward side A.
  final List<List<Station>> lines;
}

/// The figure's parts, shaped as an anatomy illustration: an athletic body
/// whose muscles show in its outline and in a few inner lines. Widths are
/// for the male figure.
abstract final class Anatomy {
  // ---------------------------------------------------------------- arms

  /// Shoulder to elbow, side on: front deltoid and biceps in front, rear
  /// deltoid and triceps behind.
  static const upperArmSide = PartShape(
    a: [
      (-0.06, 0.028),
      (0.06, 0.044),
      (0.24, 0.042),
      (0.4, 0.034),
      (0.62, 0.04),
      (0.82, 0.031),
      (1.0, 0.026),
    ],
    b: [
      (-0.06, 0.034),
      (0.08, 0.046),
      (0.28, 0.044),
      (0.5, 0.042),
      (0.72, 0.036),
      (0.9, 0.029),
      (1.04, 0.025),
    ],
    lines: [
      // The deltoid's lower edge, and the biceps' long head.
      [(0.18, 0.05), (0.32, 0.0), (0.4, -0.048)],
      [(0.5, 0.03), (0.68, 0.034), (0.86, 0.02)],
      // The triceps' horseshoe.
      [(0.48, -0.045), (0.62, -0.025), (0.8, -0.03)],
    ],
  );

  /// Shoulder to elbow from the front: the round deltoid cap outside, the
  /// arm narrowing in toward the armpit.
  static const upperArmFront = PartShape(
    a: [
      (-0.04, 0.03),
      (0.06, 0.046),
      (0.22, 0.046),
      (0.4, 0.036),
      (0.62, 0.038),
      (0.86, 0.031),
      (1.02, 0.027),
    ],
    b: [
      (0.04, 0.028),
      (0.3, 0.034),
      (0.58, 0.034),
      (0.84, 0.029),
      (1.02, 0.026),
    ],
    lines: [
      // The deltoid's edge, then the biceps.
      [(0.3, 0.044), (0.36, 0.016), (0.4, -0.018)],
      [(0.52, 0.0), (0.72, 0.006), (0.9, 0.0)],
    ],
  );

  /// Elbow to wrist: the forearm swells below the elbow and tapers.
  static const forearmSide = PartShape(
    a: [
      (-0.04, 0.03),
      (0.18, 0.038),
      (0.4, 0.034),
      (0.7, 0.026),
      (0.98, 0.021),
    ],
    b: [(-0.06, 0.03), (0.14, 0.036), (0.38, 0.03), (0.7, 0.024), (0.98, 0.02)],
    lines: [
      [(0.1, 0.02), (0.4, 0.006), (0.75, -0.004)],
    ],
  );

  static const forearmFront = PartShape(
    a: [
      (-0.04, 0.031),
      (0.2, 0.04),
      (0.45, 0.033),
      (0.75, 0.025),
      (0.98, 0.021),
    ],
    b: [(-0.04, 0.028), (0.22, 0.033), (0.5, 0.026), (0.98, 0.02)],
    lines: [
      [(0.12, 0.026), (0.45, 0.01), (0.8, 0.004)],
    ],
  );

  // ---------------------------------------------------------------- legs

  /// Hip to knee, side on: the quads' curve in front, hamstrings behind.
  static const thighSide = PartShape(
    a: [
      (-0.06, 0.05),
      (0.18, 0.058),
      (0.45, 0.06),
      (0.75, 0.05),
      (0.93, 0.038),
      (1.04, 0.032),
    ],
    b: [(-0.04, 0.062), (0.2, 0.058), (0.5, 0.054), (0.8, 0.042), (1.0, 0.032)],
    lines: [
      // Rectus femoris down the front, and the kneecap.
      [(0.3, 0.035), (0.6, 0.03), (0.86, 0.02)],
      [(0.9, 0.03), (0.98, 0.04), (1.05, 0.03)],
      // The split between quads and hamstrings.
      [(0.4, -0.01), (0.7, -0.005), (0.92, 0.0)],
    ],
  );

  /// Hip to knee from the front: the outer sweep, and the teardrop just
  /// above the knee inside.
  static const thighFront = PartShape(
    a: [
      (-0.08, 0.058),
      (0.1, 0.066),
      (0.4, 0.062),
      (0.7, 0.05),
      (0.9, 0.037),
      (1.02, 0.031),
    ],
    b: [
      (0.02, 0.046),
      (0.3, 0.05),
      (0.62, 0.04),
      (0.8, 0.044),
      (0.92, 0.036),
      (1.02, 0.028),
    ],
    lines: [
      // The line between the outer and middle quads, the teardrop, and the
      // kneecap.
      [(0.35, 0.03), (0.62, 0.022), (0.86, 0.006)],
      [(0.62, -0.028), (0.78, -0.03), (0.9, -0.018)],
      [(0.95, -0.016), (1.02, 0.0), (0.95, 0.018)],
    ],
  );

  /// Knee to ankle, side on: the shin's straight front, the calf behind.
  static const shinSide = PartShape(
    a: [(-0.02, 0.03), (0.2, 0.03), (0.55, 0.026), (0.85, 0.021), (1.02, 0.02)],
    b: [
      (-0.02, 0.03),
      (0.2, 0.048),
      (0.4, 0.044),
      (0.62, 0.03),
      (0.85, 0.022),
      (1.02, 0.021),
    ],
    lines: [
      [(0.12, -0.035), (0.32, -0.032), (0.5, -0.016)],
    ],
  );

  static const shinFront = PartShape(
    a: [
      (-0.04, 0.035),
      (0.2, 0.044),
      (0.48, 0.034),
      (0.8, 0.024),
      (1.02, 0.021),
    ],
    b: [
      (-0.04, 0.033),
      (0.18, 0.042),
      (0.42, 0.032),
      (0.8, 0.023),
      (1.02, 0.02),
    ],
    lines: [
      // The shinbone, and the inner calf.
      [(0.12, 0.004), (0.5, 0.0), (0.88, 0.002)],
      [(0.14, -0.03), (0.3, -0.026), (0.48, -0.018)],
    ],
  );

  // --------------------------------------------------------------- torso

  /// Hips to neck from the front, as half-widths at points up the spine:
  /// hips, waist, the flare of the lats, under the arms, the shoulders,
  /// the slope of the traps into the neck.
  static const torsoFront = <Station>[
    (-0.06, 0.07),
    (0.16, 0.066),
    (0.36, 0.064),
    (0.56, 0.076),
    (0.72, 0.088),
    (0.86, 0.092),
    (0.96, 0.078),
    (1.03, 0.046),
    (1.08, 0.026),
  ];

  /// Hips to neck side on: the front (abs, chest) and back (seat, low
  /// back, lats).
  static const torsoSideFront = <Station>[
    (-0.04, 0.05),
    (0.26, 0.048),
    (0.5, 0.054),
    (0.68, 0.074),
    (0.84, 0.066),
    (0.97, 0.04),
    (1.06, 0.022),
  ];
  static const torsoSideBack = <Station>[
    (-0.06, 0.07),
    (0.1, 0.06),
    (0.3, 0.048),
    (0.52, 0.054),
    (0.74, 0.074),
    (0.92, 0.06),
    (1.03, 0.036),
    (1.08, 0.022),
  ];

  // ---------------------------------------------------------------- head

  /// The head from the front, around its centre: x across, y up.
  static const headFront = <Offset>[
    Offset(0, 0.064),
    Offset(0.036, 0.054),
    Offset(0.047, 0.022),
    Offset(0.045, -0.012),
    Offset(0.036, -0.04),
    Offset(0.02, -0.058),
    Offset(0, -0.062),
    Offset(-0.02, -0.058),
    Offset(-0.036, -0.04),
    Offset(-0.045, -0.012),
    Offset(-0.047, 0.022),
    Offset(-0.036, 0.054),
  ];

  /// The head side on, around its centre: x toward the face, y up. The
  /// round back of the skull, brow, nose, lips, chin and jaw.
  static const headSide = <Offset>[
    Offset(-0.004, 0.066),
    Offset(0.03, 0.054),
    Offset(0.044, 0.026),
    Offset(0.047, 0.012),
    Offset(0.056, -0.002),
    Offset(0.047, -0.012),
    Offset(0.048, -0.028),
    Offset(0.042, -0.044),
    Offset(0.026, -0.058),
    Offset(0.004, -0.054),
    Offset(-0.02, -0.04),
    Offset(-0.044, -0.01),
    Offset(-0.048, 0.022),
    Offset(-0.036, 0.05),
  ];
}
