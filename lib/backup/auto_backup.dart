import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

import 'package:health_app/export/backup_builder.dart';
import 'package:health_app/export/backup_crypto.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/utils/log.dart';

/// A folder the user picked, where backup files can be written later.
typedef PickedFolder = ({String tree, String name});

/// A backup file found in the folder.
typedef FolderFile = ({String doc, String name, DateTime modified});

/// Reads and writes backup files in a user-chosen folder.
abstract interface class BackupFolder {
  Future<PickedFolder?> pick();
  Future<bool> hasAccess(String tree);
  Future<void> write(String tree, String name, String text);
  Future<List<FolderFile>> list(String tree);
  Future<void> delete(String doc);
}

/// Android's Storage Access Framework, through MainActivity.
class SafBackupFolder implements BackupFolder {
  const SafBackupFolder([this._channel = const MethodChannel(_name)]);

  static const _name = 'health/backup_folder';
  final MethodChannel _channel;

  @override
  Future<PickedFolder?> pick() async {
    final r = await _channel.invokeMapMethod<String, Object?>('pick');
    final tree = r?['tree'], name = r?['name'];
    if (tree is! String) return null;
    return (tree: tree, name: name is String ? name : 'Folder');
  }

  @override
  Future<bool> hasAccess(String tree) async =>
      await _channel.invokeMethod<bool>('hasAccess', {'tree': tree}) ?? false;

  @override
  Future<void> write(String tree, String name, String text) =>
      _channel.invokeMethod<String>('write', {
        'tree': tree,
        'name': name,
        'text': text,
      });

  @override
  Future<List<FolderFile>> list(String tree) async {
    final rows =
        await _channel.invokeListMethod<Map<Object?, Object?>>('list', {
          'tree': tree,
        }) ??
        const [];
    return [
      for (final r in rows)
        if (r['doc'] case final String doc)
          (
            doc: doc,
            name: '${r['name']}',
            modified: DateTime.fromMillisecondsSinceEpoch(
              (r['modified'] as num?)?.toInt() ?? 0,
            ),
          ),
    ];
  }

  @override
  Future<void> delete(String doc) =>
      _channel.invokeMethod<bool>('delete', {'doc': doc});
}

/// Keeps the backup password in the Android Keystore.
abstract interface class SecretStore {
  Future<String?> read();
  Future<void> write(String? value);
}

class KeystoreSecret implements SecretStore {
  const KeystoreSecret([this._storage = const FlutterSecureStorage()]);

  static const _key = 'health.autobackup.password';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String? value) => value == null
      ? _storage.delete(key: _key)
      : _storage.write(key: _key, value: value);
}

enum BackupEvery {
  day('Daily', Duration(days: 1)),
  week('Weekly', Duration(days: 7));

  const BackupEvery(this.label, this.interval);

  final String label;
  final Duration interval;
}

/// Encrypted backups to a chosen folder, made when the app opens and the
/// last one is old enough. Older ones beyond [keep] are removed.
class AutoBackup extends ChangeNotifier {
  AutoBackup(
    this._health,
    this._workouts, {
    BackupFolder? folder,
    SecretStore? secret,
    this.iterations = BackupCrypto.iterations,
  }) : _folder = folder ?? const SafBackupFolder(),
       _secret = secret ?? const KeystoreSecret();

  static const docKey = 'autoBackup';
  static const keepOptions = [3, 5, 10];
  static final _stamp = DateFormat('yyyy-MM-dd HHmm');

  final HealthStore _health;
  final WorkoutStore _workouts;
  final BackupFolder _folder;
  final SecretStore _secret;

  /// Password hashing work (lowered in tests).
  final int iterations;

  bool _enabled = false;
  PickedFolder? _target;
  BackupEvery _every = BackupEvery.week;
  int _keep = 5;
  DateTime? _last;
  String? _error;
  bool _running = false;

  bool get enabled => _enabled;
  PickedFolder? get folder => _target;
  BackupEvery get every => _every;
  int get keep => _keep;
  DateTime? get lastBackup => _last;

  /// Why the last automatic backup failed, if it did.
  String? get error => _error;
  bool get running => _running;

  Future<void> load() async {
    try {
      final doc = (await _health.loadDocuments([docKey]))[docKey];
      _enabled = doc?['enabled'] == true;
      final tree = doc?['tree'], name = doc?['name'];
      _target = tree is String
          ? (tree: tree, name: name is String ? name : 'Folder')
          : null;
      _every = doc?['every'] == 'day' ? BackupEvery.day : BackupEvery.week;
      _keep = switch (doc?['keep']) {
        final int k when keepOptions.contains(k) => k,
        _ => 5,
      };
      _last = DateTime.tryParse('${doc?['last']}');
      _error = doc?['error'] is String ? doc!['error']! as String : null;
    } on Exception catch (e) {
      logError('AutoBackup: could not load: $e');
    }
    notifyListeners();
  }

  /// Turns automatic backups on with a folder and password.
  Future<void> enable(PickedFolder folder, String password) async {
    await _secret.write(password);
    _enabled = true;
    _target = folder;
    _error = null;
    notifyListeners();
    await _save();
  }

  Future<void> disable() async {
    _enabled = false;
    notifyListeners();
    await _secret.write(null);
    await _save();
  }

  /// Null when cancelled, or when the phone has no folder picker (then
  /// [error] says so).
  Future<PickedFolder?> pickFolder() async {
    try {
      return await _folder.pick();
      // MissingPluginException where there's no picker channel (iOS).
    } on Exception catch (e) {
      logError('AutoBackup: could not open the folder picker: $e');
      _error = "This phone can't choose a folder.";
      notifyListeners();
      return null;
    }
  }

  Future<void> changeFolder(PickedFolder folder) async {
    _target = folder;
    _error = null;
    notifyListeners();
    await _save();
  }

  Future<void> setEvery(BackupEvery every) async {
    _every = every;
    notifyListeners();
    await _save();
  }

  Future<void> setKeep(int keep) async {
    _keep = keep;
    notifyListeners();
    await _save();
  }

  bool get isDue {
    final last = _last;
    return last == null || !_health.now.isBefore(last.add(_every.interval));
  }

  /// Backs up when on and due (e.g. on app start). Never throws.
  Future<void> maybeRun() async {
    if (_enabled && isDue) await runNow();
  }

  /// Makes a backup now. Returns true on success; failures are kept in
  /// [error] to show in settings.
  Future<bool> runNow() async {
    final target = _target;
    if (!_enabled || target == null || _running) return false;
    _running = true;
    notifyListeners();
    try {
      if (!await _folder.hasAccess(target.tree)) {
        throw const _BackupFailure(
          'Health can no longer reach the backup folder. Choose it again.',
        );
      }
      final password = await _secret.read();
      if (password == null || password.isEmpty) {
        throw const _BackupFailure(
          'The backup password is missing. Turn automatic backups off and on.',
        );
      }
      final now = _health.now;
      final (:json, :skipped) = await buildBackupJson(
        health: _health,
        workouts: _workouts,
        now: now,
      );
      final sealed = await BackupCrypto.encrypt(
        json,
        password,
        iterations: iterations,
      );
      await _folder.write(
        target.tree,
        'Health Backup ${_stamp.format(now)}.json',
        sealed,
      );
      // Written: from here on this counts as done, even if tidying fails.
      _last = now;
      _error = null;
      // A backup missing something it couldn't read never replaces older
      // complete ones.
      if (skipped == 0) await _prune(target.tree);
      return true;
    } on _BackupFailure catch (e) {
      _error = e.message;
      return false;
    } on PlatformException catch (e) {
      logError('AutoBackup: folder error: $e');
      _error = 'Couldn\'t write to the backup folder.';
      return false;
    } on Exception catch (e) {
      logError('AutoBackup: failed: $e');
      _error = 'The last automatic backup failed.';
      return false;
    } finally {
      _running = false;
      notifyListeners();
      await _save();
    }
  }

  /// Keeps the newest [keep] backups and deletes the rest. Never throws:
  /// a backup that was written still counts.
  Future<void> _prune(String tree) async {
    final List<FolderFile> files;
    try {
      files = await _folder.list(tree);
    } on PlatformException catch (e) {
      logError('AutoBackup: could not list the folder: $e');
      return;
    }
    // By the time in the name ("Health Backup 2026-10-11 0930"): some
    // folders don't report when files changed. A folder may rename a
    // same-minute copy "... 0930 (1).json"; that one is newer.
    files.sort((a, b) {
      final (baseA, copyA) = _nameOrder(a.name);
      final (baseB, copyB) = _nameOrder(b.name);
      final byBase = baseB.compareTo(baseA);
      return byBase != 0 ? byBase : copyB.compareTo(copyA);
    });
    for (final f in files.skip(_keep)) {
      try {
        await _folder.delete(f.doc);
      } on PlatformException catch (e) {
        logError('AutoBackup: could not remove ${f.name}: $e');
      }
    }
  }

  static final _copySuffix = RegExp(r' \((\d+)\)(\.json)$');

  /// A backup's name without any " (n)" copy number, and that number.
  static (String, int) _nameOrder(String name) {
    final m = _copySuffix.firstMatch(name);
    if (m == null) return (name, 0);
    return (
      name.replaceRange(m.start, m.end, m.group(2)!),
      int.tryParse(m.group(1)!) ?? 0,
    );
  }

  /// Clears everything after "Erase All".
  Future<void> reset() async {
    _enabled = false;
    _target = null;
    _last = null;
    _error = null;
    notifyListeners();
    try {
      await _secret.write(null);
    } on Exception catch (e) {
      logError('AutoBackup: could not clear password: $e');
    }
  }

  Future<void> _save() => _health.saveDocument(docKey, {
    'enabled': _enabled,
    if (_target case final t?) 'tree': t.tree,
    if (_target case final t?) 'name': t.name,
    'every': _every.name,
    'keep': _keep,
    'last': ?_last?.toIso8601String(),
    'error': ?_error,
  });
}

class _BackupFailure implements Exception {
  const _BackupFailure(this.message);

  final String message;
}
