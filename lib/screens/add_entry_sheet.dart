import 'dart:async';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/widgets/number_input.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';

/// iOS page sheet for manually logging a value.
class AddEntrySheet extends StatefulWidget {
  const AddEntrySheet({super.key, required this.type});

  final MetricType type;

  static Future<void> show(BuildContext context, MetricType type) =>
      showCupertinoSheet<void>(
        context: context,
        scrollableBuilder: (context, _) => AddEntrySheet(type: type),
      );

  /// Lets the user choose a metric first, then shows the form in the same
  /// sheet.
  static Future<void> pickMetricAndShow(BuildContext context) =>
      showCupertinoSheet<void>(
        context: context,
        useNestedNavigation: true,
        scrollableBuilder: (context, controller) =>
            _MetricPicker(controller: controller),
      );

  @override
  State<AddEntrySheet> createState() => _AddEntrySheetState();
}

class _MetricPicker extends StatelessWidget {
  const _MetricPicker({required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        // Sheets don't morph the title from the page below, as on iOS;
        // every bar shares one hero tag, so it would fly into the sheet.
        transitionBetweenRoutes: false,
        automaticallyImplyLeading: false,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => CupertinoSheetRoute.popSheet(context),
          child: const Text('Cancel'),
        ),
        middle: const Text('Add Data'),
      ),
      child: PageList(
        controller: controller,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.margin),
        children: [
          GroupedSection(
            children: [
              // Blood pressure is one form for both numbers.
              for (final t in MetricType.values)
                if (t != MetricType.bloodPressureDiastolic)
                  CupertinoListTile(
                    leading: IconTile(icon: t.icon, color: t.color),
                    title: Text(_titleOf(t)),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => Navigator.of(context).push(
                      AppRoute<void>(builder: (_) => AddEntrySheet(type: t)),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Blood pressure is logged as one reading of two numbers.
bool _isBloodPressure(MetricType t) =>
    t == MetricType.bloodPressureSystolic ||
    t == MetricType.bloodPressureDiastolic;

String _titleOf(MetricType t) =>
    _isBloodPressure(t) ? 'Blood Pressure' : t.label;

class _AddEntrySheetState extends State<AddEntrySheet> {
  final _value = TextEditingController();
  final _diastolic = TextEditingController();
  final _note = TextEditingController();
  final _valueFocus = FocusNode();
  late DateTime _date = context.read<HealthStore>().now;
  bool _showPicker = false;
  bool _submitted = false;
  String? _error;

  MetricType get type => widget.type;

  @override
  void initState() {
    super.initState();
    _value.addListener(() => setState(() => _error = null));
    _diastolic.addListener(() => setState(() => _error = null));
  }

  bool get _bp => _isBloodPressure(type);

  /// For blood pressure, [_value] is systolic.
  MetricType get _first => _bp ? MetricType.bloodPressureSystolic : type;

  @override
  void dispose() {
    _diastolic.dispose();
    _value.dispose();
    _note.dispose();
    _valueFocus.dispose();
    super.dispose();
  }

  /// The typed value, converted to the stored (metric) unit.
  double? get _parsed => _parse(_value, _first);

  static double? _parse(TextEditingController c, MetricType t) =>
      switch (double.tryParse(c.text.replaceAll(',', '.'))) {
        final v? => Units.fromDisplay(t, v),
        null => null,
      };

  /// A limit in the units being typed (hours for sleep, not "8 hr").
  String _plain(double v) =>
      type.isDuration ? '${v.round()}' : formatValue(type, v);

  void _save() {
    if (_submitted) return;
    if (_bp) return _saveBloodPressure();
    final v = _parsed;
    if (v == null || v < type.min || v > type.max) {
      HapticFeedback.heavyImpact();
      setState(
        () => _error =
            'Enter a value between ${_plain(type.min)} '
            'and ${_plain(type.max)}.',
      );
      return;
    }
    _submitted = true;
    HapticFeedback.mediumImpact();
    // The store updates in memory immediately and saves in the background
    // (failures surface as a banner), so the sheet can close right away.
    unawaited(
      context.read<HealthStore>().addEntry(
        type,
        v,
        date: _date,
        note: _note.text,
      ),
    );
    CupertinoSheetRoute.popSheet(context);
  }

  /// Logs [ml] of water at once, from a quick-add button.
  void _addWater(double ml) {
    if (_submitted) return;
    _submitted = true;
    HapticFeedback.mediumImpact();
    unawaited(
      context.read<HealthStore>().addEntry(
        type,
        ml,
        date: _date,
        note: _note.text,
      ),
    );
    CupertinoSheetRoute.popSheet(context);
  }

  /// Quick-add sizes in the user's units: label and millilitres.
  static List<(String, double)> get waterSizes => Units.imperial
      ? const [
          ('8 fl oz', 8 * Units.mlPerFlOz),
          ('16 fl oz', 16 * Units.mlPerFlOz),
          ('1 gal', 128 * Units.mlPerFlOz),
        ]
      : const [('250 ml', 250), ('500 ml', 500), ('1 L', 1000)];

  void _saveBloodPressure() {
    const sysType = MetricType.bloodPressureSystolic;
    const diaType = MetricType.bloodPressureDiastolic;
    final sys = _parse(_value, sysType);
    final dia = _parse(_diastolic, diaType);
    bool ok(double? v, MetricType t) => v != null && v >= t.min && v <= t.max;
    if (!ok(sys, sysType) || !ok(dia, diaType) || dia! >= sys!) {
      HapticFeedback.heavyImpact();
      setState(
        () => _error =
            'Enter systolic (${sysType.min.round()}–${sysType.max.round()}) '
            'above diastolic (${diaType.min.round()}–'
            '${diaType.max.round()}).',
      );
      return;
    }
    _submitted = true;
    HapticFeedback.mediumImpact();
    final store = context.read<HealthStore>();
    unawaited(() async {
      await store.addEntry(sysType, sys, date: _date, note: _note.text);
      await store.addEntry(diaType, dia, date: _date, note: _note.text);
    }());
    CupertinoSheetRoute.popSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final now = context.read<HealthStore>().now;
    final unit = type.isDuration ? 'hr' : Units.unitFor(type);
    final canPop = Navigator.of(context).canPop();

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        // Sheets don't morph the title from the page below, as on iOS;
        // every bar shares one hero tag, so it would fly into the sheet.
        transitionBetweenRoutes: false,
        automaticallyImplyLeading: canPop,
        leading: canPop
            ? null
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => CupertinoSheetRoute.popSheet(context),
                child: const Text('Cancel'),
              ),
        middle: Text(_titleOf(type)),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _value.text.isEmpty || (_bp && _diastolic.text.isEmpty)
              ? null
              : _save,
          child: const Text(
            'Add',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      child: PageList(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.margin),
        children: [
          if (type == MetricType.water)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, ml) in waterSizes)
                    _QuickAdd(
                      label: label,
                      spoken: tr('Add $label'),
                      color: context.resolve(type.color),
                      onTap: () => _addWater(ml),
                    ),
                  _QuickAdd(
                    label: tr('Custom'),
                    spoken: tr('Custom amount'),
                    color: context.resolve(type.color),
                    onTap: () => _valueFocus.requestFocus(),
                  ),
                ],
              ),
            ),
          GroupedSection(
            hasLeading: false,
            footer: _error,
            children: [
              InfoRow(
                title: 'Date',
                value:
                    '${DateFormat.MMMd().format(_date)}, ${formatTime(_date)}',
                onTap: () => setState(() => _showPicker = !_showPicker),
              ),
              if (_showPicker)
                SizedBox(
                  height: 216,
                  child: CupertinoDatePicker(
                    initialDateTime: _date,
                    maximumDate: now,
                    minimumDate: DateTime(2000),
                    onDateTimeChanged: (d) => setState(() => _date = d),
                  ),
                ),
              _FieldRow(
                label: _bp ? 'mmHg' : unit,
                trailingLabel: true,
                child: CupertinoTextField.borderless(
                  controller: _value,
                  focusNode: _valueFocus,
                  // Water opens on its quick-add buttons instead.
                  autofocus: type != MetricType.water,
                  textAlign: TextAlign.end,
                  placeholder: _bp ? 'Systolic (top)' : 'Value',
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: Units.decimalsFor(type) > 0,
                  ),
                  inputFormatters: numberInput(
                    decimal: Units.decimalsFor(type) > 0,
                  ),
                  onSubmitted: (_) => _save(),
                ),
              ),
              if (_bp)
                _FieldRow(
                  label: 'mmHg',
                  trailingLabel: true,
                  child: CupertinoTextField.borderless(
                    controller: _diastolic,
                    textAlign: TextAlign.end,
                    placeholder: tr('Diastolic (bottom)'),
                    keyboardType: TextInputType.number,
                    inputFormatters: numberInput(decimal: false),
                    onSubmitted: (_) => _save(),
                  ),
                ),
              _FieldRow(
                label: 'Note',
                child: CupertinoTextField.borderless(
                  controller: _note,
                  maxLength: 120,
                  textAlign: TextAlign.end,
                  placeholder: tr('Optional'),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A rounded button that adds a set amount (or opens the custom field).
class _QuickAdd extends StatelessWidget {
  const _QuickAdd({
    required this.label,
    required this.spoken,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String spoken;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: spoken,
    excludeSemantics: true,
    child: CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      minimumSize: const Size(0, AppTheme.minTapTarget),
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(22),
      onPressed: onTap,
      child: Text(
        label,
        style: context.subheadline.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

/// A form row: label on one side, text field on the other.
class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.child,
    this.trailingLabel = false,
  });

  final String label;
  final Widget child;

  /// Puts the label (a unit) after the field: "[  8,421] steps".
  final bool trailingLabel;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: context.body.copyWith(
        color: trailingLabel ? context.secondaryLabel : null,
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppTheme.minTapTarget),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (!trailingLabel) text,
            Expanded(child: child),
            if (trailingLabel) ...[const SizedBox(width: 6), text],
          ],
        ),
      ),
    );
  }
}
