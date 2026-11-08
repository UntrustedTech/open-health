import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart' hide Text;
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/reminder_presets.dart';
import 'package:health_app/notifications/notification_controller.dart';
import 'package:health_app/notifications/reminder_plan.dart';
import 'package:health_app/state/mood_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';

/// Choose which reminders Health sends, and when.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(
      title: 'Notifications',
      builder: (_) => const NotificationSettingsScreen(),
    ),
  );

  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  Future<void> _apply(BuildContext context, NotificationSettings next) async {
    final ok = await context.read<NotificationController>().update(next);
    if (!ok && context.mounted) {
      await showMessage(
        context,
        title: 'Notifications Are Off',
        message:
            'Allow notifications for Health in your phone\'s Settings '
            'to get reminders.',
      );
    }
  }

  /// Shows a time wheel and calls [onPicked] with the chosen hour.
  static Future<void> pickHour(
    BuildContext context,
    int current,
    ValueChanged<int> onPicked,
  ) async {
    var picked = DateTime(2000, 1, 1, current);
    final done = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => Container(
        height: 280,
        color: context.cardBackground,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: CupertinoButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  // Reminders are on the hour.
                  minuteInterval: 60,
                  initialDateTime: picked,
                  onDateTimeChanged: (d) => picked = d,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (done ?? false) onPicked(picked.hour);
  }

  static String _hour(BuildContext context, int h) =>
      TimeOfDayFormat.format(context, h);

  @override
  Widget build(BuildContext context) {
    final s = context.watch<NotificationController>().settings;
    Widget toggle(
      String title,
      bool value,
      NotificationSettings Function(bool) next,
    ) => CupertinoListTile(
      title: Text(title),
      trailing: CupertinoSwitch(
        value: value,
        onChanged: (v) => _apply(context, next(v)),
      ),
    );
    return LargeTitlePage(
      title: 'Notifications',
      children: [
        GroupedSection(
          header: 'Water',
          footer: s.water
              ? 'Every ${s.waterEveryHours} hours from '
                    '${_hour(context, s.waterStartHour)} to '
                    '${_hour(context, s.waterEndHour)}. Skipped when you\'ve '
                    'just logged a glass.'
              : null,
          hasLeading: false,
          children: [
            toggle('Hydration Reminders', s.water, (v) => s.copyWith(water: v)),
            if (s.water) ...[
              InfoRow(
                title: 'Remind Every',
                value: '${s.waterEveryHours} hours',
                onTap: () => _apply(
                  context,
                  s.copyWith(waterEveryHours: s.waterEveryHours % 4 + 1),
                ),
              ),
              InfoRow(
                title: 'From',
                value: _hour(context, s.waterStartHour),
                chevron: true,
                // A start at or after the end moves the end along.
                onTap: () => pickHour(context, s.waterStartHour, (h) {
                  final start = h.clamp(0, 22);
                  _apply(
                    context,
                    s.copyWith(
                      waterStartHour: start,
                      waterEndHour: s.waterEndHour > start
                          ? s.waterEndHour
                          : start + 1,
                    ),
                  );
                }),
              ),
              InfoRow(
                title: 'Until',
                value: _hour(context, s.waterEndHour),
                chevron: true,
                onTap: () => pickHour(context, s.waterEndHour, (h) {
                  final end = h.clamp(1, 23);
                  _apply(
                    context,
                    s.copyWith(
                      waterEndHour: end,
                      waterStartHour: s.waterStartHour < end
                          ? s.waterStartHour
                          : end - 1,
                    ),
                  );
                }),
              ),
            ],
          ],
        ),
        GroupedSection(
          header: 'Activity',
          footer:
              'Tells you what\'s left to close your rings. Skipped once '
              'they\'re all closed.',
          hasLeading: false,
          children: [
            toggle('Close Your Rings', s.rings, (v) => s.copyWith(rings: v)),
            if (s.rings)
              InfoRow(
                title: 'Time',
                value: _hour(context, s.ringsHour),
                chevron: true,
                onTap: () => pickHour(
                  context,
                  s.ringsHour,
                  (h) => _apply(context, s.copyWith(ringsHour: h)),
                ),
              ),
          ],
        ),
        if (context.watch<MoodStore>().habits.isNotEmpty)
          GroupedSection(
            header: 'Habits',
            footer: defaultTargetPlatform == TargetPlatform.android
                ? 'A daily nudge to tick off your habits, skipped once '
                      'they\'re all done. Live Habits keeps a quiet '
                      'notification of the ones left, with a button to tick '
                      'each off.'
                : 'A daily nudge to tick off your habits. Skipped once '
                      'they\'re all done.',
            hasLeading: false,
            children: [
              toggle('Habit Reminder', s.habits, (v) => s.copyWith(habits: v)),
              if (s.habits)
                InfoRow(
                  title: 'Time',
                  value: _hour(context, s.habitsHour),
                  chevron: true,
                  onTap: () => pickHour(
                    context,
                    s.habitsHour,
                    (h) => _apply(context, s.copyWith(habitsHour: h)),
                  ),
                ),
              if (defaultTargetPlatform == TargetPlatform.android)
                toggle(
                  'Live Habits',
                  s.habitsLive,
                  (v) => s.copyWith(habitsLive: v),
                ),
            ],
          ),
        GroupedSection(
          header: 'Workouts',
          hasLeading: false,
          children: [
            toggle(
              'Workout Reminders',
              s.workout,
              (v) => s.copyWith(workout: v),
            ),
            if (s.workout) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var d = 1; d <= 7; d++)
                      DayToggle(
                        letter: _dayLetters[d - 1],
                        label: weekdayNames[d - 1],
                        selected: s.workoutDays.contains(d),
                        onTap: () {
                          final days = {...s.workoutDays};
                          if (!days.remove(d)) days.add(d);
                          _apply(context, s.copyWith(workoutDays: days));
                        },
                      ),
                  ],
                ),
              ),
              InfoRow(
                title: 'Time',
                value: _hour(context, s.workoutHour),
                chevron: true,
                onTap: () => pickHour(
                  context,
                  s.workoutHour,
                  (h) => _apply(context, s.copyWith(workoutHour: h)),
                ),
              ),
            ],
            toggle(
              'Weekly Summary',
              s.weeklySummary,
              (v) => s.copyWith(weeklySummary: v),
            ),
          ],
        ),
      ],
    );
  }
}

/// A round day-of-the-week toggle.
class DayToggle extends StatelessWidget {
  const DayToggle({
    super.key,
    required this.letter,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String letter;

  /// The full day name VoiceOver reads, as letters repeat (T, S).
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: tr(label),
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: AppTheme.minTapTarget,
          child: Center(
            child: AnimatedContainer(
              duration: Motion.reduced(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? context.tint : context.fillColor,
                shape: BoxShape.circle,
              ),
              child: Text(
                letter,
                style: context.subheadline.copyWith(
                  color: selected
                      ? context.onColor(context.tint)
                      : context.labelColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Formats an hour in the user's 12/24-hour style.
abstract final class TimeOfDayFormat {
  static String format(BuildContext context, int hour) {
    final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
    if (use24) return '${hour.toString().padLeft(2, '0')}:00';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h ${hour < 12 ? 'AM' : 'PM'}';
  }
}
