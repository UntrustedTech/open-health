import 'dart:async';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/exercise_library.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/screens/workouts/exercise_library_screen.dart';
import 'package:health_app/screens/workouts/fitness_hub.dart';
import 'package:health_app/screens/workouts/live_workout_screen.dart';
import 'package:health_app/models/tab_layout.dart';
import 'package:health_app/screens/workouts/records_screen.dart';
import 'package:health_app/screens/workouts/routine_editor_screen.dart';
import 'package:health_app/screens/workouts/stats_screen.dart';
import 'package:health_app/insights/progress_stats.dart';
import 'package:health_app/insights/training_stats.dart';
import 'package:health_app/widgets/activity_heatmap.dart';
import 'package:health_app/screens/workouts/today_card.dart';
import 'package:health_app/screens/workouts/workout_detail_screen.dart';
import 'package:health_app/screens/workouts/workout_edit_screen.dart';
import 'package:health_app/screens/workouts/workout_history_screen.dart';
import 'package:health_app/screens/workouts/workout_launcher.dart';
import 'package:health_app/screens/workouts/workout_settings_screen.dart';
import 'package:health_app/screens/readiness/suggestions.dart';
import 'package:health_app/screens/workouts/programs_screen.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/models/board.dart';
import 'package:health_app/models/board_catalog.dart';
import 'package:health_app/models/health_widget.dart';
import 'package:health_app/screens/gym/gym_card.dart' show gymColor;
import 'package:health_app/screens/gym/gym_widget.dart';
import 'package:health_app/screens/health/metric_widget.dart';
import 'package:health_app/widgets/board_tiles.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/list_card.dart';
import 'package:health_app/screens/workouts/routines_screen.dart';
import 'package:health_app/screens/workouts/plan_editor_screen.dart';
import 'package:health_app/screens/gym/check_in_pass.dart';
import 'package:health_app/state/gym_store.dart';
import 'package:health_app/state/program_store.dart';
import 'package:health_app/widgets/widget_board.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/workout/workout_tracker.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/sync/health_sync_service.dart';

/// The Fitness tab: weekly progress, quick start, routines, records and
/// history.
class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  /// Sections that also come as small and medium widgets; the rest are
  /// large, full cards.
  static const _smallSections = {FitnessSection.week, FitnessSection.library};

  /// Everything the Fitness board can show: each section of the tab, and
  /// activity and heart data as metric widgets.
  static List<BoardEntry> catalog() => [
    BoardEntry(
      id: BoardIds.gym,
      label: 'Gym Check-In',
      icon: Icons.fitness_center_rounded,
      color: gymColor,
      group: 'Fitness',
      detail: 'Your membership card, ready to scan in',
      preferred: WidgetSize.medium,
      builder: (context, size) => GymWidget(size: size),
    ),
    BoardEntry(
      id: BoardIds.fitnessMore,
      label: 'More',
      icon: Icons.apps_rounded,
      color: fitnessGreen,
      group: 'Fitness',
      detail: 'Plans, routines, records and history in one short list',
      sizes: const {WidgetSize.large},
      builder: (context, size) => const _FitnessList(),
    ),
    for (final s in FitnessSection.values)
      BoardEntry(
        id: BoardIds.fitness(s),
        label: s.label,
        icon: s.icon,
        color: fitnessGreen,
        group: 'Fitness',
        sizes: _smallSections.contains(s)
            ? const {WidgetSize.small, WidgetSize.medium, WidgetSize.large}
            : const {WidgetSize.large},
        preferred: WidgetSize.large,
        builder: (context, size) => size == WidgetSize.large
            ? _FitnessSectionWidget(section: s)
            : _FitnessSmall(section: s, size: size),
      ),
    ...metricEntries(categories: BoardIds.metricCategories(BoardTab.fitness)),
  ];

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  final _board = BoardController();
  Future<WorkoutTracker?>? _unfinished;

  @override
  void dispose() {
    _board.dispose();
    super.dispose();
  }

  /// The unfinished workout, loaded when the store reports one.
  Future<WorkoutTracker?>? _checkpoint(WorkoutStore store) {
    if (!store.hasCheckpoint || LiveWorkoutScreen.isActive) {
      _unfinished = null;
      return null;
    }
    return _unfinished ??= store.loadCheckpoint().then(
      (c) => c == null
          ? null
          : WorkoutTracker.fromCheckpoint(
              c,
              bests: store.records.bestLifts,
              restDuration: Duration(seconds: store.settings.restSeconds),
            ),
    );
  }

  Future<void> _resume(WorkoutTracker t) async {
    _unfinished = null;
    await WorkoutLauncher.resume(context, t);
  }

  Future<void> _discardUnfinished() async {
    final ok = await confirmDestructive(
      context,
      message: 'The unfinished workout will be deleted.',
      action: 'Discard Workout',
    );
    if (!ok || !mounted) return;
    await context.read<WorkoutStore>().clearCheckpoint();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkoutStore>();
    final unfinished = _checkpoint(store);
    return LargeTitlePage(
      title: 'Fitness',
      trailing: BoardEditControls(
        controller: _board,
        tab: BoardTab.fitness,
        catalog: WorkoutsScreen.catalog,
        label: 'Edit Fitness',
        trailing: HeaderButton(
          icon: Icons.settings_rounded,
          semanticLabel: tr('Fitness Settings'),
          onTap: () => WorkoutSettingsScreen.open(context),
        ),
      ),
      children: [
        if (unfinished != null)
          FutureBuilder<WorkoutTracker?>(
            future: unfinished,
            builder: (context, snap) {
              final t = snap.data;
              if (t == null) return const SizedBox.shrink();
              return Appear(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ResumeCard(
                    tracker: t,
                    onResume: () => _resume(t),
                    onDiscard: _discardUnfinished,
                  ),
                ),
              );
            },
          ),
        // Keyed, so it isn't rebuilt (and faded in again) when content above
        // it comes and goes.
        Appear(
          key: const ValueKey('board'),
          child: WidgetBoard(
            tab: BoardTab.fitness,
            catalog: WorkoutsScreen.catalog(),
            controller: _board,
          ),
        ),
      ],
    );
  }
}

/// Opens the exercise library.
class _LibraryCard extends StatelessWidget {
  const _LibraryCard();

  @override
  Widget build(BuildContext context) => IosCard(
    onTap: () => ExerciseLibraryScreen.open(context),
    child: Row(
      children: [
        const IconTile(
          icon: Icons.menu_book_rounded,
          color: Palette.indigo,
          size: 36,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Exercise Library', style: context.headline),
              Text(
                'Search, browse by muscle, add your own',
                style: context.footnote.copyWith(color: context.secondaryLabel),
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
  );
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.tracker,
    required this.onResume,
    required this.onDiscard,
  });

  final WorkoutTracker tracker;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return IosCard(
      child: Row(
        children: [
          IconTile(
            icon: tracker.type.icon,
            color: tracker.type.color,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unfinished ${tracker.type.label}',
                  style: context.headline,
                ),
                Text(
                  '${formatClock(tracker.elapsed)} recorded',
                  style: context.footnote.copyWith(
                    color: context.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: onDiscard,
            child: Text(
              'Discard',
              style: TextStyle(color: context.destructive),
            ),
          ),
          CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            minimumSize: const Size(0, AppTheme.minTapTarget),
            onPressed: onResume,
            child: const Text('Resume'),
          ),
        ],
      ),
    );
  }
}

/// Weekly minutes against the goal, plus count, distance, energy, streak.
class _RoutineStrip extends StatelessWidget {
  const _RoutineStrip({required this.routines});

  final List<Routine> routines;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Taller with larger text, so the cards' lines fit.
      height: 60 + MediaQuery.textScalerOf(context).scale(72),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: routines.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final r = routines[i];
          return SizedBox(
            width: 180,
            child: IosCard(
              onTap: () => WorkoutLauncher.start(
                context,
                type: WorkoutType.strength,
                routine: r,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.headline,
                        ),
                      ),
                      if (!r.builtIn)
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size.square(AppTheme.minTapTarget),
                          onPressed: () =>
                              RoutineEditorScreen.open(context, routine: r),
                          child: Icon(
                            Icons.edit_rounded,
                            color: context.secondaryLabel,
                            semanticLabel: tr('Edit routine'),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      r.items
                          .map((i) => ExerciseLibrary.nameOf(i.exerciseId))
                          .join(', '),
                      overflow: TextOverflow.fade,
                      style: context.footnote.copyWith(
                        color: context.secondaryLabel,
                      ),
                    ),
                  ),
                  Text(
                    '${r.items.length} exercises',
                    style: context.caption1.copyWith(
                      color: WorkoutType.strength.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Headline numbers and recent weeks of activity; opens Stats.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkoutStore>();
    final today = store.today;
    final green = statsGreen(context);
    final numbers = [
      ('Workouts', store.all.length),
      ('This Month', workoutsThisMonth(store.all, today)),
      (
        'Week Streak',
        weekStreak(store.all, today, firstDay: store.plan.weekStart),
      ),
    ];
    return IosCard(
      onTap: () => StatsScreen.open(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final (label, value) in numbers)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedNumber(
                        value: value.toDouble(),
                        format: (v) => '${v.round()}',
                        style: context.number(28, weight: FontWeight.w700),
                      ),
                      Text(
                        label,
                        style: context.footnote.copyWith(
                          color: context.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          IgnorePointer(
            child: ActivityHeatmap(
              minutesByDay: activityByDay(store.all, today: today),
              today: today,
              color: green,
              weekStart: store.plan.weekStart,
              showLegend: false,
              weeks: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordsCard extends StatelessWidget {
  const _RecordsCard();

  @override
  Widget build(BuildContext context) {
    final r = context.watch<WorkoutStore>().records;
    final items = <(IconData, Color, String, String)>[
      if (r.fastest5kSeconds case final s?)
        (
          Icons.timer_rounded,
          WorkoutType.run.color,
          'Fastest 5K',
          formatClock(Duration(seconds: s)),
        ),
      if (r.fastestKmSeconds case final s?)
        (
          Icons.bolt_rounded,
          WorkoutType.run.color,
          // A kilometre's time, in miles or km alike.
          'Fastest km',
          formatClock(Duration(seconds: s)),
        ),
      if (r.longestRunMeters case final m? when m > 0)
        (
          Icons.map_rounded,
          WorkoutType.run.color,
          'Longest run',
          formatDistance(m),
        ),
      if (r.biggestVolumeKg case final v?)
        (
          Icons.insights_rounded,
          WorkoutType.strength.color,
          'Most volume',
          Units.weight(v, decimals: 0),
        ),
    ];
    return IosCard(
      onTap: () => RecordsScreen.open(context),
      child: items.isEmpty
          ? Row(
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  color: context.resolve(Palette.yellow),
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Complete workouts to set personal records.',
                    style: context.subheadline.copyWith(
                      color: context.secondaryLabel,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                for (final (icon, color, label, value) in items.take(3))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Icon(icon, color: color, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(label, style: context.subheadline),
                        ),
                        Text(
                          value,
                          style: context.headline.copyWith(color: color),
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'All records ›',
                    style: context.footnote.copyWith(color: context.tint),
                  ),
                ),
              ],
            ),
    );
  }
}

/// One workout in a list.
class WorkoutTile extends StatelessWidget {
  const WorkoutTile({super.key, required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final detail = [
      formatMinutes(s.activeDuration),
      if (s.distanceMeters >= 10) formatDistance(s.distanceMeters),
      if (s.activeKcal >= 1) formatKcal(s.activeKcal),
      if (s.completedSets > 0) '${s.completedSets} sets',
    ].join(' · ');
    final card = IosCard(
      padding: const EdgeInsets.all(12),
      onTap: () => WorkoutDetailScreen.open(context, s),
      child: Row(
        children: [
          IconTile(icon: s.type.icon, color: s.type.color, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.type.label, style: context.headline),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.footnote.copyWith(
                    color: context.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatDay(s.start, context.read<WorkoutStore>().today),
                style: context.footnote.copyWith(color: context.secondaryLabel),
              ),
              if (s.isImported)
                Text(
                  context.read<HealthSyncService>().sourceName,
                  style: context.caption2.copyWith(
                    color: context.tertiaryLabel,
                  ),
                )
              else
                Text(
                  DateFormat.jm().format(s.start),
                  style: context.caption2.copyWith(
                    color: context.tertiaryLabel,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
    return CupertinoContextMenu(
      enableHapticFeedback: true,
      actions: [
        CupertinoContextMenuAction(
          trailingIcon: Icons.description_outlined,
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
            WorkoutDetailScreen.open(context, s);
          },
          child: const Text('Show Details'),
        ),
        if (!s.isImported)
          CupertinoContextMenuAction(
            isDestructiveAction: true,
            trailingIcon: Icons.delete_outline_rounded,
            onPressed: () async {
              Navigator.of(context, rootNavigator: true).pop();
              final ok = await confirmDestructive(
                context,
                message: 'This workout and its activity data will be deleted.',
                action: 'Delete Workout',
              );
              if (ok && context.mounted) {
                await context.read<WorkoutStore>().delete(s.id);
              }
            },
            child: const Text('Delete'),
          ),
      ],
      // Fixed to the width it has in the list, so the menu preview
      // keeps the same layout.
      child: LayoutBuilder(
        builder: (context, c) => SizedBox(width: c.maxWidth, child: card),
      ),
    );
  }
}

/// Everything on the Fitness tab beyond starting a workout, as one list,
/// each row with how it stands.
class _FitnessList extends StatelessWidget {
  const _FitnessList();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkoutStore>();
    final program = context.watch<ProgramStore>().progress;
    final gym = context.watch<GymStore>();
    final today = store.todaySession();
    final planned = store.routineById(today.routineId);
    final custom = store.routines.where((r) => !r.builtIn).length;
    final records = store.records.bestLifts.length;
    final last = store.all.firstOrNull;
    return ListCard(
      items: [
        (
          icon: Icons.today_rounded,
          color: WorkoutType.strength.color,
          title: 'Weekly Plan',
          subtitle: store.plan.isEmpty
              ? 'Schedule your routines'
              : planned != null && !today.done
              ? 'Today: ${planned.name}'
              : today.done
              ? 'Done for today'
              : 'Rest day',
          onTap: () => PlanEditorScreen.open(context),
        ),
        (
          icon: Icons.flag_circle_rounded,
          color: Palette.mint,
          title: 'Programs',
          subtitle: program == null
              ? 'Couch to 5K, strength and more'
              : '${program.program.name} · ${program.completed} of '
                    '${program.program.sessionCount}',
          onTap: () => ProgramsScreen.open(context),
        ),
        (
          icon: Icons.format_list_bulleted_rounded,
          color: WorkoutType.strength.color,
          title: 'Routines',
          subtitle: custom == 0
              ? '${store.routines.length} ready to start'
              : '$custom of your own',
          onTap: () => RoutinesScreen.open(context),
        ),
        (
          icon: Icons.menu_book_rounded,
          color: Palette.indigo,
          title: 'Exercise Library',
          subtitle: 'Search or browse by muscle',
          onTap: () => ExerciseLibraryScreen.open(context),
        ),
        (
          icon: Icons.insights_rounded,
          color: fitnessGreen,
          title: 'Progress',
          subtitle:
              '${workoutsThisMonth(store.all, store.today)} workouts this month',
          onTap: () => StatsScreen.open(context),
        ),
        (
          icon: Icons.workspace_premium_rounded,
          color: Palette.yellow,
          title: 'Personal Records',
          subtitle: records == 0 ? 'Your bests appear here' : '$records lifts',
          onTap: () => RecordsScreen.open(context),
        ),
        (
          icon: Icons.schedule_rounded,
          color: Palette.blue,
          title: 'History',
          subtitle: last == null
              ? 'No workouts yet'
              : '${last.type.label} · ${formatDay(last.start, store.today)}',
          onTap: () => WorkoutHistoryScreen.open(context),
        ),
        (
          icon: Icons.fitness_center_rounded,
          color: gymColor,
          title: 'Gym Check-In',
          subtitle: gym.membership == null
              ? 'Add your membership card'
              : '${gym.thisWeek} visits this week',
          onTap: () => CheckInPass.open(context),
        ),
      ],
    );
  }
}

/// One section of the Fitness tab as a board widget.
class _FitnessSectionWidget extends StatelessWidget {
  const _FitnessSectionWidget({required this.section});

  final FitnessSection section;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkoutStore>();
    final recent = store.all.take(5).toList();
    final children = switch (section) {
      FitnessSection.today => [const TodayCard()],
      FitnessSection.suggestion => [const SuggestionCard()],
      FitnessSection.week => [const TrainingPulseCard()],
      FitnessSection.program => [
        SectionTitle(
          'Program',
          top: 0,
          action: 'All',
          onAction: () => ProgramsScreen.open(context),
        ),
        const ProgramCard(),
      ],
      FitnessSection.start => [
        const SectionTitle('Start a Workout', top: 0),
        const QuickStart(),
      ],
      FitnessSection.library => [const _LibraryCard()],
      FitnessSection.routines => [
        SectionTitle(
          'Routines',
          top: 0,
          action: 'New',
          onAction: () => RoutineEditorScreen.open(context),
        ),
        _RoutineStrip(routines: store.routines),
      ],
      FitnessSection.progress => [
        SectionTitle(
          'Progress',
          top: 0,
          action: 'Stats',
          onAction: () => StatsScreen.open(context),
        ),
        const _ProgressCard(),
      ],
      FitnessSection.records => [
        SectionTitle(
          'Personal Records',
          top: 0,
          action: 'All',
          onAction: () => RecordsScreen.open(context),
        ),
        const _RecordsCard(),
      ],
      FitnessSection.history => [
        SectionTitle(
          'History',
          top: 0,
          action: store.all.length > 5 ? 'See All' : 'Log',
          onAction: store.all.length > 5
              ? () => WorkoutHistoryScreen.open(context)
              : () => WorkoutEditScreen.open(context),
        ),
        if (recent.isEmpty)
          IosCard(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Your workouts will appear here. Pick one above to begin.',
              textAlign: TextAlign.center,
              style: context.subheadline.copyWith(
                color: context.secondaryLabel,
              ),
            ),
          )
        else
          for (final w in recent)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: WorkoutTile(session: w),
            ),
      ],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

/// A Fitness section as a small or medium widget: the week's minutes
/// against the goal, or a way into the exercise library.
class _FitnessSmall extends StatelessWidget {
  const _FitnessSmall({required this.section, required this.size});

  final FitnessSection section;
  final WidgetSize size;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkoutStore>();
    if (section == FitnessSection.library) {
      return StatWidget(
        size: size,
        icon: Icons.menu_book_rounded,
        color: Palette.indigo,
        title: 'Exercises',
        semanticLabel: tr('Exercise Library'),
        onTap: () => ExerciseLibraryScreen.open(context),
        value: StatValue('Find a move', size: size, placeholder: true),
        caption: 'Search or browse by muscle',
      );
    }
    final week = store.thisWeek;
    final goal = store.settings.weeklyGoalMinutes;
    return StatWidget(
      size: size,
      icon: Icons.pie_chart_rounded,
      color: fitnessGreen,
      title: 'This Week',
      semanticLabel:
          'This week, ${week.minutes}${goal > 0 ? ' of $goal' : ''} minutes',
      onTap: () => StatsScreen.open(context),
      value: StatValue('${week.minutes}', unit: 'min', size: size),
      caption: goal > 0
          ? (week.minutes >= goal ? 'Goal reached' : 'of $goal min goal')
          : '${week.count} workouts',
      smallVisual: goal > 0
          ? BarVisual(progress: week.minutes / goal, color: fitnessGreen)
          : null,
      facts: [
        (label: 'Workouts', value: '${week.count}'),
        (label: 'Calories', value: '${week.kcal.round()} Cal'),
        (label: 'Day Streak', value: '${store.streak}'),
      ],
    );
  }
}
