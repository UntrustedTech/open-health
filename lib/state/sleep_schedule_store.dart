import 'package:flutter/foundation.dart';

import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/sleep_schedule.dart';
import 'package:health_app/notifications/notifier.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/utils/log.dart';

/// The sleep schedule and its wind-down reminder. Turning it on also sets
/// the sleep goal to the time in bed, so the rest of the app agrees.
class SleepScheduleStore extends ChangeNotifier {
  SleepScheduleStore(this._health, this._notifier);

  static const docKey = 'sleepSchedule';

  final HealthStore _health;
  final Notifier _notifier;

  SleepSchedule _schedule = const SleepSchedule();
  bool _readable = true;

  SleepSchedule get schedule => _schedule;

  /// Hours slept [daysAgo] nights ago (0 is last night), or null.
  double? sleptNightsAgo(int daysAgo) {
    final t = _health.today;
    return _health.dailyValue(
      MetricType.sleep,
      DateTime(t.year, t.month, t.day - daysAgo),
    );
  }

  /// Whether [hours] counts as on target for the schedule.
  bool onTarget(double hours) =>
      hours >= _schedule.goalHours - onTargetMargin.inMinutes / 60;

  /// Recent nights against the schedule's goal.
  SleepConsistency consistency({int days = 7}) => sleepConsistency(
    sleepOn: (d) => _health.dailyValue(MetricType.sleep, d),
    today: _health.today,
    goalHours: _schedule.goalHours,
    days: days,
  );

  Future<void> load() async {
    _schedule = const SleepSchedule();
    _readable = true;
    try {
      _schedule = SleepSchedule.fromJson(await _health.loadDocument(docKey));
    } on Exception catch (e) {
      _readable = false;
      logError('Sleep schedule: could not load: $e');
    }
    notifyListeners();
  }

  Future<void> update(SleepSchedule next) async {
    final goalChanged =
        next.enabled &&
        (next.goalHours != _schedule.goalHours || !_schedule.enabled);
    _schedule = next;
    notifyListeners();
    if (goalChanged) {
      await _health.updateGoal(MetricType.sleep, next.goalHours);
    }
    await reschedule();
    await _save();
  }

  /// Schedules (or cancels) the wind-down reminder.
  Future<void> reschedule() async {
    try {
      if (!_schedule.enabled || !_schedule.remind) {
        await _notifier.cancel(NotificationIds.windDown);
        return;
      }
      final bed = _schedule.bedtime;
      await _notifier.scheduleDaily(
        NotificationIds.windDown,
        _schedule.windDownAt,
        'Time to Wind Down',
        'Bedtime is at ${formatTimeOfDay(bed.hour, bed.minute)}. '
            'Put the screens away and get ready for sleep.',
      );
    } on Exception catch (e) {
      logError('Sleep schedule: could not schedule: $e');
    }
  }

  /// Clears memory after "Erase All".
  Future<void> reset() async {
    _schedule = const SleepSchedule();
    _readable = true;
    notifyListeners();
    await _notifier.cancel(NotificationIds.windDown);
  }

  Future<void> _save() async {
    if (!_readable) {
      logError('Sleep schedule: not saving over data that could not be read');
      return;
    }
    await _health.saveDocument(docKey, _schedule.toJson());
  }
}
