import 'dart:math' as math;

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/cycle.dart';
import 'package:health_app/screens/cycle/cycle_day_sheet.dart';
import 'package:health_app/state/cycle_store.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/sync/health_sync_service.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';

/// Period colour, as in Apple Health's Cycle Tracking.
const periodColor = Color(0xFFFF4D8D);
const fertileColor = Color(0xFF64D2FF);

/// Cycle Tracking: the current cycle, a calendar and cycle history.
class CycleScreen extends StatelessWidget {
  const CycleScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(
      title: 'Cycle Tracking',
      builder: (_) => const CycleScreen(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cycle = context.watch<CycleStore>();
    return CupertinoPageScaffold(
      backgroundColor: context.groupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Cycle Tracking'),
      ),
      child: cycle.enabled ? const _Tracking() : const _Intro(),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return PageList(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
      children: [
        const Center(
          child: IconTile(
            icon: Icons.donut_large_rounded,
            color: periodColor,
            size: 80,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Cycle Tracking',
          textAlign: TextAlign.center,
          style: context.title1,
        ),
        const SizedBox(height: 8),
        Text(
          'Log your period and symptoms to see predictions for your next '
          'period and fertile window. Everything stays on this phone.',
          textAlign: TextAlign.center,
          style: context.body.copyWith(color: context.secondaryLabel),
        ),
        const SizedBox(height: 24),
        CupertinoButton.filled(
          onPressed: () => context.read<CycleStore>().setEnabled(true),
          child: const Text('Get Started'),
        ),
        const SizedBox(height: 16),
        Text(
          'Predictions are estimates and must not be used for contraception.',
          textAlign: TextAlign.center,
          style: context.footnote.copyWith(color: context.secondaryLabel),
        ),
      ],
    );
  }
}

class _Tracking extends StatefulWidget {
  const _Tracking();

  @override
  State<_Tracking> createState() => _TrackingState();
}

class _TrackingState extends State<_Tracking> {
  late DateTime _month = () {
    final t = context.read<HealthStore>().today;
    return DateTime(t.year, t.month);
  }();

  bool _importing = false;

  Future<void> _import(DateTime today) async {
    final sync = context.read<HealthSyncService>();
    final cycle = context.read<CycleStore>();
    final source = sync.sourceName;
    setState(() => _importing = true);
    final days = await sync.readPeriodDays(today);
    final added = days == null ? null : await cycle.importDays(days);
    if (!mounted) return;
    setState(() => _importing = false);
    await showMessage(
      context,
      title: switch (added) {
        null => "Couldn't Read $source",
        0 => 'Nothing to Add',
        1 => '1 Day Added',
        final n => '$n Days Added',
      },
      message: switch (added) {
        null =>
          'Make sure Health is allowed to read menstruation, then try '
              'again.',
        0 => "$source has no period days that aren't already here.",
        _ => 'Your predictions now include them.',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cycle = context.watch<CycleStore>();
    final today = context.select<HealthStore, DateTime>((s) => s.today);
    final f = cycle.forecast;
    return PageList(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.margin,
        8,
        AppTheme.margin,
        32,
      ),
      children: [
        Appear(
          child: CycleSummaryCard(forecast: f, today: today),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CupertinoButton.tinted(
                color: periodColor,
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  cycle.startPeriod(today);
                },
                child: Text(
                  'Period Started',
                  style: context.body.copyWith(
                    color: periodColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            CupertinoButton.tinted(
              onPressed: () => CycleDaySheet.show(context, today),
              child: Text(
                'Log Today',
                style: context.body.copyWith(
                  color: context.tint,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        IosCard(
          child: _MonthCalendar(
            month: _month,
            today: today,
            onMonth: (m) => setState(() => _month = m),
          ),
        ),
        const _Legend(),
        GroupedSection(
          header: 'Your Averages',
          footer: f.basedOn == 0
              ? 'Averages use typical values until you log two periods.'
              : 'Based on your last ${f.basedOn} '
                    '${f.basedOn == 1 ? 'cycle' : 'cycles'}.',
          hasLeading: false,
          children: [
            InfoRow(title: 'Cycle Length', value: '${f.cycleLength} days'),
            InfoRow(title: 'Period Length', value: '${f.periodLength} days'),
          ],
        ),
        if (f.periods.isNotEmpty)
          GroupedSection(
            header: 'Recent Periods',
            hasLeading: false,
            children: [
              for (final p in f.periods.reversed.take(6))
                InfoRow(
                  title: DateFormat.yMMMd().format(p.start),
                  value: '${daysBetween(p.start, p.end) + 1} days',
                ),
            ],
          ),
        GroupedSection(
          footer:
              'Adds period days logged in other apps. Days you logged here '
              'are kept as they are.',
          children: [
            InfoRow(
              leading: const IconTile(
                icon: Icons.download_rounded,
                color: periodColor,
              ),
              title:
                  'Import from ${context.read<HealthSyncService>().sourceName}',
              titleColor: context.tint,
              trailing: _importing ? const CupertinoActivityIndicator() : null,
              onTap: _importing ? null : () => _import(today),
            ),
          ],
        ),
        GroupedSection(
          hasLeading: false,
          footer:
              'Predictions are estimates based on what you log and must not '
              'be used for contraception.',
          children: [
            CupertinoListTile(
              title: Text(
                'Turn Off Cycle Tracking',
                style: TextStyle(color: context.destructive),
              ),
              onTap: () async {
                final store = context.read<CycleStore>();
                final ok = await confirmDestructive(
                  context,
                  title: 'Turn Off Cycle Tracking?',
                  message:
                      'Your logged days are kept and come back if you turn it '
                      'on again.',
                  action: 'Turn Off',
                );
                if (ok) await store.setEnabled(false);
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// "Day 12 · Period in 16 days" with the current phase.
class CycleSummaryCard extends StatelessWidget {
  const CycleSummaryCard({
    super.key,
    required this.forecast,
    required this.today,
    this.onTap,
  });

  final CycleForecast forecast;
  final DateTime today;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final f = forecast;
    final next = f.nextStart;
    final until = next == null ? null : daysBetween(today, next);
    final headline = switch (until) {
      null => 'Log your period to see predictions',
      0 => 'Period expected today',
      1 => 'Period expected tomorrow',
      final n => 'Period in $n days',
    };
    return IosCard(
      onTap: onTap,
      child: Row(
        children: [
          SizedBox.square(
            dimension: 70,
            child: CustomPaint(
              painter: _CycleRing(
                day: f.cycleDay,
                length: f.cycleLength,
                periodLength: f.periodLength,
                track: context.fillColor,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'DAY',
                      style: context.caption2.copyWith(
                        color: context.secondaryLabel,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      f.cycleDay == null ? '–' : '${f.cycleDay}',
                      style: context.number(22),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cycle Tracking',
                  style: context.subheadline.copyWith(
                    color: context.labelColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(headline, style: context.headline),
                if (f.phase case final p?)
                  Text(
                    p == CyclePhase.fertile
                        ? 'In your estimated fertile window'
                        : '${p.label} phase',
                    style: context.footnote.copyWith(
                      color: context.secondaryLabel,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CycleRing extends CustomPainter {
  _CycleRing({
    required this.day,
    required this.length,
    required this.periodLength,
    required this.track,
  });

  final int? day;
  final int length;
  final int periodLength;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const full = 6.2832, top = -1.5708;
    final rect = (Offset.zero & size).deflate(4);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, full, false, paint..color = track);
    // Period days, then the fertile window (14 days before the end).
    canvas.drawArc(
      rect,
      top,
      full * periodLength / length,
      false,
      paint..color = periodColor.withValues(alpha: 0.85),
    );
    final fertileFrom = (length - 19) / length;
    canvas.drawArc(
      rect,
      top + full * fertileFrom,
      full * 7 / length,
      false,
      paint..color = fertileColor.withValues(alpha: 0.85),
    );
    final d = day;
    if (d == null) return;
    final angle = top + full * ((d - 0.5) / length).clamp(0, 1);
    final c = rect.center;
    final r = rect.width / 2;
    final dot = Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));
    canvas.drawCircle(dot, 6, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawCircle(
      dot,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x33000000),
    );
  }

  @override
  bool shouldRepaint(_CycleRing old) =>
      old.day != day || old.length != length || old.track != track;
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Widget dot, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(width: 6),
        Text(
          label,
          style: context.footnote.copyWith(color: context.secondaryLabel),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          item(const _Dot(fill: periodColor), 'Period'),
          item(const _Dot(outline: periodColor), 'Predicted Period'),
          item(const _Dot(fill: fertileColor), 'Fertile Window'),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({this.fill, this.outline, this.size = 10});

  final Color? fill;
  final Color? outline;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: fill,
      shape: BoxShape.circle,
      border: outline == null ? null : Border.all(color: outline!, width: 1.5),
    ),
  );
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.today,
    required this.onMonth,
  });

  final DateTime month;
  final DateTime today;
  final ValueChanged<DateTime> onMonth;

  @override
  Widget build(BuildContext context) {
    final cycle = context.watch<CycleStore>();
    final f = cycle.forecast;
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Weeks start on Monday.
    final lead = first.weekday - 1;
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                DateFormat.yMMMM().format(first),
                style: context.headline,
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size.square(AppTheme.minTapTarget),
              onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
              child: Icon(
                Icons.chevron_left_rounded,
                semanticLabel: tr('Previous month'),
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size.square(AppTheme.minTapTarget),
              onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
              child: Icon(
                Icons.chevron_right_rounded,
                semanticLabel: tr('Next month'),
              ),
            ),
          ],
        ),
        Row(
          children: [
            for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: context.caption1.copyWith(
                    color: context.secondaryLabel,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: switch (r * 7 + c - lead + 1) {
                    final n when n >= 1 && n <= daysInMonth => _DayCell(
                      day: DateTime(month.year, month.month, n),
                      today: today,
                      logged: cycle.dayOf(DateTime(month.year, month.month, n)),
                      predicted: f.isPredictedPeriod(
                        DateTime(month.year, month.month, n),
                      ),
                      fertile: f.isFertile(
                        DateTime(month.year, month.month, n),
                      ),
                    ),
                    _ => const SizedBox(height: 44),
                  },
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.today,
    required this.logged,
    required this.predicted,
    required this.fertile,
  });

  final DateTime day;
  final DateTime today;
  final CycleDay logged;
  final bool predicted;
  final bool fertile;

  @override
  Widget build(BuildContext context) {
    final isToday = day == today;
    final future = day.isAfter(today);
    final flow = logged.flow;
    final hasPeriod = flow != null && flow.isPeriod;
    final spotting = flow == PeriodFlow.spotting;
    final label = [
      DateFormat.MMMMd().format(day),
      if (flow != null) '${flow.label} flow',
      if (logged.symptoms.isNotEmpty) '${logged.symptoms.length} symptoms',
      if (predicted && flow == null) 'predicted period',
      if (fertile) 'fertile window',
    ].join(', ');
    final onTap = future ? null : () => CycleDaySheet.show(context, day);
    return Semantics(
      container: true,
      button: !future,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: Motion.reduced(context)
                      ? Duration.zero
                      : Motion.fast,
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasPeriod
                        ? periodColor
                        : fertile && flow == null
                        ? fertileColor.withValues(alpha: 0.35)
                        : null,
                    border: predicted && flow == null
                        ? Border.all(color: periodColor, width: 1.5)
                        : isToday
                        ? Border.all(color: context.labelColor, width: 1.5)
                        : null,
                  ),
                ),
                Text(
                  '${day.day}',
                  style: context.subheadline.copyWith(
                    color: hasPeriod
                        ? CupertinoColors.white
                        : future
                        ? context.tertiaryLabel
                        : context.labelColor,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (spotting || logged.symptoms.isNotEmpty)
                  Positioned(
                    bottom: 2,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (spotting) const _Dot(fill: periodColor, size: 5),
                        if (logged.symptoms.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: _Dot(
                              size: 5,
                              fill: hasPeriod
                                  ? CupertinoColors.white
                                  : context.resolve(Palette.purple),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
