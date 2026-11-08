import 'package:flutter/foundation.dart';

import 'package:health_app/models/cycle.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/utils/log.dart';

/// Cycle tracking: logged days and the forecast made from them. Off until
/// the user turns it on. Saved through the HealthStore's write queue.
class CycleStore extends ChangeNotifier {
  CycleStore(this._health);

  static const docKey = 'cycle';

  final HealthStore _health;

  bool _enabled = false;
  Map<DateTime, CycleDay> _days = {};
  CycleForecast? _forecast;

  /// The day [_forecast] was worked out for; a new day needs a new one.
  DateTime? _forecastDay;

  /// False when stored data couldn't be read; saving is skipped then.
  bool _readable = true;

  bool get enabled => _enabled;
  Map<DateTime, CycleDay> get days => Map.unmodifiable(_days);

  CycleForecast get forecast {
    final today = _health.today;
    if (_forecast == null || _forecastDay != today) {
      _forecast = CycleForecast.from(_days, today);
      _forecastDay = today;
    }
    return _forecast!;
  }

  CycleDay dayOf(DateTime day) => _days[dateOnly(day)] ?? const CycleDay();

  Future<void> load() async {
    _enabled = false;
    _days = {};
    _readable = true;
    try {
      final doc = await _health.loadDocument(docKey);
      if (doc != null) {
        _enabled = doc['enabled'] == true;
        final days = doc['days'];
        if (days is Map<String, Object?>) {
          _days = {
            for (final MapEntry(:key, :value) in days.entries)
              ?parseDayKey(key): CycleDay.fromJson(value),
          }..removeWhere((_, v) => v.isEmpty);
        }
      }
    } on Exception catch (e) {
      _readable = false;
      logError('Cycle: could not load: $e');
    }
    _changed();
  }

  /// Clears memory after "Erase All".
  void reset() {
    _enabled = false;
    _days = {};
    _readable = true;
    _changed();
  }

  Future<void> setEnabled(bool on) async {
    _enabled = on;
    _changed();
    await _save();
  }

  /// Saves what was logged for [day] (an empty day removes it).
  Future<void> log(DateTime day, CycleDay value) async {
    final d = dateOnly(day);
    _days = {..._days}..remove(d);
    if (!value.isEmpty) _days[d] = value;
    _changed();
    await _save();
  }

  /// Logs the first day of a period ("My period started").
  Future<void> startPeriod(
    DateTime start, {
    PeriodFlow flow = PeriodFlow.medium,
  }) async {
    final d = dateOnly(start);
    final next = {..._days};
    final existing = next[d];
    next[d] = CycleDay(flow: flow, symptoms: existing?.symptoms ?? const {});
    _days = next;
    _changed();
    await _save();
  }

  /// Adds imported period days. Days that already have a flow logged here
  /// are left alone; returns how many days were added.
  Future<int> importDays(Map<DateTime, PeriodFlow> flows) async {
    final next = {..._days};
    var added = 0;
    for (final MapEntry(key: day, value: flow) in flows.entries) {
      final d = dateOnly(day);
      final had = next[d];
      if (had?.flow != null) continue;
      next[d] = CycleDay(flow: flow, symptoms: had?.symptoms ?? const {});
      added++;
    }
    if (added == 0) return 0;
    _days = next;
    _changed();
    await _save();
    return added;
  }

  void _changed() {
    _forecast = null;
    notifyListeners();
  }

  Future<void> _save() async {
    if (!_readable) {
      logError('Cycle: not saving over data that could not be read');
      return;
    }
    await _health.saveDocument(docKey, {
      'enabled': _enabled,
      'days': {
        for (final MapEntry(:key, :value) in _days.entries)
          dayKey(key): value.toJson(),
      },
    });
  }
}
