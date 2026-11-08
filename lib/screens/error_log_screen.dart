import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/export/share_files.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/log.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';

/// Settings → About → Error Log: problems the app ran into, kept only on
/// this phone, to share when asking for help.
class ErrorLogScreen extends StatelessWidget {
  const ErrorLogScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(title: 'Error Log', builder: (_) => const ErrorLogScreen()),
  );

  /// A readable name for what [HealthRepository.unreadable] lists.
  static String describe(String key) => key == entriesKey
      ? 'Health readings'
      : key
            .split(RegExp(r'[._]'))
            .where((w) => w.isNotEmpty)
            .join(' ')
            .replaceFirstMapped(RegExp('^.'), (m) => m[0]!.toUpperCase());

  Future<void> _share(BuildContext context) async {
    try {
      await _shareFile();
    } on Exception catch (e) {
      logError('Error log: could not share: $e');
      if (context.mounted) {
        await showMessage(
          context,
          title: 'Couldn\'t Share',
          message: 'The error log couldn\'t be shared. Please try again.',
        );
      }
    }
  }

  Future<void> _shareFile() async {
    final info = await PackageInfo.fromPlatform().then<PackageInfo?>(
      (i) => i,
      onError: (_) => null,
    );
    final dir = await ShareFiles.prepare();
    final file = File('${dir.path}/health-error-log.txt');
    await file.writeAsString(
      ErrorLog.asText(
        header: info == null
            ? 'Health error log'
            : 'Health ${info.version} (${info.buildNumber}) error log',
      ),
      flush: true,
    );
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'Health error log'),
    );
  }

  Future<void> _clear(BuildContext context) async {
    final ok = await confirmDestructive(
      context,
      message: 'Clear the error log?',
      action: 'Clear Log',
    );
    if (ok) await ErrorLog.clear();
  }

  @override
  Widget build(BuildContext context) {
    // Fixed once the app has started.
    final unreadable = context.read<HealthStore>().unreadableData;
    return ValueListenableBuilder<int>(
      valueListenable: ErrorLog.changes,
      builder: (context, _, _) {
        final entries = ErrorLog.entries.reversed.toList();
        final time = DateFormat.yMMMd().add_jm();
        return LargeTitlePage(
          title: 'Error Log',
          children: [
            if (unreadable.isNotEmpty)
              GroupedSection(
                header: 'Couldn\'t Be Read',
                footer:
                    'This saved data couldn\'t be read when Health started. '
                    'The original was kept on this phone, so don\'t use '
                    'Erase All Data. Restoring a backup brings it back.',
                hasLeading: false,
                children: [
                  for (final key in unreadable.toList()..sort())
                    InfoRow(title: describe(key)),
                ],
              ),
            GroupedSection(
              footer:
                  'Problems Health ran into, newest first. The log stays on '
                  'this phone and holds no health data; share it when '
                  'asking for help.',
              hasLeading: false,
              children: [
                if (entries.isEmpty)
                  const InfoRow(title: 'No problems recorded')
                else
                  for (final e in entries.take(ErrorLog.max))
                    InfoRow(
                      title: e.message.split('\n').first,
                      subtitle: time.format(e.at),
                    ),
              ],
            ),
            if (entries.isNotEmpty)
              GroupedSection(
                hasLeading: false,
                children: [
                  InfoRow(
                    title: 'Share Error Log',
                    titleColor: context.tint,
                    onTap: () => _share(context),
                  ),
                  InfoRow(
                    title: 'Clear Log',
                    titleColor: context.destructive,
                    onTap: () => _clear(context),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}
