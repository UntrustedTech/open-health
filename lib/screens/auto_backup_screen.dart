import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/security/app_lock.dart';
import 'package:health_app/backup/auto_backup.dart';
import 'package:health_app/screens/backup_dialogs.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/app_segmented.dart';

/// Automatic, encrypted backups to a folder you choose.
class AutoBackupScreen extends StatelessWidget {
  const AutoBackupScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(
      title: 'Automatic Backups',
      builder: (_) => const AutoBackupScreen(),
    ),
  );

  Future<void> _turnOn(BuildContext context) async {
    final auto = context.read<AutoBackup>();
    // As for Back Up Now: someone holding the unlocked phone mustn't send
    // the data to a folder of their own.
    if (!await context.read<AppLock>().confirm('Back up your health data')) {
      return;
    }
    if (!context.mounted) return;
    final folder = await auto.pickFolder();
    if (folder == null || !context.mounted) return;
    final p = await askBackupProtection(context, required: true);
    if (p is! WithPassword || !context.mounted) return;
    await auto.enable(folder, p.password);
    final ok = await auto.runNow();
    if (!context.mounted) return;
    await showMessage(
      context,
      title: ok ? 'Automatic Backups Are On' : 'Backup Failed',
      message: ok
          ? 'Your first backup is in "${folder.name}". Keep your password '
                'safe: without it, backups can\'t be restored.'
          : auto.error ?? 'Please try again.',
    );
  }

  Future<void> _turnOff(BuildContext context) async {
    final auto = context.read<AutoBackup>();
    if (!await context.read<AppLock>().confirm('Turn off automatic backups')) {
      return;
    }
    if (!context.mounted) return;
    final ok = await confirmDestructive(
      context,
      title: 'Turn Off Automatic Backups?',
      message: 'Backups already in the folder are kept.',
      action: 'Turn Off',
    );
    if (ok) await auto.disable();
  }

  Future<void> _changeFolder(BuildContext context) async {
    final auto = context.read<AutoBackup>();
    if (!await context.read<AppLock>().confirm('Change the backup folder')) {
      return;
    }
    if (!context.mounted) return;
    final folder = await auto.pickFolder();
    if (folder != null) await auto.changeFolder(folder);
  }

  @override
  Widget build(BuildContext context) {
    final auto = context.watch<AutoBackup>();
    final green = context.resolve(Palette.green);
    final last = auto.lastBackup;
    final error = auto.error;
    return LargeTitlePage(
      title: 'Automatic Backups',
      trailing: auto.running ? const CupertinoActivityIndicator() : null,
      children: [
        GroupedSection(
          footer:
              'Health saves an encrypted backup to a folder you choose, such '
              'as Downloads, an SD card or a cloud storage app, when you '
              'open the app and a backup is due.',
          children: [
            CupertinoListTile(
              leading: IconTile(
                icon: Icons.replay_circle_filled_rounded,
                color: green,
              ),
              title: const Text('Automatic Backups'),
              trailing: CupertinoSwitch(
                value: auto.enabled,
                onChanged: (v) => v ? _turnOn(context) : _turnOff(context),
              ),
            ),
          ],
        ),
        if (auto.enabled) ...[
          GroupedSection(
            header: 'Status',
            hasLeading: false,
            footer: error,
            children: [
              InfoRow(
                title: 'Last Backup',
                value: last == null
                    ? 'Never'
                    : '${formatDay(last, DateTime.now())}, '
                          '${DateFormat.jm().format(last)}',
              ),
              InfoRow(
                title: 'Folder',
                value: auto.folder?.name ?? 'None',
                chevron: true,
                onTap: () => _changeFolder(context),
              ),
              CupertinoListTile(
                title: Text(
                  'Back Up Now',
                  style: TextStyle(color: context.tint),
                ),
                onTap: auto.running ? null : auto.runNow,
              ),
            ],
          ),
          GroupedSection(
            header: 'How Often',
            hasLeading: false,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: AppSegmented<BackupEvery>(
                    groupValue: auto.every,
                    children: {
                      for (final e in BackupEvery.values) e: Text(e.label),
                    },
                    onValueChanged: (e) {
                      if (e != null) auto.setEvery(e);
                    },
                  ),
                ),
              ),
            ],
          ),
          GroupedSection(
            header: 'Keep',
            footer: 'Older backups are deleted from the folder.',
            hasLeading: false,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: AppSegmented<int>(
                    groupValue: auto.keep,
                    children: {
                      for (final k in AutoBackup.keepOptions)
                        k: Text('Last $k'),
                    },
                    onValueChanged: (k) {
                      if (k != null) auto.setKeep(k);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
