import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:health_app/backup/auto_backup.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/notifications/notification_controller.dart';
import 'package:health_app/platform/home_widgets.dart';
import 'package:health_app/security/app_lock.dart';
import 'package:health_app/state/fasting_store.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/mood_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/sync/background_sync.dart';
import 'package:health_app/sync/health_sync_service.dart';

/// When this app's copy of the data was last loaded or confirmed current.
DateTime _loadedAt = DateTime.now();

/// Records that the data is being loaded now. Called at launch, as the
/// value above is only set when first read (at the first resume), which
/// would make a background save in between look already loaded.
void noteDataLoaded() => _loadedAt = DateTime.now();

/// Brings everything up to date when the app returns to the foreground.
Future<void> onAppResumed(BuildContext context) async {
  final health = context.read<HealthStore>();
  final sync = context.read<HealthSyncService>();
  final workouts = context.read<WorkoutStore>();
  final notifications = context.read<NotificationController>();
  final autoBackup = context.read<AutoBackup>();
  final lock = context.read<AppLock>();
  final fasting = context.read<FastingStore>();
  final mood = context.read<MoodStore>();
  // A background check may have saved new data while the app was away:
  // load it before anything here saves over it.
  final saved = await AppPresence.backgroundSavedAt();
  if (saved != null && saved.isAfter(_loadedAt)) {
    await health.load();
    await workouts.load();
    await sync.reload();
    // Habits ticked from the notification while the app was closed.
    await mood.load();
  }
  _loadedAt = DateTime.now();
  health.refresh();
  await HomeWidgets.drainPendingWater(health);
  // Before syncing, so a slow sync never holds reminders up; data the
  // sync brings in re-plans them again through the coordinator.
  await notifications.reschedule();
  await sync.refreshStatus();
  await sync.refreshPermissions();
  await sync.autoSync(SyncTrigger.resume);
  await HomeWidgets.update(
    health,
    workouts,
    hidden: lock.hidesWidgets,
    fasting: fasting,
  );
  await autoBackup.maybeRun();
}

/// Reacts to data changes: refreshes home screen widgets (debounced) and
/// re-plans the evening ring reminder once today's Move goal is met.
class AppCoordinator {
  AppCoordinator(
    this._health,
    this._workouts,
    this._notifications,
    this._lock,
    this._fasting,
  );

  static const _debounce = Duration(seconds: 2);

  final HealthStore _health;
  final WorkoutStore _workouts;
  final NotificationController _notifications;
  final AppLock _lock;
  final FastingStore _fasting;
  Timer? _timer;
  bool? _hidden;

  /// What the reminders were last planned around: which rings were
  /// closed, the last glass of water, and the hour (so today's ring
  /// reminder's numbers stay roughly current).
  Object? _planKey;

  void start() {
    _health.addListener(_changed);
    _workouts.addListener(_changed);
    _fasting.addListener(_changed);
    _lock.addListener(_lockChanged);
    _changed();
  }

  void dispose() {
    _health.removeListener(_changed);
    _workouts.removeListener(_changed);
    _fasting.removeListener(_changed);
    _lock.removeListener(_lockChanged);
    _timer?.cancel();
  }

  /// Widgets switch between data and the lock card when App Lock (or its
  /// widget setting) changes, not on every lock and unlock.
  ///
  /// Updated at once, not debounced: the user may leave the app right
  /// after turning the lock on, and a pending timer could then sit frozen
  /// with the data still showing on the home screen.
  void _lockChanged() {
    final hidden = _lock.hidesWidgets;
    if (hidden == _hidden) return;
    _hidden = hidden;
    unawaited(
      HomeWidgets.update(_health, _workouts, hidden: hidden, fasting: _fasting),
    );
  }

  void _changed() {
    _timer?.cancel();
    _timer = Timer(_debounce, () async {
      _hidden = _lock.hidesWidgets;
      // Reminders first, so a widget problem can never hold them up.
      final key = (
        [
          for (final t in const [
            MetricType.activeEnergy,
            MetricType.exerciseMinutes,
            MetricType.steps,
          ])
            (_health.goalProgress(t) ?? 0) >= 1,
        ].join(),
        NotificationController.lastWaterToday(_health),
        // Close to the ring reminder, keep its numbers current.
        _health.now.hour >= _notifications.settings.ringsHour - 2
            ? NotificationController.ringsLeft(_health)
            : _health.now.hour,
      );
      if (key != _planKey) {
        _planKey = key;
        await _notifications.reschedule();
      }
      await HomeWidgets.update(
        _health,
        _workouts,
        hidden: _hidden ?? false,
        fasting: _fasting,
      );
    });
  }
}
