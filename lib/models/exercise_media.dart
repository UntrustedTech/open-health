import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:health_app/models/exercise_catalog.dart';

/// Demonstration clips: a start and an end photo per exercise, played as a
/// loop. Photos come from free-exercise-db (public domain); not every
/// exercise has one.
@immutable
class ExerciseMedia {
  const ExerciseMedia._(this._clips);

  /// Loaded at startup; empty until then.
  static ExerciseMedia instance = const ExerciseMedia._({});

  static const _asset = 'assets/data/exercise_media.json';
  static const _dir = 'assets/exercise_media';
  static final _key = RegExp(r'^\d{3}$');

  /// Exercise id → clip key.
  final Map<String, String> _clips;

  int get count => _clips.length;

  factory ExerciseMedia.fromJson(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return const ExerciseMedia._({});
    return ExerciseMedia._({
      for (final MapEntry(:key, :value) in decoded.entries)
        if (key is String && value is String && _key.hasMatch(value))
          key: value,
    });
  }

  static Future<ExerciseMedia> loadBundled([AssetBundle? bundle]) async =>
      ExerciseMedia.fromJson(await (bundle ?? rootBundle).loadString(_asset));

  /// The clip's two frames (start, end), or null if there is none.
  List<String>? framesFor(String exerciseId) {
    final key = _clips[ExerciseCatalog.canonical(exerciseId)];
    if (key == null) return null;
    return ['$_dir/${key}_0.webp', '$_dir/${key}_1.webp'];
  }

  bool has(String exerciseId) => framesFor(exerciseId) != null;
}
