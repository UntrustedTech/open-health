import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/insights/health_overview.dart';
import 'package:health_app/models/body_goal.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/user_profile.dart';

final _today = DateTime(2026, 10, 16);

/// Daily values from a map of (type, days ago) → value.
double? Function(MetricType, DateTime) _data(
  Map<(MetricType, int), double> values,
) =>
    (type, day) => values[(type, _today.difference(day).inDays)];

HealthOverview _build(
  SummaryPeriod period,
  Map<(MetricType, int), double> values, {
  GoalObjective objective = GoalObjective.maintain,
  ({double eaten, double budget})? Function(DateTime)? food,
  DateTime? now,
}) => HealthOverview.build(
  now: now,
  period: period,
  today: _today,
  dailyValue: _data(values),
  goals: const Goals(),
  bodyGoal: BodyGoal(objective: objective),
  food: food ?? (_) => null,
);

void main() {
  test('no data gives no score and an encouraging message', () {
    final o = _build(SummaryPeriod.week, {});
    expect(o.isEmpty, isTrue);
    expect(o.score, isNull);
    expect(o.rating, 'No Data Yet');
    expect(o.verdict, contains('Not enough data yet'));
  });

  test('meeting every activity goal today scores activity 100', () {
    final o = _build(SummaryPeriod.today, {
      (MetricType.steps, 0): 9000,
      (MetricType.activeEnergy, 0): 600,
      (MetricType.exerciseMinutes, 0): 45,
    });
    expect(o[Pillar.activity]?.score, 100);
    expect(o[Pillar.activity]?.value, 9000);
    expect(o.score, 100);
    expect(o.rating, 'Excellent');
  });

  test('activity counts from the first active day, not empty months', () {
    final o = _build(SummaryPeriod.year, {
      for (var d = 0; d < 7; d++) ...{
        (MetricType.steps, d): 8000,
        (MetricType.activeEnergy, d): 500,
        (MetricType.exerciseMinutes, d): 30,
      },
    });
    expect(o[Pillar.activity]?.score, 100);
    expect(o[Pillar.activity]?.days, 6); // finished days only
  });

  test('sleep scores against the sleep goal', () {
    final short = _build(SummaryPeriod.week, {
      for (var d = 0; d < 7; d++) (MetricType.sleep, d): 6,
    });
    final enough = _build(SummaryPeriod.week, {
      for (var d = 0; d < 7; d++) (MetricType.sleep, d): 8,
    });
    expect(short[Pillar.sleep]?.score, 75);
    expect(enough[Pillar.sleep]?.score, 100);
  });

  test('a resting heart rate below baseline scores higher', () {
    Map<(MetricType, int), double> heart(double recent) => {
      for (var d = 0; d < 7; d++) (MetricType.restingHeartRate, d): recent,
      for (var d = 7; d < 21; d++) (MetricType.restingHeartRate, d): 65,
    };
    final calmer = _build(SummaryPeriod.week, heart(60))[Pillar.heart]!;
    final higher = _build(SummaryPeriod.week, heart(72))[Pillar.heart]!;
    expect(calmer.score, greaterThan(higher.score));
  });

  test('losing weight on pace is on track; gaining is the wrong way', () {
    Map<(MetricType, int), double> weights(double perWeek) => {
      (MetricType.weight, 13): 80,
      (MetricType.weight, 0): 80 + perWeek * 2,
    };
    final onPace = _build(
      SummaryPeriod.week,
      weights(-0.5),
      objective: GoalObjective.lose,
    );
    final wrongWay = _build(
      SummaryPeriod.week,
      weights(0.5),
      objective: GoalObjective.lose,
    );
    expect(onPace[Pillar.body]?.score, 100);
    expect(onPace.verdict, startsWith('You\'re on track to lose weight'));
    expect(wrongWay[Pillar.body]!.score, lessThan(50));
    expect(wrongWay.verdict, contains('wrong way'));
  });

  test('nutrition rewards eating close to budget, and today under it', () {
    ({double eaten, double budget})? food(DateTime d) =>
        (eaten: d == _today ? 900 : 2000, budget: 2000);
    final week = _build(SummaryPeriod.week, {}, food: food);
    final today = _build(
      SummaryPeriod.today,
      {},
      food: food,
      now: DateTime(2026, 10, 16, 13),
    );
    // Longer periods count only finished days.
    expect(week[Pillar.nutrition]?.days, 6);
    expect(week[Pillar.nutrition]?.score, 100);
    expect(today[Pillar.nutrition]?.score, 100);

    ({double eaten, double budget})? over(DateTime d) =>
        (eaten: 3000, budget: 2000);
    expect(
      _build(SummaryPeriod.week, {}, food: over)[Pillar.nutrition]!.score,
      lessThan(30),
    );
  });

  test('the goal decides what counts most', () {
    final fitness = HealthOverview.weightsFor(GoalObjective.fitness);
    final lose = HealthOverview.weightsFor(GoalObjective.lose);
    expect(fitness[Pillar.activity], greaterThan(lose[Pillar.activity]!));
    expect(lose[Pillar.body], greaterThan(fitness[Pillar.body]!));
    for (final o in GoalObjective.values) {
      final sum = HealthOverview.weightsFor(o).values.reduce((a, b) => a + b);
      expect(sum, closeTo(1, 1e-9));
    }
  });

  test('a weak area adds a tip to the verdict', () {
    final o = _build(SummaryPeriod.week, {
      for (var d = 0; d < 7; d++) ...{
        (MetricType.steps, d): 9000,
        (MetricType.activeEnergy, d): 600,
        (MetricType.exerciseMinutes, d): 40,
        (MetricType.sleep, d): 4,
      },
    });
    expect(o.verdict, contains('More sleep would lift your score most.'));
  });

  test('changes compare with the period before, biggest first', () {
    final o = _build(SummaryPeriod.week, {
      // Finished days: the week ending yesterday against the one before.
      for (var d = 1; d <= 7; d++) ...{
        (MetricType.steps, d): 10000,
        (MetricType.sleep, d): 7,
      },
      for (var d = 8; d <= 14; d++) ...{
        (MetricType.steps, d): 5000,
        (MetricType.sleep, d): 7.1,
      },
    });
    expect(o.changes, hasLength(1)); // sleep barely moved
    expect(o.changes.first.type, MetricType.steps);
    expect(o.changes.first.fraction, closeTo(1, 1e-9));
    expect(o.changes.first.isGood, isTrue);
  });

  test('a lower resting heart rate is good news', () {
    const c = Change(
      type: MetricType.restingHeartRate,
      current: 58,
      previous: 64,
    );
    expect(c.isGood, isTrue);
  });

  test('a morning is judged against the part of the day gone by', () {
    final morning = DateTime(2026, 10, 16, 10);
    expect(HealthOverview.dayShare(morning), closeTo(0.2, 1e-9));
    final o = _build(SummaryPeriod.today, {
      (MetricType.steps, 0): 2000,
      (MetricType.activeEnergy, 0): 120,
      (MetricType.exerciseMinutes, 0): 7,
    }, now: morning);
    expect(o[Pillar.activity]!.score, greaterThan(90));
    // The same numbers at night are a quiet day.
    final night = _build(SummaryPeriod.today, {
      (MetricType.steps, 0): 2000,
      (MetricType.activeEnergy, 0): 120,
      (MetricType.exerciseMinutes, 0): 7,
    }, now: DateTime(2026, 10, 16, 23));
    expect(night[Pillar.activity]!.score, lessThan(30));
  });

  test('a week leaves out today so far', () {
    final o = _build(SummaryPeriod.week, {
      for (var d = 1; d < 7; d++) ...{
        (MetricType.steps, d): 8000,
        (MetricType.activeEnergy, d): 500,
        (MetricType.exerciseMinutes, d): 30,
      },
      (MetricType.steps, 0): 300,
    });
    expect(o[Pillar.activity]?.score, 100);
    expect(o[Pillar.activity]?.days, 6);
  });

  test('little eaten late in the day is not on track', () {
    ({double eaten, double budget})? food(DateTime d) =>
        (eaten: 400, budget: 2000);
    final noon = _build(
      SummaryPeriod.today,
      {},
      food: food,
      now: DateTime(2026, 10, 16, 12),
    );
    final late = _build(
      SummaryPeriod.today,
      {},
      food: food,
      now: DateTime(2026, 10, 16, 23),
    );
    expect(noon[Pillar.nutrition]?.score, 100);
    expect(late[Pillar.nutrition]!.score, lessThan(50));
  });

  test('a few days of water weight is not a trend', () {
    final o = _build(SummaryPeriod.week, {
      (MetricType.weight, 3): 80,
      (MetricType.weight, 0): 80.6,
    }, objective: GoalObjective.lose);
    expect(o[Pillar.body], isNull);
    final steady = _build(SummaryPeriod.week, {
      (MetricType.weight, 13): 80,
      (MetricType.weight, 0): 80.1,
    }, objective: GoalObjective.lose);
    expect(steady[Pillar.body]!.score, greaterThanOrEqualTo(60));
    expect(steady.verdict, isNot(contains('wrong way')));
  });

  test('changes need a few days on each side', () {
    final o = _build(SummaryPeriod.month, {
      for (var d = 1; d <= 30; d++) (MetricType.steps, d): 9000,
      (MetricType.steps, 40): 2000, // one stray day the month before
    });
    expect(o.changes, isEmpty);
  });

  test('today only compares things finished by morning', () {
    final o = _build(SummaryPeriod.today, {
      (MetricType.steps, 0): 500,
      (MetricType.sleep, 0): 9,
      for (var d = 1; d <= 7; d++) ...{
        (MetricType.steps, d): 9000,
        (MetricType.sleep, d): 7,
      },
    });
    expect(o.changes.map((c) => c.type), [MetricType.sleep]);
  });

  test('no activity goals means no activity score', () {
    final o = HealthOverview.build(
      period: SummaryPeriod.today,
      today: _today,
      dailyValue: _data({(MetricType.steps, 0): 5000}),
      goals: const Goals(steps: 0, activeEnergy: 0, exerciseMinutes: 0),
      bodyGoal: const BodyGoal(),
      food: (_) => null,
    );
    expect(o[Pillar.activity], isNull);
  });
}
