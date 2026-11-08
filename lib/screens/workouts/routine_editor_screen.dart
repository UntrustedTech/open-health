import 'dart:io';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/export/routine_share.dart';
import 'package:health_app/export/share_files.dart';
import 'package:health_app/models/exercise_library.dart';
import 'package:health_app/screens/workouts/exercise_library_screen.dart';
import 'package:health_app/screens/workouts/routine_item_sheet.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';
import 'package:health_app/utils/log.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/exercise_clip.dart';
import 'package:health_app/widgets/ios.dart';

/// Create or edit a strength routine.
class RoutineEditorScreen extends StatefulWidget {
  const RoutineEditorScreen({super.key, this.routine});

  final Routine? routine;

  static Future<void> open(BuildContext context, {Routine? routine}) =>
      Navigator.of(context, rootNavigator: true).push(
        AppRoute<void>(
          fullscreenDialog: true,
          builder: (_) => RoutineEditorScreen(routine: routine),
        ),
      );

  @override
  State<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends State<RoutineEditorScreen> {
  late final _name = TextEditingController(text: widget.routine?.name ?? '');
  late List<RoutineItem> _items = List.of(widget.routine?.items ?? const []);

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

  bool get _valid => _name.text.trim().isNotEmpty && _items.isNotEmpty;

  Future<void> _add() async {
    final id = await ExerciseLibraryScreen.pick(context);
    if (id != null && mounted) {
      setState(() => _items = [..._items, RoutineItem(id)]);
    }
  }

  /// Fixed for this editor, so saving twice updates one routine.
  late final _id =
      widget.routine?.id ?? 'r${DateTime.now().microsecondsSinceEpoch}';

  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    _saving = true;
    final routine = Routine(id: _id, name: _name.text.trim(), items: _items);
    try {
      await context.read<WorkoutStore>().saveRoutine(routine);
      if (mounted) Navigator.of(context).pop();
    } finally {
      _saving = false;
    }
  }

  /// Shares the routine as a file friends can import, or as a PDF.
  Future<void> _share({required bool pdf}) async {
    final routine = Routine(
      id: widget.routine?.id ?? 'shared',
      name: _name.text.trim(),
      items: _items,
    );
    final safe = routine.name.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
    try {
      final dir = await ShareFiles.prepare();
      final file = File(
        '${dir.path}/${safe.isEmpty ? 'routine' : safe}.${pdf ? 'pdf' : 'json'}',
      );
      if (pdf) {
        await file.writeAsBytes(
          await routineToPdf(routine, nameOf: ExerciseLibrary.nameOf),
        );
      } else {
        await file.writeAsString(
          routineToJson(routine, nameOf: ExerciseLibrary.nameOf),
        );
      }
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: routine.name),
      );
    } on Exception catch (e) {
      logError('Routine share failed: $e');
    }
  }

  Future<void> _delete() async {
    final r = widget.routine;
    if (r == null) return;
    final ok = await confirmDestructive(
      context,
      message: 'Delete "${r.name}"?',
      action: 'Delete Routine',
    );
    if (!ok || !mounted) return;
    await context.read<WorkoutStore>().deleteRoutine(r.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        middle: Text(widget.routine == null ? 'New Routine' : 'Edit Routine'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _valid ? _save : null,
          child: const Text(
            'Save',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      child: PageList(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.margin,
          12,
          AppTheme.margin,
          32,
        ),
        children: [
          CupertinoTextField(
            controller: _name,
            placeholder: tr('Routine Name'),
            padding: const EdgeInsets.all(14),
            textCapitalization: TextCapitalization.words,
            decoration: BoxDecoration(
              color: context.cardBackground,
              borderRadius: context.cardBorderRadius(AppTheme.listRadius),
            ),
          ),
          GroupedSection(
            header: 'Exercises',
            footer: 'Swipe left to remove an exercise.',
            hasLeading: false,
            children: [
              for (final (i, it) in _items.indexed)
                Dismissible(
                  key: ObjectKey(it),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: context.destructive,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: CupertinoColors.white),
                    ),
                  ),
                  onDismissed: (_) =>
                      setState(() => _items = [..._items]..removeAt(i)),
                  child: CupertinoListTile(
                    leading: ExerciseThumb(exerciseId: it.exerciseId),
                    leadingSize: 44,
                    title: Text(ExerciseLibrary.nameOf(it.exerciseId)),
                    subtitle: Text(RoutineItemSheet.summary(it)),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () async {
                      final updated = await RoutineItemSheet.show(context, it);
                      if (updated != null && mounted) {
                        setState(() => _items = [..._items]..[i] = updated);
                      }
                    },
                  ),
                ),
              InfoRow(
                title: 'Add Exercise',
                titleColor: context.tint,
                onTap: _add,
              ),
            ],
          ),
          if (_valid)
            GroupedSection(
              header: 'Share',
              hasLeading: false,
              children: [
                InfoRow(
                  title: 'Share as File',
                  titleColor: context.tint,
                  onTap: () => _share(pdf: false),
                ),
                InfoRow(
                  title: 'Share as PDF',
                  titleColor: context.tint,
                  onTap: () => _share(pdf: true),
                ),
              ],
            ),
          if (widget.routine != null)
            GroupedSection(
              hasLeading: false,
              children: [
                InfoRow(
                  title: 'Delete Routine',
                  titleColor: context.destructive,
                  onTap: _delete,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
