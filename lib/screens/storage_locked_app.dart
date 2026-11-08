import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;

import 'package:health_app/l10n/text.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/ios.dart';

/// Shown if the encryption key can't be read. Nothing is read, changed or
/// deleted, so the data is intact once the key is available again.
///
/// With [onStartFresh], the key isn't on this phone at all (it never
/// leaves the phone it was made on, so it's missing after moving to a new
/// phone): the data can't be opened, and the app offers to start again.
class StorageLockedApp extends StatelessWidget {
  const StorageLockedApp({super.key, this.onStartFresh});

  /// Deletes the data that can't be opened and opens the app again.
  final Future<void> Function()? onStartFresh;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Health',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme(null),
      home: Builder(
        builder: (context) => CupertinoPageScaffold(
          child: SafeArea(
            // Scrolls when large text needs more room than the screen has.
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const IconTile(
                            icon: Icons.lock_rounded,
                            color: Palette.orange,
                            size: 72,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Health Is Locked',
                            style: context.title1,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            onStartFresh == null
                                ? 'Health couldn\'t access the secure key that protects '
                                      'your data. Your data is safe and has not been changed.\n\n'
                                      'Close Health and open it again. If this keeps happening, '
                                      'restart your phone.'
                                : 'The secure key that protects your data isn\'t on this '
                                      'phone. It never leaves the phone it was made on, so '
                                      'data moved from another phone can\'t be opened here.\n\n'
                                      'Start fresh, then restore a Health backup in Settings → '
                                      'Backup, Import & Export if you have one.',
                            style: context.body.copyWith(
                              color: context.secondaryLabel,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (onStartFresh case final startFresh?) ...[
                            const SizedBox(height: 24),
                            _StartFreshButton(startFresh),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StartFreshButton extends StatefulWidget {
  const _StartFreshButton(this.startFresh);

  final Future<void> Function() startFresh;

  @override
  State<_StartFreshButton> createState() => _StartFreshButtonState();
}

class _StartFreshButtonState extends State<_StartFreshButton> {
  var _busy = false;

  Future<void> _confirm() async {
    final ok = await confirmDestructive(
      context,
      title: 'Start Fresh?',
      message:
          'The data that can\'t be opened is deleted from this phone. This '
          'can\'t be undone.',
      action: 'Delete and Start Fresh',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    await widget.startFresh();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => _busy
      ? const CupertinoActivityIndicator()
      : CupertinoButton(
          onPressed: _confirm,
          child: Text(
            'Start Fresh',
            style: TextStyle(color: context.resolve(CupertinoColors.systemRed)),
          ),
        );
}
