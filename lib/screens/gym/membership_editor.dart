import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/gym/card_code.dart';
import 'package:health_app/models/gym.dart';
import 'package:health_app/screens/food/barcode_scanner_screen.dart';
import 'package:health_app/screens/gym/gym_card.dart';
import 'package:health_app/screens/health/picker_sheet.dart';
import 'package:health_app/state/gym_store.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/log.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';

/// Add or edit the gym membership: the gym, member details, when it ends,
/// and the card's code, scanned from the card or typed in.
class MembershipEditor extends StatefulWidget {
  const MembershipEditor({super.key, required this.controller});

  final ScrollController controller;

  static Future<void> show(BuildContext context) => showCupertinoSheet<void>(
    context: context,
    scrollableBuilder: (context, controller) =>
        MembershipEditor(controller: controller),
  );

  @override
  State<MembershipEditor> createState() => _MembershipEditorState();
}

class _MembershipEditorState extends State<MembershipEditor> {
  late final GymMembership? _start = context.read<GymStore>().membership;
  late final _gym = TextEditingController(text: _start?.gym);
  late final _name = TextEditingController(text: _start?.memberName);
  late final _number = TextEditingController(text: _start?.memberNumber);
  late final _plan = TextEditingController(text: _start?.plan);
  late final _code = TextEditingController(text: _start?.code);
  late final _notes = TextEditingController(text: _start?.notes);
  final _codeFocus = FocusNode();
  late CardFormat _format = _start?.format ?? CardFormat.code128;
  late DateTime? _expires = _start?.expires;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // The preview follows the code as it's typed.
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_gym, _name, _number, _plan, _code, _notes]) {
      c.dispose();
    }
    _codeFocus.dispose();
    super.dispose();
  }

  GymMembership get _result => GymMembership(
    gym: _gym.text.trim(),
    memberName: _name.text.trim(),
    memberNumber: _number.text.trim(),
    plan: _plan.text.trim(),
    code: _code.text.trim(),
    format: _format,
    expires: _expires,
    notes: _notes.text.trim(),
  );

  Future<void> _save() async {
    if (_busy) return;
    final m = _result;
    final problem = m.gym.isEmpty
        ? 'Enter the gym\'s name.'
        : m.hasCode && !CardCode.canDraw(m.code, m.format)
        ? 'That code can\'t be shown as ${m.format.label}. Check it, or '
              'choose another format.'
        : null;
    if (problem != null) {
      HapticFeedback.heavyImpact();
      setState(() => _error = problem);
      return;
    }
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    HapticFeedback.mediumImpact();
    try {
      await context.read<GymStore>().saveMembership(m);
      navigator.pop();
    } on Object catch (e) {
      logError('Gym: could not save the membership: $e');
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Your membership couldn\'t be saved. Please try again.';
        });
      }
    }
  }

  Future<void> _delete() async {
    final store = context.read<GymStore>();
    final navigator = Navigator.of(context);
    final ok = await confirmDestructive(
      context,
      title: 'Remove Membership?',
      message: 'Its card is removed from this phone. Your visits are kept.',
      action: 'Remove',
    );
    if (!ok) return;
    try {
      await store.saveMembership(null);
      navigator.pop();
    } on Object catch (e) {
      logError('Gym: could not remove the membership: $e');
      if (mounted) {
        setState(() => _error = 'It couldn\'t be removed. Please try again.');
      }
    }
  }

  /// Reads the code off the membership card with the camera.
  Future<void> _scan() async {
    final found = await Navigator.of(context).push<(String, CardFormat)>(
      AppRoute<(String, CardFormat)>(
        fullscreenDialog: true,
        builder: (_) => BarcodeScannerScreen<(String, CardFormat)>(
          formats: CardCode.scannable,
          prompt: 'Point at your membership card',
          hint: 'Its barcode or QR code is saved to scan in with.',
          manualLabel: 'Type the Code',
          resolve: (context, code) async {
            final value = code.rawValue;
            final format = CardCode.fromScanned(code.format);
            if (value == null || value.isEmpty || format == null) return null;
            if (CardCode.canDraw(value, format)) return (value, format);
            // Read, but not drawable as read (e.g. a check digit the
            // drawing adds itself): Code 128 shows any text.
            if (CardCode.canDraw(value, CardFormat.code128)) {
              return (value, CardFormat.code128);
            }
            return null;
          },
          // Closes the camera for the code field.
          manual: (context) async => ('', _format),
        ),
      ),
    );
    if (found == null || !mounted) return;
    final (code, format) = found;
    if (code.isEmpty) {
      _codeFocus.requestFocus();
      return;
    }
    setState(() {
      _code.text = code;
      _format = format;
      _error = null;
      if (_number.text.trim().isEmpty) _number.text = code;
    });
  }

  Future<void> _pickFormat() async {
    final format = await pickFromSheet(
      context,
      title: 'Code Format',
      message:
          'Scanning the card picks this for you. Choose the one printed on '
          'the card if it doesn\'t scan.',
      options: CardFormat.values,
      label: (f) => f.label,
      current: _format,
    );
    if (format != null) setState(() => _format = format);
  }

  Future<void> _pickExpiry() async {
    final today = context.read<HealthStore>().today;
    var picked = _expires ?? DateTime(today.year + 1, today.month, today.day);
    final ok = await showPickerSheet(
      context,
      doneLabel: 'Done',
      picker: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.date,
        initialDateTime: picked,
        minimumYear: today.year - 5,
        maximumYear: today.year + 20,
        onDateTimeChanged: (d) => picked = d,
      ),
    );
    if (ok) setState(() => _expires = picked);
  }

  Widget _field(
    TextEditingController c,
    String placeholder, {
    int max = 60,
    TextCapitalization caps = TextCapitalization.words,
    FocusNode? focus,
  }) => CupertinoTextField.borderless(
    controller: c,
    focusNode: focus,
    placeholder: placeholder,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    textCapitalization: caps,
    maxLength: max,
  );

  @override
  Widget build(BuildContext context) {
    final editing = _start != null;
    final error = _error;
    final preview = _result;
    final expires = _expires;
    final drawable = CardCode.canDraw(preview.code, preview.format);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        middle: Text(editing ? 'Edit Membership' : 'Add Membership'),
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
              _field(_gym, 'Gym (e.g. Iron Works Downtown)'),
              _field(_name, 'Member Name'),
              _field(
                _number,
                'Member Number',
                caps: TextCapitalization.characters,
              ),
              _field(_plan, 'Plan (e.g. Monthly, Off-Peak)'),
            ],
          ),
          GroupedSection(
            header: 'Card',
            hasLeading: false,
            footer:
                'Scan the barcode or QR code on your membership card or in '
                'your gym\'s app. At the gym, Check In shows it full screen, '
                'bright enough for their scanner.',
            children: [
              CupertinoListTile(
                leading: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: context.tint,
                ),
                title: Text(
                  preview.hasCode ? 'Scan Again' : 'Scan Card',
                  style: TextStyle(color: context.tint),
                ),
                onTap: _scan,
              ),
              _field(
                _code,
                'Or type the code',
                max: 200,
                caps: TextCapitalization.characters,
                focus: _codeFocus,
              ),
              InfoRow(
                title: 'Format',
                value: _format.label,
                chevron: true,
                onTap: _pickFormat,
              ),
              if (preview.hasCode)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: drawable
                      ? Center(child: CardBarcode(membership: preview))
                      : Text(
                          'This code can\'t be shown as ${_format.label}. '
                          'Choose another format.',
                          style: context.footnote.copyWith(
                            color: context.destructive,
                          ),
                        ),
                ),
            ],
          ),
          GroupedSection(
            header: 'Membership Ends',
            hasLeading: false,
            children: [
              CupertinoListTile(
                title: const Text('Ends'),
                trailing: CupertinoSwitch(
                  value: expires != null,
                  onChanged: (on) async {
                    if (on) {
                      await _pickExpiry();
                    } else {
                      setState(() => _expires = null);
                    }
                  },
                ),
              ),
              if (expires != null)
                InfoRow(
                  title: 'Valid Until',
                  value: DateFormat.yMMMd().format(expires),
                  chevron: true,
                  onTap: _pickExpiry,
                ),
            ],
          ),
          GroupedSection(
            hasLeading: false,
            children: [
              _field(
                _notes,
                'Notes (locker, PIN, front desk number)',
                max: 300,
                caps: TextCapitalization.sentences,
              ),
            ],
          ),
          if (editing)
            GroupedSection(
              hasLeading: false,
              children: [
                CupertinoListTile(
                  title: Text(
                    'Remove Membership',
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
}
