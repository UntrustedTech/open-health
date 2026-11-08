import 'package:flutter/foundation.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/data/photo_vault.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/utils/log.dart';

enum PhotoPose {
  front('Front'),
  side('Side'),
  back('Back');

  const PhotoPose(this.label);

  final String label;
}

@immutable
class ProgressPhoto {
  const ProgressPhoto({
    required this.id,
    required this.date,
    required this.pose,
    this.weightKg,
  });

  final String id;
  final DateTime date;
  final PhotoPose pose;

  /// Body weight that day, if logged.
  final double? weightKg;

  Map<String, Object?> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'pose': pose.name,
    'kg': ?weightKg,
  };

  static ProgressPhoto? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final date = DateTime.tryParse('${json['date']}');
    final kg = json['kg'];
    if (id is! String || date == null) return null;
    return ProgressPhoto(
      id: id,
      date: date,
      pose:
          PhotoPose.values.where((p) => p.name == json['pose']).firstOrNull ??
          PhotoPose.front,
      weightKg: kg is num ? kg.toDouble() : null,
    );
  }
}

/// Progress photos: an index in the encrypted store, images in the
/// encrypted [PhotoVault].
class PhotoStore extends ChangeNotifier {
  PhotoStore(
    this._repo,
    this._health,
    this._vault, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const _key = 'photos';

  final HealthRepository _repo;
  final HealthStore _health;
  final PhotoVault _vault;
  final DateTime Function() _clock;
  List<ProgressPhoto> _photos = [];
  bool _readable = true;

  /// Recently viewed photos, oldest first (decrypted, so kept small).
  final Map<String, Uint8List> _cache = {};
  static const _cacheSize = 8;

  void _remember(String id, Uint8List bytes) {
    _cache
      ..remove(id)
      ..[id] = bytes;
    while (_cache.length > _cacheSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Newest first.
  List<ProgressPhoto> get photos => List.unmodifiable(_photos);

  Future<void> load() async {
    _readable = true;
    try {
      final doc = await _repo.loadDocument(_key);
      final items = doc?['items'];
      if (items is List) {
        _photos = items.map(ProgressPhoto.tryFromJson).nonNulls.toList()
          ..sort((a, b) => b.date.compareTo(a.date));
      }
    } on Exception catch (e) {
      _readable = false;
      logError('PhotoStore: load failed: $e');
    }
    notifyListeners();
  }

  /// Cleans (metadata stripped, resized) and stores a photo. Returns null if
  /// [bytes] isn't an image.
  Future<ProgressPhoto?> add(
    List<int> bytes, {
    required PhotoPose pose,
    double? weightKg,
    DateTime? date,
  }) async {
    Uint8List? clean;
    try {
      clean = await compute(
        PhotoVault.stripAndResize,
        Uint8List.fromList(bytes),
      );
      // The decoder reads untrusted files and may fail with an Error on a
      // malformed one: refuse the photo instead of crashing.
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      logError('PhotoStore: could not read photo: $e');
      return null;
    }
    if (clean == null) return null;
    final photo = ProgressPhoto(
      id: 'p${_clock().microsecondsSinceEpoch}',
      date: date ?? _clock(),
      pose: pose,
      weightKg: weightKg,
    );
    await _vault.write(photo.id, clean);
    _remember(photo.id, clean);
    _photos = [photo, ..._photos]..sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    await _save();
    return photo;
  }

  /// The decrypted image (cached after the first read).
  Future<Uint8List?> image(String id) async {
    final cached = _cache[id];
    if (cached != null) {
      _remember(id, cached);
      return cached;
    }
    final bytes = await _vault.read(id);
    if (bytes != null) _remember(id, bytes);
    return bytes;
  }

  Future<void> delete(String id) async {
    _photos = _photos.where((p) => p.id != id).toList();
    _cache.remove(id);
    notifyListeners();
    // Keep the file while the list can't be saved, so nothing points at a
    // missing image.
    if (await _save()) await _vault.delete(id);
  }

  /// Deletes every photo file (used by Erase All).
  Future<void> eraseAll() async {
    _photos = [];
    _readable = true;
    _cache.clear();
    notifyListeners();
    await _vault.deleteAll();
  }

  /// Whether the list was saved.
  Future<bool> _save() async {
    if (!_readable) {
      logError('PhotoStore: not saving over photos that could not be read');
      return false;
    }
    final json = {
      'items': [for (final p in _photos) p.toJson()],
    };
    // The write queue reports a failure by counting it, not by throwing.
    final failuresBefore = _health.saveFailures;
    await _health.saveDocument(_key, json);
    return _health.saveFailures == failuresBefore;
  }
}
