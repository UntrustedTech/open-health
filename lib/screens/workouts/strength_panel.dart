import 'dart:async';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/models/exercise_library.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/screens/workouts/exercise_library_screen.dart';
import 'package:health_app/screens/workouts/live_focus.dart';
import 'package:health_app/screens/workouts/plate_sheet.dart';
import 'package:health_app/screens/workouts/set_row.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/exercise_clip.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/workout/workout_tracker.dart';

/// Live strength logging: exercises with sets, previous results and a rest
/// timer that starts when a set is ticked off.
class StrengthPanel extends StatelessWidget {
  const StrengthPanel({super.key, required this.tracker});

  final WorkoutTracker tracker;

  Future<void> _addExercise(BuildContext context) async {
    final id = await ExerciseLibraryScreen.pick(context);
    if (id == null) return;
    final previous = context.mounted
        ? context.read<WorkoutStore>().previousSets(id)
        : const <SetLog>[];
    tracker.addExercise(
      id,
      sets: previous.isEmpty
          ? null
          : [for (final s in previous) s.copyWith(done: false, clearRpe: true)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercises = tracker.exercises;
    final completed = exercises.fold<int>(
      0,
      (n, e) => n + e.sets.where((s) => s.done).length,
    );
    final volume = exercises.fold<double>(
      0,
      (v, e) => v + e.sets.where((s) => s.done).fold(0, (a, s) => a + s.volume),
    );
    final color = context.resolve(tracker.type.color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$completed ${completed == 1 ? 'set' : 'sets'} · '
          '${Units.weight(volume, decimals: 0)} lifted · '
          '${tracker.activeKcal.round()} Cal',
          style: context.subheadline.copyWith(color: context.secondaryLabel),
        ),
        LiveFocus(tracker: tracker),
        const SizedBox(height: 12),
        for (final (i, e) in exercises.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Appear(
              index: i,
              child: _ExerciseCard(tracker: tracker, index: i, log: e),
            ),
          ),
        CupertinoButton(
          color: color.withValues(alpha: 0.2),
          borderRadius: context.cardBorderRadius(AppTheme.radius),
          onPressed: () => _addExercise(context),
          child: Text(
            'Add Exercise',
            style: context.headline.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.tracker,
    required this.index,
    required this.log,
  });

  final WorkoutTracker tracker;
  final int index;
  final ExerciseLog log;

  @override
  Widget build(BuildContext context) {
    final store = context.read<WorkoutStore>();
    final exercise = ExerciseCatalog.instance.byId(log.exerciseId);
    final timed = exercise?.timed ?? false;
    // Last time's sets, matched warm-up to warm-up and working to working.
    final previous = store.previousSets(log.exerciseId);
    final prevWorking = [
      for (final p in previous)
        if (p.type.counts) p,
    ];
    final prevWarmups = [
      for (final p in previous)
        if (!p.type.counts) p,
    ];
    final effort = store.settings.effort;
    final hint = tracker.hints[log.exerciseId];
    final barbell = exercise?.equipment.contains('barbell') ?? false;
    final header = context.caption1.copyWith(
      color: context.secondaryLabel,
      fontWeight: FontWeight.w600,
    );
    final color = context.resolve(tracker.type.color);
    final next = tracker.nextSet;
    var working = 0;
    var warmups = 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: ShapeDecoration(
        color: context.cardBackground,
        shape: context.cardShape(AppTheme.radius),
        shadows: context.skinShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (log.superset != null)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: ShapeDecoration(
                    color: color.withValues(alpha: 0.25),
                    shape: AppTheme.squircle(6),
                  ),
                  child: Text(
                    'SUPERSET ${log.superset}',
                    style: context.caption2.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Expanded(
                // Tap for the demonstration and how-to steps.
                child: Semantics(
                  button: true,
                  hint: tr('Shows how to do it'),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        ExerciseClipSheet.show(context, log.exerciseId),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ExerciseThumb(
                            exerciseId: log.exerciseId,
                            size: 36,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            ExerciseLibrary.nameOf(log.exerciseId),
                            style: context.headline.copyWith(color: color),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (barbell)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size.square(AppTheme.minTapTarget),
                  onPressed: () => PlateSheet.show(
                    context,
                    log.sets.where((s) => !s.done).firstOrNull?.weightKg ??
                        log.sets.lastOrNull?.weightKg ??
                        20,
                  ),
                  child: Icon(
                    Icons.donut_large_rounded,
                    size: 20,
                    color: context.secondaryLabel,
                    semanticLabel: tr('Plate calculator'),
                  ),
                ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size.square(AppTheme.minTapTarget),
                onPressed: () => tracker.removeExercise(index),
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: context.secondaryLabel,
                  semanticLabel: tr('Remove exercise'),
                ),
              ),
            ],
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, right: 8),
              child: Text(
                hint,
                style: context.footnote.copyWith(color: context.secondaryLabel),
              ),
            ),
          // Headers only: each row reads its own values out.
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: SetColumns.number,
                    child: Text(
                      'SET',
                      style: header,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: SetColumns.previousFlex,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text('LAST', style: header, maxLines: 1),
                    ),
                  ),
                  Expanded(
                    flex: SetColumns.weightFlex,
                    child: Text(
                      Units.weightUnit.toUpperCase(),
                      style: header,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: SetColumns.amountFlex,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        timed
                            ? 'SEC'
                            : (exercise?.perSide ?? false)
                            ? 'REPS/SIDE'
                            : 'REPS',
                        style: header,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  if (effort != EffortMode.off)
                    SizedBox(
                      width: SetColumns.effort,
                      child: Text(
                        effort.label,
                        style: header,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SizedBox(
                    width: SetColumns.done,
                    child: Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: context.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final (s, set) in log.sets.indexed)
            SetRow(
              key: ValueKey('${log.exerciseId}-$index-$s'),
              number: set.type == SetType.warmup ? 0 : ++working,
              active: next?.exercise == index && next?.set == s,
              set: set,
              previous: set.type.counts
                  ? prevWorking.elementAtOrNull(working - 1)
                  : prevWarmups.elementAtOrNull(warmups++),
              color: color,
              timed: timed,
              effort: effort,
              onChanged: (v) => tracker.updateSet(index, s, v),
              onToggle: () {
                HapticFeedback.mediumImpact();
                tracker.toggleSetDone(index, s);
              },
              onCopy: () => tracker.copySet(index, s),
              onDelete: log.sets.length > 1
                  ? () => tracker.removeSet(index, s)
                  : null,
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => tracker.addSet(index),
              child: Text(
                '+ Add Set',
                style: context.subheadline.copyWith(color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
