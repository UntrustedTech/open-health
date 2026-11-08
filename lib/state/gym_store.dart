import 'package:flutter/foundation.dart';

import 'package:health_app/models/gym.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/utils/log.dart';

/// The gym membership card and the visits checked in with it. Saved
/// through the HealthStore's write queue.
class GymStore extends ChangeNotifier {
  GymStore(this._health);

  static const docKey = 'gym';

  /// Check-ins this close together are the same visit.
  static const sameVisit = Duration(hours: 2);

  /// Visits kept.
  static const _keepDays = 3 * 366;

  final HealthStore _health;

  GymMembership? _membership;
  List<DateTime> _visits = const [];
  bool _readable = true;

  GymMembership? get membership => _membership;

  /// False when the saved data couldn't be read: nothing is saved over it,
  /// so it isn't lost.
  bool get readable => _readable;

  /// Every visit, newest first.
  List<DateTime> get visits => _visits;

  DateTime? get lastVisit => _visits.firstOrNull;

  int get total => _visits.length;

  bool get checkedInToday {
    final last = lastVisit;
    final today = _health.today;
    return last != null &&
        last.year == today.year &&
        last.month == today.month &&
        last.day == today.day;
  }

  /// The Monday of the week [day] is in.
  static DateTime _weekOf(DateTime day) =>
      DateTime(day.year, day.month, day.day - (day.weekday - 1));

  int _since(DateTime from) => _visits.where((v) => !v.isBefore(from)).length;

  /// Visits since Monday.
  int get thisWeek => _since(_weekOf(_health.today));

  int get thisMonth {
    final t = _health.today;
    return _since(DateTime(t.year, t.month));
  }

  /// Weeks in a row with a visit, up to this one (or last week, while
  /// this one still has time for a visit).
  int get weekStreak {
    final weeks = {for (final v in _visits) _weekOf(v)};
    var week = _weekOf(_health.today);
    if (!weeks.contains(week)) {
      week = DateTime(week.year, week.month, week.day - 7);
    }
    var streak = 0;
    while (weeks.contains(week)) {
      streak++;
      week = DateTime(week.year, week.month, week.day - 7);
    }
    return streak;
  }

  Future<void> load() async {
    _membership = null;
    _visits = const [];
    _readable = true;
    try {
      final doc = await readDocument();
      _membership = GymMembership.fromJson(doc?['membership']);
      final visits = doc?['visits'];
      if (visits is List) {
        _visits = _sorted([
          for (final v in visits)
            if (v is String) ?DateTime.tryParse(v),
        ]);
      }
    } on Exception catch (e) {
      _readable = false;
      logError('Gym: could not load: $e');
    }
    notifyListeners();
  }

  /// The saved document. Separate so tests can stand in a damaged one.
  @protected
  Future<Map<String, Object?>?> readDocument() => _health.loadDocument(docKey);

  /// Saves [membership] (null removes it). Throws a [StateError] when the
  /// saved data couldn't be read, rather than writing over it.
  Future<void> saveMembership(GymMembership? membership) async {
    if (!_readable) throw StateError('Gym data could not be read');
    _membership = membership;
    notifyListeners();
    await _save();
  }

  /// Whether a visit was logged within [sameVisit], so checking in again
  /// now would be the same visit.
  bool get justCheckedIn {
    final last = lastVisit;
    if (last == null) return false;
    // A visit "in the future" (the clock moved back) doesn't count.
    final since = _health.now.difference(last);
    return !since.isNegative && since < sameVisit;
  }

  /// Logs a visit now, unless one was just logged (or the saved data
  /// couldn't be read). Returns whether it did.
  Future<bool> checkIn() async {
    final now = _health.now;
    if (justCheckedIn || !_readable) return false;
    _visits = _sorted([now, ..._visits]);
    notifyListeners();
    await _save();
    return true;
  }

  Future<void> removeVisit(DateTime at) async {
    _visits = [
      for (final v in _visits)
        if (v != at) v,
    ];
    notifyListeners();
    await _save();
  }

  /// Clears memory after "Erase All".
  void reset() {
    _membership = null;
    _visits = const [];
    _readable = true;
    notifyListeners();
  }

  /// Newest first, without ones older than [_keepDays].
  List<DateTime> _sorted(List<DateTime> visits) {
    final t = _health.today;
    final oldest = DateTime(t.year, t.month, t.day - _keepDays);
    return List.unmodifiable(
      visits.where((v) => !v.isBefore(oldest)).toList()
        ..sort((a, b) => b.compareTo(a)),
    );
  }

  Future<void> _save() async {
    if (!_readable) {
      logError('Gym: not saving over data that could not be read');
      return;
    }
    await _health.saveDocument(docKey, {
      'membership': ?_membership?.toJson(),
      'visits': [for (final v in _visits) v.toIso8601String()],
    });
  }
}
