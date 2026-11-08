import 'dart:async';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/update/update_checker.dart';
import 'package:health_app/utils/log.dart';
import 'package:health_app/widgets/ios.dart';

/// The [UpdateChecker], or null where there's none (store version
/// previews and tests).
UpdateChecker? _checker(BuildContext context, {bool listen = true}) {
  try {
    return listen
        ? context.watch<UpdateChecker>()
        : context.read<UpdateChecker>();
  } on ProviderNotFoundException {
    return null;
  }
}

String _installHint() => defaultTargetPlatform == TargetPlatform.iOS
    ? 'Download the new .ipa, then install it the same way you installed '
          'Health.'
    : 'Download the new APK and open it to install. Your data stays.';

/// Opens [update]'s download in the browser.
Future<void> openUpdate(BuildContext context, AppUpdate update) async {
  var opened = false;
  try {
    opened = await launchUrl(update.url, mode: LaunchMode.externalApplication);
  } on Exception catch (e) {
    logError('Updates: could not open link: $e');
  }
  if (!opened && context.mounted) {
    await showMessage(
      context,
      title: 'Couldn\'t Open the Download',
      message: 'Please try again, or get it from GitHub.',
    );
  }
}

/// Settings: a row at the top while a newer build is out.
class UpdateSection extends StatelessWidget {
  const UpdateSection({super.key});

  @override
  Widget build(BuildContext context) {
    final update = _checker(context)?.available;
    if (update == null) return const SizedBox.shrink();
    return GroupedSection(
      footer: _installHint(),
      children: [
        InfoRow(
          leading: IconTile(
            icon: Icons.system_update_rounded,
            color: context.resolve(Palette.green),
          ),
          title: 'Update Available',
          subtitle: 'Health ${update.version} (${update.build})',
          value: 'Download',
          chevron: true,
          onTap: () => openUpdate(context, update),
        ),
      ],
    );
  }
}

/// Tells the user once, when the app opens, about each new build.
Future<void> announceUpdate(BuildContext context) async {
  final checker = _checker(context, listen: false);
  final update = checker?.available;
  if (checker == null || update == null) return;
  if (!await checker.shouldAnnounce() || !context.mounted) return;
  await checker.markAnnounced();
  if (!context.mounted) return;
  final download = await showCupertinoDialog<bool>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Text('Update Available'),
      content: Text(
        'Health ${update.version} (${update.build}) is out. '
        '${_installHint()}',
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Later'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Download'),
        ),
      ],
    ),
  );
  if (download == true && context.mounted) {
    unawaited(openUpdate(context, update));
  }
}
