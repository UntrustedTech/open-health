import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'package:health_app/app.dart';
import 'package:health_app/backup/auto_backup.dart';
import 'package:health_app/screens/startup_failed_app.dart';
import 'package:health_app/screens/storage_locked_app.dart';
import 'package:health_app/app_lifecycle.dart';
import 'package:health_app/data/health_repository.dart';
import 'package:health_app/data/photo_vault.dart';
import 'package:health_app/export/share_files.dart';
import 'package:health_app/l10n/language.dart';
import 'package:health_app/notifications/habit_actions.dart';
import 'package:health_app/notifications/notification_controller.dart';
import 'package:health_app/notifications/notifier.dart';
import 'package:health_app/nutrition/food_database.dart';
import 'package:health_app/nutrition/open_food_facts.dart';
import 'package:health_app/platform/app_icons.dart';
import 'package:health_app/platform/device_profile.dart';
import 'package:health_app/platform/home_widgets.dart';
import 'package:health_app/security/app_lock.dart';
import 'package:health_app/state/achievement_store.dart';
import 'package:health_app/state/cycle_store.dart';
import 'package:health_app/state/sleep_schedule_store.dart';
import 'package:health_app/state/program_store.dart';
import 'package:health_app/state/gym_store.dart';
import 'package:health_app/state/mood_store.dart';
import 'package:health_app/state/fasting_store.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/medication_store.dart';
import 'package:health_app/state/nutrition_store.dart';
import 'package:health_app/state/photo_store.dart';
import 'package:health_app/state/exercise_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/sync/background_scheduler.dart';
import 'package:health_app/sync/background_sync.dart';
import 'package:health_app/sync/health_connect_source.dart';
import 'package:health_app/sync/health_source.dart';
import 'package:health_app/sync/health_sync_service.dart';
import 'package:health_app/update/update_checker.dart';
import 'package:health_app/update/whats_new.dart';
import 'package:health_app/utils/log.dart';
import 'package:health_app/workout/location_source.dart';

/// Licence texts listed in the app: name and asset.
const _licenses = [
  // Health itself, first.
  ('Health', 'LICENSE'),
  ('Inter', 'assets/fonts/Inter-LICENSE.txt'),
  // Exercise names, muscles and instructions (text only).
  ('exercises-dataset', 'assets/data/EXERCISES-LICENSE.txt'),
  // Body map outlines.
  ('MuscleMap', 'assets/data/MUSCLEMAP-LICENSE.txt'),
  // Exercise demonstration photos (public domain).
  ('free-exercise-db', 'assets/data/EXERCISE-MEDIA-LICENSE.txt'),
  // Food product data looked up by barcode or search.
  ('Open Food Facts', 'assets/data/OPEN-FOOD-FACTS-LICENSE.txt'),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Font licences appear in the app's licences list.
  LicenseRegistry.addLicense(() async* {
    for (final (name, asset) in _licenses) {
      yield LicenseEntryWithLineBreaks([
        name,
      ], await rootBundle.loadString(asset));
    }
  });
  // Unexpected errors are kept in the on-device error log (Settings →
  // About → Error Log) instead of crashing the app.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    logError('Flutter error: ${details.exceptionAsString()}\n${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logError('Uncaught error: $error\n$stack');
    return true;
  };
  // Until the first screen is shown, the launch screen stays up: a step
  // that fails or hangs must show what happened instead.
  var shown = false;
  try {
    await _start(onShown: () => shown = true);
    // Anything, so it's never a silent launch screen.
    // ignore: avoid_catches_without_on_clauses
  } catch (e, st) {
    if (shown) rethrow;
    logError('Startup failed: $e\n$st');
    runApp(StartupFailedApp(details: '$e'));
  }
}

/// How long a step before the first screen may take.
const _stepLimit = Duration(seconds: 15);

/// A step before the first screen that failed or didn't finish in time.
class _StartupFailure implements Exception {
  const _StartupFailure(this.step, this.error);

  final String step;
  final Object error;

  @override
  String toString() => '$step: $error';
}

/// Deletes data whose key is gone, so the app can start again with a new
/// key. Only for [StorageKeyMissing]: that data can never be opened.
Future<void> _eraseUnreadable(SharedPreferencesAsync prefs) async {
  try {
    await prefs.clear();
    final support = (await getApplicationSupportDirectory()).path;
    for (final name in ['photos']) {
      final dir = Directory('$support/$name');
      if (dir.existsSync()) await dir.delete(recursive: true);
    }
  } on Exception catch (e) {
    logError('Start fresh: $e');
  }
}

/// Runs a step that must finish before the first screen, within
/// [_stepLimit], naming it if it fails.
Future<T> _step<T>(String step, Future<T> Function() run) async {
  try {
    return await run().timeout(_stepLimit);
    // ignore: avoid_catches_without_on_clauses
  } catch (e) {
    throw _StartupFailure(step, e);
  }
}

Future<void> _start({
  required void Function() onShown,
  bool again = false,
}) async {
  if (!again) {
    try {
      await ErrorLog.attach(
        File('${(await getApplicationSupportDirectory()).path}/error_log.json'),
      ).timeout(_stepLimit);
    } on Exception catch (e) {
      logError('Error log unavailable: $e');
    }
  }

  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  final prefs = SharedPreferencesAsync();
  await AppPresence.mark(open: true).timeout(_stepLimit, onTimeout: () {});
  // Before anything is drawn, so even the first screen is translated.
  final language = LanguageController(prefs);
  await _step('language', language.load);
  var keyMissing = false;
  final cipher = await _step(
    'storage key',
    () => loadStorageCipher(prefs, onKeyMissing: () => keyMissing = true),
  );
  if (cipher == null) {
    // Never fall back to unencrypted storage, and never touch the data
    // unless asked to start fresh.
    runApp(
      StorageLockedApp(
        onStartFresh: keyMissing
            ? () async {
                await _eraseUnreadable(prefs);
                try {
                  await _start(onShown: () {}, again: true);
                  // Anything, so a failure still shows what happened.
                  // ignore: avoid_catches_without_on_clauses
                } catch (e, st) {
                  logError('Startup failed: $e\n$st');
                  runApp(StartupFailedApp(details: '$e'));
                }
              }
            : null,
      ),
    );
    onShown();
    return;
  }
  final repo = SharedPrefsHealthRepository(prefs, cipher: cipher);
  final health = HealthStore(repo);
  final workouts = WorkoutStore(repo, health);
  final exercises = ExerciseStore(repo, health);
  final photos = PhotoStore(
    repo,
    health,
    PhotoVault(
      directory: () async =>
          Directory('${(await getApplicationSupportDirectory()).path}/photos'),
      cipher: cipher,
    ),
  );
  final source = HealthConnectSource();
  // Background checks run in their own engine; see background_sync.dart.
  // The app works without them, so a failure here doesn't stop it.
  try {
    await Workmanager()
        .initialize(backgroundSyncDispatcher)
        .timeout(_stepLimit);
  } on Object catch (e) {
    logError('Background checks unavailable: $e');
  }
  final sync = HealthSyncService(
    source: source,
    store: health,
    repo: repo,
    workouts: workouts,
    // iOS has no reliable periodic background work for this (and Apple
    // Health can't be read while the phone is locked): sync on opening.
    scheduler: defaultTargetPlatform == TargetPlatform.iOS
        ? const NoBackgroundScheduler()
        : const WorkmanagerScheduler(),
  );
  // Started now, not after everything else has loaded: first-time setup
  // needs to know at once whether Health Connect can be asked for access.
  final syncReady = sync.init().catchError((Object e) {
    logError('HealthSync: could not start: $e');
  });
  final notifier = LocalNotifier();
  final notifications = NotificationController(repo, health, notifier);
  final medications = MedicationStore(health, notifier);
  final cycle = CycleStore(health);
  final mood = MoodStore(health);
  // The habit reminder skips a day once everything's ticked off.
  notifications.habitsDone = () => mood.habitsDoneToday;
  mood.addListener(() => unawaited(notifications.reschedule()));
  notifications.habitsToday = () =>
      (all: mood.habits, left: habitsLeft(mood, health.today));
  // Done taps on the habits notification are saved here while the app runs.
  listenForHabitActions(mood, health, notifications.showHabitsAgain);
  final gym = GymStore(health);
  final fasting = FastingStore(health, notifier);
  final sleepSchedule = SleepScheduleStore(health, notifier);
  final programs = ProgramStore(health, workouts);
  final nutrition = NutritionStore(health)..workoutKcalOn = workouts.kcalOn;
  // The budget includes workouts, so it changes when they do.
  workouts.addListener(nutrition.refresh);
  final achievements = AchievementStore(
    health,
    workouts,
    nutrition: nutrition,
    medications: medications,
    cycle: cycle,
    gym: gym,
    mood: mood,
    fasting: fasting,
  );
  // Before the first frame, so a locked app never shows its content.
  final autoBackup = AutoBackup(health, workouts);
  final appLock = AppLock(health);
  await _step('App Lock', appLock.load);

  final appIcons = AppIcons(health);
  // Notifications show the chosen icon; scheduled ones are made again.
  String? notificationPicture;
  appIcons.addListener(() {
    notifier.useIcon(appIcons.notificationColor, appIcons.picture);
    if (appIcons.picture == notificationPicture) return;
    notificationPicture = appIcons.picture;
    unawaited(notifications.reschedule());
    unawaited(medications.reschedule());
  });
  final updates = UpdateChecker(prefs: prefs);
  final foodDatabase = FoodDatabase(
    directory: () async => getApplicationSupportDirectory(),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: health),
        ChangeNotifierProvider.value(value: workouts),
        ChangeNotifierProvider.value(value: exercises),
        ChangeNotifierProvider.value(value: photos),
        ChangeNotifierProvider.value(value: sync),
        ChangeNotifierProvider.value(value: notifications),
        ChangeNotifierProvider.value(value: medications),
        ChangeNotifierProvider.value(value: cycle),
        ChangeNotifierProvider.value(value: mood),
        ChangeNotifierProvider.value(value: gym),
        ChangeNotifierProvider.value(value: fasting),
        ChangeNotifierProvider.value(value: sleepSchedule),
        ChangeNotifierProvider.value(value: programs),
        ChangeNotifierProvider.value(value: nutrition),
        Provider<OpenFoodFacts>.value(value: OpenFoodFacts()),
        ChangeNotifierProvider.value(value: foodDatabase),
        ChangeNotifierProvider.value(value: achievements),
        ChangeNotifierProvider.value(value: appLock),
        ChangeNotifierProvider.value(value: autoBackup),
        ChangeNotifierProvider.value(value: appIcons),
        ChangeNotifierProvider.value(value: updates),
        Provider.value(value: WhatsNew(prefs)),
        ChangeNotifierProvider.value(value: language),
        Provider<HealthSource>.value(value: source),
        Provider<LocationSource>.value(value: const GeolocatorSource()),
        FutureProvider<DeviceProfile>(
          create: (_) => DeviceProfile.detect(),
          initialData: DeviceProfile.unknown,
        ),
      ],
      child: const HealthApp(),
    ),
  );
  onShown();

  // Order matters: workouts and imports build on the loaded health data.
  // Each part loads on its own, so one that fails can't stop the rest.
  // Before loading: a background save from here on is reloaded at resume.
  noteDataLoaded();
  await _load('health', health.load);
  await _load('workouts', workouts.load);
  // The full exercise library; names fall back to built-ins until loaded.
  unawaited(_load('exercises', exercises.load));
  // These only read their own documents (and the health data above), so
  // they load side by side.
  await Future.wait([
    _load('reminders', notifications.load),
    _load('medications', medications.load),
    _load('cycle', cycle.load),
    _load('mood', mood.load),
    _load('gym', gym.load),
    _load('fasting', fasting.load),
    _load('sleep schedule', sleepSchedule.load),
    _load('programs', programs.load),
    _load('food', () async {
      await nutrition.load();
      await nutrition.saveGuessedGoal();
    }),
    _load('automatic backups', autoBackup.load),
    _load('photos', photos.load),
  ]);
  // Achievements are worked out from everything else.
  await _load('achievements', achievements.load);
  // Shows the notice if anything above couldn't be read.
  health.refresh();
  try {
    updates.currentBuild = int.tryParse(
      (await PackageInfo.fromPlatform()).buildNumber,
    );
  } on Exception catch (e) {
    logError('Updates: app build unavailable: $e');
  }
  unawaited(updates.check());
  unawaited(
    UpdateChecker.scheduleDaily().catchError((Object e) {
      logError('Updates: daily check not scheduled: $e');
    }),
  );
  unawaited(foodDatabase.load());
  unawaited(_load('icon', appIcons.load));
  await HomeWidgets.init();
  await HomeWidgets.drainPendingWater(health);
  // Shared exports from last time may hold health data.
  unawaited(ShareFiles.clear());
  await syncReady;
  unawaited(sync.autoSync(SyncTrigger.launch));
  unawaited(notifications.reschedule());
  unawaited(medications.reschedule());
  unawaited(sleepSchedule.reschedule());
  unawaited(fasting.reschedule());
  // Reminders and home screen widgets carry text: resend it when the
  // language changes.
  language.addListener(() {
    unawaited(notifications.reschedule());
    unawaited(medications.reschedule());
    unawaited(sleepSchedule.reschedule());
    unawaited(fasting.reschedule());
    unawaited(
      HomeWidgets.update(
        health,
        workouts,
        hidden: appLock.hidesWidgets,
        fasting: fasting,
      ),
    );
  });
  // After sync, so the backup includes the latest data.
  unawaited(autoBackup.maybeRun());
  // The "+250 ml" widget button (on iPhone it runs in the widget itself).
  if (defaultTargetPlatform == TargetPlatform.android) {
    unawaited(
      HomeWidget.registerInteractivityCallback(homeWidgetBackgroundCallback),
    );
  }
  AppCoordinator(health, workouts, notifications, appLock, fasting).start();
}

/// Runs one part of startup, logging rather than stopping on failure.
Future<void> _load(String part, Future<void> Function() load) async {
  try {
    await load();
    // Anything, so the rest of the app still starts.
    // ignore: avoid_catches_without_on_clauses
  } catch (e, st) {
    logError('Startup: $part failed to load: $e\n$st');
  }
}
