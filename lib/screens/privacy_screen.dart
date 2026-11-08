import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';

import 'package:health_app/app_edition.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/app_links.dart';

import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';

/// Explains what health data the app reads, why, and where it is kept.
/// Health Connect opens this when the user asks why the app needs access.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const routeName = '/privacy';

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(title: 'Privacy', builder: (_) => const PrivacyScreen()),
  );

  /// Each platform's own names and facts: an iPhone has no Android
  /// Keystore, and its backups work differently.
  static List<(String, String)> _sections(bool iPhone) {
    final source = iPhone ? 'Apple Health' : 'Health Connect';
    return [
      (
        'What Health Reads',
        'With your permission, Health reads steps, distance, active energy, '
            'workouts, heart rate, resting heart rate, heart rate variability, '
            'blood oxygen, blood pressure, blood glucose, sleep and sleep '
            'stages, weight and water from $source. '
            'You choose which of these to share, and you can change this at '
            'any time in ${iPhone ? 'the Health app' : source}.',
      ),
      (
        'What Health Writes',
        'Nothing, unless you turn on "Save Workouts to $source" in '
            'Workout Settings. Then only workouts you record in this app (with '
            'their distance and calories) are added. Health never changes or '
            'deletes data from other apps.',
      ),
      (
        'Location',
        'Used only while you record an outdoor workout, to measure your '
            'route, distance and pace. A notification shows whenever it is in '
            'use. Routes are stored only on this device.',
      ),
      (
        'Where Your Data Is Kept',
        iPhone
            ? 'Everything stays on this device, encrypted with a key kept in '
                  'the iPhone\'s Keychain. Health has no account and no '
                  'servers, and your data is never uploaded, sold, shared or '
                  'used for advertising. The key never leaves this iPhone, so '
                  'its data in iCloud or computer backups can\'t be read; use a '
                  'Health backup to move to a new phone.'
            : 'Everything stays on this device, encrypted with a key protected '
                  'by the Android Keystore. Health has no account and no '
                  'servers, and your data is never uploaded, sold, shared or '
                  'used for advertising. It is excluded from cloud backups and '
                  'device-to-device transfers.',
      ),
      (
        'Progress Photos',
        'Photos you add are cleaned of location and camera details, then '
            'stored encrypted inside the app. They never go to your gallery '
            'or the cloud, and Erase All Data deletes them.',
      ),
      if (kStoreEdition)
        (
          'Cycle Tracking',
          'Cycle logs are stored encrypted on this device like the rest of '
              'your data.',
        )
      else
        (
          'Medications and Cycle Tracking',
          'Medications, dose records and cycle logs are stored encrypted on '
              'this device like the rest of your data. Medication reminders show '
              'the medication\'s name; your phone\'s lock screen settings decide '
              'whether they appear while locked.',
        ),
      (
        'Backups and Export',
        iPhone
            ? 'Backups are made only when you ask. They can be encrypted with '
                  'your password; without it, they can\'t be read or restored. '
                  'Spreadsheet exports are plain, unencrypted files, and Health '
                  'warns you before creating one. Once a file leaves the app, '
                  'it\'s outside Health\'s protection.'
            : 'Backups are made only when you ask, or automatically to a folder '
                  'you choose. They can be encrypted with your password; without '
                  'it, they can\'t be read or restored. Spreadsheet exports are '
                  'plain, unencrypted files, and Health warns you before creating '
                  'one. Once a file leaves the app, it\'s outside Health\'s '
                  'protection.',
      ),
      (
        'App Lock',
        iPhone
            ? 'If you turn on App Lock, your iPhone checks your Face ID, '
                  'Touch ID or passcode. Health never sees or stores them.'
            : 'If you turn on App Lock, Android checks your fingerprint, face '
                  'or screen lock. Health never sees or stores them.',
      ),
      (
        'Internet',
        'Health uses the internet to download map images from OpenStreetMap '
            'if you choose "Street Map" for workout routes, to look foods up '
            'in Open Food Facts when you scan a barcode or search for a food, '
            'and about once a week to download the food list from GitHub '
            '(and, in the GitHub version, to check for updates). Only a '
            'barcode or search words are sent; like any website, these '
            'services can see your IP address. No health data, diary or '
            'account details are sent.',
      ),
      (
        'Camera',
        'Used only while you scan a food barcode or take a progress photo. '
            'Barcode scanning happens on the phone; no images are kept or sent.',
      ),
      if (iPhone)
        (
          'Notifications',
          'Reminders are scheduled on your phone and are off until you turn '
              'them on.',
        )
      else
        (
          'Notifications and Widgets',
          'Reminders are scheduled on your phone and are off until you turn '
              'them on. Home screen widgets show only today\'s totals and your '
              'goals. These few numbers are stored unencrypted so the widgets '
              'can read them, and are removed by Erase All Data.',
        ),
      (
        'Your Device',
        iPhone
            ? 'Health reads your phone\'s model only to show it in Profile.'
            : 'Health reads your phone\'s maker and model only to show it in '
                  'Profile and to give device-specific help, such as how to '
                  'share Samsung Health data.',
      ),
      (
        'Removing Your Data',
        'Disconnect in Profile › Settings › $source removes all imported data. '
            'Erase All Data in Profile › Settings deletes everything Health has stored. '
            'Uninstalling the app also deletes all of its data.',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LargeTitlePage(
      title: 'Privacy',
      children: [
        const Center(
          child: IconTile(
            icon: Icons.lock_rounded,
            color: Palette.blue,
            size: 64,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Your Health Data Stays With You',
          textAlign: TextAlign.center,
          style: context.title2,
        ),
        for (final (title, text) in _sections(
          defaultTargetPlatform == TargetPlatform.iOS,
        ))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: IosCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(title, style: context.headline),
                  ),
                  const SizedBox(height: 6),
                  Text(text, style: context.subheadline),
                ],
              ),
            ),
          ),
        if (sourceCodeUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: IosCard(
              onTap: () async {
                await Clipboard.setData(
                  const ClipboardData(text: sourceCodeUrl),
                );
                if (context.mounted) {
                  await showMessage(
                    context,
                    title: 'Link Copied',
                    message:
                        'Paste it into your browser to see Health\'s source '
                        'code.',
                  );
                }
              },
              child: Row(
                children: [
                  const IconTile(icon: Icons.code_rounded, color: Palette.teal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Source Code', style: context.headline),
                        Text(
                          sourceCodeUrl,
                          style: context.footnote.copyWith(
                            color: context.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.copy_rounded, color: context.tint, size: 20),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            'Health is not a medical device and does not provide medical '
            'advice.',
            textAlign: TextAlign.center,
            style: context.footnote.copyWith(color: context.secondaryLabel),
          ),
        ),
      ],
    );
  }
}
