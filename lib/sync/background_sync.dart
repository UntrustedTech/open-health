import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/data/value_cipher.dart';
import 'package:health_app/notifications/notifier.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/sync/background_scheduler.dart';
import 'package:health_app/sync/health_connect_source.dart';
import 'package:health_app/sync/health_sync_service.dart';
import 'package:health_app/update/update_checker.dart';
import 'package:health_app/utils/log.dart';

/// The storage key lives in the Android Keystore / iOS Keychain. Returns
/// null if it can't be read; the app then stays locked rather than risk
/// the data. [onKeyMissing] is called if the key isn't there at all.
Future<ValueCipher?> loadStorageCipher(
  SharedPreferencesAsync prefs, {
  void Function()? onKeyMissing,
}) async {
  try {
    return await AesGcmCipher.fromSecureStorage(
      hasEncryptedData: SharedPrefsHealthRepository(prefs).hasEncryptedData,
    );
  } on StorageKeyMissing catch (e) {
    logError('Secure storage: $e');
    onKeyMissing?.call();
    return null;
  } on Exception catch (e) {
    logError('Secure storage unavailable: $e');
    return null;
  }
}

/// Whether the app is open on screen, shared with background checks so
/// they never write the data while the app is also writing it.
abstract final class AppPresence {
  static const _key = 'appInForeground';
  static const _atKey = 'appPresenceAt';
  static const _savedKey = 'backgroundSavedAt';

  /// How often the open app renews its mark, and after how long a mark
  /// that wasn't renewed counts as left over from a crash.
  static const heartbeat = Duration(minutes: 10);
  static const _stale = Duration(minutes: 30);

  /// Records whether the app is open. Never throws: a missing mark only
  /// means a background check may run, which its save check covers.
  static Future<void> mark({required bool open}) async {
    try {
      final prefs = SharedPreferencesAsync();
      await prefs.setBool(_key, open);
      await prefs.setString(_atKey, DateTime.now().toIso8601String());
    } on Object catch (e) {
      logError('AppPresence: could not save: $e');
    }
  }

  static Future<bool> isOpen(SharedPreferencesAsync prefs) async {
    if (await prefs.getBool(_key) != true) return false;
    final at = DateTime.tryParse(await prefs.getString(_atKey) ?? '');
    return at != null && DateTime.now().difference(at) < _stale;
  }

  /// Notes that a background check saved data, so the app reloads it.
  static Future<void> markBackgroundSaved(SharedPreferencesAsync prefs) =>
      prefs.setString(_savedKey, DateTime.now().toIso8601String());

  /// When a background check last saved data, if ever (null too when it
  /// can't be told).
  static Future<DateTime?> backgroundSavedAt() async {
    try {
      final prefs = SharedPreferencesAsync();
      return DateTime.tryParse(await prefs.getString(_savedKey) ?? '');
    } on Object catch (e) {
      logError('AppPresence: could not read: $e');
      return null;
    }
  }
}

/// Runs in its own Flutter engine when the system starts a background
/// check: loads the data, syncs with Health Connect once, and saves.
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      if (task == UpdateChecker.dailyTask) {
        await runBackgroundUpdateCheck();
      } else {
        await runBackgroundSync();
      }
    } on Object catch (e) {
      logError('Background task $task failed: $e');
    }
    // Always "done": a failed check waits for the next one rather than
    // retrying straight away.
    return true;
  });
}

/// One background check. Skipped while the app is open (it syncs itself)
/// or if storage can't be unlocked.
Future<void> runBackgroundSync() async {
  final prefs = SharedPreferencesAsync();
  if (await AppPresence.isOpen(prefs)) return;
  final cipher = await loadStorageCipher(prefs);
  if (cipher == null) return;
  final repo = SharedPrefsHealthRepository(prefs, cipher: cipher);
  final health = HealthStore(repo);
  final workouts = WorkoutStore(repo, health);
  await health.load();
  await workouts.load();
  final sync = HealthSyncService(
    source: HealthConnectSource(),
    store: health,
    repo: repo,
    workouts: workouts,
    scheduler: const WorkmanagerScheduler(),
  );
  // This run is the schedule; don't change it from in here.
  await sync.init(schedule: false);
  if (!sync.connected || !sync.backgroundSync) return;
  // Access removed meanwhile: the app turns the setting off when opened.
  if (!await HealthConnectSource().hasBackgroundAccess()) return;
  await sync.sync(
    force: true,
    trigger: SyncTrigger.background,
    // The app may have opened (and changed the data) during the reads;
    // then the app's copy wins and this run's results are dropped.
    canSave: () async => !await AppPresence.isOpen(prefs),
  );
  await AppPresence.markBackgroundSaved(prefs);
}

/// The daily update check: a notification for a newer build, and the app
/// shows its pop-up the next time it opens.
Future<void> runBackgroundUpdateCheck() async {
  final prefs = SharedPreferencesAsync();
  final checker = UpdateChecker(
    prefs: prefs,
    currentBuild: int.tryParse((await PackageInfo.fromPlatform()).buildNumber),
  );
  await checker.check(force: true);
  if (!await checker.shouldNotify()) return;
  await LocalNotifier().showUpdate();
  await checker.markNotified();
}
