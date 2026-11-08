import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'package:health_app/demo/demo_matcher.dart';
import 'package:health_app/demo/figure.dart';
import 'package:health_app/demo/framing.dart' show BodyStyle;
import 'package:health_app/demo/movement.dart';
import 'package:health_app/demo/movements.dart';
import 'package:health_app/demo/workout_movements.dart';
import 'package:health_app/models/workout.dart';

/// Where a workout's picture is set, drawn behind the figure.
enum Backdrop { studio, track, trail, road, pool, sea, snow, sky, street, gym }

/// What the figure wears.
enum Outfit { sport, leggings, swim, wetsuit, snow, fencing }

/// Things drawn with the figure, placed from its joints or the floor.
enum Prop {
  mat,
  treadmill,
  elliptical,
  rower,
  stepper,
  rope,
  gloves,
  bag,
  racket,
  barre,
  barbell,
  silks,
  hoop,
  pole,
  trampoline,
  canopy,
  surfboard,
  paddleboard,
  kayak,
  skis,
  snowboard,
  skateboard,
  vaultBox,
  foil,
  golfClub,
  buoy,
  wall,
  notes,
}

/// One still picture of a workout: the figure's pose and what's around it.
class SceneSpec {
  const SceneSpec({
    required this.pose,
    this.front = false,
    this.scenery = const [],
    this.props = const [],
    this.backdrop = Backdrop.studio,
    this.outfit = Outfit.sport,
    this.tilt = 0,
    this.upperTilt = 0,
    this.hold = Hold.none,
    this.onShoulders = false,
    this.anchor,
  });

  final Pose pose;
  final bool front;
  final List<Scenery> scenery;
  final List<Prop> props;
  final Backdrop backdrop;
  final Outfit outfit;

  /// The whole scene turned this many degrees (a ski slope).
  final double tilt;

  /// The upper body turned about the hips (see [Movement.upperTilt]).
  final double upperTilt;

  /// Equipment in the hands (or across the shoulders when [onShoulders]).
  final Hold hold;
  final bool onShoulders;

  /// Where a cable or band is attached.
  final Offset? anchor;

  Skeleton get skeleton {
    final s = Skeleton.solve(pose, front: front);
    return upperTilt == 0 ? s : s.withUpperTilt(upperTilt);
  }
}

/// A still picture for each kind of workout.
abstract final class WorkoutScenes {
  static final _cache = <WorkoutType, SceneSpec>{};

  static SceneSpec of(WorkoutType type) =>
      _cache.putIfAbsent(type, () => _build(type));

  static final _exercises = Expando<SceneSpec>();

  /// An exercise from the library in its working position, in the gym,
  /// holding what it uses.
  static SceneSpec forExercise(String id) {
    final demo = DemoMatcher.forId(id);
    return _exercises[demo] ??= () {
      final m = demo.movement;
      return SceneSpec(
        pose: m.poseAt(m.timeOf(1)),
        front: m.front,
        scenery: m.scenery,
        backdrop: Backdrop.gym,
        upperTilt: m.upperTilt,
        hold: demo.hold,
        onShoulders: m.slot == Slot.shoulders,
        anchor: m.anchor,
      );
    }();
  }

  /// A movement's keyframe [k] as a scene.
  static SceneSpec _from(
    WorkoutType type,
    int k, {
    List<Prop> props = const [],
    Backdrop backdrop = Backdrop.studio,
    Outfit outfit = Outfit.sport,
    bool scenery = true,
  }) {
    final (m, _) = WorkoutMovements.of(type);
    return SceneSpec(
      pose: m.poseAt(m.timeOf(k)),
      front: m.front,
      scenery: scenery ? m.scenery : const [],
      props: props,
      backdrop: backdrop,
      outfit: outfit,
      upperTilt: m.upperTilt,
    );
  }

  static SceneSpec _build(WorkoutType type) => switch (type) {
    WorkoutType.run => _from(type, 0, backdrop: Backdrop.track),
    WorkoutType.walk => _from(type, 0, backdrop: Backdrop.road),
    WorkoutType.hike => _from(type, 0, backdrop: Backdrop.trail),
    WorkoutType.cycle => _from(type, 0, backdrop: Backdrop.road),
    WorkoutType.indoorCycle => _from(type, 2, backdrop: Backdrop.gym),
    WorkoutType.strength => _from(
      type,
      0,
      props: const [Prop.barbell],
      backdrop: Backdrop.gym,
    ),
    WorkoutType.hiit => _from(type, 1, backdrop: Backdrop.gym),
    WorkoutType.swim => _from(
      type,
      1,
      backdrop: Backdrop.pool,
      outfit: Outfit.swim,
    ),
    WorkoutType.row => _from(
      type,
      0,
      props: const [Prop.rower],
      backdrop: Backdrop.gym,
      scenery: false,
    ),
    WorkoutType.elliptical => _from(
      type,
      1,
      props: const [Prop.elliptical],
      backdrop: Backdrop.gym,
      scenery: false,
    ),
    WorkoutType.yoga => _from(
      type,
      2,
      props: const [Prop.mat],
      outfit: Outfit.leggings,
    ),
    WorkoutType.dance => _from(type, 0, props: const [Prop.notes]),
    WorkoutType.indoorRun => _from(
      type,
      0,
      props: const [Prop.treadmill],
      backdrop: Backdrop.gym,
      scenery: false,
    ),
    WorkoutType.stairs => _from(
      type,
      1,
      props: const [Prop.stepper],
      backdrop: Backdrop.gym,
      scenery: false,
    ),
    // Facing us, up on the toes, the rope swinging over the head.
    WorkoutType.jumpRope => const SceneSpec(
      pose: Pose(at: Offset(0, -0.06), arm: Limb(28, 62), leg: Limb(4, 2, 10)),
      front: true,
      props: [Prop.rope],
    ),
    WorkoutType.boxing => _from(
      type,
      1,
      props: const [Prop.gloves, Prop.bag],
      backdrop: Backdrop.gym,
    ),
    WorkoutType.martialArts => _from(type, 1, props: const [Prop.mat]),
    WorkoutType.climbing => _from(
      type,
      1,
      props: const [Prop.wall],
      scenery: false,
    ),
    WorkoutType.pilates => _from(
      type,
      1,
      props: const [Prop.mat],
      outfit: Outfit.leggings,
    ),
    WorkoutType.barre => _from(
      type,
      1,
      props: const [Prop.barre],
      outfit: Outfit.leggings,
    ),
    // A standing quad stretch, balanced on one leg.
    WorkoutType.stretching => () {
      final m = Movements.quadStretch;
      return SceneSpec(
        pose: m.poseAt(m.timeOf(1)),
        front: m.front,
        props: const [Prop.mat],
        outfit: Outfit.leggings,
      );
    }(),
    WorkoutType.taiChi => _from(type, 1, backdrop: Backdrop.trail),
    WorkoutType.tennis => _from(
      type,
      1,
      props: const [Prop.racket],
      backdrop: Backdrop.track,
    ),
    WorkoutType.other => _from(type, 1),
    // Hanging in two lengths of fabric, one leg wrapped, toes pointed.
    WorkoutType.aerialSilks => const SceneSpec(
      pose: Pose(
        root: Root.hands,
        at: Offset(0, -1.3),
        torso: 176,
        head: 166,
        arm: Limb(178, 182),
        armFar: Limb(186, 178),
        leg: Limb(96, 92, 120),
        legFar: Limb(-58, -52, -30),
      ),
      props: [Prop.silks],
      backdrop: Backdrop.sky,
      outfit: Outfit.leggings,
    ),
    // Sitting in the bottom of the hoop, leaning back, one arm up to it
    // and one leg reaching out.
    WorkoutType.aerialHoop => const SceneSpec(
      pose: Pose(
        root: Root.hip,
        at: Offset(0, -0.72),
        torso: 196,
        head: 205,
        arm: Limb.to(Offset(0.06, -1.14)),
        armFar: Limb(-120, -150),
        leg: Limb(80, 20, 40),
        legFar: Limb(95, 95, 100),
      ),
      props: [Prop.hoop],
      backdrop: Backdrop.sky,
      outfit: Outfit.leggings,
    ),
    // Spinning on the pole: held high with the near hand, leaning out,
    // one knee hooked around it.
    WorkoutType.poleFitness => const SceneSpec(
      pose: Pose(
        root: Root.hands,
        at: Offset(0, -1.12),
        torso: 150,
        head: 140,
        arm: Limb(182, 196),
        armFar: Limb(-80, -60),
        leg: Limb.to(Offset(0.0, -0.5), bend: -1, end: 60),
        legFar: Limb(-20, -10, -20),
      ),
      props: [Prop.pole],
      outfit: Outfit.leggings,
    ),
    // Mid-air above the trampoline, arms and legs out in a star.
    WorkoutType.trampoline => const SceneSpec(
      pose: Pose(
        at: Offset(0, -0.42),
        arm: Limb(150, 160),
        leg: Limb(22, 18, 30),
      ),
      front: true,
      props: [Prop.trampoline],
      backdrop: Backdrop.sky,
    ),
    // Seated in the harness under the wing, hands up on the brakes.
    WorkoutType.paragliding => const SceneSpec(
      pose: Pose(
        root: Root.hip,
        at: Offset(0, -0.6),
        torso: 176,
        head: 182,
        arm: Limb(160, 185),
        armFar: Limb(150, 178),
        leg: Limb(78, 20, 70),
        legFar: Limb(70, 12, 70),
      ),
      props: [Prop.canopy],
      backdrop: Backdrop.sky,
    ),
    // Riding the board low, knees bent, arms out for balance.
    WorkoutType.surfing => const SceneSpec(
      pose: Pose(
        at: Offset(0, -0.1),
        torso: 170,
        head: 180,
        arm: Limb(100, 120),
        armFar: Limb(80, 100),
        leg: Limb(38, -12, 80),
        legFar: Limb(32, -14, 80),
      ),
      front: true,
      props: [Prop.surfboard],
      backdrop: Backdrop.sea,
      outfit: Outfit.wetsuit,
    ),
    // Standing on the board, the long paddle reaching into the water.
    WorkoutType.paddleboard => const SceneSpec(
      pose: Pose(
        at: Offset(0, -0.07),
        torso: 168,
        head: 175,
        arm: Limb(70, 50),
        armFar: Limb(130, 100),
        leg: Limb(12, -8),
        legFar: Limb(6, -6),
      ),
      props: [Prop.paddleboard],
      backdrop: Backdrop.sea,
    ),
    // Sitting in the kayak, the paddle across, one blade in the water.
    WorkoutType.kayaking => const SceneSpec(
      pose: Pose(
        root: Root.hip,
        at: Offset(0, -0.09),
        torso: 172,
        head: 178,
        arm: Limb.to(Offset(0.2, -0.3), frame: Frame.hip, bend: -1),
        armFar: Limb.to(Offset(-0.02, -0.25), frame: Frame.hip, bend: -1),
        leg: Limb(88, 80, 100),
        legFar: Limb(88, 80, 100),
      ),
      props: [Prop.kayak],
      backdrop: Backdrop.sea,
    ),
    // Tucked low down the slope, poles tucked back.
    WorkoutType.skiing => const SceneSpec(
      pose: Pose(
        at: Offset(0, -0.045),
        torso: 128,
        head: 112,
        arm: Limb(40, 100),
        armFar: Limb(30, 90),
        leg: Limb(55, -30, 90),
        legFar: Limb(50, -32, 90),
      ),
      props: [Prop.skis],
      backdrop: Backdrop.snow,
      outfit: Outfit.snow,
      tilt: 14,
    ),
    // Side on to the slope, knees soft, arms out.
    WorkoutType.snowboarding => const SceneSpec(
      pose: Pose(
        at: Offset(0, -0.05),
        torso: 172,
        head: 178,
        arm: Limb(70, 95),
        armFar: Limb(100, 120),
        leg: Limb(40, -8, 80),
        legFar: Limb(34, -10, 80),
      ),
      front: true,
      props: [Prop.snowboard],
      backdrop: Backdrop.snow,
      outfit: Outfit.snow,
      tilt: 10,
    ),
    // Riding, knees bent, arms loose.
    WorkoutType.skateboarding => const SceneSpec(
      pose: Pose(
        at: Offset(0, -0.1),
        torso: 174,
        head: 180,
        arm: Limb(60, 80),
        armFar: Limb(90, 120),
        leg: Limb(30, -10, 80),
        legFar: Limb(26, -6, 80),
      ),
      front: true,
      props: [Prop.skateboard],
      backdrop: Backdrop.street,
    ),
    // Vaulting a box: hands on top, legs swinging through to the side.
    WorkoutType.parkour => const SceneSpec(
      pose: Pose(
        root: Root.hands,
        at: Offset(0.02, -0.42),
        torso: 128,
        head: 110,
        arm: Limb(-30, -20),
        armFar: Limb(-20, -10),
        leg: Limb(60, 10, 60),
        legFar: Limb(80, 40, 80),
      ),
      props: [Prop.vaultBox],
      backdrop: Backdrop.street,
    ),
    // Front crawl in the sea, past a buoy.
    WorkoutType.openWaterSwim => SceneSpec(
      pose: () {
        final (m, _) = WorkoutMovements.of(WorkoutType.swim);
        return m.poseAt(m.timeOf(2));
      }(),
      props: const [Prop.buoy],
      backdrop: Backdrop.sea,
      outfit: Outfit.wetsuit,
    ),
    // A lunge, foil arm straight out, back hand raised.
    WorkoutType.fencing => const SceneSpec(
      pose: Pose(
        at: Offset(0, -0.025),
        torso: 172,
        head: 178,
        arm: Limb(92, 90),
        armFar: Limb(-130, -175),
        leg: Limb(85, 2, 90),
        legFar: Limb(-50, -50, 70),
      ),
      props: [Prop.foil],
      outfit: Outfit.fencing,
    ),
    // The top of the backswing, the club over the shoulder.
    WorkoutType.golf => const SceneSpec(
      pose: Pose(
        at: Offset(0, -0.025),
        torso: 168,
        head: 150,
        arm: Limb(170, 230),
        armFar: Limb(150, 220),
        leg: Limb(8, -4),
        legFar: Limb(2, -6),
      ),
      props: [Prop.golfClub],
      backdrop: Backdrop.trail,
    ),
  };
}

/// Colours of a scene, from the workout's colour.
class _Palette {
  _Palette(this.accent, Outfit outfit)
    : shirt = switch (outfit) {
        Outfit.fencing => const Color(0xFFF2F2F2),
        Outfit.wetsuit => const Color(0xFF2E4A70),
        Outfit.swim => const Color(0xFFE8B796),
        _ => accent,
      },
      bottoms = switch (outfit) {
        Outfit.fencing => const Color(0xFFE6E6E6),
        Outfit.wetsuit => const Color(0xFF2E4A70),
        Outfit.snow => const Color(0xFF2E3A52),
        Outfit.leggings => const Color(0xFF3B3F5C),
        Outfit.swim => const Color(0xFF26324A),
        Outfit.sport => const Color(0xFF34405A),
      };

  final Color accent;
  final Color shirt;
  final Color bottoms;

  static const skin = Color(0xFFEFC19B);
  static const skinShade = Color(0xFFD69F79);
  static const hair = Color(0xFF3A2A22);
  static const shoe = Color(0xFFF6F6F6);
  static const sole = Color(0xFF8A93A6);
  static const prop = Color(0xFFE9ECF2);
  static const propDark = Color(0xFF7D8699);
  static const metal = Color(0xFFB8C0CE);

  /// [c] in shadow, for the far side of the body.
  static Color shade(Color c) => Color.lerp(c, const Color(0xFF101318), 0.22)!;
}

/// Paints a [SceneSpec]: a backdrop, then a figure in flat colour (skin,
/// clothes and shoes) with what it uses, framed to fit.
class WorkoutScenePainter extends CustomPainter {
  WorkoutScenePainter({
    required this.spec,
    required this.accent,
    this.body = BodyStyle.male,
  });

  final SceneSpec spec;
  final Color accent;
  final BodyStyle body;

  @override
  void paint(Canvas canvas, Size size) {
    final colors = _Palette(accent, spec.outfit);
    final skeleton = spec.skeleton;
    _backdrop(canvas, size);

    // Fit the figure and its props, with room around them.
    final bounds = _bounds(skeleton);
    final pad = size.shortestSide * 0.1;
    final scale = math.min(
      (size.width - pad * 2) / bounds.width,
      (size.height - pad * 2) / bounds.height,
    );
    canvas.save();
    canvas.translate(
      size.width / 2 - bounds.center.dx * scale,
      size.height / 2 - bounds.center.dy * scale,
    );
    canvas.scale(scale);
    if (spec.tilt != 0) {
      final c = skeleton[J.pelvis];
      canvas.translate(c.dx, 0);
      canvas.rotate(spec.tilt * math.pi / 180);
      canvas.translate(-c.dx, 0);
    }
    final painter = _Figure(canvas, skeleton, colors, spec, body);
    painter.ground(scale, size);
    painter.propsBehind();
    for (final s in spec.scenery) {
      painter.scenery(s);
    }
    painter.heldBehind();
    painter.figure();
    painter.propsInFront();
    painter.heldInFront();
    canvas.restore();
  }

  /// What must be in the picture: the body, and props that have a size.
  Rect _bounds(Skeleton s) {
    var r = Rect.fromPoints(s[J.head], s[J.pelvis]);
    for (final p in s.points) {
      r = r.expandToInclude(Rect.fromCircle(center: p, radius: 0.06));
    }
    r = r.expandToInclude(
      Rect.fromCircle(center: s[J.head], radius: Body.headRadius + 0.03),
    );
    void add(Rect x) => r = r.expandToInclude(x);
    for (final sc in spec.scenery) {
      for (final p in sc.points) {
        add(Rect.fromCircle(center: p, radius: 0.04));
      }
    }
    if (spec.anchor case final a?) {
      add(Rect.fromCircle(center: a, radius: 0.05));
    }
    final held = spec.onShoulders
        ? s[J.neck] + const Offset(-0.035, 0.03)
        : s[J.wristN];
    switch (spec.hold) {
      case Hold.barbell when spec.front:
        add(
          Rect.fromLTRB(
            s[J.pelvis].dx - 0.47,
            held.dy - 0.11,
            s[J.pelvis].dx + 0.47,
            held.dy + 0.11,
          ),
        );
      case Hold.barbell:
        add(Rect.fromCircle(center: held, radius: 0.1));
      case Hold.dumbbells:
        add(Rect.fromCircle(center: s[J.wristN], radius: 0.07));
        add(Rect.fromCircle(center: s[J.wristF], radius: 0.07));
      case Hold.kettlebell || Hold.ball:
        add(
          Rect.fromCircle(center: held + const Offset(0, 0.05), radius: 0.08),
        );
      case Hold.platform:
        add(Rect.fromCircle(center: s[J.toeN], radius: 0.13));
      case Hold.pad || Hold.cable || Hold.band || Hold.none:
        break;
    }
    final x = s[J.pelvis].dx;
    for (final p in spec.props) {
      switch (p) {
        case Prop.treadmill:
          add(Rect.fromLTRB(x - 0.45, -0.5, x + 0.5, 0.02));
        case Prop.rower:
          add(Rect.fromLTRB(x - 0.55, -0.32, x + 0.76, 0.02));
        case Prop.elliptical:
          add(Rect.fromLTRB(x - 0.3, -0.95, x + 0.4, 0.02));
        case Prop.stepper:
          add(Rect.fromLTRB(x - 0.3, -0.9, x + 0.35, 0.02));
        case Prop.bag:
          add(Rect.fromLTRB(x + 0.25, -1.1, x + 0.55, -0.2));
        case Prop.hoop:
          add(Rect.fromCircle(center: const Offset(0, -0.98), radius: 0.48));
        case Prop.canopy:
          add(Rect.fromLTRB(x - 0.62, -1.55, x + 0.62, -0.4));
        case Prop.trampoline:
          add(Rect.fromLTRB(x - 0.55, -0.02, x + 0.55, 0.22));
        case Prop.kayak:
          add(Rect.fromLTRB(x - 0.62, -0.5, x + 0.62, 0.04));
        case Prop.vaultBox:
          add(const Rect.fromLTRB(-0.28, -0.45, 0.28, 0));
        case Prop.skis || Prop.paddleboard || Prop.surfboard:
          add(Rect.fromLTRB(x - 0.5, -0.06, x + 0.5, 0.02));
        case Prop.racket || Prop.foil || Prop.golfClub:
          add(Rect.fromCircle(center: s[J.wristN], radius: 0.24));
        default:
          break;
      }
    }
    return r;
  }

  void _backdrop(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final top = switch (spec.backdrop) {
      Backdrop.sky || Backdrop.sea => const Color(0xFF2D5E8C),
      Backdrop.snow => const Color(0xFF6E8DB3),
      Backdrop.pool => const Color(0xFF1F5E86),
      _ => Color.lerp(const Color(0xFF26272B), accent, 0.30)!,
    };
    const bottom = Color(0xFF1C1D21);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(rect),
    );
    // A soft glow behind the figure.
    canvas.drawCircle(
      rect.center,
      size.shortestSide * 0.42,
      Paint()
        ..color = accent.withValues(alpha: 0.13)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.shortestSide / 8),
    );
  }

  @override
  bool shouldRepaint(WorkoutScenePainter old) =>
      old.spec != spec || old.accent != accent || old.body != body;
}

/// Draws the figure and props in world units (floor at y = 0).
class _Figure {
  _Figure(this.c, this.s, this.colors, this.spec, this.body);

  final Canvas c;
  final Skeleton s;
  final _Palette colors;
  final SceneSpec spec;
  final BodyStyle body;

  Paint _fill(Color color) => Paint()
    ..color = color
    ..isAntiAlias = true;

  Paint _line(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  /// A tapered limb from [a] (radius [ra]) to [b] (radius [rb]).
  void capsule(Offset a, Offset b, double ra, double rb, Color color) {
    final p = _fill(color);
    final d = b - a;
    final len = d.distance;
    c.drawCircle(a, ra, p);
    c.drawCircle(b, rb, p);
    if (len < 1e-6) return;
    final n = Offset(-d.dy, d.dx) / len;
    c.drawPath(
      Path()
        ..moveTo((a + n * ra).dx, (a + n * ra).dy)
        ..lineTo((b + n * rb).dx, (b + n * rb).dy)
        ..lineTo((b - n * rb).dx, (b - n * rb).dy)
        ..lineTo((a - n * ra).dx, (a - n * ra).dy)
        ..close(),
      p,
    );
  }

  Offset _along(Offset a, Offset b, double t) => Offset.lerp(a, b, t)!;

  /// [v] scaled to length 1 (straight down when it has no length).
  static Offset _unit(Offset v) =>
      v.distance < 1e-6 ? const Offset(0, 1) : v / v.distance;

  bool get _covered =>
      spec.outfit == Outfit.wetsuit ||
      spec.outfit == Outfit.snow ||
      spec.outfit == Outfit.fencing;

  void _arm(J sh, J el, J wr, {required bool far}) {
    Color tone(Color x) => far ? _Palette.shade(x) : x;
    final a = s[sh], b = s[el], w = s[wr];
    final skin = tone(_Palette.skin);
    final sleeve = tone(colors.shirt);
    final long = _covered;
    capsule(a, b, 0.029, 0.023, long ? sleeve : skin);
    capsule(b, w, 0.023, 0.018, long ? sleeve : skin);
    if (!long && spec.outfit != Outfit.swim) {
      capsule(a, _along(a, b, 0.5), 0.034, 0.028, sleeve);
    }
    final gloves = spec.props.contains(Prop.gloves);
    c.drawCircle(
      w + _unit(w - b) * 0.012,
      gloves ? 0.034 : 0.019,
      _fill(gloves ? tone(const Color(0xFFE5484D)) : skin),
    );
  }

  void _leg(J hip, J knee, J ankle, J toe, {required bool far}) {
    Color tone(Color x) => far ? _Palette.shade(x) : x;
    final h = s[hip], k = s[knee], a = s[ankle], t = s[toe];
    final skin = tone(_Palette.skin);
    final bottoms = tone(colors.bottoms);
    final full = spec.outfit != Outfit.sport && spec.outfit != Outfit.swim;
    capsule(h, k, 0.043, 0.031, full ? bottoms : skin);
    capsule(k, a, 0.031, 0.021, full ? bottoms : skin);
    if (!full) {
      capsule(
        h,
        _along(h, k, spec.outfit == Outfit.swim ? 0.25 : 0.6),
        0.049,
        0.039,
        bottoms,
      );
    }
    // Shoes, or bare feet in the water and on the mat.
    final bare =
        spec.outfit == Outfit.swim ||
        spec.outfit == Outfit.wetsuit ||
        spec.outfit == Outfit.leggings ||
        spec.props.contains(Prop.mat);
    final boot = spec.outfit == Outfit.snow;
    capsule(
      a,
      t,
      boot ? 0.026 : 0.019,
      bare ? 0.012 : 0.017,
      bare ? skin : tone(boot ? const Color(0xFF2B2F38) : _Palette.shoe),
    );
    if (!bare && !boot) {
      final d = t - a;
      final n = Offset(-d.dy, d.dx) / math.max(d.distance, 1e-6);
      // The sole, on the side away from the leg.
      final down = (n.dx * (k - a).dx + n.dy * (k - a).dy) > 0 ? -n : n;
      c.drawLine(
        a + down * 0.015,
        t + down * 0.013,
        _line(tone(_Palette.sole), 0.008),
      );
    }
  }

  void _torso() {
    final p = s[J.pelvis], n = s[J.neck];
    final shirt = colors.shirt;
    if (s.front) {
      final shN = s[J.shoulderN], shF = s[J.shoulderF];
      final hN = s[J.hipN], hF = s[J.hipF];
      final waist = _along(p, n, 0.45);
      final path = Path()
        ..moveTo(shN.dx, shN.dy)
        ..quadraticBezierTo(
          waist.dx + (shN.dx - n.dx) * 0.7,
          waist.dy,
          hN.dx + (hN.dx - p.dx) * 0.9,
          hN.dy,
        )
        ..lineTo(hF.dx + (hF.dx - p.dx) * 0.9, hF.dy)
        ..quadraticBezierTo(
          waist.dx + (shF.dx - n.dx) * 0.7,
          waist.dy,
          shF.dx,
          shF.dy,
        )
        ..close();
      c.drawPath(path, _fill(shirt));
      capsule(shN, shF, 0.034, 0.034, shirt);
      capsule(hN, hF, 0.045, 0.045, colors.bottoms);
    } else {
      capsule(p, _along(p, n, 0.55), 0.046, 0.044, shirt);
      capsule(_along(p, n, 0.5), n, 0.046, 0.05, shirt);
      capsule(p, _along(p, n, 0.18), 0.05, 0.047, colors.bottoms);
    }
    if (spec.outfit == Outfit.swim && s.front) {
      // Bare back and shoulders; only the shorts stay.
      capsule(s[J.shoulderN], s[J.shoulderF], 0.034, 0.034, _Palette.skin);
    }
  }

  void _head() {
    final h = s[J.head], n = s[J.neck];
    final upv = h - n;
    final up = upv / math.max(upv.distance, 1e-6);
    final forward = Offset(-up.dy, up.dx);
    capsule(n, _along(n, h, 0.6), 0.02, 0.019, _Palette.skin);
    final r = Body.headRadius;
    final helmet = spec.outfit == Outfit.snow;
    final mask = spec.outfit == Outfit.fencing;
    final cap = spec.outfit == Outfit.swim;
    final hairColor = helmet
        ? colors.accent
        : cap
        ? const Color(0xFFE5484D)
        : _Palette.hair;
    if (body == BodyStyle.female && !helmet && !cap && !mask) {
      final tail = s.front
          ? h + up * 0.01 + Offset(r * 0.95, r * 0.4)
          : h - forward * r * 1.1 + up * r * 0.1;
      capsule(h - forward * r * 0.5, tail, 0.022, 0.016, _Palette.hair);
    }
    if (s.front) {
      c.drawCircle(h + up * r * 0.12, r * 1.04, _fill(hairColor));
      c.drawCircle(h - up * r * 0.1, r * 0.92, _fill(_Palette.skin));
      if (!helmet && !cap) {
        c.drawCircle(h + up * r * 0.55, r * 0.6, _fill(hairColor));
      }
    } else {
      c.drawCircle(h - forward * r * 0.12 + up * r * 0.1, r, _fill(hairColor));
      c.drawCircle(
        h + forward * r * 0.12 - up * r * 0.08,
        r * 0.9,
        _fill(_Palette.skin),
      );
      c.drawCircle(h - forward * r * 0.15, r * 0.18, _fill(_Palette.skinShade));
    }
    if (helmet) {
      // Goggles.
      final g = s.front ? h : h + forward * r * 0.55;
      capsule(
        g - (s.front ? Offset(r * 0.6, 0) : Offset.zero),
        g + (s.front ? Offset(r * 0.6, 0) : forward * r * 0.3),
        r * 0.28,
        r * 0.28,
        const Color(0xFF30C1F0),
      );
    }
    if (mask) {
      c.drawCircle(h, r * 1.08, _fill(const Color(0xFFDDDDDD)));
      final grid = _line(const Color(0xFF3A3F4A), 0.006);
      final f = s.front ? h : h + forward * r * 0.4;
      c.drawCircle(f, r * 0.62, _fill(const Color(0xFF3A3F4A)));
      c.drawCircle(f, r * 0.62, grid..color = const Color(0xFF9AA2B1));
    }
  }

  /// The body, back to front.
  void figure() {
    final lowest = s.points.map((p) => p.dy).reduce(math.max);
    if (lowest > -0.2 && !_floating) {
      c.drawOval(
        Rect.fromCenter(
          center: Offset(s[J.pelvis].dx, 0),
          width: 0.42,
          height: 0.035,
        ),
        _fill(const Color(0x40000000)),
      );
    }
    if (s.front) {
      _leg(J.hipF, J.kneeF, J.ankleF, J.toeF, far: false);
      _leg(J.hipN, J.kneeN, J.ankleN, J.toeN, far: false);
      _torso();
      _head();
      _arm(J.shoulderF, J.elbowF, J.wristF, far: false);
      _arm(J.shoulderN, J.elbowN, J.wristN, far: false);
    } else {
      _arm(J.shoulderF, J.elbowF, J.wristF, far: true);
      _leg(J.hipF, J.kneeF, J.ankleF, J.toeF, far: true);
      _torso();
      _head();
      _leg(J.hipN, J.kneeN, J.ankleN, J.toeN, far: false);
      _arm(J.shoulderN, J.elbowN, J.wristN, far: false);
    }
  }

  /// Where the water's surface is: at a swimmer's hips, or at the
  /// floor for a board or boat.
  double get _waterline => _swimming ? s[J.pelvis].dy + 0.02 : -0.02;

  bool get _swimming =>
      (spec.backdrop == Backdrop.pool || spec.backdrop == Backdrop.sea) &&
      !spec.props.any(
        (p) => p == Prop.surfboard || p == Prop.paddleboard || p == Prop.kayak,
      );

  bool get _floating =>
      const {Backdrop.sky, Backdrop.sea, Backdrop.pool}.contains(spec.backdrop);

  /// The floor or ground line, running off both edges.
  void ground(double scale, Size size) {
    const far = 6.0;
    switch (spec.backdrop) {
      case Backdrop.sky:
        // Hills far below.
        final hills = Path()
          ..moveTo(-far, 0.6)
          ..quadraticBezierTo(-0.6, 0.15, 0, 0.45)
          ..quadraticBezierTo(0.7, 0.1, far, 0.5)
          ..lineTo(far, far)
          ..lineTo(-far, far)
          ..close();
        c.drawPath(hills, _fill(const Color(0xFF2E6B52)));
      case Backdrop.sea || Backdrop.pool:
        final water = spec.backdrop == Backdrop.pool
            ? const Color(0xFF2A9BD8)
            : const Color(0xFF1C7DB8);
        final level = _waterline;
        c.drawRect(
          Rect.fromLTRB(-far, level, far, far),
          _fill(water.withValues(alpha: 0.9)),
        );
        final wave = _line(const Color(0x66FFFFFF), 0.012);
        for (var i = -12; i < 12; i++) {
          final x = i * 0.18;
          c.drawArc(
            Rect.fromCenter(
              center: Offset(x, level + 0.02),
              width: 0.16,
              height: 0.05,
            ),
            math.pi,
            math.pi,
            false,
            wave,
          );
        }
        if (spec.backdrop == Backdrop.pool) {
          // Lane rope.
          for (var i = -14; i < 14; i++) {
            c.drawCircle(
              Offset(i * 0.08, level + 0.2),
              0.022,
              _fill(i.isEven ? const Color(0xFFE5484D) : _Palette.prop),
            );
          }
        }
      case Backdrop.snow:
        c.drawRect(
          const Rect.fromLTRB(-far, 0, far, far),
          _fill(const Color(0xFFEAF1F8)),
        );
        c.drawLine(
          const Offset(-far, 0.004),
          const Offset(far, 0.004),
          _line(const Color(0xFFBFD0E2), 0.01),
        );
      case Backdrop.trail:
        c.drawRect(
          const Rect.fromLTRB(-far, 0, far, far),
          _fill(const Color(0xFF3F6B45)),
        );
      case Backdrop.track:
        c.drawRect(
          const Rect.fromLTRB(-far, 0, far, far),
          _fill(const Color(0xFFB4533C)),
        );
        for (final y in [0.05, 0.12]) {
          c.drawLine(
            Offset(-far, y),
            Offset(far, y),
            _line(const Color(0xAAFFFFFF), 0.008),
          );
        }
      case Backdrop.road || Backdrop.street:
        c.drawRect(
          const Rect.fromLTRB(-far, 0, far, far),
          _fill(const Color(0xFF3A3D45)),
        );
        for (var i = -10; i < 10; i++) {
          c.drawLine(
            Offset(i * 0.3, 0.07),
            Offset(i * 0.3 + 0.15, 0.07),
            _line(const Color(0xCCF5C542), 0.012),
          );
        }
      case Backdrop.gym || Backdrop.studio:
        c.drawRect(
          const Rect.fromLTRB(-far, 0, far, far),
          _fill(const Color(0x33FFFFFF)),
        );
    }
  }

  void scenery(Scenery sc) {
    switch (sc) {
      case Bike(:final seat, :final crank, :final handlebar):
        final rear = Offset(seat.dx - 0.24, -Bike.wheel);
        final front = Offset(handlebar.dx + 0.1, -Bike.wheel);
        final frame = _line(colors.accent, 0.022);
        final saddle = seat + const Offset(0.01, 0.03);
        final bars = handlebar + const Offset(-0.03, 0.06);
        if (spec.backdrop == Backdrop.gym) {
          // A stationary bike: a base, a heavy flywheel in front, and
          // posts up to the seat and the handlebars.
          final base = _line(_Palette.propDark, 0.034);
          c.drawLine(
            Offset(rear.dx - 0.04, -0.015),
            Offset(front.dx + 0.12, -0.015),
            base,
          );
          c.drawCircle(front, 0.14, _fill(_Palette.propDark));
          c.drawCircle(front, 0.05, _fill(colors.accent));
          c.drawLine(Offset(rear.dx + 0.06, -0.02), saddle, frame);
          c.drawLine(crank, Offset(front.dx, front.dy), frame);
          c.drawLine(Offset(front.dx - 0.04, -0.02), bars, frame);
          c.drawLine(saddle + const Offset(0, 0.12), crank, frame);
        } else {
          final tire = _line(const Color(0xFF15171C), 0.03);
          final rim = _line(_Palette.metal, 0.008);
          for (final hub in [rear, front]) {
            c.drawCircle(hub, Bike.wheel - 0.012, tire);
            c.drawCircle(hub, Bike.wheel - 0.03, rim);
          }
          c.drawLine(rear, crank, frame);
          c.drawLine(crank, saddle, frame);
          c.drawLine(saddle, rear, frame);
          c.drawLine(crank, bars, frame);
          c.drawLine(seat + const Offset(0.02, 0.05), bars, frame);
          c.drawLine(bars, front, frame);
        }
        capsule(
          seat + const Offset(-0.04, 0),
          seat + const Offset(0.04, 0.005),
          0.014,
          0.01,
          const Color(0xFF22252C),
        );
        c.drawCircle(crank, 0.028, _fill(_Palette.metal));
      case Block(:final rect):
        c.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(0.015)),
          _fill(_Palette.propDark),
        );
      case Surface(:final a, :final b, :final legs):
        capsule(a, b, 0.025, 0.025, _Palette.propDark);
        if (legs) {
          c.drawLine(a, Offset(a.dx, 0), _line(_Palette.metal, 0.014));
          c.drawLine(b, Offset(b.dx, 0), _line(_Palette.metal, 0.014));
        }
      case Bar(:final at):
        c.drawCircle(at, 0.018, _fill(_Palette.metal));
      case Ball(:final center, :final radius):
        c.drawCircle(center, radius, _fill(colors.accent));
      case Dome(:final center, :final radius):
        c.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          math.pi,
          math.pi,
          true,
          _fill(colors.accent),
        );
    }
  }

  static const _iron = Color(0xFF2A2D35);
  static const _ironEdge = Color(0xFF454A57);

  Offset get _held =>
      spec.onShoulders ? s[J.neck] + const Offset(-0.035, 0.03) : s[J.wristN];

  /// A weight plate seen edge on: dark, with a lighter rim.
  void _plate(Offset centre, double width, double height) {
    final rect = Rect.fromCenter(center: centre, width: width, height: height);
    c.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(width * 0.35)),
      _fill(_iron),
    );
    c.drawLine(
      centre + Offset(0, -height / 2 + width * 0.6),
      centre + Offset(0, height / 2 - width * 0.6),
      _line(_ironEdge, width * 0.22),
    );
  }

  void _dumbbell(Offset wrist, Offset elbow) {
    final u = _unit(wrist - elbow);
    final grip = wrist + u * 0.028;
    if (!s.front) {
      c.drawCircle(grip, 0.042, _fill(_iron));
      c.drawCircle(grip, 0.03, _line(_ironEdge, 0.008));
      c.drawCircle(grip, 0.01, _fill(_Palette.metal));
      return;
    }
    final across = Offset(u.dy, -u.dx);
    c.drawLine(
      grip - across * 0.05,
      grip + across * 0.05,
      _line(_Palette.metal, 0.012),
    );
    for (final k in [1.0, -1.0]) {
      final head = grip + across * (0.05 * k);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: head, width: 0.036, height: 0.064),
          const Radius.circular(0.012),
        ),
        _fill(_iron),
      );
    }
  }

  /// Cables (or a band) to their anchor, and in side view the far
  /// dumbbell and the barbell: things the body passes in front of.
  void heldBehind() {
    switch (spec.hold) {
      case Hold.cable || Hold.band:
        final a = spec.anchor;
        if (a == null) return;
        final band = spec.hold == Hold.band;
        final cord = band
            ? _line(colors.accent, 0.016)
            : _line(_Palette.metal, 0.008);
        void pulley(Offset at) {
          c.drawCircle(at, 0.034, _fill(_iron));
          c.drawCircle(at, 0.012, _fill(_Palette.metal));
        }

        c.drawLine(a, s[J.wristN], cord);
        if (s.front) {
          final mirrored = Offset(2 * s[J.pelvis].dx - a.dx, a.dy);
          c.drawLine(mirrored, s[J.wristF], cord);
          if (!band) pulley(mirrored);
        }
        if (!band) pulley(a);
      case Hold.dumbbells when !s.front:
        _dumbbell(s[J.wristF], s[J.elbowF]);
      case Hold.barbell when !s.front:
        // End on, the plate behind the body, so the hands grip the bar
        // and the face stays clear.
        final at = _held;
        c.drawCircle(at, 0.1, _fill(_iron));
        c.drawCircle(at, 0.082, _line(_ironEdge, 0.01));
        c.drawCircle(at, 0.022, _fill(_Palette.metal));
      default:
        break;
    }
  }

  /// What the figure holds or pushes against, drawn over it.
  void heldInFront() {
    final at = _held;
    switch (spec.hold) {
      case Hold.barbell when s.front:
        final y = at.dy, cx = s[J.pelvis].dx;
        c.drawLine(
          Offset(cx - 0.36, y),
          Offset(cx + 0.36, y),
          _line(_Palette.metal, 0.014),
        );
        for (final k in [-1.0, 1.0]) {
          _plate(Offset(cx + k * 0.262, y), 0.046, 0.21);
          _plate(Offset(cx + k * 0.306, y), 0.034, 0.15);
        }
      case Hold.barbell:
        // Drawn behind the figure, see [heldBehind].
        break;
      case Hold.dumbbells:
        if (s.front) _dumbbell(s[J.wristF], s[J.elbowF]);
        _dumbbell(s[J.wristN], s[J.elbowN]);
      case Hold.kettlebell:
        final bell = at + const Offset(0, 0.062);
        c.drawArc(
          Rect.fromCircle(center: at + const Offset(0, 0.026), radius: 0.03),
          math.pi,
          math.pi,
          false,
          _line(_iron, 0.014),
        );
        c.drawCircle(bell, 0.05, _fill(_iron));
        c.drawCircle(
          bell + const Offset(-0.016, -0.016),
          0.012,
          _fill(_ironEdge),
        );
      case Hold.ball:
        c.drawCircle(at, 0.075, _fill(const Color(0xFFE5484D)));
        c.drawArc(
          Rect.fromCircle(center: at, radius: 0.075),
          -math.pi * 0.85,
          math.pi * 0.5,
          false,
          _line(const Color(0x66FFFFFF), 0.012),
        );
      case Hold.platform:
        final d = _unit(s[J.ankleN] - s[J.kneeN]);
        final n = Offset(-d.dy, d.dx);
        final toe = s[J.toeN] + d * 0.035;
        c.drawLine(toe - n * 0.12, toe + n * 0.12, _line(_iron, 0.03));
        c.drawLine(
          toe - n * 0.12 - d * 0.016,
          toe + n * 0.12 - d * 0.016,
          _line(_ironEdge, 0.006),
        );
      case Hold.pad:
        c.drawCircle(s[J.ankleN], 0.036, _fill(_iron));
        c.drawCircle(s[J.ankleN], 0.012, _fill(_Palette.metal));
      case Hold.cable || Hold.band:
        c.drawCircle(s[J.wristN] + const Offset(0, 0.02), 0.018, _fill(_iron));
      case Hold.none:
        break;
    }
  }

  void propsBehind() {
    final x = s[J.pelvis].dx;
    for (final p in spec.props) {
      switch (p) {
        case Prop.mat:
          final feet = [s[J.toeN], s[J.toeF], s[J.ankleN], s[J.ankleF]];
          final minX = [...feet, s[J.wristN], s[J.head]].map((o) => o.dx);
          final left = math.min(minX.reduce(math.min), x - 0.3) - 0.08;
          final right = math.max(minX.reduce(math.max), x + 0.3) + 0.08;
          c.drawRRect(
            RRect.fromLTRBR(
              left,
              -0.012,
              right,
              0.006,
              const Radius.circular(0.01),
            ),
            _fill(colors.accent.withValues(alpha: 0.85)),
          );
        case Prop.treadmill:
          final deck = Rect.fromLTRB(x - 0.42, -0.05, x + 0.42, 0);
          c.drawRRect(
            RRect.fromRectAndRadius(deck, const Radius.circular(0.02)),
            _fill(const Color(0xFF2A2D35)),
          );
          c.drawLine(
            Offset(deck.left + 0.02, -0.05),
            Offset(deck.right - 0.02, -0.05),
            _line(colors.accent, 0.012),
          );
          c.drawLine(
            Offset(x + 0.38, -0.05),
            Offset(x + 0.32, -0.5),
            _line(_Palette.metal, 0.02),
          );
          capsule(
            Offset(x + 0.24, -0.5),
            Offset(x + 0.36, -0.52),
            0.03,
            0.03,
            const Color(0xFF2A2D35),
          );
        case Prop.rower:
          c.drawLine(
            Offset(x - 0.52, -0.08),
            Offset(x + 0.58, -0.08),
            _line(_Palette.metal, 0.022),
          );
          c.drawCircle(Offset(x + 0.6, -0.15), 0.12, _fill(_Palette.propDark));
          c.drawCircle(Offset(x + 0.6, -0.15), 0.05, _fill(colors.accent));
          capsule(
            Offset(x - 0.08, -0.11),
            Offset(x + 0.08, -0.11),
            0.022,
            0.022,
            const Color(0xFF22252C),
          );
          c.drawLine(
            Offset(x - 0.52, -0.08),
            Offset(x - 0.52, 0),
            _line(_Palette.metal, 0.02),
          );
          c.drawLine(
            Offset(x + 0.5, -0.08),
            Offset(x + 0.5, 0),
            _line(_Palette.metal, 0.02),
          );
          // The handle's chain, to the hands.
          c.drawLine(
            s[J.wristN],
            Offset(x + 0.6, -0.15),
            _line(const Color(0xFF15171C), 0.006),
          );
        case Prop.elliptical:
          final base = Rect.fromLTRB(x - 0.28, -0.05, x + 0.38, 0);
          c.drawRRect(
            RRect.fromRectAndRadius(base, const Radius.circular(0.02)),
            _fill(_Palette.propDark),
          );
          c.drawLine(
            Offset(x + 0.32, -0.05),
            Offset(x + 0.3, -0.9),
            _line(_Palette.metal, 0.026),
          );
          for (final w in [s[J.wristN], s[J.wristF]]) {
            c.drawLine(w, Offset(x + 0.3, -0.45), _line(_Palette.metal, 0.016));
          }
          c.drawCircle(Offset(x + 0.3, -0.18), 0.1, _fill(colors.accent));
        case Prop.stepper:
          for (var i = 0; i < 3; i++) {
            c.drawRRect(
              RRect.fromLTRBR(
                x - 0.3 + i * 0.18,
                -0.08 - i * 0.12,
                x + 0.35,
                0,
                const Radius.circular(0.01),
              ),
              _fill(Color.lerp(_Palette.propDark, colors.accent, i * 0.25)!),
            );
          }
          c.drawLine(
            Offset(x + 0.3, -0.3),
            Offset(x + 0.25, -0.9),
            _line(_Palette.metal, 0.022),
          );
        case Prop.bag:
          c.drawLine(
            Offset(x + 0.42, -2),
            Offset(x + 0.42, -1.0),
            _line(_Palette.metal, 0.01),
          );
          capsule(
            Offset(x + 0.42, -0.95),
            Offset(x + 0.42, -0.35),
            0.11,
            0.11,
            const Color(0xFFB8322E),
          );
          c.drawLine(
            Offset(x + 0.31, -0.8),
            Offset(x + 0.53, -0.8),
            _line(const Color(0x55000000), 0.01),
          );
        case Prop.barre:
          final y = -0.62;
          c.drawLine(
            Offset(x - 2, y),
            Offset(x + 2, y),
            _line(const Color(0xFFC8A27A), 0.03),
          );
          for (final px in [x - 0.55, x + 0.55]) {
            c.drawLine(
              Offset(px, y),
              Offset(px, 0),
              _line(_Palette.metal, 0.02),
            );
          }
        case Prop.silks:
          final fabric = _line(colors.accent, 0.05)..strokeCap = StrokeCap.butt;
          final hands = s[J.wristN];
          c.drawLine(Offset(hands.dx - 0.02, -3), hands, fabric);
          c.drawLine(
            Offset(hands.dx + 0.03, -3),
            s[J.wristF] + const Offset(0.01, 0),
            fabric,
          );
          // The tails hang down past the feet, one wrapped round a leg.
          final knee = s[J.kneeN];
          final path = Path()
            ..moveTo(hands.dx, hands.dy)
            ..quadraticBezierTo(knee.dx + 0.15, knee.dy - 0.1, knee.dx, knee.dy)
            ..quadraticBezierTo(
              knee.dx - 0.15,
              knee.dy + 0.2,
              hands.dx + 0.05,
              0.5,
            );
          c.drawPath(
            path,
            _line(Color.lerp(colors.accent, Colors.black, 0.2)!, 0.04),
          );
        case Prop.hoop:
          const center = Offset(0, -0.98);
          c.drawLine(
            const Offset(0, -3),
            center + const Offset(0, -0.46),
            _line(_Palette.metal, 0.01),
          );
          c.drawCircle(center, 0.46, _line(_Palette.metal, 0.034));
          c.drawCircle(center, 0.46, _line(colors.accent, 0.014));
        case Prop.pole:
          final px = s[J.wristN].dx;
          c.drawLine(
            Offset(px, -3),
            Offset(px, 0),
            _line(const Color(0xFFDCE1EA), 0.035),
          );
          c.drawLine(
            Offset(px - 0.008, -3),
            Offset(px - 0.008, 0),
            _line(const Color(0x88FFFFFF), 0.008),
          );
        case Prop.trampoline:
          final bed = Rect.fromLTRB(x - 0.5, 0, x + 0.5, 0.05);
          for (final px in [bed.left + 0.06, bed.right - 0.06]) {
            c.drawLine(
              Offset(px, 0.02),
              Offset(px + (px < x ? -0.05 : 0.05), 0.22),
              _line(_Palette.metal, 0.022),
            );
          }
          c.drawOval(bed, _fill(const Color(0xFF15171C)));
          c.drawOval(bed, _line(colors.accent, 0.022));
        case Prop.canopy:
          final top = Offset(x, -1.45);
          final wing = Path()
            ..moveTo(x - 0.6, -1.15)
            ..quadraticBezierTo(top.dx, top.dy - 0.22, x + 0.6, -1.15)
            ..quadraticBezierTo(top.dx, top.dy - 0.02, x - 0.6, -1.15)
            ..close();
          c.drawPath(wing, _fill(colors.accent));
          final lines = _line(const Color(0x99FFFFFF), 0.004);
          for (final f in [-0.58, -0.3, 0.0, 0.3, 0.58]) {
            final from = Offset(x + f, -1.18 - (0.6 - f.abs()) * 0.3);
            c.drawLine(from, s[J.shoulderN], lines);
          }
          // The harness seat.
          capsule(
            s[J.pelvis] + const Offset(-0.06, 0.02),
            s[J.kneeN] + const Offset(0, 0.03),
            0.035,
            0.03,
            const Color(0xFF2B2F38),
          );
        case Prop.vaultBox:
          c.drawRRect(
            RRect.fromLTRBR(-0.26, -0.42, 0.26, 0, const Radius.circular(0.02)),
            _fill(const Color(0xFF8C9099)),
          );
          for (var y = -0.36; y < 0; y += 0.09) {
            c.drawLine(
              Offset(-0.26, y),
              Offset(0.26, y),
              _line(const Color(0x33000000), 0.006),
            );
          }
        case Prop.wall:
          c.drawRect(
            Rect.fromLTRB(s[J.pelvis].dx + 0.08, -3, 3, 0),
            _fill(const Color(0xFF8D6B4A)),
          );
          final holds = [
            const Offset(0.0, -1.0),
            const Offset(0.1, -0.7),
            const Offset(0.05, -0.4),
            const Offset(0.12, -0.15),
            const Offset(0.0, -1.25),
          ];
          final palette = [
            colors.accent,
            const Color(0xFFF5C542),
            const Color(0xFF3EC1F0),
            const Color(0xFFE5484D),
            const Color(0xFF4BE38F),
          ];
          for (final (i, h) in holds.indexed) {
            c.drawCircle(
              Offset(s[J.pelvis].dx + 0.1 + h.dx, h.dy),
              0.03,
              _fill(palette[i]),
            );
          }
        case Prop.notes:
          final paint = _fill(colors.accent.withValues(alpha: 0.8));
          for (final (o, r) in const [
            (Offset(-0.38, -0.85), 0.03),
            (Offset(0.36, -0.95), 0.026),
            (Offset(0.42, -0.6), 0.022),
          ]) {
            final at = s[J.pelvis] + o;
            c.drawCircle(at, r, paint);
            c.drawLine(
              at + Offset(r * 0.9, 0),
              at + Offset(r * 0.9, -r * 4),
              _line(colors.accent.withValues(alpha: 0.8), 0.008),
            );
          }
        default:
          break;
      }
    }
  }

  void propsInFront() {
    final x = s[J.pelvis].dx;
    for (final p in spec.props) {
      switch (p) {
        case Prop.rope:
          final a = s[J.wristN], b = s[J.wristF];
          final high = s[J.head].dy - Body.headRadius - 0.2;
          final rope = Path()
            ..moveTo(a.dx, a.dy)
            ..cubicTo(a.dx + 0.12, high, b.dx - 0.12, high, b.dx, b.dy);
          c.drawPath(rope, _line(colors.accent, 0.012));
        case Prop.racket:
          final w = s[J.wristN], e = s[J.elbowN];
          final d = _unit(w - e);
          final head = w + d * 0.22;
          c.drawLine(w, w + d * 0.12, _line(const Color(0xFF22252C), 0.018));
          c.drawOval(
            Rect.fromCenter(center: head, width: 0.17, height: 0.2),
            _line(colors.accent, 0.016),
          );
          c.drawCircle(
            head + const Offset(0.2, -0.12),
            0.03,
            _fill(const Color(0xFFD7F25C)),
          );
        case Prop.barbell:
          final w = s[J.wristN];
          c.drawLine(
            w - const Offset(0.05, 0),
            w + const Offset(0.05, 0),
            _line(_Palette.metal, 0.012),
          );
          c.drawCircle(w, 0.13, _fill(const Color(0xFF2A2D35)));
          c.drawCircle(w, 0.13, _line(colors.accent, 0.018));
          c.drawCircle(w, 0.03, _fill(_Palette.metal));
        case Prop.surfboard:
          final board = Rect.fromCenter(
            center: Offset(x, 0.0),
            width: 0.95,
            height: 0.06,
          );
          c.drawOval(board, _fill(_Palette.prop));
          c.drawLine(
            Offset(board.left + 0.06, 0),
            Offset(board.right - 0.06, 0),
            _line(colors.accent, 0.01),
          );
          // The wave curling up behind.
          final wave = Path()
            ..moveTo(x - 1.6, 0.04)
            ..quadraticBezierTo(x - 0.9, 0.0, x - 0.75, -0.55)
            ..quadraticBezierTo(x - 0.55, -0.85, x - 0.95, -0.7)
            ..quadraticBezierTo(x - 0.75, -0.5, x - 1.6, -0.1)
            ..close();
          c.drawPath(wave, _fill(const Color(0xCCFFFFFF)));
        case Prop.paddleboard:
          final board = Rect.fromCenter(
            center: Offset(x, 0.0),
            width: 1.05,
            height: 0.05,
          );
          c.drawOval(board, _fill(colors.accent));
          final top = s[J.wristF], low = s[J.wristN];
          final d = _unit(low - top);
          final blade = low + d * 0.45;
          c.drawLine(top, blade, _line(const Color(0xFF22252C), 0.012));
          capsule(
            blade - d * 0.06,
            blade + d * 0.06,
            0.022,
            0.03,
            const Color(0xFF22252C),
          );
        case Prop.kayak:
          // The hull over the legs, then the paddle across the body.
          final hull = Path()
            ..moveTo(x - 0.62, -0.06)
            ..quadraticBezierTo(x, 0.1, x + 0.62, -0.06)
            ..quadraticBezierTo(x, -0.13, x - 0.62, -0.06)
            ..close();
          c.drawPath(hull, _fill(colors.accent));
          capsule(
            Offset(x - 0.08, -0.08),
            Offset(x + 0.12, -0.08),
            0.022,
            0.022,
            Color.lerp(colors.accent, Colors.black, 0.35)!,
          );
          final mid = Offset.lerp(s[J.wristN], s[J.wristF], 0.5)!;
          const d = Offset(0.975, -0.22);
          final from = mid - d * 0.42, to = mid + d * 0.42;
          c.drawLine(from, to, _line(const Color(0xFF22252C), 0.013));
          for (final (end, dir) in [(from, -1.0), (to, 1.0)]) {
            capsule(
              end,
              end + d * 0.1 * dir,
              0.026,
              0.032,
              const Color(0xFFF5C542),
            );
          }
        case Prop.skis:
          final heel = s[J.ankleN];
          c.drawLine(
            Offset(heel.dx - 0.45, 0.012),
            Offset(heel.dx + 0.5, 0.012),
            _line(colors.accent, 0.018),
          );
          c.drawArc(
            Rect.fromCircle(
              center: Offset(heel.dx + 0.5, -0.03),
              radius: 0.042,
            ),
            0,
            math.pi / 2,
            false,
            _line(colors.accent, 0.018),
          );
          // Poles, tucked back under the arms.
          for (final w in [s[J.wristN], s[J.wristF]]) {
            c.drawLine(
              w,
              w + const Offset(-0.48, 0.12),
              _line(_Palette.metal, 0.009),
            );
          }
        case Prop.snowboard:
          c.drawRRect(
            RRect.fromLTRBR(
              x - 0.4,
              -0.01,
              x + 0.4,
              0.035,
              const Radius.circular(0.02),
            ),
            _fill(colors.accent),
          );
        case Prop.skateboard:
          c.drawRRect(
            RRect.fromLTRBR(
              x - 0.32,
              -0.02,
              x + 0.32,
              0.012,
              const Radius.circular(0.02),
            ),
            _fill(const Color(0xFF2A2D35)),
          );
          c.drawLine(
            Offset(x - 0.3, -0.018),
            Offset(x + 0.3, -0.018),
            _line(colors.accent, 0.008),
          );
          for (final px in [x - 0.2, x + 0.2]) {
            c.drawCircle(
              Offset(px, 0.04),
              0.03,
              _fill(const Color(0xFFF5C542)),
            );
          }
        case Prop.foil:
          final w = s[J.wristN], e = s[J.elbowN];
          final d = _unit(w - e);
          c.drawCircle(w, 0.026, _fill(_Palette.metal));
          c.drawLine(w, w + d * 0.55, _line(_Palette.metal, 0.007));
        case Prop.golfClub:
          final w = s[J.wristN];
          final shaftEnd = w + const Offset(-0.32, 0.18);
          c.drawLine(w, shaftEnd, _line(_Palette.metal, 0.01));
          capsule(
            shaftEnd,
            shaftEnd + const Offset(-0.05, 0.02),
            0.016,
            0.02,
            const Color(0xFF22252C),
          );
          c.drawCircle(Offset(x + 0.3, -0.02), 0.02, _fill(_Palette.prop));
        default:
          break;
      }
    }
    // Water over the swimmer's lower half, so they're in it.
    if (_swimming) {
      final y = _waterline;
      if (spec.props.contains(Prop.buoy)) {
        final b = Offset(x + 0.6, y - 0.03);
        c.drawCircle(b, 0.08, _fill(const Color(0xFFFF8A3D)));
        c.drawCircle(b, 0.08, _line(_Palette.prop, 0.012));
      }
      c.drawRect(Rect.fromLTRB(-6, y, 6, 6), _fill(const Color(0x8C1A8AD0)));
      final wave = _line(const Color(0x88FFFFFF), 0.012);
      for (var i = -10; i < 10; i++) {
        c.drawArc(
          Rect.fromCenter(
            center: Offset(x + i * 0.16, y),
            width: 0.14,
            height: 0.04,
          ),
          math.pi,
          math.pi,
          false,
          wave,
        );
      }
    }
  }
}

/// Lets `Colors.black` be used above without importing material.
abstract final class Colors {
  static const black = Color(0xFF000000);
}
