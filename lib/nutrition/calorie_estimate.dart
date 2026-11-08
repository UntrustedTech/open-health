import 'package:health_app/models/activity_level.dart';
import 'package:health_app/models/body_goal.dart';
import 'package:health_app/models/user_profile.dart';

export 'package:health_app/models/activity_level.dart';

/// Where the activity level in an estimate came from.
enum ActivitySource {
  /// Average steps over recent days.
  measured,

  /// The level the user picked.
  chosen,

  /// No steps or choice: lightly active is assumed.
  assumed,
}

/// Details an estimate needs that the user hasn't given.
enum MissingDetail {
  birthday('Birthday'),
  height('Height'),
  weight('Weight');

  const MissingDetail(this.label);

  final String label;
}

/// A daily calorie goal, and how it was worked out.
class CalorieEstimate {
  const CalorieEstimate({
    required this.bmr,
    required this.maintenance,
    required this.target,
    required this.level,
    required this.countsExercise,
    required this.atFloor,
    this.weightKg,
    this.source = ActivitySource.assumed,
    this.goalChange = 0,
  });

  /// Where [level] came from.
  final ActivitySource source;

  /// The daily change for the goal: negative to lose, positive to gain.
  final double goalChange;

  /// Energy from activity and digestion on top of resting energy.
  double get activityKcal => maintenance - bmr;

  /// The weight it was worked out for.
  final double? weightKg;

  /// Resting energy (Mifflin-St Jeor), kcal a day.
  final double bmr;

  /// Calories that keep weight steady.
  final double maintenance;

  /// The suggested daily goal, with the [BodyGoal] applied.
  final double target;

  /// The activity level used, or null when the day's measured activity is
  /// added to the budget instead ([countsExercise]).
  final ActivityLevel? level;

  /// True when activity isn't in [maintenance] because each day's active
  /// energy is added to the budget as it happens.
  final bool countsExercise;

  /// True when the goal was raised to the safe minimum.
  final bool atFloor;

  /// Thermic effect of food: about 10% on top of resting energy.
  static const digestion = 1.1;

  /// Lowest goals suggested without medical supervision.
  static const floorFemale = 1200.0;
  static const floorMale = 1500.0;
  static const floorOther = 1350.0;

  /// Days of active energy needed before measured activity is trusted.
  static const minActiveDays = 3;

  /// Resting energy, kcal a day (Mifflin-St Jeor). Without a sex, the
  /// midpoint of the two equations.
  static double bmrOf({
    required String sex,
    required double weightKg,
    required double heightCm,
    required int age,
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    return switch (sex.toLowerCase()) {
      'male' => base + 5,
      'female' => base - 161,
      _ => base - 78,
    };
  }

  /// What [estimate] still needs for [profile] and [weightKg].
  static List<MissingDetail> missingFor(
    UserProfile profile,
    double? weightKg,
    DateTime today,
  ) => [
    if (profile.ageOn(today) == null) MissingDetail.birthday,
    if (profile.heightCm == null) MissingDetail.height,
    if (weightKg == null) MissingDetail.weight,
  ];

  /// The goal for [profile], or null without a weight, height and age.
  ///
  /// When [exerciseAdded] (the food budget grows with each day's active
  /// energy) and there's enough measured activity ([activeDays]), activity
  /// isn't counted here too: maintenance is resting energy plus
  /// digestion, and movement is added as it's measured. Otherwise average
  /// [averageSteps] set the activity level (lightly active without data).
  static CalorieEstimate? estimate({
    required UserProfile profile,
    required double? weightKg,
    required DateTime today,
    required BodyGoal goal,
    required bool exerciseAdded,
    double? averageSteps,
    int activeDays = 0,
  }) {
    final age = profile.ageOn(today);
    final h = profile.heightCm;
    if (weightKg == null || h == null || age == null) return null;
    final bmr = bmrOf(
      sex: profile.sex,
      weightKg: weightKg,
      heightCm: h,
      age: age,
    );
    final countsExercise = exerciseAdded && activeDays >= minActiveDays;
    final chosen = goal.activity;
    final (level, source) = countsExercise
        ? (null, ActivitySource.measured)
        : chosen != null
        ? (chosen, ActivitySource.chosen)
        : averageSteps != null
        ? (ActivityLevel.fromSteps(averageSteps), ActivitySource.measured)
        : (ActivityLevel.low, ActivitySource.assumed);
    final maintenance = bmr * (level?.factor ?? digestion);
    final floor = switch (profile.sex.toLowerCase()) {
      'female' => floorFemale,
      'male' => floorMale,
      _ => floorOther,
    };
    final change = goal.dailyKcalChangeFor(weightKg);
    final wanted = maintenance + change;
    final target = wanted < floor ? floor : wanted;
    return CalorieEstimate(
      bmr: bmr,
      maintenance: _round(maintenance),
      target: _round(target),
      level: level,
      countsExercise: countsExercise,
      atFloor: wanted < floor,
      weightKg: weightKg,
      source: source,
      goalChange: change,
    );
  }

  static double _round(double kcal) => (kcal / 10).round() * 10.0;
}
