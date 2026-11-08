import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/widgets/number_input.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/motion.dart';

/// Weight in the user's units, without a needless ".0".
String formatWeightInput(double kg) {
  final v = double.parse(Units.weightOut(kg).toStringAsFixed(1));
  return v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
}

/// Column sizes shared by the set table's header and its rows, so the
/// labels sit right above their values. The tap targets are fixed; last
/// time, weight and reps split the rest, so wide screens don't leave a gap.
abstract final class SetColumns {
  static const number = 40.0;
  static const effort = 44.0;
  static const done = 44.0;
  static const previousFlex = 4;
  static const weightFlex = 4;
  static const amountFlex = 3;
}

/// One set: number (tap to change its type), previous result, weight and
/// reps (or seconds), optional effort, and the done tick. Swipe left to
/// delete, right to copy.
class SetRow extends StatefulWidget {
  const SetRow({
    super.key,
    required this.number,
    required this.set,
    required this.previous,
    required this.color,
    required this.timed,
    required this.effort,
    required this.onChanged,
    required this.onToggle,
    required this.onCopy,
    required this.onDelete,
    this.active = false,
  });

  /// Working-set number (warm-ups show "W" instead).
  final int number;
  final SetLog set;
  final SetLog? previous;
  final Color color;
  final bool timed;
  final EffortMode effort;
  final ValueChanged<SetLog> onChanged;
  final VoidCallback onToggle;
  final VoidCallback onCopy;
  final VoidCallback? onDelete;

  /// The set to do next: outlined so it matches the card above.
  final bool active;

  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  late final _kg = TextEditingController(
    text: formatWeightInput(widget.set.weightKg),
  );
  late final _reps = TextEditingController(text: '${_amount(widget.set)}');

  int _amount(SetLog s) => widget.timed ? (s.seconds ?? 0) : s.reps;

  @override
  void didUpdateWidget(SetRow old) {
    super.didUpdateWidget(old);
    // Rows are reused by position: show the set now in this place.
    final shown = double.tryParse(_kg.text.replaceAll(',', '.')) ?? 0;
    if ((shown - Units.weightOut(widget.set.weightKg)).abs() > 0.05) {
      _kg.text = formatWeightInput(widget.set.weightKg);
    }
    if ((int.tryParse(_reps.text) ?? 0) != _amount(widget.set)) {
      _reps.text = '${_amount(widget.set)}';
    }
  }

  @override
  void dispose() {
    _kg.dispose();
    _reps.dispose();
    super.dispose();
  }

  void _changed() {
    final kg = Units.weightIn(
      double.tryParse(_kg.text.replaceAll(',', '.')) ?? 0,
    ).clamp(0, 1000).toDouble();
    final n = (int.tryParse(_reps.text) ?? 0).clamp(0, 9999);
    widget.onChanged(
      widget.timed
          ? widget.set.copyWith(weightKg: kg, seconds: n)
          : widget.set.copyWith(weightKg: kg, reps: n),
    );
  }

  Future<void> _pickType() async {
    final type = await showCupertinoModalPopup<SetType>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Set Type'),
        actions: [
          for (final t in SetType.values)
            CupertinoActionSheetAction(
              isDefaultAction: t == widget.set.type,
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
    if (type != null) widget.onChanged(widget.set.copyWith(type: type));
  }

  Future<void> _pickEffort() async {
    final rir = widget.effort == EffortMode.rir;
    // RPE 6–10 in halves; shown as RIR (reps left) when chosen.
    final values = [for (var v = 6.0; v <= 10; v += 0.5) v];
    String label(double rpe) => rir
        ? '${_half(10 - rpe)} RIR · ${_effortWords(rpe)}'
        : 'RPE ${_half(rpe)} · ${_effortWords(rpe)}';
    final picked = await showCupertinoModalPopup<double>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(rir ? 'Reps in Reserve' : 'Effort (RPE)'),
        actions: [
          for (final v in values.reversed)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, v),
              child: Text(label(v)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (picked != null) widget.onChanged(widget.set.copyWith(rpe: picked));
  }

  /// Whole numbers without a decimal, halves with one.
  static String _half(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1);

  static String _effortWords(double rpe) => switch (rpe) {
    >= 10 => 'Max effort',
    >= 9 => '1 rep left',
    >= 8 => '2 reps left',
    >= 7 => '3 reps left',
    _ => 'Easy',
  };

  static Color _effortColor(double rpe) => switch (rpe) {
    >= 9.5 => Palette.red,
    >= 8.5 => Palette.orange,
    >= 7.5 => Palette.yellow,
    _ => Palette.green,
  };

  @override
  Widget build(BuildContext context) {
    final s = widget.set;
    final done = s.done;
    final prev = widget.previous;
    final badge = s.type == SetType.normal ? '${widget.number}' : s.type.badge;
    final badgeColor = switch (s.type) {
      SetType.warmup => Palette.yellow,
      SetType.drop => Palette.purple,
      SetType.failure => Palette.red,
      SetType.normal => context.labelColor,
    };
    Widget field(TextEditingController c, {bool decimal = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: CupertinoTextField(
        controller: c,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: numberInput(decimal: decimal),
        style: TextStyle(color: context.labelColor),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: context.fillColor,
          borderRadius: BorderRadius.circular(8),
        ),
        onChanged: (_) => _changed(),
      ),
    );
    final row = AnimatedContainer(
      duration: Motion.fast,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: ShapeDecoration(
        color: done ? widget.color.withValues(alpha: 0.16) : null,
        shape: AppTheme.squircle(
          10,
          side: widget.active && !done
              ? BorderSide(color: widget.color.withValues(alpha: 0.6))
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _pickType,
              child: SizedBox(
                width: SetColumns.number,
                height: AppTheme.minTapTarget,
                child: Center(
                  child: Text(
                    badge,
                    semanticsLabel:
                        '${s.type.label} ${widget.number}. Tap to change type',
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.w700,
                      fontFamily: AppTheme.textFamily,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: SetColumns.previousFlex,
            child: Padding(
              padding: const EdgeInsets.only(left: 4, right: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  prev == null
                      ? '—'
                      : widget.timed
                      ? '${prev.seconds ?? 0}s'
                      : '${formatWeightInput(prev.weightKg)}×${prev.reps}',
                  semanticsLabel: prev == null ? 'No previous set' : null,
                  style: context.footnote.copyWith(
                    color: context.secondaryLabel,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ),
          Expanded(
            flex: SetColumns.weightFlex,
            child: field(_kg, decimal: true),
          ),
          Expanded(flex: SetColumns.amountFlex, child: field(_reps)),
          if (widget.effort != EffortMode.off)
            Semantics(
              button: true,
              label: tr(
                s.rpe == null
                    ? 'Effort not set'
                    : widget.effort == EffortMode.rir
                    ? '${_half(10 - s.rpe!)} RIR'
                    : 'RPE ${_half(s.rpe!)}',
              ),
              onTap: _pickEffort,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _pickEffort,
                child: SizedBox(
                  width: SetColumns.effort,
                  height: AppTheme.minTapTarget,
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: ShapeDecoration(
                        color: s.rpe == null
                            ? context.fillColor
                            : _effortColor(s.rpe!).withValues(alpha: 0.3),
                        shape: AppTheme.squircle(8),
                      ),
                      child: Text(
                        s.rpe == null
                            ? '—'
                            : widget.effort == EffortMode.rir
                            ? _half(10 - s.rpe!)
                            : _half(s.rpe!),
                        style: context.footnote.copyWith(
                          color: s.rpe == null
                              ? context.secondaryLabel
                              : _effortColor(s.rpe!),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          SizedBox(
            width: SetColumns.done,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size.square(AppTheme.minTapTarget),
              onPressed: widget.onToggle,
              child: AnimatedSwitcher(
                duration: Motion.reduced(context) ? Duration.zero : Motion.fast,
                transitionBuilder: (c, a) =>
                    ScaleTransition(scale: a, child: c),
                child: Icon(
                  done
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  key: ValueKey(done),
                  color: done ? widget.color : context.secondaryLabel,
                  size: 28,
                  semanticLabel: done ? 'Set done' : 'Mark set done',
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return Dismissible(
      key: ValueKey('dismiss-${widget.key}'),
      direction: widget.onDelete == null
          ? DismissDirection.startToEnd
          : DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        color: context.resolve(Palette.blue),
        child: const Text(
          'Copy',
          style: TextStyle(color: CupertinoColors.white),
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: context.destructive,
        child: const Text(
          'Delete',
          style: TextStyle(color: CupertinoColors.white),
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          HapticFeedback.selectionClick();
          widget.onCopy();
          return false; // Copying keeps this row.
        }
        // Delete here rather than in onDismissed: rows are keyed by
        // position, so a dismissed row's collapsed state would otherwise
        // be reused by the set that moves into its place.
        widget.onDelete?.call();
        return false;
      },
      child: row,
    );
  }
}
