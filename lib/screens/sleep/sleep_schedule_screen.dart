import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/sleep_schedule.dart';
import 'package:health_app/notifications/notification_controller.dart';
import 'package:health_app/screens/health/picker_sheet.dart';
import 'package:health_app/state/sleep_schedule_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';

/// The sleep schedule colour.
const sleepColor = Palette.indigo;

String _time(ClockTime t) => formatTimeOfDay(t.hour, t.minute);

String _hours(double h) {
  final m = (h * 60).round();
  return m % 60 == 0 ? '${m ~/ 60} hr' : '${m ~/ 60} hr ${m % 60} min';
}

/// Sleep schedule: bedtime, wake time, wind-down reminder and how well
/// recent nights matched.
class SleepScheduleScreen extends StatelessWidget {
  const SleepScheduleScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(
      title: 'Sleep Schedule',
      builder: (_) => const SleepScheduleScreen(),
    ),
  );

  Future<void> _pickTime(
    BuildContext context,
    String title,
    ClockTime initial,
    ValueChanged<ClockTime> onPicked,
  ) async {
    var picked = initial;
    final ok = await showPickerSheet(
      context,
      title: title,
      doneLabel: 'Done',
      picker: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.time,
        minuteInterval: 5,
        initialDateTime: DateTime(
          2000,
          1,
          1,
          initial.hour,
          initial.minute - initial.minute % 5,
        ),
        onDateTimeChanged: (d) => picked = (hour: d.hour, minute: d.minute),
      ),
    );
    if (ok) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SleepScheduleStore>();
    final s = store.schedule;
    final c = store.consistency();
    Future<void> update(SleepSchedule next) async {
      if (next.enabled && next.remind && !(s.enabled && s.remind)) {
        await context
            .read<NotificationController>()
            .notifier
            .requestPermission();
      }
      await store.update(next);
    }

    return CupertinoPageScaffold(
      backgroundColor: context.groupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Sleep Schedule'),
      ),
      child: PageList(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.margin,
          12,
          AppTheme.margin,
          32,
        ),
        children: [
          const BedtimeCard(tappable: false),
          GroupedSection(
            footer: s.enabled
                ? 'Your sleep goal is set to ${_hours(s.goalHours)}, the '
                      'time between bedtime and waking.'
                : 'Turn on to set your sleep goal from your schedule and get '
                      'a reminder to wind down.',
            children: [
              CupertinoListTile(
                leading: const Icon(Icons.bedtime_rounded),
                title: const Text('Sleep Schedule'),
                trailing: CupertinoSwitch(
                  value: s.enabled,
                  onChanged: (on) => update(s.copyWith(enabled: on)),
                ),
              ),
              InfoRow(
                leading: const Icon(Icons.nights_stay_rounded),
                title: 'Bedtime',
                value: _time(s.bedtime),
                chevron: true,
                onTap: () => _pickTime(
                  context,
                  'Bedtime',
                  s.bedtime,
                  (t) => update(s.copyWith(bedtime: t)),
                ),
              ),
              InfoRow(
                leading: const Icon(Icons.wb_sunny_rounded),
                title: 'Wake Up',
                value: _time(s.wake),
                chevron: true,
                onTap: () => _pickTime(
                  context,
                  'Wake Up',
                  s.wake,
                  (t) => update(s.copyWith(wake: t)),
                ),
              ),
            ],
          ),
          GroupedSection(
            header: 'Wind Down',
            footer: s.remind && s.enabled
                ? 'A reminder at ${_time(s.windDownAt)} each night.'
                : null,
            children: [
              CupertinoListTile(
                leading: const Icon(Icons.notifications_rounded),
                title: const Text('Wind-Down Reminder'),
                trailing: CupertinoSwitch(
                  value: s.remind,
                  onChanged: s.enabled
                      ? (on) => update(s.copyWith(remind: on))
                      : null,
                ),
              ),
              for (final m in SleepSchedule.windDownChoices)
                CupertinoListTile(
                  leading: const SizedBox.shrink(),
                  title: Text('$m minutes before bed'),
                  trailing: s.windDown.inMinutes == m
                      ? Icon(Icons.check_rounded, color: context.tint)
                      : null,
                  onTap: s.enabled && s.remind
                      ? () => update(s.copyWith(windDown: Duration(minutes: m)))
                      : null,
                ),
            ],
          ),
          GroupedSection(
            header: 'Last 7 Nights',
            hasLeading: false,
            footer:
                'A night is on target within 30 minutes of your '
                '${_hours(s.goalHours)} goal.',
            children: [
              InfoRow(
                title: 'On Target',
                value: c.nights == 0 ? '–' : '${c.onTarget} of ${c.nights}',
              ),
              InfoRow(
                title: 'Average',
                value: switch (c.average) {
                  final a? => _hours(a),
                  null => '–',
                },
              ),
              InfoRow(
                title: 'Bedtime Streak',
                value: c.streak == 1 ? '1 night' : '${c.streak} nights',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bedtime and wake time with last week's consistency.
class BedtimeCard extends StatelessWidget {
  const BedtimeCard({super.key, this.tappable = true});

  final bool tappable;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SleepScheduleStore>();
    final s = store.schedule;
    final c = store.consistency();
    final color = context.resolve(sleepColor);
    Widget time(String label, ClockTime t, IconData icon) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: context.caption1.copyWith(color: context.secondaryLabel),
              ),
            ],
          ),
          Text(_time(t), style: context.number(22, weight: FontWeight.w600)),
        ],
      ),
    );
    return IosCard(
      onTap: tappable ? () => SleepScheduleScreen.open(context) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.enabled ? 'Sleep Schedule' : 'Sleep Schedule · Off',
            style: context.footnote.copyWith(
              color: context.secondaryLabel,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              time('Bedtime', s.bedtime, Icons.nights_stay_rounded),
              time('Wake Up', s.wake, Icons.wb_sunny_rounded),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 6; i >= 0; i--)
                Expanded(child: _NightDot(daysAgo: i)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            c.streak > 0
                ? '${c.streak}-night bedtime streak · '
                      '${c.onTarget} of ${c.nights} nights on target'
                : c.nights == 0
                ? 'No sleep data this week'
                : '${c.onTarget} of ${c.nights} nights on target',
            style: context.caption1.copyWith(color: context.secondaryLabel),
          ),
        ],
      ),
    );
  }
}

class _NightDot extends StatelessWidget {
  const _NightDot({required this.daysAgo});

  final int daysAgo;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SleepScheduleStore>();
    final hours = store.sleptNightsAgo(daysAgo);
    final color = context.resolve(sleepColor);
    return Center(
      child: Container(
        width: 22,
        height: 8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: hours == null
              ? context.fillColor
              : store.onTarget(hours)
              ? color
              : color.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
