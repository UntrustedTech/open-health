import 'package:flutter/foundation.dart';

import 'package:health_app/demo/exercise_description.dart';
import 'package:health_app/demo/more_movements.dart';
import 'package:health_app/demo/movement.dart';
import 'package:health_app/demo/movements.dart';
import 'package:health_app/demo/variants.dart';
import 'package:health_app/models/exercise_catalog.dart';

/// What to show for an exercise: a movement and the equipment held.
@immutable
class Demo {
  const Demo(this.movement, this.hold);

  final Movement movement;
  final Hold hold;
}

typedef _Rule = (RegExp, Movement Function(CatalogExercise e));

/// Picks a demonstration for any exercise: a movement chosen from its name
/// (falling back to the muscle it targets, so every exercise shows
/// something), then shaped to follow its instructions: how the body is
/// placed and on what, one side or both, and the pace.
abstract final class DemoMatcher {
  static final _cache = <String, Demo>{};

  static Demo forId(String id) {
    final e = ExerciseCatalog.instance.byId(id);
    if (e == null) return const Demo(Movements.stand, Hold.none);
    return forExercise(e);
  }

  static Demo forExercise(CatalogExercise e) =>
      _cache.putIfAbsent('${e.id}|${e.name}|${e.equipment}|${e.target}', () {
        final m = shaped(movementFor(e), describe(e));
        return Demo(m, holdFor(m, e.equipment));
      });

  static ExerciseDescription describe(CatalogExercise e) =>
      ExerciseDescription.read(e.name, e.steps);

  /// [m] changed to match [d]: a special movement when the description
  /// calls for one, then the bench, ball or bosu, the sides and the pace.
  static Movement shaped(Movement m, ExerciseDescription d) {
    var out = _special(m, d) ?? m;
    if (identical(out, m)) {
      if (d.bench == BenchAngle.incline || d.bench == BenchAngle.decline) {
        out = Variants.onBench(out, d.bench);
      }
      if (d.props.contains(Prop.stabilityBall)) out = Variants.onBall(out);
      if (d.props.contains(Prop.bosu)) out = Variants.handsOnDome(out);
      out = switch (d.sides) {
        Sides.single => Variants.oneSide(out, d.limbs),
        Sides.alternating => Variants.alternating(out, d.limbs),
        Sides.both => out,
      };
    }
    return Variants.paced(
      out,
      slowLowering: d.slowLowering,
      explosive: d.explosive,
    );
  }

  /// A movement made for what [d] describes, when [m] can't be bent to it.
  static Movement? _special(Movement m, ExerciseDescription d) {
    // The name picked a standing move, but the instructions lie down.
    if (d.posture == Posture.lyingBack &&
        const {'fly', 'front_raise', 'standing_chest_press'}.contains(m.id)) {
      return shaped(Movements.benchPress, d);
    }
    if (d.posture == Posture.lyingFace &&
        const {'row', 'reverse_fly', 'shrug'}.contains(m.id)) {
      return Movements.chestSupportedRow;
    }
    final single = d.sides == Sides.single;
    if (d.posture == Posture.handstand &&
        const {'push_up', 'overhead_press', 'dip'}.contains(m.id)) {
      return MoreMovements.handstandPushUp;
    }
    if (single &&
        d.limbs == Limbs.legs &&
        const {'squat', 'back_squat', 'front_squat'}.contains(m.id)) {
      return MoreMovements.pistolSquat;
    }
    if (single && d.limbs == Limbs.arms && m.id == 'push_up') {
      return MoreMovements.oneArmPushUp;
    }
    if (d.props.contains(Prop.stabilityBall) &&
        const {'crunch', 'sit_up'}.contains(m.id)) {
      return MoreMovements.ballCrunch;
    }
    if (d.props.contains(Prop.stabilityBall) &&
        d.posture == Posture.lyingFace &&
        m.id == 'back_extension') {
      return MoreMovements.ballBackExtension;
    }
    return null;
  }

  static Movement movementFor(CatalogExercise e) {
    // "(with rope)" and the like describe attachments, not the movement.
    final name = e.name.toLowerCase().replaceAll(RegExp(r'\(.*?\)'), ' ');
    for (final (pattern, pick) in _rules) {
      if (pattern.hasMatch(name)) return _positioned(pick(e), e);
    }
    return _positioned(_byTarget(e), e);
  }

  /// How the exercise's instructions start: seated, kneeling or neither.
  static ({bool seated, bool kneeling}) positionOf(CatalogExercise e) {
    final start = e.steps.take(2).join(' ').toLowerCase();
    final name = e.name.toLowerCase();
    final kneeling =
        RegExp(r'\bkneel|on your knees').hasMatch(start) ||
        name.contains('kneeling');
    final seated =
        !kneeling &&
        (RegExp(
              r'^(adjust[^.]*\. )?sit (on|down|upright|tall|with)|'
              r'^sit\b',
            ).hasMatch(start) ||
            RegExp(r'\bseated\b').hasMatch(name));
    return (seated: seated, kneeling: kneeling);
  }

  /// [m] in the seated or kneeling form the instructions describe.
  static Movement _positioned(Movement m, CatalogExercise e) {
    final pos = positionOf(e);
    if (pos.kneeling) return Movements.kneelingFormOf(m) ?? m;
    if (pos.seated) return Movements.seatedFormOf(m) ?? m;
    return m;
  }

  static Hold holdFor(Movement m, String equipment) {
    if (m.fixed case final fixed?) return fixed;
    if (m.slot == Slot.none) return Hold.none;
    return switch (equipment) {
      'barbell' ||
      'ez barbell' ||
      'olympic barbell' ||
      'smith machine' ||
      'trap bar' => Hold.barbell,
      'dumbbell' => Hold.dumbbells,
      'kettlebell' => Hold.kettlebell,
      'medicine ball' when m.slot == Slot.hands => Hold.ball,
      'cable' || 'rope' when m.anchor != null => Hold.cable,
      'band' || 'resistance band' when m.anchor != null => Hold.band,
      _ => Hold.none,
    };
  }

  static bool _barbell(CatalogExercise e) => const {
    'barbell',
    'ez barbell',
    'olympic barbell',
    'smith machine',
    'trap bar',
  }.contains(e.equipment);

  static RegExp _r(String pattern) => RegExp(pattern);

  /// Whether the instructions begin by telling you to [verb] (stand, lie,
  /// sit...).
  static bool _starts(CatalogExercise e, String verb) =>
      RegExp('^((adjust|attach|set|place|hold|grab)[^.]*\\. )?$verb\\b')
          .hasMatch(e.steps.take(2).join(' ').toLowerCase().trim());

  static Movement _stretch(CatalogExercise e) =>
      _starts(e, 'lie') && !RegExp(r'face down').hasMatch(e.steps.first)
      ? Movements.legRaise
      : _stretchByTarget(e);

  static Movement _stretchByTarget(CatalogExercise e) => switch (e.target) {
    'hamstrings' || 'calves' || 'glutes' || 'spine' => Movements.forwardFold,
    'quads' => Movements.quadStretch,
    _ => Movements.reach,
  };

  static Movement _squat(CatalogExercise e) {
    if (_barbell(e)) return Movements.backSquat;
    return switch (e.equipment) {
      'dumbbell' || 'kettlebell' || 'medicine ball' => Movements.frontSquat,
      _ => Movements.squat,
    };
  }

  static Movement _press(CatalogExercise e, String name) {
    if (name.contains('floor')) return Movements.floorPress;
    if (name.contains('incline')) return Movements.inclinePress;
    if (name.contains('decline')) return Movements.declinePress;
    return Movements.benchPress;
  }

  // Most specific first.
  static final List<_Rule> _rules = [
    (_r(r'stretch|yoga|pose\b'), _stretch),
    (_r(r'jumping jack|star jump'), (_) => Movements.jumpingJack),
    (_r(r'wrist curl|wrist roller|reverse wrist'), (_) => Movements.wristCurl),
    (_r(r'pallof'), (_) => Movements.pallofPress),
    // Grip work where only the hands move.
    (
      _r(r'finger curl|pronation|supination|gripper'),
      (_) => Movements.fingerCurl,
    ),
    (_r(r'seated.*calf|calf.*seated'), (_) => Movements.seatedCalfRaise),
    // Ab moves that aren't floor crunches.
    (
      _r(r'kneeling.*crunch|standing.*crunch|cable crunch|band crunch'),
      (_) => Movements.kneelingCrunch,
    ),
    (_r(r'^(?!.*curl).*(\bl.?sit|\bv.?sit)'), (_) => Movements.vSit),
    (
      _r(
        r'^(?!.*push).*(planche|front lever|back lever|maltese|\bflag\b|'
        r'shoulder tap)',
      ),
      (_) => Movements.plank,
    ),
    (
      _r(r'hanging pike|gorilla chin|arm slingers|hanging straight leg'),
      (_) => Movements.hangingLegRaise,
    ),
    (_r(r'windmill'), (_) => Movements.sideBend),
    (
      _r(
        r'sledge|slam|judo flip|landmine 180|standing lift|figure 8|'
        r'spell caster',
      ),
      (_) => Movements.woodChop,
    ),
    (_r(r'pull-in|body saw|fallout'), (_) => Movements.abRollout),
    (_r(r'inchworm'), (_) => MoreMovements.inchworm),
    (_r(r'jefferson'), (_) => MoreMovements.jeffersonSquat),
    // A step back into a lunge, reaching up.
    (
      _r(r'step.*(overhead|reach)|lunge.*(reach|overhead)'),
      (_) => Variants.reachingUp(Movements.lunge),
    ),
    // Moves whose names suggest a different family than they belong to.
    (_r(r'pull.?through'), (_) => Movements.romanianDeadlift),
    (_r(r'tire flip'), (_) => Movements.deadlift),
    (_r(r'turkish get'), (_) => Movements.sitUp),
    (_r(r'half knee bend'), (_) => Movements.squat),
    (_r(r'sprint lunge|high knees? lunge'), (_) => Movements.lunge),
    (_r(r'cross trainer|elliptical'), (_) => Movements.walk),
    (_r(r'leg kick push|push.*leg kick'), (_) => Movements.pushUp),
    (_r(r'pullover hip'), (_) => Movements.pullover),
    (
      _r(r'hip extension|glute kickback|donkey kick|kickback.*(glute|hip)'),
      (_) => Movements.gluteKickback,
    ),
    // Curl variations, by how the upper arm is supported.
    (
      _r(r'^(?!.*push).*(spider|prone.*curl|lying preacher)'),
      (_) => Movements.spiderCurl,
    ),
    (_r(r'preacher|scott curl'), (_) => Movements.preacherCurl),
    (
      _r(r'^(?!.*(extension|standing)).*concentration'),
      (_) => Movements.concentrationCurl,
    ),
    (
      _r(
        r'^(?!.*(leg|wrist|calf)).*(incline.*(curl|biceps)|curl.*incline bench)',
      ),
      (_) => Movements.inclineCurl,
    ),
    (
      _r(r'^(?!.*(leg|wrist|calf|crunch)).*seated.*curl'),
      (_) => Movements.seatedCurl,
    ),
    // Dips and push-ups by body position.
    (
      _r(r'bench dip|three bench|between benches|bench leg|dips? floor'),
      (_) => Movements.benchDip,
    ),
    (_r(r'inverted row|body row|australian'), (_) => Movements.invertedRow),
    (
      _r(r'push.?up|press.?up'),
      (e) => switch (e.name.toLowerCase()) {
        final n when n.contains('wall') => Movements.wallPushUp,
        final n when n.contains('knee') => Movements.kneelingPushUp,
        _ => Movements.pushUp,
      },
    ),
    (
      _r(r'seated.*(abduct|adduct)|(abduct|adduct).*machine'),
      (_) => Movements.seatedAbduction,
    ),
    (
      _r(
        r'^(?!.*bent over).*(seated.*(tric.*extension|french press)|'
        r'seated.*overhead.*tric)',
      ),
      (_) => Movements.seatedOverheadExtension,
    ),
    // Positions the names give away.
    (
      _r(r'straight.?arm pull|straight arm lat'),
      (_) => Movements.straightArmPulldown,
    ),
    (
      _r(r'^(?!.*(seated|kneel)).*(band|cable|standing).*pull.?down'),
      (e) =>
          _starts(e, 'stand') ? Movements.standingPulldown : Movements.pulldown,
    ),
    (
      _r(
        // Cable bench presses are done lying on a bench, whatever the
        // source instructions say.
        r'svend|chest push|(cable|band).*chest press|'
        r'cable cross-over variation',
      ),
      (e) => _starts(e, 'lie')
          ? _press(e, e.name.toLowerCase())
          : Movements.standingChestPress,
    ),
    (
      _r(
        r'incline.*(row|shrug|rear|reverse(?!.*press))|decline shrug|'
        r'lying.*rear delt|'
        r'lying row|(prone|lying).*reverse fly|supine reverse fly',
      ),
      (_) => Movements.chestSupportedRow,
    ),
    (_r(r'standing.*concentration'), (_) => Movements.spiderCurl),
    (
      _r(r'lying (supine|wide).*curl|lying supine bicep'),
      (_) => Movements.inclineCurl,
    ),
    (
      _r(r'tric.*dips?|elbow dips|exercise ball dip'),
      (e) => RegExp(r'^sit').hasMatch(e.steps.firstOrNull?.toLowerCase() ?? '')
          ? Movements.benchDip
          : Movements.dip,
    ),
    (
      _r(r'(lying|decline|incline|floor|hyght).*(fly|flye)'),
      (_) => Movements.benchPress,
    ),
    (
      _r(r'reclining|iron cross|lying (calves|glutes|gluteus)'),
      (_) => Movements.legRaise,
    ),
    (_r(r'sled lying squat'), (_) => Movements.legPress),
    (_r(r'standing.*twist|cable twist'), (_) => Movements.woodChop),
    (_r(r'bent over.*tric.*extension'), (_) => Movements.kickback),
    (
      _r(r'(incline|decline|supine).*tric.*extension'),
      (_) => Movements.skullCrusher,
    ),
    (_r(r'roll ?out|rollerout|ab wheel'), (_) => Movements.abRollout),
    (_r(r'air bike|bicycle crunch'), (_) => Movements.bicycleCrunch),
    (
      _r(r'hanging.*(leg|hip) raise|hanging leg'),
      (_) => Movements.hangingLegRaise,
    ),
    (
      // Names lose anything in brackets before matching.
      _r(r'reverse crunch|leg.?hip raise|hip raise|pelvic tilt'),
      (e) => e.target == 'abs' ? Movements.reverseCrunch : Movements.bridge,
    ),
    (_r(r'curl-up|curl up'), (_) => Movements.crunch),
    (_r(r'lower back curl'), (_) => Movements.backExtension),
    (_r(r'glute-ham|glute ham|nordic'), (_) => Movements.legCurl),
    (_r(r'reverse hyper|prone leg raise'), (_) => Movements.superman),
    (_r(r'side bridge|side plank'), (_) => Movements.plank),
    (_r(r'squat(ting)? row'), (_) => Movements.row),
    (_r(r'squatting curl'), (_) => Movements.curl),
    (
      _r(r'toe touch'),
      (e) => e.target == 'abs' ? Movements.sitUp : Movements.forwardFold,
    ),
    (_r(r'burpee'), (_) => Movements.burpee),
    (_r(r'mountain climber'), (_) => Movements.mountainClimber),
    (_r(r'crunch'), (_) => Movements.crunch),
    (
      _r(r'\brun\b|running|jog|sprint|high knee|butt kick'),
      (_) => Movements.run,
    ),
    (_r(r'bike|cycling|ergometer'), (_) => Movements.cycling),
    (
      _r(r'jump squat|squat jump|box jump|tuck jump|broad jump|jump lunge'),
      (_) => Movements.jumpSquat,
    ),
    (_r(r'jump|skip|hop\b'), (_) => Movements.jump),
    (
      _r(r'clean and press|clean & press|clean and jerk'),
      (_) => Movements.cleanAndPress,
    ),
    (_r(r'snatch'), (_) => Movements.snatch),
    (_r(r'\bclean'), (_) => Movements.clean),
    (_r(r'thruster'), (_) => Movements.thruster),
    (_r(r'swing'), (_) => Movements.kettlebellSwing),
    (_r(r'chop'), (_) => Movements.woodChop),
    (_r(r'side bend'), (_) => Movements.sideBend),
    (
      _r(r'leg press|sled press|sled .*press|leg wide press'),
      (_) => Movements.legPress,
    ),
    (_r(r'leg extension'), (_) => Movements.legExtension),
    (_r(r'seated leg curl'), (_) => Movements.seatedLegCurl),
    (_r(r'leg curl|hamstring curl'), (_) => Movements.legCurl),
    (
      _r(r'abduct|adduct|side leg|clam|fire hydrant|lateral leg'),
      (_) => Movements.abduction,
    ),
    (_r(r'calf|calves|heel raise|toe raise'), (_) => Movements.calfRaise),
    (_r(r'hip thrust'), (_) => Movements.hipThrust),
    (_r(r'bridge|hip raise|hip lift|pelvic'), (_) => Movements.bridge),
    (_r(r'good morning'), (_) => Movements.goodMorning),
    (
      _r(r'romanian|stiff leg|straight leg deadlift|single leg deadlift'),
      (_) => Movements.romanianDeadlift,
    ),
    (_r(r'deadlift|rack pull'), (_) => Movements.deadlift),
    (
      _r(r'lunge|split squat|bulgarian'),
      (e) => _barbell(e) ? Movements.barbellLunge : Movements.lunge,
    ),
    (_r(r'step-up|step up|stepup'), (_) => Movements.stepUp),
    (_r(r'front squat|goblet|zercher'), (_) => Movements.frontSquat),
    (_r(r'squat|sit-to-stand'), _squat),
    (_r(r'push-up|push up|pushup|press-up|press up'), (_) => Movements.pushUp),
    (
      _r(
        r'rear delt|reverse fly|revers fly|rear fly|rear lateral|reverse flye',
      ),
      (_) => Movements.reverseFly,
    ),
    (
      _r(r'seated row|cable row|seated.*row|rowing|rower|low row'),
      (_) => Movements.seatedRow,
    ),
    (_r(r'\bfly|flye|crossover|pec deck'), (_) => Movements.fly),
    (_r(r'pullover|pull-over|straight.?arm'), (_) => Movements.pullover),
    (
      _r(r'pull-up|pull up|pullup|chin-up|chin up|chinup|muscle up'),
      (_) => Movements.pullUp,
    ),
    (_r(r'\bdips?\b'), (_) => Movements.dip),
    (_r(r'pulldown|pull-down|pull down'), (_) => Movements.pulldown),
    (_r(r'face pull'), (_) => Movements.facePull),
    (_r(r'upright row'), (_) => Movements.uprightRow),
    (_r(r'\brows?\b'), (_) => Movements.row),
    (_r(r'shrug'), (_) => Movements.shrug),
    (
      _r(r'hyperextension|back extension|back raise'),
      (_) => Movements.backExtension,
    ),
    (_r(r'superman|swimmer'), (_) => Movements.superman),
    (_r(r'hanging.*knee|knee raise'), (_) => Movements.hangingKneeRaise),
    (
      _r(r'leg raise\b|leg lift|leg pull|flutter|scissor|dead bug'),
      (_) => Movements.legRaise,
    ),
    (
      _r(r'lateral raise|side raise|side lateral|lateral|\by raise'),
      (_) => Movements.lateralRaise,
    ),
    (_r(r'front raise'), (_) => Movements.frontRaise),
    (_r(r'skull|lying.*tric|lying.*extension'), (_) => Movements.skullCrusher),
    (_r(r'kickback|kick back'), (_) => Movements.kickback),
    (_r(r'pushdown|push-down|push down|pressdown'), (_) => Movements.pushdown),
    (
      _r(r'triceps? extension|overhead extension|french press'),
      (_) => Movements.overheadExtension,
    ),
    (
      _r(r'seated.*(shoulder|overhead|military) press|seated press'),
      (_) => Movements.seatedPress,
    ),
    (
      _r(
        r'shoulder press|overhead press|military press|push press|arnold|'
        r'jerk|press overhead',
      ),
      (_) => Movements.overheadPress,
    ),
    (_r(r'curl'), (_) => Movements.curl),
    (
      _r(r'bench|chest press|floor press'),
      (e) => _press(e, e.name.toLowerCase()),
    ),
    (
      _r(r'(internal|external).*rotation'),
      (e) =>
          e.target == 'glutes' ? Movements.abduction : Movements.lateralRaise,
    ),
    (_r(r'battling'), (_) => Movements.frontRaise),
    (_r(r'twist|rotation'), (_) => Movements.twist),
    (
      _r(r'sit-up|sit up|situp|v-up|v up|jackknife|roll ?up'),
      (_) => Movements.sitUp,
    ),
    (_r(r'plank|hollow|bear crawl|\bhold\b'), (_) => Movements.plank),
    (_r(r'walk|carry|march'), (_) => Movements.walk),
    (
      _r(r'\braise'),
      (e) =>
          e.target == 'delts' ? Movements.lateralRaise : Movements.frontRaise,
    ),
    (
      _r(r'press'),
      (e) => switch (e.target) {
        'pectorals' => _press(e, e.name.toLowerCase()),
        // Close-grip presses lying down are bench presses.
        'triceps'
            when RegExp(r'lying|bench|floor|pin|incline|decline|close')
                .hasMatch(e.name.toLowerCase()) =>
          _press(e, e.name.toLowerCase()),
        'triceps' => Movements.pushdown,
        _ => Movements.overheadPress,
      },
    ),
    (_r(r'neck'), (_) => Movements.neck),
    (_r(r'wrist|forearm'), (_) => Movements.curl),
  ];

  static Movement _byTarget(CatalogExercise e) => switch (e.target) {
    'abs' => Movements.crunch,
    'pectorals' =>
      e.bodyweight ? Movements.pushUp : _press(e, e.name.toLowerCase()),
    'biceps' || 'forearms' => Movements.curl,
    'glutes' => Movements.bridge,
    'delts' => Movements.overheadPress,
    'triceps' => Movements.pushdown,
    'upper back' => Movements.row,
    'lats' => e.bodyweight ? Movements.pullUp : Movements.pulldown,
    'calves' => Movements.calfRaise,
    'quads' => _squat(e),
    'cardiovascular system' => Movements.run,
    'hamstrings' => Movements.romanianDeadlift,
    'spine' => Movements.backExtension,
    'traps' => Movements.shrug,
    'adductors' || 'abductors' => Movements.abduction,
    'serratus anterior' => Movements.pushUp,
    'levator scapulae' => Movements.neck,
    _ => Movements.stand,
  };
}
