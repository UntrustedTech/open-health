import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:health_app/utils/log.dart';

/// Files handed to the share sheet. The receiving app may read a file
/// after sharing returns, so files are kept until the next share or the
/// next launch, then removed.
abstract final class ShareFiles {
  static Future<Directory> _dir() async =>
      Directory('${(await getTemporaryDirectory()).path}/share');

  /// A fresh, empty folder for a new file to share.
  static Future<Directory> prepare() async {
    await clear();
    final dir = await _dir();
    await dir.create(recursive: true);
    return dir;
  }

  /// Removes earlier shared files (they may contain health data).
  static Future<void> clear() async {
    try {
      final dir = await _dir();
      if (dir.existsSync()) await dir.delete(recursive: true);
    } on FileSystemException catch (e) {
      logError('ShareFiles: could not clear: $e');
    }
  }
}
