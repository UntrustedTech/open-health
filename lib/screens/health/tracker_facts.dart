import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/insights/trends.dart' show Trend;
import 'package:health_app/insights/readiness.dart';
import 'package:health_app/models/board_catalog.dart';
import 'package:health_app/models/cycle.dart' show daysBetween;
import 'package:health_app/models/medication.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/mood.dart';
import 'package:health_app/screens/food/food_cards.dart' show kcalText;
import 'package:health_app/screens/readiness/readiness_screen.dart';
import 'package:health_app/screens/recap/recap_screen.dart';
import 'package:health_app/screens/trends_screen.dart';
import 'package:health_app/state/achievement_store.dart';
import 'package:health_app/state/cycle_store.dart';
import 'package:health_app/state/fasting_store.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/medication_store.dart';
import 'package:health_app/state/mood_store.dart';
import 'package:health_app/state/nutrition_store.dart';
import 'package:health_app/state/sleep_schedule_store.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/widgets/board_tiles.dart';

/// Shown for a fact with nothing to show yet.
const _none = '–';

NumberFormat get _count => cachedFormat('grouped', NumberFormat.decimalPattern);

/// What's known about a tracker, most telling first: a medium widget shows
/// the first three, a large one all six. Watches what it reads, so the
/// widget updates with it.
List<StatFact> trackerFacts(BuildContext context, Tracker tracker) =>
    switch (tracker) {
      Tracker.readiness => _readiness(context),
      Tracker.mood => _mood(context),
      Tracker.habits => _habits(context),
      Tracker.sleepSchedule => _sleepSchedule(context),
      Tracker.fasting => _fasting(context),
      Tracker.food => _food(context),
      Tracker.trends => _trends(context),
      Tracker.medications => _medications(context),
      Tracker.cycle => _cycle(context),
      Tracker.achievements => _achievements(context),
      Tracker.recap => _recap(context),
      Tracker.report => _report(context),
    };

String _hours(double? hours) => hours == null ? _none : formatHours(hours);

/// The days from [today] back [days], newest first.
Iterable<DateTime> _lastDays(DateTime today, int days) => [
  for (var i = 0; i < days; i++)
    DateTime(today.year, today.month, today.day - i),
];

List<StatFact> _readiness(BuildContext context) {
  final health = context.watch<HealthStore>();
  final r = readinessOf(health);
  final signals = r?.signals ?? {};
  String score(ReadinessSignal s) =>
      signals[s] == null ? _none : '${signals[s]!.score.round()}';
  final hrv = health.dailyValue(MetricType.hrv, health.today);
  final rhr = health.dailyValue(MetricType.restingHeartRate, health.today);
  return [
    (label: 'HRV Score', value: score(ReadinessSignal.hrv)),
    (label: 'Heart Score', value: score(ReadinessSignal.restingHeart)),
    (label: 'Sleep Score', value: score(ReadinessSignal.sleep)),
    (
      label: 'HRV',
      value: hrv == null ? _none : '${formatValue(MetricType.hrv, hrv)} ms',
    ),
    (label: 'Resting HR', value: rhr == null ? _none : '${rhr.round()} bpm'),
    (
      label: 'Last Night',
      value: _hours(health.dailyValue(MetricType.sleep, health.today)),
    ),
  ];
}

List<StatFact> _habits(BuildContext context) {
  final today = context.select<HealthStore, DateTime>((s) => s.today);
  final mood = context.watch<MoodStore>();
  final habits = mood.habits;
  final week = _lastDays(today, 7);
  final ticks = [
    for (final d in week)
      for (final h in habits)
        if (mood.didHabit(h, d)) h,
  ].length;
  final best = habits.isEmpty
      ? null
      : habits.reduce((a, b) => mood.streak(b) > mood.streak(a) ? b : a);
  return [
    (
      label: 'Today',
      value: habits.isEmpty
          ? _none
          : '${habits.where((h) => mood.didHabit(h, today)).length} of '
                '${habits.length}',
    ),
    (
      label: 'Best Streak',
      value: best == null ? _none : '${mood.streak(best)} days',
    ),
    (
      label: 'This Week',
      value: habits.isEmpty
          ? _none
          : '${(ticks / (habits.length * 7) * 100).round()}%',
    ),
    (label: 'Habits', value: habits.isEmpty ? _none : '${habits.length}'),
    (label: 'Top Habit', value: best ?? _none),
    (label: 'Ticked This Week', value: '$ticks'),
  ];
}

List<StatFact> _mood(BuildContext context) {
  final today = context.select<HealthStore, DateTime>((s) => s.today);
  final moods = context.watch<MoodStore>();
  final week = [for (final d in _lastDays(today, 7)) ?moods.on(d)];
  Mood? common;
  var most = 0;
  for (final m in Mood.values) {
    final n = week.where((e) => e.mood == m).length;
    if (n > most) (common, most) = (m, n);
  }
  final tags = <MoodTag, int>{};
  for (final e in week) {
    for (final t in e.tags) {
      tags[t] = (tags[t] ?? 0) + 1;
    }
  }
  final topTag = tags.entries.isEmpty
      ? null
      : tags.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  var streak = 0;
  for (final d in _lastDays(today, 366)) {
    if (moods.on(d) == null) break;
    streak++;
  }
  return [
    (label: 'Today', value: moods.today?.mood.emoji ?? _none),
    (label: 'Most Often', value: common?.emoji ?? _none),
    (label: 'This Week', value: '${week.length} of 7'),
    (label: 'Top Feeling', value: topTag?.label ?? _none),
    (label: 'Streak', value: '$streak ${streak == 1 ? 'day' : 'days'}'),
    (label: 'All Logged', value: '${moods.days.length}'),
  ];
}

List<StatFact> _sleepSchedule(BuildContext context) {
  final store = context.watch<SleepScheduleStore>();
  final s = store.schedule;
  final c = store.consistency();
  return [
    (
      label: 'Bedtime',
      value: formatTimeOfDay(s.bedtime.hour, s.bedtime.minute),
    ),
    (label: 'Wake', value: formatTimeOfDay(s.wake.hour, s.wake.minute)),
    (
      label: 'On Target',
      value: c.nights == 0 ? _none : '${c.onTarget} of ${c.nights}',
    ),
    (label: 'Goal', value: formatHours(s.goalHours)),
    (label: 'Average', value: _hours(c.average)),
    (
      label: 'Streak',
      value: '${c.streak} ${c.streak == 1 ? 'night' : 'nights'}',
    ),
  ];
}

List<StatFact> _fasting(BuildContext context) {
  final health = context.watch<HealthStore>();
  final fasting = context.watch<FastingStore>();
  final history = fasting.history;
  final longest = history.isEmpty
      ? null
      : history.map((f) => f.length.inMinutes).reduce(math.max) / 60;
  // History is newest first.
  final last = history.firstOrNull;
  return [
    if (fasting.isFasting)
      (
        label: 'Fasting For',
        value: _hours(fasting.elapsed(health.now).inMinutes / 60),
      )
    else
      (
        label: 'Last Fast',
        value: last == null ? _none : _hours(last.length.inMinutes / 60),
      ),
    (label: 'Goal', value: formatHours(fasting.goal.inMinutes / 60)),
    (label: 'Streak', value: '${fasting.streak}'),
    (label: 'Fasts', value: '${history.length}'),
    (label: 'Longest', value: _hours(longest)),
    (
      label: 'Goals Met',
      value: '${history.where((f) => f.reachedGoal).length}',
    ),
  ];
}

List<StatFact> _food(BuildContext context) {
  final today = context.select<HealthStore, DateTime>((s) => s.today);
  final food = context.watch<NutritionStore>();
  final n = food.totalOn(today);
  final budget = food.budgetOn(today);
  return [
    (label: 'Eaten', value: '${kcalText(n.kcal)} Cal'),
    (label: 'Budget', value: '${kcalText(budget)} Cal'),
    (
      label: n.kcal > budget ? 'Over' : 'Left',
      value: '${kcalText((budget - n.kcal).abs())} Cal',
    ),
    (label: 'Protein', value: '${n.protein.round()} g'),
    (label: 'Carbs', value: '${n.carbs.round()} g'),
    (label: 'Fat', value: '${n.fat.round()} g'),
  ];
}

List<StatFact> _trends(BuildContext context) {
  final trends = TrendsScreen.trendsFor(context.watch<HealthStore>());
  String count(Trend t) => '${trends.where((x) => x.trend == t).length}';
  String first(Trend t) =>
      trends.where((x) => x.trend == t).firstOrNull?.type.label ?? _none;
  return [
    (label: 'Rising', value: count(Trend.up)),
    (label: 'Falling', value: count(Trend.down)),
    (label: 'Steady', value: count(Trend.steady)),
    (label: 'Going Up', value: first(Trend.up)),
    (label: 'Going Down', value: first(Trend.down)),
    (label: 'Tracked', value: '${trends.length}'),
  ];
}

List<StatFact> _medications(BuildContext context) {
  final health = context.watch<HealthStore>();
  final meds = context.watch<MedicationStore>();
  final slots = meds.slotsOn(health.today);
  int count(DoseStatus status) =>
      slots.where((s) => s.log?.status == status).length;
  final next = slots
      .where((s) => s.log == null && s.time.isAfter(health.now))
      .map((s) => s.time)
      .fold<DateTime?>(null, (a, t) => a == null || t.isBefore(a) ? t : a);
  String share(double? v) => v == null ? _none : '${(v * 100).round()}%';
  return [
    (label: 'Active', value: '${meds.active.length}'),
    (
      label: 'Taken Today',
      value: slots.isEmpty
          ? _none
          : '${count(DoseStatus.taken)} of ${slots.length}',
    ),
    (
      label: 'Next Dose',
      value: next == null ? _none : formatTimeOfDay(next.hour, next.minute),
    ),
    (label: '7-Day', value: share(meds.adherence(days: 7))),
    (label: '30-Day', value: share(meds.adherence())),
    (label: 'Skipped Today', value: '${count(DoseStatus.skipped)}'),
  ];
}

List<StatFact> _cycle(BuildContext context) {
  final today = context.select<HealthStore, DateTime>((s) => s.today);
  final cycle = context.watch<CycleStore>();
  if (!cycle.enabled) return const [];
  final f = cycle.forecast;
  String inDays(DateTime? day) {
    if (day == null) return _none;
    final d = daysBetween(today, day);
    return d <= 0 ? 'Now' : 'In $d d';
  }

  return [
    (label: 'Day', value: f.cycleDay == null ? _none : '${f.cycleDay}'),
    (label: 'Phase', value: f.phase?.label ?? _none),
    (label: 'Next Period', value: inDays(f.nextStart)),
    (label: 'Fertile', value: inDays(f.fertileStart)),
    (label: 'Cycle', value: '${f.cycleLength} days'),
    (label: 'Period', value: '${f.periodLength} days'),
  ];
}

List<StatFact> _achievements(BuildContext context) {
  final badges = context.watch<AchievementStore>();
  final now = context.select<HealthStore, DateTime>((s) => s.today);
  final thisMonth = badges.earned.where((a) {
    final on = badges.earnedOn(a.id);
    return on != null && on.year == now.year && on.month == now.month;
  }).length;
  return [
    (label: 'Medals to Go', value: '${badges.totalMedals - badges.medals}'),
    (label: 'Badges', value: '${badges.earned.length} of ${badges.all.length}'),
    (label: 'Newest', value: badges.recent.firstOrNull?.title ?? _none),
    (label: 'This Month', value: '$thisMonth'),
    (label: 'New', value: '${badges.unseen.length}'),
    (
      label: 'Complete',
      value: badges.totalMedals == 0
          ? _none
          : '${(badges.medals / badges.totalMedals * 100).round()}%',
    ),
  ];
}

List<StatFact> _recap(BuildContext context) {
  final health = context.watch<HealthStore>();
  final r = recapFor(context, health.today);
  return [
    (label: 'Steps', value: _count.format(r.steps.round())),
    (label: 'Workouts', value: '${r.workouts}'),
    (label: 'Avg Sleep', value: _hours(r.averageSleep)),
    (label: 'Active Cal', value: _count.format(r.activeKcal.round())),
    (
      label: 'Distance',
      value:
          '${formatValue(MetricType.distance, r.distanceKm)} '
          '${unitLabel(MetricType.distance)}',
    ),
    (label: 'Goal Days', value: '${r.ringDays} of ${r.days}'),
  ];
}

List<StatFact> _report(BuildContext context) {
  final health = context.watch<HealthStore>();
  final entries = health.allEntries;
  final dates = entries.map((e) => e.date);
  final since = dates.isEmpty
      ? null
      : dates.reduce((a, b) => a.isBefore(b) ? a : b);
  final latest = dates.isEmpty
      ? null
      : dates.reduce((a, b) => a.isAfter(b) ? a : b);
  return [
    (label: 'Metrics', value: '${entries.map((e) => e.type).toSet().length}'),
    (label: 'Days Logged', value: '${health.daysLogged}'),
    (label: 'Readings', value: _count.format(entries.length)),
    (
      label: 'Since',
      value: since == null ? _none : DateFormat.yMMM().format(since),
    ),
    (
      label: 'Latest',
      value: latest == null ? _none : formatDay(latest, health.today),
    ),
    (label: 'Format', value: 'PDF'),
  ];
}
