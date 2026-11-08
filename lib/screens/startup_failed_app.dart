import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/ios.dart';

/// Shown if a step that must finish before the first screen fails or
/// hangs, instead of leaving the launch screen up for good. [details] says
/// which step and why, for a bug report.
class StartupFailedApp extends StatelessWidget {
  const StartupFailedApp({required this.details, super.key});

  final String details;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Health',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme(null),
      home: Builder(
        builder: (context) => CupertinoPageScaffold(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(32),
              children: [
                const SizedBox(height: 40),
                const Center(
                  child: IconTile(
                    icon: Icons.error_outline_rounded,
                    color: Palette.orange,
                    size: 72,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Health Couldn\'t Start',
                  style: context.title1,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your data is safe and has not been changed. Close Health '
                  'and open it again. If this keeps happening, send the '
                  'details below to the developer.',
                  style: context.body.copyWith(color: context.secondaryLabel),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  details,
                  style: context.footnote.copyWith(
                    color: context.secondaryLabel,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                CupertinoButton(
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: details)),
                  child: const Text('Copy'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
