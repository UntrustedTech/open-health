import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/insights/achievements.dart';
import 'package:health_app/models/body_goal.dart';
import 'package:health_app/models/user_profile.dart';
import 'package:health_app/nutrition/calorie_estimate.dart';
import 'package:health_app/screens/onboarding/setup_units_step.dart';
import 'package:health_app/screens/workouts/workout_goal.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/height_picker.dart';

void main() {
  tearDown(() => Units.system = UnitSystem.metric);

  final man = UserProfile(
    sex: 'Male',
    heightCm: 180,
    birthDate: DateTime(1990, 1, 1),
  );
  final today = DateTime(2026, 10, 13);

  CalorieEstimate? estimate({
    BodyGoal goal = const BodyGoal(),
    double? steps,
    bool exerciseAdded = false,
    int activeDays = 0,
    UserProfile? profile,
    double? weight = 80,
  }) => CalorieEstimate.estimate(
    profile: profile ?? man,
    weightKg: weight,
    today: today,
    goal: goal,
    exerciseAdded: exerciseAdded,
    averageSteps: steps,
    activeDays: activeDays,
  );

  group('units', () {
    test('the US, Liberia and Myanmar default to imperial', () {
      expect(unitsForCountry('US'), UnitSystem.imperial);
      expect(unitsForCountry('mm'), UnitSystem.imperial);
      expect(unitsForCountry('GB'), UnitSystem.metric);
      expect(unitsForCountry(null), UnitSystem.metric);
    });

    test('height shows feet and inches for imperial', () {
      Units.system = UnitSystem.imperial;
      expect(Units.height(177.8), '5\u00A0ft 10\u00A0in');
      Units.system = UnitSystem.metric;
      expect(Units.height(177.8), '178 cm');
    });

    test('elevation shows feet for imperial', () {
      expect(Units.elevation(100), '100 m');
      Units.system = UnitSystem.imperial;
      expect(Units.elevation(100), '328 ft');
    });

    test('distance workout goals show in miles for imperial', () {
      expect(const WorkoutGoal(GoalKind.distance, 5).label, '5 km');
      Units.system = UnitSystem.imperial;
      expect(WorkoutGoal(GoalKind.distance, Units.distanceIn(3)).label, '3 mi');
    });

    test('distance and lifting achievements use the chosen units', () {
      Units.system = UnitSystem.imperial;
      final all = evaluateAchievements(
        AchievementInputs(
          dailyValue: (_, _) => null,
          today: today,
          goals: const Goals(),
          workouts: const [],
          daysLogged: 0,
        ),
      );
      final text = all.map((a) => a.targets.map(a.describe).join('|')).join();
      expect(text, isNot(contains(' km ')));
      expect(text, contains('mi in one go'));
      expect(text, contains('lb in one workout'));
    });

    testWidgets('the height picker uses feet and inches for imperial', (
      tester,
    ) async {
      Units.system = UnitSystem.imperial;
      double? picked;
      await tester.pumpWidget(
        CupertinoApp(
          home: Builder(
            builder: (context) => CupertinoButton(
              onPressed: () async => picked = await pickHeight(context, 180),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('5 ft'), findsOneWidget);
      expect(find.text('11 in'), findsOneWidget);

      // Untouched: the exact height comes back.
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(picked, 180);

      // Moving the inches wheel down one: 5 ft 10 in.
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.drag(find.text('11 in'), const Offset(0, 38));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(picked, closeTo(70 * Units.cmPerInch, 0.001));
    });
  });

  group('calorie estimate', () {
    test('says which details are missing', () {
      expect(CalorieEstimate.missingFor(man, 80, today), isEmpty);
      expect(CalorieEstimate.missingFor(const UserProfile(), null, today), [
        MissingDetail.birthday,
        MissingDetail.height,
        MissingDetail.weight,
      ]);
      expect(estimate(weight: null), isNull);
    });

    test('a chosen activity level wins over steps', () {
      final measured = estimate(steps: 4000);
      expect(measured?.level, ActivityLevel.sedentary);
      expect(measured?.source, ActivitySource.measured);

      final chosen = estimate(
        steps: 4000,
        goal: const BodyGoal(activity: ActivityLevel.active),
      );
      expect(chosen?.level, ActivityLevel.active);
      expect(chosen?.source, ActivitySource.chosen);
      expect(chosen!.target, greaterThan(measured!.target));

      expect(estimate()?.source, ActivitySource.assumed);
    });

    test('the breakdown adds up to the target', () {
      final e = estimate(
        steps: 8000,
        goal: const BodyGoal(objective: GoalObjective.lose),
      )!;
      expect(e.goalChange, closeTo(-550, 0.1));
      expect(e.bmr + e.activityKcal + e.goalChange, closeTo(e.target, 10));
    });

    test('activity choice survives saving and can go back to automatic', () {
      const goal = BodyGoal(activity: ActivityLevel.moderate);
      expect(BodyGoal.fromJson(goal.toJson()), goal);
      expect(goal.copyWith(autoActivity: true).activity, isNull);
      expect(
        goal.copyWith(weeklyRateKg: 0.25).activity,
        ActivityLevel.moderate,
      );
    });
  });
}
