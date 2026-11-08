import 'package:workmanager/workmanager.dart';

/// Runs the background Health Connect sync every so often.
abstract interface class BackgroundScheduler {
  /// Starts periodic background syncs, [every] apart. With [replace] the
  /// timing restarts (for a changed setting); without it an existing
  /// schedule is kept as is (e.g. on every app launch).
  Future<void> schedule(Duration every, {bool replace = true});

  /// Stops background syncs.
  Future<void> cancel();
}

/// For platforms and tests without background work.
class NoBackgroundScheduler implements BackgroundScheduler {
  const NoBackgroundScheduler();

  @override
  Future<void> schedule(Duration every, {bool replace = true}) async {}

  @override
  Future<void> cancel() async {}
}

/// Android's WorkManager, through the `workmanager` package. The system
/// may run a check later than asked (to save battery) but never more often.
class WorkmanagerScheduler implements BackgroundScheduler {
  const WorkmanagerScheduler();

  /// The one periodic task's unique name and task name.
  static const task = 'health-connect-sync';

  @override
  Future<void> schedule(Duration every, {bool replace = true}) =>
      Workmanager().registerPeriodicTask(
        task,
        task,
        frequency: every,
        existingWorkPolicy: replace
            ? ExistingPeriodicWorkPolicy.update
            : ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.notRequired),
      );

  @override
  Future<void> cancel() => Workmanager().cancelByUniqueName(task);
}
