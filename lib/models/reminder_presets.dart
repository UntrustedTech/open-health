import 'package:health_app/notifications/reminder_plan.dart';

/// The water reminder schedule recommended in setup.
const recommendedWater = (everyHours: 2, startHour: 9, endHour: 21);

/// Whether [s] uses the recommended water schedule.
bool isRecommendedWater(NotificationSettings s) =>
    s.waterEveryHours == recommendedWater.everyHours &&
    s.waterStartHour == recommendedWater.startHour &&
    s.waterEndHour == recommendedWater.endHour;

/// [s] with the recommended water schedule.
NotificationSettings withRecommendedWater(NotificationSettings s) => s.copyWith(
  waterEveryHours: recommendedWater.everyHours,
  waterStartHour: recommendedWater.startHour,
  waterEndHour: recommendedWater.endHour,
);

/// A typical session length, used to turn a weekly goal into days.
const typicalSessionMinutes = 45;

/// How many days a week to work out to reach [weeklyMinutes] in typical
/// sessions: two to six, or three when there's no weekly goal.
int sessionsForGoal(int weeklyMinutes) => weeklyMinutes <= 0
    ? 3
    : (weeklyMinutes / typicalSessionMinutes).round().clamp(2, 6);

/// Workout days spread through the week for [weeklyMinutes], with rest
/// days in between where possible ([DateTime.monday] = 1).
Set<int> workoutDaysForGoal(int weeklyMinutes) => switch (sessionsForGoal(
  weeklyMinutes,
)) {
  2 => {DateTime.tuesday, DateTime.friday},
  3 => {DateTime.monday, DateTime.wednesday, DateTime.friday},
  4 => {DateTime.monday, DateTime.tuesday, DateTime.thursday, DateTime.friday},
  5 => {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  },
  _ => {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
  },
};

/// The usual evening time for workout reminders.
const recommendedWorkoutHour = 18;

/// Short day names, Monday first.
const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Full weekday names, Monday first, e.g. for VoiceOver.
const weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// "Mon, Wed and Fri" for [days], in week order.
String dayList(Set<int> days) {
  final names = [
    for (var d = 1; d <= 7; d++)
      if (days.contains(d)) dayNames[d - 1],
  ];
  return switch (names.length) {
    0 => 'No days',
    7 => 'Every day',
    1 => names.first,
    _ => '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}',
  };
}
