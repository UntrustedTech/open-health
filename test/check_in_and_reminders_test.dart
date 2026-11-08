import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/insights/weight_trend.dart';
import 'package:health_app/models/body_goal.dart';
import 'package:health_app/notifications/reminder_plan.dart';

void main() {
  final today = DateTime(2026, 10, 13);

  /// Daily weigh-ins over [days] days ending today, changing [perWeek] kg
  /// a week from [start].
  List<(DateTime, double)> weighIns(double start, double perWeek, int days) => [
    for (var i = days - 1; i >= 0; i--)
      (
        DateTime(today.year, today.month, today.day - i, 7),
        start + perWeek / 7 * (days - 1 - i),
      ),
  ];

  group('weight trend', () {
    test('smoothing follows the direction but damps a one-day spike', () {
      final points = [
        for (var i = 0; i < 10; i++) (DateTime(2026, 10, 1 + i), 80.0),
      ]..[5] = (DateTime(2026, 10, 6), 83.0);
      final trend = smoothWeights(points);
      expect(trend, hasLength(10));
      expect(trend[5], lessThan(80.4)); // 3 kg spike moves it 0.3 kg
      expect(trend.last, closeTo(80.2, 0.1));
    });

    test('gaps between weigh-ins count as days', () {
      final trend = smoothWeights([
        (DateTime(2026, 10, 1), 80),
        (DateTime(2026, 10, 21), 78),
      ]);
      // 20 days at 10% a day moves most of the way.
      expect(trend.last, closeTo(78.24, 0.05));
    });

    test('the trend on a day uses only weigh-ins up to then', () {
      final points = [
        (DateTime(2026, 10, 1, 8), 80.0),
        (DateTime(2026, 10, 3, 8), 79.0),
      ];
      final t = trendOn(points, [
        DateTime(2026, 9, 30),
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 2),
        DateTime(2026, 10, 3),
      ]);
      expect(t[0], 80);
      expect(t[1], 80);
      expect(t[2], 80);
      expect(t[3], lessThan(80));
    });
  });

  group('weekly check-in', () {
    final lose = BodyGoal(
      objective: GoalObjective.lose,
      weeklyRateKg: 0.5,
      startDate: DateTime(2026, 10, 1),
    );

    CheckInResult? check(BodyGoal goal, double perWeek) =>
        WeeklyCheckIn.evaluate(
          goal: goal,
          weighIns: weighIns(80, perWeek, 21),
          today: today,
          currentKcal: 2000,
          floorKcal: 1500,
        );

    test('is due a week after the start or last check-in', () {
      expect(WeeklyCheckIn.isDue(lose, today), isTrue);
      expect(
        WeeklyCheckIn.isDue(
          lose.copyWith(checkedIn: DateTime(2026, 10, 10)),
          today,
        ),
        isFalse,
      );
      expect(
        WeeklyCheckIn.isDue(
          lose.copyWith(objective: GoalObjective.fitness),
          today,
        ),
        isFalse,
      );
    });

    test('on plan: no change suggested', () {
      final r = check(lose, -0.5)!;
      expect(r.status, CheckInStatus.onTrack);
      expect(r.suggestedKcal, isNull);
    });

    test('losing too slowly suggests eating a little less', () {
      final r = check(lose, -0.2)!;
      expect(r.status, CheckInStatus.slower);
      // 0.3 kg a week behind ≈ 330 kcal a day, capped at 250.
      expect(r.suggestedKcal, 1750);
    });

    test('losing too fast suggests eating more', () {
      final r = check(lose, -1.0)!;
      expect(r.status, CheckInStatus.faster);
      expect(r.suggestedKcal, 2250);
    });

    test('gaining while trying to lose is the wrong way', () {
      expect(check(lose, 0.3)!.status, CheckInStatus.wrongWay);
    });

    test('never suggests below the safe minimum', () {
      final r = WeeklyCheckIn.evaluate(
        goal: lose,
        weighIns: weighIns(80, 0.4, 21),
        today: today,
        currentKcal: 1600,
        floorKcal: 1500,
      )!;
      expect(r.suggestedKcal, 1500);
    });

    test('needs enough weigh-ins for a trend', () {
      expect(
        WeeklyCheckIn.evaluate(
          goal: lose,
          weighIns: weighIns(80, -0.5, 2),
          today: today,
          currentKcal: 2000,
          floorKcal: 1500,
        ),
        isNull,
      );
    });

    test('due on day 7 even when the goal started in the afternoon', () {
      final g = BodyGoal(
        objective: GoalObjective.lose,
        startDate: DateTime(2026, 10, 6, 15),
      );
      expect(WeeklyCheckIn.isDue(g, DateTime(2026, 10, 13)), isTrue);
      expect(WeeklyCheckIn.isDue(g, DateTime(2026, 10, 12)), isFalse);
    });

    test('weigh-ins from before the goal started are left out', () {
      // Gaining for three weeks, then losing since the goal began 8
      // days ago: on plan, not the wrong way.
      final before = weighIns(78, 1.0, 21).take(12).toList();
      final since = [
        for (var i = 8; i >= 0; i--)
          (
            DateTime(today.year, today.month, today.day - i, 7),
            80 - 0.5 / 7 * (8 - i),
          ),
      ];
      final r = WeeklyCheckIn.evaluate(
        goal: BodyGoal(
          objective: GoalObjective.lose,
          weeklyRateKg: 0.5,
          startDate: DateTime(today.year, today.month, today.day - 8),
        ),
        weighIns: [...before, ...since],
        today: today,
        currentKcal: 2000,
        floorKcal: 1500,
      )!;
      expect(r.status, CheckInStatus.onTrack);
    });

    test('a goal already at the minimum is never raised to cut', () {
      final r = WeeklyCheckIn.evaluate(
        goal: lose,
        weighIns: weighIns(80, 0.4, 21),
        today: today,
        currentKcal: 1300,
        floorKcal: 1500,
      )!;
      expect(r.status, isNot(CheckInStatus.onTrack));
      expect(r.suggestedKcal, isNull);
    });

    test('the check-in date is saved', () {
      final g = lose.copyWith(checkedIn: today);
      expect(BodyGoal.fromJson(g.toJson()).checkedIn, today);
    });
  });

  group('smarter reminders', () {
    final now = DateTime(2026, 10, 13, 12, 30);
    const water = NotificationSettings(
      water: true,
      waterStartHour: 9,
      waterEndHour: 21,
      waterEveryHours: 2,
    );

    test('a glass just logged skips the next water reminder today', () {
      final plan = planReminders(
        water,
        now: now,
        lastWater: DateTime(2026, 10, 13, 12, 10),
      );
      DateTime at(int hour) =>
          plan.firstWhere((r) => r.first.hour == hour).first;
      expect(at(13).day, 14); // skipped today
      expect(at(15).day, 13); // later ones still today
    });

    test('without a recent glass every later reminder stays', () {
      final plan = planReminders(
        water,
        now: now,
        lastWater: DateTime(2026, 10, 13, 9),
      );
      expect(plan.firstWhere((r) => r.first.hour == 13).first.day, 13);
    });

    test("today's rings reminder says what's left", () {
      final plan = planReminders(
        const NotificationSettings(rings: true),
        now: now,
        ringsLeft: '120 kcal and 2,000 steps',
      );
      final once = plan.singleWhere((r) => r.repeat == Repeat.once);
      expect(once.first, DateTime(2026, 10, 13, 20));
      expect(once.body, contains('120 kcal and 2,000 steps'));
      final daily = plan.singleWhere((r) => r.repeat == Repeat.daily);
      expect(daily.first.day, 14);
    });

    test('Android gets weekly repeats for a reminder that skips today', () {
      final plan = planReminders(
        water,
        now: now,
        lastWater: DateTime(2026, 10, 13, 12, 10),
      );
      final out = forScheduling(plan, now);
      final at13 = out.where((r) => r.first.hour == 13).toList();
      // A weekly repeat for every day, today's starting a week from now.
      expect(at13, hasLength(7));
      expect(at13.where((r) => r.repeat == Repeat.weekly), hasLength(7));
      expect(at13.map((r) => r.first.weekday).toSet(), hasLength(7));
      expect(
        at13.where((r) => r.first.weekday == now.weekday).single.first,
        DateTime(2026, 10, 20, 13),
      );
      expect(at13.every((r) => isReminderId(r.id)), isTrue);
      expect(at13.map((r) => r.id).toSet(), hasLength(7));
      // Reminders that don't skip today are unchanged.
      expect(out.where((r) => r.first.hour == 15).single.repeat, Repeat.daily);
    });

    test('no rings reminder today once every ring is closed', () {
      final plan = planReminders(
        const NotificationSettings(rings: true),
        now: now,
        ringsLeft: '',
      );
      expect(plan.single.repeat, Repeat.daily);
      expect(plan.single.first.day, 14);
    });
  });
}
