import 'package:flutter/foundation.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/models/exercise_media.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/utils/log.dart';

/// The exercise library: the bundled catalog plus the user's own exercises,
/// and which equipment the user has (used to filter the library).
class ExerciseStore extends ChangeNotifier {
  ExerciseStore(
    this._repo,
    this._health, {
    Future<ExerciseCatalog> Function()? loadCatalog,
    Future<ExerciseMedia> Function()? loadMedia,
  }) : _loadCatalog = loadCatalog ?? ExerciseCatalog.loadBundled,
       _loadMedia = loadMedia ?? ExerciseMedia.loadBundled;

  static const _customKey = 'customExercises';
  static const _equipmentKey = 'equipmentOwned';

  final HealthRepository _repo;
  final HealthStore _health;
  final Future<ExerciseCatalog> Function() _loadCatalog;
  final Future<ExerciseMedia> Function() _loadMedia;

  ExerciseCatalog _base = ExerciseCatalog.instance;
  List<CatalogExercise> _custom = [];
  Set<String> _owned = {};
  bool _loaded = false;

  bool get loaded => _loaded;
  ExerciseCatalog get catalog => ExerciseCatalog.instance;
  List<CatalogExercise> get custom => List.unmodifiable(_custom);

  /// Equipment the user has; empty means "show everything".
  Set<String> get ownedEquipment => Set.unmodifiable(_owned);

  Future<void> load() async {
    try {
      _base = await _loadCatalog();
    } on Exception catch (e) {
      logError('ExerciseStore: library failed to load: $e');
    }
    try {
      ExerciseMedia.instance = await _loadMedia();
    } on Exception catch (e) {
      // Without clips the library still works.
      logError('ExerciseStore: demo clips failed to load: $e');
    }
    try {
      final doc = await _repo.loadDocument(_customKey);
      final items = doc?['items'];
      if (items is List) {
        _custom = items
            .whereType<Map<String, Object?>>()
            .map(CatalogExercise.fromJson)
            .nonNulls
            .toList();
      }
      _customReadable = true;
    } on Exception catch (e) {
      _customReadable = false;
      logError('ExerciseStore: could not load custom exercises: $e');
    }
    try {
      final eq = await _repo.loadDocument(_equipmentKey);
      final owned = eq?['items'];
      if (owned is List) _owned = owned.whereType<String>().toSet();
      _equipmentReadable = true;
    } on Exception catch (e) {
      _equipmentReadable = false;
      logError('ExerciseStore: could not load equipment: $e');
    }
    _publish();
    _loaded = true;
    notifyListeners();
  }

  /// Whether each document was read; one that couldn't be is never saved
  /// over, so what's stored isn't lost to an empty list.
  bool _customReadable = true;
  bool _equipmentReadable = true;

  void _publish() => ExerciseCatalog.instance = _base.withCustom(_custom);

  Future<CatalogExercise> addCustom({
    required String name,
    required String bodyPart,
    required String equipment,
    required String target,
    List<String> secondary = const [],
    bool timed = false,
    bool perSide = false,
  }) async {
    _checkCustomReadable();
    final e = CatalogExercise(
      id: 'c_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      bodyPart: bodyPart,
      equipment: equipment,
      target: target,
      secondary: secondary,
      custom: true,
      timed: timed,
      perSide: perSide,
    );
    _custom = [e, ..._custom];
    _publish();
    notifyListeners();
    await _saveCustom();
    return e;
  }

  /// Removes a custom exercise. Workouts that used it keep their data.
  Future<void> deleteCustom(String id) async {
    _checkCustomReadable();
    _custom = _custom.where((e) => e.id != id).toList();
    _publish();
    notifyListeners();
    await _saveCustom();
  }

  Future<void> setOwnedEquipment(Set<String> owned) async {
    if (!_equipmentReadable) {
      throw StateError('Equipment could not be read');
    }
    _owned = {...owned};
    notifyListeners();
    final json = {'items': _owned.toList()..sort()};
    await _health.saveDocument(_equipmentKey, json);
  }

  void _checkCustomReadable() {
    if (!_customReadable) {
      throw StateError('Custom exercises could not be read');
    }
  }

  Future<void> _saveCustom() {
    final json = {
      'items': [for (final e in _custom) e.toJson()],
    };
    return _health.saveDocument(_customKey, json);
  }

  /// Clears memory after "Erase All".
  void reset() {
    _custom = [];
    _customReadable = true;
    _equipmentReadable = true;
    _owned = {};
    _publish();
    notifyListeners();
  }
}
