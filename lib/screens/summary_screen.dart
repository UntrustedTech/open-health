import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/insights/health_overview.dart';
import 'package:health_app/models/board.dart';
import 'package:health_app/models/board_catalog.dart';
import 'package:health_app/models/health_widget.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/screens/add_entry_sheet.dart';
import 'package:health_app/screens/food/food_diary_screen.dart';
import 'package:health_app/screens/goal/check_in_card.dart';
import 'package:health_app/screens/health_connect_screen.dart';
import 'package:health_app/screens/health_screen.dart';
import 'package:health_app/screens/summary/overview_widgets.dart';
import 'package:health_app/screens/summary/setup_card.dart';
import 'package:health_app/screens/workouts/workouts_screen.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/nutrition_store.dart';
import 'package:health_app/sync/health_source.dart';
import 'package:health_app/sync/health_sync_service.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/widgets/shell_tabs.dart';
import 'package:health_app/widgets/widget_board.dart';

/// The overview of the user's health: one score for today, the past week,
/// month, three months or year, weighted by their goal, with how each
/// area is doing and what changed.
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  SummaryPeriod _period = SummaryPeriod.today;
  final _board = BoardController();

  @override
  void dispose() {
    _board.dispose();
    super.dispose();
  }

  HealthOverview? _overview;
  Object? _overviewKey;

  /// The overview, worked out again only when what it's built from
  /// changes: a year takes a frame's worth of time, and the screen
  /// rebuilds for things like sync progress.
  HealthOverview _overviewFor(HealthStore store, NutritionStore nutrition) {
    final now = store.now;
    // Today's score allows for how much of the day has gone, to the
    // quarter hour.
    final at = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute ~/ 15 * 15,
    );
    final key = (
      _period,
      store.revision,
      nutrition.revision,
      store.goals,
      store.bodyGoal,
      at,
    );
    if (key == _overviewKey && _overview != null) return _overview!;
    _overviewKey = key;
    return _overview = HealthOverview.build(
      period: _period,
      today: store.today,
      dailyValue: store.dailyValue,
      goals: store.goals,
      bodyGoal: store.bodyGoal,
      food: (day) {
        // One lookup per day: the year view asks for hundreds of days.
        final entries = nutrition.entriesOn(day);
        if (entries.isEmpty) return null;
        final eaten = entries.fold(0.0, (sum, e) => sum + e.nutrients.kcal);
        return (eaten: eaten, budget: nutrition.budgetOn(day));
      },
      now: at,
    );
  }

  /// The Summary's own widgets, then every other tab's, each once.
  List<BoardEntry> _catalog(
    OverviewData data,
    Widget Function(Widget) fade,
    DateTime today,
  ) {
    BoardEntry pillar(String id, Pillar p, String detail) {
      final (icon, color) = pillarLook(p);
      return BoardEntry(
        id: id,
        label: p.label,
        icon: icon,
        color: color,
        group: 'Summary',
        detail: detail,
        sizes: const {WidgetSize.small, WidgetSize.medium},
        builder: (_, _) => fade(PillarTile(pillar: p, data: data)),
      );
    }

    final entries = [
      BoardEntry(
        id: BoardIds.score,
        label: 'Health Score',
        icon: Icons.insights_rounded,
        color: Palette.purple,
        group: 'Summary',
        detail: 'One score for the day, with each area',
        sizes: const {WidgetSize.large},
        preferred: WidgetSize.large,
        builder: (_, _) => fade(ScoreHero(data: data)),
      ),
      BoardEntry(
        id: BoardIds.rings,
        label: 'Activity Rings',
        icon: Icons.local_fire_department_rounded,
        color: Palette.red,
        group: 'Summary',
        detail: 'Move, exercise and steps',
        sizes: const {WidgetSize.large},
        preferred: WidgetSize.large,
        builder: (_, _) => fade(ActivityHero(data: data)),
      ),
      pillar(BoardIds.sleep, Pillar.sleep, 'Last night, or a night on average'),
      pillar(BoardIds.heart, Pillar.heart, 'Resting heart rate'),
      pillar(BoardIds.nutrition, Pillar.nutrition, 'Calories eaten'),
      pillar(BoardIds.body, Pillar.body, 'Your weight trend'),
      BoardEntry(
        id: BoardIds.water,
        label: 'Water Intake',
        icon: MetricType.water.icon,
        color: MetricType.water.color,
        group: 'Summary',
        detail: 'Water against your goal',
        sizes: const {WidgetSize.small, WidgetSize.medium},
        builder: (_, _) => fade(WaterTile(data: data)),
      ),
      BoardEntry(
        id: BoardIds.changes,
        label: 'What Changed',
        icon: Icons.trending_up_rounded,
        color: Palette.green,
        group: 'Summary',
        detail: 'The biggest changes against before',
        sizes: const {WidgetSize.large},
        preferred: WidgetSize.large,
        builder: (_, _) => fade(ChangeList(overview: data.overview)),
      ),
      ...HealthScreen.catalog(),
      ...WorkoutsScreen.catalog(),
      ...FoodDiaryScreen.catalog(today),
    ];
    final seen = <String>{};
    return [
      for (final e in entries)
        if (seen.add(e.id)) e,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final nutrition = context.watch<NutritionStore>();
    final sync = context.watch<HealthSyncService>();
    final look = store.personalization;
    final firstName = store.profile.name.split(' ').first;
    final overview = _overviewFor(store, nutrition);
    final data = OverviewData(
      overview: overview,
      today: store.today,
      dailyValue: store.dailyValue,
      goals: store.goals,
      eatenOn: (day) {
        final entries = nutrition.entriesOn(day);
        return entries.isEmpty
            ? null
            : entries.fold<double>(0, (sum, e) => sum + e.nutrients.kcal);
      },
    );
    final reduce = Motion.reduced(context);

    // Switching period cross-fades the overview.
    Widget fade(Widget child) => AnimatedSwitcher(
      duration: reduce ? Duration.zero : Motion.medium,
      switchInCurve: Motion.curve,
      switchOutCurve: Motion.curve,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      child: KeyedSubtree(key: ValueKey(_period), child: child),
    );

    List<BoardEntry> catalog() => _catalog(data, fade, store.today);

    return LargeTitlePage(
      title: 'Summary',
      onRefresh: sync.connected ? () => sync.sync(force: true) : null,
      trailing: BoardEditControls(
        controller: _board,
        tab: BoardTab.summary,
        catalog: catalog,
        label: 'Edit Summary',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HeaderButton(
              icon: Icons.add_rounded,
              semanticLabel: tr('Add Data'),
              onTap: () => AddEntrySheet.pickMetricAndShow(context),
            ),
            _Avatar(initials: store.profile.initials),
          ],
        ),
      ),
      children: [
        _Header(
          date: store.now,
          greeting: look.showGreeting,
          name: firstName,
          subtitle: _period == SummaryPeriod.today
              ? _Text._daySoFar(store.now)
              : 'Here\'s how your ${_Text._span(_period)} went.',
        ),
        const SizedBox(height: 16),
        Appear(
          child: PeriodSwitch(
            value: _period,
            onChanged: (p) => setState(() => _period = p),
          ),
        ),
        const SizedBox(height: 14),
        const _SyncBanner(),
        const SetupCard(),
        const CheckInCard(dueOnly: true),
        // Keyed, so it isn't rebuilt (and faded in again) when content
        // above it comes and goes.
        Appear(
          key: const ValueKey('board'),
          index: 1,
          child: WidgetBoard(
            tab: BoardTab.summary,
            catalog: catalog(),
            controller: _board,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// The date, an optional greeting and a line about the day.
class _Header extends StatelessWidget {
  const _Header({
    required this.date,
    required this.greeting,
    required this.name,
    this.subtitle,
  });

  final DateTime date;

  /// Settings → Appearance → Greeting.
  final bool greeting;
  final String name;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (greeting)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              name.isEmpty
                  ? _Text._greeting(date)
                  : _Text._greetingWithName(date, name),
              style: context.subheadline.copyWith(
                color: context.secondaryLabel,
              ),
            ),
          ),
        // The day is the title; a greeting would fit any app.
        Text(
          DateFormat.MMMMEEEEd().format(date),
          style: context.title1.copyWith(fontWeight: FontWeight.w600),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: AnimatedSwitcher(
              duration: Motion.medium,
              child: Text(
                subtitle,
                key: ValueKey(subtitle),
                style: context.subheadline.copyWith(
                  color: context.secondaryLabel,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The greeting and the line under it.
abstract final class _Text {
  /// The selected period in a sentence.
  static String _span(SummaryPeriod p) => switch (p) {
    SummaryPeriod.today => 'day',
    SummaryPeriod.week => 'past week',
    SummaryPeriod.month => 'past month',
    SummaryPeriod.quarter => 'past 3 months',
    SummaryPeriod.year => 'past year',
  };

  /// A line under the greeting that follows the time of day.
  static String _daySoFar(DateTime now) => switch (now.hour) {
    < 5 => 'Rest well. Here\'s how today went.',
    < 12 => 'Here\'s how your morning is going.',
    < 18 => 'Here\'s your day so far.',
    _ => 'Here\'s how today went.',
  };

  static String _greeting(DateTime now) => switch (now.hour) {
    < 5 => 'Good evening',
    < 12 => 'Good morning',
    < 18 => 'Good afternoon',
    _ => 'Good evening',
  };

  // Whole, so each language can place the name where it goes.
  static String _greetingWithName(DateTime now, String name) =>
      switch (now.hour) {
        < 5 => 'Good evening, $name',
        < 12 => 'Good morning, $name',
        < 18 => 'Good afternoon, $name',
        _ => 'Good evening, $name',
      };
}

/// The user's initials in an inverted circle; opens Profile.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: tr('Profile'),
      onTap: () => ShellTabs.maybeOf(context)?.select(ShellTabs.profile),
      child: SizedBox.square(
        dimension: AppTheme.minTapTarget,
        child: Center(
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.labelColor,
            ),
            child: initials.isEmpty
                ? Icon(Icons.person_rounded, color: context.onLabel, size: 20)
                : Text(
                    initials,
                    style: context.footnote.copyWith(
                      color: context.onLabel,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Shows sync progress, problems, or an invitation to connect.
class _SyncBanner extends StatelessWidget {
  const _SyncBanner();

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<HealthSyncService>();
    final status = sync.status;
    final error = sync.error;

    final Widget? content;
    if (sync.syncing) {
      content = Row(
        children: [
          const CupertinoActivityIndicator(),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Syncing with ${sync.sourceName}…',
              style: context.subheadline,
            ),
          ),
        ],
      );
    } else if (sync.connected && error != null) {
      content = _BannerRow(
        icon: Icons.warning_rounded,
        color: context.resolve(Palette.orange),
        text: error,
      );
    } else if (!sync.connected &&
        (status == SourceStatus.available ||
            status == SourceStatus.needsInstall)) {
      content = _BannerRow(
        icon: Icons.monitor_heart_rounded,
        color: context.tint,
        title: 'Connect ${sync.sourceName}',
        text: 'See steps, sleep and heart rate from your phone and watch.',
      );
    } else {
      content = null;
    }
    if (content == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IosCard(
        onTap: sync.syncing ? null : () => HealthConnectScreen.open(context),
        child: content,
      ),
    );
  }
}

class _BannerRow extends StatelessWidget {
  const _BannerRow({
    required this.icon,
    required this.color,
    required this.text,
    this.title,
  });

  final IconData icon;
  final Color color;
  final String text;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title case final t?) Text(t, style: context.headline),
              Text(
                text,
                style: context.subheadline.copyWith(
                  color: title == null ? null : context.secondaryLabel,
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
    );
  }
}
