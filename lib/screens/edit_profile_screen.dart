import 'dart:async';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/app_edition.dart';
import 'package:health_app/screens/health/picker_sheet.dart';
import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/user_profile.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/sync/health_sync_service.dart';
import 'package:health_app/sync/profile_fill.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/height_picker.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/utils/units.dart';

/// The profile, Medical ID and emergency contact, edited in the app's own
/// cards (so it follows the chosen style), presented modally with Cancel
/// and Done.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context, rootNavigator: true).push(
        AppRoute<void>(
          fullscreenDialog: true,
          builder: (_) => const EditProfileScreen(),
        ),
      );

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _bloodTypes = [
    '',
    'A+',
    'A−',
    'B+',
    'B−',
    'AB+',
    'AB−',
    'O+',
    'O−',
  ];
  static const _sexes = ['', 'Female', 'Male', 'Other'];

  late final UserProfile _initial = context.read<HealthStore>().profile;
  late final _name = TextEditingController(text: _initial.name);

  /// Centimetres, picked with the height wheels (feet and inches for
  /// imperial users).
  late double? _heightCm = _initial.heightCm;
  late final _allergies = TextEditingController(text: _initial.allergies);
  late final _conditions = TextEditingController(text: _initial.conditions);
  late final _medications = TextEditingController(text: _initial.medications);
  late final _emergencyName = TextEditingController(
    text: _initial.emergencyName,
  );
  late final _emergencyPhone = TextEditingController(
    text: _initial.emergencyPhone,
  );
  late DateTime? _birthDate = _initial.birthDate;
  // Values from elsewhere (a backup, an older version) are matched loosely
  // and otherwise kept as they are, never cleared by saving.
  late String _sex = _match(_sexes, _initial.sex);
  late String _bloodType = _match(
    _bloodTypes,
    _initial.bloodType.replaceAll('-', '−'),
  );

  static String _match(List<String> options, String value) =>
      options.firstWhere(
        (o) => o.toLowerCase() == value.trim().toLowerCase(),
        orElse: () => value.trim(),
      );
  bool _submitted = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _allergies,
      _conditions,
      _medications,
      _emergencyName,
      _emergencyPhone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The profile as edited so far.
  UserProfile _current() => UserProfile(
    name: _name.text.trim(),
    birthDate: _birthDate,
    sex: _sex,
    heightCm: _heightCm,
    bloodType: _bloodType,
    allergies: _allergies.text.trim(),
    conditions: _conditions.text.trim(),
    medications: _medications.text.trim(),
    emergencyName: _emergencyName.text.trim(),
    emergencyPhone: _emergencyPhone.text.trim(),
  );

  void _save() {
    if (_submitted) return;
    _submitted = true;
    HapticFeedback.mediumImpact();
    unawaited(context.read<HealthStore>().updateProfile(_current()));
    Navigator.of(context).pop();
  }

  bool _filling = false;

  /// Reads what Apple Health or Health Connect knows, shows it, and adds
  /// it to the editor once confirmed. Nothing is saved until Done.
  Future<void> _fill() async {
    if (_filling) return;
    final sync = context.read<HealthSyncService>();
    final source = sync.sourceName;
    setState(() => _filling = true);
    final facts = await sync.readProfile();
    if (!mounted) return;
    setState(() => _filling = false);
    if (facts == null) {
      await showMessage(
        context,
        title: "Couldn't Read $source",
        message: 'Make sure Health is allowed to read it, then try again.',
      );
      return;
    }
    final current = _current();
    final changes = profileChanges(current, facts);
    if (changes.isEmpty) {
      await showMessage(
        context,
        title: 'Nothing to Add',
        message: "$source has nothing that isn't already in your profile.",
      );
      return;
    }
    final replacing = changes.any((c) => c.replaces);
    final adding = changes.any((c) => !c.replaces);
    // true: replace what differs; false: only fill empty fields.
    final replace = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Add from $source?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in changes) Text('${tr(c.label)}: ${c.shown}'),
            if (replacing) ...[
              const SizedBox(height: 8),
              const Text('Replace changes values you entered.'),
            ],
          ],
        ),
        actions: [
          if (replacing && adding)
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Only Add Missing'),
            ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, replacing),
            child: Text(replacing ? 'Replace' : 'Add'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (replace == null || !mounted) return;
    final filled = fillProfile(current, facts, replace: replace);
    HapticFeedback.selectionClick();
    setState(() {
      _birthDate = filled.birthDate;
      _sex = _match(_sexes, filled.sex);
      _heightCm = filled.heightCm;
      _bloodType = _match(_bloodTypes, filled.bloodType.replaceAll('-', '−'));
    });
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    var picked = _birthDate ?? DateTime(now.year - 30, 1, 1);
    final done = await _showPicker(
      CupertinoDatePicker(
        mode: CupertinoDatePickerMode.date,
        initialDateTime: picked,
        minimumDate: DateTime(1900),
        maximumDate: now,
        onDateTimeChanged: (d) => picked = d,
      ),
      title: 'Birthday',
    );
    if (done && mounted) setState(() => _birthDate = picked);
  }

  Future<void> _pickOption(
    String title,
    List<String> options,
    String current,
    ValueChanged<String> onPicked,
  ) async {
    // A kept value that isn't one of the options can still be picked.
    if (!options.contains(current)) options = [...options, current];
    var index = options.indexOf(current).clamp(0, options.length - 1);
    final done = await _showPicker(
      WheelPicker(
        initialItem: index,
        onSelectedItemChanged: (i) => index = i,
        children: [
          for (final o in options)
            Center(child: Text(o.isEmpty ? 'Not Set' : o)),
        ],
      ),
      title: title,
    );
    if (done && mounted) setState(() => onPicked(options[index]));
  }

  Widget _fillSection() {
    final source = context.read<HealthSyncService>().sourceName;
    return GroupedSection(
      footer: defaultTargetPlatform == TargetPlatform.iOS
          ? 'Adds your birthday, sex, height and blood type from Apple '
                'Health. Nothing is saved until you tap Done.'
          : 'Adds your height from Health Connect. Nothing is saved until '
                'you tap Done.',
      children: [
        InfoRow(
          leading: const IconTile(
            icon: Icons.favorite_rounded,
            color: Palette.red,
          ),
          title: 'Fill from $source',
          titleColor: context.tint,
          trailing: _filling ? const CupertinoActivityIndicator() : null,
          onTap: _filling ? null : _fill,
        ),
      ],
    );
  }

  /// Shows [picker] in a bottom sheet titled [title], with a Done button.
  Future<bool> _showPicker(Widget picker, {String title = ''}) async {
    final done = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => Container(
        height: 300,
        decoration: ShapeDecoration(
          color: context.cardRaised,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(context.cardRadius(AppTheme.heroRadius)),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 4, 0),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: context.headline)),
                    CupertinoButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: picker),
            ],
          ),
        ),
      ),
    );
    return done ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final birth = _birthDate;
    final today = DateTime.now();
    final age = birth == null
        ? null
        : today.year -
              birth.year -
              ((today.month < birth.month ||
                      (today.month == birth.month && today.day < birth.day))
                  ? 1
                  : 0);
    return CupertinoPageScaffold(
      backgroundColor: context.groupedBackground,
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        backgroundColor: context.groupedBackground.withValues(alpha: 0.9),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        middle: const Text('Edit Profile'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _save,
          child: const Text(
            'Done',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const PageBackground(),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppTheme.margin,
                12,
                AppTheme.margin,
                32 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                _NameCard(controller: _name),
                _fillSection(),
                GroupedSection(
                  header: 'About You',
                  footer:
                      'Used to estimate calories, heart rate zones and your '
                      'healthy weight range.',
                  children: [
                    _pickerRow(
                      Icons.cake_rounded,
                      Palette.orange,
                      'Birthday',
                      birth == null
                          ? 'Not Set'
                          : '${DateFormat.yMMMd().format(birth)} · $age',
                      _pickBirthDate,
                    ),
                    _pickerRow(
                      Icons.person_rounded,
                      Palette.purple,
                      'Sex',
                      _sex.isEmpty ? 'Not Set' : _sex,
                      () => _pickOption('Sex', _sexes, _sex, (v) => _sex = v),
                    ),
                    _pickerRow(
                      Icons.height_rounded,
                      Palette.blue,
                      'Height',
                      switch (_heightCm) {
                        final cm? => Units.height(cm),
                        null => 'Not Set',
                      },
                      () async {
                        final cm = await pickHeight(context, _heightCm);
                        if (cm != null && mounted) {
                          setState(() => _heightCm = cm);
                        }
                      },
                    ),
                  ],
                ),
                GroupedSection(
                  header: 'Medical ID',
                  footer:
                      'Kept only on this phone, to show in an emergency. '
                      'Leave anything blank you\'d rather not add.',
                  children: [
                    _pickerRow(
                      Icons.water_drop_rounded,
                      Palette.red,
                      'Blood Type',
                      _bloodType.isEmpty ? 'Not Set' : _bloodType,
                      () => _pickOption(
                        'Blood Type',
                        _bloodTypes,
                        _bloodType,
                        (v) => _bloodType = v,
                      ),
                    ),
                    _FieldRow(
                      icon: Icons.warning_amber_rounded,
                      color: Palette.yellow,
                      label: 'Allergies',
                      controller: _allergies,
                      multiline: true,
                    ),
                    _FieldRow(
                      icon: Icons.healing_rounded,
                      color: Palette.pink,
                      label: 'Conditions',
                      controller: _conditions,
                      multiline: true,
                    ),
                    if (!kStoreEdition)
                      _FieldRow(
                        icon: Icons.medication_rounded,
                        color: Palette.green,
                        label: 'Medications',
                        controller: _medications,
                        multiline: true,
                      ),
                  ],
                ),
                GroupedSection(
                  header: 'Emergency Contact',
                  children: [
                    _FieldRow(
                      icon: Icons.contact_emergency_rounded,
                      color: Palette.teal,
                      label: 'Name',
                      controller: _emergencyName,
                      capitalization: TextCapitalization.words,
                    ),
                    _FieldRow(
                      icon: Icons.phone_rounded,
                      color: Palette.green,
                      label: 'Phone',
                      controller: _emergencyPhone,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickerRow(
    IconData icon,
    Color color,
    String label,
    String value,
    VoidCallback onTap,
  ) => InfoRow(
    leading: IconTile(icon: icon, color: color),
    title: label,
    value: value,
    chevron: true,
    onTap: onTap,
  );
}

/// The avatar, its initials following the name as it's typed, and the
/// name itself, large.
class _NameCard extends StatelessWidget {
  const _NameCard({required this.controller});

  final TextEditingController controller;

  static String _initials(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w.characters.first.toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    final tint = context.tint;
    return IosCard(
      tint: tint,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 14),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  tint,
                  Color.lerp(tint, const Color(0xFFFFFFFF), 0.45)!,
                  tint,
                ],
              ),
              boxShadow: [
                BoxShadow(color: tint.withValues(alpha: 0.35), blurRadius: 24),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.cardBackground,
              ),
              child: Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.labelColor,
                ),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    final initials = _initials(value.text);
                    return initials.isEmpty
                        ? Icon(
                            Icons.person_rounded,
                            size: 36,
                            color: context.onLabel,
                          )
                        : Text(
                            initials,
                            style: context.title2.copyWith(
                              color: context.onLabel,
                              fontWeight: FontWeight.w800,
                            ),
                          );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: controller,
            placeholder: tr('Your Name'),
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.words,
            maxLength: 60,
            style: context.title2.copyWith(fontWeight: FontWeight.w800),
            placeholderStyle: context.title2.copyWith(
              fontWeight: FontWeight.w800,
              color: context.tertiaryLabel,
            ),
            decoration: null,
          ),
          Text(
            'Tap your name to change it',
            style: context.caption1.copyWith(color: context.secondaryLabel),
          ),
        ],
      ),
    );
  }
}

/// A labelled text field in a section: on one line, or with the text
/// under the label when it can run to several.
class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.capitalization = TextCapitalization.sentences,
    this.multiline = false,
  });

  final IconData icon;
  final Color color;
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final field = CupertinoTextField(
      controller: controller,
      placeholder: tr('Not Set'),
      textAlign: multiline ? TextAlign.start : TextAlign.end,
      keyboardType: multiline ? TextInputType.multiline : keyboardType,
      textCapitalization: capitalization,
      minLines: 1,
      maxLines: multiline ? 4 : 1,
      maxLength: multiline ? 300 : 60,
      padding: EdgeInsets.zero,
      style: context.body.copyWith(
        color: multiline ? context.labelColor : context.secondaryLabel,
      ),
      placeholderStyle: context.body.copyWith(color: context.tertiaryLabel),
      decoration: null,
    );
    final title = Text(label, style: context.body);
    return Padding(
      // Lines up with the picker rows (CupertinoListTile's spacing).
      padding: const EdgeInsets.fromLTRB(20, 11, 14, 11),
      child: Row(
        crossAxisAlignment: multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          IconTile(icon: icon, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: multiline
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: title,
                      ),
                      field,
                    ],
                  )
                : Row(
                    children: [
                      title,
                      const SizedBox(width: 12),
                      Expanded(child: field),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
