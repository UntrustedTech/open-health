import 'package:flutter/foundation.dart';

import 'package:health_app/models/fasting.dart';
import 'package:health_app/notifications/notifier.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/utils/log.dart';

/// The fasting timer: the running fast (if any), the chosen preset and
/// past fasts. Schedules a notification for when the goal is reached.
class FastingStore extends ChangeNotifier {
  FastingStore(this._health, this._notifier);

  static const docKey = 'fasting';

  /// Past fasts kept.
  static const _keepFasts = 400;

  /// Fasts longer than this are treated as forgotten timers.
  static const maxFast = Duration(hours: 72);

  final HealthStore _health;
  final Notifier _notifier;

  FastingPreset _preset = FastingPreset.sixteen;
  DateTime? _started;
  List<FastRecord> _history = [];
  bool _readable = true;

  FastingPreset get preset => _preset;

  /// When the running fast began, or null.
  DateTime? get started => _started;
  bool get isFasting => _started != null;
  List<FastRecord> get history => List.unmodifiable(_history);

  Duration get goal => _preset.duration;

  /// How long the running fast has lasted.
  /// Never negative, even if the clock is set back after it starts.
  Duration elapsed(DateTime now) => switch (_started) {
    final s? when now.isAfter(s) => now.difference(s),
    _ => Duration.zero,
  };

  int get streak => fastingStreak(_history, _health.today);

  Future<void> load() async {
    _preset = FastingPreset.sixteen;
    _started = null;
    _history = [];
    _readable = true;
    try {
      final doc = await _health.loadDocument(docKey);
      if (doc != null) {
        _preset = FastingPreset.fromName(doc['preset']);
        final s = DateTime.tryParse('${doc['started']}');
        final now = _health.now;
        // A start a little ahead of now comes from the clock or time zone
        // changing (e.g. flying west): keep the fast, from now. One far in
        // the future, or long ago, is a broken or forgotten timer.
        if (s != null && now.difference(s) <= maxFast) {
          if (!s.isAfter(now)) {
            _started = s;
          } else if (s.difference(now) <= const Duration(hours: 14)) {
            _started = now;
          }
        }
        final h = doc['history'];
        if (h is List) {
          _history = h.map(FastRecord.fromJson).nonNulls.toList()
            ..sort((a, b) => b.end.compareTo(a.end));
        }
      }
    } on Exception catch (e) {
      _readable = false;
      logError('Fasting: could not load: $e');
    }
    notifyListeners();
  }

  /// Schedules (or cancels) the end-of-fast notification for the loaded
  /// state, e.g. after launch or a restore.
  Future<void> reschedule() => _schedule();

  Future<void> setPreset(FastingPreset preset) async {
    _preset = preset;
    notifyListeners();
    // Saved first, so a stuck notification call can't hold up the save.
    await _save();
    await _schedule();
  }

  /// Starts a fast at [at] (now by default; earlier if the last meal was
  /// earlier).
  Future<void> start({DateTime? at}) async {
    final now = _health.now;
    final s = at == null || at.isAfter(now) ? now : at;
    _started = now.difference(s) > maxFast ? now.subtract(maxFast) : s;
    notifyListeners();
    // Saved first, so a stuck notification call can't hold up the save.
    await _save();
    await _schedule();
  }

  /// Ends the running fast and records it.
  Future<FastRecord?> end() async {
    final s = _started;
    if (s == null) return null;
    final now = _health.now;
    _started = null;
    FastRecord? record;
    if (now.isAfter(s)) {
      record = FastRecord(start: s, end: now, goal: goal);
      _history = [record, ..._history].take(_keepFasts).toList();
    }
    notifyListeners();
    await _save();
    await _schedule();
    return record;
  }

  /// Clears memory after "Erase All".
  Future<void> reset() async {
    _preset = FastingPreset.sixteen;
    _started = null;
    _history = [];
    _readable = true;
    notifyListeners();
    await _notifier.cancel(NotificationIds.fastingDone);
    await _notifier.cancel(NotificationIds.fastingLive);
  }

  Future<void> _schedule() async {
    final s = _started;
    try {
      final at = s?.add(goal);
      if (at == null || !at.isAfter(_health.now)) {
        await _notifier.cancel(NotificationIds.fastingDone);
        await _notifier.cancel(NotificationIds.fastingLive);
        return;
      }
      await _notifier.scheduleOnce(
        NotificationIds.fastingDone,
        at,
        'Fast Complete',
        'You reached your ${_preset.label} goal.',
      );
      await _notifier.showFasting(at);
    } on Exception catch (e) {
      logError('Fasting: could not schedule: $e');
    }
  }

  Future<void> _save() async {
    if (!_readable) {
      logError('Fasting: not saving over data that could not be read');
      return;
    }
    await _health.saveDocument(docKey, {
      'preset': _preset.name,
      if (_started case final s?) 'started': s.toIso8601String(),
      'history': [for (final f in _history) f.toJson()],
    });
  }
}
