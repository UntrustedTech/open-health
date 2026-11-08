import 'package:flutter/foundation.dart';

/// What the user wants to be reminded about. Everything is off by default.
@immutable
class NotificationSettings {
  const NotificationSettings({
    this.water = false,
    this.waterStartHour = 9,
    this.waterEndHour = 21,
    this.waterEveryHours = 2,
    this.rings = false,
    this.ringsHour = 20,
    this.workout = false,
    this.workoutDays = const {
      DateTime.monday,
      DateTime.wednesday,
      DateTime.friday,
    },
    this.workoutHour = 18,
    this.weeklySummary = false,
    this.meals = false,
    this.mealHours = defaultMealHours,
    this.habits = false,
    this.habitsHour = 21,
    this.habitsLive = false,
  });

  /// Breakfast, lunch and dinner reminder hours.
  static const defaultMealHours = (8, 12, 18);

  final bool water;
  final int waterStartHour;
  final int waterEndHour;
  final int waterEveryHours;
  final bool rings;
  final int ringsHour;
  final bool workout;

  /// [DateTime.monday] … [DateTime.sunday].
  final Set<int> workoutDays;
  final int workoutHour;
  final bool weeklySummary;

  /// Reminders to log breakfast, lunch and dinner in the food diary.
  final bool meals;
  final (int, int, int) mealHours;

  /// A daily nudge to tick off habits.
  final bool habits;
  final int habitsHour;

  /// A quiet notification with today's habits left and a Done button for
  /// each, kept up to date until they're all done (Android).
  final bool habitsLive;

  bool get anyOn =>
      water ||
      rings ||
      workout ||
      weeklySummary ||
      meals ||
      habits ||
      habitsLive;

  NotificationSettings copyWith({
    bool? water,
    int? waterStartHour,
    int? waterEndHour,
    int? waterEveryHours,
    bool? rings,
    int? ringsHour,
    bool? workout,
    Set<int>? workoutDays,
    int? workoutHour,
    bool? weeklySummary,
    bool? meals,
    (int, int, int)? mealHours,
    bool? habits,
    int? habitsHour,
    bool? habitsLive,
  }) => NotificationSettings(
    water: water ?? this.water,
    waterStartHour: waterStartHour ?? this.waterStartHour,
    waterEndHour: waterEndHour ?? this.waterEndHour,
    waterEveryHours: waterEveryHours ?? this.waterEveryHours,
    rings: rings ?? this.rings,
    ringsHour: ringsHour ?? this.ringsHour,
    workout: workout ?? this.workout,
    workoutDays: workoutDays ?? this.workoutDays,
    workoutHour: workoutHour ?? this.workoutHour,
    weeklySummary: weeklySummary ?? this.weeklySummary,
    meals: meals ?? this.meals,
    mealHours: mealHours ?? this.mealHours,
    habits: habits ?? this.habits,
    habitsHour: habitsHour ?? this.habitsHour,
    habitsLive: habitsLive ?? this.habitsLive,
  );

  Map<String, Object?> toJson() => {
    'water': water,
    'waterStart': waterStartHour,
    'waterEnd': waterEndHour,
    'waterEvery': waterEveryHours,
    'rings': rings,
    'ringsHour': ringsHour,
    'workout': workout,
    'workoutDays': workoutDays.toList()..sort(),
    'workoutHour': workoutHour,
    'summary': weeklySummary,
    'meals': meals,
    'mealHours': [mealHours.$1, mealHours.$2, mealHours.$3],
    'habits': habits,
    'habitsHour': habitsHour,
    'habitsLive': habitsLive,
  };

  factory NotificationSettings.fromJson(Map<String, Object?> json) {
    int hour(String key, int fallback) => switch (json[key]) {
      final int v when v >= 0 && v <= 23 => v,
      _ => fallback,
    };
    final days = json['workoutDays'];
    final every = json['waterEvery'];
    final mh = json['mealHours'];
    bool okHour(Object? h) => h is int && h >= 0 && h <= 23;
    return NotificationSettings(
      water: json['water'] == true,
      waterStartHour: hour('waterStart', 9),
      waterEndHour: hour('waterEnd', 21),
      waterEveryHours: every is int && every >= 1 && every <= 6 ? every : 2,
      rings: json['rings'] == true,
      ringsHour: hour('ringsHour', 20),
      workout: json['workout'] == true,
      workoutDays: days is List
          ? days.whereType<int>().where((d) => d >= 1 && d <= 7).toSet()
          : const {DateTime.monday, DateTime.wednesday, DateTime.friday},
      workoutHour: hour('workoutHour', 18),
      weeklySummary: json['summary'] == true,
      meals: json['meals'] == true,
      mealHours: switch (mh) {
        [final int b, final int l, final int d]
            when okHour(b) && okHour(l) && okHour(d) =>
          (b, l, d),
        _ => defaultMealHours,
      },
      habits: json['habits'] == true,
      habitsHour: hour('habitsHour', 21),
      habitsLive: json['habitsLive'] == true,
    );
  }
}

enum ReminderKind { water, rings, workout, summary, medication, meal, habits }

enum Repeat {
  daily,
  weekly,

  /// Fires once, e.g. today's reminder with today's numbers.
  once,
}

/// One repeating notification to schedule.
@immutable
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.kind,
    required this.first,
    required this.repeat,
    required this.title,
    required this.body,
  });

  final int id;
  final ReminderKind kind;

  /// First time it fires; it then repeats at the same time.
  final DateTime first;
  final Repeat repeat;
  final String title;
  final String body;
}

/// Notification ids used for reminders (cancelled and re-created together).
const reminderIds = (start: 100, end: 170);

/// Ids for daily reminders that skip today (see [forScheduling]).
const skippedReminderIds = (start: 1000, end: 1560);

/// Water reminders: at most one an hour, so 24 a day (ids 100–123).
const waterSlots = 24;

/// Whether [id] is a water reminder, as planned or as scheduled.
bool isWaterReminderId(int id) =>
    (id >= reminderIds.start && id < reminderIds.start + waterSlots) ||
    (id >= skippedReminderIds.start &&
        id < skippedReminderIds.start + waterSlots * 8);

/// iOS keeps only the 64 pending notifications that fire soonest and
/// silently drops the rest; [iosReserved] of them stay free for one-off
/// alerts (fast complete, wind-down, rest timer).
const iosPendingLimit = 64;
const iosReserved = 6;

/// At most [budget] of [scheduled], giving up water reminders first (the
/// latest first), then the latest of the rest.
List<PlannedReminder> withinBudget(
  List<PlannedReminder> scheduled,
  int budget,
) {
  if (scheduled.length <= budget) return scheduled;
  if (budget <= 0) return const [];
  int rank(PlannedReminder r) => r.kind == ReminderKind.water ? 1 : 0;
  final ranked = [...scheduled]
    ..sort((a, b) {
      final byKind = rank(a).compareTo(rank(b));
      return byKind != 0 ? byKind : a.first.compareTo(b.first);
    });
  final keep = ranked.take(budget).map((r) => r.id).toSet();
  return [
    for (final r in scheduled)
      if (keep.contains(r.id)) r,
  ];
}

/// Ids for every reminder kind, as scheduled.
bool isReminderId(int id) =>
    (id >= reminderIds.start && id < reminderIds.end) ||
    (id >= skippedReminderIds.start && id < skippedReminderIds.end);

/// Turns [plan] into what the phone can schedule. Android only lets a
/// daily repeat start at the next time its clock time comes round, so a
/// daily reminder that should skip today becomes a weekly repeat for each
/// day of the week, today's starting a week from now. It keeps going even
/// if the app isn't opened again to re-plan.
List<PlannedReminder> forScheduling(List<PlannedReminder> plan, DateTime now) =>
    [
      for (final r in plan)
        if (r.repeat != Repeat.daily || !_skipsToday(r, now))
          r
        else ...[
          for (var d = 1; d <= 7; d++)
            PlannedReminder(
              id: _skippedId(r.id, d),
              kind: r.kind,
              first: DateTime(
                now.year,
                now.month,
                now.day + d,
                r.first.hour,
                r.first.minute,
              ),
              repeat: Repeat.weekly,
              title: r.title,
              body: r.body,
            ),
        ],
    ];

int _skippedId(int id, int day) =>
    skippedReminderIds.start + (id - reminderIds.start) * 8 + day;

/// Whether [r] starts later than its clock time next comes round.
bool _skipsToday(PlannedReminder r, DateTime now) {
  var natural = DateTime(
    now.year,
    now.month,
    now.day,
    r.first.hour,
    r.first.minute,
  );
  if (!natural.isAfter(now)) {
    natural = DateTime(
      now.year,
      now.month,
      now.day + 1,
      r.first.hour,
      r.first.minute,
    );
  }
  return r.first.isAfter(natural);
}

/// Notification ids used for medication reminders.
const medicationReminderIds = (start: 300, end: 500);

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Works out which reminders to schedule. Repeating messages are fixed
/// when scheduled, so they stay general; today's ring reminder is a
/// one-off that says what's left ([ringsLeft], e.g. "120 kcal and 2,000
/// steps"; empty once every ring is closed).
///
/// A water reminder due within [NotificationSettings.waterEveryHours] of
/// a glass logged at [lastWater] is skipped today. The habit reminder
/// skips today once [habitsDone]; null means there are no habits to
/// remind about.
List<PlannedReminder> planReminders(
  NotificationSettings s, {
  required DateTime now,
  bool moveGoalMet = false,
  String? ringsLeft,
  DateTime? lastWater,
  bool? habitsDone,
}) {
  final ringsClosed = moveGoalMet || ringsLeft == '';
  bool waterJustLogged(int hour) {
    final slot = DateTime(now.year, now.month, now.day, hour);
    final last = lastWater;
    return last != null &&
        slot.isAfter(now) &&
        !last.isAfter(now) &&
        !last.isBefore(slot.subtract(Duration(hours: s.waterEveryHours)));
  }

  final ringsToday = DateTime(now.year, now.month, now.day, s.ringsHour);

  DateTime nextDaily(int hour, {bool skipToday = false}) {
    final today = DateTime(now.year, now.month, now.day, hour);
    return skipToday || !today.isAfter(now)
        ? DateTime(now.year, now.month, now.day + 1, hour)
        : today;
  }

  DateTime nextWeekly(int weekday, int hour) {
    var d = DateTime(now.year, now.month, now.day, hour);
    while (d.weekday != weekday || !d.isAfter(now)) {
      d = DateTime(d.year, d.month, d.day + 1, hour);
    }
    return d;
  }

  return [
    if (s.water)
      for (
        var h = s.waterStartHour, i = 0;
        h <= s.waterEndHour && i < waterSlots;
        h += s.waterEveryHours, i++
      )
        PlannedReminder(
          id: reminderIds.start + i,
          kind: ReminderKind.water,
          first: nextDaily(h, skipToday: waterJustLogged(h)),
          repeat: Repeat.daily,
          title: 'Time for some water',
          body: 'Log a glass from your Summary or home screen widget.',
        ),
    if (s.rings) ...[
      // Today's, with today's numbers; the daily one starts tomorrow.
      if (ringsLeft != null && !ringsClosed && ringsToday.isAfter(now))
        PlannedReminder(
          id: reminderIds.start + 31,
          kind: ReminderKind.rings,
          first: ringsToday,
          repeat: Repeat.once,
          title: 'Close your rings',
          body: '$ringsLeft to go. A short walk could do it.',
        ),
      PlannedReminder(
        id: reminderIds.start + 30,
        kind: ReminderKind.rings,
        first: nextDaily(
          s.ringsHour,
          skipToday: ringsClosed || ringsLeft != null,
        ),
        repeat: Repeat.daily,
        title: 'Close your rings',
        body: 'There is still time to reach today\'s goals.',
      ),
    ],
    if (s.workout)
      for (final day in s.workoutDays.toList()..sort())
        PlannedReminder(
          id: reminderIds.start + 40 + day,
          kind: ReminderKind.workout,
          first: nextWeekly(day, s.workoutHour),
          repeat: Repeat.weekly,
          title: 'Workout time',
          body: 'Your ${_weekdayNames[day - 1]} workout is waiting.',
        ),
    if (s.weeklySummary)
      PlannedReminder(
        id: reminderIds.start + 50,
        kind: ReminderKind.summary,
        first: nextWeekly(DateTime.sunday, 18),
        repeat: Repeat.weekly,
        title: 'Your week in review',
        body: 'See your activity, workouts and trends for this week.',
      ),
    if (s.meals)
      for (final (i, (hour, meal)) in [
        (s.mealHours.$1, 'breakfast'),
        (s.mealHours.$2, 'lunch'),
        (s.mealHours.$3, 'dinner'),
      ].indexed)
        PlannedReminder(
          id: reminderIds.start + 55 + i,
          kind: ReminderKind.meal,
          first: nextDaily(hour),
          repeat: Repeat.daily,
          title: 'Log your $meal',
          body: 'Scan or search what you ate to keep your calories on track.',
        ),
    if (s.habits && habitsDone != null)
      PlannedReminder(
        id: reminderIds.start + 60,
        kind: ReminderKind.habits,
        first: nextDaily(s.habitsHour, skipToday: habitsDone),
        repeat: Repeat.daily,
        title: 'How did your habits go?',
        body: 'Tick off today\'s habits.',
      ),
  ];
}
