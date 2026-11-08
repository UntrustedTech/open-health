import 'package:flutter/cupertino.dart' hide Text;
import 'package:provider/provider.dart';

import 'package:health_app/screens/health/picker_sheet.dart';
import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/state/exercise_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';
import 'package:health_app/widgets/ios.dart';

String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Create your own exercise.
class CustomExerciseSheet extends StatefulWidget {
  const CustomExerciseSheet({super.key, required this.controller});

  final ScrollController controller;

  /// Returns the new exercise, or null if cancelled.
  static Future<CatalogExercise?> show(BuildContext context) =>
      showCupertinoSheet<CatalogExercise>(
        context: context,
        scrollableBuilder: (context, controller) =>
            CustomExerciseSheet(controller: controller),
      );

  @override
  State<CustomExerciseSheet> createState() => _CustomExerciseSheetState();
}

class _CustomExerciseSheetState extends State<CustomExerciseSheet> {
  final _name = TextEditingController();
  String _bodyPart = 'chest';
  String _equipment = 'dumbbell';
  String _target = 'pectorals';
  bool _timed = false;
  bool _perSide = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final CatalogExercise e;
    try {
      e = await context.read<ExerciseStore>().addCustom(
        name: _name.text,
        bodyPart: _bodyPart,
        equipment: _equipment,
        target: _target,
        timed: _timed,
        perSide: _perSide,
      );
    } catch (_) {
      // Only a failure re-enables Save: after success the sheet is closing,
      // and a second tap would add the exercise twice.
      if (mounted) setState(() => _saving = false);
      rethrow;
    }
    if (mounted) Navigator.of(context).pop(e);
  }

  Future<void> _pick(
    String title,
    List<String> options,
    String current,
    ValueChanged<String> onPick,
  ) async {
    var index = options.indexOf(current).clamp(0, options.length - 1);
    final ok = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => Container(
        height: 300,
        color: context.cardBackground,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(child: Text(title, style: context.headline)),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Done'),
                  ),
                ],
              ),
              Expanded(
                child: WheelPicker(
                  initialItem: index,
                  onSelectedItemChanged: (i) => index = i,
                  children: [
                    for (final o in options) Center(child: Text(capitalize(o))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok ?? false) setState(() => onPick(options[index]));
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<ExerciseStore>().catalog;
    final targets = {for (final e in catalog.builtIn) e.target}.toList()
      ..sort();
    final equipment = {...catalog.equipmentTypes, 'other'}.toList()..sort();
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
        middle: const Text('New Exercise'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _name.text.trim().isEmpty || _saving ? null : _save,
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
          12,
          AppTheme.margin,
          32,
        ),
        children: [
          CupertinoTextField(
            controller: _name,
            placeholder: tr('Exercise Name'),
            autofocus: true,
            maxLength: 60,
            textCapitalization: TextCapitalization.words,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cardBackground,
              borderRadius: context.cardBorderRadius(AppTheme.listRadius),
            ),
          ),
          GroupedSection(
            hasLeading: false,
            children: [
              InfoRow(
                title: 'Body Part',
                value: capitalize(_bodyPart),
                chevron: true,
                onTap: () => _pick(
                  'Body Part',
                  catalog.bodyParts,
                  _bodyPart,
                  (v) => _bodyPart = v,
                ),
              ),
              InfoRow(
                title: 'Main Muscle',
                value: capitalize(_target),
                chevron: true,
                onTap: () =>
                    _pick('Main Muscle', targets, _target, (v) => _target = v),
              ),
              InfoRow(
                title: 'Equipment',
                value: capitalize(_equipment),
                chevron: true,
                onTap: () => _pick(
                  'Equipment',
                  equipment,
                  _equipment,
                  (v) => _equipment = v,
                ),
              ),
            ],
          ),
          GroupedSection(
            hasLeading: false,
            footer: 'Timed exercises log how long you hold (planks, hangs, carries).',
            children: [
              CupertinoListTile(
                title: const Text('Timed'),
                trailing: CupertinoSwitch(
                  value: _timed,
                  onChanged: (v) => setState(() => _timed = v),
                ),
              ),
              CupertinoListTile(
                title: const Text('Each Side Separately'),
                trailing: CupertinoSwitch(
                  value: _perSide,
                  onChanged: (v) => setState(() => _perSide = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
