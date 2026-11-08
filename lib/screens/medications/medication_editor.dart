import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/medication.dart';
import 'package:health_app/screens/health/picker_sheet.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/medication_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/ios.dart';

/// Add or edit a medication: name, dose, form, schedule and reminders.
class MedicationEditor extends StatefulWidget {
  const MedicationEditor({super.key, this.med, required this.controller});

  final Medication? med;
  final ScrollController controller;

  static Future<void> show(BuildContext context, {Medication? med}) =>
      showCupertinoSheet<void>(
        context: context,
        scrollableBuilder: (context, controller) =>
            MedicationEditor(med: med, controller: controller),
      );

  @override
  State<MedicationEditor> createState() => _MedicationEditorState();
}

class _MedicationEditorState extends State<MedicationEditor> {
  late final Medication _start =
      widget.med ??
      Medication(
        id: context.read<MedicationStore>().newId(),
        name: '',
        times: const [8 * 60],
        created: context.read<HealthStore>().now,
      );
  late final _name = TextEditingController(text: _start.name);
  late final _dose = TextEditingController(text: _start.dose);
  late final _notes = TextEditingController(text: _start.notes);
  late MedForm _form = _start.form;
  late List<DoseTime> _times = [..._start.times];
  late bool _asNeeded = _start.asNeeded;
  late Set<int> _days = {..._start.days};
  late int _color = _start.colorIndex;
  late bool _reminders = _start.reminders;

  /// Set while a save, delete or archive runs, so a double tap acts once.
  bool _busy = false;

  Future<void> _once(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _error;

  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _notes.dispose();
    super.dispose();
  }

  Medication get _result => _start.copyWith(
    name: _name.text.trim(),
    dose: _dose.text.trim(),
    form: _form,
    times: _asNeeded ? const [] : _times,
    days: _days.length == 7 ? const {} : _days,
    colorIndex: _color,
    notes: _notes.text.trim(),
    reminders: _reminders,
  );

  Future<void> _save() => _once(_saveNow);

  Future<void> _saveNow() async {
    if (_name.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() => _error = 'Enter a name.');
      return;
    }
    if (!_asNeeded && _times.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() => _error = 'Add a time, or choose As Needed.');
      return;
    }
    final store = context.read<MedicationStore>();
    final navigator = Navigator.of(context);
    HapticFeedback.mediumImpact();
    final allowed = await store.save(_result);
    navigator.pop();
    if (!allowed && mounted) {
      await showMessage(
        context,
        title: 'Reminders Are Off',
        message:
            'Allow notifications for Health in Settings to get medication '
            'reminders.',
      );
    }
  }

  Future<void> _addTime() async {
    var picked = DateTime(2000, 1, 1, 8);
    final ok = await showPickerSheet(
      context,
      doneLabel: 'Add',
      picker: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.time,
        initialDateTime: picked,
        minuteInterval: 5,
        onDateTimeChanged: (d) => picked = d,
      ),
    );
    if (!ok) return;
    final t = picked.hour * 60 + picked.minute;
    setState(() => _times = ({..._times, t}.toList()..sort()));
  }

  Future<void> _pickForm() async {
    final form = await pickFromSheet(
      context,
      title: 'Form',
      options: MedForm.values,
      label: (f) => f.label,
      current: _form,
    );
    if (form != null) setState(() => _form = form);
  }

  Future<void> _delete() => _once(_deleteNow);

  Future<void> _deleteNow() async {
    final store = context.read<MedicationStore>();
    final navigator = Navigator.of(context);
    final ok = await confirmDestructive(
      context,
      title: 'Delete ${_start.name}?',
      message: 'Its reminders and dose history will be deleted too.',
      action: 'Delete',
    );
    if (!ok) return;
    await store.delete(_start.id);
    navigator.pop();
  }

  Future<void> _toggleArchive() => _once(_toggleArchiveNow);

  Future<void> _toggleArchiveNow() async {
    final store = context.read<MedicationStore>();
    final navigator = Navigator.of(context);
    await store.save(_result.copyWith(archived: !_start.archived));
    navigator.pop();
  }

  Widget _field(TextEditingController c, String placeholder) =>
      CupertinoTextField.borderless(
        controller: c,
        placeholder: placeholder,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        textCapitalization: TextCapitalization.sentences,
        maxLength: placeholder == 'Notes' ? 300 : 60,
      );

  @override
  Widget build(BuildContext context) {
    final editing = widget.med != null;
    final green = context.resolve(Palette.green);
    final error = _error;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        middle: Text(editing ? 'Edit Medication' : 'New Medication'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _busy ? null : _save,
          child: const Text(
            'Save',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      child: PageList(
        controller: widget.controller,
        padding: const EdgeInsets.fromLTRB(
          AppTheme.margin,
          0,
          AppTheme.margin,
          32,
        ),
        children: [
          GroupedSection(
            hasLeading: false,
            footer: error,
            children: [
              _field(_name, 'Name (e.g. Vitamin D)'),
              _field(_dose, 'Dose (e.g. 1000 IU, 2 tablets)'),
              InfoRow(
                title: 'Form',
                value: _form.label,
                chevron: true,
                onTap: _pickForm,
              ),
            ],
          ),
          GroupedSection(
            header: 'Schedule',
            hasLeading: false,
            children: [
              CupertinoListTile(
                title: const Text('As Needed'),
                trailing: CupertinoSwitch(
                  value: _asNeeded,
                  onChanged: (v) => setState(() => _asNeeded = v),
                ),
              ),
              if (!_asNeeded) ...[
                for (final t in _times)
                  CupertinoListTile(
                    title: Text(formatDoseTime(t)),
                    trailing: CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size.square(AppTheme.minTapTarget),
                      onPressed: () =>
                          setState(() => _times = [..._times]..remove(t)),
                      child: Icon(
                        Icons.remove_circle_rounded,
                        color: context.destructive,
                        semanticLabel: tr('Remove ${formatDoseTime(t)}'),
                      ),
                    ),
                  ),
                CupertinoListTile(
                  title: Text(
                    'Add a Time',
                    style: TextStyle(color: context.tint),
                  ),
                  leading: Icon(Icons.add_circle_rounded, color: green),
                  onTap: _addTime,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      for (var d = 1; d <= 7; d++)
                        Expanded(child: _dayChip(context, d)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (!_asNeeded)
            GroupedSection(
              hasLeading: false,
              footer:
                  'Reminders include the medication\'s name. To hide them on '
                  'your lock screen, change it in your phone\'s notification '
                  'settings.',
              children: [
                CupertinoListTile(
                  title: const Text('Reminders'),
                  trailing: CupertinoSwitch(
                    value: _reminders,
                    onChanged: (v) => setState(() => _reminders = v),
                  ),
                ),
              ],
            ),
          GroupedSection(
            header: 'Colour',
            hasLeading: false,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  children: [
                    for (final (i, c) in medColors.indexed)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: i == _color,
                          label: 'Colour ${i + 1}',
                          onTap: () => setState(() => _color = i),
                          excludeSemantics: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => _color = i),
                            // The dot sits in a full-size tap area.
                            child: SizedBox(
                              height: AppTheme.minTapTarget,
                              child: Center(
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: context.resolve(c),
                                    shape: BoxShape.circle,
                                    border: i == _color
                                        ? Border.all(
                                            color: context.labelColor,
                                            width: 2.5,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          GroupedSection(
            hasLeading: false,
            children: [_field(_notes, 'Notes')],
          ),
          if (editing)
            GroupedSection(
              hasLeading: false,
              children: [
                CupertinoListTile(
                  title: Text(
                    _start.archived ? 'Restore Medication' : 'Archive',
                    style: TextStyle(color: context.tint),
                  ),
                  subtitle: _start.archived
                      ? null
                      : const Text('Stop reminders but keep its history'),
                  onTap: _toggleArchive,
                ),
                CupertinoListTile(
                  title: Text(
                    'Delete Medication',
                    style: TextStyle(color: context.destructive),
                  ),
                  onTap: _delete,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _dayChip(BuildContext context, int day) {
    // No days chosen means every day.
    final on = _days.isEmpty || _days.contains(day);
    final tint = context.tint;
    void toggle() => setState(() {
      final next = _days.isEmpty ? {1, 2, 3, 4, 5, 6, 7} : {..._days};
      if (!next.remove(day)) next.add(day);
      // At least one day; all seven means every day.
      if (next.isNotEmpty) _days = next.length == 7 ? {} : next;
    });
    return Semantics(
      button: true,
      selected: on,
      label: const [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ][day - 1],
      onTap: toggle,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: toggle,
        child: SizedBox(
          height: AppTheme.minTapTarget,
          child: Center(
            child: Container(
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? tint : context.fillColor,
                shape: BoxShape.circle,
              ),
              child: Text(
                _dayLetters[day - 1],
                style: context.subheadline.copyWith(
                  color: on ? context.onColor(tint) : context.labelColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
