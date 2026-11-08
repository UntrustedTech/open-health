import 'dart:isolate';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:health_app/data/value_cipher.dart';
import 'package:health_app/models/health_entry.dart';
import 'package:health_app/utils/log.dart';

/// Thrown when stored data exists but can't be decrypted or parsed. The
/// original is kept as a backup before this is thrown.
class UnreadableDataException implements Exception {
  const UnreadableDataException(this.key);

  final String key;

  @override
  String toString() => 'UnreadableDataException: $key';
}

/// Storage boundary for the app. Swap the implementation (e.g. for a database
/// or Health Connect / HealthKit sync) without touching the UI.
abstract interface class HealthRepository {
  Future<List<HealthEntry>> loadEntries();
  Future<void> saveEntries(List<HealthEntry> entries);

  /// Loads a small JSON document such as the profile, goals or settings.
  /// Throws [UnreadableDataException] if it exists but can't be read.
  Future<Map<String, Object?>?> loadDocument(String key);
  Future<void> saveDocument(String key, Map<String, Object?> value);
  Future<void> deleteDocument(String key);

  /// Removes everything the app has stored.
  Future<void> clear();

  /// What couldn't be read since the app started (document keys, or
  /// [entriesKey]), each with its original kept as a backup.
  Set<String> get unreadable;
}

/// The key [HealthRepository.unreadable] uses for the health entries.
const entriesKey = 'entries';

/// Stores everything in SharedPreferences, encrypted with [cipher] when one
/// is given. Plain-text data from older versions is read and re-encrypted.
class SharedPrefsHealthRepository implements HealthRepository {
  SharedPrefsHealthRepository(this._prefs, {this._cipher});

  static const _entriesKey = 'entries.v1';
  static const _backupPrefix = 'entries.v1.backup.';
  static const _docPrefix = 'doc.v1.';

  /// Encrypted with the storage key as context (see [ValueCipher.encrypt]).
  static const _encryptedPrefix = 'enc2:';

  /// Encrypted without context, by older versions; rewritten when read.
  static const _unboundPrefix = 'enc1:';

  final SharedPreferencesAsync _prefs;
  final ValueCipher? _cipher;

  @override
  final Set<String> unreadable = {};

  /// Reads and decrypts a value. Returns `(text: null, raw)` when it can't be
  /// decrypted, so callers can keep the raw value as a backup.
  Future<({String? text, String? raw})> _read(String key) async {
    final raw = await _prefs.getString(key);
    final cipher = _cipher;
    if (raw == null) return (text: null, raw: null);
    final bound = raw.startsWith(_encryptedPrefix);
    if (!bound && !raw.startsWith(_unboundPrefix)) {
      // Plain text from an older version: encrypt it now.
      if (cipher != null) await _migrate(key, raw, raw);
      return (text: raw, raw: raw);
    }
    if (cipher == null) return (text: null, raw: raw);
    try {
      final text = await cipher.decrypt(
        raw.substring(_encryptedPrefix.length),
        context: bound ? key : '',
      );
      if (!bound) await _migrate(key, raw, text);
      return (text: text, raw: raw);
    } on CipherException catch (e) {
      logError('HealthRepository: could not decrypt $key: $e');
      return (text: null, raw: raw);
    }
  }

  /// Whether [key] is one this repository stores data under (others hold
  /// flags and settings of other types, which can't be read as text).
  static bool _isDataKey(String key) =>
      key == _entriesKey ||
      key.startsWith(_backupPrefix) ||
      key.startsWith(_docPrefix) ||
      key.startsWith('backup.doc.');

  /// True if anything was saved encrypted (used to protect the key).
  Future<bool> hasEncryptedData() async {
    for (final key in (await _prefs.getKeys()).where(_isDataKey)) {
      final value = await _prefs.getString(key);
      if (value != null &&
          (value.startsWith(_encryptedPrefix) ||
              value.startsWith(_unboundPrefix))) {
        return true;
      }
    }
    return false;
  }

  Future<String> _encode(String key, String plain) async {
    final cipher = _cipher;
    return cipher == null
        ? plain
        : '$_encryptedPrefix${await cipher.encrypt(plain, context: key)}';
  }

  Future<void> _write(String key, String plain) async =>
      _prefs.setString(key, await _encode(key, plain));

  /// Rewrites [key] in the current format, unless it changed since it was
  /// read as [raw]: a save made meanwhile must not be replaced by the
  /// older text.
  Future<void> _migrate(String key, String raw, String plain) async {
    final value = await _encode(key, plain);
    if (await _prefs.getString(key) == raw) await _prefs.setString(key, value);
  }

  @override
  Future<List<HealthEntry>> loadEntries() async {
    final (:text, :raw) = await _read(_entriesKey);
    if (raw == null) return [];
    // Years of readings take a while to parse: off the UI thread, so the
    // app stays smooth while it starts.
    final (:entries, :readAll) = text == null
        ? (entries: <HealthEntry>[], readAll: false)
        : text.length > _parseInBackgroundOver
        ? await Isolate.run(() => _parseEntries(text))
        : _parseEntries(text);
    // If anything could not be read, keep the original text before the app
    // overwrites it with the readable subset, so no data is lost for good.
    if (!readAll) {
      unreadable.add(entriesKey);
      // Keep only the newest backup so copies of health data don't pile up.
      final keys = await _prefs.getKeys();
      for (final key in keys.where((k) => k.startsWith(_backupPrefix))) {
        await _prefs.remove(key);
      }
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await _prefs.setString('$_backupPrefix$stamp', raw);
    }
    return entries;
  }

  /// Characters of entries above which they're parsed in an isolate.
  static const _parseInBackgroundOver = 200000;

  /// The entries in [text], and whether every one could be read.
  static ({List<HealthEntry> entries, bool readAll}) _parseEntries(
    String text,
  ) {
    final decoded = _tryDecode(text);
    if (decoded is! List) return (entries: <HealthEntry>[], readAll: false);
    final entries = [
      for (final item in decoded)
        if (item is Map<String, Object?>) HealthEntry.tryFromJson(item),
    ].nonNulls.toList();
    return (entries: entries, readAll: entries.length == decoded.length);
  }

  @override
  Future<void> saveEntries(List<HealthEntry> entries) =>
      _write(_entriesKey, jsonEncode([for (final e in entries) e.toJson()]));

  @override
  Future<Map<String, Object?>?> loadDocument(String key) async {
    final (:text, :raw) = await _read('$_docPrefix$key');
    if (raw == null) return null;
    final decoded = text == null ? null : _tryDecode(text);
    if (decoded is Map<String, Object?>) return decoded;
    unreadable.add(key);
    // Keep the original before anything can overwrite it: one copy per
    // document, as several readers may hit the same damaged one.
    final prefix = 'backup.doc.$key.';
    final kept = (await _prefs.getKeys()).where((k) => k.startsWith(prefix));
    if (!await _keepsCopyOf(kept, raw)) {
      for (final old in kept) {
        await _prefs.remove(old);
      }
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await _prefs.setString('$prefix$stamp', raw);
    }
    throw UnreadableDataException(key);
  }

  Future<bool> _keepsCopyOf(Iterable<String> keys, String raw) async {
    for (final k in keys) {
      if (await _prefs.getString(k) == raw) return true;
    }
    return false;
  }

  @override
  Future<void> saveDocument(String key, Map<String, Object?> value) =>
      _write('$_docPrefix$key', jsonEncode(value));

  @override
  Future<void> deleteDocument(String key) => _prefs.remove('$_docPrefix$key');

  @override
  Future<void> clear() => _prefs.clear();

  static Object? _tryDecode(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }
}

/// Non-persistent repository used by tests and previews.
class InMemoryHealthRepository implements HealthRepository {
  List<HealthEntry> _entries = [];
  final Map<String, Map<String, Object?>> _docs = {};

  @override
  final Set<String> unreadable = {};

  @override
  Future<List<HealthEntry>> loadEntries() async => List.of(_entries);

  @override
  Future<void> saveEntries(List<HealthEntry> entries) async =>
      _entries = List.of(entries);

  @override
  Future<Map<String, Object?>?> loadDocument(String key) async => _docs[key];

  @override
  Future<void> saveDocument(String key, Map<String, Object?> value) async =>
      _docs[key] = value;

  @override
  Future<void> deleteDocument(String key) async => _docs.remove(key);

  @override
  Future<void> clear() async {
    _entries = [];
    _docs.clear();
  }
}
