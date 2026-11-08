import 'package:flutter/foundation.dart';

/// How the day felt, 1 (awful) to 5 (great).
enum Mood {
  awful('Awful', '😣'),
  low('Low', '😕'),
  okay('Okay', '😐'),
  good('Good', '🙂'),
  great('Great', '😄');

  const Mood(this.label, this.emoji);

  final String label;
  final String emoji;

  /// 1..5.
  int get value => index + 1;

  static Mood? fromValue(Object? v) =>
      v is int && v >= 1 && v <= values.length ? values[v - 1] : null;
}

/// Quick tags for what shaped the day.
enum MoodTag {
  energised('Energised'),
  calm('Calm'),
  focused('Focused'),
  social('Social'),
  grateful('Grateful'),
  stressed('Stressed'),
  anxious('Anxious'),
  tired('Tired'),
  sick('Sick'),
  sore('Sore'),
  busy('Busy'),
  lonely('Lonely');

  const MoodTag(this.label);

  final String label;

  static MoodTag? fromName(Object? n) =>
      values.where((t) => t.name == n).firstOrNull;
}

/// One day's journal: a mood, tags and an optional note.
@immutable
class MoodEntry {
  const MoodEntry({required this.mood, this.tags = const {}, this.note = ''});

  /// Longest note kept.
  static const maxNote = 500;

  final Mood mood;
  final Set<MoodTag> tags;
  final String note;

  Map<String, Object?> toJson() => {
    'm': mood.value,
    if (tags.isNotEmpty) 't': [for (final t in tags) t.name],
    if (note.isNotEmpty) 'n': note,
  };

  static MoodEntry? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final mood = Mood.fromValue(json['m']);
    if (mood == null) return null;
    final tags = json['t'];
    final note = json['n'];
    return MoodEntry(
      mood: mood,
      tags: {
        if (tags is List)
          for (final t in tags) ?MoodTag.fromName(t),
      },
      note: note is String
          ? note.substring(0, note.length.clamp(0, maxNote))
          : '',
    );
  }
}

/// A difference in average mood between days with and without something
/// ("+0.8 on days you work out").
typedef MoodPattern = ({String label, double withIt, double without});

/// Patterns between mood and other data, each needing a few days on both
/// sides before it's shown.
abstract final class MoodInsights {
  /// Days needed on each side of a comparison.
  static const minDays = 3;

  /// Smallest difference worth mentioning (on the 1..5 scale).
  static const minDifference = 0.3;

  /// Average mood on days where [test] holds against days where it doesn't.
  static MoodPattern? compare(
    String label,
    Map<DateTime, MoodEntry> days,
    bool? Function(DateTime day) test,
  ) {
    final yes = <int>[], no = <int>[];
    for (final MapEntry(key: day, value: e) in days.entries) {
      switch (test(day)) {
        case true:
          yes.add(e.mood.value);
        case false:
          no.add(e.mood.value);
        case null:
          break;
      }
    }
    if (yes.length < minDays || no.length < minDays) return null;
    double avg(List<int> l) => l.reduce((a, b) => a + b) / l.length;
    final p = (label: label, withIt: avg(yes), without: avg(no));
    return (p.withIt - p.without).abs() >= minDifference ? p : null;
  }

  /// Average mood over [days], or null with none.
  static double? average(Iterable<MoodEntry> days) {
    if (days.isEmpty) return null;
    return days.fold(0, (s, e) => s + e.mood.value) / days.length;
  }
}
