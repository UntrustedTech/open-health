import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/models/cycle.dart' show dayKey, parseDayKey;
import 'package:health_app/notifications/notifier.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/mood_store.dart';
import 'package:health_app/sync/background_sync.dart';
import 'package:health_app/utils/log.dart';

/// Where the running app listens for Done taps on the habits notification.
const _portName = 'health/habit-actions';
const _prefix = 'habit_';

/// How long a Done tap waits for the app to say it ticked the habit
/// before ticking it itself (the app may have just been closed).
const _ackWait = Duration(seconds: 3);

String habitActionId(String habit) => '$_prefix$habit';

String? _habitOf(String? actionId) =>
    actionId != null && actionId.startsWith(_prefix)
    ? actionId.substring(_prefix.length)
    : null;

/// The habits still to do on [day], in the order they're listed.
List<String> habitsLeft(MoodStore mood, DateTime day) => [
  for (final h in mood.habits)
    if (!mood.didHabit(h, day)) h,
];

/// A Done tap on the habits notification. Android runs this in a
/// background engine whether or not the app is open.
@pragma('vm:entry-point')
void habitActionInBackground(NotificationResponse response) {
  final habit = _habitOf(response.actionId);
  final day = parseDayKey(response.payload ?? '');
  if (habit == null || day == null) return;
  unawaited(_tick(habit, day));
}

Future<void> _tick(String habit, DateTime day) async {
  try {
    // Only one copy of the habits may save, or one would undo the other's
    // ticks: the app's, while it's running.
    if (IsolateNameServer.lookupPortByName(_portName) case final app?) {
      final reply = ReceivePort();
      app.send([habit, dayKey(day), reply.sendPort]);
      final ok = await reply.first.timeout(_ackWait, onTimeout: () => false);
      reply.close();
      if (ok == true) return;
    }
    await _tickWhileClosed(habit, day);
  } on Object catch (e) {
    logError('Habit action failed: $e');
  }
}

/// The app isn't running: load the habits, tick, save, and update the
/// notification. The app reloads them when it next comes back.
Future<void> _tickWhileClosed(String habit, DateTime day) async {
  final prefs = SharedPreferencesAsync();
  final cipher = await loadStorageCipher(prefs);
  if (cipher == null) return;
  final health = HealthStore(
    SharedPrefsHealthRepository(prefs, cipher: cipher),
  );
  await health.load();
  final mood = MoodStore(health);
  await mood.load();
  await _apply(mood, health, habit, day);
  await AppPresence.markBackgroundSaved(prefs);
  await LocalNotifier().showHabits(
    health.today,
    mood.habits,
    habitsLeft(mood, health.today),
  );
}

/// Ticks [habit] off for [day] if that's still today and it isn't already
/// (a second tap must never untick it).
Future<void> _apply(
  MoodStore mood,
  HealthStore health,
  String habit,
  DateTime day,
) async {
  if (day != health.today || !mood.habits.contains(habit)) return;
  if (!mood.didHabit(habit, day)) await mood.toggleHabit(habit, day);
}

/// Lets the running app take Done taps, so it saves them itself.
/// [refresh] re-shows the notification when a tap changed nothing (a list
/// left over from yesterday, say).
void listenForHabitActions(
  MoodStore mood,
  HealthStore health,
  Future<void> Function() refresh,
) {
  final port = ReceivePort();
  // A name left by an earlier run of the app in this process.
  IsolateNameServer.removePortNameMapping(_portName);
  IsolateNameServer.registerPortWithName(port.sendPort, _portName);
  port.listen((message) async {
    if (message case [
      final String habit,
      final String key,
      final SendPort reply,
    ]) {
      try {
        if (parseDayKey(key) case final day?) {
          final before = mood.didHabit(habit, day);
          await _apply(mood, health, habit, day);
          if (before == mood.didHabit(habit, day)) await refresh();
        }
      } finally {
        reply.send(true);
      }
    }
  });
}
