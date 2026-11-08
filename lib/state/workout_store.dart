import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/models/exercise_library.dart';
import 'package:health_app/models/health_entry.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/starter_plans.dart';
import 'package:health_app/models/training_plan.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/utils/log.dart';
import 'package:health_app/workout/geo.dart';
import 'package:health_app/workout/plan_scheduler.dart';
import 'package:health_app/workout/workout_stats.dart';

/// Effort column shown on sets.
enum EffortMode {
  off('Off'),

  /// Rate of perceived exertion, 6–10.
  rpe('RPE'),

  /// Reps in reserve, 0–4 (10 − RPE).
  rir('RIR');

  const EffortMode(this.label);

  final String label;
}

/// How GPS routes are drawn.
enum MapStyle {
  /// Route shape only; the app stays fully offline.
  trace,

  /// OpenStreetMap street map (downloads map images).
  street,
}

@immutable
class WorkoutSettings {
  const WorkoutSettings({
    this.mapStyle = MapStyle.trace,
    this.saveToHealthConnect = false,
    this.weeklyGoalMinutes = defaultWeeklyGoal,
    this.restSeconds = 90,
    this.effort = EffortMode.off,
    this.barKg = 20,
    this.plates,
  });

  final MapStyle mapStyle;
  final bool saveToHealthConnect;

  /// WHO recommends at least 150 minutes of activity a week. Zero means
  /// no weekly goal (e.g. for someone who trains on a treadmill and only
  /// wants to log).
  final int weeklyGoalMinutes;

  static const defaultWeeklyGoal = 150;

  bool get hasWeeklyGoal => weeklyGoalMinutes > 0;
  final int restSeconds;

  /// Optional effort column on each set.
  final EffortMode effort;

  /// Default bar for the plate calculator.
  final double barKg;

  /// Plate weight → pairs owned; null means a full standard set.
  final Map<double, int>? plates;

  WorkoutSettings copyWith({
    MapStyle? mapStyle,
    bool? saveToHealthConnect,
    int? weeklyGoalMinutes,
    int? restSeconds,
    EffortMode? effort,
    double? barKg,
    Map<double, int>? plates,
  }) => WorkoutSettings(
    mapStyle: mapStyle ?? this.mapStyle,
    saveToHealthConnect: saveToHealthConnect ?? this.saveToHealthConnect,
    weeklyGoalMinutes: weeklyGoalMinutes ?? this.weeklyGoalMinutes,
    restSeconds: restSeconds ?? this.restSeconds,
    effort: effort ?? this.effort,
    barKg: barKg ?? this.barKg,
    plates: plates ?? this.plates,
  );

  Map<String, Object?> toJson() => {
    'map': mapStyle.name,
    'saveHc': saveToHealthConnect,
    'weeklyGoal': weeklyGoalMinutes,
    'rest': restSeconds,
    if (effort != EffortMode.off) 'effort': effort.name,
    'bar': barKg,
    if (plates case final p?)
      'plates': {for (final e in p.entries) '${e.key}': e.value},
  };

  factory WorkoutSettings.fromJson(Map<String, Object?> json) {
    final goal = json['weeklyGoal'];
    final rest = json['rest'];
    return WorkoutSettings(
      mapStyle: json['map'] == MapStyle.street.name
          ? MapStyle.street
          : MapStyle.trace,
      saveToHealthConnect: json['saveHc'] == true,
      weeklyGoalMinutes: goal is int && goal >= 0 ? goal : defaultWeeklyGoal,
      restSeconds: rest is int && rest > 0 ? rest : 90,
      effort:
          EffortMode.values
              .where((e) => e.name == json['effort'])
              .firstOrNull ??
          EffortMode.off,
      barKg: switch (json['bar']) {
        final num b when b > 0 => b.toDouble(),
        _ => 20,
      },
      plates: switch (json['plates']) {
        final Map<String, Object?> p => {
          for (final e in p.entries)
            if (double.tryParse(e.key) case final kg? when e.value is int)
              kg: e.value as int,
        },
        _ => null,
      },
    );
  }
}

/// Workouts, routines and workout settings. Each saved workout also adds
/// linked Health entries (exercise minutes, active energy, distance) with
/// ids `wk:<workout id>:<metric>`, removed again when the workout is deleted.
class WorkoutStore extends ChangeNotifier {
  WorkoutStore(this._repo, this._health, {Clock? clock})
    : _clock = clock ?? DateTime.now;

  static const _listKey = 'workouts';
  static const _routinesKey = 'routines';
  static const _settingsKey = 'workoutSettings';
  static const _checkpointKey = 'workoutCheckpoint';
  static const _planKey = 'trainingPlan';
  static String _routeKey(String id) => 'route.$id';
  static String linkPrefix(String id) => 'wk:$id:';

  final HealthRepository _repo;
  final HealthStore _health;
  final Clock _clock;

  List<WorkoutSession> _all = [];
  List<Routine> _custom = [];
  WorkoutSettings _settings = const WorkoutSettings();
  TrainingPlan _plan = const TrainingPlan();
  bool _loaded = false;
  bool _hasCheckpoint = false;

  /// False when the saved list or routines couldn't be read, so saving
  /// can't overwrite them with only what's in memory.
  bool _listReadable = true;
  bool _routinesReadable = true;
  PersonalRecords? _records;

  /// All workouts, newest first.
  // A read-only view, not a copy: the list is replaced, never changed.
  List<WorkoutSession> get all => UnmodifiableListView(_all);
  List<Routine> get routines => [..._custom, ...Routine.presets];
  WorkoutSettings get settings => _settings;
  TrainingPlan get plan => _plan;

  /// Completed workouts that came from a routine (for the plan).
  List<DoneSession> get _done => [
    for (final w in _all)
      if (w.routineId case final id?) (routineId: id, date: w.start),
  ];

  /// Today's planned session (or a rest day).
  PlannedDay todaySession() => sessionFor(_clock(), _plan, _done);

  /// The next planned session that isn't done yet.
  PlannedDay? nextPlanned() => nextSession(_clock(), _plan, _done);

  /// What's planned on any [day] (for the week view).
  PlannedDay plannedOn(DateTime day) => sessionFor(day, _plan, _done);

  /// Active calories burned in workouts started on [day].
  double kcalOn(DateTime day) => _all
      .where((w) {
        final s = w.start.toLocal();
        return s.year == day.year && s.month == day.month && s.day == day.day;
      })
      .fold(0.0, (sum, w) => sum + w.activeKcal);

  Routine? routineById(String? id) =>
      id == null ? null : routines.where((r) => r.id == id).firstOrNull;
  bool get loaded => _loaded;

  /// True when an unfinished workout can be resumed.
  bool get hasCheckpoint => _hasCheckpoint;
  DateTime get today => _health.today;

  /// This week's totals; the week starts on the plan's first day.
  WeekSummary get thisWeek =>
      weekSummary(_all, _clock(), firstDay: _plan.weekStart);
  int get streak => dayStreak(_all, _clock());
  PersonalRecords get records => _records ??= personalRecords(_all);

  WorkoutSession? byId(String id) => _all.where((w) => w.id == id).firstOrNull;

  Future<void> _write(Future<void> Function() write, {String? key}) =>
      _health.queue.run(write, key: key);

  Future<void> load() async {
    final list = await _loadDoc(_listKey);
    _listReadable = list.readable;
    final items = list.doc?['items'];
    if (items is List) {
      _setAll(
        items
            .whereType<Map<String, Object?>>()
            .map(WorkoutSession.tryFromJson)
            .nonNulls
            .toList(),
      );
    }
    final routinesDoc = await _loadDoc(_routinesKey);
    _routinesReadable = routinesDoc.readable;
    final routines = routinesDoc.doc?['items'];
    if (routines is List) {
      _custom = routines.map(Routine.tryFromJson).nonNulls.toList();
    }
    final settings = (await _loadDoc(_settingsKey)).doc;
    if (settings != null) _settings = WorkoutSettings.fromJson(settings);
    final plan = (await _loadDoc(_planKey)).doc;
    if (plan != null) _plan = TrainingPlan.fromJson(plan);
    _hasCheckpoint = (await _loadDoc(_checkpointKey)).doc != null;
    // Only tidy up linked entries when the workout list is known to be
    // complete; otherwise they could belong to workouts we couldn't read.
    if (list.readable) await _removeOrphanedEntries();
    _loaded = true;
    notifyListeners();
  }

  /// Loads one document; each is independent, so one bad document can't
  /// stop the others from loading.
  Future<({Map<String, Object?>? doc, bool readable})> _loadDoc(
    String key,
  ) async {
    try {
      return (doc: await _repo.loadDocument(key), readable: true);
    } on Exception catch (e) {
      logError('WorkoutStore: could not load $key: $e');
      return (doc: null, readable: false);
    }
  }

  /// Removes the linked entries of the workouts [ids] that aren't here:
  /// those a restore skipped as the same session already here under
  /// another id, whose entries would otherwise be counted twice.
  Future<void> dropEntriesOfMissing(Iterable<String> ids) async {
    final here = {for (final w in _all) w.id};
    for (final id in {...ids}.difference(here)) {
      await _health.removeEntriesWithPrefix(linkPrefix(id));
    }
  }

  /// Removes linked entries whose workout no longer exists (e.g. after a
  /// crash between two writes).
  Future<void> _removeOrphanedEntries() async {
    final ids = {for (final w in _all) w.id};
    final orphans = <String>{};
    for (final type in MetricType.values) {
      for (final e in _health.entriesFor(type)) {
        if (!e.isFromWorkout) continue;
        final id = e.id.split(':').elementAtOrNull(1);
        if (id != null && !ids.contains(id)) orphans.add(id);
      }
    }
    for (final id in orphans) {
      await _health.removeEntriesWithPrefix(linkPrefix(id));
    }
  }

  /// Clears memory after "Erase All" (storage is cleared by the HealthStore).
  void reset() {
    _plan = const TrainingPlan();
    _hasCheckpoint = false;
    _listReadable = true;
    _routinesReadable = true;
    _setAll([]);
    _custom = [];
    _settings = const WorkoutSettings();
    notifyListeners();
  }

  // ------------------------------------------------------------- workouts

  /// Saves a workout with its route and linked Health entries. All writes
  /// are queued at once, so a later "Erase All" can't be overtaken.
  Future<void> save(WorkoutSession session, {List<GeoPoint> route = const []}) {
    _setAll([session, ..._all.where((w) => w.id != session.id)]);
    notifyListeners();
    final writes = [
      _saveList(),
      if (route.length >= 2)
        _write(
          () => _repo.saveDocument(_routeKey(session.id), {
            'o': session.start.toIso8601String(),
            'p': [for (final p in route) p.toCompact(session.start)],
          }),
          key: _routeKey(session.id),
        ),
      _health.addEntries(_linkedEntries(session)),
    ];
    return Future.wait(writes);
  }

  /// Adds workouts from another app's export, skipping any already here.
  /// They add no linked Health entries. Returns how many were added.
  Future<int> importSessions(List<WorkoutSession> sessions) async {
    final existing = {for (final w in _all) w.id};
    // A strength workout already here, started the same minute with the
    // same exercises (e.g. this app's own export brought back in).
    String key(WorkoutSession w) =>
        '${w.start.millisecondsSinceEpoch ~/ 60000}|'
        '${[for (final e in w.exercises) ExerciseCatalog.canonical(e.exerciseId)].join(',')}';
    final same = {
      for (final w in _all)
        if (w.exercises.isNotEmpty) key(w),
    };
    final fresh = [
      for (final w in sessions)
        if (!existing.contains(w.id) &&
            !(w.exercises.isNotEmpty && same.contains(key(w))))
          w,
    ];
    if (fresh.isEmpty) return 0;
    _setAll([..._all, ...fresh]);
    notifyListeners();
    await _saveList();
    return fresh.length;
  }

  /// Replaces workouts imported from Health Connect that started on or
  /// after [from]. Imported workouts add no linked entries: their minutes
  /// and energy already arrive through the Health Connect sync.
  Future<void> replaceImported(DateTime from, List<WorkoutSession> imported) {
    final ids = {for (final w in imported) w.id};
    _setAll([
      for (final w in _all)
        if (!(w.isImported && !w.start.isBefore(from)) && !ids.contains(w.id))
          w,
      ...imported,
    ]);
    notifyListeners();
    return _saveList();
  }

  Future<void> removeImported() {
    _setAll(_all.where((w) => !w.isImported).toList());
    notifyListeners();
    return _saveList();
  }

  /// Saves changes to a workout. With [relink], its linked Health entries
  /// are rebuilt (needed when the date, duration, distance or energy changed).
  Future<void> update(WorkoutSession edited, {bool relink = false}) {
    // Edits never change where a workout came from.
    final stored = _all.where((w) => w.id == edited.id).firstOrNull;
    final session = stored == null || stored.source == edited.source
        ? edited
        : edited.copyWith(source: stored.source);
    _setAll([for (final w in _all) w.id == session.id ? session : w]);
    notifyListeners();
    final writes = [_saveList()];
    // Only the app's own workouts add activity data.
    if (relink && session.source == WorkoutSource.app) {
      writes
        ..add(_health.removeEntriesWithPrefix(linkPrefix(session.id)))
        ..add(_health.addEntries(_linkedEntries(session)));
    }
    return Future.wait(writes);
  }

  Future<void> delete(String id) {
    _setAll(_all.where((w) => w.id != id).toList());
    notifyListeners();
    return Future.wait([
      _saveList(),
      _write(() => _repo.deleteDocument(_routeKey(id)), key: _routeKey(id)),
      _health.removeEntriesWithPrefix(linkPrefix(id)),
    ]);
  }

  Future<List<GeoPoint>> routeOf(String id) async {
    final doc = await _repo.loadDocument(_routeKey(id));
    final origin = DateTime.tryParse('${doc?['o']}');
    final points = doc?['p'];
    if (origin == null || points is! List) return const [];
    return points.map((p) => GeoPoint.fromCompact(p, origin)).nonNulls.toList();
  }

  /// Sets for [exerciseId] from its last [count] workouts, newest first.
  List<List<SetLog>> recentSets(String exerciseId, {int count = 3}) {
    final id = ExerciseCatalog.canonical(exerciseId);
    final out = <List<SetLog>>[];
    for (final w in _all) {
      for (final e in w.exercises) {
        if (ExerciseCatalog.canonical(e.exerciseId) == id) {
          final done = _doneSets(e.sets);
          if (done.isNotEmpty) out.add(done);
          break;
        }
      }
      if (out.length >= count) break;
    }
    return out;
  }

  /// Sets from the most recent workout that included [exerciseId].
  /// The sets actually done: planned sets left unticked when a workout
  /// finished aren't something to repeat or compare against.
  static List<SetLog> _doneSets(List<SetLog> sets) => [
    for (final s in sets)
      if (s.done) s,
  ];

  List<SetLog> previousSets(String exerciseId) {
    final id = ExerciseCatalog.canonical(exerciseId);
    for (final w in _all) {
      for (final e in w.exercises) {
        if (ExerciseCatalog.canonical(e.exerciseId) != id) continue;
        final done = _doneSets(e.sets);
        if (done.isNotEmpty) return done;
        break;
      }
    }
    return const [];
  }

  List<HealthEntry> _linkedEntries(WorkoutSession s) {
    final minutes = s.activeSeconds / 60;
    HealthEntry entry(MetricType type, double value) => HealthEntry(
      id: '${linkPrefix(s.id)}${type.name}',
      type: type,
      value: double.parse(
        value.clamp(type.min, type.max).toStringAsFixed(type.decimals),
      ),
      date: s.start,
      note: s.type.label,
      source: EntrySource.workout,
    );
    return [
      if (minutes >= 1) entry(MetricType.exerciseMinutes, minutes),
      if (s.activeKcal >= 1) entry(MetricType.activeEnergy, s.activeKcal),
      if (s.type.usesGps && s.distanceMeters >= 10)
        entry(MetricType.distance, s.kilometres),
    ];
  }

  void _setAll(List<WorkoutSession> list) {
    _all = list..sort((a, b) => b.start.compareTo(a.start));
    _records = null;
  }

  Future<void> _saveList() {
    if (!_listReadable) {
      logError('WorkoutStore: not saving over workouts that could not be read');
      return Future.value();
    }
    final json = {
      'items': [for (final w in _all) w.toJson()],
    };
    return _write(() => _repo.saveDocument(_listKey, json), key: _listKey);
  }

  // ------------------------------------------------------------- routines

  Future<void> saveRoutine(Routine routine) {
    _custom = [routine, ..._custom.where((r) => r.id != routine.id)];
    notifyListeners();
    return _saveRoutines();
  }

  Future<void> deleteRoutine(String id) {
    _custom = _custom.where((r) => r.id != id).toList();
    final writes = [_saveRoutines()];
    if (_plan.days.containsValue(id) ||
        _plan.rotation.contains(id) ||
        _plan.overrides.containsValue(id)) {
      writes.add(setPlan(_plan.withoutRoutine(id)));
    }
    notifyListeners();
    return Future.wait(writes);
  }

  // ----------------------------------------------------------------- plan

  Future<void> setPlan(TrainingPlan plan) {
    _plan = plan;
    notifyListeners();
    final json = plan.toJson();
    return _write(() => _repo.saveDocument(_planKey, json), key: _planKey);
  }

  /// Copies a starter plan's routines (so they can be edited) and makes it
  /// the weekly plan.
  Future<void> applyStarter(StarterPlan starter) {
    final stamp = _clock().microsecondsSinceEpoch;
    final copies = [
      for (final (i, r) in starter.routines.indexed)
        Routine(id: 'r${stamp}_$i', name: r.name, items: r.items),
    ];
    _custom = [...copies, ..._custom];
    final days = {
      for (final MapEntry(key: day, value: i) in starter.days.entries)
        day: copies[i].id,
    };
    notifyListeners();
    return Future.wait([
      _saveRoutines(),
      setPlan(
        _plan.copyWith(
          mode: PlanMode.weekday,
          days: days,
          rotation: [for (final r in copies) r.id],
          overrides: const {},
        ),
      ),
    ]);
  }

  Future<void> _saveRoutines() {
    if (!_routinesReadable) {
      logError('WorkoutStore: not saving over routines that could not be read');
      return Future.value();
    }
    final json = {
      'items': [for (final r in _custom) r.toJson()],
    };
    return _write(
      () => _repo.saveDocument(_routinesKey, json),
      key: _routinesKey,
    );
  }

  // ------------------------------------------------- settings, checkpoint

  Future<void> updateSettings(WorkoutSettings settings) {
    _settings = settings;
    notifyListeners();
    final json = settings.toJson();
    return _write(
      () => _repo.saveDocument(_settingsKey, json),
      key: _settingsKey,
    );
  }

  Future<void> saveCheckpoint(Map<String, Object?> checkpoint) {
    _setHasCheckpoint(true);
    return _write(
      () => _repo.saveDocument(_checkpointKey, checkpoint),
      key: _checkpointKey,
    );
  }

  Future<void> clearCheckpoint() {
    _setHasCheckpoint(false);
    return _write(
      () => _repo.deleteDocument(_checkpointKey),
      key: _checkpointKey,
    );
  }

  void _setHasCheckpoint(bool value) {
    if (_hasCheckpoint == value) return;
    _hasCheckpoint = value;
    notifyListeners();
  }

  Future<Map<String, Object?>?> loadCheckpoint() =>
      _repo.loadDocument(_checkpointKey);
}
