import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/workout/calories.dart';
import 'package:health_app/workout/energy.dart';
import 'package:health_app/workout/geo.dart';
import 'package:health_app/workout/intervals.dart';
import 'package:health_app/workout/workout_stats.dart';

typedef Clock = DateTime Function();

enum TrackerStatus { ready, running, paused, finished }

/// Records one live workout: time (excluding pauses), GPS distance, km
/// splits, laps, interval phases and strength sets.
///
/// Time comes from the wall clock rather than a stopwatch, because the
/// phone's monotonic clock stops while the device sleeps.
class WorkoutTracker extends ChangeNotifier {
  WorkoutTracker({
    required this.type,
    required this.weightKg,
    this.program,
    List<ExerciseLog> exercises = const [],
    this.restDuration = const Duration(seconds: 90),
    this.routineId,
    Map<String, LiftRecord> bests = const {},
    this.hints = const {},
    Clock? clock,
  }) : _bests = {...bests},
       _startBests = Map.unmodifiable(bests),
       _clock = clock ?? DateTime.now,
       _exercises = List.of(exercises),
       _filter = RouteFilter(maxSpeedMps: type.maxSpeedMps);

  /// Window used for the current pace.
  static const _paceWindow = Duration(seconds: 60);

  final WorkoutType type;
  final double weightKg;
  final IntervalProgram? program;
  final Duration restDuration;

  /// Where each exercise's targets came from, by exercise id.
  final Map<String, String> hints;

  /// The routine this workout follows, if any.
  final String? routineId;
  final Clock _clock;
  final RouteFilter _filter;

  TrackerStatus _status = TrackerStatus.ready;
  DateTime? _startTime;
  DateTime? _runningSince;
  Duration _accumulated = Duration.zero;

  final List<GeoPoint> _route = [];
  int _segmentStart = 0;
  double _distance = 0;
  double _elevationGain = 0;
  double _topSpeed = 0;

  /// Fixes looked back over for the top speed: a 15-second window even at
  /// one fix every few seconds.
  static const _speedFixes = 60;

  /// Altitude climbs are measured from; see [_climbThreshold].
  double? _altitudeRef;

  /// Phone GPS altitude jitters by a few metres. Climbs count only once
  /// they pass this, so standing still or running on the flat adds nothing.
  static const _climbThreshold = 5.0;
  final List<int> _splits = [];
  int _lastSplitSeconds = 0;

  /// Splits announced so far, in the display unit (kilometres or miles).
  int _shownSplits = 0;
  int _lastShownSeconds = 0;
  final List<Lap> _laps = [];
  int _lastLapSeconds = 0;
  double _lastLapMeters = 0;
  int _phaseIndex = 0;
  bool _programFinished = false;
  List<ExerciseLog> _exercises;
  DateTime? _restEndsAt;

  /// Called when an interval phase starts (null when the program ends).
  void Function(IntervalPhase? phase)? onPhaseChange;

  /// Called when a rest period starts after completing a set.
  void Function(Duration rest)? onRestStart;

  /// Called when a rest period is skipped.
  VoidCallback? onRestEnd;

  /// Called when a rest period runs out on its own.
  VoidCallback? onRestComplete;

  /// Called when a set beats the previous best for its exercise.
  void Function(String exerciseId, SetLog set)? onPersonalRecord;

  /// Best lifts so far, by canonical exercise id (updated as PRs happen).
  final Map<String, LiftRecord> _bests;

  /// The bests before this workout, to count records again from.
  final Map<String, LiftRecord> _startBests;
  int _prs = 0;

  /// Personal records set during this workout.
  int get personalRecords => _prs;

  /// Called each time a full kilometre, or mile in imperial units, is
  /// completed, with its number and how long it took.
  void Function(int number, int seconds)? onSplit;

  static double get _shownSplitMeters =>
      Units.imperial ? Units.kmPerMile * 1000 : 1000;

  TrackerStatus get status => _status;
  DateTime? get startTime => _startTime;
  double get distanceMeters => _distance;
  double get elevationGainMeters => _elevationGain;

  /// Fastest 15-second stretch so far, in m/s; null before there's one.
  double? get topSpeedMps => _topSpeed > 0 ? _topSpeed : null;

  /// Speed over the last minute, in m/s (see [currentPaceSecondsPerKm]).
  double? get currentSpeedMps => switch (currentPaceSecondsPerKm) {
    final pace? when pace > 0 => 1000 / pace,
    _ => null,
  };
  List<int> get splits => List.unmodifiable(_splits);
  List<Lap> get laps => List.unmodifiable(_laps);

  /// Read-only view (no copy, so it's cheap to read every second).
  List<GeoPoint> get route => UnmodifiableListView(_route);
  List<ExerciseLog> get exercises => List.unmodifiable(_exercises);
  bool get programFinished => _programFinished;

  Duration get elapsed {
    final since = _runningSince;
    return since == null
        ? _accumulated
        : _accumulated + _clock().difference(since);
  }

  double get activeKcal =>
      activeCalories(met: _met(elapsed), weightKg: weightKg, duration: elapsed);

  /// Intensity from the pace and climbing so far (GPS workouts), else the
  /// workout type's typical value.
  double _met(Duration active) {
    final pace = paceOf(
      distanceMeters: _distance,
      active: active,
      elevationGainMeters: _elevationGain,
    );
    return metFor(
      type,
      metersPerSecond: pace.metersPerSecond,
      grade: pace.grade,
    );
  }

  double? get averagePaceSecondsPerKm =>
      _distance < 50 ? null : elapsed.inSeconds / (_distance / 1000);

  /// Pace over the last minute of the current segment.
  double? get currentPaceSecondsPerKm {
    if (_route.length - _segmentStart < 2) return null;
    final last = _route.last;
    final from = last.time.subtract(_paceWindow);
    var i = _route.length - 1;
    while (i > _segmentStart && !_route[i - 1].time.isBefore(from)) {
      i--;
    }
    final first = _route[i];
    final seconds = last.time.difference(first.time).inSeconds;
    var meters = 0.0;
    for (var j = i + 1; j < _route.length; j++) {
      meters += haversineMeters(_route[j - 1], _route[j]);
    }
    if (seconds <= 0 || meters < 10) return null;
    return seconds / (meters / 1000);
  }

  /// The current interval phase and time left, if running a program.
  ({int index, IntervalPhase phase, Duration remaining})? get phase =>
      program?.phaseAt(elapsed);

  /// Length of the current rest (it can be lengthened or shortened).
  Duration get restTotal => _restTotal ?? restDuration;
  Duration? _restTotal;

  /// The first set not yet done, as (exercise index, set index).
  ({int exercise, int set})? get nextSet {
    for (var i = 0; i < _exercises.length; i++) {
      final sets = _exercises[i].sets;
      for (var j = 0; j < sets.length; j++) {
        if (!sets[j].done) return (exercise: i, set: j);
      }
    }
    return null;
  }

  /// Adds (or with a negative [by], removes) rest time; never below 5 s.
  void adjustRest(Duration by) {
    final end = _restEndsAt;
    if (end == null) return;
    final now = _clock();
    var next = end.add(by);
    final min = now.add(const Duration(seconds: 5));
    if (next.isBefore(min)) next = min;
    _restTotal = restTotal + next.difference(end);
    _restEndsAt = next;
    onRestStart?.call(next.difference(now));
    notifyListeners();
  }

  Duration? get restRemaining {
    final end = _restEndsAt;
    if (end == null) return null;
    final left = end.difference(_clock());
    return left > Duration.zero ? left : null;
  }

  // ------------------------------------------------------------- controls

  void start() {
    if (_status != TrackerStatus.ready) return;
    _startTime = _clock();
    _runningSince = _startTime;
    _status = TrackerStatus.running;
    notifyListeners();
  }

  /// When the workout was paused, so a rest under way can wait too.
  DateTime? _pausedAt;

  void pause() {
    if (_status != TrackerStatus.running) return;
    _accumulated = elapsed;
    _runningSince = null;
    _pausedAt = _clock();
    _status = TrackerStatus.paused;
    notifyListeners();
  }

  void resume() {
    if (_status != TrackerStatus.paused) return;
    _runningSince = _clock();
    final rest = _restEndsAt;
    final pausedAt = _pausedAt;
    if (rest != null && pausedAt != null) {
      // Only the paused time after the rest began is added back: a set
      // ticked while paused starts its rest then.
      final restStart = rest.subtract(restTotal);
      final from = restStart.isAfter(pausedAt) ? restStart : pausedAt;
      final next = rest.add(_runningSince!.difference(from));
      _restEndsAt = next;
      onRestStart?.call(next.difference(_runningSince!));
    }
    _pausedAt = null;
    _status = TrackerStatus.running;
    // Don't join the line across the pause.
    _filter.reset();
    _segmentStart = _route.length;
    notifyListeners();
  }

  /// Called about once a second while visible: detects interval phase
  /// changes and refreshes the display.
  void tick() {
    // A rest waits while the workout is paused (see [resume]).
    final rest = _restEndsAt;
    if (_status == TrackerStatus.running &&
        rest != null &&
        !_clock().isBefore(rest)) {
      _restEndsAt = null;
      onRestComplete?.call();
      notifyListeners();
    }
    if (_status != TrackerStatus.running) return;
    final p = program;
    if (p != null && !_programFinished) {
      final now = p.phaseAt(elapsed);
      if (now == null) {
        _programFinished = true;
        onPhaseChange?.call(null);
      } else if (now.index != _phaseIndex) {
        _phaseIndex = now.index;
        onPhaseChange?.call(now.phase);
      }
    }
    notifyListeners();
  }

  void addLocation(GeoPoint point) {
    if (_status != TrackerStatus.running || !_filter.accept(point)) return;
    if (_route.length > _segmentStart) {
      final prev = _route.last;
      _distance += haversineMeters(prev, point);
    }
    _trackClimb(point.altitude);
    _route.add(point);
    final recent = rollingSpeeds(
      _route.sublist(max(_segmentStart, _route.length - _speedFixes)),
    );
    if (recent.lastOrNull?.mps case final v? when v > _topSpeed) {
      _topSpeed = v;
    }
    final seconds = elapsed.inSeconds;
    // A long gap between fixes can cross several kilometres at once; they
    // share the time, so none is recorded as 0:00. Kilometre splits are
    // kept with the workout; announcements follow the display units.
    final crossed = _distance ~/ 1000 - _splits.length;
    final start = _lastSplitSeconds;
    for (var i = 1; i <= crossed; i++) {
      final at = start + (seconds - start) * i ~/ crossed;
      _splits.add(at - _lastSplitSeconds);
      _lastSplitSeconds = at;
    }
    final shown = (_distance / _shownSplitMeters).floor() - _shownSplits;
    final from = _lastShownSeconds;
    for (var i = 1; i <= shown; i++) {
      final at = from + (seconds - from) * i ~/ shown;
      _shownSplits++;
      onSplit?.call(_shownSplits, at - _lastShownSeconds);
      _lastShownSeconds = at;
    }
    notifyListeners();
  }

  void _trackClimb(double? altitude) {
    if (altitude == null) return;
    final ref = _altitudeRef;
    if (ref == null || altitude < ref) {
      // Going down (or starting): climbs count from the lowest point.
      _altitudeRef = altitude;
    } else if (altitude - ref >= _climbThreshold) {
      _elevationGain += altitude - ref;
      _altitudeRef = altitude;
    }
  }

  void lap() {
    if (_status != TrackerStatus.running) return;
    final seconds = elapsed.inSeconds;
    _laps.add(
      Lap(
        seconds: seconds - _lastLapSeconds,
        meters: _distance - _lastLapMeters,
      ),
    );
    _lastLapSeconds = seconds;
    _lastLapMeters = _distance;
    notifyListeners();
  }

  // ------------------------------------------------------------- strength

  void addExercise(String exerciseId, {List<SetLog>? sets}) {
    _exercises = [
      ..._exercises,
      ExerciseLog(
        exerciseId: exerciseId,
        sets: sets ?? const [SetLog(reps: 10, weightKg: 0)],
      ),
    ];
    notifyListeners();
  }

  void removeExercise(int index) {
    _exercises = [..._exercises]..removeAt(index);
    // Its done sets may have held a record.
    _recountRecords();
    notifyListeners();
  }

  /// Adds a set copying the previous one's reps and weight.
  void addSet(int exercise) {
    final e = _exercises[exercise];
    final last = e.sets.lastOrNull ?? const SetLog(reps: 10, weightKg: 0);
    _replace(
      exercise,
      e.copyWith(sets: [...e.sets, last.copyWith(done: false)]),
    );
  }

  void removeSet(int exercise, int set) {
    final e = _exercises[exercise];
    final removed = e.sets[set];
    _replace(exercise, e.copyWith(sets: [...e.sets]..removeAt(set)));
    if (removed.done) _recountRecords();
  }

  void updateSet(int exercise, int set, SetLog value) {
    final e = _exercises[exercise];
    final sets = [...e.sets];
    sets[set] = value.copyWith(done: sets[set].done);
    _replace(exercise, e.copyWith(sets: sets));
    // A done set changed: its record (or not) may have too.
    if (sets[set].done) _recountRecords();
  }

  void toggleSetDone(int exercise, int set) {
    final e = _exercises[exercise];
    final sets = [...e.sets];
    final done = !sets[set].done;
    sets[set] = sets[set].copyWith(done: done);
    _replace(exercise, e.copyWith(sets: sets));
    if (!done) {
      // Unticked: a record it set no longer counts.
      _recountRecords();
      return;
    }
    _checkRecord(e.exerciseId, sets[set]);
    if (!sets[set].type.counts || !_lastInSuperset(exercise)) return;
    final rest = Duration(seconds: e.restSeconds ?? restDuration.inSeconds);
    _restEndsAt = _clock().add(rest);
    _restTotal = rest;
    onRestStart?.call(rest);
    // The rest view shows at once, not on the next tick.
    notifyListeners();
  }

  /// In a superset, rest comes after the last exercise of the group.
  bool _lastInSuperset(int index) {
    final group = _exercises[index].superset;
    if (group == null) return true;
    for (var i = index + 1; i < _exercises.length; i++) {
      if (_exercises[i].superset == group) return false;
    }
    return true;
  }

  /// Counts records again from the done sets, in order, without
  /// celebrating them again.
  void _recountRecords() {
    _bests
      ..clear()
      ..addAll(_startBests);
    _prs = 0;
    for (final e in _exercises) {
      for (final s in e.sets) {
        if (s.done) _checkRecord(e.exerciseId, s, announce: false);
      }
    }
  }

  void _checkRecord(String exerciseId, SetLog set, {bool announce = true}) {
    final id = ExerciseCatalog.canonical(exerciseId);
    final best = _bests[id];
    if (best == null) {
      // First time doing this lift: it sets the bar for later sets.
      if (set.done && set.type.counts && set.weightKg > 0) {
        _bests[id] = (
          weightKg: set.weightKg,
          reps: set.reps,
          estimatedOneRepMax: epley(set.weightKg, set.reps),
          date: _clock(),
        );
      }
      return;
    }
    if (!isPersonalRecord(set, best)) return;
    _prs++;
    // Keep the best of both measures, so a heavy single doesn't lower the
    // estimated max (and vice versa).
    final e1rm = epley(set.weightKg, set.reps);
    _bests[id] = (
      weightKg: max(set.weightKg, best.weightKg),
      reps: set.reps,
      estimatedOneRepMax: max(e1rm, best.estimatedOneRepMax),
      date: _clock(),
    );
    if (announce) onPersonalRecord?.call(exerciseId, set);
  }

  /// Inserts an undone copy of a set right after it.
  void copySet(int exercise, int set) {
    final e = _exercises[exercise];
    final sets = [...e.sets]
      ..insert(set + 1, e.sets[set].copyWith(done: false));
    _replace(exercise, e.copyWith(sets: sets));
  }

  void skipRest() {
    _restEndsAt = null;
    onRestEnd?.call();
    notifyListeners();
  }

  void _replace(int index, ExerciseLog log) {
    _exercises = [..._exercises]..[index] = log;
    notifyListeners();
  }

  // --------------------------------------------------------------- finish

  /// Ends the workout and returns it with its (downsampled) route.
  (WorkoutSession, List<GeoPoint>) finish({required String id}) {
    final active = elapsed;
    _accumulated = active;
    _runningSince = null;
    _status = TrackerStatus.finished;
    final route = downsample(_route);
    final start = _startTime ?? _clock();
    final session = WorkoutSession(
      id: id,
      type: type,
      start: start,
      end: _clock(),
      activeSeconds: active.inSeconds,
      distanceMeters: _distance,
      activeKcal: activeCalories(
        met: _met(active),
        weightKg: weightKg,
        duration: active,
      ),
      elevationGainMeters: _elevationGain,
      splits: List.of(_splits),
      laps: List.of(_laps),
      exercises: [
        for (final e in _exercises)
          if (e.sets.isNotEmpty) e,
      ],
      intervalProgram: program?.name,
      hasRoute: route.length >= 2,
      routineId: routineId,
    );
    notifyListeners();
    return (session, route);
  }

  // ----------------------------------------------------------- checkpoint

  /// Snapshot saved periodically so a workout survives the app being closed.
  Map<String, Object?> toCheckpoint() {
    final start = _startTime ?? _clock();
    return {
      'type': type.name,
      'weight': weightKg,
      'program': program?.name,
      'routine': ?routineId,
      'start': start.toIso8601String(),
      'elapsed': elapsed.inSeconds,
      // Whether the clock was running when saved, and when, so time the app
      // spent closed can be counted on restore.
      'running': _status == TrackerStatus.running,
      'savedAt': _clock().toIso8601String(),
      'distance': _distance,
      'elevation': _elevationGain,
      'topSpeed': _topSpeed,
      'splits': _splits,
      'lastSplit': _lastSplitSeconds,
      'lastShown': _lastShownSeconds,
      'laps': [for (final l in _laps) l.toJson()],
      'lastLap': [_lastLapSeconds, _lastLapMeters],
      // Downsampled so saving stays quick on long workouts.
      'route': [for (final p in downsample(_route)) p.toCompact(start)],
      'exercises': [for (final e in _exercises) e.toJson()],
    };
  }

  /// The most time a workout gains while the app was closed.
  static const _maxAway = Duration(hours: 4);

  /// Restores a workout from [toCheckpoint], paused. Returns null if the
  /// data is unusable.
  static WorkoutTracker? fromCheckpoint(
    Map<String, Object?> json, {
    Clock? clock,
    Map<String, LiftRecord> bests = const {},
    Duration restDuration = const Duration(seconds: 90),
  }) {
    final type = WorkoutType.fromName(json['type']);
    final start = DateTime.tryParse('${json['start']}');
    final elapsed = json['elapsed'];
    final weight = json['weight'];
    if (type == null || start == null || elapsed is! int || weight is! num) {
      return null;
    }
    final programName = json['program'];
    final exercises = json['exercises'];
    final t = WorkoutTracker(
      type: type,
      weightKg: weight.toDouble(),
      program: IntervalProgram.byName(programName),
      exercises: exercises is List
          ? exercises.map(ExerciseLog.tryFromJson).nonNulls.toList()
          : const [],
      routineId: json['routine'] is String ? json['routine'] as String : null,
      bests: bests,
      restDuration: restDuration,
      clock: clock,
    );
    double num0(Object? v) => v is num ? v.toDouble() : 0;
    t._startTime = start;
    var total = Duration(seconds: elapsed);
    // Running when the app was closed (Android may stop it in the
    // background): the workout went on, so that time counts, up to a
    // limit in case it was simply forgotten.
    final savedAt = DateTime.tryParse('${json['savedAt']}');
    if (json['running'] == true && savedAt != null) {
      final away = t._clock().difference(savedAt);
      if (!away.isNegative) total += away > _maxAway ? _maxAway : away;
    }
    t._accumulated = total;
    t._status = TrackerStatus.paused;
    t._distance = num0(json['distance']);
    t._elevationGain = num0(json['elevation']);
    t._topSpeed = num0(json['topSpeed']);
    final splits = json['splits'];
    if (splits is List) t._splits.addAll(splits.whereType<int>());
    final lastSplit = json['lastSplit'];
    if (lastSplit is int) t._lastSplitSeconds = lastSplit;
    // Splits already announced aren't announced again.
    t._shownSplits = (t._distance / _shownSplitMeters).floor();
    // Older checkpoints only have the last kilometre's time.
    final lastShown = json['lastShown'];
    t._lastShownSeconds = lastShown is int ? lastShown : t._lastSplitSeconds;
    final laps = json['laps'];
    if (laps is List) t._laps.addAll(laps.map(Lap.tryFromJson).nonNulls);
    final lastLap = json['lastLap'];
    if (lastLap case [final int s, final num m]) {
      t._lastLapSeconds = s;
      t._lastLapMeters = m.toDouble();
    }
    final route = json['route'];
    if (route is List) {
      t._route.addAll(
        route.map((r) => GeoPoint.fromCompact(r, start)).nonNulls,
      );
      t._segmentStart = t._route.length;
    }
    final p = t.program;
    if (p != null) {
      t._phaseIndex = p.phaseAt(t.elapsed)?.index ?? 0;
      t._programFinished = p.phaseAt(t.elapsed) == null;
    }
    return t;
  }
}
