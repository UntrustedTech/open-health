import 'package:health_app/backup/auto_backup.dart';

/// A backup folder in memory.
class FakeBackupFolder implements BackupFolder {
  final files = <String, ({String name, String text, DateTime modified})>{};
  bool access = true;
  PickedFolder? toPick = (tree: 'tree:1', name: 'Backups');
  var _clock = DateTime(2026);

  @override
  Future<PickedFolder?> pick() async => toPick;

  @override
  Future<bool> hasAccess(String tree) async => access;

  @override
  Future<void> write(String tree, String name, String text) async {
    _clock = _clock.add(const Duration(minutes: 1));
    files['doc:$name'] = (name: name, text: text, modified: _clock);
  }

  @override
  Future<List<FolderFile>> list(String tree) async => [
    for (final MapEntry(:key, :value) in files.entries)
      (doc: key, name: value.name, modified: value.modified),
  ];

  @override
  Future<void> delete(String doc) async => files.remove(doc);
}

class FakeSecret implements SecretStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? v) async => value = v;
}
