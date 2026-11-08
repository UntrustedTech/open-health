import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:health_app/utils/log.dart';
import 'package:health_app/data/health_repository.dart';
import 'package:health_app/models/health_entry.dart';
import 'package:health_app/insights/heart_zones.dart';
import 'package:health_app/models/cycle.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/sync/background_scheduler.dart';
import 'package:health_app/sync/daily_import.dart';
import 'package:health_app/sync/health_sample.dart';
import 'package:health_app/sync/health_source.dart';

/// What started a sync, for the Recent Access log.
enum SyncTrigger {
  connect('Connected'),
  launch('Opened the app'),
  resume('Returned to the app'),
  manual('Sync Now'),
  periodic('While the app was open'),
  background('Background check');

  const SyncTrigger(this.label);

  final String label;

  static SyncTrigger fromName(Object? name) =>
      values.firstWhere((t) => t.name == name, orElse: () => manual);
}

/// One time the app read the health platform.
@immutable
class SyncRecord {
  const SyncRecord({
    required this.at,
    required this.trigger,
    required this.readings,
    required this.ok,
    this.error,
  });

  final DateTime at;
  final SyncTrigger trigger;

  /// Days of data imported (one per metric per day).
  final int readings;
  final bool ok;
  final String? error;

  Map<String, Object?> toJson() => {
    'at': at.toIso8601String(),
    'trigger': trigger.name,
    'readings': readings,
    'ok': ok,
    'error': ?error,
  };

  static SyncRecord? fromJson(Object? json) {
    if (json is! Map) return null;
    final at = json['at'] is String
        ? DateTime.tryParse(json['at'] as String)
        : null;
    if (at == null) return null;
    return SyncRecord(
      at: at,
      trigger: SyncTrigger.fromName(json['trigger']),
      readings: json['readings'] is int ? json['readings'] as int : 0,
      ok: json['ok'] != false,
      error: json['error'] is String ? json['error'] as String : null,
    );
  }
}

/// Connects to the phone's health platform and keeps imported data current.
///
/// The first sync imports up to a year of history (30 days if the user
/// doesn't allow history). Later syncs re-read the last week, because watches
/// and apps such as Samsung Health often sync their data late.
class HealthSyncService extends ChangeNotifier {
  HealthSyncService({
    required this._source,
    required this._store,
    required this._repo,
    this._workouts,
    this._scheduler = const NoBackgroundScheduler(),
    Clock? clock,
  }) : _clock = clock ?? DateTime.now;

  static const _docKey = 'sync';
  static const historyDays = 365;
  static const recentDays = 30;

  /// How often the app checks for new data while it's open, by default,
  /// and the choices.
  static const whileOpen = Duration(minutes: 1);
  static const openIntervals = [
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
    Duration(minutes: 30),
  ];

  /// Timers fire a little early: a check this close to due counts as due.
  static const _pollSlack = Duration(seconds: 5);
  static const resyncDays = 7;

  /// What the frequent checks (while open, in the background) re-read:
  /// since the last sync plus a day, so they stay light.
  static const quickResyncDays = 1;

  /// Automatic syncs (on opening or returning to the app) run at most this
  /// often. Short, so data just added in Health Connect shows up when you
  /// come back to the app; it only guards against back-to-back syncs.
  static const minInterval = Duration(minutes: 1);

  /// How often background checks can be set to run. Android runs periodic
  /// work at most every 15 minutes.
  static const intervals = [
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 6),
    Duration(hours: 12),
  ];
  static const defaultInterval = Duration(minutes: 15);

  /// Syncs kept in the Recent Access log.
  static const recentLimit = 30;

  final BackgroundScheduler _scheduler;
  bool _syncOnOpen = true;
  bool _backgroundSync = false;
  Duration _backgroundInterval = defaultInterval;
  Duration _openInterval = whileOpen;
  List<SyncRecord> _recent = const [];

  final HealthSource _source;
  final HealthStore _store;
  final HealthRepository _repo;

  /// Receives workouts recorded by other apps, when provided.
  final WorkoutStore? _workouts;
  final Clock _clock;

  SourceStatus? _status;
  bool _connected = false;
  bool _historyAllowed = false;
  DateTime? _lastSync;
  Set<MetricType> _granted = {};
  double? _progress;
  String? _error;
  Future<void>? _running;

  /// Types whose full history has been imported since connecting.
  Set<MetricType> _backfilled = {};

  /// Bumped on disconnect so a sync that was already running discards its
  /// results instead of writing them back.
  int _generation = 0;

  /// Heart rate bands read during the current sync.
  Map<DateTime, List<double>> _bins = {};

  /// The newest reading of each averaged metric in this sync.
  Map<MetricType, LiveReading> _newest = {};

  /// When the last sync began, so failing syncs are retried at most every
  /// [minInterval] rather than on every app resume.
  DateTime? _lastAttempt;

  String get sourceName => _source.name;
  Set<MetricType> get supportedTypes => _source.supportedTypes;

  /// Null until [init] has checked the platform.
  SourceStatus? get status => _status;
  bool get connected => _connected;
  bool get historyAllowed => _historyAllowed;
  DateTime? get lastSync => _lastSync;
  Set<MetricType> get granted => Set.unmodifiable(_granted);
  bool get syncing => _running != null;

  /// 0..1 while syncing, otherwise null.
  double? get progress => _progress;

  /// User-facing description of the last problem, if any.
  String? get error => _error;

  /// Whether opening (or returning to) the app syncs on its own.
  bool get syncOnOpen => _syncOnOpen;

  /// Whether the app checks for new data in the background, and how often.
  bool get backgroundSync => _backgroundSync;
  Duration get backgroundInterval => _backgroundInterval;

  /// How often the app checks for new data while it's open.
  Duration get openInterval => _openInterval;

  Future<void> setOpenInterval(Duration every) async {
    _openInterval = every;
    notifyListeners();
    await _saveDoc();
  }

  /// Recent syncs, newest first.
  List<SyncRecord> get recentAccess => _recent;

  Future<void> setSyncOnOpen(bool on) async {
    _syncOnOpen = on;
    notifyListeners();
    await _saveDoc();
  }

  /// A problem with a setting or with opening the platform's screens,
  /// shown by the setting (sync problems are in [error]).
  String? get settingsError => _settingsError;
  String? _settingsError;

  /// Turns background checks on or off. Turning them on asks the platform
  /// for background access; returns false if that isn't allowed.
  Future<bool> setBackgroundSync(bool on) async {
    _settingsError = null;
    if (on) {
      BackgroundAccess access;
      try {
        access = await _source.requestBackgroundAccess();
        // The plugin throws Errors too (e.g. when Health Connect is
        // missing); they must not escape sync, disconnect or erase.
        // ignore: avoid_catches_without_on_clauses
      } catch (e) {
        logError('HealthSync: background permission failed: $e');
        access = BackgroundAccess.denied;
      }
      if (access != BackgroundAccess.allowed) {
        _settingsError = access == BackgroundAccess.unavailable
            ? "This phone's $sourceName doesn't support reading data in the "
                  'background. Updating $sourceName may add it.'
            : "$sourceName didn't allow reading data in the background. You "
                  'can allow it in Manage Permissions, then try again.';
        notifyListeners();
        return false;
      }
    }
    _backgroundSync = on;
    notifyListeners();
    await _applySchedule();
    await _saveDoc();
    return true;
  }

  Future<void> setBackgroundInterval(Duration every) async {
    _backgroundInterval = every;
    notifyListeners();
    await _applySchedule();
    await _saveDoc();
  }

  /// Matches the system's schedule to the setting. [replace] restarts the
  /// timing (for a changed setting) rather than keeping it.
  Future<void> _applySchedule({bool replace = true}) async {
    try {
      if (_connected && _backgroundSync) {
        await _scheduler.schedule(_backgroundInterval, replace: replace);
      } else {
        await _scheduler.cancel();
      }
      // The plugin throws Errors too (e.g. when Health Connect is
      // missing); they must not escape sync, disconnect or erase.
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      logError('HealthSync: scheduling background sync failed: $e');
    }
  }

  /// Every reading of [type] from [from] to [to], straight from the source
  /// and not saved. Empty when it isn't connected or [type] isn't shared.
  Future<List<HealthSample>> readAll(
    MetricType type,
    DateTime from,
    DateTime to,
  ) async {
    if (!_connected || !_granted.contains(type)) return const [];
    return _source.read(type, from, to);
  }

  /// Opens the platform's page of this app's permissions; what's shared is
  /// checked again on returning to the app.
  Future<void> openPermissionSettings() async {
    // Apple Health asks only once; until it has, its sheet is the way in
    // (the Health app has nothing to change yet).
    if (await needsAccessRequest()) {
      await connect();
      return;
    }
    await _openScreen(_source.openPermissionSettings, 'permissions');
  }

  /// Whether $sourceName has yet to ask the user what Health may read.
  /// When it can't say, the answer is yes: asking then fails with the
  /// reason, which is shown.
  Future<bool> needsAccessRequest() async {
    try {
      return await _source.needsAccessRequest();
      // The plugin throws Errors too; they must not escape.
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      logError('HealthSync: permission status failed: $e');
      return true;
    }
  }

  /// Opens the platform's own settings (data, app access, recent access).
  Future<void> openDataSettings() =>
      _openScreen(_source.openDataSettings, 'settings');

  Future<void> _openScreen(Future<void> Function() open, String what) async {
    try {
      await open();
      // The plugin throws Errors too (e.g. when Health Connect is
      // missing); they must not escape sync, disconnect or erase.
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      logError('HealthSync: could not open $what: $e');
      _settingsError = "Couldn't open $sourceName. Please try again.";
      notifyListeners();
    }
  }

  /// Checks again what's shared (e.g. after the user changed it in the
  /// platform's settings), without syncing.
  Future<void> refreshPermissions() async {
    if (!_connected) return;
    _granted = await _safeGranted();
    // Background access can be removed in the platform's settings; then
    // background checks would only fail, so they stop.
    if (_backgroundSync && !await _backgroundAllowed()) {
      _backgroundSync = false;
      _settingsError =
          'Background Sync was turned off because $sourceName no longer '
          'allows reading data in the background.';
      await _applySchedule();
      await _saveDoc();
    }
    notifyListeners();
  }

  Future<bool> _backgroundAllowed() async {
    try {
      return await _source.hasBackgroundAccess();
      // The plugin throws Errors too (e.g. when Health Connect is
      // missing); they must not escape sync, disconnect or erase.
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      // Unknown isn't "no": leave the setting alone.
      logError('HealthSync: background check failed: $e');
      return true;
    }
  }

  /// Re-reads the saved sync state, e.g. after a background check saved
  /// newer state while the app was in the background.
  Future<void> reload() async {
    await _loadDoc('reload');
    notifyListeners();
  }

  Future<void> _loadDoc(String verb) async {
    try {
      final doc = await _repo.loadDocument(_docKey);
      if (doc != null) _applyDoc(doc);
      // The plugin throws Errors too (e.g. when Health Connect is
      // missing); they must not escape sync, disconnect or erase.
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      logError('HealthSync: could not $verb sync state: $e');
    }
  }

  /// A sync started by opening or returning to the app; skipped when the
  /// user turned that off.
  Future<void> autoSync(SyncTrigger trigger) =>
      _syncOnOpen ? sync(trigger: trigger) : Future.value();

  /// Called every minute while the app is open: syncs once
  /// [openInterval] has passed since the last sync.
  Future<void> pollWhileOpen() {
    final last = _lastAttempt ?? _lastSync;
    if (last != null &&
        _clock().difference(last) < _openInterval - _pollSlack) {
      return Future.value();
    }
    return _syncOnOpen
        ? sync(trigger: SyncTrigger.periodic, force: true)
        : Future.value();
  }

  /// Loads the saved state and checks the platform. [schedule] keeps the
  /// system's background schedule matching the setting (off inside a
  /// background check, which is itself the schedule running).
  Future<void> init({bool schedule = true}) async {
    await _loadDoc('load');
    await refreshStatus();
    if (_connected) {
      _granted = await _safeGranted();
      notifyListeners();
    }
    // Keeps the system's schedule matching the setting (e.g. after an
    // app update or a restored backup) without restarting its timing.
    if (schedule) await _applySchedule(replace: false);
  }

  /// Re-checks whether the platform is installed (e.g. after returning from
  /// the Play Store).
  Future<void> refreshStatus() async {
    try {
      _status = await _source.status();
      // The plugin throws Errors too (e.g. when Health Connect is
      // missing); they must not escape sync, disconnect or erase.
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      logError('HealthSync: status check failed: $e');
      _status = SourceStatus.unsupported;
    }
    notifyListeners();
  }

  Future<void> openInstallPage() => _source.openInstallPage();

  /// Asks for permission, then imports history. Returns false if the user
  /// allowed nothing or the platform isn't ready.
  Future<bool> connect() async {
    _error = null;
    try {
      _granted = await _source.requestAccess();
      if (_granted.isEmpty) {
        _error =
            'No data was shared. Allow at least one type of data to '
            'connect $sourceName.';
        notifyListeners();
        return false;
      }
      _historyAllowed = await _source.requestHistoryAccess();
      // The plugin also throws errors (not exceptions) when Health
      // Connect is missing; those mustn't leave the button spinning.
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      logError('HealthSync: permission request failed: $e');
      _error = "Couldn't open $sourceName permissions. Please try again.";
      notifyListeners();
      return false;
    }
    _connected = true;
    _lastSync = null;
    _backfilled = {};
    notifyListeners();
    await _saveDoc();
    // The import continues in the background; progress shows in the UI.
    unawaited(sync(force: true, trigger: SyncTrigger.connect));
    // New readings keep coming while the app is closed, if allowed; if
    // not, the setting says why.
    if (!_backgroundSync) await setBackgroundSync(true);
    return true;
  }

  /// The profile details $sourceName keeps (asking to read them first), or
  /// null if they couldn't be read.
  Future<ProfileFacts?> readProfile() async {
    try {
      return await _source.readProfile();
      // The plugin throws errors (not exceptions) when Health Connect is
      // missing; the caller only needs to know nothing was read.
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      logError('HealthSync: reading the profile failed: $e');
      return null;
    }
  }

  /// Period days $sourceName has from the last two years (asking to read
  /// them first), or null if they couldn't be read.
  Future<Map<DateTime, PeriodFlow>?> readPeriodDays(DateTime today) async {
    try {
      return await _source.readPeriodDays(
        DateTime(today.year - 2, today.month, today.day),
        today.add(const Duration(days: 1)),
      );
      // As in [readProfile]: the plugin throws errors, not exceptions.
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      logError('HealthSync: reading periods failed: $e');
      return null;
    }
  }

  /// Re-opens the permission screen so the user can change what is shared.
  Future<void> changePermissions() async {
    try {
      _granted = await _source.requestAccess();
      // The plugin throws Errors too (e.g. when Health Connect is
      // missing); they must not escape sync, disconnect or erase.
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      logError('HealthSync: permission request failed: $e');
    }
    notifyListeners();
    unawaited(sync(force: true));
  }

  /// Imports new data. Automatic calls are skipped if a sync ran within
  /// [minInterval]; calls made while a sync is running share that sync.
  ///
  /// [canSave] is asked just before anything is saved; when it says no
  /// (e.g. the app opened during a background check) the results are
  /// dropped.
  Future<void> sync({
    bool force = false,
    SyncTrigger trigger = SyncTrigger.manual,
    Future<bool> Function()? canSave,
  }) {
    if (!_connected) return Future.value();
    final running = _running;
    if (running != null) return running;
    final last = _lastAttempt ?? _lastSync;
    if (!force && last != null && _clock().difference(last) < minInterval) {
      return Future.value();
    }
    final run = _runSync(trigger, canSave).whenComplete(() {
      _running = null;
      _progress = null;
      notifyListeners();
    });
    _running = run;
    return run;
  }

  /// Withdraws the app's access to ${'$'}sourceName without disconnecting
  /// (Erase All Data, when not connected: access may still be granted).
  Future<void> revokeAccess() async {
    try {
      await _source.revokeAccess();
      // The plugin throws Errors too; see [disconnect].
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      logError('HealthSync: revoke failed: $e');
    }
  }

  /// Stops syncing, removes imported data and withdraws permissions.
  Future<void> disconnect() async {
    // Stop new syncs at once and make a running one discard its results.
    _connected = false;
    _generation++;
    notifyListeners();
    await _running;
    try {
      await _source.revokeAccess();
      // The plugin throws Errors too (e.g. when Health Connect is
      // missing); they must not escape sync, disconnect or erase.
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      logError('HealthSync: revoke failed: $e');
    }
    _lastSync = null;
    _lastAttempt = null;
    _granted = {};
    _backfilled = {};
    _error = null;
    _settingsError = null;
    _backgroundSync = false;
    _recent = const [];
    notifyListeners();
    await _applySchedule();
    await _workouts?.removeImported();
    await _store.removeImported();
    await _store.clearImportedHeartBins();
    await _saveDoc();
  }

  Future<void> _runSync(
    SyncTrigger trigger,
    Future<bool> Function()? canSave,
  ) async {
    final generation = _generation;
    final now = _clock();
    _lastAttempt = now;
    _error = null;
    _progress = 0;
    _readings = 0;
    _dropped = false;
    notifyListeners();
    try {
      // Nothing can be read, and nothing would say why.
      if (await _source.needsAccessRequest()) {
        _error =
            "$sourceName hasn't been allowed yet. Tap Manage Permissions "
            'to choose what Health can read.';
      } else {
        await _importAll(
          now,
          generation,
          background: trigger == SyncTrigger.background,
          quick:
              trigger == SyncTrigger.background ||
              trigger == SyncTrigger.periodic,
          canSave: canSave,
        );
      }
      // The plugin throws Errors too (e.g. when Health Connect is
      // missing); they must not escape sync, disconnect or erase.
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      logError('HealthSync: sync failed: $e');
      if (generation == _generation) {
        _error = "Couldn't sync with $sourceName. Tap Sync Now to try again.";
      }
    }
    if (generation != _generation || _dropped) return;
    _recent = List.unmodifiable([
      SyncRecord(
        at: now,
        trigger: trigger,
        readings: _readings,
        ok: _error == null,
        error: _error,
      ),
      ..._recent.take(recentLimit - 1),
    ]);
    notifyListeners();
    await _saveDoc();
  }

  /// Daily readings the current sync added or changed.
  int _readings = 0;

  /// Whether the current sync's results were dropped (see `canSave`).
  bool _dropped = false;

  Future<void> _importAll(
    DateTime now,
    int generation, {
    required bool background,
    bool quick = false,
    Future<bool> Function()? canSave,
  }) async {
    _grantsChecked = false;
    _granted = await _safeGranted();
    // A background check only refreshes types already imported: a full
    // history import could outlast the time Android gives it, so that's
    // left to the app.
    final types = _granted
        .intersection(_source.supportedTypes)
        .where((t) => !background || _backfilled.contains(t))
        .toList();
    final imported = <DateTime, List<HealthEntry>>{};
    final importedWorkouts = <(DateTime, List<WorkoutSession>)>[];
    final succeeded = <DateTime, Set<MetricType>>{};
    final failed = <MetricType>[];
    _bins = {};
    _newest = {};

    for (var i = 0; i < types.length; i++) {
      final type = types[i];
      final from = _windowStart(
        now,
        type,
        background: background,
        quick: quick,
      );
      try {
        final entries = await _readType(type, from, now);
        // Workouts arrive with exercise minutes (same permission).
        final workouts = _workouts;
        if (type == MetricType.exerciseMinutes && workouts != null) {
          importedWorkouts.add((from, await _source.readWorkouts(from, now)));
        }
        imported.putIfAbsent(from, () => []).addAll(entries);
        succeeded.putIfAbsent(from, () => {}).add(type);
        // The plugin throws Errors too (e.g. when Health Connect is
        // missing); they must not escape sync, disconnect or erase.
        // ignore: avoid_catches_without_on_clauses
      } catch (e) {
        logError('HealthSync: reading ${type.name} failed: $e');
        failed.add(type);
      }
      _progress = (i + 1) / types.length;
      notifyListeners();
    }

    // Disconnected meanwhile, or no longer safe to save: drop the results.
    // Asked again before every write, as the app may open between them
    // (it then reloads what was saved so far).
    Future<bool> mayWrite() async {
      if (generation != _generation) return false;
      if (canSave != null && !await canSave()) {
        _dropped = true;
        return false;
      }
      return true;
    }

    if (!await mayWrite()) return;
    for (final (from, list) in importedWorkouts) {
      await _workouts?.replaceImported(from, list);
    }
    // Only readings that are new or changed count as new.
    final stored = {for (final e in _store.allEntries) e.id: e.value};
    _readings = imported.values
        .expand((list) => list)
        .where((e) => stored[e.id] != e.value)
        .length;
    if (!await mayWrite()) return;
    await _store.mergeHeartBins(_bins);
    await _store.setLiveReadings(_newest);

    for (final MapEntry(key: from, value: done) in succeeded.entries) {
      if (!await mayWrite()) return;
      await _store.replaceImported(
        from: from,
        types: done,
        entries: imported[from] ?? const [],
      );
      _backfilled.addAll(done);
    }
    // Data for types the user no longer shares is removed, but only on a
    // definite answer: a failed permission check must never wipe data.
    final revoked = _grantsChecked
        ? _source.supportedTypes.difference(_granted)
        : const <MetricType>{};
    if (revoked.isNotEmpty) {
      if (!await mayWrite()) return;
      await _store.replaceImported(
        from: DateTime(1970),
        types: revoked,
        entries: const [],
      );
      _backfilled.removeAll(revoked);
      if (revoked.contains(MetricType.exerciseMinutes)) {
        await _workouts?.removeImported();
      }
      if (revoked.contains(MetricType.heartRate)) {
        await _store.clearImportedHeartBins();
        await _store.removeEstimates();
      }
      await _store.clearLiveReadings(revoked);
    }
    if (failed.isEmpty) {
      _lastSync = now;
    } else {
      final names = failed.map((t) => t.label).join(', ');
      _error =
          "Couldn't read $names from $sourceName. Tap Sync Now to try "
          'again.';
    }
    if (!await mayWrite()) return;
    await _saveDoc();
  }

  /// Types imported before re-read the last week (a day for [quick]
  /// checks), plus any days since the last sync; new types get their full
  /// history.
  DateTime _windowStart(
    DateTime now,
    MetricType type, {
    bool background = false,
    bool quick = false,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    // Background checks stay short (see [_importAll]).
    final limit = background
        ? recentDays
        : _historyAllowed
        ? historyDays
        : recentDays;
    final last = _lastSync;
    final days = last != null && _backfilled.contains(type)
        ? today.difference(DateTime(last.year, last.month, last.day)).inDays +
              (quick ? quickResyncDays : resyncDays)
        : limit;
    final capped = days.clamp(0, limit);
    return DateTime(today.year, today.month, today.day - capped);
  }

  /// Reads one metric in chunks (heart rate in small ones, as watches record
  /// thousands of readings a day) and turns each chunk into daily entries.
  Future<List<HealthEntry>> _readType(
    MetricType type,
    DateTime from,
    DateTime to,
  ) async {
    final chunkDays = type == MetricType.heartRate ? 7 : 30;
    final entries = <HealthEntry>[];
    final averaged = type.aggregation == Aggregation.average;
    var start = from;
    while (start.isBefore(to)) {
      final next = DateTime(start.year, start.month, start.day + chunkDays);
      final end = next.isBefore(to) ? next : to;
      // Sleep counts toward the wake-up day, so include nights that began
      // the evening before this chunk.
      final readFrom = type.isDuration
          ? DateTime(start.year, start.month, start.day - 1)
          : start;
      final samples = await _source.read(type, readFrom, end);
      if (averaged) {
        // The newest reading, shown as the latest value (a day's entry is
        // its average).
        for (final s in samples) {
          if (s.value < type.min || s.value > type.max) continue;
          if (s.start.isAfter(to)) continue;
          final held = _newest[type];
          if (held == null || s.start.isAfter(held.at)) {
            _newest[type] = (at: s.start, value: s.value);
          }
        }
      }
      if (type == MetricType.heartRate) {
        // Time in each heart rate band, for the zones chart; saved once
        // the sync is known to still be wanted.
        // Only days inside this chunk: Health Connect returns records that
        // merely overlap it whole, and their few minutes from an earlier
        // day would replace that day's full total.
        _bins.addAll({
          for (final MapEntry(:key, :value) in HeartBins.fromSamples(
            samples,
          ).entries)
            if (!key.isBefore(start) && key.isBefore(end)) key: value,
        });
      }
      entries.addAll(
        [
          ...toDailyEntries(samples),
          // Resting heart rate for days without a record of it.
          if (type == MetricType.heartRate) ...restingFromHeartRate(samples),
        ].where((e) => !e.date.isBefore(start) && e.date.isBefore(end)),
      );
      start = next;
    }
    return entries;
  }

  /// Whether the last [_safeGranted] got a definite answer.
  bool _grantsChecked = false;

  /// What's shared now; if that can't be told, what was shared before.
  Future<Set<MetricType>> _safeGranted() async {
    try {
      final granted = await _source.grantedTypes();
      _grantsChecked = true;
      return granted;
      // The plugin throws Errors too (e.g. when Health Connect is
      // missing); they must not escape sync, disconnect or erase.
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      logError('HealthSync: permission check failed: $e');
      _grantsChecked = false;
      return _granted;
    }
  }

  void _applyDoc(Map<String, Object?> doc) {
    _connected = doc['connected'] == true;
    _historyAllowed = doc['history'] == true;
    final last = doc['lastSync'];
    _lastSync = last is String ? DateTime.tryParse(last) : null;
    final done = doc['backfilled'];
    _backfilled = done is List
        ? done.whereType<String>().map(MetricType.fromName).nonNulls.toSet()
        : {};
    _syncOnOpen = doc['syncOnOpen'] != false;
    _backgroundSync = doc['background'] == true;
    final minutes = doc['intervalMinutes'];
    _backgroundInterval = intervals.firstWhere(
      (d) => d.inMinutes == minutes,
      orElse: () => defaultInterval,
    );
    final openMinutes = doc['openMinutes'];
    _openInterval = openIntervals.firstWhere(
      (d) => d.inMinutes == openMinutes,
      orElse: () => whileOpen,
    );
    final recent = doc['recent'];
    _recent = List.unmodifiable(
      [if (recent is List) ...recent.map(SyncRecord.fromJson).nonNulls]
          .take(recentLimit),
    );
  }

  Future<void> _saveDoc() => _store.saveDocument(_docKey, {
    'connected': _connected,
    'history': _historyAllowed,
    'lastSync': _lastSync?.toIso8601String(),
    'backfilled': [for (final t in _backfilled) t.name],
    'syncOnOpen': _syncOnOpen,
    'background': _backgroundSync,
    'intervalMinutes': _backgroundInterval.inMinutes,
    'openMinutes': _openInterval.inMinutes,
    'recent': [for (final r in _recent) r.toJson()],
  });
}
