import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/export/share_files.dart';
import 'package:health_app/insights/monthly_recap.dart';
import 'package:health_app/state/achievement_store.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/mood_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/utils/log.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/app_chip.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';

/// The recap for [month], from the stores.
MonthlyRecap recapFor(BuildContext context, DateTime month) {
  final health = context.read<HealthStore>();
  return MonthlyRecap.build(
    month: month,
    today: health.today,
    dailyValue: health.dailyValue,
    goalFor: health.goals.forMetric,
    sessions: context.read<WorkoutStore>().all,
  );
}

NumberFormat get _count => cachedFormat('grouped', NumberFormat.decimalPattern);

/// "Your October": a month in numbers, shareable as an image.
class RecapScreen extends StatefulWidget {
  const RecapScreen({super.key, this.month});

  /// Any day in the month to show; this month by default.
  final DateTime? month;

  static Future<void> open(BuildContext context, {DateTime? month}) =>
      Navigator.of(context).push(
        AppRoute<void>(
          title: 'Monthly Recap',
          builder: (_) => RecapScreen(month: month),
        ),
      );

  @override
  State<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends State<RecapScreen> {
  final _poster = GlobalKey();
  late DateTime _month = () {
    final m = widget.month ?? context.read<HealthStore>().today;
    return DateTime(m.year, m.month);
  }();
  bool _sharing = false;

  /// This month and the five before it.
  List<DateTime> get _months {
    final t = context.read<HealthStore>().today;
    return [for (var i = 0; i < 6; i++) DateTime(t.year, t.month - i)];
  }

  Future<void> _share() async {
    final boundary =
        _poster.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) return;
      final dir = await ShareFiles.prepare();
      final name = DateFormat('MMMM-yyyy', 'en_US').format(_month);
      final file = File('${dir.path}/Health-$name.png');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'My ${DateFormat.MMMM().format(_month)} in Health',
        ),
      );
    } on Exception catch (e) {
      logError('Recap share failed: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<HealthStore>();
    context.watch<WorkoutStore>();
    final r = recapFor(context, _month);
    return CupertinoPageScaffold(
      backgroundColor: context.groupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Monthly Recap'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: r.isEmpty || _sharing ? null : _share,
          child: const Icon(Icons.ios_share_rounded),
        ),
      ),
      child: PageList(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.margin,
          12,
          AppTheme.margin,
          32,
        ),
        children: [
          ChipRow(
            children: [
              for (final m in _months)
                AppChip(
                  label: DateFormat.MMM().format(m),
                  selected: m == _month,
                  onTap: () => setState(() => _month = m),
                ),
            ],
          ),
          const SizedBox(height: 12),
          RepaintBoundary(
            key: _poster,
            child: _Poster(recap: r),
          ),
          const SizedBox(height: 12),
          if (!r.isEmpty)
            CupertinoButton(
              color: context.labelColor,
              borderRadius: BorderRadius.circular(14),
              onPressed: _sharing ? null : _share,
              child: Text(
                'Share Recap',
                style: context.headline.copyWith(color: context.onLabel),
              ),
            ),
        ],
      ),
    );
  }
}

/// The recap itself, also captured as the shared image.
class _Poster extends StatelessWidget {
  const _Poster({required this.recap});

  final MonthlyRecap recap;

  @override
  Widget build(BuildContext context) {
    final r = recap;
    final today = context.read<HealthStore>().today;
    final current = r.month.year == today.year && r.month.month == today.month;
    final moods = context.watch<MoodStore>().days.entries.where(
      (e) => e.key.year == r.month.year && e.key.month == r.month.month,
    );
    final mood = moods.isEmpty
        ? null
        : moods.fold(0, (s, e) => s + e.value.mood.value) / moods.length;
    final medals = context.watch<AchievementStore>().medals;
    final weight = r.weightChangeKg;
    final stats = <(IconData, Color, String, String)>[
      (
        Icons.directions_walk_rounded,
        Palette.orange,
        _count.format(r.steps.round()),
        'steps',
      ),
      (
        Icons.calendar_today_rounded,
        Palette.green,
        '${r.activeDays} of ${r.days}',
        'active days',
      ),
      (
        Icons.fitness_center_rounded,
        Palette.mint,
        '${r.workouts}',
        r.workouts == 1 ? 'workout' : 'workouts',
      ),
      (
        Icons.timer_rounded,
        Palette.mint,
        formatMinutes(Duration(minutes: r.workoutMinutes)),
        'training',
      ),
      if (r.distanceKm > 0)
        (
          Icons.route_rounded,
          Palette.blue,
          '${Units.distanceOut(r.distanceKm).toStringAsFixed(1)} '
              '${Units.distanceUnit}',
          'workout distance',
        ),
      (
        Icons.donut_large_rounded,
        Palette.red,
        '${r.ringDays}',
        r.ringDays == 1 ? 'day all rings' : 'days all rings',
      ),
      if (r.averageSleep case final s?)
        (Icons.bed_rounded, Palette.indigo, formatHours(s), 'average sleep'),
      if (r.averageRestingHeart case final h?)
        (
          Icons.favorite_rounded,
          Palette.red,
          '${h.round()} bpm',
          'resting heart rate',
        ),
      if (weight != null)
        (
          Icons.monitor_weight_rounded,
          Palette.purple,
          '${weight > 0
                  ? '+'
                  : weight < 0
                  ? '−'
                  : ''}'
              '${Units.weight(weight.abs())}',
          'weight change',
        ),
      if (mood != null)
        (
          Icons.emoji_emotions_rounded,
          Palette.yellow,
          '${mood.toStringAsFixed(1)} / 5',
          'average mood',
        ),
    ];
    return IosCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            current ? 'SO FAR THIS MONTH' : DateFormat.y().format(r.month),
            style: context.overline,
          ),
          Text(
            'Your ${DateFormat.MMMM().format(r.month)}',
            style: context.title1,
          ),
          if (r.bestStepDay case final d? when r.bestSteps > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Best day: ${DateFormat.MMMMd().format(d)} with '
              '${_count.format(r.bestSteps.round())} steps'
              '${r.topWorkout == null ? '' : '. Favourite workout: '
                        '${r.topWorkout!.label}'}.',
              style: context.subheadline.copyWith(
                color: context.secondaryLabel,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (r.isEmpty)
            Text(
              'Nothing recorded this month yet.',
              style: context.subheadline.copyWith(
                color: context.secondaryLabel,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final w = (c.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  children: [
                    for (final (icon, color, value, label) in stats)
                      SizedBox(
                        width: w,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icon, size: 18, color: context.resolve(color)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    value,
                                    style: context.number(
                                      18,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    label,
                                    style: context.caption1.copyWith(
                                      color: context.secondaryLabel,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.monitor_heart_rounded,
                size: 14,
                color: context.tertiaryLabel,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Health · $medals medals earned so far',
                  style: context.caption2.copyWith(
                    color: context.tertiaryLabel,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Summary card for the recap: this month (or last month, early on).
class RecapCard extends StatelessWidget {
  const RecapCard({super.key});

  @override
  Widget build(BuildContext context) {
    final today = context.select<HealthStore, DateTime>((s) => s.today);
    context.watch<WorkoutStore>();
    // In the first week the month has barely started: show last month.
    final month = today.day <= 7
        ? DateTime(today.year, today.month - 1)
        : DateTime(today.year, today.month);
    final r = recapFor(context, month);
    return IosCard(
      onTap: () => RecapScreen.open(context, month: month),
      child: Row(
        children: [
          IconTile(
            icon: Icons.auto_graph_rounded,
            color: Palette.purple,
            size: 40,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your ${DateFormat.MMMM().format(month)}',
                  style: context.headline,
                ),
                Text(
                  r.isEmpty
                      ? 'Your monthly recap'
                      : '${_count.format(r.steps.round())} steps · '
                            '${r.workouts} '
                            '${r.workouts == 1 ? 'workout' : 'workouts'} · '
                            '${r.activeDays} active days',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.footnote.copyWith(
                    color: context.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.tertiaryLabel),
        ],
      ),
    );
  }
}
