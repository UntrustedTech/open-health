import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/app_edition.dart';
import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/insights/trends.dart' show Trend;
import 'package:health_app/models/board.dart';
import 'package:health_app/models/board_catalog.dart';
import 'package:health_app/models/health_widget.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/screens/achievements_screen.dart';
import 'package:health_app/screens/cycle/cycle_screen.dart';
import 'package:health_app/screens/fasting/fasting_screen.dart';
import 'package:health_app/screens/food/food_diary_screen.dart';
import 'package:health_app/screens/health/all_health_data.dart';
import 'package:health_app/screens/health/health_widgets.dart';
import 'package:health_app/screens/health/metric_widget.dart';
import 'package:health_app/screens/health/tracker_facts.dart';
import 'package:health_app/screens/health_report_screen.dart';
import 'package:health_app/screens/health_settings_screen.dart';
import 'package:health_app/screens/medications/medications_screen.dart';
import 'package:health_app/screens/habits/habits_screen.dart';
import 'package:health_app/screens/mood/mood_screen.dart';
import 'package:health_app/screens/readiness/readiness_screen.dart';
import 'package:health_app/insights/readiness.dart';
import 'package:health_app/screens/recap/recap_screen.dart';
import 'package:health_app/screens/sleep/sleep_schedule_screen.dart';
import 'package:health_app/screens/trends_screen.dart';
import 'package:health_app/state/achievement_store.dart';
import 'package:health_app/state/cycle_store.dart';
import 'package:health_app/state/fasting_store.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/medication_store.dart';
import 'package:health_app/state/mood_store.dart';
import 'package:health_app/state/nutrition_store.dart';
import 'package:health_app/state/sleep_schedule_store.dart';
import 'package:health_app/sync/health_sync_service.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/board_tiles.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/list_card.dart';
import 'package:health_app/widgets/metric_card.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/widgets/widget_board.dart';

/// The Health tab: a board of widgets the user arranges (vitals, body
/// categories, trackers and metrics), with search and every metric a tap
/// away.
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  /// Everything the Health board can show.
  static List<BoardEntry> catalog() => [
    BoardEntry(
      id: BoardIds.vitals,
      label: 'Vitals Now',
      icon: Icons.monitor_heart_rounded,
      color: Palette.red,
      group: 'Highlights',
      detail: 'Resting heart rate and how your vitals stand',
      sizes: const {WidgetSize.large},
      builder: (context, size) => const VitalsHero(),
    ),
    for (final c in HealthCategory.values)
      BoardEntry(
        id: BoardIds.category(c),
        // Distinct from the metric of the same name (Sleep).
        label: '${c.label} Overview',
        icon: c.icon,
        color: c.color,
        group: 'Your Body',
        detail: 'Its key number and a week of bars',
        builder: (context, size) => _CategoryWidget(category: c, size: size),
      ),
    BoardEntry(
      id: BoardIds.healthMore,
      label: 'More',
      icon: Icons.apps_rounded,
      color: Palette.indigo,
      group: 'Highlights',
      detail: 'Trackers and insights in one short list',
      sizes: const {WidgetSize.large},
      builder: (context, size) => const _TrackerList(),
    ),
    for (final t in Tracker.shown)
      BoardEntry(
        id: BoardIds.tracker(t),
        label: _TrackerWidget.label(t),
        icon: _TrackerWidget.icon(t),
        color: _TrackerWidget.color(t),
        group: 'Trackers & Insights',
        builder: (context, size) => _TrackerWidget(tracker: t, size: size),
      ),
    ...metricEntries(),
  ];

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final _board = BoardController();
  String _query = '';

  @override
  void dispose() {
    _board.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().isNotEmpty;
    final sync = context.watch<HealthSyncService>();
    return LargeTitlePage(
      title: 'Health',
      // Pull down to fetch what's new in Health Connect right away.
      onRefresh: sync.connected ? () => sync.sync(force: true) : null,
      trailing: BoardEditControls(
        controller: _board,
        tab: BoardTab.health,
        catalog: HealthScreen.catalog,
        label: 'Edit Health',
        trailing: HeaderButton(
          icon: Icons.settings_rounded,
          semanticLabel: tr('Health Settings'),
          onTap: () => HealthSettingsScreen.open(context),
        ),
      ),
      children: [
        CupertinoSearchTextField(
          placeholder: tr('Search'),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 14),
        // While searching, only the results show.
        if (searching) ...[
          if (_TrackerList.matching(_query) case final found
              when found.isNotEmpty)
            _TrackerList(shown: found),
          ...MetricGroups.of(
            context,
            _query,
            showEmpty: _TrackerList.matching(_query).isEmpty,
          ),
        ] else ...[
          // Keyed, so it isn't rebuilt (and faded in again) when content above
          // it comes and goes.
          Appear(
            key: const ValueKey('board'),
            child: WidgetBoard(
              tab: BoardTab.health,
              catalog: HealthScreen.catalog(),
              controller: _board,
            ),
          ),
          const SizedBox(height: AppTheme.gap),
          AllDataLink(onTap: () => AllHealthDataScreen.open(context)),
        ],
      ],
    );
  }
}

/// A body category as a widget: its key number and a week of bars. Opens
/// the category.
class _CategoryWidget extends StatelessWidget {
  const _CategoryWidget({required this.category, required this.size});

  final HealthCategory category;
  final WidgetSize size;

  /// The number each category leads with.
  static const _key = {
    HealthCategory.activity: MetricType.steps,
    HealthCategory.heart: MetricType.restingHeartRate,
    HealthCategory.vitals: MetricType.bloodOxygen,
    HealthCategory.sleep: MetricType.sleep,
    HealthCategory.body: MetricType.weight,
    HealthCategory.nutrition: MetricType.dietaryEnergy,
    HealthCategory.mindfulness: MetricType.mindfulMinutes,
  };

  static MetricType _metricFor(HealthStore store, HealthCategory category) {
    final preferred =
        _key[category] ??
        MetricType.values.firstWhere((t) => t.category == category);
    // Calories eaten once the food diary is used; water until then.
    return preferred == MetricType.dietaryEnergy &&
            store.latestReading(preferred) == null
        ? MetricType.water
        : preferred;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final metric = _metricFor(store, category);
    final reading = store.latestReading(metric);
    final week = store.dailySeries(metric, end: store.today, days: 7);
    final value = reading == null
        ? null
        : '${formatValue(metric, reading.value)} ${unitLabel(metric)}'.trim();
    return StatWidget(
      size: size,
      icon: category.icon,
      color: category.color,
      title: size.fullWidth || category != HealthCategory.body
          ? category.label
          : 'Body',
      semanticLabel: value == null
          ? '${category.label}, no data yet'
          : '${category.label}, ${metric.label} $value',
      onTap: () => CategoryScreen.open(context, category),
      value: reading == null
          ? StatValue('No data yet', size: size, placeholder: true)
          : StatValue(
              formatValue(metric, reading.value),
              unit: unitLabel(metric),
              size: size,
            ),
      caption: size.fullWidth ? weekChange(week) ?? metric.label : metric.label,
      smallVisual: WeekBars(
        values: week,
        color: category.color,
        today: store.today,
        labels: false,
      ),
      wideVisual: WeekBars(
        values: week,
        color: category.color,
        today: store.today,
      ),
      facts: metricFacts(store, metric),
      history: size == WidgetSize.large
          ? store.dailySeries(metric, end: store.today, days: 30)
          : null,
    );
  }
}

/// Trackers and insights as one short list, each with how it stands
/// today: the Health tab's default instead of a tile for each.
class _TrackerList extends StatelessWidget {
  const _TrackerList({this.shown = trackers});

  final List<Tracker> shown;

  /// Every tracker (Readiness too) named like [query], in English or the
  /// app's language.
  static List<Tracker> matching(String query) {
    final q = query.trim().toLowerCase();
    bool has(String name) =>
        name.toLowerCase().contains(q) || tr(name).toLowerCase().contains(q);
    return [
      for (final t in [Tracker.readiness, ...trackers])
        if (has(_TrackerWidget.label(t))) t,
    ];
  }

  /// Readiness has its own widget.
  static const trackers = [
    Tracker.trends,
    Tracker.food,
    Tracker.mood,
    Tracker.habits,
    Tracker.sleepSchedule,
    Tracker.fasting,
    if (!kStoreEdition) Tracker.medications,
    Tracker.cycle,
    Tracker.achievements,
    Tracker.recap,
    Tracker.report,
  ];

  @override
  Widget build(BuildContext context) => ListCard(
    items: [
      for (final t in shown)
        if (_TrackerWidget.stateOf(context, t) case (
          final color,
          final value,
          _,
          final unit,
          final onTap,
        ))
          (
            icon: _TrackerWidget.icon(t),
            color: color,
            title: _TrackerWidget.label(t),
            subtitle: unit == null ? value : '$value $unit',
            onTap: onTap,
          ),
    ],
  );
}

/// A tracker or insight as a widget: its icon and name and how it stands
/// today. Opens its screen.
class _TrackerWidget extends StatelessWidget {
  const _TrackerWidget({required this.tracker, required this.size});

  final Tracker tracker;
  final WidgetSize size;

  static String label(Tracker t) => switch (t) {
    Tracker.readiness => 'Readiness',
    Tracker.mood => 'Mood',
    Tracker.habits => 'Habits',
    Tracker.sleepSchedule => 'Sleep Schedule',
    Tracker.fasting => 'Fasting',
    Tracker.food => 'Food & Calories',
    Tracker.trends => 'Trends',
    Tracker.medications => 'Medications',
    Tracker.cycle => 'Cycle Tracking',
    Tracker.achievements => 'Achievements',
    Tracker.recap => 'Monthly Recap',
    Tracker.report => 'Health Report',
  };

  /// The title on a small widget, where the full one would be cut off.
  static String shortLabel(Tracker t) => switch (t) {
    Tracker.sleepSchedule => 'Bedtime',
    Tracker.food => 'Calories',
    Tracker.cycle => 'Cycle',
    Tracker.recap => 'Recap',
    Tracker.report => 'Report',
    _ => label(t),
  };

  static IconData icon(Tracker t) => switch (t) {
    Tracker.readiness => Icons.bolt_rounded,
    Tracker.mood => Icons.emoji_emotions_rounded,
    Tracker.habits => Icons.task_alt_rounded,
    Tracker.sleepSchedule => Icons.bedtime_rounded,
    Tracker.fasting => Icons.hourglass_bottom_rounded,
    Tracker.food => Icons.qr_code_scanner_rounded,
    Tracker.trends => Icons.insights_rounded,
    Tracker.medications => Icons.medication_rounded,
    Tracker.cycle => Icons.donut_large_rounded,
    Tracker.achievements => Icons.workspace_premium_rounded,
    Tracker.recap => Icons.auto_graph_rounded,
    Tracker.report => Icons.description_rounded,
  };

  static Color color(Tracker t) => switch (t) {
    Tracker.readiness => Palette.green,
    Tracker.mood => moodColor,
    Tracker.habits => Palette.green,
    Tracker.sleepSchedule => sleepColor,
    Tracker.fasting => fastingColor,
    Tracker.food => foodOrange,
    Tracker.trends => Palette.indigo,
    Tracker.medications => Palette.teal,
    Tracker.cycle => const Color(0xFFFF4D8D),
    Tracker.achievements => Palette.yellow,
    Tracker.recap => Palette.purple,
    Tracker.report => Palette.blue,
  };

  /// How [t] stands today: its colour, the value (or a prompt), progress
  /// when it has some, the unit after a number value, and what a tap does.
  static (Color, String, double?, String?, VoidCallback) stateOf(
    BuildContext context,
    Tracker t,
  ) => switch (t) {
    Tracker.readiness => () {
      final store = context.watch<HealthStore>();
      final r = readinessOf(store);
      return (
        r == null ? Palette.grey : readinessColor(r.level),
        r == null ? 'Needs a week of data' : '${r.score}',
        // Before a score, the bar shows the week of readings filling up.
        r == null
            ? Readiness.baselineProgress(store.dailyValue, store.today)
            : r.score / 100,
        r?.level.label,
        () => ReadinessScreen.open(context),
      );
    }(),
    Tracker.mood => () {
      final mood = context.watch<MoodStore>().today;
      return (
        moodColor,
        mood == null
            ? 'How are you today?'
            : '${mood.mood.emoji} ${mood.mood.label}',
        null,
        null,
        () => MoodScreen.open(context),
      );
    }(),
    Tracker.habits => () {
      final mood = context.watch<MoodStore>();
      final today = context.watch<HealthStore>().today;
      final all = mood.habits.length;
      final done = mood.habits.where((h) => mood.didHabit(h, today)).length;
      return (
        color(Tracker.habits),
        all == 0 ? 'Build a daily habit' : '$done of $all done',
        all == 0 ? null : done / all,
        null,
        () => HabitsScreen.open(context),
      );
    }(),
    Tracker.sleepSchedule => () {
      final schedule = context.watch<SleepScheduleStore>().schedule;
      return (
        sleepColor,
        schedule.enabled
            ? 'Bed ${formatTimeOfDay(schedule.bedtime.hour, schedule.bedtime.minute)}'
            : 'Set a bedtime',
        null,
        null,
        () => SleepScheduleScreen.open(context),
      );
    }(),
    Tracker.fasting => () {
      final fasting = context.watch<FastingStore>();
      return (
        fastingColor,
        fasting.isFasting
            ? 'Fasting · ${fasting.preset.label}'
            : 'Start a ${fasting.preset.label} fast',
        null,
        null,
        () => FastingScreen.open(context),
      );
    }(),
    Tracker.food => () {
      final store = context.watch<HealthStore>();
      final food = context.watch<NutritionStore>();
      final eaten = food.totalOn(store.today).kcal;
      // The budget, as on the Food tab: the goal plus exercise.
      final goal = food.budgetOn(store.today);
      return (
        foodOrange,
        eaten > 0 ? kcalText(eaten) : 'Scan & count calories',
        goal > 0 ? eaten / goal : 0.0,
        eaten > 0 && goal > 0 ? 'of ${kcalText(goal)} Cal' : null,
        () => FoodDiaryScreen.open(context),
      );
    }(),
    Tracker.trends => () {
      final moving = TrendsScreen.trendsFor(context.watch<HealthStore>())
          .where((t) => t.trend != Trend.steady)
          .length;
      return (
        Palette.indigo,
        moving == 0
            ? 'All steady'
            : '$moving ${moving == 1 ? 'trend' : 'trends'} changing',
        null,
        null,
        () => TrendsScreen.open(context),
      );
    }(),
    Tracker.medications => () {
      final meds = context.watch<MedicationStore>();
      return (
        Palette.teal,
        meds.isEmpty ? 'Add reminders' : '${meds.active.length} active',
        null,
        null,
        () => MedicationsScreen.open(context),
      );
    }(),
    Tracker.cycle => () {
      final cycle = context.watch<CycleStore>();
      final day = cycle.enabled ? cycle.forecast.cycleDay : null;
      return (
        const Color(0xFFFF4D8D),
        !cycle.enabled
            ? 'Off'
            : day == null
            ? 'Log a period'
            : 'Day $day',
        null,
        null,
        () => CycleScreen.open(context),
      );
    }(),
    Tracker.achievements => () {
      final badges = context.watch<AchievementStore>();
      final earned = badges.medals;
      final total = badges.totalMedals;
      return (
        Palette.yellow,
        '$earned',
        total == 0 ? 0.0 : earned / total,
        'of $total medals',
        () => AchievementsScreen.open(context),
      );
    }(),
    Tracker.recap => (
      Palette.purple,
      'Your ${DateFormat.MMMM().format(context.select<HealthStore, DateTime>((s) => s.today))}',
      null,
      null,
      () => RecapScreen.open(context),
    ),
    Tracker.report => (
      Palette.blue,
      'PDF for your doctor',
      null,
      null,
      () => HealthReportScreen.open(context),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final t = tracker;
    final (c, value, progress, unit, onTap) = stateOf(context, t);
    final p = progress;
    return StatWidget(
      size: size,
      icon: icon(t),
      color: c,
      title: size.fullWidth ? label(t) : shortLabel(t),
      semanticLabel: tr('${label(t)}, $value${unit == null ? '' : ' $unit'}'),
      onTap: onTap,
      value: unit == null
          ? StatValue(value, size: size, placeholder: true)
          : StatValue(value, unit: unit, size: size),
      smallVisual: p == null ? null : BarVisual(progress: p, color: c),
      wideVisual: p == null
          ? IconDisc(icon: icon(t), color: c)
          : RingVisual(
              progress: p,
              color: c,
              child: Text('${(p * 100).round()}%', style: context.number(16)),
            ),
      facts: size == WidgetSize.small ? const [] : trackerFacts(context, t),
    );
  }
}

/// One category's data as Summary-style cards with 7-day trends.
class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key, required this.category});

  final HealthCategory category;

  static Future<void> open(BuildContext context, HealthCategory category) =>
      Navigator.of(context).push(
        AppRoute<void>(
          title: category.label,
          builder: (_) => CategoryScreen(category: category),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final metrics = MetricType.values.where((t) => t.category == category);
    return CupertinoPageScaffold(
      backgroundColor: context.groupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(category.label),
        previousPageTitle: tr('Health'),
      ),
      child: PageList(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.margin,
          12,
          AppTheme.margin,
          32,
        ),
        children: [
          if (category == HealthCategory.nutrition) ...[
            IosCard(
              onTap: () => FoodDiaryScreen.open(context),
              child: Row(
                children: [
                  const IconTile(
                    icon: Icons.qr_code_scanner_rounded,
                    color: Color(0xFFFF9447),
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Food Diary', style: context.headline),
                        Text(
                          'Scan barcodes and count calories',
                          style: context.footnote.copyWith(
                            color: context.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 14,
                    color: context.tertiaryLabel,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          for (final (i, t) in metrics.indexed) ...[
            Appear(
              index: i,
              child: MetricCard(type: t),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
