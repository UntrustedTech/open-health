import 'dart:async';

import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleListener, AppLifecycleState;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:health_app/l10n/language.dart';
import 'package:health_app/models/cycle.dart' show dayKey;
import 'package:health_app/notifications/habit_actions.dart';
import 'package:health_app/notifications/reminder_plan.dart';
import 'package:health_app/utils/log.dart';

/// Shows and schedules the app's notifications.
abstract interface class Notifier {
  Future<void> init();

  /// Asks for permission to post notifications (Android 13+).
  Future<bool> requestPermission();

  /// Cancels all reminders and schedules [plan] instead.
  Future<void> replaceReminders(List<PlannedReminder> plan);

  /// Cancels all medication reminders and schedules [plan] instead.
  Future<void> replaceMedicationReminders(List<PlannedReminder> plan);

  /// Live countdown for a rest period between sets.
  Future<void> showRestTimer(Duration rest);
  Future<void> cancelRestTimer();

  /// Ongoing "workout in progress" notification with a running timer
  /// (frozen while [paused]).
  Future<void> showWorkoutOngoing(
    String title,
    DateTime startedAt, {
    bool paused = false,
  });
  Future<void> cancelWorkoutOngoing();

  /// Today's habits still [left] out of [all], with a Done button for
  /// the first few; cleared when nothing is left (Android only).
  Future<void> showHabits(DateTime day, List<String> all, List<String> left);

  /// Ongoing countdown to the end of a fast at [end] (Android only); clear
  /// it with [cancel] and [NotificationIds.fastingLive].
  Future<void> showFasting(DateTime end);

  /// A one-off message, e.g. an interval phase change.
  Future<void> showMessage(String title, String body);

  /// Schedules (or replaces) notification [id] to fire once at [at].
  Future<void> scheduleOnce(int id, DateTime at, String title, String body);

  /// Schedules (or replaces) notification [id] every day at [hour]:[minute].
  Future<void> scheduleDaily(
    int id,
    ({int hour, int minute}) time,
    String title,
    String body,
  );

  /// Cancels notification [id].
  Future<void> cancel(int id);

  /// Shows [picture] (a PNG of the chosen app icon) and tints the small
  /// icon [color] on notifications from now on; null for the defaults.
  void useIcon(Color? color, String? picture);
}

/// Notification ids for single reminders outside the reminder plans.
abstract final class NotificationIds {
  /// "Your fast is complete."
  static const fastingDone = 600;

  /// Bedtime wind-down.
  static const windDown = 601;

  /// The fast in progress.
  static const fastingLive = 602;
}

class LocalNotifier implements Notifier {
  LocalNotifier([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _restId = 200;
  static const _ongoingId = 201;
  static const _messageId = 202;
  static const _habitsId = 203;
  static const _updateId = 204;

  /// Android shows at most three buttons on a notification.
  static const _maxActions = 3;
  static const _icon = 'ic_stat_health';

  Color? _color;
  AndroidBitmap<Object>? _picture;

  @override
  void useIcon(Color? color, String? picture) {
    _color = color;
    _picture = picture == null ? null : FilePathAndroidBitmap(picture);
  }

  AndroidNotificationDetails get _reminders => AndroidNotificationDetails(
    'reminders',
    'Reminders',
    channelDescription: 'Water, activity and workout reminders',
    icon: _icon,
    color: _color,
    largeIcon: _picture,
    visibility: NotificationVisibility.private,
  );

  AndroidNotificationDetails get _medications => AndroidNotificationDetails(
    'medications',
    'Medications',
    channelDescription: 'Reminders to take your medications',
    icon: _icon,
    color: _color,
    largeIcon: _picture,
    importance: Importance.high,
    priority: Priority.high,
    visibility: NotificationVisibility.private,
  );

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _useLocalZone();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_icon),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveBackgroundNotificationResponse: habitActionInBackground,
    );
    _ready = true;
  }

  /// Times reminders in the phone's current time zone.
  Future<void> _useLocalZone() async {
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } on Exception catch (e) {
      // A zone the bundled database lacks: one with the same offset now
      // keeps reminders at the right time, at least until a DST change.
      final offset = DateTime.now().timeZoneOffset;
      final same = tz.timeZoneDatabase.locations.values
          .where((l) => l.currentTimeZone.offset == offset)
          .firstOrNull;
      if (same != null) tz.setLocalLocation(same);
      logError('Notifier: unknown time zone, using ${same?.name ?? 'UTC'}: $e');
    }
  }

  @override
  Future<bool> requestPermission() async {
    await init();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true) ??
          false;
    }
    final android = _android;
    if (android == null) return false;
    if (await android.areNotificationsEnabled() ?? false) return true;
    // The plugin's answer can go missing (another plugin may take the
    // permission result), which would leave the caller waiting forever.
    // So once the app is back in front after the dialog, an allowed
    // permission is reported at once; a refusal waits briefly for the
    // plugin's own answer. A long timeout is the last resort.
    final back = Completer<void>();
    var left = false;
    final listener = AppLifecycleListener(
      onStateChange: (state) {
        if (state != AppLifecycleState.resumed) {
          left = true;
        } else if (left && !back.isCompleted) {
          back.complete();
        }
      },
    );
    try {
      final answered = android.requestNotificationsPermission().then(
        (v) => v ?? false,
      );
      final viaResume = back.future.then((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (await android.areNotificationsEnabled() ?? false) return true;
        return answered.timeout(_refusalGrace, onTimeout: () => false);
      });
      return await Future.any([answered, viaResume]).timeout(
        _permissionTimeout,
        onTimeout: () async => await android.areNotificationsEnabled() ?? false,
      );
    } finally {
      listener.dispose();
    }
  }

  /// How long a refusal waits for the plugin's own answer.
  static const _refusalGrace = Duration(seconds: 3);

  /// The longest the permission request can take.
  static const _permissionTimeout = Duration(minutes: 2);

  @override
  Future<void> replaceReminders(List<PlannedReminder> plan) async {
    await init();
    // The phone may have moved to another time zone since launch.
    await _useLocalZone();
    for (var id = reminderIds.start; id < reminderIds.end; id++) {
      await _plugin.cancel(id: id);
    }
    // Skip-today reminders use a wider range; cancel only those pending.
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (isReminderId(p.id) && p.id >= skippedReminderIds.start) {
        await _plugin.cancel(id: p.id);
      }
    }
    var scheduled = forScheduling(plan, DateTime.now());
    if (_isIOS) {
      // Medication reminders come first; these share what's left.
      final meds = (await _plugin.pendingNotificationRequests())
          .where((p) => _isMedicationId(p.id))
          .length;
      final kept = withinBudget(
        scheduled,
        iosPendingLimit - iosReserved - meds,
      );
      if (kept.length < scheduled.length) {
        logError(
          'Notifications: iOS limit, '
          '${scheduled.length - kept.length} reminders left out',
        );
      }
      scheduled = kept;
    }
    for (final r in scheduled) {
      await _schedule(r, _reminders);
    }
  }

  static bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  static bool _isMedicationId(int id) =>
      id >= medicationReminderIds.start && id < medicationReminderIds.end;

  /// On iOS, cancels other reminders (water first, then the rest) until
  /// [needed] more fit under the limit, so none of them is dropped by iOS.
  Future<void> _makeRoomOnIOS(int needed) async {
    if (!_isIOS) return;
    final pending = await _plugin.pendingNotificationRequests();
    final over = pending.length + needed - (iosPendingLimit - iosReserved);
    if (over <= 0) return;
    final ids =
        [
          for (final p in pending)
            if (isReminderId(p.id)) p.id,
        ]..sort((a, b) {
          final water = (isWaterReminderId(b) ? 1 : 0).compareTo(
            isWaterReminderId(a) ? 1 : 0,
          );
          return water != 0 ? water : b.compareTo(a);
        });
    for (final id in ids.take(over)) {
      await _plugin.cancel(id: id);
    }
    logError(
      'Notifications: iOS limit, cancelled ${ids.take(over).length} '
      'reminders for medications',
    );
  }

  Future<void> _schedule(
    PlannedReminder r,
    AndroidNotificationDetails details,
  ) => _plugin.zonedSchedule(
    id: r.id,
    title: tr(r.title),
    body: tr(r.body),
    scheduledDate: tz.TZDateTime.from(r.first, tz.local),
    notificationDetails: NotificationDetails(android: details),
    // Reminders don't need to be to-the-second, so no exact alarms.
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    matchDateTimeComponents: switch (r.repeat) {
      Repeat.daily => DateTimeComponents.time,
      Repeat.weekly => DateTimeComponents.dayOfWeekAndTime,
      Repeat.once => null,
    },
  );

  @override
  Future<void> replaceMedicationReminders(List<PlannedReminder> plan) async {
    await init();
    await _useLocalZone();
    for (
      var id = medicationReminderIds.start;
      id < medicationReminderIds.end;
      id++
    ) {
      await _plugin.cancel(id: id);
    }
    final doses = _isIOS
        ? withinBudget(plan, iosPendingLimit - iosReserved)
        : plan;
    await _makeRoomOnIOS(doses.length);
    for (final r in doses) {
      await _schedule(r, _medications);
    }
  }

  @override
  Future<void> showRestTimer(Duration rest) async {
    await init();
    final end = DateTime.now().add(rest);
    if (_isIOS) return _scheduleRestOver(end);
    await _plugin.show(
      id: _restId,
      title: tr('Rest'),
      body: tr('Next set when the timer ends'),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'timers',
          'Workout timers',
          channelDescription: 'Rest timers and interval cues',
          icon: _icon,
          color: _color,
          largeIcon: _picture,
          importance: Importance.high,
          priority: Priority.high,
          onlyAlertOnce: true,
          // Live Updates must be ongoing; it still goes when the rest ends.
          ongoing: true,
          usesChronometer: true,
          chronometerCountDown: true,
          when: end.millisecondsSinceEpoch,
          timeoutAfter: rest.inMilliseconds,
          category: AndroidNotificationCategory.stopwatch,
          requestPromotedOngoing: true,
          // Hidden on a lock screen set to hide sensitive content.
          visibility: NotificationVisibility.private,
        ),
      ),
    );
  }

  /// iOS has no live countdown and pauses the app soon after the phone
  /// locks, so the "Rest over" alert is scheduled up front instead.
  Future<void> _scheduleRestOver(DateTime end) async {
    await _useLocalZone();
    await _plugin.zonedSchedule(
      id: _restId,
      title: tr('Rest over'),
      body: tr('Time for your next set.'),
      scheduledDate: tz.TZDateTime.from(end, tz.local),
      // Silent while the app is open: the workout screen shows its own note.
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: false,
          presentBanner: false,
          presentList: false,
          presentSound: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancelRestTimer() => _plugin.cancel(id: _restId);

  @override
  Future<void> showWorkoutOngoing(
    String title,
    DateTime startedAt, {
    bool paused = false,
  }) async {
    await init();
    await _plugin.show(
      id: _ongoingId,
      title: tr(title),
      body: tr(paused ? 'Paused' : 'Workout in progress'),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'workout',
          'Workout in progress',
          channelDescription: 'Shown while a workout is being recorded',
          icon: _icon,
          color: _color,
          largeIcon: _picture,
          importance: Importance.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          usesChronometer: !paused,
          showWhen: !paused,
          when: startedAt.millisecondsSinceEpoch,
          category: AndroidNotificationCategory.workout,
          // A Live Update on Android 16+ (status bar chip, Now Bar).
          requestPromotedOngoing: true,
          // Hidden on a lock screen set to hide sensitive content.
          visibility: NotificationVisibility.private,
        ),
      ),
    );
  }

  @override
  Future<void> showFasting(DateTime end) async {
    await init();
    if (_isIOS) return;
    final left = end.difference(DateTime.now());
    if (left <= Duration.zero) return;
    await _plugin.show(
      id: NotificationIds.fastingLive,
      title: tr('Fasting'),
      body: tr('Ends at ${DateFormat.jm().format(end)}'),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'fasting',
          'Fast in progress',
          channelDescription: 'Shown while you fast, counting down to the end',
          icon: _icon,
          color: _color,
          largeIcon: _picture,
          importance: Importance.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          usesChronometer: true,
          chronometerCountDown: true,
          when: end.millisecondsSinceEpoch,
          // "Fast Complete" takes over at the end.
          timeoutAfter: left.inMilliseconds,
          category: AndroidNotificationCategory.stopwatch,
          requestPromotedOngoing: true,
          // Hidden on a lock screen set to hide sensitive content.
          visibility: NotificationVisibility.private,
        ),
      ),
    );
  }

  @override
  Future<void> cancelWorkoutOngoing() => _plugin.cancel(id: _ongoingId);

  @override
  Future<void> showHabits(
    DateTime day,
    List<String> all,
    List<String> left,
  ) async {
    await init();
    if (_isIOS || all.isEmpty || left.isEmpty) {
      return _plugin.cancel(id: _habitsId);
    }
    final done = all.length - left.length;
    final midnight = DateTime(day.year, day.month, day.day + 1);
    await _plugin.show(
      id: _habitsId,
      title: tr('$done of ${all.length} habits done'),
      body: tr('Still to do: ${left.join(', ')}'),
      payload: dayKey(day),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'habits_live',
          'Today\'s habits',
          channelDescription: 'Habits left today, with a button to tick each',
          icon: _icon,
          color: _color,
          largeIcon: _picture,
          importance: Importance.low,
          autoCancel: false,
          onlyAlertOnce: true,
          showProgress: true,
          maxProgress: all.length,
          progress: done,
          // Yesterday's list is no use: gone at midnight.
          timeoutAfter: midnight.difference(DateTime.now()).inMilliseconds,
          visibility: NotificationVisibility.private,
          actions: [
            for (final h in left.take(_maxActions))
              AndroidNotificationAction(
                habitActionId(h),
                '✓ $h',
                // Kept up, and updated, rather than removed on a tap.
                cancelNotification: false,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Future<void> scheduleOnce(
    int id,
    DateTime at,
    String title,
    String body,
  ) async {
    await init();
    await _plugin.zonedSchedule(
      id: id,
      title: tr(title),
      body: tr(body),
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: NotificationDetails(android: _reminders),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> scheduleDaily(
    int id,
    ({int hour, int minute}) time,
    String title,
    String body,
  ) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!at.isAfter(now)) {
      // Tomorrow by the calendar, not 24 hours on, which is off by an hour
      // across a DST change.
      at = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + 1,
        time.hour,
        time.minute,
      );
    }
    await _plugin.zonedSchedule(
      id: id,
      title: tr(title),
      body: tr(body),
      scheduledDate: at,
      notificationDetails: NotificationDetails(android: _reminders),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await init();
    await _plugin.cancel(id: id);
  }

  /// A newer build is out (from the daily background check).
  Future<void> showUpdate() async {
    await init();
    await _plugin.show(
      id: _updateId,
      title: tr('Update Available'),
      body: tr('A new version of Health is out. Open the app to get it.'),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'updates',
          'App updates',
          channelDescription: 'When a new version of Health is out',
          icon: _icon,
          color: _color,
          largeIcon: _picture,
        ),
      ),
    );
  }

  @override
  Future<void> showMessage(String title, String body) async {
    await init();
    await _plugin.show(
      id: _messageId,
      title: tr(title),
      body: tr(body),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'timers',
          'Workout timers',
          channelDescription: 'Rest timers and interval cues',
          icon: _icon,
          color: _color,
          largeIcon: _picture,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
