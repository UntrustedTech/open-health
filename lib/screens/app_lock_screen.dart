import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/security/app_lock.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';

/// Turn App Lock on or off and choose when it locks.
class AppLockScreen extends StatelessWidget {
  const AppLockScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(title: 'App Lock', builder: (_) => const AppLockScreen()),
  );

  Future<void> _toggle(BuildContext context, bool on) async {
    final lock = context.read<AppLock>();
    final result = await lock.setEnabled(on);
    if (!context.mounted || result != LockChange.noScreenLock) return;
    await showMessage(
      context,
      title: 'Set Up a Screen Lock',
      message:
          'App Lock uses your phone\'s fingerprint, face unlock or screen '
          'lock. Set one up in your phone\'s Settings first.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<AppLock>();
    final green = context.resolve(Palette.green);
    return LargeTitlePage(
      title: 'App Lock',
      children: [
        if (lock.screenLockMissing)
          GroupedSection(
            footer:
                'Your phone no longer has a screen lock, so App Lock can\'t '
                'protect Health. Set up a PIN, pattern, fingerprint or face '
                'unlock in your phone\'s Settings to turn it back on.',
            children: [
              CupertinoListTile(
                leading: IconTile(
                  icon: Icons.warning_rounded,
                  color: context.resolve(Palette.orange),
                ),
                title: const Text('App Lock Is Not Working'),
              ),
            ],
          ),
        GroupedSection(
          footer:
              'Ask for your fingerprint, face or screen lock before showing '
              'your health data.',
          children: [
            CupertinoListTile(
              leading: IconTile(icon: Icons.shield_rounded, color: green),
              title: const Text('Require Unlock'),
              trailing: CupertinoSwitch(
                value: lock.enabled,
                onChanged: (v) => _toggle(context, v),
              ),
            ),
          ],
        ),
        if (lock.enabled)
          GroupedSection(
            header: 'Lock',
            hasLeading: false,
            children: [
              for (final a in LockAfter.values)
                CupertinoListTile(
                  title: Text(a.label),
                  trailing: a == lock.lockAfter
                      ? Icon(Icons.check_rounded, color: context.tint)
                      : null,
                  onTap: () => lock.setLockAfter(a),
                ),
            ],
          ),
        GroupedSection(
          footer:
              'Shows a blank screen in the list of recent apps. This also '
              'stops screenshots in Health.',
          children: [
            CupertinoListTile(
              leading: IconTile(
                icon: Icons.visibility_off_rounded,
                color: context.resolve(Palette.indigo),
              ),
              title: const Text('Hide in App Switcher'),
              trailing: CupertinoSwitch(
                value: lock.hideInSwitcher,
                onChanged: lock.setHideInSwitcher,
              ),
            ),
          ],
        ),
        if (lock.enabled)
          GroupedSection(
            footer:
                'When off, home screen widgets show a lock instead of your '
                'steps, water and workouts while App Lock is on.',
            children: [
              CupertinoListTile(
                leading: IconTile(
                  icon: Icons.widgets_rounded,
                  color: context.resolve(Palette.teal),
                ),
                title: const Text('Show Data in Widgets'),
                trailing: CupertinoSwitch(
                  value: lock.showWidgetData,
                  onChanged: lock.setShowWidgetData,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
