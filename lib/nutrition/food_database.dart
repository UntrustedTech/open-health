import 'dart:async';
import 'dart:convert';
import 'dart:io' hide BytesBuilder;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:health_app/models/food.dart';
import 'package:health_app/utils/log.dart';

/// A food in the database, nutrition per 100 g.
@immutable
class DatabaseFood {
  const DatabaseFood({
    required this.id,
    required this.name,
    required this.category,
    required this.per100g,
    this.portions = const [],
  });

  final String id;
  final String name;
  final String category;
  final Nutrients per100g;

  /// Common portions: label and grams.
  final List<(String, double)> portions;

  static DatabaseFood? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'], name = json['name'];
    if (id is! String || id.isEmpty || id.length > 60) return null;
    if (name is! String || name.trim().isEmpty) return null;
    final n = Nutrients.fromJson(json['n']);
    if (n.kcal <= 0 || !n.isFinite) return null;
    final cat = json['cat'];
    return DatabaseFood(
      id: id,
      name: name.length > 100 ? name.substring(0, 100) : name,
      category: cat is String ? cat : '',
      per100g: n,
      portions: [
        if (json['p'] case final List list)
          for (final p in list.take(6))
            if (p case [final String label, final num grams]
                when grams > 0 && grams < 5000 && label.isNotEmpty)
              (
                label.length > 50 ? label.substring(0, 50) : label,
                grams.toDouble(),
              ),
      ],
    );
  }

  /// As a [Food] to log: per its first common portion, else per 100 g.
  Food toFood() {
    final liquid = category == 'Beverages';
    final unit = liquid ? 'ml' : 'g';
    final portion = portions.firstOrNull;
    final grams = portion?.$2 ?? 100;
    return Food(
      id: 'db:$id',
      name: name,
      servingLabel: portion == null
          ? '100 $unit'
          : '${portion.$1} (${_amount(grams)} $unit)',
      servingGrams: grams,
      perServing: per100g * (grams / 100),
      source: FoodSource.database,
      liquid: liquid,
    );
  }

  static String _amount(double g) =>
      g == g.roundToDouble() ? '${g.round()}' : g.toStringAsFixed(1);
}

/// The Health food database: everyday foods with vitamins and minerals,
/// from github.com/UntrustedTech/health-foods (USDA FoodData Central and
/// hand-added foods). Downloaded once, kept on the phone, and refreshed
/// every [maxAge], so search works offline. Only the file is fetched;
/// nothing about the user is sent.
class FoodDatabase extends ChangeNotifier {
  FoodDatabase({
    required Future<Directory> Function() directory,
    Future<FoodDownload> Function(Uri, String? etag)? fetch,
  }) : // Named parameters can't be private.
       // ignore: prefer_initializing_formals
       _directory = directory,
       _fetch = fetch ?? _download;

  static final source = Uri.https(
    'raw.githubusercontent.com',
    '/UntrustedTech/health-foods/main/foods.json',
  );
  static const maxAge = Duration(days: 7);

  final Future<Directory> Function() _directory;
  final Future<FoodDownload> Function(Uri, String?) _fetch;

  List<DatabaseFood> _foods = const [];
  List<String> _names = const [];
  DateTime? _updated;
  bool _updating = false;
  bool _failed = false;

  /// How many foods it has (0 until downloaded).
  int get count => _foods.length;
  bool get isEmpty => _foods.isEmpty;

  /// When it was last downloaded or confirmed current.
  DateTime? get updated => _updated;
  bool get updating => _updating;

  /// Whether the last download failed (e.g. offline).
  bool get failed => _failed;

  /// Reads the copy on the phone, then refreshes it if it's old.
  Future<void> load({DateTime? now}) async {
    try {
      final dir = await _directory();
      final file = File('${dir.path}/$_file');
      final meta = await _readMeta(dir);
      if (await file.exists()) {
        _set(await compute(_parse, await file.readAsString()));
        _updated = meta.updated;
        notifyListeners();
      }
    } on Exception catch (e) {
      logError('FoodDatabase: could not read: $e');
    }
    unawaited(refresh(now: now));
  }

  /// Downloads a newer copy, unless the one here is under [maxAge] old.
  Future<void> refresh({DateTime? now, bool force = false}) async {
    if (_updating) return;
    final at = now ?? DateTime.now();
    final last = _updated;
    if (!force && last != null && at.difference(last) < maxAge) return;
    _updating = true;
    notifyListeners();
    try {
      final dir = await _directory();
      final meta = await _readMeta(dir);
      final got = await _fetch(source, isEmpty ? null : meta.etag);
      switch (got) {
        case FoodDownloadUnchanged():
          _updated = at;
          _failed = false;
          await _writeMeta(dir, _Meta(at, meta.etag));
        case FoodDownloadBody(:final body, :final etag):
          final foods = await compute(_parse, body);
          if (foods.isEmpty) throw const FormatException();
          final tmp = File('${dir.path}/$_file.tmp');
          await tmp.writeAsString(body, flush: true);
          await tmp.rename('${dir.path}/$_file');
          _set(foods);
          _updated = at;
          _failed = false;
          await _writeMeta(dir, _Meta(at, etag));
        case FoodDownloadFailed():
          _failed = true;
      }
    } on Exception catch (e) {
      logError('FoodDatabase: could not update: $e');
      _failed = true;
    } finally {
      _updating = false;
      notifyListeners();
    }
  }

  void _set(List<DatabaseFood> foods) {
    _foods = foods;
    _names = [for (final f in foods) _fold(f.name)];
  }

  /// Foods whose names have every word of [query], best matches first:
  /// names starting with it, then whole words, then shorter names.
  List<DatabaseFood> search(String query, {int limit = 30}) {
    final words = _fold(query)
        .split(RegExp(r'[\s,]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty || _foods.isEmpty) return const [];
    final hits = <(int, int)>[];
    for (var i = 0; i < _names.length; i++) {
      final name = _names[i];
      if (!words.every(name.contains)) continue;
      var score = name.length;
      if (name.startsWith(words.first)) score -= 1000;
      for (final w in words) {
        if (RegExp('(^|[ ,(])${RegExp.escape(w)}').hasMatch(name)) {
          score -= 100;
        }
      }
      // "raw" and plain forms before processed ones.
      score += ','.allMatches(name).length * 8;
      hits.add((score, i));
    }
    hits.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final (_, i) in hits.take(limit)) _foods[i]];
  }

  static String _fold(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[àáâãä]'), 'a')
      .replaceAll(RegExp('[èéêë]'), 'e')
      .replaceAll(RegExp('[ìíîï]'), 'i')
      .replaceAll(RegExp('[òóôõö]'), 'o')
      .replaceAll(RegExp('[ùúûü]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll('ç', 'c');

  static const _file = 'food_database.json';
  static const _metaFile = 'food_database_meta.json';

  static List<DatabaseFood> _parse(String body) {
    final json = jsonDecode(body);
    if (json is! Map<String, Object?> || json['format'] != 1) {
      throw const FormatException();
    }
    final foods = json['foods'];
    if (foods is! List) return const [];
    return [for (final f in foods) ?DatabaseFood.fromJson(f)];
  }

  static Future<_Meta> _readMeta(Directory dir) async {
    try {
      final file = File('${dir.path}/$_metaFile');
      if (!await file.exists()) return const _Meta(null, null);
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, Object?>) return const _Meta(null, null);
      final at = json['updated'], etag = json['etag'];
      return _Meta(
        at is String ? DateTime.tryParse(at) : null,
        etag is String ? etag : null,
      );
    } on FormatException {
      return const _Meta(null, null);
    }
  }

  static Future<void> _writeMeta(Directory dir, _Meta meta) =>
      File('${dir.path}/$_metaFile').writeAsString(
        jsonEncode({
          'updated': meta.updated?.toIso8601String(),
          'etag': meta.etag,
        }),
      );

  static const _timeout = Duration(seconds: 30);
  static const _maxBytes = 40 * 1024 * 1024;

  static Future<FoodDownload> _download(Uri url, String? etag) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final req = await client.getUrl(url).timeout(_timeout);
      req.followRedirects = false;
      if (etag != null) req.headers.set(HttpHeaders.ifNoneMatchHeader, etag);
      final res = await req.close().timeout(_timeout);
      if (res.statusCode == 304) {
        await res.drain<void>();
        return const FoodDownloadUnchanged();
      }
      if (res.statusCode != 200) {
        await res.drain<void>();
        logError('FoodDatabase: HTTP ${res.statusCode}');
        return const FoodDownloadFailed();
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in res.timeout(_timeout)) {
        bytes.add(chunk);
        if (bytes.length > _maxBytes) return const FoodDownloadFailed();
      }
      return FoodDownloadBody(
        utf8.decode(bytes.takeBytes(), allowMalformed: true),
        res.headers.value(HttpHeaders.etagHeader),
      );
    } on SocketException {
      return const FoodDownloadFailed();
    } on TimeoutException {
      return const FoodDownloadFailed();
    } on HttpException catch (e) {
      logError('FoodDatabase: $e');
      return const FoodDownloadFailed();
    } finally {
      client.close(force: true);
    }
  }
}

@immutable
class _Meta {
  const _Meta(this.updated, this.etag);
  final DateTime? updated;
  final String? etag;
}

/// What a download of the database gave.
sealed class FoodDownload {
  const FoodDownload();
}

class FoodDownloadBody extends FoodDownload {
  const FoodDownloadBody(this.body, this.etag);
  final String body;
  final String? etag;
}

/// The copy here is current (HTTP 304).
class FoodDownloadUnchanged extends FoodDownload {
  const FoodDownloadUnchanged();
}

class FoodDownloadFailed extends FoodDownload {
  const FoodDownloadFailed();
}
