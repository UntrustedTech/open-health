import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Logs a problem: printed in debug builds, and kept in the [ErrorLog] on
/// the phone so the user can share it. Nothing is ever sent by itself, and
/// release builds never write to the system log.
void logError(String message) {
  if (kDebugMode) debugPrint(message);
  ErrorLog.add(message);
}

/// One problem in the [ErrorLog].
typedef LoggedError = ({DateTime at, String message});

/// The most recent problems, newest last (Settings → About → Error Log).
///
/// Only an error's first line and stack frames are kept: messages like a
/// JSON parse error can quote the data that failed, and health data must
/// not leave the encrypted store this way.
abstract final class ErrorLog {
  static const max = 50;
  static const _maxLine = 300;
  static const _maxFrames = 12;

  static final _entries = <LoggedError>[];
  static File? _file;
  static Timer? _pending;

  /// Notified when an error is added or the log is cleared.
  static final changes = ValueNotifier<int>(0);

  static List<LoggedError> get entries => List.unmodifiable(_entries);

  /// Keeps the log in [file], loading what an earlier run left there.
  static Future<void> attach(File file) async {
    _file = file;
    try {
      if (!file.existsSync()) return;
      final saved = jsonDecode(await file.readAsString());
      if (saved is! List) return;
      final earlier = [
        for (final e in saved)
          if (e is Map && e['message'] is String)
            if (DateTime.tryParse('${e['at']}') case final at?)
              (at: at, message: e['message'] as String),
      ];
      _entries.insertAll(0, earlier);
      _trim();
      changes.value++;
      // Errors logged before the file was attached are kept too.
      if (earlier.length != _entries.length) _persistSoon();
    } on Object catch (e) {
      // A damaged log isn't worth more than starting a fresh one.
      if (kDebugMode) debugPrint('ErrorLog: could not read: $e');
    }
  }

  static void add(String message, {DateTime? at}) {
    _entries.add((at: at ?? DateTime.now(), message: redact(message)));
    _trim();
    // Not straight away: an error can be logged while a frame is built.
    scheduleMicrotask(() => changes.value++);
    _persistSoon();
  }

  static Future<void> clear() async {
    _entries.clear();
    changes.value++;
    _pending?.cancel();
    try {
      await _file?.delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  /// The log as plain text, for sharing.
  static String asText({String header = ''}) => [
    if (header.isNotEmpty) header,
    for (final e in _entries.reversed)
      '[${e.at.toIso8601String()}] ${e.message}',
  ].join('\n\n');

  /// [message]'s first line and its stack frames, shortened.
  @visibleForTesting
  static String redact(String message) {
    final lines = message.split('\n');
    final first = lines.first.length > _maxLine
        ? '${lines.first.substring(0, _maxLine)}…'
        : lines.first;
    final frames = lines
        .skip(1)
        .where((l) => l.startsWith('#'))
        .take(_maxFrames)
        .map((l) => l.length > _maxLine ? l.substring(0, _maxLine) : l);
    return [first, ...frames].join('\n');
  }

  static void _trim() {
    if (_entries.length > max) _entries.removeRange(0, _entries.length - max);
  }

  static void _persistSoon() {
    if (_file == null) return;
    _pending?.cancel();
    _pending = Timer(const Duration(seconds: 2), () => unawaited(_persist()));
  }

  static Future<void> _persist() async {
    final file = _file;
    if (file == null) return;
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode([
          for (final e in _entries)
            {'at': e.at.toIso8601String(), 'message': e.message},
        ]),
        flush: true,
      );
    } on FileSystemException catch (e) {
      if (kDebugMode) debugPrint('ErrorLog: could not save: $e');
    }
  }
}
