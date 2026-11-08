import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/exercise_library.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/workout/progression.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/app_segmented.dart';

/// Detailed options for one exercise in a routine.
class RoutineItemSheet extends StatefulWidget {
  const RoutineItemSheet({
    super.key,
    required this.item,
    required this.controller,
  });

  final RoutineItem item;
  final ScrollController controller;

  static Future<RoutineItem?> show(BuildContext context, RoutineItem item) =>
      showCupertinoSheet<RoutineItem>(
        context: context,
        scrollableBuilder: (context, controller) =>
            RoutineItemSheet(item: item, controller: controller),
      );

  /// "3 × 8 · Linear +2.5 kg · Rest 2:00" for the routine list.
  static String summary(RoutineItem it) {
    final p = it.progression;
    final reps = p.kind == ProgressionKind.double
        ? '${p.repMin}–${p.repMax}'
        : '${it.reps}';
    return [
      '${it.sets} × $reps',
      if (it.warmupSets > 0) '+${it.warmupSets} warm-up',
      if (p.kind != ProgressionKind.none)
        '${p.kind.label} +${Units.weight(p.increment)}',
      if (it.restSeconds case final r?) 'Rest ${_clock(r)}',
      if (it.superset case final s?) 'Superset $s',
    ].join(' · ');
  }

  static String _clock(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  State<RoutineItemSheet> createState() => _RoutineItemSheetState();
}

class _RoutineItemSheetState extends State<RoutineItemSheet> {
  late RoutineItem _it = widget.item;

  void _set(RoutineItem it) => setState(() => _it = it);

  Widget _stepper(
    String title,
    String value,
    VoidCallback? minus,
    VoidCallback? plus,
  ) => CupertinoListTile(
    title: Text(title),
    additionalInfo: Text(value),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(AppTheme.minTapTarget),
          onPressed: minus,
          child: Icon(
            Icons.remove_circle_rounded,
            semanticLabel: tr('Less $title'),
          ),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(AppTheme.minTapTarget),
          onPressed: plus,
          child: Icon(
            Icons.add_circle_rounded,
            semanticLabel: tr('More $title'),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final it = _it;
    final p = it.progression;
    String kg(double v) => Units.weight(v);
    // Steps of 1.25 kg, or 2.5 lb for imperial users.
    final step = Units.weightIn(Units.imperial ? 2.5 : 1.25);
    final maxStep = Units.weightIn(Units.imperial ? 25 : 10);
    final rest = it.restSeconds;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        // Sheets don't morph the title from the page below, as on iOS;
        // every bar shares one hero tag, so it would fly into the sheet.
        transitionBetweenRoutes: false,
        automaticallyImplyLeading: false,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        middle: Text(ExerciseLibrary.nameOf(it.exerciseId)),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(_it),
          child: const Text(
            'Done',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      child: PageList(
        controller: widget.controller,
        padding: const EdgeInsets.fromLTRB(
          AppTheme.margin,
          8,
          AppTheme.margin,
          32,
        ),
        children: [
          GroupedSection(
            header: 'Sets',
            hasLeading: false,
            children: [
              _stepper(
                'Working Sets',
                '${it.sets}',
                it.sets > 1 ? () => _set(it.copyWith(sets: it.sets - 1)) : null,
                it.sets < 10
                    ? () => _set(it.copyWith(sets: it.sets + 1))
                    : null,
              ),
              if (p.kind != ProgressionKind.double)
                _stepper(
                  'Reps',
                  '${it.reps}',
                  it.reps > 1
                      ? () => _set(it.copyWith(reps: it.reps - 1))
                      : null,
                  it.reps < 100
                      ? () => _set(it.copyWith(reps: it.reps + 1))
                      : null,
                ),
              _stepper(
                'Starting Weight',
                kg(it.weightKg),
                it.weightKg >= 2.5
                    ? () => _set(it.copyWith(weightKg: it.weightKg - 2.5))
                    : null,
                () => _set(it.copyWith(weightKg: it.weightKg + 2.5)),
              ),
              _stepper(
                'Warm-up Sets',
                '${it.warmupSets}',
                it.warmupSets > 0
                    ? () => _set(it.copyWith(warmupSets: it.warmupSets - 1))
                    : null,
                it.warmupSets < 3
                    ? () => _set(it.copyWith(warmupSets: it.warmupSets + 1))
                    : null,
              ),
            ],
          ),
          GroupedSection(
            header: 'Rest',
            footer: 'Rest between sets. Default uses Workout Settings. Exercises in the same superset group run back to back.',
            hasLeading: false,
            children: [
              _stepper(
                'Rest',
                rest == null ? 'Default' : RoutineItemSheet._clock(rest),
                rest == null
                    ? null
                    : () => _set(
                        rest <= 15
                            ? it.copyWith(clearRest: true)
                            : it.copyWith(restSeconds: rest - 15),
                      ),
                (rest ?? 0) < 900
                    ? () => _set(it.copyWith(restSeconds: (rest ?? 75) + 15))
                    : null,
              ),
              // Its own full-width row, so the label isn't squeezed.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Superset', style: context.body),
                    const SizedBox(height: 8),
                    AppSegmented<int>(
                      groupValue: it.superset ?? 0,
                      children: const {
                        0: Text('Off'),
                        1: Text('A'),
                        2: Text('B'),
                        3: Text('C'),
                      },
                      onValueChanged: (v) => _set(
                        v == null || v == 0
                            ? it.copyWith(clearSuperset: true)
                            : it.copyWith(superset: v),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          GroupedSection(
            header: 'Progression',
            footer: switch (p.kind) {
              ProgressionKind.none => 'Starts from your numbers last time.',
              ProgressionKind.linear =>
                'Adds ${kg(p.increment)} whenever every set hits its reps. '
                    'After ${p.stallLimit} stalled sessions it deloads by 10%.',
              ProgressionKind.double =>
                'Adds a rep each session up to ${p.repMax}, then adds '
                    '${kg(p.increment)} and starts again at ${p.repMin}.',
            },
            hasLeading: false,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: AppSegmented<ProgressionKind>(
                    groupValue: p.kind,
                    children: const {
                      ProgressionKind.none: Text('Repeat'),
                      ProgressionKind.linear: Text('Linear'),
                      ProgressionKind.double: Text('Double'),
                    },
                    onValueChanged: (k) {
                      if (k == null) return;
                      _set(
                        it.copyWith(
                          progression: ProgressionRule(
                            kind: k,
                            increment: p.increment,
                            repMin: p.repMin,
                            repMax: p.repMax,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (p.kind != ProgressionKind.none)
                _stepper(
                  'Weight Step',
                  kg(p.increment),
                  p.increment > step + 1e-6
                      ? () => _setRule(p, increment: p.increment - step)
                      : null,
                  p.increment < maxStep - 1e-6
                      ? () => _setRule(p, increment: p.increment + step)
                      : null,
                ),
              if (p.kind == ProgressionKind.double) ...[
                _stepper(
                  'Lowest Reps',
                  '${p.repMin}',
                  p.repMin > 1 ? () => _setRule(p, repMin: p.repMin - 1) : null,
                  p.repMin < p.repMax - 1
                      ? () => _setRule(p, repMin: p.repMin + 1)
                      : null,
                ),
                _stepper(
                  'Highest Reps',
                  '${p.repMax}',
                  p.repMax > p.repMin + 1
                      ? () => _setRule(p, repMax: p.repMax - 1)
                      : null,
                  p.repMax < 30
                      ? () => _setRule(p, repMax: p.repMax + 1)
                      : null,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _setRule(
    ProgressionRule p, {
    double? increment,
    int? repMin,
    int? repMax,
  }) => _set(
    _it.copyWith(
      progression: ProgressionRule(
        kind: p.kind,
        increment: increment ?? p.increment,
        repMin: repMin ?? p.repMin,
        repMax: repMax ?? p.repMax,
      ),
    ),
  );
}
