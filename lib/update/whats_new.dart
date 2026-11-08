import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:health_app/app_edition.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/log.dart';
import 'package:health_app/widgets/ios.dart';

typedef WhatsNewItem = ({IconData icon, String title, String detail});

/// What each build brought, newest first. Add an entry with every release
/// that has something to tell; builds without one show nothing.
const Map<int, List<WhatsNewItem>> whatsNewNotes = {
  128: [
    (
      icon: Icons.check_circle_rounded,
      title: 'Livelier Habits',
      detail:
          'Pick an icon and colour for each habit, reorder them, and see '
          'your best streak.',
    ),
    (
      icon: Icons.notifications_active_rounded,
      title: 'Live Notifications',
      detail:
          'Tick habits off right from the notification. Workouts, rest '
          'timers and fasts stay pinned as Live Updates.',
    ),
    (
      icon: Icons.speed_rounded,
      title: 'Speed Tracking',
      detail:
          'GPS workouts like cycling and skating show your speed, top speed '
          'and a speed chart.',
    ),
    (
      icon: Icons.water_drop_rounded,
      title: 'Quick Water',
      detail:
          'One-tap glass, bottle and big bottle buttons, in your units, plus '
          'Custom.',
    ),
    (
      icon: Icons.lock_rounded,
      title: 'Encrypted Export',
      detail: 'Spreadsheets can be exported in a password-protected zip.',
    ),
    // Store versions are updated by the store.
    if (!kStoreEdition)
      (
        icon: Icons.system_update_rounded,
        title: 'Update Alerts',
        detail: 'Health checks for a new version once a day and tells you.',
      ),
  ],
};

/// The notes for builds after [seen] up to [current], newest first.
@visibleForTesting
List<WhatsNewItem> notesSince(
  int seen,
  int current, [
  Map<int, List<WhatsNewItem>> notes = whatsNewNotes,
]) => [
  for (final b in notes.keys.toList()..sort((a, b) => b - a))
    if (b > seen && b <= current) ...notes[b]!,
];

/// Shows what's new once after each update (provided by main.dart).
class WhatsNew {
  WhatsNew(this._prefs, {Future<int?> Function()? build})
    : _build = build ?? _appBuild;

  static const _seenKey = 'whatsNewSeenBuild';
  static const _freshKey = 'whatsNewFreshInstall';

  final SharedPreferencesAsync _prefs;
  final Future<int?> Function() _build;

  static Future<int?> _appBuild() async =>
      int.tryParse((await PackageInfo.fromPlatform()).buildNumber);

  /// The one in [context], or null where there's none (tests, previews).
  static WhatsNew? of(BuildContext context) {
    try {
      return context.read<WhatsNew>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// Called when first-time setup finishes, so a new install never shows
  /// notes for a version the user didn't update from.
  Future<void> markFreshInstall() async {
    try {
      await _prefs.setBool(_freshKey, true);
    } on Exception catch (e) {
      logError('What\'s New: could not save: $e');
    }
  }

  /// The notes not shown yet, marking them shown.
  Future<List<WhatsNewItem>> takeUnseen() async {
    try {
      final current = await _build();
      if (current == null) return const [];
      final seen = await _prefs.getInt(_seenKey);
      if (seen == current) return const [];
      await _prefs.setInt(_seenKey, current);
      if (await _prefs.getBool(_freshKey) ?? false) {
        await _prefs.remove(_freshKey);
        return const [];
      }
      // No mark yet: set up before this screen existed, so this build's.
      return notesSince(seen ?? current - 1, current);
    } on Exception catch (e) {
      logError('What\'s New: $e');
      return const [];
    }
  }

  Future<void> show(BuildContext context) async {
    final items = await takeUnseen();
    if (items.isEmpty || !context.mounted) return;
    await showCupertinoSheet<void>(
      context: context,
      scrollableBuilder: (context, controller) =>
          _WhatsNewSheet(items: items, controller: controller),
    );
  }
}

class _WhatsNewSheet extends StatelessWidget {
  const _WhatsNewSheet({required this.items, required this.controller});

  final List<WhatsNewItem> items;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        automaticallyImplyLeading: false,
        middle: const Text('What\'s New'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Done',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      child: PageList(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          AppTheme.margin,
          12,
          AppTheme.margin,
          32,
        ),
        children: [
          GroupedSection(
            header: 'In This Update',
            children: [
              for (final item in items)
                InfoRow(
                  leading: IconTile(
                    icon: item.icon,
                    color: context.resolve(Palette.green),
                  ),
                  title: item.title,
                  subtitle: item.detail,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
