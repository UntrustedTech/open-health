import 'package:flutter/foundation.dart';

import 'package:intl/intl.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/notifications/notifier.dart';
import 'package:health_app/notifications/reminder_plan.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/utils/log.dart';

/// Holds reminder settings and keeps the scheduled notifications in line
/// with them.
class NotificationController extends ChangeNotifier {
  NotificationController(this._repo, this._health, this.notifier);

  static const _docKey = 'notificationSettings';

  final HealthRepository _repo;
  final HealthStore _health;
  final Notifier notifier;

  /// Today's habits: null when there are none, else whether all are done.
  bool? Function() habitsDone = () => null;

  /// Today's habits, and those still to do, for the live notification.
  ({List<String> all, List<String> left}) Function() habitsToday = () =>
      (all: const [], left: const []);
  NotificationSettings _settings = const NotificationSettings();

  NotificationSettings get settings => _settings;

  Future<void> load() async {
    try {
      final doc = await _repo.loadDocument(_docKey);
      if (doc != null) _settings = NotificationSettings.fromJson(doc);
    } on Exception catch (e) {
      logError('Notifications: could not load settings: $e');
    }
    notifyListeners();
  }

  /// Applies new settings. Turning on the first reminder asks for
  /// permission; returns false (and changes nothing) if it's refused.
  Future<bool> update(NotificationSettings next) async {
    if (next.anyOn && !_settings.anyOn) {
      if (!await notifier.requestPermission()) return false;
    }
    _settings = next;
    notifyListeners();
    await _health.saveDocument(_docKey, next.toJson());
    await reschedule();
    return true;
  }

  Future<void> _scheduling = Future.value();

  /// Re-plans reminders, e.g. on app start or once today's Move goal is met.
  /// Runs one at a time, each with the settings current when it starts, so
  /// an older plan can never overwrite a newer one.
  Future<void> reschedule() {
    final next = _scheduling.then((_) => _apply());
    // Even an unexpected Error must not break the chain, or no later
    // plan would ever run; the caller still sees it.
    _scheduling = next.catchError((Object e, StackTrace st) {
      logError('Notifications: scheduling crashed: $e\n$st');
    });
    return next;
  }

  /// The plan last handed to the notifier, so an unchanged plan isn't
  /// rewritten (which would also clear reminders still in the tray).
  String? _lastPlan;

  /// What the habits notification last showed, so it's only re-sent when
  /// that changes.
  String? _lastHabits;

  /// Re-sends the habits notification even if nothing changed, e.g. after
  /// it was swiped away.
  Future<void> showHabitsAgain() {
    _lastHabits = null;
    return reschedule();
  }

  Future<void> _apply() async {
    await _applyHabits();
    try {
      final plan = planReminders(
        _settings,
        now: _health.now,
        ringsLeft: ringsLeft(_health),
        lastWater: lastWaterToday(_health),
        habitsDone: habitsDone(),
      );
      final key = [
        // Text is translated as it's sent: a new language needs a resend.
        '${Intl.defaultLocale}',
        // So does a new time zone, as the times are in local time.
        '${DateTime.now().timeZoneName} ${DateTime.now().timeZoneOffset}',
        for (final r in plan)
          '${r.id}|${r.first.toIso8601String()}|${r.repeat.name}|${r.body}',
      ].join('\n');
      if (key == _lastPlan) return;
      await notifier.replaceReminders(plan);
      _lastPlan = key;
    } on Exception catch (e) {
      logError('Notifications: scheduling failed: $e');
    }
  }

  Future<void> _applyHabits() async {
    final h = _settings.habitsLive
        ? habitsToday()
        : (all: const <String>[], left: const <String>[]);
    final key = [
      '${Intl.defaultLocale}',
      _health.today.toIso8601String(),
      ...h.all,
      '|',
      ...h.left,
    ].join('\n');
    if (key == _lastHabits) return;
    try {
      await notifier.showHabits(_health.today, h.all, h.left);
      _lastHabits = key;
    } on Exception catch (e) {
      logError('Notifications: habits notification failed: $e');
    }
  }

  /// What's left to close today's rings, e.g. "120 kcal and 2,000
  /// steps"; empty when every ring with a goal is closed.
  static String ringsLeft(HealthStore health) {
    final parts = [
      for (final type in const [
        MetricType.activeEnergy,
        MetricType.exerciseMinutes,
        MetricType.steps,
      ])
        if (health.goals.forMetric(type) case final goal? when goal > 0)
          if (health.todayValue(type) < goal)
            if (formatValue(type, goal - health.todayValue(type))
                case final left when left != '0')
              '$left ${unitLabel(type)}'.trim(),
    ];
    return switch (parts.length) {
      0 => '',
      1 => parts.single,
      _ => '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}',
    };
  }

  /// When water was last logged today, if it was.
  static DateTime? lastWaterToday(HealthStore health) {
    final today = health.today;
    DateTime? last;
    for (final e in health.entriesFor(MetricType.water)) {
      if (e.date.isBefore(today)) continue;
      if (last == null || e.date.isAfter(last)) last = e.date;
    }
    return last;
  }

  /// Clears memory after "Erase All".
  Future<void> reset() async {
    _settings = const NotificationSettings();
    notifyListeners();
    await reschedule();
  }
}
