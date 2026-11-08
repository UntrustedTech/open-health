import 'package:flutter/foundation.dart';

import 'package:health_app/utils/log.dart';

/// Runs storage writes one after another, so a slow save can never land
/// after a newer one (e.g. resurrecting data after "Erase All"). Shared by
/// every store that writes to the same repository.
class WriteQueue extends ChangeNotifier {
  Future<void> _tail = Future.value();

  /// What failed to save and hasn't been saved since, by write key.
  final _failedKeys = <String>{};
  int _failures = 0;

  /// The key of a write that replaces everything (e.g. "Erase All").
  static const everything = '*';

  /// True while a write failed and nothing has saved the same data since;
  /// the UI shows a warning. Writes save whole documents, so a later
  /// success of the same key also saves the change that failed.
  bool get failed => _failedKeys.isNotEmpty;

  /// How many writes have ever failed. Unlike [failed], a later success
  /// doesn't reset it, so a batch of writes can tell whether any of its
  /// own failed by comparing the count before and after.
  int get failures => _failures;

  /// Appends a write of [key] (a document; writes without one share a
  /// key). Failures are recorded rather than thrown, so callers can fire
  /// and forget safely.
  Future<void> run(Future<void> Function() write, {String? key}) {
    final k = key ?? '';
    final next = _tail.then((_) async {
      try {
        await write();
        final before = _failedKeys.length;
        if (k == everything) {
          _failedKeys.clear();
        } else {
          _failedKeys.remove(k);
        }
        if (_failedKeys.length != before) notifyListeners();
        // Any failure, even an unexpected Error, must not break the chain,
        // or no later write would ever run.
        // ignore: avoid_catches_without_on_clauses
      } catch (e, st) {
        logError('WriteQueue: save of "$k" failed: $e\n$st');
        _failedKeys.add(k);
        _failures++;
        notifyListeners();
      }
    });
    _tail = next;
    return next;
  }
}
