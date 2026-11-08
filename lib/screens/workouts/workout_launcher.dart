import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/models/exercise_library.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/notifications/notification_controller.dart';
import 'package:health_app/screens/workouts/live_workout_screen.dart';
import 'package:health_app/screens/workouts/workout_goal.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/workout_art.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/workout/calories.dart';
import 'package:health_app/workout/intervals.dart';
import 'package:health_app/workout/location_source.dart';
import 'package:health_app/workout/session_builder.dart';
import 'package:health_app/workout/workout_tracker.dart';
import 'package:health_app/widgets/app_segmented.dart';

/// Starts workouts: shows the setup sheet, checks permissions and opens
/// the live workout screen.
abstract final class WorkoutLauncher {
  /// Shows the setup sheet for [type] (goal, program or routine).
  static Future<void> showSetup(BuildContext context, WorkoutType type) async {
    // One workout at a time: a minimized one comes back instead.
    if (LiveWorkoutScreen.isActive) return LiveWorkoutScreen.reopen(context);
    await showCupertinoSheet<void>(
      context: context,
      scrollableBuilder: (context, controller) =>
          _SetupSheet(type: type, controller: controller),
    );
  }

  /// Opens the live screen after checking permissions.
  static Future<void> start(
    BuildContext context, {
    required WorkoutType type,
    WorkoutGoal goal = WorkoutGoal.open,
    IntervalProgram? program,
    Routine? routine,
  }) async {
    // Only one workout at a time (also stops double taps).
    if (LiveWorkoutScreen.isActive) return LiveWorkoutScreen.reopen(context);
    if (_starting) return;
    _starting = true;
    try {
      await _start(
        context,
        type: type,
        goal: goal,
        program: program,
        routine: routine,
      );
    } finally {
      _starting = false;
    }
  }

  static bool _starting = false;

  static Future<void> _start(
    BuildContext context, {
    required WorkoutType type,
    required WorkoutGoal goal,
    IntervalProgram? program,
    Routine? routine,
  }) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (type.usesGps && !await _ensureLocation(context)) return;
    if (!context.mounted) return;
    // The workout notification needs permission on Android 13+; the
    // workout still runs without it.
    await context.read<NotificationController>().notifier.requestPermission();
    if (!context.mounted) return;
    final health = context.read<HealthStore>();
    final weight =
        health.latestReading(MetricType.weight)?.value ?? defaultWeightKg;
    final store = context.read<WorkoutStore>();
    final planned = routine == null
        ? const <PlannedExercise>[]
        : buildSession(
            routine,
            recentSets: store.recentSets,
            isTimed: (id) => ExerciseCatalog.instance.byId(id)?.timed ?? false,
          );
    final tracker = WorkoutTracker(
      type: type,
      weightKg: weight,
      program: program,
      routineId: routine?.id,
      bests: store.records.bestLifts,
      hints: {for (final p in planned) p.log.exerciseId: ?p.hint},
      restDuration: Duration(seconds: store.settings.restSeconds),
      exercises: [for (final p in planned) p.log],
    );
    await navigator.push(
      AppRoute<void>(
        fullscreenDialog: true,
        builder: (_) => LiveWorkoutScreen(tracker: tracker, goal: goal),
      ),
    );
  }

  /// Re-opens a workout restored from a checkpoint. Ignored while a
  /// workout is open or starting, so a double tap opens it once.
  static Future<void> resume(
    BuildContext context,
    WorkoutTracker tracker,
  ) async {
    if (LiveWorkoutScreen.isActive || _starting) return;
    _starting = true;
    try {
      final route = AppRoute<void>(
        fullscreenDialog: true,
        builder: (_) => LiveWorkoutScreen(tracker: tracker, restored: true),
      );
      final done = Navigator.of(context, rootNavigator: true).push(route);
      // Released once the screen is up; from then on it counts as active.
      await route.didPush();
      _starting = false;
      await done;
    } finally {
      _starting = false;
    }
  }

  static Future<bool> _ensureLocation(BuildContext context) async {
    final location = context.read<LocationSource>();
    final access = await location.ensureAccess();
    if (access == LocationAccess.granted || !context.mounted) {
      return access == LocationAccess.granted;
    }
    final off = access == LocationAccess.servicesOff;
    final open = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(off ? 'Location Is Off' : 'Location Needed'),
        content: Text(
          off
              ? 'Turn on Location to record your route, distance and pace.'
              : 'Allow location access to record your route, distance and '
                    'pace. Health uses it only during a workout.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    if (open ?? false) await location.openSettings(access);
    return false;
  }
}

class _SetupSheet extends StatefulWidget {
  const _SetupSheet({required this.type, required this.controller});

  final WorkoutType type;
  final ScrollController controller;

  @override
  State<_SetupSheet> createState() => _SetupSheetState();
}

class _SetupSheetState extends State<_SetupSheet> {
  GoalKind _kind = GoalKind.open;
  double _target = 30;

  static const _defaults = {
    GoalKind.time: 30.0,
    GoalKind.distance: 5.0,
    GoalKind.calories: 300.0,
  };
  static const _steps = {
    GoalKind.time: 5.0,
    GoalKind.distance: 0.5,
    GoalKind.calories: 50.0,
  };

  WorkoutType get type => widget.type;

  /// Distance targets are picked in the user's units (km or mi) and
  /// stored in kilometres.
  double _stored(double shown) =>
      _kind == GoalKind.distance ? Units.distanceIn(shown) : shown;

  void _go({IntervalProgram? program, Routine? routine}) {
    final goal = _kind == GoalKind.open
        ? WorkoutGoal.open
        : WorkoutGoal(_kind, _stored(_target));
    final root = Navigator.of(context, rootNavigator: true).context;
    CupertinoSheetRoute.popSheet(context);
    WorkoutLauncher.start(
      root,
      type: type,
      goal: goal,
      program: program,
      routine: routine,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        // Sheets don't morph the title from the page below, as on iOS;
        // every bar shares one hero tag, so it would fly into the sheet.
        transitionBetweenRoutes: false,
        automaticallyImplyLeading: false,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => CupertinoSheetRoute.popSheet(context),
          child: const Text('Cancel'),
        ),
        middle: Text(type.label),
      ),
      child: PageList(
        controller: widget.controller,
        padding: const EdgeInsets.fromLTRB(
          AppTheme.margin,
          16,
          AppTheme.margin,
          32,
        ),
        children: [
          // The workout, pictured, as a header.
          SizedBox(height: 200, child: WorkoutArt(type: type)),
          const SizedBox(height: 12),
          _SafetyNote(type: type),
          const SizedBox(height: 16),
          ...switch (type.kind) {
            WorkoutKind.intervals => _programs(context),
            WorkoutKind.strength => _routines(context),
            WorkoutKind.gps || WorkoutKind.timed => [
              ..._goal(context),
              if (IntervalProgram.forType(type).isNotEmpty) ...[
                const SizedBox(height: 28),
                Text('Or Follow a Guided Flow', style: context.title3),
                const SizedBox(height: 4),
                Text(
                  'Timed moves with a countdown for each, and a short '
                  'pause to get into the next.',
                  style: context.footnote.copyWith(
                    color: context.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 10),
                ..._programCards(context),
              ],
            ],
          },
        ],
      ),
    );
  }

  List<Widget> _goal(BuildContext context) {
    final kinds = [
      GoalKind.open,
      GoalKind.time,
      if (type.usesGps) GoalKind.distance,
      GoalKind.calories,
    ];
    final step = _steps[_kind] ?? 1;
    return [
      AppSegmented<GoalKind>(
        groupValue: _kind,
        children: {
          for (final k in kinds)
            k: Text(switch (k) {
              GoalKind.open => 'Open',
              GoalKind.time => 'Time',
              GoalKind.distance => 'Distance',
              GoalKind.calories => 'Calories',
            }),
        },
        onValueChanged: (k) => setState(() {
          _kind = k ?? GoalKind.open;
          _target = _defaults[_kind] ?? 0;
        }),
      ),
      const SizedBox(height: 24),
      AnimatedSwitcher(
        duration: Motion.fast,
        child: _kind == GoalKind.open
            ? Text(
                'Track freely with no target.',
                key: const ValueKey('open'),
                textAlign: TextAlign.center,
                style: context.body.copyWith(color: context.secondaryLabel),
              )
            : Row(
                key: ValueKey(_kind),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RoundButton(
                    icon: Icons.remove_rounded,
                    onTap: _target > step
                        ? () => setState(() => _target -= step)
                        : null,
                  ),
                  Expanded(
                    child: Text(
                      WorkoutGoal(_kind, _stored(_target)).label,
                      textAlign: TextAlign.center,
                      style: context.largeTitle,
                    ),
                  ),
                  _RoundButton(
                    icon: Icons.add_rounded,
                    onTap: () => setState(() => _target += step),
                  ),
                ],
              ),
      ),
      const SizedBox(height: 32),
      CupertinoButton.filled(onPressed: _go, child: const Text('Start')),
    ];
  }

  List<Widget> _programs(BuildContext context) => [
    Text('Choose a Program', style: context.title3),
    const SizedBox(height: 8),
    ..._programCards(context),
  ];

  List<Widget> _programCards(BuildContext context) => [
    for (final (i, p) in IntervalProgram.forType(type).indexed)
      _playCard(
        context,
        index: i,
        title: p.name,
        subtitle: '${p.summary} · ${(p.total.inSeconds / 60).ceil()} min',
        onTap: () => _go(program: p),
      ),
  ];

  List<Widget> _routines(BuildContext context) {
    final routines = context.read<WorkoutStore>().routines;
    return [
      IosCard(
        onTap: _go,
        child: Row(
          children: [
            Icon(
              Icons.add_circle_rounded,
              color: context.resolve(type.color),
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Empty Workout', style: context.headline)),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Text('Routines', style: context.title3),
      const SizedBox(height: 8),
      for (final (i, r) in routines.indexed)
        _playCard(
          context,
          index: i,
          title: r.name,
          subtitle: r.items
              .map((i) => ExerciseLibrary.nameOf(i.exerciseId))
              .join(', '),
          maxLines: 2,
          onTap: () => _go(routine: r),
        ),
    ];
  }

  /// A tappable program or routine with a play button.
  Widget _playCard(
    BuildContext context, {
    required int index,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int? maxLines,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Appear(
      index: index,
      child: IosCard(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.headline),
                  Text(
                    subtitle,
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                    style: context.footnote.copyWith(
                      color: context.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.play_circle_rounded,
              color: context.resolve(type.color),
              size: 34,
            ),
          ],
        ),
      ),
    ),
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap?.call();
            },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: context.fillColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: onTap == null ? context.tertiaryLabel : context.labelColor,
        ),
      ),
    );
  }
}

/// A line on staying safe doing [type], and stopping if something's wrong.
class _SafetyNote extends StatelessWidget {
  const _SafetyNote({required this.type});

  final WorkoutType type;

  static String? _advice(WorkoutType type) => switch (type) {
    WorkoutType.aerialSilks ||
    WorkoutType.aerialHoop ||
    WorkoutType.poleFitness =>
      'Train with a qualified instructor, on '
          'professionally rigged equipment, over a crash mat.',
    WorkoutType.trampoline =>
      'One person at a time, with safety nets or '
          'spotters; no flips without coaching.',
    WorkoutType.paragliding =>
      'Fly only with training, checked equipment '
          'and suitable weather.',
    WorkoutType.climbing =>
      'Check knots, harness and belay, or climb over '
          'crash pads.',
    WorkoutType.surfing ||
    WorkoutType.paddleboard ||
    WorkoutType.kayaking ||
    WorkoutType.openWaterSwim =>
      'Check conditions, wear a leash or life '
          'jacket, and never go alone.',
    WorkoutType.skiing || WorkoutType.snowboarding =>
      'Wear a helmet and '
          'stay on runs that suit your ability.',
    WorkoutType.skateboarding || WorkoutType.parkour =>
      'Wear a helmet and '
          'pads, and stay clear of traffic.',
    WorkoutType.boxing || WorkoutType.martialArts || WorkoutType.fencing =>
      'Use the right protective gear, with a coach for sparring.',
    _ when type.usesGps =>
      'Watch for traffic and your surroundings, and '
          'never look at your phone while driving or in traffic.',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final advice = _advice(type);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            Icons.health_and_safety_rounded,
            size: 16,
            color: context.secondaryLabel,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${advice == null ? '' : '$advice '}Stop if you feel pain, '
            'dizziness or short of breath.',
            style: context.footnote.copyWith(color: context.secondaryLabel),
          ),
        ),
      ],
    );
  }
}
