import 'dart:async';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/notifications/notification_controller.dart';
import 'package:health_app/screens/workouts/active_workout.dart';
import 'package:health_app/screens/workouts/live_workout_widgets.dart';
import 'package:health_app/screens/workouts/strength_panel.dart';
import 'package:health_app/screens/workouts/workout_detail_screen.dart';
import 'package:health_app/screens/workouts/workout_goal.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/utils/log.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/widgets/route_map.dart';
import 'package:health_app/workout/location_source.dart';
import 'package:health_app/workout/workout_tracker.dart';
import 'package:health_app/utils/units.dart';

/// Full-screen live workout, styled like Apple's Workout app: large timer,
/// live metrics, route, goal progress and big controls.
class LiveWorkoutScreen extends StatefulWidget {
  const LiveWorkoutScreen({
    super.key,
    required this.tracker,
    this.goal = WorkoutGoal.open,
    this.restored = false,
  });

  final WorkoutTracker tracker;
  final WorkoutGoal goal;

  /// Reopened from a checkpoint: starts paused, without a countdown.
  final bool restored;

  /// True while a workout is being recorded, on screen or minimized; only
  /// one can run at a time.
  static bool get isActive =>
      _active > 0 || ActiveWorkout.instance.tracker != null;
  static int _active = 0;

  /// Brings the minimized workout back on screen.
  static Future<void> reopen(BuildContext context) async {
    final active = ActiveWorkout.instance;
    final t = active.tracker;
    if (t == null || _active > 0) return;
    await Navigator.of(context, rootNavigator: true).push(
      AppRoute<void>(
        fullscreenDialog: true,
        builder: (_) => LiveWorkoutScreen(tracker: t, goal: active.goal),
      ),
    );
  }

  @override
  State<LiveWorkoutScreen> createState() => _LiveWorkoutScreenState();
}

class _LiveWorkoutScreenState extends State<LiveWorkoutScreen> {
  final _active = ActiveWorkout.instance;
  late final WorkoutStore _store;
  int? _countdown;
  String? _toast;
  Timer? _toastTimer;

  /// Set once End was chosen, so the workout can't be ended twice.
  bool _ending = false;

  WorkoutTracker get t => widget.tracker;

  @override
  void initState() {
    super.initState();
    LiveWorkoutScreen._active++;
    _store = context.read<WorkoutStore>();
    _active
      ..adopt(
        t,
        goal: widget.goal,
        notifier: context.read<NotificationController>().notifier,
        store: _store,
        location: context.read<LocationSource>(),
      )
      ..expand()
      ..onMessage = _showToast;
    unawaited(WakelockPlus.enable().catchError((Object _) {}));
    // Start after the first frame, once the screen's context is ready;
    // a workout brought back from minimized is already going.
    if (_active.recording) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.restored) {
        _active.record();
      } else {
        unawaited(_runCountdown());
      }
    });
  }

  @override
  void dispose() {
    LiveWorkoutScreen._active--;
    unawaited(WakelockPlus.disable().catchError((Object _) {}));
    if (_active.onMessage == _showToast) _active.onMessage = null;
    // Minimized, it keeps recording; otherwise it has ended.
    if (!_active.minimized && identical(_active.tracker, t)) _active.finish();
    _toastTimer?.cancel();
    super.dispose();
  }

  Future<void> _runCountdown() async {
    final reduced = Motion.reduced(context);
    for (var i = 3; i >= 1 && !reduced; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      unawaited(HapticFeedback.mediumImpact());
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    if (!mounted) return;
    setState(() => _countdown = null);
    unawaited(HapticFeedback.heavyImpact());
    t.start();
    _active.record();
  }

  /// Closes the screen while the workout keeps recording, so the rest of
  /// the app can be used; a bar above the tabs brings it back.
  void _minimize() {
    if (_countdown != null || _ending) return;
    unawaited(HapticFeedback.selectionClick());
    _active.minimize();
    Navigator.of(context).pop();
  }

  void _showToast(String text) {
    if (!mounted) return;
    _toastTimer?.cancel();
    setState(() => _toast = text);
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _togglePause() => _active.togglePause();

  Future<void> _end() async {
    if (_ending) return;
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('End this workout?'),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, 'end'),
            child: const Text('End and Save'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard Workout'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep Going'),
        ),
      ),
    );
    if (!mounted || choice == null || _ending) return;
    setState(() => _ending = true);
    await _active.stopRecording();
    if (!mounted) return;
    if (choice == 'discard') {
      await _store.clearCheckpoint();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    // Keep the checkpoint until the workout is saved, so it can still be
    // recovered if the app is closed on the summary screen. Paused, so a
    // recovery doesn't count the time since as part of the workout.
    t.pause();
    try {
      await _store.saveCheckpoint(t.toCheckpoint());
    } on Exception catch (e) {
      // Only the recovery copy is lost; the workout itself is still saved
      // from the summary, so finishing mustn't stop here.
      logError('Workout: could not save the checkpoint before ending: $e');
    }
    if (!mounted) return;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final (session, route) = t.finish(id: id);
    await Navigator.of(context).pushReplacement(
      AppRoute<void>(
        builder: (_) =>
            WorkoutDetailScreen.review(session: session, route: route),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = t.type;
    return PopScope(
      canPop: false,
      // Back minimizes: the workout keeps going while the app is used.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _minimize();
      },
      // In the app's theme, like every other screen.
      child: CupertinoPageScaffold(
        backgroundColor: context.groupedBackground,
        child: Stack(
          children: [
            SafeArea(
              child: ListenableBuilder(
                listenable: t,
                builder: (context, _) => _content(context),
              ),
            ),
            if (_toast case final text?)
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: LiveToast(text: text, color: type.color),
                ),
              ),
            if (_countdown case final n?)
              StartCountdown(value: n, color: type.color),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final type = t.type;
    final goal = _active.goalProgress;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size.square(AppTheme.minTapTarget),
                onPressed: _countdown == null && !_ending ? _minimize : null,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 30,
                  color: context.secondaryLabel,
                  semanticLabel: tr('Minimize'),
                ),
              ),
              const SizedBox(width: 4),
              Icon(type.icon, color: context.resolve(type.color), size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text(type.label, style: context.headline)),
              if (t.status == TrackerStatus.paused)
                Text(
                  'PAUSED',
                  style: context.footnote.copyWith(
                    color: context.resolve(Palette.yellow),
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            children: [
              LiveTimer(
                elapsed: t.elapsed,
                paused: t.status == TrackerStatus.paused,
                size: type.kind == WorkoutKind.strength && t.program == null
                    ? 56
                    : 84,
              ),
              if (goal != null) ...[
                const SizedBox(height: 4),
                LiveGoalBar(
                  progress: goal,
                  label: widget.goal.label,
                  color: type.color,
                ),
              ],
              const SizedBox(height: 16),
              ...switch (type.kind) {
                _ when t.program != null => [IntervalRingView(tracker: t)],
                WorkoutKind.intervals => [IntervalRingView(tracker: t)],
                WorkoutKind.strength => [StrengthPanel(tracker: t)],
                WorkoutKind.gps => _gpsMetrics(context),
                WorkoutKind.timed => [_metrics(context)],
              },
            ],
          ),
        ),
        LiveControls(
          color: type.color,
          running: t.status == TrackerStatus.running,
          enabled: _countdown == null && !_ending,
          showLap:
              type.kind == WorkoutKind.gps || type.kind == WorkoutKind.timed,
          onLap: () {
            unawaited(HapticFeedback.mediumImpact());
            t.lap();
            _active.updateOngoing();
            _showToast(
              'Lap ${t.laps.length} · ${formatClock(Duration(seconds: t.laps.last.seconds))}',
            );
          },
          onPause: _togglePause,
          onEnd: _end,
        ),
      ],
    );
  }

  List<Widget> _gpsMetrics(BuildContext context) => [
    _metrics(context),
    const SizedBox(height: 16),
    ClippedCard(
      radius: AppTheme.radius,
      child: SizedBox(
        height: 200,
        child: ColoredBox(
          color: context.cardBackground,
          child: RouteMap(
            points: t.route,
            style: _store.settings.mapStyle,
            color: t.type.color,
          ),
        ),
      ),
    ),
    if (t.splits.isNotEmpty) ...[
      const SizedBox(height: 16),
      Text('Splits', style: context.headline),
      for (final (i, s) in t.splits.indexed)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Text('${i + 1} km', style: context.subheadline),
              ),
              Expanded(
                child: Text(
                  // Each split is the time for that kilometre.
                  formatClock(Duration(seconds: s)),
                  style: context.subheadline.copyWith(color: t.type.color),
                ),
              ),
            ],
          ),
        ),
    ],
  ];

  Widget _metrics(BuildContext context) {
    final type = t.type;
    final tiles = <(String, String)>[
      if (type.usesGps) ('DISTANCE', formatDistance(t.distanceMeters)),
      if (type.showsSpeed) ...[
        ('SPEED', '${formatSpeed(t.currentSpeedMps)} ${Units.speedUnit}'),
        (
          'AVG SPEED',
          '${formatSpeed(switch (t.averagePaceSecondsPerKm) {
            final p? => 1000 / p,
            null => null,
          })} ${Units.speedUnit}',
        ),
      ] else if (type.usesGps) ...[
        (
          'CURRENT PACE',
          '${formatPace(t.currentPaceSecondsPerKm)} ${Units.paceUnit}',
        ),
        (
          'AVG PACE',
          '${formatPace(t.averagePaceSecondsPerKm)} ${Units.paceUnit}',
        ),
      ],
      if (type.usesGps && t.topSpeedMps != null)
        ('TOP SPEED', '${formatSpeed(t.topSpeedMps)} ${Units.speedUnit}'),
      ('ACTIVE KCAL', t.activeKcal.round().toString()),
      if (type.usesGps && t.elevationGainMeters > 0)
        ('ELEV GAIN', Units.elevation(t.elevationGainMeters)),
      if (t.laps.isNotEmpty) ('LAPS', '${t.laps.length}'),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final (label, value) in tiles)
          LiveMetricTile(label: label, value: value, color: type.color),
      ],
    );
  }
}
