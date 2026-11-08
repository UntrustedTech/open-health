import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:health_app/models/exercise_library.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/notifications/notifier.dart';
import 'package:health_app/platform/live_activity.dart';
import 'package:health_app/screens/workouts/workout_goal.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/workout/intervals.dart';
import 'package:health_app/workout/location_source.dart';
import 'package:health_app/workout/workout_tracker.dart';

/// The workout being recorded. Its clock, GPS, recovery copy and ongoing
/// notification live here rather than in the live screen, so the screen
/// can be minimized and the rest of the app used while it keeps going.
class ActiveWorkout extends ChangeNotifier with WidgetsBindingObserver {
  ActiveWorkout._();

  /// Only one workout is recorded at a time.
  static final instance = ActiveWorkout._();

  static const _checkpointEvery = Duration(seconds: 15);

  WorkoutTracker? _tracker;
  WorkoutGoal _goal = WorkoutGoal.open;
  Notifier? _notifier;
  WorkoutStore? _store;
  LocationSource? _location;
  Timer? _ticker;
  StreamSubscription<Object>? _gps;
  DateTime _lastCheckpoint = DateTime.now();
  bool _foreground = true;
  bool _minimized = false;
  bool _goalCelebrated = false;

  /// The iPhone Lock Screen shows the workout, so no notification is needed.
  bool _liveActivity = false;

  WorkoutTracker? get tracker => _tracker;
  WorkoutGoal get goal => _goal;

  /// The live screen is closed while the workout keeps recording.
  bool get minimized => _minimized && _tracker != null;

  /// The clock is running (after the countdown, until the workout ends).
  bool get recording => _ticker != null;

  /// Shows a short note on the live screen while it's open; null when no
  /// screen is showing the workout.
  void Function(String text)? onMessage;

  double? get goalProgress => switch (_tracker) {
    final t? => _goal.progress(
      elapsed: t.elapsed,
      meters: t.distanceMeters,
      kcal: t.activeKcal,
    ),
    null => null,
  };

  /// Takes on [tracker] as the workout being recorded.
  void adopt(
    WorkoutTracker tracker, {
    required WorkoutGoal goal,
    required Notifier notifier,
    required WorkoutStore store,
    required LocationSource location,
  }) {
    if (identical(tracker, _tracker)) return;
    _halt();
    _tracker = tracker;
    _goal = goal;
    _notifier = notifier;
    _store = store;
    _location = location;
    _minimized = false;
    _goalCelebrated = false;
    tracker
      ..onPhaseChange = _onPhase
      ..onRestStart = _onRest
      ..onRestEnd = _onRestEnd
      ..onRestComplete = _onRestComplete
      ..onSplit = _onSplit
      ..onPersonalRecord = _onRecord;
    notifyListeners();
  }

  /// Starts the once-a-second tick, GPS and the ongoing notification.
  void record() {
    final t = _tracker;
    if (t == null || _ticker != null) return;
    WidgetsBinding.instance.addObserver(this);
    _lastCheckpoint = DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    if (t.type.usesGps) {
      _gps = _location?.positions().listen(
        t.addLocation,
        onError: (Object e) => _say('GPS signal lost'),
      );
    }
    unawaited(_startLiveActivity(t));
    notifyListeners();
  }

  Future<void> _startLiveActivity(WorkoutTracker t) async {
    _liveActivity = await LiveActivity.start(t);
    // Finished or replaced while starting.
    if (!identical(t, _tracker) || _ticker == null) {
      if (_liveActivity) unawaited(LiveActivity.end());
      _liveActivity = false;
      return;
    }
    updateOngoing();
  }

  void minimize() {
    if (_tracker == null || _minimized) return;
    _minimized = true;
    notifyListeners();
  }

  void expand() {
    if (!_minimized) return;
    _minimized = false;
    notifyListeners();
  }

  void togglePause() {
    final t = _tracker;
    if (t == null) return;
    unawaited(HapticFeedback.mediumImpact());
    if (t.status == TrackerStatus.running) {
      t.pause();
      unawaited(_store?.saveCheckpoint(t.toCheckpoint()));
    } else {
      t.resume();
    }
    updateOngoing();
  }

  /// The ongoing notification, its timer stopped while paused. GPS
  /// workouts have the location service's notification instead.
  void updateOngoing() {
    final t = _tracker;
    if (t == null) return;
    if (_liveActivity) {
      unawaited(LiveActivity.update(t));
      return;
    }
    if (t.type.usesGps) return;
    unawaited(
      _notifier?.showWorkoutOngoing(
        t.type.label,
        DateTime.now().subtract(t.elapsed),
        paused: t.status == TrackerStatus.paused,
      ),
    );
  }

  /// Stops the clock and GPS once End is chosen; the tracker stays for
  /// the summary.
  Future<void> stopRecording() async {
    _endLiveActivity();
    _ticker?.cancel();
    _ticker = null;
    await _gps?.cancel();
    _gps = null;
  }

  /// The workout is over (saved or discarded): lets everything go.
  void finish() {
    _halt();
    _tracker = null;
    _minimized = false;
    onMessage = null;
    notifyListeners();
  }

  void _halt() {
    final t = _tracker;
    if (t != null) {
      if (t.onPhaseChange == _onPhase) t.onPhaseChange = null;
      if (t.onRestStart == _onRest) t.onRestStart = null;
      if (t.onRestEnd == _onRestEnd) t.onRestEnd = null;
      if (t.onRestComplete == _onRestComplete) t.onRestComplete = null;
      if (t.onSplit == _onSplit) t.onSplit = null;
      if (t.onPersonalRecord == _onRecord) t.onPersonalRecord = null;
    }
    if (_ticker != null) WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _ticker = null;
    unawaited(_gps?.cancel());
    _gps = null;
    unawaited(_notifier?.cancelWorkoutOngoing());
    unawaited(_notifier?.cancelRestTimer());
    _endLiveActivity();
  }

  void _endLiveActivity() {
    if (!_liveActivity) return;
    _liveActivity = false;
    unawaited(LiveActivity.end());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    final t = _tracker;
    // Save progress whenever the app is backgrounded, in case it's closed.
    if (!_foreground && t != null && t.status != TrackerStatus.finished) {
      unawaited(_store?.saveCheckpoint(t.toCheckpoint()));
    }
  }

  void _tick() {
    final t = _tracker;
    if (t == null) return;
    t.tick();
    final now = DateTime.now();
    if (now.difference(_lastCheckpoint) >= _checkpointEvery) {
      _lastCheckpoint = now;
      unawaited(_store?.saveCheckpoint(t.toCheckpoint()));
      // New distance; the clock counts by itself.
      if (_liveActivity && t.type.usesGps) unawaited(LiveActivity.update(t));
    }
    final p = goalProgress;
    if (p != null && p >= 1 && !_goalCelebrated) {
      _goalCelebrated = true;
      unawaited(HapticFeedback.heavyImpact());
      _say('Goal reached', alert: ('Goal reached', _goal.label));
    }
  }

  /// [text] on the live screen when it's in view; otherwise [alert] as a
  /// notification, if there is one.
  void _say(String text, {(String, String)? alert}) {
    final show = onMessage;
    if (show != null && !_minimized && _foreground) {
      show(text);
    } else if (alert case (final title, final body)) {
      unawaited(_notifier?.showMessage(title, body));
    }
  }

  void _onPhase(IntervalPhase? phase) {
    unawaited(HapticFeedback.heavyImpact());
    final text = phase == null
        ? 'Program complete'
        : phase.name != null
        ? phase.label
        : '${phase.label}${phase.round > 0 ? ' · Round ${phase.round}' : ''}';
    _say(text, alert: (text, _tracker?.type.label ?? ''));
  }

  void _onRest(Duration rest) => unawaited(_notifier?.showRestTimer(rest));

  void _onRestEnd() => unawaited(_notifier?.cancelRestTimer());

  /// The rest ran out: a buzz and a note on screen, or an alert when the
  /// screen isn't in view.
  void _onRestComplete() {
    unawaited(_notifier?.cancelRestTimer());
    unawaited(HapticFeedback.heavyImpact());
    _say(
      'Rest over: next set',
      alert: ('Rest over', 'Time for your next set.'),
    );
  }

  void _onRecord(String exerciseId, SetLog set) {
    unawaited(HapticFeedback.heavyImpact());
    _say('🏆 New Personal Record: ${ExerciseLibrary.nameOf(exerciseId)}');
  }

  void _onSplit(int number, int seconds) {
    unawaited(HapticFeedback.mediumImpact());
    final time = formatClock(Duration(seconds: seconds));
    _say(Units.imperial ? 'Mile $number · $time' : 'Kilometre $number · $time');
  }
}
