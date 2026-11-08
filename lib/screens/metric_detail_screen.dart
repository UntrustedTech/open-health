import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/widgets/number_input.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/insights/weight_trend.dart';
import 'package:health_app/screens/add_entry_sheet.dart';
import 'package:health_app/screens/goal/check_in_card.dart' show weighInsOf;
import 'package:health_app/screens/all_data_screen.dart';
import 'package:health_app/screens/body/progress_photos_screen.dart';
import 'package:health_app/screens/heart_day_panel.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/sync/health_sync_service.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/bar_chart.dart';
import 'package:health_app/widgets/detail_cards.dart';
import 'package:health_app/widgets/line_chart.dart';
import 'package:health_app/widgets/metric_chip.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/metric_card.dart';
import 'package:health_app/widgets/app_segmented.dart';

enum ChartRange {
  /// Every reading of one day; heart rate only.
  day('D', 1),
  week('W', 7),
  month('M', 30),
  sixMonths('6M', 6),
  year('Y', 12);

  const ChartRange(this.label, this.count);

  final String label;

  /// Number of bars: days for D/W/M, months for 6M/Y.
  final int count;

  bool get isMonthly => this == sixMonths || this == year;
}

class MetricDetailScreen extends StatefulWidget {
  const MetricDetailScreen({super.key, required this.type});

  final MetricType type;

  static Future<void> open(BuildContext context, MetricType type) =>
      Navigator.of(context).push(
        AppRoute<void>(
          title: type.label,
          builder: (_) => MetricDetailScreen(type: type),
        ),
      );

  @override
  State<MetricDetailScreen> createState() => _MetricDetailScreenState();
}

/// Average, lowest and highest over [values], oldest first. A running total
/// (steps, water) for the current day or month is still growing, so it's left
/// out; sleep is the exception, as last night is already over.
@visibleForTesting
RangeStats? rangeStats(MetricType type, List<double?> values) {
  final partial =
      type.aggregation == Aggregation.sum &&
      type != MetricType.sleep &&
      values.nonNulls.length > 1;
  return HealthStore.statsOf(
    partial ? values.sublist(0, values.length - 1) : values,
  );
}

class _MetricDetailScreenState extends State<MetricDetailScreen> {
  // Heart Rate opens on its Day tab: every reading of today.
  late ChartRange _range = widget.type == MetricType.heartRate
      ? ChartRange.day
      : ChartRange.week;
  int? _selected;

  MetricType get type => widget.type;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final today = store.today;

    final values = _range.isMonthly
        ? store.monthlySeries(type, end: today, months: _range.count)
        : store.dailySeries(type, end: today, days: _range.count);
    final dates = [
      for (var i = _range.count - 1; i >= 0; i--)
        _range.isMonthly
            ? DateTime(today.year, today.month - i)
            : DateTime(today.year, today.month, today.day - i),
    ];
    final labels = [for (var i = 0; i < dates.length; i++) _label(dates[i], i)];
    final stats = rangeStats(type, values);
    final goal = store.goals.forMetric(type);
    final weightPoints = [
      if (type == MetricType.weight)
        for (var i = 0; i < values.length; i++)
          if (values[i] case final v?)
            (
              // Monthly points stand for the month's last day.
              date: _range.isMonthly
                  ? DateTime(dates[i].year, dates[i].month + 1, 0)
                  : dates[i],
              value: v,
            ),
    ];

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(type.label),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => AddEntrySheet.show(context, type),
          child: const Text('Add Data'),
        ),
      ),
      child: PageList(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.margin,
          12,
          AppTheme.margin,
          40,
        ),
        children: [
          SizedBox(
            width: double.infinity,
            child: AppSegmented<ChartRange>(
              groupValue: _range,
              children: {
                for (final r in ChartRange.values)
                  if (r != ChartRange.day || type == MetricType.heartRate)
                    r: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(r.label),
                    ),
              },
              onValueChanged: (r) => setState(() {
                if (r != null) _range = r;
                _selected = null;
              }),
            ),
          ),
          const SizedBox(height: 16),
          if (_range == ChartRange.day) ...[
            const HeartDayPanel(),
            _OptionsSection(type: type),
            _AboutSection(type: type),
          ] else ...[
            _Headline(
              type: type,
              range: _range,
              values: values,
              dates: dates,
              stats: stats,
              selected: _selected,
            ),
            if (store.liveReading(type) case final live?
                when _isToday(live.at, today))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Latest ${formatValue(type, live.value)} ${unitLabel(type)} '
                  'at ${formatTimeOfDay(live.at.hour, live.at.minute)}',
                  style: context.subheadline.copyWith(
                    color: context.resolve(type.color),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            IosCard(
              child: type == MetricType.weight
                  ? TrendLineChart(
                      points: weightPoints,
                      trend: switch (weightPoints.length < 2
                          ? const <double>[]
                          : trendOn(weighInsOf(store), [
                              for (final p in weightPoints) p.date,
                            ])) {
                        final t when t.length == weightPoints.length => t,
                        _ => null,
                      },
                      color: type.color,
                      goal: store.goals.weightKg,
                      format: Units.weight,
                      // At least 2 kg tall, so a few hundred grams of daily
                      // wobble stays a gentle line.
                      minSpan: 2,
                      emptyText: 'Log your weight on two days to see a trend.',
                    )
                  : BarChart(
                      values: values,
                      labels: labels,
                      color: type.color,
                      goal: _range.isMonthly ? null : goal,
                      selected: _selected,
                      axisLabel: (v) => NumberFormat.compact().format(
                        type.isDuration ? v.round() : Units.toDisplay(type, v),
                      ),
                      onSelect: (i) {
                        if (i != _selected) HapticFeedback.selectionClick();
                        setState(() => _selected = _selected == i ? null : i);
                      },
                    ),
            ),
            if (type == MetricType.weight) const _BodySection(),
            if (type.isDuration) const SleepStagesCard(),
            if (type == MetricType.heartRate) const HeartZonesCard(),
            if (stats != null && type.aggregation != Aggregation.latest)
              GroupedSection(
                header: 'Highlights',
                hasLeading: false,
                children: [
                  _statRow(context, 'Average', stats.average),
                  _statRow(context, 'Lowest', stats.min),
                  _statRow(context, 'Highest', stats.max),
                ],
              ),
            if (goal != null)
              _GoalSection(
                type: type,
                goal: goal,
                values: values,
                isMonthly: _range.isMonthly,
              ),
            _OptionsSection(type: type),
            _AboutSection(type: type),
          ],
        ],
      ),
    );
  }

  Widget _statRow(BuildContext context, String label, double value) => InfoRow(
    title: label,
    value: '${formatValue(type, value)} ${unitLabel(type)}'.trim(),
  );

  String _label(DateTime date, int index) => switch (_range) {
    ChartRange.day => '',
    ChartRange.week => DateFormat('EEEEE').format(date),
    ChartRange.month => index % 7 == 0 ? DateFormat.d().format(date) : '',
    ChartRange.sixMonths => DateFormat.MMM().format(date),
    ChartRange.year => DateFormat('MMMMM').format(date),
  };
}

/// "DAILY AVERAGE / 8,421 steps / Oct 5 – 11, 2026" above the chart, or the
/// selected bar's value.
bool _isToday(DateTime at, DateTime today) =>
    at.year == today.year && at.month == today.month && at.day == today.day;

class _Headline extends StatelessWidget {
  const _Headline({
    required this.type,
    required this.range,
    required this.values,
    required this.dates,
    required this.stats,
    required this.selected,
  });

  final MetricType type;
  final ChartRange range;
  final List<double?> values;
  final List<DateTime> dates;
  final RangeStats? stats;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final String caption;
    final double? value;
    final String period;
    final sel = selected;
    if (sel != null && sel < values.length) {
      value = values[sel];
      caption = range.isMonthly ? 'DAILY AVERAGE' : _aggregationLabel;
      period = range.isMonthly
          ? DateFormat.yMMMM().format(dates[sel])
          : DateFormat.yMMMEd().format(dates[sel]);
    } else {
      final latest = type.aggregation == Aggregation.latest;
      value = latest ? values.nonNulls.lastOrNull : stats?.average;
      caption = latest
          ? 'LATEST'
          : type.aggregation == Aggregation.sum
          ? 'DAILY AVERAGE'
          : 'AVERAGE';
      final fmtStart = range.isMonthly ? DateFormat.yMMM() : DateFormat.MMMd();
      final fmtEnd = range.isMonthly ? DateFormat.yMMM() : DateFormat.yMMMd();
      period = '${fmtStart.format(dates.first)} – ${fmtEnd.format(dates.last)}';
    }
    final muted = context.footnote.copyWith(
      color: context.secondaryLabel,
      fontWeight: FontWeight.w600,
    );
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MetricChip(type: type, size: 34, hero: true),
              const SizedBox(width: 10),
              Expanded(child: Text(caption, style: muted)),
            ],
          ),
          const SizedBox(height: 4),
          if (value == null)
            Text('No Data', style: context.largeTitle)
          else
            ValueText(type: type, value: value, large: true),
          Text(period, style: muted),
        ],
      ),
    );
  }

  String get _aggregationLabel => switch (type.aggregation) {
    Aggregation.sum => 'TOTAL',
    Aggregation.average => 'AVERAGE',
    Aggregation.latest => 'LATEST',
  };
}

class _GoalSection extends StatelessWidget {
  const _GoalSection({
    required this.type,
    required this.goal,
    required this.values,
    required this.isMonthly,
  });

  final MetricType type;
  final double goal;
  final List<double?> values;
  final bool isMonthly;

  @override
  Widget build(BuildContext context) {
    final store = context.read<HealthStore>();
    final today = store.dailyValue(type, store.today) ?? 0;
    final progress = (today / goal).clamp(0.0, 1.0);
    final metDays = isMonthly
        ? null
        : values.where((v) => v != null && v >= goal).length;
    final goalText = '${formatValue(type, goal)} ${unitLabel(type)}'.trim();

    return GroupedSection(
      header: 'Daily Goal',
      footer: progress >= 1
          ? 'Goal reached today.'
          : '${(progress * 100).round()}% of today\'s goal'
                '${metDays == null ? '' : ' · met on $metDays of ${values.length} days'}',
      hasLeading: false,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                goalText,
                style: context.headline.copyWith(
                  color: context.resolve(type.color),
                ),
              ),
              const SizedBox(height: 10),
              CapsuleProgress(value: progress, color: type.color),
            ],
          ),
        ),
      ],
    );
  }
}

class _OptionsSection extends StatelessWidget {
  const _OptionsSection({required this.type});

  final MetricType type;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final sync = context.watch<HealthSyncService>();
    final entries = store.entriesFor(type);
    final imported = entries.where((e) => e.isImported).length;
    final syncing = sync.connected && sync.granted.contains(type);
    // Connected, but this one isn't shared: say so, or the page just
    // looks empty.
    final notAllowed =
        sync.connected &&
        sync.supportedTypes.contains(type) &&
        !sync.granted.contains(type);
    return GroupedSection(
      footer: syncing
          ? 'Daily totals are imported from ${sync.sourceName}. Change '
                'them in the app that recorded them.'
          : notAllowed
          ? '${type.label} isn\'t allowed in ${sync.sourceName}, so none is '
                'imported. Allow it to see readings from your phone and '
                'watch.'
          : null,
      hasLeading: false,
      children: [
        if (notAllowed)
          InfoRow(
            title: 'Manage Permissions',
            titleColor: context.tint,
            chevron: true,
            onTap: sync.openPermissionSettings,
          ),
        InfoRow(
          title: 'Show All Data',
          value: '${entries.length}',
          chevron: true,
          onTap: () => AllDataScreen.open(context, type),
        ),
        if (imported > 0) InfoRow(title: 'Data Source', value: sync.sourceName),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.type});

  final MetricType type;

  static const _about = {
    MetricType.steps: 'Step count is the number of steps you take throughout the day. Regular walking supports heart health, mood and weight management.',
    MetricType.distance: 'The total distance you covered walking and running.',
    MetricType.activeEnergy: 'Active energy is the calories you burn by moving, on top of the energy your body uses at rest.',
    MetricType.exerciseMinutes: 'Minutes of activity at or above a brisk walk. Health organisations recommend at least 150 minutes per week.',
    MetricType.heartRate: 'Your heart rate is the number of times your heart beats per minute. It varies with activity, stress, sleep and more.',
    MetricType.restingHeartRate: 'Resting heart rate is measured while you are inactive and relaxed. A lower resting rate often indicates better fitness.',
    MetricType.respiratoryRate: 'Respiratory rate is how many breaths you take per minute, usually measured by your watch while you sleep. A sudden rise can be an early sign of illness.',
    MetricType.bodyTemperature: 'Body temperature from a thermometer or another app. A normal temperature is around 36.1 to 37.2 °C (97 to 99 °F).',
    MetricType.bodyFat: 'Body fat is the share of your weight that is fat, from a smart scale or another app. It shows changes that weight alone can miss.',
    MetricType.restingEnergy: 'Resting energy is what your body burns at rest to keep you alive, estimated by your watch or scale.',
    MetricType.floorsClimbed: 'Floors climbed counts each flight of stairs or rise of about 3 metres, measured by your phone or watch.',
    MetricType.skinTemperature: 'Skin temperature is the change from your own usual temperature while you sleep, measured by your watch or ring. A rise can come with illness, alcohol or your cycle.',
    MetricType.leanBodyMass: 'Lean body mass is your weight minus your body fat: muscle, bone, organs and water, from a smart scale.',
    MetricType.bodyWaterMass: 'Body water mass is how much of your weight is water, from a smart scale.',
    MetricType.bloodOxygen: 'Blood oxygen (SpO₂) is the percentage of oxygen your red blood cells carry. Typical readings are 95–100%.',
    MetricType.bloodPressureSystolic: 'Systolic pressure is the top number: the pressure in your arteries when your heart beats. Under 120 mmHg is considered normal; see a doctor about readings that are often 130 or higher.',
    MetricType.bloodPressureDiastolic: 'Diastolic pressure is the bottom number: the pressure between beats. Under 80 mmHg is considered normal.',
    MetricType.bloodGlucose: 'Blood glucose is the sugar in your blood. Levels rise after meals and fall with activity. Follow your doctor\'s targets if you manage diabetes, and never use Health to decide an insulin or medication dose.',
    MetricType.sleep: 'Most adults need 7–9 hours of sleep a night. Consistent sleep supports recovery, memory and mood.',
    MetricType.weight: 'Tracking weight over time helps you notice trends. Day-to-day changes are normal; focus on the long-term trend.',
    MetricType.water: 'Staying hydrated supports energy, focus and digestion. Needs vary with climate, activity and body size.',
    MetricType.hrv: 'Heart rate variability (HRV) is the variation in time between heartbeats, measured here as RMSSD. Higher values usually mean better recovery; compare against your own baseline rather than others.',
    MetricType.sleepDeep: 'Deep sleep is when your body repairs itself. Adults typically spend 13–23% of the night in deep sleep.',
    MetricType.sleepCore: 'Core (light) sleep makes up most of the night and supports memory and learning.',
    MetricType.sleepRem: 'REM sleep is when most dreaming happens. It supports mood and memory, and is usually 20–25% of the night.',
    MetricType.sleepAwake: 'Time spent awake after first falling asleep. Brief wake-ups are normal.',
    MetricType.mindfulMinutes: 'Time spent on mindfulness, meditation or breathing exercises. Even a few minutes a day can reduce stress.',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: IosCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('About ${type.label}', style: context.headline),
            const SizedBox(height: 6),
            Text(_about[type] ?? '', style: context.subheadline),
          ],
        ),
      ),
    );
  }
}

/// Goal weight and progress photos, under the weight chart.
class _BodySection extends StatelessWidget {
  const _BodySection();

  Future<void> _editGoal(BuildContext context) async {
    final store = context.read<HealthStore>();
    final result = await showTextPrompt(
      context,
      title: 'Goal Weight',
      confirm: 'Save',
      clearLabel: 'Remove',
      initial: switch (store.goals.weightKg) {
        final kg? => Units.weightOut(kg).toStringAsFixed(1),
        null => '',
      },
      textAlign: TextAlign.center,
      placeholder: Units.weightUnit,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: numberInput(),
    );
    if (result == null) return;
    // "Remove" returns an empty string.
    if (result.trim().isEmpty) {
      await store.setWeightGoal(null);
      return;
    }
    final shown = double.tryParse(result.replaceAll(',', '.'));
    final kg = shown == null ? null : Units.weightIn(shown);
    if (kg == null || kg < 20 || kg > 400) {
      if (context.mounted) {
        await showMessage(
          context,
          title: 'Check Your Goal',
          message:
              'Enter a weight between ${Units.weight(20, decimals: 0)} and '
              '${Units.weight(400, decimals: 0)}. Your goal hasn\'t changed.',
        );
      }
      return;
    }
    await store.setWeightGoal(kg);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final goal = store.goals.weightKg;
    final latest = store.latestReading(MetricType.weight)?.value;
    String? toGo;
    if (goal != null && latest != null) {
      final diff = (latest - goal).abs();
      toGo = diff < 0.05 ? 'Goal reached' : '${Units.weight(diff)} to go';
    }
    return GroupedSection(
      header: 'Body',
      hasLeading: false,
      children: [
        InfoRow(
          title: 'Goal Weight',
          subtitle: toGo,
          value: goal == null ? 'Not Set' : Units.weight(goal),
          chevron: true,
          onTap: () => _editGoal(context),
        ),
        InfoRow(
          title: 'Progress Photos',
          chevron: true,
          onTap: () => ProgressPhotosScreen.open(context),
        ),
      ],
    );
  }
}
