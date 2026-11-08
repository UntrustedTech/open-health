import 'dart:math' as math;

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:health_app/screens/workouts/set_row.dart'
    show formatWeightInput;
import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/exercise_clip.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/workout/workout_tracker.dart';

const _restColor = Palette.teal;

/// The top of a strength workout: the set to do now with big controls,
/// or the rest countdown, plus what comes next.
class LiveFocus extends StatelessWidget {
  const LiveFocus({super.key, required this.tracker});

  final WorkoutTracker tracker;

  @override
  Widget build(BuildContext context) {
    final resting = tracker.restRemaining != null;
    final next = tracker.nextSet;
    final Widget child;
    if (resting) {
      child = _RestRing(key: const ValueKey('rest'), tracker: tracker);
    } else if (next != null) {
      child = _NowCard(
        key: ValueKey('now ${next.exercise} ${next.set}'),
        tracker: tracker,
        exercise: next.exercise,
        set: next.set,
      );
    } else if (tracker.exercises.isNotEmpty) {
      child = const _AllDone(key: ValueKey('done'));
    } else {
      child = const SizedBox.shrink(key: ValueKey('empty'));
    }
    return AnimatedSwitcher(
      duration: Motion.reduced(context) ? Duration.zero : Motion.medium,
      switchInCurve: Motion.curve,
      switchOutCurve: Motion.curve,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(a),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// "Up next" text for the set after [exercise]/[set].
String? _upNext(WorkoutTracker t, int exercise, int set) {
  final ex = t.exercises;
  for (var i = exercise; i < ex.length; i++) {
    for (var j = i == exercise ? set + 1 : 0; j < ex[i].sets.length; j++) {
      final s = ex[i].sets[j];
      if (s.done) continue;
      final name = ExerciseCatalog.instance.nameOf(ex[i].exerciseId);
      final what = s.weightKg > 0
          ? '${Units.weight(s.weightKg)} × ${s.reps}'
          : '${s.reps} reps';
      return i == exercise
          ? 'Set ${j + 1} · $what'
          : '$name · set ${j + 1} · $what';
    }
  }
  return null;
}

class _NowCard extends StatelessWidget {
  const _NowCard({
    super.key,
    required this.tracker,
    required this.exercise,
    required this.set,
  });

  final WorkoutTracker tracker;
  final int exercise;
  final int set;

  @override
  Widget build(BuildContext context) {
    final log = tracker.exercises[exercise];
    final s = log.sets[set];
    final color = context.resolve(tracker.type.color);
    final timed = s.seconds != null && s.reps == 0;
    final step = Units.imperial ? 5.0 : 2.5;
    final next = _upNext(tracker, exercise, set);
    void update(SetLog v) {
      HapticFeedback.selectionClick();
      tracker.updateSet(exercise, set, v);
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: context.cardBackground,
        shape: AppTheme.squircle(context.cardRadius(AppTheme.heroRadius)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExerciseThumb(exerciseId: log.exerciseId, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NOW · SET ${set + 1} OF ${log.sets.length}',
                      style: context.caption1.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      ExerciseCatalog.instance.nameOf(log.exerciseId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.title3.copyWith(color: context.labelColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (!timed) ...[
                Expanded(
                  child: _Stepper(
                    label: Units.weightUnit.toUpperCase(),
                    value: formatWeightInput(s.weightKg),
                    color: color,
                    onMinus: s.weightKg <= 0
                        ? null
                        : () => update(
                            s.copyWith(
                              weightKg: math.max(
                                0,
                                s.weightKg - Units.weightIn(step),
                              ),
                            ),
                          ),
                    onPlus: () => update(
                      s.copyWith(weightKg: s.weightKg + Units.weightIn(step)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: timed
                    ? _Stepper(
                        label: 'SECONDS',
                        value: '${s.seconds}',
                        color: color,
                        onMinus: (s.seconds ?? 0) <= 5
                            ? null
                            : () => update(
                                s.copyWith(seconds: (s.seconds ?? 0) - 5),
                              ),
                        onPlus: () =>
                            update(s.copyWith(seconds: (s.seconds ?? 0) + 5)),
                      )
                    : _Stepper(
                        label: 'REPS',
                        value: '${s.reps}',
                        color: color,
                        onMinus: s.reps <= 1
                            ? null
                            : () => update(s.copyWith(reps: s.reps - 1)),
                        onPlus: () => update(s.copyWith(reps: s.reps + 1)),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Pressable(
            semanticLabel: tr('Complete set ${set + 1}'),
            onTap: () {
              HapticFeedback.mediumImpact();
              tracker.toggleSetDone(exercise, set);
            },
            child: Container(
              height: 54,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: color,
                shape: const StadiumBorder(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, color: context.onColor(color)),
                  const SizedBox(width: 6),
                  Text(
                    'Complete Set',
                    style: context.headline.copyWith(
                      color: context.onColor(color),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (next != null) ...[
            const SizedBox(height: 12),
            _UpNext(text: next),
          ],
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.color,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String value;
  final Color color;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, VoidCallback? onTap, String what) => Expanded(
      child: Semantics(
        container: true,
        button: true,
        enabled: onTap != null,
        label: '$what $label',
        onTap: onTap,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: AppTheme.minTapTarget,
            decoration: ShapeDecoration(
              color: onTap == null
                  ? context.fillColor
                  : color.withValues(alpha: 0.18),
              shape: AppTheme.squircle(12),
            ),
            child: Icon(
              icon,
              size: 22,
              color: onTap == null ? context.secondaryLabel : color,
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: ShapeDecoration(
        color: context.fillColor,
        shape: AppTheme.squircle(16),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: context.caption2.copyWith(
              color: context.secondaryLabel,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(
            height: 48,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedSwitcher(
                duration: Motion.reduced(context) ? Duration.zero : Motion.fast,
                transitionBuilder: (c, a) =>
                    ScaleTransition(scale: a, child: c),
                child: Text(
                  value,
                  key: ValueKey(value),
                  style: context
                      .number(36, weight: FontWeight.w700)
                      .copyWith(color: context.labelColor),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              button(Icons.remove_rounded, onMinus, 'Less'),
              const SizedBox(width: 8),
              button(Icons.add_rounded, onPlus, 'More'),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpNext extends StatelessWidget {
  const _UpNext({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        'UP NEXT',
        style: context.caption2.copyWith(
          color: context.secondaryLabel,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.footnote.copyWith(color: context.labelColor),
        ),
      ),
    ],
  );
}

/// A big countdown ring while resting, redrawn every frame.
class _RestRing extends StatefulWidget {
  const _RestRing({super.key, required this.tracker});

  final WorkoutTracker tracker;

  @override
  State<_RestRing> createState() => _RestRingState();
}

class _RestRingState extends State<_RestRing>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  /// How much rest is left (1 → 0); the ring repaints from it every frame,
  /// while the rest of the panel rebuilds only when the seconds change.
  final _progress = ValueNotifier<double>(1);
  int? _shownSeconds;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      final t = widget.tracker;
      final left = t.restRemaining ?? Duration.zero;
      final total = t.restTotal.inMilliseconds;
      _progress.value = total <= 0 ? 0.0 : left.inMilliseconds / total;
      final seconds = (left + const Duration(milliseconds: 999)).inSeconds;
      if (seconds != _shownSeconds) setState(() => _shownSeconds = seconds);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tracker;
    final left = t.restRemaining ?? Duration.zero;
    final next = t.nextSet;
    final upNext = next == null
        ? null
        : _upNext(t, next.exercise, next.set - 1) ??
              ExerciseCatalog.instance.nameOf(
                t.exercises[next.exercise].exerciseId,
              );
    final teal = context.resolve(_restColor);
    Widget pill(String label, VoidCallback onTap) => CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, AppTheme.minTapTarget),
      color: context.labelColor.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(22),
      onPressed: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Text(
        label,
        style: context.subheadline.copyWith(
          color: context.labelColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: ShapeDecoration(
        color: context.cardBackground,
        shape: AppTheme.squircle(context.cardRadius(AppTheme.heroRadius)),
      ),
      child: Column(
        children: [
          Semantics(
            label: 'Rest, ${left.inSeconds} seconds left',
            excludeSemantics: true,
            child: SizedBox.square(
              dimension: 190,
              child: CustomPaint(
                painter: _RingPainter(progress: _progress, color: teal),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'REST',
                        style: context.caption1.copyWith(
                          color: teal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        formatClock(left + const Duration(milliseconds: 999)),
                        style: context
                            .number(46, weight: FontWeight.w700)
                            .copyWith(color: context.labelColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: pill(
                  '−15s',
                  () => t.adjustRest(const Duration(seconds: -15)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: pill(
                  '+15s',
                  () => t.adjustRest(const Duration(seconds: 15)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, AppTheme.minTapTarget),
                  color: teal,
                  borderRadius: BorderRadius.circular(22),
                  onPressed: t.skipRest,
                  child: Text(
                    'Skip',
                    style: context.subheadline.copyWith(
                      color: context.onColor(teal),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (upNext != null) ...[
            const SizedBox(height: 14),
            _UpNext(text: upNext),
          ],
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color})
    : super(repaint: progress);

  final ValueListenable<double> progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      paint..color = color.withValues(alpha: 0.18),
    );
    final sweep = math.pi * 2 * progress.value.clamp(0.0, 1.0);
    if (sweep <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      paint
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

class _AllDone extends StatelessWidget {
  const _AllDone({super.key});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(16),
    decoration: ShapeDecoration(
      color: context.cardRaised,
      shape: AppTheme.squircle(context.cardRadius(AppTheme.radius)),
    ),
    child: Row(
      children: [
        Icon(
          Icons.verified_rounded,
          color: context.resolve(Palette.green),
          size: 28,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'All sets done. Add another exercise or tap End to finish.',
            style: context.subheadline.copyWith(color: context.labelColor),
          ),
        ),
      ],
    ),
  );
}
