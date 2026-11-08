import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/models/activity_level.dart';
import 'package:health_app/models/goal_presets.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/personalization.dart';
import 'package:health_app/models/reminder_presets.dart';
import 'package:health_app/models/user_profile.dart';
import 'package:health_app/notifications/reminder_plan.dart';
import 'package:health_app/state/workout_store.dart';

void main() {
  group('goal presets', () {
    test('recommends for the activity level, with easier and harder', () {
      final presets = goalPresets(
        level: ActivityLevel.moderate,
        current: targetsOf(const Goals()),
      );
      final kinds = presets.map((p) => p.kind).toList();
      expect(kinds, [
        GoalPresetKind.recommended,
        GoalPresetKind.current,
        GoalPresetKind.easier,
        GoalPresetKind.harder,
        GoalPresetKind.custom,
      ]);
      expect(presets.first.targets, targetsForLevel(ActivityLevel.moderate));
      expect(presets[2].targets, targetsForLevel(ActivityLevel.low));
      expect(presets[3].targets, targetsForLevel(ActivityLevel.active));
    });

    test('leaves out current goals when they match the recommendation', () {
      final presets = goalPresets(
        level: ActivityLevel.active,
        current: targetsForLevel(ActivityLevel.active),
      );
      expect(
        presets.map((p) => p.kind),
        isNot(contains(GoalPresetKind.current)),
      );
    });

    test('has no easier preset at the lowest level, no harder at the top', () {
      final lowest = goalPresets(
        level: ActivityLevel.sedentary,
        current: targetsOf(const Goals()),
      );
      final highest = goalPresets(
        level: ActivityLevel.veryActive,
        current: targetsOf(const Goals()),
      );
      expect(lowest.map((p) => p.kind), isNot(contains(GoalPresetKind.easier)));
      expect(
        highest.map((p) => p.kind),
        isNot(contains(GoalPresetKind.harder)),
      );
    });

    test('custom starts from the current goals', () {
      const goals = Goals(steps: 12345, activeEnergy: 420);
      final custom = goalPresets(level: null, current: targetsOf(goals)).last;
      expect(custom.kind, GoalPresetKind.custom);
      expect(targetFor(custom.targets, MetricType.steps), 12345);
      expect(targetFor(custom.targets, MetricType.activeEnergy), 420);
    });

    test('withTarget changes only one target', () {
      final t = targetsForLevel(ActivityLevel.low);
      final next = withTarget(t, MetricType.water, 3000);
      expect(next.water, 3000);
      expect(next.steps, t.steps);
      expect(next.activeEnergy, t.activeEnergy);
      expect(next.exerciseMinutes, t.exerciseMinutes);
    });
  });

  group('setup steps', () {
    test('a skipped Units step from an older version becomes Preferences', () {
      expect(SetupStep.fromName('units'), SetupStep.preferences);
      expect(SetupStep.fromName('about'), SetupStep.about);
      expect(SetupStep.fromName('nope'), isNull);
    });

    test('About You comes first and Connect second', () {
      expect(SetupStep.values.first, SetupStep.about);
      expect(SetupStep.values[1], SetupStep.connect);
      expect(SetupStep.values[2], SetupStep.preferences);
    });
  });

  group('weekly goal', () {
    test('zero means no weekly goal and survives saving', () {
      const s = WorkoutSettings(weeklyGoalMinutes: 0);
      expect(s.hasWeeklyGoal, isFalse);
      final back = WorkoutSettings.fromJson(s.toJson());
      expect(back.weeklyGoalMinutes, 0);
      expect(back.hasWeeklyGoal, isFalse);
    });

    test('a missing or broken goal falls back to the default', () {
      expect(
        WorkoutSettings.fromJson(const {}).weeklyGoalMinutes,
        WorkoutSettings.defaultWeeklyGoal,
      );
      expect(
        WorkoutSettings.fromJson(const {'weeklyGoal': -5}).weeklyGoalMinutes,
        WorkoutSettings.defaultWeeklyGoal,
      );
    });
  });

  group('reminder presets', () {
    test('workout days follow the weekly goal', () {
      expect(sessionsForGoal(0), 3);
      expect(sessionsForGoal(75), 2);
      expect(sessionsForGoal(150), 3);
      expect(sessionsForGoal(300), 6);
      expect(sessionsForGoal(2000), 6);
      expect(workoutDaysForGoal(150), {
        DateTime.monday,
        DateTime.wednesday,
        DateTime.friday,
      });
      expect(workoutDaysForGoal(75), {DateTime.tuesday, DateTime.friday});
      for (final goal in [0, 60, 150, 200, 240, 300, 600]) {
        expect(workoutDaysForGoal(goal), hasLength(sessionsForGoal(goal)));
      }
    });

    test('day lists read naturally', () {
      expect(dayList({1, 3, 5}), 'Mon, Wed and Fri');
      expect(dayList({2}), 'Tue');
      expect(dayList({1, 2, 3, 4, 5, 6, 7}), 'Every day');
      expect(dayList({}), 'No days');
    });

    test('recommended water is every 2 hours from 9 to 9', () {
      const custom = NotificationSettings(waterEveryHours: 3);
      expect(isRecommendedWater(custom), isFalse);
      final rec = withRecommendedWater(custom);
      expect(isRecommendedWater(rec), isTrue);
      expect(rec.waterEveryHours, 2);
      expect(rec.waterStartHour, 9);
      expect(rec.waterEndHour, 21);
    });
  });
}
