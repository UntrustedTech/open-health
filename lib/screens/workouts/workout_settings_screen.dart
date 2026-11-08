import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/notifications/notification_controller.dart';
import 'package:health_app/screens/customize_tab_sheet.dart';
import 'package:health_app/screens/notification_settings_screen.dart';
import 'package:health_app/screens/workouts/equipment_screen.dart';
import 'package:health_app/state/exercise_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/sync/health_source.dart';
import 'package:health_app/sync/health_sync_service.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/glow_tile.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/route_style_preview.dart';
import 'package:health_app/workout/plate_calculator.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/app_segmented.dart';

/// Fitness settings: map style, Health Connect saving, gym defaults, the
/// weekly goal, rest timer, the Fitness tab layout and workout reminders.
class WorkoutSettingsScreen extends StatelessWidget {
  const WorkoutSettingsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(
      title: 'Fitness Settings',
      builder: (_) => const WorkoutSettingsScreen(),
    ),
  );

  Future<void> _toggleSave(BuildContext context, bool on) async {
    final store = context.read<WorkoutStore>();
    if (on) {
      final allowed = await context.read<HealthSource>().requestWriteAccess();
      if (!allowed) {
        if (context.mounted) {
          await showMessage(
            context,
            title: 'Not Allowed',
            message:
                'Allow Health to write exercise data in '
                '${context.read<HealthSyncService>().sourceName} to save your '
                'workouts there.',
          );
        }
        return;
      }
    }
    await store.updateSettings(
      store.settings.copyWith(saveToHealthConnect: on),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkoutStore>();
    final s = store.settings;
    final sourceName = context.read<HealthSyncService>().sourceName;
    final reminders = context.watch<NotificationController>().settings;
    return LargeTitlePage(
      title: 'Fitness Settings',
      children: [
        const SettingsHero(
          icon: Icons.local_fire_department_rounded,
          color: Palette.orange,
          title: 'Fitness',
          subtitle: 'How workouts are recorded, shown and shared.',
        ),
        GroupedSection(
          header: 'Fitness Tab',
          children: [
            InfoRow(
              leading: IconTile(
                icon: Icons.tune_rounded,
                color: context.resolve(Palette.orange),
              ),
              title: 'Customize Fitness Tab',
              chevron: true,
              onTap: () => CustomizeTabSheet.fitness(context),
            ),
            InfoRow(
              leading: IconTile(
                icon: Icons.notifications_rounded,
                color: context.resolve(Palette.red),
              ),
              title: 'Workout Reminders',
              value: reminders.workout ? 'On' : 'Off',
              chevron: true,
              onTap: () => NotificationSettingsScreen.open(context),
            ),
          ],
        ),
        GroupedSection(
          header: 'Route Maps',
          footer: s.mapStyle == MapStyle.street
              ? 'Street maps download map images from OpenStreetMap. Your '
                    'route and health data are never sent.'
              : 'Routes are drawn without a map, so Health stays fully '
                    'offline.',
          hasLeading: false,
          children: [
            RouteStylePicker(
              value: s.mapStyle,
              onChanged: (m) => store.updateSettings(s.copyWith(mapStyle: m)),
            ),
          ],
        ),
        GroupedSection(
          header: sourceName,
          footer: defaultTargetPlatform == TargetPlatform.iOS
              ? 'Workouts you record are added to $sourceName, so your '
                    'other fitness apps can show them too.'
              : 'Workouts you record are added to $sourceName, so apps '
                    'like Samsung Health and Google Fit can show them too.',
          hasLeading: false,
          children: [
            CupertinoListTile(
              title: Text('Save Workouts to $sourceName'),
              trailing: CupertinoSwitch(
                value: s.saveToHealthConnect,
                onChanged: (v) => _toggleSave(context, v),
              ),
            ),
          ],
        ),
        GroupedSection(
          header: 'Gym',
          hasLeading: false,
          children: [
            CupertinoListTile(
              title: const Text('Effort Column'),
              trailing: AppSegmented<EffortMode>(
                groupValue: s.effort,
                children: {for (final m in EffortMode.values) m: Text(m.label)},
                onValueChanged: (m) {
                  if (m != null) store.updateSettings(s.copyWith(effort: m));
                },
              ),
            ),
            InfoRow(
              title: 'Default Bar',
              value:
                  barTypes.entries
                      .where((e) => e.value == s.barKg)
                      .firstOrNull
                      ?.key ??
                  Units.weight(s.barKg),
              chevron: true,
              onTap: () async {
                final picked = await showCupertinoModalPopup<double>(
                  context: context,
                  builder: (context) => CupertinoActionSheet(
                    title: const Text('Bar for the Plate Calculator'),
                    actions: [
                      for (final e in barTypes.entries)
                        CupertinoActionSheetAction(
                          onPressed: () => Navigator.pop(context, e.value),
                          child: Text('${e.key} · ${Units.weight(e.value)}'),
                        ),
                    ],
                    cancelButton: CupertinoActionSheetAction(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                );
                if (picked != null) {
                  await store.updateSettings(s.copyWith(barKg: picked));
                }
              },
            ),
            InfoRow(
              title: 'Equipment I Own',
              value: () {
                final n = context.watch<ExerciseStore>().ownedEquipment.length;
                return n == 0 ? 'All' : '$n';
              }(),
              chevron: true,
              onTap: () => EquipmentScreen.open(context),
            ),
          ],
        ),
        GroupedSection(
          header: 'Goals and Timers',
          footer: s.hasWeeklyGoal
              ? 'Health organisations recommend at least 150 minutes of '
                    'activity a week.'
              : 'Turn on a weekly goal to see your progress on Fitness and '
                    'Summary. Workouts are still logged without one.',
          hasLeading: false,
          children: [
            CupertinoListTile(
              title: const Text('Weekly Goal'),
              trailing: CupertinoSwitch(
                value: s.hasWeeklyGoal,
                onChanged: (on) => store.updateSettings(
                  s.copyWith(
                    weeklyGoalMinutes: on
                        ? WorkoutSettings.defaultWeeklyGoal
                        : 0,
                  ),
                ),
              ),
            ),
            if (s.hasWeeklyGoal)
              _StepRow(
                title: 'Minutes Each Week',
                value: '${s.weeklyGoalMinutes} min',
                onMinus: s.weeklyGoalMinutes > 30
                    ? () => store.updateSettings(
                        s.copyWith(weeklyGoalMinutes: s.weeklyGoalMinutes - 15),
                      )
                    : null,
                onPlus: s.weeklyGoalMinutes < 1500
                    ? () => store.updateSettings(
                        s.copyWith(weeklyGoalMinutes: s.weeklyGoalMinutes + 15),
                      )
                    : null,
              ),
            _StepRow(
              title: 'Rest Between Sets',
              value: '${s.restSeconds} s',
              onMinus: s.restSeconds > 15
                  ? () => store.updateSettings(
                      s.copyWith(restSeconds: s.restSeconds - 15),
                    )
                  : null,
              onPlus: s.restSeconds < 600
                  ? () => store.updateSettings(
                      s.copyWith(restSeconds: s.restSeconds + 15),
                    )
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.title,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String title;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return CupertinoListTile(
      title: Text(title),
      subtitle: Text(value),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(AppTheme.minTapTarget),
            onPressed: onMinus,
            child: Icon(
              Icons.remove_circle_rounded,
              semanticLabel: tr('Decrease $title'),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(AppTheme.minTapTarget),
            onPressed: onPlus,
            child: Icon(
              Icons.add_circle_rounded,
              semanticLabel: tr('Increase $title'),
            ),
          ),
        ],
      ),
    );
  }
}
