import 'dart:async';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/fasting.dart';
import 'package:health_app/notifications/notification_controller.dart';
import 'package:health_app/screens/health/picker_sheet.dart';
import 'package:health_app/state/fasting_store.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/widgets/app_chip.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/progress_ring.dart';

/// The fasting timer colour.
const fastingColor = Palette.indigo;

/// A time, with "yesterday" or "tomorrow" when it isn't today.
String _when(DateTime t, DateTime now) {
  // UTC dates, so a 23-hour day (clocks going forward) still counts as one.
  final days = DateTime.utc(
    t.year,
    t.month,
    t.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  return switch (days) {
    0 => formatTime(t),
    1 => '${formatTime(t)} tomorrow',
    -1 => '${formatTime(t)} yesterday',
    _ => '${DateFormat.MMMd().format(t)}, ${formatTime(t)}',
  };
}

/// "15:42" style hours and minutes.
String _hm(Duration d) =>
    '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}';

/// Rebuilds [builder] with the current time every [_interval], so running
/// timers (shown in hours and minutes) stay live.
class _Ticking extends StatefulWidget {
  const _Ticking({required this.builder});

  static const _interval = Duration(seconds: 20);

  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<_Ticking> createState() => _TickingState();
}

class _TickingState extends State<_Ticking> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_Ticking._interval, (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, context.read<HealthStore>().now);
}

/// Intermittent fasting: a live timer, presets, stages and history.
class FastingScreen extends StatelessWidget {
  const FastingScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(title: 'Fasting', builder: (_) => const FastingScreen()),
  );

  @override
  Widget build(BuildContext context) {
    final fasting = context.watch<FastingStore>();
    return CupertinoPageScaffold(
      backgroundColor: context.groupedBackground,
      navigationBar: const CupertinoNavigationBar(middle: Text('Fasting')),
      child: PageList(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.margin,
          12,
          AppTheme.margin,
          32,
        ),
        children: [
          const _Timer(),
          const SectionTitle('Schedule'),
          Wrap(
            spacing: 8,
            runSpacing: 0,
            children: [
              for (final p in FastingPreset.values)
                AppChip(
                  label: p.label,
                  selected: p == fasting.preset,
                  onTap: () => fasting.setPreset(p),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            fasting.preset.detail,
            style: context.footnote.copyWith(color: context.secondaryLabel),
          ),
          const SectionTitle('Stages'),
          _Stages(started: fasting.started),
          if (fasting.history.isNotEmpty) ...[
            SectionTitle(
              'History',
              action: fasting.streak > 0
                  ? '${fasting.streak}-day streak'
                  : null,
            ),
            GroupedSection(
              children: [
                for (final f in fasting.history.take(14))
                  InfoRow(
                    leading: Icon(
                      f.reachedGoal
                          ? Icons.check_circle_rounded
                          : Icons.timelapse_rounded,
                      color: f.reachedGoal
                          ? context.resolve(Palette.green)
                          : context.tertiaryLabel,
                    ),
                    title: _hm(f.length),
                    subtitle:
                        '${DateFormat.MMMEd().format(f.start)}, '
                        '${formatTime(f.start)} – ${formatTime(f.end)}',
                    value: 'Goal ${f.goal.inHours} h',
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Fasting isn\'t right for everyone. Talk to your doctor first if '
            'you are pregnant, have diabetes, take medication or have a '
            'history of eating disorders.',
            style: context.footnote.copyWith(color: context.secondaryLabel),
          ),
        ],
      ),
    );
  }
}

class _Timer extends StatelessWidget {
  const _Timer();

  Future<void> _start(BuildContext context) async {
    HapticFeedback.mediumImpact();
    // The end-of-fast notification needs permission on Android 13+.
    await context.read<NotificationController>().notifier.requestPermission();
    if (!context.mounted) return;
    await context.read<FastingStore>().start();
  }

  Future<void> _startEarlier(BuildContext context) async {
    final now = context.read<HealthStore>().now;
    var picked = now.subtract(const Duration(hours: 1));
    final ok = await showPickerSheet(
      context,
      title: 'Last Meal',
      doneLabel: 'Start',
      picker: CupertinoDatePicker(
        initialDateTime: picked,
        minimumDate: now.subtract(const Duration(hours: 48)),
        maximumDate: now,
        onDateTimeChanged: (d) => picked = d,
      ),
    );
    if (!ok || !context.mounted) return;
    await context.read<NotificationController>().notifier.requestPermission();
    if (!context.mounted) return;
    await context.read<FastingStore>().start(at: picked);
  }

  Future<void> _end(BuildContext context) async {
    final fasting = context.read<FastingStore>();
    final now = context.read<HealthStore>().now;
    if (fasting.elapsed(now) < fasting.goal) {
      final ok = await confirmDestructive(
        context,
        title: 'End Fast Early?',
        message:
            'You\'ve fasted ${_hm(fasting.elapsed(now))} of your '
            '${fasting.goal.inHours}-hour goal.',
        action: 'End Fast',
      );
      if (!ok) return;
    }
    HapticFeedback.mediumImpact();
    await fasting.end();
  }

  @override
  Widget build(BuildContext context) {
    final fasting = context.watch<FastingStore>();
    final color = context.resolve(fastingColor);
    return IosCard(
      padding: const EdgeInsets.all(20),
      child: _Ticking(
        builder: (context, now) {
          final started = fasting.started;
          final elapsed = fasting.elapsed(now);
          final goal = fasting.goal;
          final left = goal - elapsed;
          return Column(
            children: [
              ProgressRing(
                progress: started == null
                    ? 0
                    : elapsed.inSeconds / goal.inSeconds,
                color: color,
                size: 200,
                stroke: 14,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      started == null ? 'Not Fasting' : 'Fasting',
                      style: context.footnote.copyWith(
                        color: context.secondaryLabel,
                      ),
                    ),
                    Text(
                      started == null ? '0:00' : _hm(elapsed),
                      style: context.number(40, weight: FontWeight.w600),
                    ),
                    Text(
                      started == null
                          ? '${fasting.preset.label} goal'
                          : left > Duration.zero
                          ? '${_hm(left)} to go'
                          : 'Goal reached',
                      style: context.footnote.copyWith(
                        color: context.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              if (started != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Started ${_when(started, now)} · ends '
                  '${_when(started.add(goal), now)}',
                  style: context.footnote.copyWith(
                    color: context.secondaryLabel,
                  ),
                ),
                Text(
                  FastingStage.at(elapsed).label,
                  style: context.subheadline.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: started == null ? context.labelColor : null,
                  borderRadius: BorderRadius.circular(14),
                  onPressed: () =>
                      started == null ? _start(context) : _end(context),
                  child: Text(
                    started == null ? 'Start Fast' : 'End Fast',
                    style: context.headline.copyWith(
                      color: started == null
                          ? context.onLabel
                          : context.destructive,
                    ),
                  ),
                ),
              ),
              if (started == null)
                CupertinoButton(
                  onPressed: () => _startEarlier(context),
                  child: Text(
                    'I Already Started…',
                    style: context.subheadline.copyWith(color: context.tint),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Stages extends StatelessWidget {
  const _Stages({required this.started});

  final DateTime? started;

  @override
  Widget build(BuildContext context) => _Ticking(
    builder: (context, now) {
      final s = started;
      final current = s == null ? null : FastingStage.at(now.difference(s));
      return GroupedSection(
        hasLeading: false,
        footer: 'A general guide; every body is different.',
        children: [
          for (final stage in FastingStage.values)
            InfoRow(
              title: stage.label,
              subtitle: stage.detail,
              value: '${stage.fromHours}+ h',
              titleColor: stage == current
                  ? context.resolve(fastingColor)
                  : null,
            ),
        ],
      );
    },
  );
}

/// Summary card: the running fast, or a button to start one.
class FastingCard extends StatelessWidget {
  const FastingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final fasting = context.watch<FastingStore>();
    final color = context.resolve(fastingColor);
    return IosCard(
      onTap: () => FastingScreen.open(context),
      child: _Ticking(
        builder: (context, now) {
          final started = fasting.started;
          final elapsed = fasting.elapsed(now);
          final last = fasting.history.firstOrNull;
          return Row(
            children: [
              ProgressRing(
                progress: started == null
                    ? 0
                    : elapsed.inSeconds / fasting.goal.inSeconds,
                color: color,
                size: 64,
                stroke: 7,
                child: Icon(
                  Icons.hourglass_bottom_rounded,
                  color: started == null ? context.tertiaryLabel : color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fasting · ${fasting.preset.label}',
                      style: context.footnote.copyWith(
                        color: context.secondaryLabel,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      started == null ? 'Not fasting' : _hm(elapsed),
                      style: context.title3,
                    ),
                    Text(
                      started != null
                          ? FastingStage.at(elapsed).label
                          : last == null
                          ? 'Tap to start your first fast'
                          : 'Last fast ${_hm(last.length)}',
                      style: context.footnote.copyWith(
                        color: context.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
