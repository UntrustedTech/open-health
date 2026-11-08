import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/models/body_goal.dart';
import 'package:health_app/models/user_profile.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/nutrition/calorie_estimate.dart';
import 'package:health_app/workout/energy.dart';

void main() {
  final today = DateTime(2026, 10, 12);
  // 30 years old, 180 cm: Mifflin-St Jeor BMR at 80 kg is 1,780 kcal.
  final man = UserProfile(
    sex: 'Male',
    heightCm: 180,
    birthDate: DateTime(1996, 1, 1),
  );

  group('CalorieEstimate', () {
    test('needs weight, height and age', () {
      expect(
        CalorieEstimate.estimate(
          profile: const UserProfile(),
          weightKg: 80,
          today: today,
          goal: const BodyGoal(),
          exerciseAdded: true,
        ),
        isNull,
      );
    });

    test('BMR follows Mifflin-St Jeor', () {
      expect(
        CalorieEstimate.bmrOf(
          sex: 'Male',
          weightKg: 80,
          heightCm: 180,
          age: 30,
        ),
        1780,
      );
      expect(
        CalorieEstimate.bmrOf(
          sex: 'Female',
          weightKg: 60,
          heightCm: 165,
          age: 30,
        ),
        closeTo(1320.25, 0.01),
      );
    });

    test('measured activity is not counted twice', () {
      final e = CalorieEstimate.estimate(
        profile: man,
        weightKg: 80,
        today: today,
        goal: const BodyGoal(),
        exerciseAdded: true,
        activeDays: 10,
      )!;
      // Resting energy plus digestion only; movement is added each day.
      expect(e.countsExercise, isTrue);
      expect(e.maintenance, 1960);
      expect(e.level, isNull);
    });

    test('without activity data, steps set the activity level', () {
      CalorieEstimate at(double? steps) => CalorieEstimate.estimate(
        profile: man,
        weightKg: 80,
        today: today,
        goal: const BodyGoal(),
        exerciseAdded: true,
        averageSteps: steps,
      )!;
      expect(at(null).level, ActivityLevel.low);
      expect(at(3000).maintenance, 2140); // × 1.2
      expect(at(11000).level, ActivityLevel.active);
      expect(at(11000).maintenance, 2760); // × 1.55
    });

    test('a weight-loss goal takes off the deficit for its pace', () {
      final e = CalorieEstimate.estimate(
        profile: man,
        weightKg: 80,
        today: today,
        goal: const BodyGoal(objective: GoalObjective.lose, weeklyRateKg: 0.5),
        exerciseAdded: false,
        averageSteps: 8000,
      )!;
      // 1,780 × 1.465 = 2,608 maintenance; 0.5 kg a week ≈ 550 kcal a day.
      expect(e.maintenance, 2610);
      expect(e.target, 2060);
      expect(e.atFloor, isFalse);
    });

    test('never suggests less than the safe minimum', () {
      final e = CalorieEstimate.estimate(
        profile: UserProfile(
          sex: 'Female',
          heightCm: 150,
          birthDate: DateTime(1960, 1, 1),
        ),
        weightKg: 50,
        today: today,
        goal: const BodyGoal(objective: GoalObjective.lose, weeklyRateKg: 0.75),
        exerciseAdded: false,
        averageSteps: 2000,
      )!;
      expect(e.target, CalorieEstimate.floorFemale);
      expect(e.atFloor, isTrue);
    });

    test('step bands', () {
      expect(ActivityLevel.fromSteps(4999), ActivityLevel.sedentary);
      expect(ActivityLevel.fromSteps(5000), ActivityLevel.low);
      expect(ActivityLevel.fromSteps(9999), ActivityLevel.moderate);
      expect(ActivityLevel.fromSteps(13000), ActivityLevel.veryActive);
    });
  });

  group('BodyGoal', () {
    test('round-trips and rejects bad values', () {
      final g = BodyGoal(
        objective: GoalObjective.gain,
        weeklyRateKg: 0.25,
        startKg: 70,
        startDate: DateTime(2026, 10, 1),
      );
      expect(BodyGoal.fromJson(g.toJson()), g);
      final bad = BodyGoal.fromJson({
        'objective': 'x',
        'rate': 9,
        'startKg': -1,
      });
      expect(bad.objective, GoalObjective.maintain);
      expect(bad.weeklyRateKg, 0.5);
      expect(bad.startKg, isNull);
    });

    test('the pace is capped at 1% of body weight a week', () {
      const goal = BodyGoal(objective: GoalObjective.lose, weeklyRateKg: 0.75);
      expect(goal.safeRate(50), 0.5);
      expect(goal.safeRate(90), 0.75);
      expect(goal.dailyKcalChangeFor(50), closeTo(-550, 0.01));
      // Gaining offers slower paces.
      expect(BodyGoal.ratesFor(GoalObjective.gain).last, 0.5);
    });

    test('only weight goals change calories', () {
      expect(
        const BodyGoal(objective: GoalObjective.fitness).dailyKcalChange,
        0,
      );
      expect(
        const BodyGoal(
          objective: GoalObjective.gain,
          weeklyRateKg: 0.25,
        ).dailyKcalChange,
        275,
      );
    });
  });

  group('workout intensity', () {
    test('running speed sets the MET (ACSM)', () {
      // 10 km/h on the flat: (0.2 × 166.7 + 3.5) / 3.5 ≈ 10.5 METs.
      expect(
        metFor(WorkoutType.run, metersPerSecond: 10 / 3.6),
        closeTo(10.52, 0.01),
      );
      // Hills cost more.
      expect(
        metFor(WorkoutType.run, metersPerSecond: 10 / 3.6, grade: 0.05),
        greaterThan(metFor(WorkoutType.run, metersPerSecond: 10 / 3.6)),
      );
    });

    test('a slow "run" counts as walking, a fast walk as running', () {
      // 5 km/h walk: (0.1 × 83.3 + 3.5) / 3.5 ≈ 3.4 METs.
      expect(
        metFor(WorkoutType.run, metersPerSecond: 5 / 3.6),
        closeTo(3.38, 0.01),
      );
      expect(
        metFor(WorkoutType.walk, metersPerSecond: 9 / 3.6),
        closeTo(metFor(WorkoutType.run, metersPerSecond: 9 / 3.6), 0.001),
      );
    });

    test('cycling by speed band', () {
      expect(metFor(WorkoutType.cycle, metersPerSecond: 15 / 3.6), 4.0);
      expect(metFor(WorkoutType.cycle, metersPerSecond: 23 / 3.6), 10.0);
    });

    test('without a trustworthy pace, the typical value', () {
      expect(
        metFor(WorkoutType.yoga, metersPerSecond: 3),
        WorkoutType.yoga.met,
      );
      expect(metFor(WorkoutType.run), WorkoutType.run.met);
      final short = paceOf(
        distanceMeters: 50,
        active: const Duration(minutes: 5),
      );
      expect(short.metersPerSecond, isNull);
    });

    test('GPS altitude noise can\'t make a steep climb', () {
      expect(
        metFor(WorkoutType.walk, metersPerSecond: 1.4, grade: 0.9),
        metFor(WorkoutType.walk, metersPerSecond: 1.4, grade: maxGrade),
      );
    });
  });
}
