import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:intl/intl.dart';

import 'package:health_app/app_edition.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/models/body_goal.dart';
import 'package:health_app/models/food.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/user_profile.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/theme/app_theme.dart';

enum AchievementGroup {
  activity('Activity'),
  workouts('Workouts'),
  distance('Running, Walking & Cycling'),
  strength('Strength'),
  food('Food'),
  wellbeing('Wellbeing'),
  body('Body & Health');

  const AchievementGroup(this.label);

  final String label;
}

/// The five ranks of every achievement.
enum Tier {
  bronze('Bronze', Color(0xFFD08A4E), Color(0xFF8C5226)),
  silver('Silver', Color(0xFFE3E8F0), Color(0xFF8B95A7)),
  gold('Gold', Color(0xFFFFD45C), Color(0xFFC98A00)),
  platinum('Platinum', Color(0xFFB8F3EC), Color(0xFF4FA9A0)),
  diamond('Diamond', Color(0xFFA8E6FF), Color(0xFF9B7CFF));

  const Tier(this.label, this.light, this.dark);

  final String label;

  /// The medal's highlight and shadow colours.
  final Color light;
  final Color dark;

  Tier? get next => index + 1 < values.length ? values[index + 1] : null;
}

/// A badge with five ranks and how close you are to the next.
@immutable
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.group,
    required this.current,
    required this.targets,
    required this.describe,
  }) : assert(targets.length == 5, 'One target per tier');

  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final AchievementGroup group;
  final double current;

  /// What each tier needs, bronze to diamond, rising.
  final List<double> targets;

  /// What reaching [target] means, e.g. "Walk 10,000 steps in a day".
  final String Function(double target) describe;

  /// The highest tier reached, or null for none yet.
  Tier? get tier {
    Tier? reached;
    for (final t in Tier.values) {
      if (current >= targets[t.index]) reached = t;
    }
    return reached;
  }

  bool get earned => tier != null;

  /// All five tiers reached.
  bool get maxed => tier == Tier.diamond;

  /// The tier being worked toward, or null when all are reached.
  Tier? get nextTier => tier == null ? Tier.bronze : tier!.next;

  double targetOf(Tier t) => targets[t.index];

  /// Progress toward the next tier, 0..1 (1 when all are reached).
  double get progress {
    final next = nextTier;
    if (next == null) return 1;
    final from = next == Tier.bronze ? 0.0 : targets[next.index - 1];
    final to = targets[next.index];
    return ((current - from) / (to - from)).clamp(0.0, 1.0);
  }

  /// The next goal in words, or the top one once all are reached.
  String get detail => describe(targetOf(nextTier ?? Tier.diamond));
}

/// What achievements are worked out from.
@immutable
class AchievementInputs {
  const AchievementInputs({
    required this.dailyValue,
    required this.today,
    required this.goals,
    required this.workouts,
    required this.daysLogged,
    this.food = const [],
    this.foodGoals = const NutritionGoals(),
    this.dosesTaken = 0,
    this.periods = 0,
    this.bodyGoal = const BodyGoal(),
    this.latestWeightKg,
    this.firstDay,
    this.gymVisits = const [],
    this.moodDays = const {},
    this.fastsReached = 0,
  });

  final double? Function(MetricType type, DateTime day) dailyValue;
  final DateTime today;
  final Goals goals;
  final List<WorkoutSession> workouts;
  final int daysLogged;
  final List<FoodEntry> food;
  final NutritionGoals foodGoals;
  final int dosesTaken;
  final int periods;
  final BodyGoal bodyGoal;
  final double? latestWeightKg;

  /// The day of the earliest data, so totals can cover all of it.
  final DateTime? firstDay;

  /// Gym check-ins.
  final List<DateTime> gymVisits;

  /// Days with a mood logged.
  final Set<DateTime> moodDays;

  /// Fasts that lasted their goal.
  final int fastsReached;
}

/// How far back daily achievements look.
const _lookback = 730;

/// The furthest back "in all" totals go (ten years).
const _maxLookback = 3650;

NumberFormat get _n => cachedFormat('grouped', NumberFormat.decimalPattern);

/// A distance target (in km) in the user's units.
String _km(double km) => Units.imperial
    ? '${_num((Units.distanceOut(km) * 10).round() / 10)} mi'
    : '${_num(km)} km';

/// A climb target (in metres) in the user's units.
String _m(double m) => Units.imperial
    ? '${_num((m * Units.feetPerMeter).roundToDouble())} ft'
    : '${_num(m)} m';

String _num(double v) =>
    v == v.roundToDouble() ? _n.format(v.round()) : v.toStringAsFixed(1);

/// Every achievement with its progress, in display order.
List<Achievement> evaluateAchievements(AchievementInputs x) {
  // Everything since the first data ("in all" totals mean all), within
  // reason; at least two years so streak windows are full.
  final first = x.firstDay;
  final span = first == null
      ? _lookback
      : x.today.difference(first).inDays.clamp(_lookback, _maxLookback) + 1;
  final days = [
    for (var i = span - 1; i >= 0; i--)
      DateTime(x.today.year, x.today.month, x.today.day - i),
  ];
  final index = {for (final (i, d) in days.indexed) d: i};
  // Each metric's daily values are read once and reused by every badge.
  final series = <MetricType, List<double>>{};
  List<double> of(MetricType t) => series.putIfAbsent(
    t,
    () => [for (final d in days) x.dailyValue(t, d) ?? 0],
  );
  double v(MetricType t, DateTime d) => of(t)[index[d]!];
  double best(MetricType t) =>
      days.map((d) => v(t, d)).fold(0, (a, b) => a > b ? a : b);
  double total(MetricType t) =>
      days.map((d) => v(t, d)).fold(0, (a, b) => a + b);
  bool met(MetricType t, DateTime d) {
    final goal = x.goals.forMetric(t);
    return goal != null && goal > 0 && v(t, d) >= goal;
  }

  bool allRings(DateTime d) =>
      met(MetricType.activeEnergy, d) &&
      met(MetricType.exerciseMinutes, d) &&
      met(MetricType.steps, d);

  /// Longest run of consecutive days where [test] holds.
  double longestRun(bool Function(DateTime) test) {
    var best = 0, run = 0;
    for (final d in days) {
      run = test(d) ? run + 1 : 0;
      if (run > best) best = run;
    }
    return best.toDouble();
  }

  /// Most of [t] in any 7 days in a row.
  double bestWeek(MetricType t) {
    var best = 0.0, sum = 0.0;
    for (var i = 0; i < days.length; i++) {
      sum += v(t, days[i]);
      if (i >= 7) sum -= v(t, days[i - 7]);
      if (sum > best) best = sum;
    }
    return best;
  }

  double count(bool Function(DateTime) test) =>
      days.where(test).length.toDouble();

  DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  // Workouts.
  final w = x.workouts;
  double longest(Set<WorkoutType> types) => w
      .where((s) => types.contains(s.type))
      .map((s) => s.kilometres)
      .fold(0, (a, b) => a > b ? a : b);
  final workoutDays = {for (final s in w) dayOf(s.start)};
  final sets = [
    for (final s in w)
      for (final e in s.exercises)
        for (final set in e.sets)
          if (set.done || set.reps > 0) set,
  ];
  final exercisesTried = {
    for (final s in w)
      for (final e in s.exercises) e.exerciseId,
  };

  double sessions(Set<WorkoutType> types) =>
      w.where((s) => types.contains(s.type)).length.toDouble();
  final doneSets = [
    for (final s in w)
      for (final e in s.exercises)
        for (final set in e.sets)
          if (set.done) set,
  ];
  // Weekends (by their Saturday) with a workout on either day.
  final weekends = {
    for (final s in w)
      if (s.start.weekday >= DateTime.saturday)
        DateTime(
          s.start.year,
          s.start.month,
          s.start.day - (s.start.weekday - DateTime.saturday),
        ),
  };
  // The longest run of weeks in a row with a gym visit.
  DateTime mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));
  final gymWeeks = {for (final v in x.gymVisits) mondayOf(v)}.toList()..sort();
  var gymStreak = 0, gymRun = 0;
  for (final (i, week) in gymWeeks.indexed) {
    final prev = i == 0 ? null : gymWeeks[i - 1];
    gymRun = prev != null && week.difference(prev).inDays.abs() <= 8
        ? gymRun + 1
        : 1;
    if (gymRun > gymStreak) gymStreak = gymRun;
  }

  // Food.
  final foodDays = {for (final e in x.food) dayOf(e.date)};
  final breakfastDays = {
    for (final e in x.food)
      if (e.meal == Meal.breakfast) dayOf(e.date),
  };
  final kcalByDay = <DateTime, double>{};
  final proteinByDay = <DateTime, double>{};
  for (final e in x.food) {
    final d = dayOf(e.date);
    final n = e.nutrients;
    kcalByDay[d] = (kcalByDay[d] ?? 0) + n.kcal;
    proteinByDay[d] = (proteinByDay[d] ?? 0) + n.protein;
  }
  final kcalGoal = x.foodGoals.kcal;
  bool onBudget(DateTime d) {
    final k = kcalByDay[d];
    // Within 10% of the goal, on a day with a real amount logged.
    return k != null &&
        k >= kcalGoal * 0.5 &&
        (k - kcalGoal).abs() <= kcalGoal * 0.1;
  }

  // Body goal: share of the way from the start to the target.
  final start = x.bodyGoal.startKg, target = x.goals.weightKg;
  final now = x.latestWeightKg;
  var goalShare = 0.0;
  if (x.bodyGoal.objective.changesWeight &&
      start != null &&
      target != null &&
      now != null &&
      (target - start).abs() >= 0.5) {
    goalShare = ((now - start) / (target - start)).clamp(0.0, 1.0) * 100;
  }

  final moveGoal = x.goals.forMetric(MetricType.activeEnergy) ?? 0;
  final steps = Palette.indigo, move = Palette.pink, ring = Palette.aurora;
  const act = AchievementGroup.activity;
  const fit = AchievementGroup.workouts;
  const dist = AchievementGroup.distance;
  const str = AchievementGroup.strength;
  const eat = AchievementGroup.food;
  const well = AchievementGroup.wellbeing;
  const body = AchievementGroup.body;

  Achievement a(
    String id,
    String title,
    IconData icon,
    Color color,
    AchievementGroup group,
    double current,
    List<double> targets,
    String Function(double t) describe,
  ) => Achievement(
    id: id,
    title: title,
    icon: icon,
    color: color,
    group: group,
    current: current,
    targets: targets,
    describe: describe,
  );

  return [
    // ------------------------------------------------------------ activity
    a(
      'steps',
      'Step Day',
      Icons.directions_walk_rounded,
      steps,
      act,
      best(MetricType.steps),
      [10000, 15000, 20000, 30000, 40000],
      (t) => 'Walk ${_num(t)} steps in a day',
    ),
    a(
      'stepsTotal',
      'Globetrotter',
      Icons.public_rounded,
      steps,
      act,
      total(MetricType.steps),
      [100000, 500000, 1000000, 2500000, 5000000],
      (t) => 'Walk ${_num(t)} steps in all',
    ),
    a(
      'perfectDays',
      'Perfect Days',
      Icons.donut_large_rounded,
      ring,
      act,
      count(allRings),
      [1, 10, 50, 100, 365],
      (t) => 'Close all three rings on ${_num(t)} ${t == 1 ? 'day' : 'days'}',
    ),
    a(
      'ringStreak',
      'Ring Streak',
      Icons.stars_rounded,
      ring,
      act,
      longestRun(allRings),
      [3, 7, 14, 30, 100],
      (t) => 'Close all rings ${_num(t)} days in a row',
    ),
    a(
      'moveStreak',
      'Move Streak',
      Icons.local_fire_department_rounded,
      move,
      act,
      longestRun((d) => met(MetricType.activeEnergy, d)),
      [7, 14, 30, 60, 100],
      (t) => 'Meet your Move goal ${_num(t)} days in a row',
    ),
    a(
      'overachiever',
      'Overachiever',
      Icons.bolt_rounded,
      move,
      act,
      moveGoal <= 0 ? 0 : best(MetricType.activeEnergy) / moveGoal * 100,
      [150, 200, 300, 400, 500],
      (t) => 'Burn ${_num(t)}% of your Move goal in a day',
    ),
    a(
      'activeWeek',
      'Active Week',
      Icons.timer_rounded,
      ring,
      act,
      bestWeek(MetricType.exerciseMinutes),
      [150, 300, 450, 600, 900],
      (t) => 'Exercise ${_num(t)} minutes in a week',
    ),
    // ------------------------------------------------------------ workouts
    a(
      'workouts',
      'Dedicated',
      Icons.workspace_premium_rounded,
      Palette.green,
      fit,
      w.length.toDouble(),
      [1, 25, 100, 250, 500],
      (t) =>
          t == 1 ? 'Record your first workout' : 'Record ${_num(t)} workouts',
    ),
    a(
      'workoutStreak',
      'Week Warrior',
      Icons.edit_calendar_rounded,
      Palette.green,
      fit,
      longestRun(workoutDays.contains),
      [3, 7, 14, 30, 60],
      (t) => 'Work out ${_num(t)} days in a row',
    ),
    a(
      'workoutHours',
      'Time Invested',
      Icons.hourglass_bottom_rounded,
      Palette.green,
      fit,
      w.fold<double>(0, (s, e) => s + e.activeSeconds) / 3600,
      [5, 25, 100, 250, 500],
      (t) => 'Work out for ${_num(t)} hours in all',
    ),
    a(
      'variety',
      'Explorer',
      Icons.explore_rounded,
      Palette.green,
      fit,
      {for (final s in w) s.type}.length.toDouble(),
      [2, 4, 6, 8, 10],
      (t) => 'Try ${_num(t)} kinds of workout',
    ),
    a(
      'earlyBird',
      'Early Bird',
      Icons.wb_twilight_rounded,
      Palette.orange,
      fit,
      w.where((s) => s.start.hour < 7).length.toDouble(),
      [1, 10, 25, 50, 100],
      (t) => 'Start ${_num(t)} ${t == 1 ? 'workout' : 'workouts'} before 7 am',
    ),
    a(
      'nightOwl',
      'Night Owl',
      Icons.nightlight_round,
      Palette.indigo,
      fit,
      w.where((s) => s.start.hour >= 20).length.toDouble(),
      [1, 10, 25, 50, 100],
      (t) => 'Start ${_num(t)} ${t == 1 ? 'workout' : 'workouts'} after 8 pm',
    ),
    a(
      'weekendWarrior',
      'Weekend Warrior',
      Icons.weekend_rounded,
      Palette.green,
      fit,
      weekends.length.toDouble(),
      [1, 8, 26, 52, 104],
      (t) => 'Work out on ${_num(t)} ${t == 1 ? 'weekend' : 'weekends'}',
    ),
    a(
      'longWorkout',
      'Endurance',
      Icons.timer_rounded,
      Palette.teal,
      fit,
      w.map((s) => s.activeSeconds / 60).fold(0, (a, b) => a > b ? a : b),
      [45, 60, 90, 120, 180],
      (t) => 'Keep going for ${_num(t)} minutes in one workout',
    ),
    a(
      'gymVisits',
      'Gym Regular',
      Icons.badge_rounded,
      Palette.mint,
      fit,
      x.gymVisits.length.toDouble(),
      [1, 10, 50, 100, 250],
      (t) => 'Check in at the gym ${_num(t)} ${t == 1 ? 'time' : 'times'}',
    ),
    a(
      'gymStreak',
      'Creature of Habit',
      Icons.event_repeat_rounded,
      Palette.mint,
      fit,
      gymStreak.toDouble(),
      [2, 4, 8, 16, 52],
      (t) => 'Visit the gym ${_num(t)} weeks in a row',
    ),
    // ------------------------------------------------------------ distance
    a(
      'longestRun',
      'Distance Runner',
      Icons.directions_run_rounded,
      Palette.orange,
      dist,
      longest({WorkoutType.run}),
      [5, 10, 21.1, 30, 42.2],
      (t) => switch (t) {
        21.1 => 'Run a half marathon (${_km(t)}) in one go',
        42.2 => 'Run a marathon (${_km(t)}) in one go',
        _ => 'Run ${_km(t)} in one go',
      },
    ),
    a(
      'longestRide',
      'Long Ride',
      Icons.directions_bike_rounded,
      Palette.cyan,
      dist,
      longest({WorkoutType.cycle}),
      [10, 25, 50, 100, 160],
      (t) => 'Ride ${_km(t)} in one go',
    ),
    a(
      'longestWalk',
      'Trailblazer',
      Icons.hiking_rounded,
      Palette.green,
      dist,
      longest({WorkoutType.walk, WorkoutType.hike}),
      [5, 10, 20, 30, 42.2],
      (t) => 'Walk or hike ${_km(t)} in one go',
    ),
    a(
      'distanceWeek',
      'Big Week',
      Icons.map_rounded,
      Palette.orange,
      dist,
      bestWeek(MetricType.distance),
      [20, 42.2, 75, 100, 150],
      (t) => 'Cover ${_km(t)} in a week',
    ),
    a(
      'distanceTotal',
      'Long Haul',
      Icons.route_rounded,
      Palette.orange,
      dist,
      total(MetricType.distance),
      [50, 250, 500, 1000, 2500],
      (t) => 'Cover ${_km(t)} in all',
    ),
    a(
      'climb',
      'Climber',
      Icons.terrain_rounded,
      Palette.brown,
      dist,
      w.fold<double>(0, (s, e) => s + e.elevationGainMeters),
      [500, 2000, 5000, 8849, 20000],
      (t) => t == 8849
          ? 'Climb the height of Everest (${_m(t)}) in all'
          : 'Climb ${_m(t)} in all',
    ),
    a(
      'runs',
      'Runner',
      Icons.directions_run_rounded,
      Palette.orange,
      dist,
      sessions({WorkoutType.run, WorkoutType.indoorRun}),
      [1, 10, 50, 100, 250],
      (t) => 'Go for ${_num(t)} ${t == 1 ? 'run' : 'runs'}',
    ),
    a(
      'rides',
      'Cyclist',
      Icons.directions_bike_rounded,
      Palette.green,
      dist,
      sessions({WorkoutType.cycle, WorkoutType.indoorCycle}),
      [1, 10, 50, 100, 250],
      (t) => 'Go for ${_num(t)} ${t == 1 ? 'ride' : 'rides'}',
    ),
    a(
      'swims',
      'Swimmer',
      Icons.pool_rounded,
      Palette.cyan,
      dist,
      sessions({WorkoutType.swim}),
      [1, 5, 20, 50, 100],
      (t) => 'Swim ${_num(t)} ${t == 1 ? 'time' : 'times'}',
    ),
    // ------------------------------------------------------------ strength
    a(
      'volume',
      'Heavy Lifter',
      Icons.fitness_center_rounded,
      Palette.purple,
      str,
      w.map((s) => s.volumeKg).fold(0, (a, b) => a > b ? a : b),
      [2500, 5000, 10000, 20000, 30000],
      (t) => 'Lift ${Units.weight(t, decimals: 0)} in one workout',
    ),
    a(
      'volumeTotal',
      'Tonnage',
      Icons.scale_rounded,
      Palette.purple,
      str,
      w.fold<double>(0, (s, e) => s + e.volumeKg) / 1000,
      [50, 250, 1000, 2500, 5000],
      (t) => 'Lift ${_num(t)} tonnes in all',
    ),
    a(
      'heaviestLift',
      'Iron Will',
      Icons.sports_gymnastics_rounded,
      Palette.purple,
      str,
      doneSets.map((s) => s.weightKg).fold(0, (a, b) => a > b ? a : b),
      [40, 60, 100, 140, 180],
      (t) => 'Lift ${Units.weight(t, decimals: 0)} in one set',
    ),
    a(
      'reps',
      'Rep Machine',
      Icons.repeat_rounded,
      Palette.purple,
      str,
      doneSets.fold<double>(0, (n, s) => n + s.reps),
      [500, 2500, 10000, 25000, 50000],
      (t) => 'Do ${_num(t)} reps in all',
    ),
    a(
      'sets',
      'Set by Set',
      Icons.format_list_numbered_rounded,
      Palette.purple,
      str,
      sets.length.toDouble(),
      [50, 250, 1000, 2500, 5000],
      (t) => 'Log ${_num(t)} sets',
    ),
    a(
      'exercises',
      'Well Rounded',
      Icons.category_rounded,
      Palette.purple,
      str,
      exercisesTried.length.toDouble(),
      [5, 15, 30, 50, 100],
      (t) => 'Train ${_num(t)} different exercises',
    ),
    // ---------------------------------------------------------------- food
    a(
      'foodDays',
      'Food Logger',
      Icons.restaurant_rounded,
      Palette.orange,
      eat,
      foodDays.length.toDouble(),
      [1, 7, 30, 100, 365],
      (t) => t == 1 ? 'Log your first meal' : 'Log food on ${_num(t)} days',
    ),
    a(
      'foodStreak',
      'Mindful Eater',
      Icons.event_available_rounded,
      Palette.orange,
      eat,
      longestRun(foodDays.contains),
      [3, 7, 30, 60, 100],
      (t) => 'Log food ${_num(t)} days in a row',
    ),
    a(
      'onBudget',
      'On Budget',
      Icons.track_changes_rounded,
      Palette.orange,
      eat,
      count(onBudget),
      [1, 7, 30, 100, 200],
      (t) =>
          'Eat within 10% of your calorie goal on ${_num(t)} '
          '${t == 1 ? 'day' : 'days'}',
    ),
    a(
      'protein',
      'Protein Pro',
      Icons.egg_alt_rounded,
      Palette.teal,
      eat,
      count(
        (d) =>
            (proteinByDay[d] ?? 0) >= x.foodGoals.proteinGrams &&
            x.foodGoals.proteinGrams > 0,
      ),
      [1, 7, 30, 100, 200],
      (t) =>
          'Meet your protein goal on ${_num(t)} '
          '${t == 1 ? 'day' : 'days'}',
    ),
    a(
      'scanner',
      'Label Reader',
      Icons.qr_code_scanner_rounded,
      Palette.orange,
      eat,
      x.food.where((e) => e.food.barcode != null).length.toDouble(),
      [1, 10, 50, 200, 500],
      (t) => t == 1
          ? 'Log a food by scanning its barcode'
          : 'Log ${_num(t)} scanned foods',
    ),
    // ----------------------------------------------------------- wellbeing
    a(
      'breakfast',
      'Breakfast Club',
      Icons.free_breakfast_rounded,
      Palette.yellow,
      eat,
      breakfastDays.length.toDouble(),
      [7, 30, 100, 200, 365],
      (t) => 'Log breakfast on ${_num(t)} days',
    ),
    a(
      'water',
      'Hydrated',
      Icons.water_drop_rounded,
      Palette.cyan,
      well,
      longestRun((d) => met(MetricType.water, d)),
      [3, 7, 14, 30, 100],
      (t) => 'Meet your water goal ${_num(t)} days in a row',
    ),
    a(
      'sleep',
      'Well Rested',
      Icons.bed_rounded,
      Palette.indigo,
      well,
      longestRun((d) => v(MetricType.sleep, d) >= 7),
      [3, 7, 14, 30, 60],
      (t) => 'Sleep 7 hours or more ${_num(t)} nights in a row',
    ),
    a(
      'sleepGoal',
      'Sleep Goal',
      Icons.bedtime_rounded,
      Palette.indigo,
      well,
      count((d) => met(MetricType.sleep, d)),
      [7, 30, 100, 200, 365],
      (t) => 'Meet your sleep goal on ${_num(t)} nights',
    ),
    a(
      'waterTotal',
      'Water Works',
      Icons.local_drink_rounded,
      Palette.cyan,
      well,
      total(MetricType.water) / 1000,
      [50, 250, 1000, 2500, 5000],
      (t) => 'Drink ${_num(t)} litres of water in all',
    ),
    a(
      'moodDays',
      'Self-Check',
      Icons.emoji_emotions_rounded,
      Palette.yellow,
      well,
      x.moodDays.length.toDouble(),
      [1, 7, 30, 100, 365],
      (t) => 'Log your mood on ${_num(t)} ${t == 1 ? 'day' : 'days'}',
    ),
    a(
      'moodStreak',
      'Self-Aware',
      Icons.self_improvement_rounded,
      Palette.yellow,
      well,
      longestRun((d) => x.moodDays.contains(d)),
      [3, 7, 14, 30, 100],
      (t) => 'Log your mood ${_num(t)} days in a row',
    ),
    a(
      'fasts',
      'Fasting Focus',
      Icons.hourglass_bottom_rounded,
      Palette.purple,
      well,
      x.fastsReached.toDouble(),
      [1, 5, 20, 50, 100],
      (t) => 'Reach your fasting goal ${_num(t)} ${t == 1 ? 'time' : 'times'}',
    ),
    a(
      'exerciseDay',
      'Sweat Session',
      Icons.whatshot_rounded,
      move,
      act,
      best(MetricType.exerciseMinutes),
      [30, 60, 90, 120, 180],
      (t) => 'Exercise ${_num(t)} minutes in a day',
    ),
    a(
      'mindful',
      'Calm Mind',
      Icons.self_improvement_rounded,
      Palette.mint,
      well,
      count((d) => v(MetricType.mindfulMinutes, d) > 0),
      [1, 7, 30, 100, 365],
      (t) =>
          'Practise mindfulness on ${_num(t)} '
          '${t == 1 ? 'day' : 'days'}',
    ),
    a(
      'logged',
      'Committed',
      Icons.monitor_heart_rounded,
      Palette.pink,
      well,
      x.daysLogged.toDouble(),
      [7, 30, 100, 365, 730],
      (t) => 'Log health data on ${_num(t)} days',
    ),
    // ----------------------------------------------------------------- body
    a(
      'weighIns',
      'Check-In',
      Icons.monitor_weight_rounded,
      Palette.purple,
      body,
      count((d) => v(MetricType.weight, d) > 0),
      [1, 10, 30, 100, 250],
      (t) => t == 1 ? 'Log your weight' : 'Log your weight on ${_num(t)} days',
    ),
    a(
      'goal',
      'Goal Getter',
      Icons.flag_rounded,
      Palette.teal,
      body,
      goalShare,
      [10, 25, 50, 75, 100],
      (t) => t == 100
          ? 'Reach your target weight'
          : 'Get ${_num(t)}% of the way to your target weight',
    ),
    if (!kStoreEdition)
      a(
        'meds',
        'On Schedule',
        Icons.medication_rounded,
        Palette.blue,
        body,
        x.dosesTaken.toDouble(),
        [1, 30, 100, 365, 1000],
        (t) => t == 1
            ? 'Log a medication dose'
            : 'Log ${_num(t)} medication doses',
      ),
    a(
      'cycle',
      'In Tune',
      Icons.water_drop_outlined,
      Palette.pink,
      body,
      x.periods.toDouble(),
      [1, 3, 6, 12, 24],
      (t) => t == 1 ? 'Log a period' : 'Log ${_num(t)} periods',
    ),
  ];
}
