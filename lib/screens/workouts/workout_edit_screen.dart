import 'dart:async';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/widgets/number_input.dart';
import 'package:health_app/models/exercise_library.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/screens/workouts/exercise_library_screen.dart';
import 'package:health_app/screens/workouts/set_row.dart'
    show formatWeightInput;
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/workout/calories.dart';
import 'package:health_app/workout/energy.dart';

/// Edit a saved workout, or log one done without the app.
class WorkoutEditScreen extends StatefulWidget {
  const WorkoutEditScreen({super.key, this.session});

  /// Null to log a new (past) workout.
  final WorkoutSession? session;

  static Future<void> open(BuildContext context, {WorkoutSession? session}) =>
      Navigator.of(context, rootNavigator: true).push(
        AppRoute<void>(
          fullscreenDialog: true,
          builder: (_) => WorkoutEditScreen(session: session),
        ),
      );

  @override
  State<WorkoutEditScreen> createState() => _WorkoutEditScreenState();
}

class _WorkoutEditScreenState extends State<WorkoutEditScreen> {
  late WorkoutType _type = widget.session?.type ?? WorkoutType.strength;
  late DateTime _start =
      widget.session?.start ??
      DateTime.now()
          .subtract(const Duration(hours: 2))
          .copyWith(second: 0, millisecond: 0, microsecond: 0);
  late int _minutes = (widget.session?.activeSeconds ?? 2700) ~/ 60;

  /// The minutes shown at first, to tell whether the duration was edited.
  late final int _minutesShown = _minutes;
  late final _distance = TextEditingController(
    text: (widget.session?.distanceMeters ?? 0) >= 10
        ? Units.distanceOut(widget.session!.distanceMeters / 1000)
              .toStringAsFixed(2)
        : '',
  );
  late final String _distanceShown = _distance.text;
  late final _kcal = TextEditingController(
    text: widget.session == null ? '' : '${widget.session!.activeKcal.round()}',
  );
  late final _notes = TextEditingController(text: widget.session?.notes ?? '');
  late List<ExerciseLog> _exercises = List.of(
    widget.session?.exercises ?? const [],
  );
  bool _saving = false;

  bool get _isNew => widget.session == null;
  bool get _hasDistance =>
      _type.usesGps ||
      {
        WorkoutType.swim,
        WorkoutType.row,
        WorkoutType.elliptical,
      }.contains(_type);

  @override
  void dispose() {
    _distance.dispose();
    _kcal.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    var picked = _start;
    final ok = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => Container(
        height: 300,
        color: context.cardBackground,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: CupertinoButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  initialDateTime: _start,
                  maximumDate: DateTime.now(),
                  minimumDate: DateTime(2000),
                  minuteInterval: 1,
                  onDateTimeChanged: (d) => picked = d,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok ?? false) setState(() => _start = picked);
  }

  Future<void> _pickType() async {
    final t = await showCupertinoModalPopup<WorkoutType>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Workout Type'),
        actions: [
          for (final t in WorkoutType.values)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, t),
              child: Text(t.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (t != null) setState(() => _type = t);
  }

  Future<void> _addExercise() async {
    final id = await ExerciseLibraryScreen.pick(context);
    if (id == null || !mounted) return;
    final previous = context.read<WorkoutStore>().previousSets(id);
    setState(() {
      _exercises = [
        ..._exercises,
        ExerciseLog(
          exerciseId: id,
          sets: previous.isEmpty
              ? const [SetLog(reps: 10, weightKg: 0, done: true)]
              : [for (final s in previous) s.copyWith(done: true)],
        ),
      ];
    });
  }

  void _setSets(int e, List<SetLog> sets) => setState(
    () =>
        _exercises = [..._exercises]..[e] = _exercises[e].copyWith(sets: sets),
  );

  /// Intensity from the distance and time entered, when there is one.
  double _metFor(double km, Duration duration) {
    final pace = paceOf(
      distanceMeters: _hasDistance ? km * 1000 : 0,
      active: duration,
      elevationGainMeters: widget.session?.elevationGainMeters ?? 0,
    );
    return metFor(
      _type,
      metersPerSecond: pace.metersPerSecond,
      grade: pace.grade,
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final ends = _start.add(Duration(minutes: _minutes.clamp(1, 24 * 60)));
    // A small allowance for the minutes spent filling in the form.
    if (ends.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      unawaited(HapticFeedback.heavyImpact());
      await showMessage(
        context,
        title: 'Ends in the Future',
        message:
            'This workout would end after now. Choose an earlier start or '
            'a shorter duration.',
      );
      return;
    }
    setState(() => _saving = true);
    unawaited(HapticFeedback.mediumImpact());
    final store = context.read<WorkoutStore>();
    final health = context.read<HealthStore>();
    final weight =
        health.latestReading(MetricType.weight)?.value ?? defaultWeightKg;
    final old = widget.session;
    // Untouched, the recorded time stays exact (seconds included); edited,
    // any time spent paused is kept on top of the new active time.
    final kept = old != null && _minutes == _minutesShown;
    final duration = kept
        ? Duration(seconds: old.activeSeconds)
        : Duration(minutes: _minutes.clamp(1, 24 * 60));
    final paused = old == null
        ? Duration.zero
        : old.end.difference(old.start) - Duration(seconds: old.activeSeconds);
    final end = kept && _start == old.start
        ? old.end
        : _start.add(duration + (paused.isNegative ? Duration.zero : paused));
    // Unchanged text keeps the exact recorded distance.
    final km = _distance.text == _distanceShown
        ? (widget.session?.distanceMeters ?? 0) / 1000
        : Units.distanceIn(
            double.tryParse(_distance.text.replaceAll(',', '.')) ?? 0,
          );
    final kcal =
        double.tryParse(_kcal.text.replaceAll(',', '.')) ??
        activeCalories(
          met: _metFor(km, duration),
          weightKg: weight,
          duration: duration,
        );
    final session = WorkoutSession(
      id: old?.id ?? 'log${DateTime.now().microsecondsSinceEpoch}',
      type: _type,
      start: _start,
      end: end,
      activeSeconds: duration.inSeconds,
      distanceMeters: _hasDistance ? (km * 1000).clamp(0, 1000000) : 0,
      activeKcal: kcal.clamp(0, 20000),
      elevationGainMeters: old?.elevationGainMeters ?? 0,
      splits: old?.splits ?? const [],
      laps: old?.laps ?? const [],
      exercises: _type == WorkoutType.strength ? _exercises : const [],
      intervalProgram: old?.intervalProgram,
      rpe: old?.rpe,
      notes: _notes.text.trim(),
      hasRoute: old?.hasRoute ?? false,
      source: old?.source ?? WorkoutSource.app,
      routineId: old?.routineId,
    );
    try {
      if (old == null) {
        await store.save(session);
      } else {
        await store.update(session, relink: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final end = _start.add(Duration(minutes: _minutes));
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        middle: Text(_isNew ? 'Log Workout' : 'Edit Workout'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _saving ? null : _save,
          child: const Text(
            'Save',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      child: PageList(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.margin,
          8,
          AppTheme.margin,
          32,
        ),
        children: [
          GroupedSection(
            hasLeading: false,
            children: [
              InfoRow(
                title: 'Type',
                value: _type.label,
                chevron: _isNew,
                onTap: _isNew ? _pickType : null,
              ),
              InfoRow(
                title: 'Start',
                value:
                    '${DateFormat.MMMd().format(_start)}, ${DateFormat.jm().format(_start)}',
                chevron: true,
                onTap: _pickDateTime,
              ),
              CupertinoListTile(
                title: const Text('Duration'),
                subtitle: Text(
                  '$_minutes min · ends ${DateFormat.jm().format(end)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size.square(AppTheme.minTapTarget),
                      onPressed: _minutes > 5
                          ? () => setState(() => _minutes -= 5)
                          : null,
                      child: Icon(
                        Icons.remove_circle_rounded,
                        semanticLabel: tr('Shorter'),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size.square(AppTheme.minTapTarget),
                      onPressed: () => setState(() => _minutes += 5),
                      child: Icon(
                        Icons.add_circle_rounded,
                        semanticLabel: tr('Longer'),
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasDistance)
                _field(
                  'Distance',
                  _distance,
                  Units.distanceUnit,
                  decimal: true,
                ),
              _field(
                'Active Energy',
                _kcal,
                'Cal',
                placeholder: tr('Estimate'),
              ),
            ],
          ),
          if (_type == WorkoutType.strength) ...[
            for (final (e, ex) in _exercises.indexed)
              GroupedSection(
                header: ExerciseLibrary.nameOf(ex.exerciseId),
                hasLeading: false,
                children: [
                  for (final (s, set) in ex.sets.indexed)
                    _SetEditor(
                      key: ValueKey('$e-$s-${ex.sets.length}'),
                      number: s + 1,
                      set: set,
                      onChanged: (v) => _setSets(e, [...ex.sets]..[s] = v),
                      onDelete: ex.sets.length > 1
                          ? () => _setSets(e, [...ex.sets]..removeAt(s))
                          : null,
                    ),
                  InfoRow(
                    title: 'Add Set',
                    titleColor: context.tint,
                    onTap: () => _setSets(e, [
                      ...ex.sets,
                      ex.sets.last.copyWith(done: true),
                    ]),
                  ),
                  InfoRow(
                    title: 'Remove Exercise',
                    titleColor: context.destructive,
                    onTap: () => setState(
                      () => _exercises = [..._exercises]..removeAt(e),
                    ),
                  ),
                ],
              ),
            GroupedSection(
              hasLeading: false,
              children: [
                InfoRow(
                  title: 'Add Exercise',
                  titleColor: context.tint,
                  onTap: _addExercise,
                ),
              ],
            ),
          ],
          GroupedSection(
            header: 'Notes',
            hasLeading: false,
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: CupertinoTextField.borderless(
                  controller: _notes,
                  placeholder: tr('How did it go?'),
                  maxLines: 4,
                  minLines: 2,
                  maxLength: 500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c,
    String unit, {
    bool decimal = false,
    String placeholder = '0',
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Row(
      children: [
        Text(label, style: context.body),
        Expanded(
          child: CupertinoTextField.borderless(
            controller: c,
            textAlign: TextAlign.end,
            placeholder: placeholder,
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            inputFormatters: numberInput(decimal: decimal),
          ),
        ),
        Text(unit, style: context.body.copyWith(color: context.secondaryLabel)),
      ],
    ),
  );
}

class _SetEditor extends StatefulWidget {
  const _SetEditor({
    super.key,
    required this.number,
    required this.set,
    required this.onChanged,
    required this.onDelete,
  });

  final int number;
  final SetLog set;
  final ValueChanged<SetLog> onChanged;
  final VoidCallback? onDelete;

  @override
  State<_SetEditor> createState() => _SetEditorState();
}

class _SetEditorState extends State<_SetEditor> {
  late final _kg = TextEditingController(
    text: formatWeightInput(widget.set.weightKg),
  );
  late final _reps = TextEditingController(text: '${widget.set.reps}');

  @override
  void didUpdateWidget(_SetEditor old) {
    super.didUpdateWidget(old);
    // Rows are keyed by position, so after a removal this row may now show
    // another set: bring the fields in line, leaving text that already
    // means the same value (such as "8." while typing) alone.
    final kg = Units.weightIn(
      double.tryParse(_kg.text.replaceAll(',', '.')) ?? 0,
    );
    if ((kg - widget.set.weightKg).abs() > 0.05) {
      _kg.text = formatWeightInput(widget.set.weightKg);
    }
    if ((int.tryParse(_reps.text) ?? 0) != widget.set.reps) {
      _reps.text = '${widget.set.reps}';
    }
  }

  @override
  void dispose() {
    _kg.dispose();
    _reps.dispose();
    super.dispose();
  }

  void _changed() => widget.onChanged(
    widget.set.copyWith(
      weightKg: Units.weightIn(
        double.tryParse(_kg.text.replaceAll(',', '.')) ?? 0,
      ).clamp(0, 1000).toDouble(),
      reps: (int.tryParse(_reps.text) ?? 0).clamp(0, 999),
    ),
  );

  @override
  Widget build(BuildContext context) {
    Widget box(
      TextEditingController c,
      String suffix, {
      bool decimal = false,
    }) => SizedBox(
      width: 88,
      child: CupertinoTextField(
        controller: c,
        textAlign: TextAlign.center,
        suffix: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(suffix),
        ),
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: numberInput(decimal: decimal),
        onChanged: (_) => _changed(),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('${widget.number}', style: context.headline),
          ),
          box(_kg, Units.weightUnit, decimal: true),
          const SizedBox(width: 8),
          box(_reps, 'reps'),
          const Spacer(),
          if (widget.onDelete != null)
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size.square(AppTheme.minTapTarget),
              onPressed: widget.onDelete,
              child: Icon(
                Icons.remove_circle_outline_rounded,
                color: context.destructive,
                semanticLabel: tr('Remove set'),
              ),
            ),
        ],
      ),
    );
  }
}
