import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/notifications/reminder_plan.dart';

void main() {
  // Sunday 11 October 2026, 15:30.
  final now = DateTime(2026, 10, 11, 15, 30);

  test('nothing is planned when every reminder is off', () {
    expect(planReminders(const NotificationSettings(), now: now), isEmpty);
  });

  test('water reminders repeat daily across the chosen hours', () {
    final plan = planReminders(
      const NotificationSettings(
        water: true,
        waterStartHour: 9,
        waterEndHour: 21,
        waterEveryHours: 2,
      ),
      now: now,
    );

    expect(plan.map((r) => r.first.hour), [9, 11, 13, 15, 17, 19, 21]);
    expect(plan.every((r) => r.repeat == Repeat.daily), isTrue);
    // Already-passed times start tomorrow; later ones today.
    expect(plan.first.first.day, 12);
    expect(plan.firstWhere((r) => r.first.hour == 17).first.day, 11);
    expect(plan.map((r) => r.id).toSet(), hasLength(7));
  });

  test('ring reminder skips today when the Move goal is already met', () {
    const settings = NotificationSettings(rings: true, ringsHour: 20);

    final notMet = planReminders(settings, now: now).single;
    final met = planReminders(settings, now: now, moveGoalMet: true).single;

    expect(notMet.first, DateTime(2026, 10, 11, 20));
    expect(met.first, DateTime(2026, 10, 12, 20));
  });

  test('a daily habit reminder at the chosen hour, kept when saved', () {
    const settings = NotificationSettings(habits: true, habitsHour: 21);
    final r = planReminders(settings, now: now, habitsDone: false).single;
    expect(r.kind, ReminderKind.habits);
    expect(r.first, DateTime(2026, 10, 11, 21));
    // All ticked off: tomorrow. No habits: nothing.
    expect(
      planReminders(settings, now: now, habitsDone: true).single.first,
      DateTime(2026, 10, 12, 21),
    );
    expect(planReminders(settings, now: now), isEmpty);
    expect(isReminderId(r.id), isTrue);
    for (final s in forScheduling([r], DateTime(2026, 10, 11, 22))) {
      expect(isReminderId(s.id), isTrue);
    }
    final back = NotificationSettings.fromJson(settings.toJson());
    expect((back.habits, back.habitsHour), (true, 21));
  });

  test('workout reminders on chosen weekdays and a weekly summary', () {
    final plan = planReminders(
      const NotificationSettings(
        workout: true,
        workoutDays: {DateTime.monday, DateTime.wednesday},
        workoutHour: 18,
        weeklySummary: true,
      ),
      now: now,
    );

    final workouts = plan.where((r) => r.kind == ReminderKind.workout);
    expect(workouts.map((r) => r.first), [
      DateTime(2026, 10, 12, 18),
      DateTime(2026, 10, 14, 18),
    ]);
    expect(workouts.every((r) => r.repeat == Repeat.weekly), isTrue);
    final summary = plan.singleWhere((r) => r.kind == ReminderKind.summary);
    expect(summary.first, DateTime(2026, 10, 11, 18));
  });

  test('settings round-trip through JSON', () {
    const s = NotificationSettings(
      water: true,
      workout: true,
      workoutDays: {DateTime.friday},
    );
    final back = NotificationSettings.fromJson(s.toJson());
    expect(back.water, isTrue);
    expect(back.workoutDays, {DateTime.friday});
  });

  test('meal reminders: one a day for each meal at the chosen hours', () {
    final plan = planReminders(
      const NotificationSettings(meals: true, mealHours: (7, 13, 19)),
      now: now,
    );
    expect(plan.map((r) => r.title), [
      'Log your breakfast',
      'Log your lunch',
      'Log your dinner',
    ]);
    // 7:00 and 13:00 have passed today; dinner is still to come.
    expect(plan[0].first, DateTime(2026, 10, 12, 7));
    expect(plan[1].first, DateTime(2026, 10, 12, 13));
    expect(plan[2].first, DateTime(2026, 10, 11, 19));
    expect(plan.every((r) => r.repeat == Repeat.daily), isTrue);
    expect(plan.map((r) => r.id).toSet(), hasLength(3));
  });

  test('meal settings round-trip and bad hours fall back', () {
    const s = NotificationSettings(meals: true, mealHours: (6, 12, 20));
    final back = NotificationSettings.fromJson(s.toJson());
    expect(back.meals, isTrue);
    expect(back.mealHours, (6, 12, 20));
    final bad = NotificationSettings.fromJson({
      'meals': true,
      'mealHours': [6, 99, 'x'],
    });
    expect(bad.mealHours, NotificationSettings.defaultMealHours);
  });

  group('iOS pending limit', () {
    PlannedReminder at(int id, ReminderKind kind, int hour) => PlannedReminder(
      id: id,
      kind: kind,
      first: DateTime(2026, 10, 25, hour),
      repeat: Repeat.daily,
      title: 't',
      body: 'b',
    );

    test('water reminders are given up first, the latest first', () {
      final plan = [
        at(100, ReminderKind.water, 9),
        at(101, ReminderKind.water, 12),
        at(130, ReminderKind.rings, 18),
        at(140, ReminderKind.workout, 7),
      ];

      expect(withinBudget(plan, 4), plan);
      expect(withinBudget(plan, 3).map((r) => r.id), [100, 130, 140]);
      expect(withinBudget(plan, 2).map((r) => r.id), [130, 140]);
      expect(withinBudget(plan, 0), isEmpty);
    });

    test('water ids cover the planned and the skip-today ranges', () {
      expect(isWaterReminderId(100), isTrue);
      expect(isWaterReminderId(123), isTrue);
      expect(isWaterReminderId(130), isFalse);
      expect(isWaterReminderId(1000 + 23 * 8 + 7), isTrue);
      expect(isWaterReminderId(1000 + 30 * 8 + 1), isFalse);
    });
  });
}
