import 'package:flutter/foundation.dart';

import 'package:health_app/models/workout_program.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/utils/log.dart';

/// The workout program the user is following (if any) and when they
/// started it. Progress comes from their saved workouts.
class ProgramStore extends ChangeNotifier {
  ProgramStore(this._health, this._workouts) {
    _workouts.addListener(_onWorkouts);
  }

  static const docKey = 'program';

  final HealthStore _health;
  final WorkoutStore _workouts;

  WorkoutProgram? _program;
  DateTime? _started;
  ProgramProgress? _progress;
  bool _readable = true;

  WorkoutProgram? get program => _program;
  DateTime? get started => _started;

  /// Progress through the current program, or null without one.
  ProgramProgress? get progress {
    final p = _program, s = _started;
    if (p == null || s == null) return null;
    return _progress ??= ProgramProgress.of(p, s, _workouts.all);
  }

  void _onWorkouts() {
    _progress = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _workouts.removeListener(_onWorkouts);
    super.dispose();
  }

  Future<void> load() async {
    _program = null;
    _started = null;
    _progress = null;
    _readable = true;
    try {
      final doc = await _health.loadDocument(docKey);
      final p = WorkoutProgram.byId(doc?['id']);
      final s = DateTime.tryParse('${doc?['started']}');
      if (p != null && s != null) {
        _program = p;
        _started = s;
      }
    } on Exception catch (e) {
      _readable = false;
      logError('Program: could not load: $e');
    }
    notifyListeners();
  }

  /// Starts [program] from today (replacing any current one).
  Future<void> start(WorkoutProgram program) async {
    _program = program;
    _started = _health.today;
    _progress = null;
    notifyListeners();
    await _save();
  }

  Future<void> stop() async {
    _program = null;
    _started = null;
    _progress = null;
    notifyListeners();
    await _save();
  }

  /// Clears memory after "Erase All".
  void reset() {
    _program = null;
    _started = null;
    _progress = null;
    _readable = true;
    notifyListeners();
  }

  Future<void> _save() async {
    if (!_readable) {
      logError('Program: not saving over data that could not be read');
      return;
    }
    final p = _program, s = _started;
    if (p == null || s == null) {
      await _health.deleteDocument(docKey);
      return;
    }
    await _health.saveDocument(docKey, {
      'id': p.id,
      'started': s.toIso8601String(),
    });
  }
}
