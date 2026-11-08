import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/backup/auto_backup.dart';
import 'package:health_app/export/backup.dart';
import 'package:health_app/export/backup_builder.dart';
import 'package:health_app/export/backup_crypto.dart';
import 'package:health_app/export/backup_restorer.dart';
import 'package:health_app/export/csv_export.dart';
import 'package:health_app/export/routine_share.dart';
import 'package:health_app/export/share_files.dart';
import 'package:health_app/import/csv_formats.dart';
import 'package:health_app/import/food_csv.dart';
import 'package:health_app/import/importer.dart';
import 'package:health_app/import/name_matcher.dart';
import 'package:health_app/models/exercise_library.dart';
import 'package:health_app/models/food.dart';
import 'package:health_app/notifications/notification_controller.dart';
import 'package:health_app/screens/auto_backup_screen.dart';
import 'package:health_app/screens/backup_dialogs.dart';
import 'package:health_app/state/achievement_store.dart';
import 'package:health_app/state/cycle_store.dart';
import 'package:health_app/state/sleep_schedule_store.dart';
import 'package:health_app/state/program_store.dart';
import 'package:health_app/state/gym_store.dart';
import 'package:health_app/state/mood_store.dart';
import 'package:health_app/state/fasting_store.dart';
import 'package:health_app/state/exercise_store.dart';
import 'package:health_app/state/medication_store.dart';
import 'package:health_app/state/nutrition_store.dart';
import 'package:health_app/security/app_lock.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/utils/log.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/theme/app_theme.dart';

/// Back up and restore everything, export spreadsheets, and import
/// workouts and routines from other apps.
class DataTransferScreen extends StatefulWidget {
  const DataTransferScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(title: 'Backup', builder: (_) => const DataTransferScreen()),
  );

  @override
  State<DataTransferScreen> createState() => _DataTransferScreenState();
}

class _DataTransferScreenState extends State<DataTransferScreen> {
  bool _busy = false;

  /// Largest file accepted for import.
  static const _maxImportBytes = 20 * 1024 * 1024;

  Future<String?> _pickText(List<String> extensions) async {
    try {
      final file = await FilePicker.pickFile(allowedExtensions: extensions);
      if (file == null) return null;
      if ((await file.length() ?? 0) > _maxImportBytes) {
        if (mounted) {
          await showMessage(
            context,
            title: 'File Too Large',
            message: 'Health can import files up to 20 MB.',
          );
        }
        return null;
      }
      return utf8.decode(await file.readAsBytes(), allowMalformed: true);
    } on Exception catch (e) {
      logError('Import: could not read file: $e');
      if (mounted) {
        await showMessage(
          context,
          title: 'Couldn\'t Open File',
          message: 'Please try another file.',
        );
      }
      return null;
    } finally {
      // The picker may keep a copy in the cache: don't leave it behind.
      try {
        await FilePicker.clearTemporaryFiles();
      } on Exception catch (e) {
        logError('Import: could not clear picker files: $e');
      }
    }
  }

  Future<void> _importWorkouts() async {
    final text = await _pickText(['csv']);
    if (text == null || !mounted) return;
    setState(() => _busy = true);
    // Large exports take a moment: parse off the UI thread.
    final ParsedCsv parsed;
    try {
      parsed = await compute(parseWorkoutCsv, text);
    } on Exception catch (e) {
      logError('Import: could not parse CSV: $e');
      if (mounted) {
        await showMessage(
          context,
          title: "Couldn't Read File",
          message: "This CSV file couldn't be read. Nothing was changed.",
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (parsed.format == CsvFormat.unknown || parsed.workouts.isEmpty) {
      await showMessage(
        context,
        title: 'Unsupported File',
        message:
            'Health can import CSV exports from Strong, Hevy and FitNotes.',
      );
      return;
    }
    final exercises = context.read<ExerciseStore>();
    final matcher = NameMatcher(exercises.catalog);
    final names = {
      for (final w in parsed.workouts)
        for (final e in w.exercises) e.name,
    };
    final matched = {for (final n in names) n: matcher.match(n)?.id};
    final unmatched = [
      for (final e in matched.entries)
        if (e.value == null) e.key,
    ]..sort();
    // Exports may list newest first: show the range oldest to newest.
    final starts = [for (final w in parsed.workouts) w.start]..sort();
    final first = starts.first, last = starts.last;

    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Import from ${parsed.format.label}?'),
        content: Text(
          '${parsed.workouts.length} workouts from ${DateFormat.yMMMd().format(first)} '
          'to ${DateFormat.yMMMd().format(last)}.\n\n'
          '${names.length - unmatched.length} of ${names.length} exercises match the library.'
          '${unmatched.isEmpty ? '' : ' These will be added as your own exercises: ${unmatched.take(6).join(', ')}${unmatched.length > 6 ? '…' : ''}'}',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final store = context.read<WorkoutStore>();
    setState(() => _busy = true);
    final int added;
    try {
      final ids = <String, String>{};
      for (final e in matched.entries) {
        ids[e.key] = e.value ?? await _addCustomExercise(exercises, e.key);
      }
      added = await store.importSessions(toSessions(parsed, ids));
    } on Exception catch (e) {
      logError('Import failed: $e');
      if (mounted) {
        await showMessage(
          context,
          title: 'Import Failed',
          message: 'Nothing was changed. Please try again.',
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    await showMessage(
      context,
      title: 'Import Complete',
      message: added == 0
          ? 'These workouts were already imported.'
          : 'Added $added workouts to your history.',
    );
  }

  Future<void> _importFood() async {
    final text = await _pickText(['csv']);
    if (text == null || !mounted) return;
    final List<FoodEntry> entries;
    try {
      entries = await compute(parseMyFitnessPalCsv, text);
    } on Exception catch (e) {
      logError('Import: could not parse food CSV: $e');
      if (mounted) {
        await showMessage(
          context,
          title: "Couldn't Read File",
          message: "This CSV file couldn't be read. Nothing was changed.",
        );
      }
      return;
    }
    if (!mounted) return;
    if (entries.isEmpty) {
      await showMessage(
        context,
        title: 'Unsupported File',
        message:
            'Choose the Nutrition Summary CSV from a MyFitnessPal export. '
            'If it came as a .zip, unzip it first.',
      );
      return;
    }
    final days = {
      for (final e in entries) DateTime(e.date.year, e.date.month, e.date.day),
    }.toList()..sort();
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Import from MyFitnessPal?'),
        content: Text(
          '${entries.length} meals over ${days.length} days, from '
          '${DateFormat.yMMMd().format(days.first)} to '
          '${DateFormat.yMMMd().format(days.last)}. Each meal is added '
          'with its calories and macros.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final store = context.read<NutritionStore>();
    setState(() => _busy = true);
    final int added;
    try {
      added = await store.importEntries(entries);
    } on Exception catch (e) {
      logError('Import: food failed: $e');
      if (mounted) {
        await showMessage(
          context,
          title: 'Import Failed',
          message: 'Nothing was changed. Please try again.',
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    await showMessage(
      context,
      title: 'Import Complete',
      message: added == 0
          ? 'These meals were already imported.'
          : 'Added $added meals to your food diary.',
    );
  }

  Future<void> _importRoutine() async {
    final text = await _pickText(['json']);
    if (text == null || !mounted) return;
    final shared = routineFromJson(text);
    if (shared == null) {
      await showMessage(
        context,
        title: 'Not a Routine',
        message: 'That file isn\'t a shared Health routine.',
      );
      return;
    }
    final exercises = context.read<ExerciseStore>();
    final store = context.read<WorkoutStore>();
    setState(() => _busy = true);
    try {
      await _addRoutine(shared, exercises, store);
    } on Exception catch (e) {
      logError('Import: routine failed: $e');
      if (mounted) {
        await showMessage(
          context,
          title: 'Import Failed',
          message: 'The routine couldn\'t be added. Please try again.',
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) {
      await showMessage(
        context,
        title: 'Routine Added',
        message: '"${shared.routine.name}" is in your routines.',
      );
    }
  }

  Future<void> _addRoutine(
    ({Routine routine, Map<String, String> names}) shared,
    ExerciseStore exercises,
    WorkoutStore store,
  ) async {
    final matcher = NameMatcher(exercises.catalog);
    final items = <RoutineItem>[];
    for (final item in shared.routine.items) {
      var id = item.exerciseId;
      if (exercises.catalog.byId(id) == null) {
        final name = shared.names[id] ?? 'Exercise';
        id =
            matcher.match(name)?.id ??
            await _addCustomExercise(exercises, name);
      }
      items.add(
        RoutineItem(
          id,
          sets: item.sets,
          reps: item.reps,
          weightKg: item.weightKg,
          warmupSets: item.warmupSets,
          restSeconds: item.restSeconds,
          superset: item.superset,
          progression: item.progression,
        ),
      );
    }
    await store.saveRoutine(
      Routine(
        id: 'r${DateTime.now().microsecondsSinceEpoch}',
        name: shared.routine.name,
        items: items,
      ),
    );
  }

  Future<String> _addCustomExercise(
    ExerciseStore exercises,
    String name,
  ) async {
    final exercise = await exercises.addCustom(
      name: name,
      bodyPart: 'other',
      equipment: 'other',
      target: 'other',
    );
    return exercise.id;
  }

  /// Writes [contents] to a temporary file and opens the share sheet.
  /// [files] are (name, text or bytes).
  Future<void> _share(List<(String, Object)> files, String subject) async {
    final dir = await ShareFiles.prepare();
    final out = <XFile>[];
    for (final (name, contents) in files) {
      final file = File('${dir.path}/$name');
      await switch (contents) {
        final List<int> bytes => file.writeAsBytes(bytes, flush: true),
        _ => file.writeAsString('$contents', flush: true),
      };
      out.add(XFile(file.path));
    }
    // The copies are removed on the next share or launch (the receiving
    // app may still be reading them).
    await SharePlus.instance.share(ShareParams(files: out, subject: subject));
  }

  Future<void> _busyWhile(String failure, Future<void> Function() run) async {
    setState(() => _busy = true);
    try {
      await run();
    } on Exception catch (e) {
      logError('$failure: $e');
      if (mounted) {
        await showMessage(
          context,
          title: failure,
          message: 'Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> _backUp() async {
    if (!await context.read<AppLock>().confirm('Back up your health data')) {
      return;
    }
    if (!mounted) return;
    final protection = await askBackupProtection(context);
    if (protection == null || !mounted) return;
    if (protection is NoPassword) {
      final ok = await confirmDestructive(
        context,
        title: 'Back Up Without a Password?',
        message:
            'Anyone with the file can read your health data, Medical ID and '
            'workouts. Only keep it somewhere you trust.',
        action: 'Back Up',
      );
      if (!ok || !mounted) return;
    }
    final toFiles = await _askSaveToFiles();
    if (toFiles == null || !mounted) return;
    final health = context.read<HealthStore>();
    final workouts = context.read<WorkoutStore>();
    await _busyWhile('Backup Failed', () async {
      final (:json, skipped: _) = await buildBackupJson(
        health: health,
        workouts: workouts,
        now: DateTime.now(),
      );
      final contents = switch (protection) {
        WithPassword(:final password) => await BackupCrypto.encrypt(
          json,
          password,
        ),
        NoPassword() => json,
      };
      final name = 'health-backup-$_today.json';
      if (!toFiles) {
        await _share([(name, contents)], 'Health backup');
        return;
      }
      final saved = await FilePicker.saveFile(
        fileName: name,
        bytes: utf8.encode(contents),
        mimeType: 'application/json',
      );
      if (saved != null && mounted) {
        await showMessage(
          context,
          title: 'Backup Saved',
          message: 'Saved as $name. Keep it somewhere safe.',
        );
      }
    });
  }

  /// Where a backup goes: true to save it in Files (or a folder on
  /// Android), false to share it with another app. Null if cancelled.
  Future<bool?> _askSaveToFiles() => showCupertinoModalPopup<bool>(
    context: context,
    builder: (context) => CupertinoActionSheet(
      title: const Text('Save Backup'),
      actions: [
        CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Save to Files'),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Share…'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ),
  );

  Future<void> _restore() async {
    var text = await _pickText(['json']);
    if (text == null || !mounted) return;
    if (BackupCrypto.isEncrypted(text)) {
      text = await _unlock(text);
      if (text == null || !mounted) return;
    }
    final Backup backup;
    try {
      backup = await compute(Backup.parse, text);
    } on FormatException catch (e) {
      if (!mounted) return;
      await showMessage(
        context,
        title: 'Can\'t Restore This File',
        message: e.message == 'Made by a newer version of Health'
            ? 'This backup was made by a newer version of Health. Update '
                  'the app, then try again.'
            : 'Choose a backup made with "Back Up Now".',
      );
      return;
    } on Exception catch (e) {
      logError('Restore: could not read backup: $e');
      if (mounted) {
        await showMessage(
          context,
          title: 'Can\'t Restore This File',
          message: 'Choose a backup made with "Back Up Now".',
        );
      }
      return;
    }
    if (!mounted) return;
    if (backup.isEmpty) {
      await showMessage(
        context,
        title: 'Empty Backup',
        message: 'This backup has nothing to restore.',
      );
      return;
    }
    final mode = await askRestoreMode(context, backup);
    if (mode == null || !mounted) return;
    if (mode == RestoreMode.replace) {
      final ok = await confirmDestructive(
        context,
        title: 'Replace All Data?',
        message:
            'Your current health data, workouts, routines and settings will '
            'be replaced by the backup. Progress photos are kept.'
            '${backup.skipped > 0 ? '\n\n${backup.skipped} damaged records in the backup can\'t be restored and will be lost.' : ''}',
        action: 'Replace',
      );
      if (!ok || !mounted) return;
      if (!await context.read<AppLock>().confirm('Replace All Data')) return;
      if (!mounted) return;
    }
    // Read now: the restore outlives this frame.
    final meds = context.read<MedicationStore>();
    final cycle = context.read<CycleStore>();
    final badges = context.read<AchievementStore>();
    final food = context.read<NutritionStore>();
    final mood = context.read<MoodStore>();
    final gym = context.read<GymStore>();
    final fasting = context.read<FastingStore>();
    final sleepSchedule = context.read<SleepScheduleStore>();
    final programs = context.read<ProgramStore>();
    final restorer = BackupRestorer(
      health: context.read<HealthStore>(),
      workouts: context.read<WorkoutStore>(),
      exercises: context.read<ExerciseStore>(),
      notifications: context.read<NotificationController>(),
      reloadOthers: () async {
        await meds.load();
        await meds.reschedule();
        await cycle.load();
        await mood.load();
        await gym.load();
        await fasting.load();
        await fasting.reschedule();
        await sleepSchedule.load();
        await sleepSchedule.reschedule();
        await programs.load();
        await food.load();
        await badges.load();
      },
    );
    RestoreResult? result;
    setState(() => _busy = true);
    try {
      result = await restorer.restore(backup, mode);
    } on RestoreException catch (e) {
      logError('Restore failed: $e');
      if (mounted) {
        await showMessage(
          context,
          title: 'Restore Didn\'t Finish',
          message: mode == RestoreMode.merge
              ? 'Some data couldn\'t be saved. Free up some storage, then '
                    'restore again; nothing will be added twice.'
              : e.rolledBack
              ? 'Some data couldn\'t be saved, so your previous data was '
                    'put back. Free up some storage and try again.'
              : 'Some data couldn\'t be saved. Free up some storage and '
                    'restore again.',
        );
      }
    } on Exception catch (e) {
      logError('Restore failed: $e');
      if (mounted) {
        await showMessage(
          context,
          title: 'Restore Failed',
          message: 'Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    final r = result;
    if (r == null || !mounted) return;
    await showMessage(
      context,
      title: 'Restore Complete',
      message: mode == RestoreMode.replace
          ? 'Health now matches your backup.'
          : r.entries + r.workouts + r.routines == 0
          ? 'Everything in this backup was already here.'
          : 'Added ${r.entries} health entries, ${r.workouts} workouts and '
                '${r.routines} routines.',
    );
  }

  /// Asks for the password until the backup opens or the user gives up.
  Future<String?> _unlock(String text) async {
    String? error;
    for (;;) {
      if (!mounted) return null;
      final password = await askBackupPassword(context, error: error);
      if (password == null || !mounted) return null;
      setState(() => _busy = true);
      try {
        return await BackupCrypto.decrypt(text, password);
      } on BackupPasswordException {
        error = 'Wrong password. Please try again.';
      } on FormatException {
        if (mounted) {
          await showMessage(
            context,
            title: 'Damaged Backup',
            message: 'This backup file can\'t be read.',
          );
        }
        return null;
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Future<void> _exportCsv() async {
    if (!await context.read<AppLock>().confirm('Export your health data')) {
      return;
    }
    if (!mounted) return;
    final protection = await askBackupProtection(
      context,
      title: 'Encrypt Spreadsheets?',
      message:
          'A password puts them in an encrypted zip (AES-256) that 7-Zip, '
          'WinZip and most file apps can open with it.',
    );
    if (protection == null || !mounted) return;
    if (protection is NoPassword &&
        !await confirmDestructive(
          context,
          title: 'Export Without a Password?',
          message:
              'The files are NOT encrypted. Anyone with them can read your '
              'health data and workouts.',
          action: 'Export',
        )) {
      return;
    }
    if (!mounted) return;
    final health = context.read<HealthStore>();
    final workouts = context.read<WorkoutStore>();
    final names = context.read<ExerciseStore>().catalog;
    final files = [
      ('health-data-$_today.csv', healthEntriesCsv(health.allEntries)),
      ('workouts-$_today.csv', workoutsCsv(workouts.all, names.nameOf)),
    ];
    await _busyWhile('Export Failed', () async {
      switch (protection) {
        case WithPassword(:final password):
          // Off the UI thread: encrypting years of data takes a moment.
          final zip = await Isolate.run(() => encryptedZip(files, password));
          await _share([
            ('health-spreadsheets-$_today.zip', zip),
          ], 'Health spreadsheets');
        case NoPassword():
          await _share(files, 'Health spreadsheets');
      }
    });
  }

  static Widget _row(
    IconData icon,
    Color color,
    String title,
    VoidCallback onTap, {
    String? value,
  }) => InfoRow(
    leading: IconTile(icon: icon, color: color),
    title: title,
    value: value,
    chevron: true,
    onTap: onTap,
  );

  @override
  Widget build(BuildContext context) {
    return LargeTitlePage(
      absorbing: _busy,
      title: 'Backup & Export',
      trailing: _busy ? const CupertinoActivityIndicator() : null,
      children: [
        GroupedSection(
          header: 'Backup',
          footer:
              'A backup holds your health data, workouts, routines and '
              'settings. Protect it with a password to encrypt it. '
              'Progress photos aren\'t included.',
          children: [
            _row(Icons.shield_rounded, Palette.green, 'Back Up Now', _backUp),
            _row(
              Icons.undo_rounded,
              Palette.blue,
              'Restore from Backup',
              _restore,
            ),
            // Android only for now: they write to a folder picked through
            // Android's document picker (see SafBackupFolder).
            if (defaultTargetPlatform == TargetPlatform.android)
              _row(
                Icons.replay_circle_filled_rounded,
                Palette.teal,
                'Automatic Backups',
                () => AutoBackupScreen.open(context),
                value: switch (context.watch<AutoBackup>()) {
                  AutoBackup(enabled: false) => 'Off',
                  AutoBackup(error: _?) => 'Failed',
                  _ => 'On',
                },
              ),
          ],
        ),
        GroupedSection(
          header: 'Export',
          footer:
              'Two CSV files for Excel, Numbers or Google Sheets: every '
              'health entry, and your workouts in Strong\'s format. Add a '
              'password to export them encrypted.',
          children: [
            _row(
              Icons.table_chart_rounded,
              Palette.teal,
              'Export Spreadsheets',
              _exportCsv,
            ),
          ],
        ),
        GroupedSection(
          header: 'Import from Other Apps',
          footer:
              'Export a CSV from Strong, Hevy or FitNotes for workouts, or '
              'MyFitnessPal for food, and choose it here. Importing the same '
              'file twice won\'t create duplicates.',
          children: [
            _row(
              Icons.file_download_rounded,
              Palette.indigo,
              'Import Workouts',
              _importWorkouts,
            ),
            _row(
              Icons.restaurant_rounded,
              Palette.green,
              'Import Food Diary',
              _importFood,
            ),
            _row(
              Icons.format_list_bulleted_rounded,
              Palette.orange,
              'Import Shared Routine',
              _importRoutine,
            ),
          ],
        ),
      ],
    );
  }
}
