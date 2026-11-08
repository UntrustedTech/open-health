import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:health_app/notifications/habit_actions.dart';
import 'package:health_app/notifications/notification_controller.dart';
import 'package:health_app/notifications/notifier.dart';
import 'package:health_app/notifications/reminder_plan.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/mood_store.dart';

import 'fake_notifier.dart';

void main() {
  test('notification ids never overlap', () {
    final ranges = [reminderIds, skippedReminderIds, medicationReminderIds];
    // The rest timer, workout and message notifications (LocalNotifier).
    final singles = [
      200,
      201,
      202,
      203,
      204,
      NotificationIds.fastingDone,
      NotificationIds.windDown,
      NotificationIds.fastingLive,
    ];
    for (final (i, a) in ranges.indexed) {
      for (final b in ranges.skip(i + 1)) {
        expect(a.end <= b.start || b.end <= a.start, isTrue);
      }
      for (final id in singles) {
        expect(id < a.start || id >= a.end, isTrue, reason: '$id in $a');
      }
    }
    expect(singles.toSet(), hasLength(singles.length));
  });

  late InMemoryHealthRepository repo;
  late HealthStore health;
  late FakeNotifier notifier;
  late NotificationController controller;

  setUp(() async {
    repo = InMemoryHealthRepository();
    health = HealthStore(repo, clock: () => DateTime(2026, 10, 11, 15));
    await health.load();
    notifier = FakeNotifier();
    controller = NotificationController(repo, health, notifier);
    await controller.load();
  });

  test('turning on reminders asks permission and schedules them', () async {
    final ok = await controller.update(const NotificationSettings(rings: true));

    expect(ok, isTrue);
    expect(notifier.scheduled, isNotEmpty);
    expect(
      notifier.scheduled.every((r) => r.kind == ReminderKind.rings),
      isTrue,
    );
    expect(
      notifier.scheduled.where((r) => r.repeat == Repeat.daily),
      hasLength(1),
    );
  });

  test('refused permission leaves reminders off', () async {
    notifier.allow = false;

    final ok = await controller.update(const NotificationSettings(water: true));

    expect(ok, isFalse);
    expect(controller.settings.water, isFalse);
    expect(notifier.scheduled, isEmpty);
  });

  test('settings persist', () async {
    await controller.update(const NotificationSettings(weeklySummary: true));

    final again = NotificationController(repo, health, FakeNotifier());
    await again.load();

    expect(again.settings.weeklySummary, isTrue);
  });

  test('a glass of water pushes the next water reminder to tomorrow', () async {
    await controller.update(const NotificationSettings(water: true));
    DateTime at(int hour) =>
        notifier.scheduled.firstWhere((r) => r.first.hour == hour).first;
    expect(at(17).day, 11);

    await health.addEntry(MetricType.water, 250);
    await controller.reschedule();

    expect(at(17).day, 12);
    expect(at(19).day, 11);
  });

  test('live habits follow the ticks and a Done tap ticks one', () async {
    final mood = MoodStore(health);
    await mood.load();
    await mood.addHabit('Stretch');
    await mood.addHabit('Read');
    controller.habitsToday = () =>
        (all: mood.habits, left: habitsLeft(mood, health.today));
    mood.addListener(controller.reschedule);
    listenForHabitActions(mood, health, controller.showHabitsAgain);

    await controller.reschedule();
    expect(notifier.habits, isNull, reason: 'off until turned on');
    await controller.update(const NotificationSettings(habitsLive: true));
    expect(notifier.habits?.left, ['Stretch', 'Read']);

    // The notification's Done button, as Android delivers it.
    void tap(String habit) => habitActionInBackground(
      NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        actionId: habitActionId(habit),
        payload: '20261011',
      ),
    );
    tap('Read');
    await pumpEventQueue();
    await controller.reschedule();
    expect(mood.didHabit('Read', health.today), isTrue);
    expect(notifier.habits?.left, ['Stretch']);

    // A second tap never unticks it.
    tap('Read');
    await pumpEventQueue();
    expect(mood.didHabit('Read', health.today), isTrue);

    await mood.toggleHabit('Stretch', health.today);
    await controller.reschedule();
    expect(notifier.habits, isNull, reason: 'all done: cleared');
  });
}
