import 'package:flutter/foundation.dart';

import 'package:health_app/models/cycle.dart'
    show dateOnly, dayKey, parseDayKey;
import 'package:health_app/models/mood.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/utils/log.dart';

/// The mood journal: one entry a day, and daily habits to tick off.
/// Saved through the HealthStore's write queue.
class MoodStore extends ChangeNotifier {
  MoodStore(this._health);

  static const docKey = 'mood';

  /// Days kept.
  static const _keepDays = 800;

  final HealthStore _health;

  Map<DateTime, MoodEntry> _days = {};
  List<String> _habits = [];
  Map<DateTime, Set<String>> _habitDays = {};

  /// Icon and colour names a habit was given, keyed by habit.
  Map<String, ({String? icon, String? color})> _looks = {};
  bool _readable = true;

  /// Longest habit name kept.
  static const maxHabitName = 60;

  Map<DateTime, MoodEntry> get days => Map.unmodifiable(_days);

  /// Habits, in the order they were added.
  List<String> get habits => List.unmodifiable(_habits);

  /// Null with no habits; else whether every one is ticked off today.
  bool? get habitsDoneToday =>
      _habits.isEmpty ? null : _habits.every((h) => didHabit(h, _health.today));

  bool didHabit(String habit, DateTime day) =>
      _habitDays[dateOnly(day)]?.contains(habit) ?? false;

  /// Days in a row [habit] was done, up to today. Today not done yet
  /// doesn't break it.
  int streak(String habit) {
    final t = _health.today;
    var day = didHabit(habit, t) ? t : DateTime(t.year, t.month, t.day - 1);
    var n = 0;
    while (didHabit(habit, day)) {
      n++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return n;
  }

  /// Most days in a row [habit] was ever done.
  int bestStreak(String habit) {
    final days = [
      for (final MapEntry(:key, :value) in _habitDays.entries)
        if (value.contains(habit)) key,
    ]..sort();
    var best = 0, run = 0;
    DateTime? last;
    for (final d in days) {
      final next = last == null
          ? null
          : DateTime(last.year, last.month, last.day + 1);
      run = d == next ? run + 1 : 1;
      if (run > best) best = run;
      last = d;
    }
    return best;
  }

  /// The icon and colour names chosen for [habit]; null parts mean the
  /// screen picks one from the name.
  ({String? icon, String? color}) look(String habit) =>
      _looks[habit] ?? (icon: null, color: null);

  Future<void> setLook(String habit, {String? icon, String? color}) async {
    if (!_habits.contains(habit)) return;
    _looks = {..._looks, habit: (icon: icon, color: color)};
    notifyListeners();
    await _save();
  }

  /// Moves [habit] [by] places up (negative) or down the list.
  Future<void> moveHabit(String habit, int by) async {
    final i = _habits.indexOf(habit);
    final to = i + by;
    if (i < 0 || to < 0 || to >= _habits.length) return;
    _habits = [..._habits]
      ..removeAt(i)
      ..insert(to, habit);
    notifyListeners();
    await _save();
  }

  /// Adds [name] as a habit; false if it's empty or already there.
  Future<bool> addHabit(String name) async {
    final n = name.trim();
    if (n.isEmpty || n.length > maxHabitName || _habits.contains(n)) {
      return false;
    }
    _habits = [..._habits, n];
    notifyListeners();
    await _save();
    return true;
  }

  /// Renames [habit] to [name], keeping its history; false if [name] is
  /// empty or another habit's.
  Future<bool> renameHabit(String habit, String name) async {
    final n = name.trim();
    if (n == habit) return true;
    if (n.isEmpty ||
        n.length > maxHabitName ||
        _habits.contains(n) ||
        !_habits.contains(habit)) {
      return false;
    }
    _habits = [for (final h in _habits) h == habit ? n : h];
    _habitDays = {
      for (final MapEntry(:key, :value) in _habitDays.entries)
        key: {for (final h in value) h == habit ? n : h},
    };
    _looks = {
      for (final MapEntry(:key, :value) in _looks.entries)
        key == habit ? n : key: value,
    };
    notifyListeners();
    await _save();
    return true;
  }

  /// Removes [habit] and its history.
  Future<void> removeHabit(String habit) async {
    _habits = [..._habits]..remove(habit);
    _looks = {..._looks}..remove(habit);
    _habitDays = {
      for (final MapEntry(:key, :value) in _habitDays.entries)
        if (value.difference({habit}) case final left when left.isNotEmpty)
          key: left,
    };
    notifyListeners();
    await _save();
  }

  /// Ticks [habit] off for [day], or unticks it.
  Future<void> toggleHabit(String habit, DateTime day) async {
    final d = dateOnly(day);
    final done = {...?_habitDays[d]};
    if (!done.remove(habit)) done.add(habit);
    _habitDays = {..._habitDays}..remove(d);
    if (done.isNotEmpty) _habitDays[d] = done;
    notifyListeners();
    await _save();
  }

  MoodEntry? on(DateTime day) => _days[dateOnly(day)];
  MoodEntry? get today => on(_health.today);

  /// Entries from the last [count] days (today included), newest first.
  List<(DateTime, MoodEntry)> recent(int count) {
    final t = _health.today;
    return [
      for (var i = 0; i < count; i++)
        if (_days[DateTime(t.year, t.month, t.day - i)] case final e?)
          (DateTime(t.year, t.month, t.day - i), e),
    ];
  }

  Future<void> load() async {
    _days = {};
    _habits = [];
    _habitDays = {};
    _looks = {};
    _readable = true;
    try {
      final doc = await _health.loadDocument(docKey);
      final days = doc?['days'];
      if (days is Map<String, Object?>) {
        _days = {
          for (final MapEntry(:key, :value) in days.entries)
            ?parseDayKey(key): ?MoodEntry.fromJson(value),
        };
      }
      if (doc?['habits'] case final List<Object?> names) {
        _habits = <String>{
          for (final n in names)
            if (n is String && n.isNotEmpty && n.length <= maxHabitName) n,
        }.toList();
      }
      if (doc?['habitDays'] case final Map<String, Object?> days) {
        _habitDays = {
          for (final MapEntry(:key, :value) in days.entries)
            if ((parseDayKey(key), value) case (
              final d?,
              final List<Object?> l,
            ))
              d: {
                for (final h in l)
                  if (h is String && _habits.contains(h)) h,
              },
        }..removeWhere((_, done) => done.isEmpty);
      }
      if (doc?['habitLooks'] case final Map<String, Object?> looks) {
        _looks = {
          for (final MapEntry(:key, :value) in looks.entries)
            if (_habits.contains(key) && value is Map<String, Object?>)
              key: (
                icon: value['icon'] is String ? value['icon'] as String : null,
                color: value['color'] is String
                    ? value['color'] as String
                    : null,
              ),
        };
      }
    } on Exception catch (e) {
      _readable = false;
      logError('Mood: could not load: $e');
    }
    notifyListeners();
  }

  /// Saves [entry] for [day] (null removes the day).
  Future<void> log(DateTime day, MoodEntry? entry) async {
    final d = dateOnly(day);
    _days = {..._days}..remove(d);
    if (entry != null) _days[d] = entry;
    notifyListeners();
    await _save();
  }

  /// Clears memory after "Erase All".
  void reset() {
    _days = {};
    _habits = [];
    _habitDays = {};
    _looks = {};
    _readable = true;
    notifyListeners();
  }

  Future<void> _save() async {
    if (!_readable) {
      logError('Mood: not saving over data that could not be read');
      return;
    }
    final t = _health.today;
    final oldest = DateTime(t.year, t.month, t.day - _keepDays);
    _days.removeWhere((d, _) => d.isBefore(oldest));
    _habitDays.removeWhere((d, _) => d.isBefore(oldest));
    await _health.saveDocument(docKey, {
      'days': {
        for (final MapEntry(:key, :value) in _days.entries)
          dayKey(key): value.toJson(),
      },
      'habits': _habits,
      'habitDays': {
        for (final MapEntry(:key, :value) in _habitDays.entries)
          dayKey(key): value.toList(),
      },
      'habitLooks': {
        for (final MapEntry(:key, :value) in _looks.entries)
          key: {'icon': ?value.icon, 'color': ?value.color},
      },
    });
  }
}
