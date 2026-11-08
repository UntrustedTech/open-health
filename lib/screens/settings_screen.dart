import 'dart:async';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'package:flutter/material.dart' show Icons;
import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/screens/language_screen.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/notifications/notification_controller.dart';
import 'package:health_app/screens/error_log_screen.dart';
import 'package:health_app/screens/food/food_diary_screen.dart'
    show foodOrange, kcalText;
import 'package:health_app/screens/food/food_settings_screen.dart';
import 'package:health_app/screens/health_settings_screen.dart';
import 'package:health_app/state/nutrition_store.dart';
import 'package:health_app/update/update_ui.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/glow_tile.dart';
import 'package:health_app/backup/auto_backup.dart';
import 'package:health_app/export/share_files.dart';
import 'package:health_app/platform/device_profile.dart';
import 'package:health_app/screens/acknowledgements_screen.dart';
import 'package:health_app/screens/app_lock_screen.dart';
import 'package:health_app/screens/appearance_screen.dart';
import 'package:health_app/screens/data_transfer_screen.dart';
import 'package:health_app/platform/home_widgets.dart';
import 'package:health_app/screens/health_connect_screen.dart';
import 'package:health_app/screens/notification_settings_screen.dart';
import 'package:health_app/screens/workouts/workout_settings_screen.dart';
import 'package:health_app/state/achievement_store.dart';
import 'package:health_app/state/cycle_store.dart';
import 'package:health_app/state/sleep_schedule_store.dart';
import 'package:health_app/state/program_store.dart';
import 'package:health_app/state/gym_store.dart';
import 'package:health_app/state/mood_store.dart';
import 'package:health_app/state/fasting_store.dart';
import 'package:health_app/state/exercise_store.dart';
import 'package:health_app/state/medication_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/screens/privacy_screen.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/utils/log.dart';
import 'package:health_app/state/photo_store.dart';
import 'package:health_app/security/app_lock.dart';
import 'package:health_app/sync/health_sync_service.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/platform/app_permissions.dart';

/// Every app-wide setting, opened from the cog on Profile.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(title: 'Settings', builder: (_) => const SettingsScreen()),
  );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final sync = context.watch<HealthSyncService>();
    final device = context.watch<DeviceProfile>();

    return LargeTitlePage(
      title: 'Settings',
      children: [
        const UpdateSection(),
        const _AdvancedSettings(),
        GroupedSection(
          header: 'Personalization',
          children: [
            InfoRow(
              leading: IconTile(
                icon: Icons.palette_rounded,
                color: context.tint,
              ),
              title: 'Appearance',
              value: store.personalization.accent.label,
              chevron: true,
              onTap: () => AppearanceScreen.open(context),
            ),
            _row(
              context,
              icon: Icons.straighten_rounded,
              color: Palette.teal,
              title: 'Units',
              value: store.personalization.units.label,
              onTap: () => HealthSettingsScreen.open(context),
            ),
            _row(
              context,
              icon: Icons.translate_rounded,
              color: Palette.indigo,
              title: 'Language',
              value: switch (context.watch<LanguageController>().choice) {
                AppLanguage.system => 'System',
                final l => l.nativeName,
              },
              onTap: () => LanguageScreen.open(context),
            ),
          ],
        ),
        GroupedSection(
          header: 'Data',
          children: [
            InfoRow(
              leading: const IconTile(
                icon: Icons.favorite_rounded,
                color: AppTheme.accent,
              ),
              title: sync.sourceName,
              subtitle: sync.connected
                  ? 'Permissions, background sync and recent access'
                  : null,
              value: !sync.connected
                  ? 'Off'
                  : sync.backgroundSync
                  ? 'Background'
                  : 'On',
              chevron: true,
              onTap: () => HealthConnectScreen.open(context),
            ),
            _row(
              context,
              icon: Icons.swap_vert_rounded,
              color: Palette.blue,
              title: 'Backup, Import & Export',
              // A failing automatic backup shouldn't go unnoticed.
              value: switch (context.watch<AutoBackup>()) {
                AutoBackup(enabled: true, error: _?) => 'Backup failed',
                _ => null,
              },
              onTap: () => DataTransferScreen.open(context),
            ),
            _row(
              context,
              icon: Icons.shield_rounded,
              color: Palette.green,
              title: 'App Lock',
              value: switch (context.watch<AppLock>()) {
                final l when l.screenLockMissing => 'Not Working',
                final l => l.enabled ? 'On' : 'Off',
              },
              onTap: () => AppLockScreen.open(context),
            ),
            _row(
              context,
              icon: Icons.lock_rounded,
              color: Palette.blue,
              title: 'Privacy',
              onTap: () => PrivacyScreen.open(context),
            ),
          ],
        ),
        GroupedSection(
          header: 'About',
          children: [
            CupertinoListTile(
              leading: const IconTile(
                icon: Icons.smartphone_rounded,
                color: Palette.grey,
              ),
              title: Text(device.displayName),
              subtitle: device.systemName.isEmpty
                  ? null
                  : Text(device.systemName),
            ),
            const _VersionRow(),
            _row(
              context,
              icon: Icons.bug_report_rounded,
              color: Palette.grey,
              title: 'Error Log',
              onTap: () => ErrorLogScreen.open(context),
            ),
            _row(
              context,
              icon: Icons.description_rounded,
              color: Palette.grey,
              title: 'Acknowledgements',
              onTap: () => AcknowledgementsScreen.open(context),
            ),
          ],
        ),
        GroupedSection(
          footer:
              'Health is not a medical device and does not provide medical '
              'advice. Your data is stored only on this device.',
          hasLeading: false,
          children: [
            CupertinoListTile(
              title: Text(
                store.hasSampleData ? 'Remove Sample Data' : 'Load Sample Data',
                style: TextStyle(color: context.tint),
              ),
              onTap: store.hasSampleData
                  ? store.removeSampleData
                  : store.loadSampleData,
            ),
            CupertinoListTile(
              title: Text(
                'Erase All Data',
                style: TextStyle(color: context.destructive),
              ),
              onTap: () => _confirmErase(context),
            ),
          ],
        ),
      ],
    );
  }

  static Widget _row(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
    String? value,
  }) => InfoRow(
    leading: IconTile(icon: icon, color: context.resolve(color)),
    title: title,
    value: value,
    chevron: true,
    onTap: onTap,
  );

  Future<void> _confirmErase(BuildContext context) async {
    final store = context.read<HealthStore>();
    final sync = context.read<HealthSyncService>();
    final workouts = context.read<WorkoutStore>();
    final exercises = context.read<ExerciseStore>();
    final photos = context.read<PhotoStore>();
    final notifications = context.read<NotificationController>();
    final medications = context.read<MedicationStore>();
    final cycle = context.read<CycleStore>();
    final mood = context.read<MoodStore>();
    final gym = context.read<GymStore>();
    final fasting = context.read<FastingStore>();
    final sleepSchedule = context.read<SleepScheduleStore>();
    final programs = context.read<ProgramStore>();
    final nutrition = context.read<NutritionStore>();
    final achievements = context.read<AchievementStore>();
    final appLock = context.read<AppLock>();
    final autoBackup = context.read<AutoBackup>();
    final language = context.read<LanguageController>();
    final ok = await confirmDestructive(
      context,
      title: 'Erase All Data?',
      message:
          'This permanently deletes all health data, workouts, food diary, '
          'medications, cycle history, mood journal, gym membership and visits, progress photos, your profile and goals from this '
          'device, and resets what Health is allowed to access. Data in '
          '${sync.sourceName} is not affected.',
      action: 'Erase All Data',
    );
    if (!ok) return;
    // With App Lock on, someone holding the unlocked phone can't wipe it.
    if (!await appLock.confirm('Erase All Data')) return;
    // Every step runs even if an earlier one fails, so nothing is left
    // behind by accident.
    var failed = false;
    Future<void> step(String name, FutureOr<void> Function() run) async {
      try {
        await run();
        // Errors too (the health plugin throws them): a failed step must
        // not stop the rest of the erase.
        // ignore: avoid_catches_without_on_clauses
      } catch (e) {
        failed = true;
        logError('Erase All: $name failed: $e');
      }
    }

    await step('disconnect', () async {
      if (sync.connected) {
        await sync.disconnect();
      } else {
        await sync.revokeAccess();
      }
    });
    await step('health data', store.eraseAll);
    await step('workouts', workouts.reset);
    await step('exercises', exercises.reset);
    await step('photos', photos.eraseAll);
    await step('notifications', notifications.reset);
    await step('medications', medications.reset);
    await step('cycle', cycle.reset);
    await step('mood', mood.reset);
    await step('gym', gym.reset);
    await step('fasting', fasting.reset);
    await step('sleep schedule', sleepSchedule.reset);
    await step('program', programs.reset);
    await step('food diary', nutrition.reset);
    await step('achievements', achievements.reset);
    await step('app lock', appLock.reset);
    await step('automatic backups', autoBackup.reset);
    await step('widgets', HomeWidgets.clear);
    await step('shared files', ShareFiles.clear);
    await step('error log', ErrorLog.clear);
    // Its setting is erased with the rest; match it now, not at restart.
    await step('language', () => language.choose(AppLanguage.system));
    // Last: permissions, for a fresh start like a new install.
    var close = false;
    await step('permissions', () async {
      close = await AppPermissions.revokeAll();
    });
    if (!context.mounted) return;
    if (failed) {
      await showMessage(
        context,
        title: 'Some Data Wasn\'t Erased',
        message: 'Please try Erase All Data again.',
      );
    } else if (close) {
      await showMessage(
        context,
        title: 'Everything Is Erased',
        message:
            'Health will now close to give back its permissions. Open it '
            'again to start fresh.',
      );
      await AppPermissions.close();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      await showMessage(
        context,
        title: 'Everything Is Erased',
        message:
            'Your iPhone keeps the permissions you gave Health, such as '
            'Apple Health, notifications and location. To reset them too, '
            'change them in the Settings app, or delete and reinstall '
            'Health.',
      );
    }
  }
}

/// App version, read from the installed package.
class _VersionRow extends StatelessWidget {
  const _VersionRow();

  static final Future<PackageInfo?> _info = () async {
    try {
      return await PackageInfo.fromPlatform();
    } on Exception catch (e) {
      logError('Profile: version unavailable: $e');
      return null;
    }
  }();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo?>(
      future: _info,
      builder: (context, snap) {
        final info = snap.data;
        return InfoRow(
          leading: IconTile(
            icon: Icons.info_rounded,
            color: context.resolve(Palette.grey),
          ),
          title: 'Version',
          value: info == null ? '' : '${info.version} (${info.buildNumber})',
        );
      },
    );
  }
}

/// One premium tile per part of the app, each opening its own settings.
class _AdvancedSettings extends StatelessWidget {
  const _AdvancedSettings();

  @override
  Widget build(BuildContext context) {
    final food = context.watch<NutritionStore>();
    final fitness = context.watch<WorkoutStore>().settings;
    final reminders = context.watch<NotificationController>().settings;
    final store = context.watch<HealthStore>();
    final on = [
      reminders.water,
      reminders.rings,
      reminders.workout,
      reminders.weeklySummary,
      reminders.meals,
      reminders.habits,
    ].where((v) => v).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('App Settings'),
          GlowGrid(
            children: [
              GlowTile(
                icon: Icons.favorite_rounded,
                color: Palette.pink,
                title: 'Health',
                value:
                    '${formatValue(MetricType.steps, store.goals.steps)} '
                    'steps',
                onTap: () => HealthSettingsScreen.open(context),
              ),
              GlowTile(
                icon: Icons.restaurant_rounded,
                color: foodOrange,
                title: 'Food',
                value: '${kcalText(food.goals.kcal)} Cal',
                onTap: () => FoodSettingsScreen.open(context),
              ),
              GlowTile(
                icon: Icons.local_fire_department_rounded,
                color: Palette.orange,
                title: 'Fitness',
                value: fitness.hasWeeklyGoal
                    ? '${fitness.weeklyGoalMinutes} min/wk'
                    : 'No goal',
                onTap: () => WorkoutSettingsScreen.open(context),
              ),
              GlowTile(
                icon: Icons.notifications_rounded,
                color: Palette.red,
                title: 'Notifications',
                value: on == 0
                    ? 'All off'
                    : '$on reminder${on == 1 ? '' : 's'} on',
                onTap: () => NotificationSettingsScreen.open(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
