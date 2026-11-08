import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';

import 'package:health_app/app_edition.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/notifications/notification_controller.dart';
import 'package:health_app/screens/customize_tab_sheet.dart';
import 'package:health_app/screens/cycle/cycle_screen.dart';
import 'package:health_app/screens/edit_profile_screen.dart';
import 'package:health_app/screens/goal/body_goal_screen.dart';
import 'package:health_app/screens/goals_screen.dart';
import 'package:health_app/screens/health_connect_screen.dart';
import 'package:health_app/screens/medications/medications_screen.dart';
import 'package:health_app/screens/notification_settings_screen.dart';
import 'package:health_app/state/cycle_store.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/medication_store.dart';
import 'package:health_app/sync/health_sync_service.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/glow_tile.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/app_segmented.dart';

/// Health settings: your details, goals, units, the Health tab layout,
/// trackers and where data comes from.
class HealthSettingsScreen extends StatelessWidget {
  const HealthSettingsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(
      title: 'Health Settings',
      builder: (_) => const HealthSettingsScreen(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final sync = context.watch<HealthSyncService>();
    final meds = context.watch<MedicationStore>();
    final cycle = context.watch<CycleStore>();
    final reminders = context.watch<NotificationController>().settings;
    final look = store.personalization;
    Widget row(
      IconData icon,
      Color color,
      String title,
      VoidCallback onTap, {
      String? value,
    }) => InfoRow(
      leading: IconTile(icon: icon, color: context.resolve(color)),
      title: title,
      value: value,
      chevron: true,
      onTap: onTap,
    );
    String onOff(bool on) => on ? 'On' : 'Off';
    return LargeTitlePage(
      title: 'Health Settings',
      children: [
        const SettingsHero(
          icon: Icons.favorite_rounded,
          color: Palette.pink,
          title: 'Health',
          subtitle: 'Your details, goals, trackers and data sources.',
        ),
        GroupedSection(
          header: 'You',
          children: [
            row(
              Icons.person_rounded,
              Palette.grey,
              'Health Details',
              () => EditProfileScreen.open(context),
            ),
            row(
              Icons.flag_rounded,
              Palette.teal,
              'Your Goal',
              () => BodyGoalScreen.open(context),
            ),
            row(
              Icons.track_changes_rounded,
              Palette.orange,
              'Goals',
              () => GoalsScreen.open(context),
            ),
          ],
        ),
        GroupedSection(
          header: 'Units',
          footer: look.units.examples,
          hasLeading: false,
          children: [const UnitsPicker()],
        ),
        GroupedSection(
          header: 'Health Tab',
          children: [
            row(
              Icons.tune_rounded,
              Palette.pink,
              'Customize Health Tab',
              () => CustomizeTabSheet.health(context),
            ),
          ],
        ),
        GroupedSection(
          header: 'Tracking',
          children: [
            if (!kStoreEdition)
              row(
                Icons.medication_rounded,
                Palette.teal,
                'Medications',
                () => MedicationsScreen.open(context),
                value: meds.isEmpty ? null : '${meds.active.length}',
              ),
            row(
              Icons.donut_large_rounded,
              const Color(0xFFFF4D8D),
              'Cycle Tracking',
              () => CycleScreen.open(context),
              value: onOff(cycle.enabled),
            ),
            row(
              Icons.water_drop_rounded,
              Palette.blue,
              'Hydration Reminders',
              () => NotificationSettingsScreen.open(context),
              value: onOff(reminders.water),
            ),
            row(
              Icons.radio_button_unchecked_rounded,
              Palette.red,
              'Ring Reminders',
              () => NotificationSettingsScreen.open(context),
              value: onOff(reminders.rings),
            ),
          ],
        ),
        GroupedSection(
          header: 'Data Sources',
          footer:
              'Steps, sleep, heart and workouts from your phone and watch '
              'come in through ${sync.sourceName}.',
          children: [
            row(
              Icons.sync_rounded,
              AppTheme.accent,
              sync.sourceName,
              () => HealthConnectScreen.open(context),
              value: onOff(sync.connected),
            ),
          ],
        ),
      ],
    );
  }
}

/// The metric / imperial switch, padded to sit inside a section.
class UnitsPicker extends StatelessWidget {
  const UnitsPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final look = store.personalization;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        child: AppSegmented<UnitSystem>(
          groupValue: look.units,
          children: {for (final u in UnitSystem.values) u: Text(u.label)},
          onValueChanged: (u) {
            if (u != null) store.setPersonalization(look.copyWith(units: u));
          },
        ),
      ),
    );
  }
}
