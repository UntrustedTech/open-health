import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'package:health_app/demo/anatomy.dart';
import 'package:health_app/demo/figure.dart';
import 'package:health_app/demo/framing.dart';
import 'package:health_app/demo/movement.dart';

/// The card and ink of the drawings.
abstract final class IllustrationColors {
  static const paper = Color(0xFF2B2B2D);
  static const ink = Color(0xFFFFFFFF);
}

/// Draws [movement] at [t] (0–1 through a cycle) as an anatomy
/// illustration in white line on a dark card: an athletic figure whose
/// every part has a shaped outline (deltoids, biceps, forearms, the sweep of
/// the quads, calves, a V-shaped torso) with its muscles drawn in, in shorts
/// and trainers, holding equipment drawn the same way.
class IllustrationPainter extends CustomPainter {
  IllustrationPainter({
    required this.movement,
    required this.hold,
    required this.t,
    this.body = BodyStyle.male,
    super.repaint,
  });

  final Movement movement;
  final Hold hold;
  final BodyStyle body;

  /// Read on every paint, so an animation can drive it via [repaint].
  final double Function() t;

  // Set for each paint.
  double _line = 0.006;
  double _fine = 0.0032;
  bool _detail = true;

  /// Below this many pixels per figure unit the inner lines are left out.
  static const _detailScale = 140.0;

  double get _arms => switch (body) {
    BodyStyle.male => 1.16,
    BodyStyle.female => 0.92,
    BodyStyle.neutral => 1.04,
  };
  double get _legs => switch (body) {
    BodyStyle.male => 1.14,
    BodyStyle.female => 1.06,
    BodyStyle.neutral => 1.1,
  };
  double get _shoulders => switch (body) {
    BodyStyle.male => 1.14,
    BodyStyle.female => 0.9,
    BodyStyle.neutral => 1.02,
  };
  double get _hips => switch (body) {
    BodyStyle.male => 1.0,
    BodyStyle.female => 1.1,
    BodyStyle.neutral => 1.04,
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bounds = Framing.boundsOf(movement, hold);
    final scale = math.min(
      size.width * 0.88 / bounds.width,
      size.height * 0.84 / bounds.height,
    );
    // Bold outlines and lighter inner lines, as in the reference.
    _line = math.max(0.0085, 1.6 / scale);
    _fine = math.max(0.0042, 0.9 / scale);
    _detail = scale >= _detailScale;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-bounds.center.dx, -bounds.center.dy);

    final s = movement.skeletonAt(t());
    _floor(canvas, bounds);
    for (final sc in movement.scenery) {
      _scenery(canvas, sc);
    }
    if (hold == Hold.cable || hold == Hold.band) _cables(canvas, s);

    if (s.front) {
      _leg(canvas, s, far: true);
      _leg(canvas, s, far: false);
      _torso(canvas, s);
      _frontShorts(canvas, s);
      _head(canvas, s);
      _arm(canvas, s, far: true);
      _arm(canvas, s, far: false);
      _props(canvas, s);
      if (hold == Hold.dumbbells) {
        _dumbbell(canvas, s, s[J.wristF], s[J.elbowF]);
        _dumbbell(canvas, s, s[J.wristN], s[J.elbowN]);
      }
      _hand(canvas, s, far: true);
      _hand(canvas, s, far: false);
    } else {
      _arm(canvas, s, far: true);
      _hand(canvas, s, far: true);
      if (hold == Hold.dumbbells) {
        _dumbbell(canvas, s, s[J.wristF], s[J.elbowF], far: true);
      }
      _leg(canvas, s, far: true);
      _sideShorts(canvas, s, far: true);
      _torso(canvas, s);
      _leg(canvas, s, far: false);
      _sideShorts(canvas, s, far: false);
      _head(canvas, s);
      _props(canvas, s);
      _arm(canvas, s, far: false);
      if (hold == Hold.dumbbells) {
        _dumbbell(canvas, s, s[J.wristN], s[J.elbowN]);
      }
      _hand(canvas, s, far: false);
    }
    canvas.restore();
  }

  // ----------------------------------------------------------------- ink

  Paint _ink({bool far = false, double? width}) => Paint()
    ..color = IllustrationColors.ink.withValues(alpha: far ? 0.5 : 1)
    ..strokeWidth = width ?? _line
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  Paint _detailInk({bool far = false}) => Paint()
    ..color = IllustrationColors.ink.withValues(alpha: far ? 0.32 : 0.78)
    ..strokeWidth = _fine
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final _paper = Paint()..color = IllustrationColors.paper;

  /// Fills [path] with the card (hiding what's behind) and outlines it.
  void _part(Canvas canvas, Path path, {bool far = false}) {
    canvas.drawPath(path, _paper);
    canvas.drawPath(path, _ink(far: far));
  }

  void _partCircle(
    Canvas canvas,
    Offset center,
    double radius, {
    bool far = false,
  }) => _part(
    canvas,
    Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    far: far,
  );

  void _partRRect(Canvas canvas, Rect rect, double radius) => _part(
    canvas,
    Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius))),
  );

  /// A bone's part and its inner lines.
  void _bone(
    Canvas canvas,
    Offset a,
    Offset b,
    PartShape shape,
    Offset n,
    double k, {
    bool far = false,
  }) {
    _part(canvas, _outline(a, b, shape, n, k), far: far);
    _lines(canvas, a, b, shape, n, k, far: far);
  }

  void _stroke(Canvas canvas, List<Offset> points, {bool far = false}) {
    if (!_detail || points.length < 2) return;
    canvas.drawPath(_smooth(points), _detailInk(far: far));
  }

  // ------------------------------------------------------------ geometry

  /// A smooth curve through [p] (Catmull-Rom), closed when [closed].
  static Path _smooth(List<Offset> p, {bool closed = false}) {
    final path = Path()..moveTo(p.first.dx, p.first.dy);
    final n = p.length;
    if (n < 3) {
      for (final q in p.skip(1)) {
        path.lineTo(q.dx, q.dy);
      }
      if (closed) path.close();
      return path;
    }
    Offset at(int i) => closed ? p[(i % n + n) % n] : p[i.clamp(0, n - 1)];
    final segments = closed ? n : n - 1;
    for (var i = 0; i < segments; i++) {
      final p0 = at(i - 1), p1 = at(i), p2 = at(i + 1), p3 = at(i + 2);
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    if (closed) path.close();
    return path;
  }

  /// A point [st] along the bone [a]→[b], [n] being side A.
  static Offset _at(Offset a, Offset b, Offset n, Station st, double k) =>
      Offset.lerp(a, b, st.$1)! + n * (st.$2 * k);

  /// The outline of a part on the bone [a]→[b]: side A out along [n],
  /// round over the far end, back down side B, and round over the near
  /// end.
  static Path _outline(
    Offset a,
    Offset b,
    PartShape shape,
    Offset n,
    double k,
  ) {
    final d = b - a;
    final len = d.distance;
    final u = len < 1e-6 ? const Offset(0, 1) : d / len;
    final aEnd = shape.a.last, bEnd = shape.b.last;
    final aStart = shape.a.first, bStart = shape.b.first;
    final tipT = math.max(aEnd.$1, bEnd.$1);
    final tipW = (aEnd.$2 + bEnd.$2) / 2 * k;
    final baseT = math.min(aStart.$1, bStart.$1);
    final baseW = (aStart.$2 + bStart.$2) / 2 * k;
    final points = [
      for (final st in shape.a) _at(a, b, n, st, k),
      // Round over the end.
      Offset.lerp(a, b, tipT)! +
          u * (tipW * 0.45) +
          n * ((aEnd.$2 - bEnd.$2) / 2 * k),
      for (final st in shape.b.reversed) _at(a, b, -n, st, k),
      Offset.lerp(a, b, baseT)! - u * (baseW * 0.45),
    ];
    return _smooth(points, closed: true);
  }

  void _lines(
    Canvas canvas,
    Offset a,
    Offset b,
    PartShape shape,
    Offset n,
    double k, {
    bool far = false,
  }) {
    for (final line in shape.lines) {
      _stroke(canvas, [for (final st in line) _at(a, b, n, st, k)], far: far);
    }
  }

  /// The side-on "front" of a bone: the side the figure faces when the
  /// bone hangs down.
  static Offset _front(Offset a, Offset b) {
    final d = b - a;
    final len = d.distance;
    return len < 1e-6 ? const Offset(1, 0) : Offset(d.dy, -d.dx) / len;
  }

  /// Seen from the front, the side of a bone away from the body's middle.
  static Offset _outward(Offset a, Offset b, Offset middle) {
    final n = _front(a, b);
    final mid = Offset.lerp(a, b, 0.5)!;
    final away = (mid - middle).dx * n.dx + (mid - middle).dy * n.dy;
    return away >= 0 ? n : -n;
  }

  /// The direction the figure faces (side on), or up the spine's side
  /// (from the front), from the spine [up].
  static Offset _facing(Offset up) => Offset(-up.dy, up.dx);

  // ---------------------------------------------------------------- arms

  void _arm(Canvas canvas, Skeleton s, {required bool far}) {
    final (shoulder, elbow, wrist) = far
        ? (s[J.shoulderF], s[J.elbowF], s[J.wristF])
        : (s[J.shoulderN], s[J.elbowN], s[J.wristN]);
    final faded = far && !s.front;
    final k = _arms;
    final upper = s.front ? Anatomy.upperArmFront : Anatomy.upperArmSide;
    final fore = s.front ? Anatomy.forearmFront : Anatomy.forearmSide;
    final middle = s[J.pelvis] + (s[J.neck] - s[J.pelvis]) * 0.6;
    Offset normal(Offset a, Offset b) =>
        s.front ? _outward(a, b, middle) : _front(a, b);
    _bone(canvas, elbow, wrist, fore, normal(elbow, wrist), k, far: faded);
    _bone(
      canvas,
      shoulder,
      elbow,
      upper,
      normal(shoulder, elbow),
      k,
      far: faded,
    );
  }

  /// A closed fist at the end of the forearm, its knuckles marked.
  void _hand(Canvas canvas, Skeleton s, {required bool far}) {
    final (elbow, wrist) = far
        ? (s[J.elbowF], s[J.wristF])
        : (s[J.elbowN], s[J.wristN]);
    final faded = far && !s.front;
    final d = wrist - elbow;
    final len = d.distance;
    if (len < 1e-6) return;
    final u = d / len;
    final n = Offset(u.dy, -u.dx);
    final w = 0.022 * _arms;
    Offset p(double along, double across) => wrist + u * along + n * across;
    _part(
      canvas,
      _smooth([
        p(-0.006, w * 0.9),
        p(0.02, w * 1.15),
        p(0.046, w * 1.05),
        p(0.058, 0),
        p(0.046, -w * 1.05),
        p(0.02, -w * 1.15),
        p(-0.006, -w * 0.9),
      ], closed: true),
      far: faded,
    );
    _stroke(canvas, [p(0.036, w), p(0.04, 0), p(0.036, -w)], far: faded);
  }

  // ---------------------------------------------------------------- legs

  void _leg(Canvas canvas, Skeleton s, {required bool far}) {
    final (hip, knee, ankle, toe) = far
        ? (s[J.hipF], s[J.kneeF], s[J.ankleF], s[J.toeF])
        : (s[J.hipN], s[J.kneeN], s[J.ankleN], s[J.toeN]);
    final faded = far && !s.front;
    final k = _legs;
    final thigh = s.front ? Anatomy.thighFront : Anatomy.thighSide;
    final shin = s.front ? Anatomy.shinFront : Anatomy.shinSide;
    final middle = s[J.pelvis];
    Offset normal(Offset a, Offset b) =>
        s.front ? _outward(a, b, middle) : _front(a, b);
    final nt = normal(hip, knee);
    _bone(canvas, knee, ankle, shin, normal(knee, ankle), k, far: faded);
    _bone(canvas, hip, knee, thigh, nt, k, far: faded);
    if (s.front) {
      _frontShoe(canvas, ankle, knee, nt);
    } else {
      _sideShoe(canvas, ankle, toe, knee, far: faded);
    }
  }

  /// A trainer side on: heel, collar, laces, toe and sole.
  void _sideShoe(
    Canvas canvas,
    Offset ankle,
    Offset toe,
    Offset knee, {
    bool far = false,
  }) {
    final d = toe - ankle;
    final len = d.distance;
    if (len < 1e-6) return;
    final f = d / len;
    var up = Offset(f.dy, -f.dx);
    if ((knee - ankle).dx * up.dx + (knee - ankle).dy * up.dy < 0) up = -up;
    Offset p(double along, double rise) => ankle + f * along + up * rise;
    _part(
      canvas,
      _smooth([
        p(-0.036, -0.022),
        p(-0.04, 0.008),
        p(-0.03, 0.03),
        p(-0.004, 0.034),
        p(0.016, 0.026),
        p(0.05, 0.014),
        p(0.078, 0.004),
        p(0.088, -0.01),
        p(0.08, -0.025),
        p(0.02, -0.027),
      ], closed: true),
      far: far,
    );
    _stroke(canvas, [
      p(-0.036, -0.012),
      p(0.03, -0.014),
      p(0.084, -0.014),
    ], far: far);
    _stroke(canvas, [p(0.016, 0.024), p(0.03, 0.02)], far: far);
    _stroke(canvas, [p(0.032, 0.02), p(0.046, 0.015)], far: far);
  }

  /// A trainer from the front, below the ankle.
  void _frontShoe(Canvas canvas, Offset ankle, Offset knee, Offset outward) {
    final d = ankle - knee;
    final len = d.distance;
    if (len < 1e-6) return;
    final down = d / len;
    Offset p(double across, double drop) =>
        ankle + outward * across + down * drop;
    _part(
      canvas,
      _smooth([
        p(-0.026, -0.016),
        p(0.03, -0.016),
        p(0.05, 0.008),
        p(0.058, 0.03),
        p(0.03, 0.04),
        p(-0.012, 0.04),
        p(-0.036, 0.032),
        p(-0.036, 0.004),
      ], closed: true),
    );
    _stroke(canvas, [p(-0.036, 0.026), p(0.01, 0.032), p(0.058, 0.026)]);
  }

  // --------------------------------------------------------------- torso

  void _torso(Canvas canvas, Skeleton s) {
    final pelvis = s[J.pelvis], neck = s[J.neck];
    final spine = neck - pelvis;
    final length = spine.distance;
    if (length < 1e-6) return;
    final up = spine / length;
    final side = _facing(up);
    Offset at(double f, double w) => pelvis + up * (f * length) + side * w;
    double widen(double f) {
      // The hips to the waist, then the chest and shoulders.
      final hipShare = (1 - f / 0.45).clamp(0.0, 1.0);
      return hipShare * _hips + (1 - hipShare) * _shoulders;
    }

    if (s.front) {
      final half = [for (final (f, w) in Anatomy.torsoFront) (f, w * widen(f))];
      _part(
        canvas,
        _smooth([
          for (final (f, w) in half) at(f, w),
          for (final (f, w) in half.reversed) at(f, -w),
        ], closed: true),
      );
      if (!_detail) return;
      final female = body == BodyStyle.female;
      for (final k in [1.0, -1.0]) {
        // Collarbones, the chest's lower edge, the side of the abs, the
        // obliques and the ribs under the arms.
        _stroke(canvas, [
          at(0.98, k * 0.012),
          at(0.96, k * 0.042),
          at(0.985, k * 0.074),
        ]);
        if (female) {
          _stroke(canvas, [
            at(0.84, k * 0.072),
            at(0.68, k * 0.06),
            at(0.64, k * 0.02),
          ]);
          _stroke(canvas, [at(0.98, k * 0.05), at(0.82, k * 0.05)]);
        } else {
          _stroke(canvas, [
            at(0.84, k * 0.078),
            at(0.68, k * 0.064),
            at(0.64, k * 0.024),
            at(0.66, k * 0.004),
          ]);
        }
        _stroke(canvas, [
          at(0.6, k * 0.034),
          at(0.36, k * 0.033),
          at(0.12, k * 0.026),
        ]);
        _stroke(canvas, [
          at(0.62, k * 0.06),
          at(0.4, k * 0.054),
          at(0.16, k * 0.042),
        ]);
        for (final f in [0.68, 0.62, 0.56]) {
          _stroke(canvas, [at(f, k * 0.07), at(f - 0.025, k * 0.058)]);
        }
      }
      if (female) {
        _stroke(canvas, [at(0.62, -0.06), at(0.6, 0), at(0.62, 0.06)]);
      } else {
        _stroke(canvas, [at(0.92, 0), at(0.66, 0)]);
      }
      // The six-pack: the centre line and three rows.
      _stroke(canvas, [at(0.58, 0), at(0.14, 0)]);
      for (final f in [0.5, 0.39, 0.28]) {
        _stroke(canvas, [at(f, -0.032), at(f - 0.012, 0), at(f, 0.032)]);
      }
      _stroke(canvas, [at(0.18, -0.006), at(0.16, 0), at(0.18, 0.006)]);
      return;
    }
    // Side on: the front (abs, chest) and the back (seat, lats).
    _part(
      canvas,
      _smooth([
        for (final (f, w) in Anatomy.torsoSideFront) at(f, w * widen(f)),
        for (final (f, w) in Anatomy.torsoSideBack.reversed)
          at(f, -w * widen(f)),
      ], closed: true),
    );
    if (!_detail) return;
    _stroke(canvas, [at(0.84, 0.03), at(0.68, 0.058), at(0.62, 0.05)]);
    for (final f in [0.48, 0.38, 0.28]) {
      _stroke(canvas, [at(f, 0.044), at(f - 0.012, 0.028)]);
    }
    _stroke(canvas, [at(0.84, -0.05), at(0.62, -0.03), at(0.44, -0.042)]);
    _stroke(canvas, [at(0.56, 0.04), at(0.34, 0.03), at(0.14, 0.036)]);
  }

  // ---------------------------------------------------------------- head

  void _head(Canvas canvas, Skeleton s) {
    final neck = s[J.neck];
    final toHead = s[J.head] - neck;
    final len = toHead.distance;
    final up = len < 1e-6 ? const Offset(0, -1) : toHead / len;
    final face = _facing(up);
    final centre = neck + up * 0.088;
    Offset h(Offset p) => centre + face * p.dx + up * p.dy;

    // The neck, its strap muscles running down to the collarbones.
    final neckW = 0.025 * _shoulders;
    _part(
      canvas,
      _smooth([
        neck + face * neckW - up * 0.01,
        neck + face * (neckW * 0.95) + up * 0.05,
        neck - face * (neckW * 0.95) + up * 0.05,
        neck - face * neckW - up * 0.01,
      ], closed: true),
    );
    if (s.front) {
      _stroke(canvas, [
        neck + face * 0.02 + up * 0.04,
        neck + face * 0.006 + up * 0.002,
      ]);
      _stroke(canvas, [
        neck - face * 0.02 + up * 0.04,
        neck - face * 0.006 + up * 0.002,
      ]);
    }

    if (body == BodyStyle.female && !s.front) {
      // A ponytail behind.
      _part(
        canvas,
        _smooth([
          h(const Offset(-0.03, 0.04)),
          h(const Offset(-0.07, 0.02)),
          h(const Offset(-0.074, -0.03)),
          h(const Offset(-0.05, -0.01)),
          h(const Offset(-0.036, 0.012)),
        ], closed: true),
      );
    }
    final outline = s.front ? Anatomy.headFront : Anatomy.headSide;
    _part(canvas, _smooth([for (final p in outline) h(p)], closed: true));
    if (!_detail) return;
    if (s.front) {
      for (final k in [1.0, -1.0]) {
        // Ears.
        _stroke(canvas, [
          h(Offset(k * 0.045, 0.02)),
          h(Offset(k * 0.054, 0.012)),
          h(Offset(k * 0.052, -0.006)),
          h(Offset(k * 0.044, -0.01)),
        ]);
      }
      // A short hairline.
      _stroke(canvas, [
        h(const Offset(-0.04, 0.03)),
        h(const Offset(0, 0.046)),
        h(const Offset(0.04, 0.03)),
      ]);
    } else {
      _stroke(canvas, [
        h(const Offset(-0.006, 0.016)),
        h(const Offset(-0.016, 0.01)),
        h(const Offset(-0.016, -0.008)),
        h(const Offset(-0.004, -0.014)),
      ]);
      _stroke(canvas, [
        h(const Offset(0.03, 0.05)),
        h(const Offset(-0.01, 0.054)),
        h(const Offset(-0.04, 0.036)),
      ]);
    }
  }

  // -------------------------------------------------------------- shorts

  /// [d] scaled to length 1, or [fallback] when it's too short to have a
  /// direction (two joints in the same place).
  static Offset _unit(Offset d, Offset fallback) {
    final len = d.distance;
    return len < 1e-6 ? fallback : d / len;
  }

  /// Shorts across both hips to mid-thigh, seen from the front, with a
  /// waistband, a seam and folds.
  void _frontShorts(Canvas canvas, Skeleton s) {
    final pelvis = s[J.pelvis];
    final spine = s[J.neck] - pelvis;
    final up = _unit(spine, const Offset(0, -1));
    final side = _facing(up);
    final hipW = 0.074 * _hips;
    Offset hem(Offset hip, Offset knee) => Offset.lerp(hip, knee, 0.46)!;
    final hemN = hem(s[J.hipN], s[J.kneeN]);
    final hemF = hem(s[J.hipF], s[J.kneeF]);
    final outN = _outward(s[J.hipN], s[J.kneeN], pelvis);
    final outF = _outward(s[J.hipF], s[J.kneeF], pelvis);
    final crotch = pelvis - up * 0.085;
    final sideN =
        (s[J.hipN] - pelvis).dx * side.dx + (s[J.hipN] - pelvis).dy * side.dy >=
            0
        ? 1.0
        : -1.0;
    final waistN = pelvis + up * 0.05 + side * (hipW * sideN);
    final waistF = pelvis + up * 0.05 - side * (hipW * sideN);
    final shape = Path()..moveTo(waistN.dx, waistN.dy);
    void line(Offset p) => shape.lineTo(p.dx, p.dy);
    void curve(Offset c, Offset p) =>
        shape.quadraticBezierTo(c.dx, c.dy, p.dx, p.dy);
    curve(s[J.hipN] + outN * 0.082, hemN + outN * 0.074);
    line(hemN - outN * 0.06);
    curve(crotch + (hemN - crotch) * 0.2, crotch);
    curve(crotch + (hemF - crotch) * 0.2, hemF - outF * 0.06);
    line(hemF + outF * 0.074);
    curve(s[J.hipF] + outF * 0.082, waistF);
    shape.close();
    _part(canvas, shape);
    if (!_detail) return;
    _stroke(canvas, [
      waistN - up * 0.018,
      pelvis + up * 0.03,
      waistF - up * 0.018,
    ]);
    _stroke(canvas, [pelvis + up * 0.03, crotch + up * 0.008]);
    for (final (h, out) in [(hemN, outN), (hemF, outF)]) {
      _stroke(canvas, [
        h - out * 0.02 - up * 0.004,
        h - out * 0.035 + up * 0.03,
      ]);
      _stroke(canvas, [
        h + out * 0.04 + up * 0.002,
        h + out * 0.05 + up * 0.028,
      ]);
    }
  }

  /// Shorts side on: over the seat and down the thigh.
  void _sideShorts(Canvas canvas, Skeleton s, {required bool far}) {
    final hip = far ? s[J.hipF] : s[J.hipN];
    final knee = far ? s[J.kneeF] : s[J.kneeN];
    final faded = far;
    final pelvis = s[J.pelvis];
    final spine = s[J.neck] - pelvis;
    final up = _unit(spine, const Offset(0, -1));
    final face = _facing(up);
    final hem = Offset.lerp(hip, knee, 0.44)!;
    final n = _front(hip, knee);
    final hips = _hips;
    // Front of the thigh is n; the seat rounds out behind the hips.
    final points = far
        ? [
            Offset.lerp(hip, hem, -0.1)! + n * 0.06,
            hem + n * 0.07,
            hem - n * 0.066,
            Offset.lerp(hip, hem, 0.2)! - n * 0.068,
          ]
        : [
            pelvis + up * 0.05 + face * (0.05 * hips),
            Offset.lerp(hip, hem, 0.3)! + n * 0.062,
            hem + n * 0.066,
            hem - n * 0.062,
            Offset.lerp(hip, hem, 0.35)! - n * 0.066,
            pelvis - face * (0.074 * hips) + up * 0.0,
            pelvis + up * 0.05 - face * (0.062 * hips),
          ];
    _part(canvas, _smooth(points, closed: true), far: faded);
    if (far || !_detail) return;
    _stroke(canvas, [
      pelvis + up * 0.032 + face * (0.05 * hips),
      pelvis + up * 0.032 - face * (0.064 * hips),
    ]);
    _stroke(canvas, [
      hem + n * 0.03 + (hip - hem) * 0.12,
      hem + n * 0.01 + (hip - hem) * 0.4,
    ]);
    _stroke(canvas, [
      hem - n * 0.03 + (hip - hem) * 0.1,
      hem - n * 0.045 + (hip - hem) * 0.32,
    ]);
  }

  // ----------------------------------------------------------- equipment

  /// A dumbbell in the hand: side on, its round end; from the front, the
  /// handle across the fist with a head each side.
  void _dumbbell(
    Canvas canvas,
    Skeleton s,
    Offset wrist,
    Offset elbow, {
    bool far = false,
  }) {
    final d = wrist - elbow;
    final len = d.distance;
    final u = len < 1e-6 ? const Offset(0, 1) : d / len;
    final grip = wrist + u * 0.028;
    if (!s.front) {
      _partCircle(canvas, grip, 0.04, far: far);
      if (_detail) {
        canvas.drawCircle(grip, 0.03, _detailInk(far: far));
      }
      return;
    }
    final across = Offset(u.dy, -u.dx);
    for (final k in [1.0, -1.0]) {
      final head = grip + across * (0.05 * k);
      _partRRect(
        canvas,
        Rect.fromCenter(center: head, width: 0.034, height: 0.06),
        0.01,
      );
    }
    _partRRect(
      canvas,
      Rect.fromCenter(center: grip, width: 0.072, height: 0.012),
      0.004,
    );
  }

  /// A plate of [height] at [centre], seen edge on, with its rim.
  void _plate(Canvas canvas, Offset centre, double width, double height) {
    final rect = Rect.fromCenter(center: centre, width: width, height: height);
    _partRRect(canvas, rect, width * 0.35);
    if (_detail) {
      canvas.drawLine(
        centre + Offset(0, -height / 2 + width * 0.6),
        centre + Offset(0, height / 2 - width * 0.6),
        _detailInk(),
      );
    }
  }

  void _props(Canvas canvas, Skeleton s) {
    final at = Framing.heldAt(movement, s);
    switch (hold) {
      case Hold.barbell when movement.front:
        // The bar across both fists, plates a side, as in the reference.
        final y = at.dy, cx = s[J.pelvis].dx;
        _partRRect(
          canvas,
          Rect.fromLTRB(cx - 0.36, y - 0.007, cx + 0.36, y + 0.007),
          0.007,
        );
        for (final k in [-1.0, 1.0]) {
          _partRRect(
            canvas,
            Rect.fromCenter(
              center: Offset(cx + k * 0.228, y),
              width: 0.014,
              height: 0.034,
            ),
            0.004,
          );
          _plate(canvas, Offset(cx + k * 0.262, y), 0.046, 0.21);
          _plate(canvas, Offset(cx + k * 0.306, y), 0.034, 0.15);
        }
      case Hold.barbell:
        // End on: the plate, its rim and the sleeve.
        _partCircle(canvas, at, 0.1);
        if (_detail) canvas.drawCircle(at, 0.082, _detailInk());
        _partCircle(canvas, at, 0.022);
      case Hold.kettlebell:
        final bell = at + const Offset(0, 0.062);
        canvas.drawArc(
          Rect.fromCircle(center: at + const Offset(0, 0.026), radius: 0.03),
          math.pi,
          math.pi,
          false,
          _ink(width: _line * 2.2),
        );
        _partCircle(canvas, bell, 0.05);
      case Hold.ball:
        _partCircle(canvas, at, 0.075);
        if (_detail) {
          canvas.drawArc(
            Rect.fromCircle(center: at + const Offset(0.05, 0), radius: 0.075),
            math.pi * 0.7,
            math.pi * 0.6,
            false,
            _detailInk(),
          );
          canvas.drawArc(
            Rect.fromCircle(center: at - const Offset(0.05, 0), radius: 0.075),
            -math.pi * 0.3,
            math.pi * 0.6,
            false,
            _detailInk(),
          );
        }
      case Hold.platform:
        final dir = _unit(s[J.ankleN] - s[J.kneeN], const Offset(0, 1));
        final n = Offset(-dir.dy, dir.dx);
        final toe = s[J.toeN];
        _part(
          canvas,
          _smooth([
            toe - n * 0.12 + dir * 0.02,
            toe + n * 0.12 + dir * 0.02,
            toe + n * 0.12 + dir * 0.05,
            toe - n * 0.12 + dir * 0.05,
          ], closed: true),
        );
      case Hold.pad:
        _partCircle(canvas, s[J.ankleN], 0.034);
      case Hold.cable || Hold.band:
        canvas.drawCircle(s[J.wristN] + const Offset(0, 0.02), 0.02, _ink());
      case Hold.dumbbells || Hold.none:
        break;
    }
  }

  void _cables(Canvas canvas, Skeleton s) {
    final a = movement.anchor;
    if (a == null) return;
    final paint = _ink(width: hold == Hold.band ? _line * 1.6 : _fine * 1.2);
    void pulley(Offset at) {
      _partCircle(canvas, at, 0.03);
      if (_detail) canvas.drawCircle(at, 0.01, _detailInk());
    }

    canvas.drawLine(a, s[J.wristN], paint);
    if (movement.front) {
      final mirrored = Offset(2 * s[J.pelvis].dx - a.dx, a.dy);
      canvas.drawLine(mirrored, s[J.wristF], paint);
      if (hold == Hold.cable) pulley(mirrored);
    }
    if (hold == Hold.cable) pulley(a);
  }

  // ------------------------------------------------------------- scenery

  void _floor(Canvas canvas, Rect bounds) {
    final half = bounds.width * 0.42;
    canvas.drawLine(
      Offset(bounds.center.dx - half, 0.012),
      Offset(bounds.center.dx + half, 0.012),
      _ink()..color = IllustrationColors.ink.withValues(alpha: 0.14),
    );
  }

  void _scenery(Canvas canvas, Scenery sc) {
    switch (sc) {
      case Surface(:final a, :final b, :final legs):
        if (legs) {
          final mid = Offset.lerp(a, b, 0.5)!;
          final post = _ink(width: _line * 1.4);
          canvas.drawLine(mid, Offset(mid.dx, 0), post);
          canvas.drawLine(
            Offset(mid.dx - 0.09, 0),
            Offset(mid.dx + 0.09, 0),
            post,
          );
        }
        final along = _unit(b - a, const Offset(1, 0));
        final n = Offset(-along.dy, along.dx);
        // The pad: a thick cushion with rounded ends.
        Offset c(double t, double w) => Offset.lerp(a, b, t)! + n * w;
        const r = 0.018;
        final inset = along * r;
        final pad = Path()
          ..moveTo((c(0, 0.026) + inset).dx, (c(0, 0.026) + inset).dy)
          ..lineTo((c(1, 0.026) - inset).dx, (c(1, 0.026) - inset).dy);
        void curve(Offset control, Offset end) =>
            pad.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
        curve(c(1, 0.026), c(1, 0.008));
        pad.lineTo(c(1, -0.008).dx, c(1, -0.008).dy);
        curve(c(1, -0.026), c(1, -0.026) - inset);
        pad.lineTo((c(0, -0.026) + inset).dx, (c(0, -0.026) + inset).dy);
        curve(c(0, -0.026), c(0, -0.008));
        pad.lineTo(c(0, 0.008).dx, c(0, 0.008).dy);
        curve(c(0, 0.026), c(0, 0.026) + inset);
        _part(canvas, pad..close());
        if (_detail) {
          canvas.drawLine(
            a - n * 0.004 + (b - a) * 0.03,
            b - n * 0.004 - (b - a) * 0.03,
            _detailInk(),
          );
        }
      case Bar(:final at):
        final post = Offset(at.dx - 0.3, at.dy);
        final frame = _ink(far: true, width: _line * 1.4);
        canvas.drawLine(Offset(post.dx, 0), post, frame);
        canvas.drawLine(post, at, frame);
        _partCircle(canvas, at, 0.02);
      case Block(:final rect):
        _partRRect(canvas, rect, 0.016);
      case Ball(:final center, :final radius):
        _partCircle(canvas, center, radius);
        if (_detail) {
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius * 0.72),
            math.pi * 1.15,
            math.pi * 0.5,
            false,
            _detailInk(),
          );
        }
      case Dome(:final center, :final radius):
        _part(
          canvas,
          Path()
            ..addArc(
              Rect.fromCenter(
                center: center,
                width: radius * 2,
                height: radius * 1.2,
              ),
              math.pi,
              math.pi,
            )
            ..close(),
        );
      case Bike():
        _bike(canvas, sc);
    }
  }

  void _bike(Canvas canvas, Bike b) {
    final frame = _ink(width: _line * 1.2);
    for (final hub in [b.rearHub, b.frontHub]) {
      canvas.drawCircle(hub, Bike.wheel, frame);
      if (_detail) canvas.drawCircle(hub, Bike.wheel * 0.88, _detailInk());
      canvas.drawCircle(hub, 0.012, frame);
    }
    final head = Offset(b.handlebar.dx - 0.03, b.handlebar.dy + 0.12);
    canvas
      ..drawLine(b.rearHub, b.crank, frame)
      ..drawLine(b.crank, b.seat, frame)
      ..drawLine(b.rearHub, b.seat + const Offset(0, 0.04), frame)
      ..drawLine(b.seat + const Offset(0, 0.04), head, frame)
      ..drawLine(b.crank, head, frame)
      ..drawLine(head, b.frontHub, frame)
      ..drawLine(head, b.handlebar, frame);
    _part(
      canvas,
      _smooth([
        b.seat + const Offset(-0.05, -0.006),
        b.seat + const Offset(0.045, -0.004),
        b.seat + const Offset(0.04, 0.012),
        b.seat + const Offset(-0.05, 0.012),
      ], closed: true),
    );
    canvas.drawCircle(b.crank, 0.045, frame);
  }

  @override
  bool shouldRepaint(IllustrationPainter old) =>
      old.movement != movement || old.hold != hold || old.body != body;
}
