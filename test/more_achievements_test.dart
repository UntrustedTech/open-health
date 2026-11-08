import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/insights/achievements.dart';
import 'package:health_app/models/food.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/user_profile.dart';
import 'package:health_app/models/workout.dart';

final _today = DateTime(2026, 10, 14); // A Wednesday.

WorkoutSession _session(
  String id,
  WorkoutType type,
  DateTime start, {
  int minutes = 40,
  List<ExerciseLog> exercises = const [],
}) => WorkoutSession(
  id: id,
  type: type,
  start: start,
  end: start.add(Duration(minutes: minutes)),
  activeSeconds: minutes * 60,
  exercises: exercises,
);

List<Achievement> _evaluate({
  double? Function(MetricType type, DateTime day)? daily,
  List<WorkoutSession> workouts = const [],
  List<DateTime> gymVisits = const [],
  Set<DateTime> moodDays = const {},
  int fastsReached = 0,
  List<FoodEntry> food = const [],
}) => evaluateAchievements(
  AchievementInputs(
    dailyValue: daily ?? (_, _) => null,
    today: _today,
    goals: const Goals(),
    workouts: workouts,
    daysLogged: 0,
    gymVisits: gymVisits,
    moodDays: moodDays,
    fastsReached: fastsReached,
    food: food,
  ),
);

Achievement _a(List<Achievement> all, String id) =>
    all.firstWhere((a) => a.id == id, orElse: () => fail('No "$id" badge'));

void main() {
  test('there are more achievements, each with a unique id', () {
    final all = _evaluate();
    expect(all.length, greaterThanOrEqualTo(50));
    expect({for (final a in all) a.id}, hasLength(all.length));
  });

  group('workouts', () {
    test('early birds, night owls and weekend warriors', () {
      final all = _evaluate(
        workouts: [
          _session('a', WorkoutType.run, DateTime(2026, 10, 10, 6, 15)), // Sat
          _session('b', WorkoutType.run, DateTime(2026, 10, 12, 21, 5)),
          _session('c', WorkoutType.hiit, DateTime(2026, 10, 13, 12)),
        ],
      );
      expect(_a(all, 'earlyBird').current, 1);
      expect(_a(all, 'nightOwl').current, 1);
      expect(_a(all, 'weekendWarrior').current, 1);
    });

    test('the longest session counts for Endurance', () {
      final all = _evaluate(
        workouts: [
          _session(
            'a',
            WorkoutType.cycle,
            DateTime(2026, 10, 1, 9),
            minutes: 95,
          ),
          _session('b', WorkoutType.run, DateTime(2026, 10, 2, 9)),
        ],
      );
      expect(_a(all, 'longWorkout').current, 95);
      expect(_a(all, 'longWorkout').tier, Tier.gold);
    });

    test('runs, rides and swims are counted', () {
      final all = _evaluate(
        workouts: [
          for (var i = 0; i < 10; i++)
            _session('r$i', WorkoutType.run, DateTime(2026, 9, 1 + i, 7)),
          _session('i', WorkoutType.indoorRun, DateTime(2026, 9, 20, 7)),
          _session('c', WorkoutType.cycle, DateTime(2026, 9, 21, 7)),
          _session('s', WorkoutType.swim, DateTime(2026, 9, 22, 7)),
        ],
      );
      expect(_a(all, 'runs').current, 11);
      expect(_a(all, 'runs').tier, Tier.silver);
      expect(_a(all, 'rides').current, 1);
      expect(_a(all, 'swims').current, 1);
    });
  });

  group('strength', () {
    test('the heaviest set and every rep done', () {
      final all = _evaluate(
        workouts: [
          _session(
            'a',
            WorkoutType.strength,
            DateTime(2026, 10, 1, 18),
            exercises: const [
              ExerciseLog(
                exerciseId: 'squat',
                sets: [
                  SetLog(reps: 5, weightKg: 100, done: true),
                  SetLog(reps: 5, weightKg: 110, done: true),
                  // Planned, not done: doesn't count.
                  SetLog(reps: 5, weightKg: 200),
                ],
              ),
            ],
          ),
        ],
      );
      expect(_a(all, 'heaviestLift').current, 110);
      expect(_a(all, 'reps').current, 10);
    });
  });

  group('gym', () {
    test('visits and weeks in a row', () {
      final all = _evaluate(
        gymVisits: [
          DateTime(2026, 10, 13, 18),
          DateTime(2026, 10, 6, 18),
          DateTime(2026, 9, 29, 18),
          DateTime(2026, 9, 1, 18),
        ],
      );
      expect(_a(all, 'gymVisits').current, 4);
      expect(_a(all, 'gymStreak').current, 3);
    });
  });

  group('wellbeing', () {
    test('mood logging and its streak', () {
      final all = _evaluate(
        moodDays: {
          for (var i = 0; i < 9; i++) DateTime(2026, 10, 14 - i),
          DateTime(2026, 9, 1),
        },
      );
      expect(_a(all, 'moodDays').current, 10);
      expect(_a(all, 'moodStreak').current, 9);
      expect(_a(all, 'moodStreak').tier, Tier.silver);
    });

    test('fasts that reached their goal', () {
      expect(_a(_evaluate(fastsReached: 6), 'fasts').tier, Tier.silver);
    });

    test('nights meeting the sleep goal, and water drunk in all', () {
      final all = _evaluate(
        daily: (type, day) => switch (type) {
          MetricType.sleep => day.isAfter(DateTime(2026, 10, 7)) ? 8.2 : 5,
          MetricType.water => 2500,
          _ => null,
        },
      );
      // Nights meeting the 8-hour goal.
      expect(_a(all, 'sleepGoal').current, 7);
      // 2.5 litres a day over two years: 1,825 litres.
      expect(_a(all, 'waterTotal').current, closeTo(1825, 1));
      expect(_a(all, 'waterTotal').tier, Tier.gold);
    });

    test('the best exercise day', () {
      final all = _evaluate(
        daily: (type, day) =>
            type == MetricType.exerciseMinutes && day == DateTime(2026, 10, 3)
            ? 75
            : null,
      );
      expect(_a(all, 'exerciseDay').current, 75);
    });
  });

  test('breakfast logged on its own days', () {
    final all = _evaluate(
      food: [
        for (var i = 0; i < 3; i++)
          FoodEntry(
            id: 'b$i',
            food: const Food(id: 'oats', name: 'Oats', perServing: Nutrients()),
            amount: 1,
            date: DateTime(2026, 10, 10 + i, 8),
            meal: Meal.breakfast,
          ),
        FoodEntry(
          id: 'l',
          food: const Food(id: 'oats', name: 'Oats', perServing: Nutrients()),
          amount: 1,
          date: DateTime(2026, 10, 9, 13),
          meal: Meal.lunch,
        ),
      ],
    );
    expect(_a(all, 'breakfast').current, 3);
  });
}
