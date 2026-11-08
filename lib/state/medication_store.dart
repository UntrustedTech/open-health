import 'package:flutter/foundation.dart';

import 'package:health_app/app_edition.dart';
import 'package:health_app/models/medication.dart';
import 'package:health_app/notifications/notifier.dart';
import 'package:health_app/notifications/reminder_plan.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/utils/log.dart';

/// Medications, their schedules and the record of doses taken. Saved
/// through the HealthStore's ordered write queue.
class MedicationStore extends ChangeNotifier {
  MedicationStore(this._health, this._notifier);

  static const docKey = 'medications';

  /// Dose history is kept this long.
  static const _keepDays = 400;

  final HealthStore _health;
  final Notifier _notifier;

  List<Medication> _meds = [];
  List<DoseLog> _log = [];
  int _idCounter = 0;

  /// False when stored data couldn't be read: nothing is saved then, so
  /// the stored copy isn't overwritten by an empty list.
  bool _readable = true;

  /// Active medications first, by name.
  List<Medication> get all => List.unmodifiable(_meds);
  List<Medication> get active => _meds.where((m) => !m.archived).toList();
  bool get isEmpty => active.isEmpty;
  List<DoseLog> get log => List.unmodifiable(_log);

  Medication? byId(String id) => _meds.where((m) => m.id == id).firstOrNull;

  Future<void> load() async {
    _meds = [];
    _log = [];
    _readable = true;
    try {
      final doc = await _health.loadDocument(docKey);
      final items = doc?['items'];
      if (items is List) {
        _meds = items.map(Medication.tryFromJson).nonNulls.toList();
      }
      final log = doc?['log'];
      if (log is List) _log = log.map(DoseLog.tryFromJson).nonNulls.toList();
    } on Exception catch (e) {
      _readable = false;
      logError('Medications: could not load: $e');
    }
    _sort();
    notifyListeners();
  }

  /// Clears memory after "Erase All".
  Future<void> reset() async {
    _meds = [];
    _log = [];
    _readable = true;
    notifyListeners();
    await reschedule();
  }

  String newId() => 'm${_health.now.microsecondsSinceEpoch}${_idCounter++}';

  /// Adds or replaces a medication. Turning on its first reminder asks for
  /// notification permission; returns false if refused (it's saved anyway).
  Future<bool> save(Medication input) async {
    // Doses before a medication was added aren't "missed".
    final med = input.created == null
        ? input.copyWith(created: byId(input.id)?.created ?? _health.now)
        : input;
    final hadReminders = _meds.any((m) => _reminds(m));
    _meds = [med, ..._meds.where((m) => m.id != med.id)];
    _sort();
    notifyListeners();
    await _save();
    var allowed = true;
    if (!hadReminders && _reminds(med)) {
      allowed = await _notifier.requestPermission();
    }
    await reschedule();
    return allowed;
  }

  /// Deletes a medication and its history.
  Future<void> delete(String id) async {
    _meds = _meds.where((m) => m.id != id).toList();
    _log = _log.where((l) => l.medId != id).toList();
    notifyListeners();
    await _save();
    await reschedule();
  }

  /// Today's (or [day]'s) scheduled doses, in time order.
  List<DoseSlot> slotsOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final slots = <DoseSlot>[
      for (final m in _meds)
        if (m.takenOn(d))
          for (final t in m.times)
            (
              med: m,
              time: DateTime(d.year, d.month, d.day, t ~/ 60, t % 60),
              log: null,
            ),
    ];
    return [
      for (final s in slots..sort((a, b) => a.time.compareTo(b.time)))
        (
          med: s.med,
          time: s.time,
          log: _log
              .where((l) => l.medId == s.med.id && l.scheduled == s.time)
              .lastOrNull,
        ),
    ];
  }

  /// As-needed doses logged on [day].
  List<DoseLog> extraOn(DateTime day) => [
    for (final l in _log)
      if (l.scheduled == null &&
          l.at.year == day.year &&
          l.at.month == day.month &&
          l.at.day == day.day)
        l,
  ];

  /// Records a scheduled dose (replacing an earlier answer), or an
  /// as-needed one when [slot] is null.
  Future<void> record(
    Medication med,
    DoseStatus status, {
    DateTime? slot,
  }) async {
    _log = [
      for (final l in _log)
        if (slot == null || !(l.medId == med.id && l.scheduled == slot)) l,
      DoseLog(medId: med.id, at: _health.now, status: status, scheduled: slot),
    ];
    notifyListeners();
    await _save();
  }

  /// Clears the answer for a scheduled dose.
  Future<void> undo(Medication med, DateTime slot) async {
    _log = _log
        .where((l) => !(l.medId == med.id && l.scheduled == slot))
        .toList();
    notifyListeners();
    await _save();
  }

  /// Share of scheduled doses taken over the last [days] days (excluding
  /// doses still to come today). Null when nothing was scheduled.
  double? adherence({int days = 30}) {
    final now = _health.now;
    var due = 0, taken = 0;
    for (var i = 0; i < days; i++) {
      final day = DateTime(now.year, now.month, now.day - i);
      for (final s in slotsOn(day)) {
        if (s.time.isAfter(now)) continue;
        // Doses due before it was added weren't missed.
        if (s.med.created case final c? when s.time.isBefore(c)) continue;
        due++;
        if (s.log?.status == DoseStatus.taken) taken++;
      }
    }
    return due == 0 ? null : taken / due;
  }

  bool _reminds(Medication m) => m.reminders && !m.archived && !m.asNeeded;

  /// True when reminders couldn't be set up last time; the Medications
  /// screen says so, as a missed dose matters.
  bool get remindersFailed => _remindersFailed;
  bool _remindersFailed = false;

  /// Re-plans medication reminders.
  Future<void> reschedule() async {
    var failed = false;
    try {
      await _notifier.replaceMedicationReminders(
        // The store version has no Medications screen to stop them.
        planMedicationReminders(
          kStoreEdition ? const [] : _meds,
          now: _health.now,
        ),
      );
    } on Exception catch (e) {
      logError('Medications: scheduling failed: $e');
      failed = true;
    }
    if (failed != _remindersFailed) {
      _remindersFailed = failed;
      notifyListeners();
    }
  }

  void _sort() => _meds.sort((a, b) {
    if (a.archived != b.archived) return a.archived ? 1 : -1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  Future<void> _save() async {
    if (!_readable) {
      logError('Medications: not saving over data that could not be read');
      return;
    }
    final now = _health.now;
    final oldest = DateTime(now.year, now.month, now.day - _keepDays);
    _log = _log.where((l) => l.at.isAfter(oldest)).toList();
    await _health.saveDocument(docKey, {
      'items': [for (final m in _meds) m.toJson()],
      'log': [for (final l in _log) l.toJson()],
    });
  }
}

/// Reminders for every scheduled dose: daily, or weekly on chosen days.
/// The channel's private visibility hides them on a locked screen.
List<PlannedReminder> planMedicationReminders(
  List<Medication> meds, {
  required DateTime now,
}) {
  DateTime next(DoseTime t, {int? weekday}) {
    var d = DateTime(now.year, now.month, now.day, t ~/ 60, t % 60);
    while ((weekday != null && d.weekday != weekday) || !d.isAfter(now)) {
      d = DateTime(d.year, d.month, d.day + 1, t ~/ 60, t % 60);
    }
    return d;
  }

  final out = <PlannedReminder>[];
  var id = medicationReminderIds.start;
  for (final m in meds) {
    if (!m.reminders || m.archived || m.asNeeded) continue;
    final title = 'Time for ${m.name}';
    final body = m.dose.isEmpty
        ? 'Tap to log it in Health.'
        : 'Take ${m.dose}. Tap to log it in Health.';
    final everyDay = m.days.isEmpty || m.days.length == 7;
    for (final t in m.times) {
      for (final day in everyDay ? const <int?>[null] : ([...m.days]..sort())) {
        if (id >= medicationReminderIds.end) return out;
        out.add(
          PlannedReminder(
            id: id++,
            kind: ReminderKind.medication,
            first: next(t, weekday: day),
            repeat: everyDay ? Repeat.daily : Repeat.weekly,
            title: title,
            body: body,
          ),
        );
      }
    }
  }
  return out;
}
