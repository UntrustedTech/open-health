import 'package:flutter/foundation.dart';

/// Common intermittent fasting schedules.
enum FastingPreset {
  twelve('12:12', 12, 'A gentle start: overnight plus a little.'),
  sixteen('16:8', 16, 'The most popular: skip breakfast or dinner.'),
  eighteen('18:6', 18, 'A longer fast with a six-hour eating window.'),
  twenty('20:4', 20, 'Advanced: one large meal and a snack.'),
  omad('OMAD', 23, 'One meal a day.');

  const FastingPreset(this.label, this.hours, this.detail);

  final String label;
  final int hours;
  final String detail;

  Duration get duration => Duration(hours: hours);

  static FastingPreset fromName(Object? n) =>
      values.where((p) => p.name == n).firstOrNull ?? sixteen;
}

/// A finished (or ended early) fast.
@immutable
class FastRecord {
  const FastRecord({
    required this.start,
    required this.end,
    required this.goal,
  });

  final DateTime start;
  final DateTime end;
  final Duration goal;

  Duration get length => end.difference(start);
  bool get reachedGoal => length >= goal;

  Map<String, Object?> toJson() => {
    's': start.toIso8601String(),
    'e': end.toIso8601String(),
    'g': goal.inMinutes,
  };

  static FastRecord? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final s = DateTime.tryParse('${json['s']}');
    final e = DateTime.tryParse('${json['e']}');
    final g = json['g'];
    if (s == null || e == null || g is! int || g <= 0 || !e.isAfter(s)) {
      return null;
    }
    return FastRecord(
      start: s,
      end: e,
      goal: Duration(minutes: g),
    );
  }
}

/// The phase of a running fast, by hours since the last meal. A rough,
/// widely used guide (individual bodies vary).
enum FastingStage {
  fed('Digesting', 0, 'Your body is using your last meal.'),
  falling('Blood Sugar Falling', 4, 'Insulin drops as digestion finishes.'),
  burning('Fat Burning', 12, 'Your body turns more to stored fat.'),
  ketosis('Ketosis', 18, 'Ketone levels start to rise.'),
  deep('Deep Fast', 24, 'Longer fasts are best done with medical advice.');

  const FastingStage(this.label, this.fromHours, this.detail);

  final String label;
  final int fromHours;
  final String detail;

  /// The stage after [elapsed]; the first for no time (or less, if the
  /// clock was set back).
  static FastingStage at(Duration elapsed) => values.lastWhere(
    (s) => elapsed.inMinutes >= s.fromHours * 60,
    orElse: () => fed,
  );
}

/// Streak of days (ending today or yesterday) with a fast that reached its
/// goal, by the day each fast ended.
int fastingStreak(List<FastRecord> history, DateTime today) {
  final done = {
    for (final f in history)
      if (f.reachedGoal) DateTime(f.end.year, f.end.month, f.end.day),
  };
  var day = today;
  if (!done.contains(day)) day = DateTime(day.year, day.month, day.day - 1);
  var streak = 0;
  while (done.contains(day)) {
    streak++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return streak;
}
