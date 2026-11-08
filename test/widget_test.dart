import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons, ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:health_app/app_edition.dart';
import 'package:health_app/l10n/language.dart';
import 'package:health_app/platform/app_icons.dart';
import 'package:health_app/widgets/glass_tab_bar.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/screens/habits/habits_screen.dart';
import 'package:health_app/screens/food/food_diary_screen.dart';
import 'package:health_app/app.dart';
import 'package:health_app/models/meal_template.dart';
import 'package:health_app/models/workout_program.dart';
import 'package:health_app/notifications/notifier.dart';
import 'package:health_app/screens/add_entry_sheet.dart';
import 'package:health_app/screens/edit_profile_screen.dart';
import 'package:health_app/screens/summary_screen.dart';
import 'package:health_app/backup/auto_backup.dart';
import 'package:health_app/data/health_repository.dart';
import 'package:health_app/data/photo_vault.dart';
import 'package:health_app/data/value_cipher.dart';
import 'package:health_app/models/body_goal.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/health_widget.dart';
import 'package:health_app/models/personalization.dart';
import 'package:health_app/widgets/bar_chart.dart';
import 'package:health_app/widgets/glow_tile.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/notifications/reminder_plan.dart';
import 'package:health_app/screens/workouts/active_workout.dart';
import 'package:health_app/screens/workouts/live_workout_screen.dart';
import 'package:health_app/notifications/notification_controller.dart';
import 'package:health_app/platform/device_profile.dart';
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
import 'package:health_app/nutrition/open_food_facts.dart';
import 'package:health_app/state/photo_store.dart';
import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/state/exercise_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/sync/health_source.dart';
import 'package:health_app/sync/health_sample.dart';
import 'package:health_app/sync/health_sync_service.dart';
import 'package:health_app/workout/geo.dart';
import 'package:health_app/screens/achievements_screen.dart';
import 'package:health_app/screens/health/all_health_data.dart';
import 'package:health_app/models/board.dart';
import 'package:health_app/models/board_catalog.dart';
import 'package:health_app/screens/workouts/workouts_screen.dart';
import 'package:health_app/screens/health_screen.dart';
import 'package:health_app/widgets/board_tiles.dart';
import 'package:health_app/widgets/widget_board.dart';
import 'package:health_app/screens/metric_detail_screen.dart';
import 'package:health_app/screens/food/barcode_scanner_screen.dart';
import 'package:health_app/models/food.dart';
import 'package:health_app/screens/workouts/workout_detail_screen.dart';
import 'package:health_app/widgets/exercise_figure.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/metric_card.dart';
import 'package:health_app/workout/location_source.dart';
import 'package:health_app/theme/app_theme.dart';

import 'fake_authenticator.dart';
import 'fake_backup_folder.dart';
import 'fake_food_server.dart';
import 'fake_health_source.dart';
import 'fake_location.dart';
import 'fake_notifier.dart';

const _samsung = DeviceProfile(
  platform: DevicePlatform.android,
  manufacturer: 'samsung',
  model: 'SM-S921B',
  osVersion: '15',
);

final _now = DateTime(2026, 10, 11, 15, 30);

class _Harness {
  _Harness(
    this.store,
    this.sync,
    this.source,
    this.workouts,
    this.notifier,
    this.location, {
    required this.meds,
    required this.cycle,
    required this.appLock,
    required this.auth,
    required this.nutrition,
  });

  final NutritionStore nutrition;
  final MedicationStore meds;
  final CycleStore cycle;
  final AppLock appLock;
  final FakeAuthenticator auth;
  final HealthStore store;
  final HealthSyncService sync;
  final FakeHealthSource source;
  final WorkoutStore workouts;
  final FakeNotifier notifier;
  final FakeLocation location;
}

/// Scrolls [finder] into view in the first scrollable, then settles.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  // Also into view sideways, e.g. in a carousel.
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
}

/// Puts the Health board back to the tile-per-tracker layout with pinned
/// metrics, for tests of metric tiles (the default no longer pins any).
Future<void> _withMetricTiles(WidgetTester tester, _Harness h) async {
  await h.store.updateBoard(
    BoardTab.health,
    const Board(BoardIds.previousHealthLayout),
  );
  await tester.pumpAndSettle();
}

/// Scrolls the page down until [finder] is built, then brings it into
/// view. Unlike [_reveal], it never needs the target to be unique.
Future<void> _scrollDownTo(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 20 && finder.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -250));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
}

/// Opens [label]'s detail from the Health tab's All Health Data screen
/// (the "Your Body" tiles open whole categories).
Future<void> _openMetric(WidgetTester tester, String label) async {
  await _scrollDownTo(tester, find.text('All Health Data'));
  await tester.tap(find.text('All Health Data'));
  await tester.pumpAndSettle();
  final row = find.descendant(
    of: find.byType(MetricRow),
    matching: find.text(label),
  );
  await _scrollDownTo(tester, row);
  await tester.tap(row.first);
  await tester.pumpAndSettle();
}

Future<_Harness> _pumpApp(
  WidgetTester tester, {
  DeviceProfile device = _samsung,
  bool onboarded = false,
  double textScale = 1,
  bool syncReady = true,
}) async {
  // Typical phone screen: 360 x 780 logical pixels.
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  // No workout left recording by an earlier test.
  ActiveWorkout.instance.finish();
  final repo = InMemoryHealthRepository();
  final store = HealthStore(repo, clock: () => _now);
  await store.load();
  if (onboarded) {
    await store.completeOnboarding(name: 'Alex', withSampleData: true);
  }
  final source = FakeHealthSource(grant: {MetricType.steps, MetricType.sleep});
  source.samples.add(
    HealthSample(
      type: MetricType.steps,
      value: 6543,
      start: DateTime(2026, 10, 11, 9),
      end: DateTime(2026, 10, 11, 10),
    ),
  );
  final workouts = WorkoutStore(repo, store, clock: () => _now);
  await workouts.load();
  final sync = HealthSyncService(
    source: source,
    store: store,
    repo: repo,
    workouts: workouts,
    clock: () => _now,
  );
  if (syncReady) await sync.init();
  final notifier = FakeNotifier();
  final notifications = NotificationController(repo, store, notifier);
  final medications = MedicationStore(store, notifier);
  await medications.load();
  final cycle = CycleStore(store);
  await cycle.load();
  final mood = MoodStore(store);
  await mood.load();
  final gym = GymStore(store);
  await gym.load();
  final fasting = FastingStore(store, notifier);
  await fasting.load();
  final sleepSchedule = SleepScheduleStore(store, notifier);
  await sleepSchedule.load();
  final programs = ProgramStore(store, workouts);
  await programs.load();
  final nutrition = NutritionStore(store);
  await nutrition.load();
  final achievements = AchievementStore(store, workouts);
  await achievements.load();
  final auth = FakeAuthenticator();
  final appLock = AppLock(store, authenticator: auth);
  await appLock.load();
  addTearDown(appLock.dispose);
  final autoBackup = AutoBackup(
    store,
    workouts,
    folder: FakeBackupFolder(),
    secret: FakeSecret(),
  );
  await autoBackup.load();
  final location = FakeLocation();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: sync),
        ChangeNotifierProvider.value(value: workouts),
        ChangeNotifierProvider.value(value: _exercises(repo, store)),
        ChangeNotifierProvider.value(
          value: PhotoStore(
            repo,
            store,
            PhotoVault(
              directory: () async => Directory.systemTemp.createTempSync('ph'),
              cipher: AesGcmCipher.withKey(List<int>.filled(32, 1)),
            ),
          ),
        ),
        ChangeNotifierProvider.value(value: notifications),
        ChangeNotifierProvider.value(value: medications),
        ChangeNotifierProvider.value(value: cycle),
        ChangeNotifierProvider.value(value: mood),
        ChangeNotifierProvider.value(value: gym),
        ChangeNotifierProvider.value(value: fasting),
        ChangeNotifierProvider.value(value: sleepSchedule),
        ChangeNotifierProvider.value(value: programs),
        ChangeNotifierProvider.value(value: nutrition),
        Provider<OpenFoodFacts>.value(value: fakeOpenFoodFacts()),
        ChangeNotifierProvider.value(value: achievements),
        ChangeNotifierProvider.value(value: appLock),
        ChangeNotifierProvider.value(value: autoBackup),
        ChangeNotifierProvider(create: (_) => AppIcons(store)),
        ChangeNotifierProvider(create: (_) => LanguageController(null)),
        Provider<HealthSource>.value(value: source),
        Provider<LocationSource>.value(value: location),
        Provider.value(value: device),
      ],
      child: const HealthApp(),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(
    store,
    sync,
    source,
    workouts,
    notifier,
    location,
    meds: medications,
    cycle: cycle,
    appLock: appLock,
    auth: auth,
    nutrition: nutrition,
  );
}

/// The tab bar's button for [label]. Only the selected tab shows its
/// name, so tabs are found by their label for screen readers.
Finder _tabButton(String label) => find.descendant(
  of: find.byType(GlassTabBar),
  matching: find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
  ),
);

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(_tabButton(label));
  await tester.pumpAndSettle();
}

/// App settings: the cog on Profile.
Future<void> _openSettings(WidgetTester tester) async {
  await _openTab(tester, 'Profile');
  await tester.tap(find.bySemanticsLabel('Settings').first);
  await tester.pumpAndSettle();
}

/// The home screen widget plugin has no test implementation.
void _mockHomeWidgetChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockStreamHandler(
    const EventChannel('home_widget/updates'),
    MockStreamHandler.inline(onListen: (_, _) {}),
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('home_widget'),
    (_) async => null,
  );
}

final _catalog = ExerciseCatalog.fromBundledJson(
  File('assets/data/exercises.json').readAsStringSync(),
);

ExerciseStore _exercises(HealthRepository repo, HealthStore store) {
  final s = ExerciseStore(repo, store, loadCatalog: () async => _catalog);
  ExerciseCatalog.instance = _catalog;
  return s;
}

void main() {
  setUp(_mockHomeWidgetChannels);
  // Endless animations (pulse line, beating heart) never settle.
  Motion.ambient = false;
  testWidgets('welcome shows who made Health and goes straight into setup', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.text('Welcome to Health'), findsOneWidget);
    expect(find.text('Made for the people, by the people.'), findsOneWidget);
    expect(find.bySemanticsLabel('Created by UntrustedTech'), findsOneWidget);
    expect(find.text('Set Up Later'), findsNothing);
    expect(find.byType(CupertinoTextField), findsNothing);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Nice to Meet You'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 1 of 9'), findsOneWidget);
  });

  testWidgets('the data page recommends Health Connect and explains it', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Use Health Connect'), findsOneWidget);
    expect(find.text('RECOMMENDED'), findsOneWidget);
    expect(find.text('What is Health Connect?'), findsOneWidget);
    expect(find.textContaining('Samsung SM-S921B'), findsOneWidget);
    expect(find.textContaining('Samsung Health'), findsOneWidget);
    await _reveal(tester, find.text('Try With Demo Data'));
    expect(find.text('Start Fresh'), findsOneWidget);
  });

  testWidgets(
    'setup waits for the Health Connect check rather than skipping it',
    (tester) async {
      // The check runs as the app starts; setup may get there first.
      final h = await _pumpApp(tester, syncReady: false);
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip')); // about you
      // A spinner shows while checking, so it never settles.
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(CupertinoActivityIndicator), findsWidgets);
      expect(find.text('Start Fresh'), findsOneWidget); // the other option
      expect(find.text('Connect Health Connect'), findsNothing);
      expect(h.sync.connected, isFalse);

      await h.sync.init();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Connect Health Connect'));
      await tester.pumpAndSettle();
      expect(h.sync.connected, isTrue);
    },
  );

  testWidgets('connecting during onboarding imports Health Connect data', (
    tester,
  ) async {
    final h = await _pumpApp(tester);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip')); // about you
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect Health Connect'));
    await tester.pumpAndSettle();
    expect(find.text('Preferences'), findsOneWidget);
    // Skip the rest.
    for (var i = 0; i < 7; i++) {
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Almost There'), findsOneWidget);
    await tester.tap(find.text('Start Using Health'));
    await tester.pumpAndSettle();

    expect(h.sync.connected, isTrue);
    expect(h.store.hasSampleData, isFalse);
    expect(h.store.todayValue(MetricType.steps), 6543);
    expect(find.text('Summary'), findsWidgets);
    expect(find.text('1 of 9 done'), findsOneWidget);
  });

  testWidgets('choosing demo data fills Health with sample data', (
    tester,
  ) async {
    final h = await _pumpApp(tester);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await _reveal(tester, find.text('Try With Demo Data'));
    await tester.tap(find.text('Try With Demo Data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore With Demo Data'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 7; i++) {
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Start Using Health'));
    await tester.pumpAndSettle();

    expect(h.sync.connected, isFalse);
    expect(h.store.hasSampleData, isTrue);
    expect(
      h.store.personalization.setupLeft,
      isNot(contains(SetupStep.connect)),
    );
  });

  testWidgets('choosing demo data and then skipping adds no demo data', (
    tester,
  ) async {
    final h = await _pumpApp(tester);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await _reveal(tester, find.text('Try With Demo Data'));
    await tester.tap(find.text('Try With Demo Data'));
    await tester.pumpAndSettle();
    while (find.text('Start Using Health').evaluate().isEmpty) {
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Start Using Health'));
    await tester.pumpAndSettle();

    expect(h.store.hasSampleData, isFalse);
    expect(h.store.personalization.setupLeft, contains(SetupStep.connect));
  });

  testWidgets('onboarding saves each step and skipped ones can be finished '
      'from Summary', (tester) async {
    final h = await _pumpApp(tester);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    // About you: name and birthday; the age follows from it.
    await tester.enterText(find.byType(CupertinoTextField), 'Alex Smith');
    expect(find.text('Scroll to choose'), findsOneWidget);
    // The year wheel, scrolled to earlier years.
    await tester.drag(find.byType(CupertinoPicker).last, const Offset(0, 160));
    await tester.pumpAndSettle();
    final age = h.store.profile.ageOn(h.store.today);
    expect(age, isNull); // not saved until Continue
    expect(find.textContaining('years old'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    final saved = h.store.profile.ageOn(h.store.today);
    expect(saved, isNotNull);
    expect(saved, greaterThan(30));
    expect(find.text('$saved years old'), findsNothing); // moved on

    // Your data: a fresh start.
    await _reveal(tester, find.text('Start Fresh'));
    await tester.tap(find.text('Start Fresh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Fresh').last);
    await tester.pumpAndSettle();

    // Preferences: metric, with examples of each, and street maps.
    expect(find.bySemanticsLabel(RegExp('^Imperial: .*5 ft 10 in')), findsOne);
    await tester.tap(find.bySemanticsLabel(RegExp('^Metric: ')));
    await _reveal(tester, find.text('Street Map'));
    await tester.tap(find.text('Street Map'));
    h.location.access = LocationAccess.denied;
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Location Is Off'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(h.store.personalization.units, UnitSystem.metric);
    expect(h.workouts.settings.mapStyle, MapStyle.street);

    // Allowed: no message.
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    h.location.access = LocationAccess.granted;
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Location Is Off'), findsNothing);

    // Health details: height from the wheels (untouched: 170 cm exactly).
    expect(find.text('Birthday'), findsNothing);
    await tester.tap(find.text('Male'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Height'));
    await tester.pumpAndSettle();
    expect(find.text('170 cm'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField).at(0), '80');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(h.store.profile.sex, 'Male');
    expect(h.store.profile.heightCm, 170);
    expect(h.store.latestReading(MetricType.weight)?.value, 80);

    // Back and Continue again: same weight isn't logged twice and the
    // height is kept.
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.text('170 cm'), findsOneWidget);
    await tester.enterText(find.byType(CupertinoTextField).at(0), '80');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(h.store.entriesFor(MetricType.weight), hasLength(1));
    expect(h.store.profile.heightCm, 170);

    // Your Goal: lose weight, with the default target 5 kg down.
    await tester.tap(find.text('Lose Weight'));
    await tester.pumpAndSettle();
    expect(find.textContaining('around'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(h.store.bodyGoal.objective, GoalObjective.lose);
    expect(h.store.bodyGoal.startKg, 80);
    expect(h.store.goals.weightKg, 75);

    // Goals: presets, then custom with one more step.
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('FOR YOU'), findsOneWidget);
    await _reveal(tester, find.text('Custom'));
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await _reveal(tester, find.bySemanticsLabel('Increase Steps'));
    await tester.tap(find.bySemanticsLabel('Increase Steps'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(h.store.goals.steps, 8500);

    // Food: pick High Protein.
    await _reveal(tester, find.text('High Protein'));
    await tester.tap(find.text('High Protein'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(h.nutrition.goals.proteinShare, closeTo(0.40, 0.001));

    // Fitness: no weekly goal (a treadmill runner).
    await tester.tap(find.text('No Weekly Goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(h.workouts.settings.weeklyGoalMinutes, 0);
    expect(h.workouts.settings.hasWeeklyGoal, isFalse);

    // Reminders: skipped.
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Later'), findsOneWidget);
    await _reveal(tester, find.text('Your Data Stays Yours'));
    await tester.tap(find.text('Start Using Health'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Setting Up Health'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(h.store.profile.name, 'Alex Smith');
    expect(h.store.hasSampleData, isFalse);
    await _reveal(tester, find.text('8 of 9 done'));
    expect(find.text('8 of 9 done'), findsOneWidget);
    await tester.tap(find.text('Reminders'));
    await tester.pumpAndSettle();
    expect(find.text('Hydration Reminders'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(h.store.personalization.setupLeft, isEmpty);
  });

  testWidgets('the Reminders step asks for notifications and never hangs', (
    tester,
  ) async {
    final h = await _pumpApp(tester);
    h.notifier.allow = false;
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    while (find.text('Reminders').evaluate().isEmpty) {
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
    }

    // Nothing switched on: still asked, and moves on when refused.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(h.notifier.permissionRequests, 1);
    expect(find.text('Start Using Health'), findsOneWidget);

    // Back, with water on and permission refused: explained, then on.
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Water'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Notifications Are Off'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Start Using Health'), findsOneWidget);
    expect(h.notifier.scheduled, isEmpty);
  });

  testWidgets('reminders offer recommended or custom schedules, with '
      'workout days from the weekly goal', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    while (find.text('Fitness').evaluate().isEmpty) {
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
    }
    // A bigger weekly goal: 300 minutes is six days.
    await tester.tap(find.text('Active'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Water: recommended, then custom every 3 hours.
    await tester.tap(find.text('Water'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Every 2 hours'), findsOneWidget);
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Increase Remind Every'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Water')); // collapse it again
    await tester.pumpAndSettle();
    await tester.tap(find.text('Water'));
    await tester.pumpAndSettle();

    // Meals: times for each, snacks any time.
    await _reveal(tester, find.text('Meals'));
    await tester.tap(find.text('Meals'));
    await tester.pumpAndSettle();
    expect(find.text('When do you usually eat?'), findsOneWidget);
    expect(find.textContaining('Snacks can be logged any time'), findsOne);

    // Workouts: recommended days follow the weekly goal.
    await _reveal(tester, find.text('Workouts'));
    await tester.tap(find.text('Workouts'));
    await tester.pumpAndSettle();
    await _reveal(tester, find.textContaining('Fits your 300 min'));
    expect(find.textContaining('Mon, Tue, Wed, Thu, Fri and Sat'), findsOne);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    final s = Provider.of<NotificationController>(
      tester.element(find.byType(HealthApp)),
      listen: false,
    ).settings;
    expect(s.water, isTrue);
    expect(s.waterEveryHours, 3);
    expect(s.meals, isTrue);
    expect(s.workout, isTrue);
    expect(s.workoutDays, hasLength(6));
    expect(s.workoutHour, 18);
  });

  testWidgets('Health tab opens a detail screen; Android back returns', (
    tester,
  ) async {
    await _pumpApp(tester, onboarded: true);

    await _openTab(tester, 'Health');
    await tester.tap(find.text('RESTING HEART RATE'));
    await tester.pumpAndSettle();

    expect(find.text('Add Data'), findsOneWidget);
    expect(find.text('AVERAGE'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Add Data'), findsNothing);
    expect(find.text('RESTING HEART RATE'), findsOneWidget);
  });

  testWidgets('search results show while the keyboard is open', (tester) async {
    await _pumpApp(tester, onboarded: true);
    await _openTab(tester, 'Health');
    await tester.enterText(find.byType(CupertinoSearchTextField), 'Heart');
    // A phone keyboard covering about 40% of the screen.
    tester.view.viewInsets = FakeViewPadding(
      bottom: tester.view.physicalSize.height * 0.4,
    );
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    expect(find.text('Resting Heart Rate').hitTestable(), findsOneWidget);
  });

  testWidgets('a page opened above the tabs animates without crashing', (
    tester,
  ) async {
    await _pumpApp(tester, onboarded: true);
    // Visited tabs stay alive, hidden, with their own navigation bars.
    await _openTab(tester, 'Health');
    await _openTab(tester, 'Summary');

    unawaited(
      EditProfileScreen.open(tester.element(find.byType(SummaryScreen))),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(EditProfileScreen), findsOneWidget);
  });

  testWidgets('iOS: moving around pages and swiping back never crashes', (
    tester,
  ) async {
    await _pumpApp(tester, onboarded: true);
    // Far enough to go back, or not (it springs back).
    Future<void> swipeBack({double by = 300}) async {
      final g = await tester.startGesture(const Offset(5, 400));
      await g.moveBy(Offset(by / 2, 0));
      await tester.pump();
      await g.moveBy(Offset(by / 2, 0));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
    }

    await _openTab(tester, 'Health');
    await tester.tap(find.text('RESTING HEART RATE'));
    await tester.pumpAndSettle();
    await swipeBack(by: 80);
    expect(find.text('Add Data'), findsOneWidget);
    await swipeBack(by: 360);
    expect(find.text('Add Data'), findsNothing);
    await _openTab(tester, 'Summary');
    unawaited(
      EditProfileScreen.open(tester.element(find.byType(SummaryScreen))),
    );
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await _openTab(tester, 'Health');
    await tester.tap(find.text('RESTING HEART RATE'));
    await tester.pumpAndSettle();
    await swipeBack();

    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS: hopping quickly between menus never crashes', (
    tester,
  ) async {
    await _pumpApp(tester, onboarded: true);
    Future<void> tapIfThere(Finder f) async {
      if (f.hitTestable().evaluate().isNotEmpty) {
        await tester.tap(f.hitTestable().last, warnIfMissed: false);
      }
    }

    Future<void> backToSettings() async {
      await tester.pumpAndSettle();
      if (find.text('Appearance').evaluate().isEmpty) {
        await tester.tap(_tabButton('Profile'));
        await tester.pumpAndSettle();
        if (find.text('Appearance').evaluate().isEmpty) {
          await tester.tap(find.bySemanticsLabel('Settings').first);
          await tester.pumpAndSettle();
        }
      }
    }

    const rows = [
      'Appearance',
      'Privacy',
      'Acknowledgements',
      'Backup, Import & Export',
    ];
    for (final gap in const [30, 60, 120, 200, 300]) {
      final step = Duration(milliseconds: gap);
      for (final row in rows) {
        await backToSettings();
        await _reveal(tester, find.text(row));
        // Double tap: a second page pushed mid-transition.
        await tapIfThere(find.text(row));
        await tester.pump(step);
        await tapIfThere(find.text(row));
        await tester.pump(step);
        // Back twice, quickly, then straight into another page mid-pop.
        await tester.binding.handlePopRoute();
        await tester.pump(step);
        await tester.binding.handlePopRoute();
        await tester.pump(step);
        await tapIfThere(find.text(rows[(rows.indexOf(row) + 1) % rows.length]));
        await tester.pump(step);
        // Switch tabs mid-push and back.
        await tester.tap(_tabButton('Summary'));
        await tester.pump(step);
        await tester.tap(_tabButton('Profile'));
        await tester.pump(step);
        await tester.tap(_tabButton('Profile'));
        await tester.pump(step);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$row at $gap ms');
      }
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS: opening and closing sheets quickly never crashes', (
    tester,
  ) async {
    await _pumpApp(tester, onboarded: true);
    await _openTab(tester, 'Health');
    await tester.tap(find.text('RESTING HEART RATE'));
    await tester.pumpAndSettle();
    for (final gap in const [20, 50, 100, 180, 300]) {
      final step = Duration(milliseconds: gap);
      // Open, close mid-way, open again before it's gone.
      await tester.tap(find.text('Add Data').hitTestable().last);
      await tester.pump(step);
      await tester.binding.handlePopRoute();
      await tester.pump(step);
      if (find.text('Add Data').hitTestable().evaluate().isNotEmpty) {
        await tester.tap(find.text('Add Data').hitTestable().last);
      }
      await tester.pump(step);
      // Away to another tab and back while it moves.
      await tester.tap(_tabButton('Summary'));
      await tester.pump(step);
      await tester.tap(_tabButton('Health'));
      await tester.pump(step);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'at $gap ms');
      if (find.text('Add Data').evaluate().isEmpty) {
        await tester.tap(find.text('RESTING HEART RATE'));
        await tester.pumpAndSettle();
      }
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS: tapping the open tab mid-transition goes back safely', (
    tester,
  ) async {
    await _pumpApp(tester, onboarded: true);
    await _openTab(tester, 'Health');

    // Mid-push.
    await tester.tap(find.text('RESTING HEART RATE'));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(_tabButton('Health'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // A sheet over a page, closed while going back to the tab's start.
    await tester.tap(find.text('RESTING HEART RATE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Data'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(_tabButton('Health'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('add data sheet logs a value', (tester) async {
    final h = await _pumpApp(tester, onboarded: true);
    await _openTab(tester, 'Health');
    await _openMetric(tester, 'Weight');

    await tester.tap(find.text('Add Data'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField).first, '72.5');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(h.store.entriesFor(MetricType.weight).first.value, 72.5);
    expect(find.text('Add'), findsNothing);
  });

  testWidgets('Health Connect screen connects, lists access, disconnects', (
    tester,
  ) async {
    final h = await _pumpApp(tester, onboarded: true);
    await _openSettings(tester);
    await _reveal(tester, find.text('Health Connect'));
    await tester.tap(find.text('Health Connect'));
    await tester.pumpAndSettle();

    expect(find.text('Galaxy phone detected'), findsOneWidget);
    await tester.tap(find.text('Connect Health Connect'));
    await tester.pumpAndSettle();

    expect(find.text('Last Synced'), findsOneWidget);
    expect(find.text('Not Allowed'), findsWidgets);
    expect(h.store.hasImportedData, isTrue);

    await _reveal(tester, find.text('Disconnect'));
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disconnect').last);
    await tester.pumpAndSettle();

    expect(h.sync.connected, isFalse);
    expect(h.store.hasImportedData, isFalse);
    expect(find.text('Connect Health Connect'), findsOneWidget);
  });

  testWidgets('Health Connect settings: automatic sync, permissions, data '
      'and recent access', (tester) async {
    final h = await _pumpApp(tester, onboarded: true);
    await h.sync.connect();
    await h.sync.sync();
    await _openSettings(tester);
    await _reveal(tester, find.text('Health Connect'));
    await tester.tap(find.text('Health Connect'));
    await tester.pumpAndSettle();

    Finder switchFor(String title) => find.descendant(
      of: find.ancestor(
        of: find.text(title),
        matching: find.byType(CupertinoListTile),
      ),
      matching: find.byType(CupertinoSwitch),
    );

    // Sync when the app opens: on by default, can be turned off.
    await _reveal(tester, switchFor('Sync When App Opens'));
    await tester.tap(switchFor('Sync When App Opens'));
    await tester.pumpAndSettle();
    expect(h.sync.syncOnOpen, isFalse);

    // Background sync was turned on when connecting; the interval can be
    // set.
    expect(h.sync.backgroundSync, isTrue);
    await _reveal(tester, find.text('Check Every'));
    await tester.tap(find.text('Check Every'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('6 hrs'));
    await tester.pumpAndSettle();
    expect(h.sync.backgroundInterval, const Duration(hours: 6));

    // Health Connect's own screens.
    await _reveal(tester, find.text('Manage Permissions'));
    await tester.tap(find.text('Manage Permissions'));
    await tester.pumpAndSettle();
    expect(h.source.permissionSettingsOpened, 1);
    await _reveal(tester, find.text('Data & Access'));
    await tester.tap(find.text('Data & Access'));
    await tester.pumpAndSettle();
    expect(h.source.dataSettingsOpened, 1);

    // Recent access lists the syncs.
    await _reveal(tester, find.text('RECENT ACCESS'));
    await _reveal(tester, find.text('Connected'));
    expect(find.text('Connected'), findsOneWidget);
  });

  testWidgets('imported entries cannot be swiped away', (tester) async {
    final h = await _pumpApp(tester, onboarded: true);
    await h.sync.connect();
    await tester.pumpAndSettle();

    await _openTab(tester, 'Health');
    await _openMetric(tester, 'Steps');
    await _reveal(tester, find.text('Show All Data'));
    await tester.tap(find.text('Show All Data'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Health Connect'), findsWidgets);
    expect(find.byType(Dismissible), findsWidgets); // sample entries only
    final importedTile = find.ancestor(
      of: find.text('6,543 steps'),
      matching: find.byType(Dismissible),
    );
    expect(importedTile, findsNothing);
  });

  testWidgets('screens fit with the largest standard text size', (
    tester,
  ) async {
    await _pumpApp(tester, onboarded: true, textScale: 1.6);

    await _openTab(tester, 'Health');
    await _openTab(tester, 'Food');
    await _reveal(tester, find.text('Snacks'));
    await tester.tap(find.text('Add Food').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await _openSettings(tester);
    await _reveal(tester, find.text('Erase All Data'));
    await _openTab(tester, 'Summary');
    await _scrollDownTo(tester, find.text('Body'));
    for (final p in ['Week', 'Year']) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pumpAndSettle();
      await tester.tap(find.text(p));
      await tester.pumpAndSettle();
      await _scrollDownTo(tester, find.text('Body'));
    }
    // Layout overflows would have failed the test with an exception.
  });

  testWidgets('screen readers can press tabs, chips and food rows', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpApp(tester, onboarded: true);

    // The tab bar's buttons carry a tap action, not just a label.
    tester.semantics.tap(find.semantics.byLabel('Food'));
    await tester.pumpAndSettle();
    expect(find.byType(FoodDiaryScreen), findsOneWidget);

    // So do the day strip and the meal buttons.
    tester.semantics.tap(find.semantics.byLabel('Previous day'));
    await tester.pumpAndSettle();
    expect(find.textContaining('YESTERDAY'), findsOneWidget);
    await Scrollable.ensureVisible(
      tester.element(find.text('Add Food').first),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    tester.semantics.tap(find.semantics.byLabel('Add Food to Breakfast'));
    await tester.pumpAndSettle();
    expect(find.text('Add to Breakfast'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('dark mode renders', (tester) async {
    final h = await _pumpApp(tester, onboarded: true);
    await h.store.setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();

    final ctx = tester.element(find.text('Activity').first);
    expect(CupertinoTheme.brightnessOf(ctx), Brightness.dark);
  });

  testWidgets('privacy screen opens from Profile', (tester) async {
    await _pumpApp(tester, onboarded: true);
    await _openSettings(tester);
    await _reveal(tester, find.text('Privacy'));
    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();

    expect(find.text('Your Health Data Stays With You'), findsOneWidget);
    await _reveal(tester, find.textContaining('never uploaded'));
    expect(find.textContaining('never uploaded'), findsOneWidget);
  });

  group('workouts', () {
    /// Lets the 3-2-1 countdown finish (the live screen ticks every second,
    /// so pumpAndSettle would never settle).
    Future<void> countdown(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }

    /// Several frames, so sheets finish animating (the live screen ticks
    /// every second, so pumpAndSettle would never return).
    Future<void> frames(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    Future<void> endWith(WidgetTester tester, String choice) async {
      await tester.tap(find.text('End'));
      // Several frames so the action sheet finishes sliding in.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.tap(find.text(choice));
      // The ticker stops when the workout ends, so the UI can settle.
      await tester.pumpAndSettle();
    }

    testWidgets('record and save a timed workout', (tester) async {
      final h = await _pumpApp(tester, onboarded: true);
      await _openTab(tester, 'Fitness');
      expect(find.bySemanticsLabel(RegExp('^This week[:,] ')), findsOneWidget);

      await _reveal(tester, find.text('All Workouts'));
      await tester.tap(find.text('All Workouts'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Yoga'));
      await tester.tap(find.text('Yoga'));
      await tester.pumpAndSettle();
      // The sheet's Start, above the suggestion card's.
      await tester.tap(find.text('Start').last);
      await tester.pump();
      await countdown(tester);

      expect(find.text('Pause'), findsOneWidget);
      expect(h.notifier.ongoing, isTrue);
      expect(LiveWorkoutScreen.isActive, isTrue);

      await endWith(tester, 'End and Save');
      expect(find.text('Workout Summary'), findsOneWidget);
      // Recoverable until saved, in case the app is closed here.
      expect(h.workouts.hasCheckpoint, isTrue);
      await tester.tap(find.text('Save Workout'));
      await tester.pumpAndSettle();

      expect(h.workouts.all.single.type, WorkoutType.yoga);
      expect(h.workouts.hasCheckpoint, isFalse);
      expect(h.notifier.ongoing, isFalse);
    });

    testWidgets('a minimized workout keeps going and comes back', (
      tester,
    ) async {
      final h = await _pumpApp(tester, onboarded: true);
      await _openTab(tester, 'Fitness');
      await _reveal(tester, find.text('Outdoor Run'));
      await tester.tap(find.text('Outdoor Run'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start').last);
      await tester.pump();
      await countdown(tester);

      await tester.tap(find.bySemanticsLabel('Minimize'));
      await frames(tester);
      expect(find.byType(LiveWorkoutScreen), findsNothing);
      expect(ActiveWorkout.instance.recording, isTrue);
      // The rest of the app works meanwhile.
      await tester.tap(find.text('Weekly Plan'));
      await frames(tester);
      expect(find.text('Push / Pull / Legs'), findsWidgets);
      final bar = find.bySemanticsLabel(
        RegExp(r'^Outdoor Run, .*Open workout'),
      );
      expect(bar, findsOneWidget);
      // Starting another brings this one back instead.
      await tester.tap(bar);
      await frames(tester);
      expect(find.byType(LiveWorkoutScreen), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);

      await endWith(tester, 'Discard Workout');
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.byType(LiveWorkoutScreen), findsNothing);
      expect(ActiveWorkout.instance.tracker, isNull);
      expect(h.workouts.all, isEmpty);
    });

    testWidgets('a guided Pilates flow counts down each move', (tester) async {
      final h = await _pumpApp(tester, onboarded: true);
      await _openTab(tester, 'Fitness');
      await _reveal(tester, find.text('All Workouts'));
      await tester.tap(find.text('All Workouts'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Pilates'));
      expect(find.text('2 guided flows'), findsWidgets);
      await tester.tap(find.text('Pilates'));
      await tester.pumpAndSettle();
      expect(find.text('Or Follow a Guided Flow'), findsOneWidget);
      await _reveal(tester, find.text('Classical Pilates Mat'));
      await tester.tap(find.text('Classical Pilates Mat'));
      await tester.pump();
      await countdown(tester);

      // A minute of breathing first (moves are covered in unit tests;
      // the tracker runs on the wall clock).
      expect(find.text('Breathe & Center'), findsOneWidget);
      expect(find.textContaining('Classical Pilates Mat ·'), findsOneWidget);

      await endWith(tester, 'End and Save');
      await tester.tap(find.text('Save Workout'));
      await tester.pumpAndSettle();
      expect(h.workouts.all.single.type, WorkoutType.pilates);
    });

    testWidgets('strength routine: completing a set starts rest', (
      tester,
    ) async {
      final h = await _pumpApp(tester, onboarded: true);
      await _openTab(tester, 'Fitness');
      await _reveal(tester, find.text('Routines'));
      await tester.tap(find.text('Routines'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Push Day'));
      await tester.tap(find.text('Push Day'));
      await tester.pump();
      await countdown(tester);

      // The focus card shows the first set; the exercise card is below.
      expect(find.text('Barbell Bench Press'), findsWidgets);
      expect(find.text('NOW · SET 1 OF 4'), findsOneWidget);
      await tester.tap(find.text('Complete Set'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('REST'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      await tester.tap(find.text('+15s'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(h.notifier.rest, greaterThan(const Duration(seconds: 100)));
      await tester.tap(find.text('Skip'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('NOW · SET 2 OF 4'), findsOneWidget);

      await endWith(tester, 'Discard Workout');
      expect(h.workouts.all, isEmpty);
    });

    testWidgets('routines pre-fill from last time and celebrate records', (
      tester,
    ) async {
      final h = await _pumpApp(tester, onboarded: true);
      await h.workouts.save(
        WorkoutSession(
          id: 'prev',
          type: WorkoutType.strength,
          start: DateTime(2026, 10, 9, 18),
          end: DateTime(2026, 10, 9, 19),
          activeSeconds: 3600,
          exercises: const [
            ExerciseLog(
              exerciseId: 'bench_press',
              sets: [
                SetLog(reps: 8, weightKg: 60, done: true),
                SetLog(reps: 8, weightKg: 60, done: true),
              ],
            ),
          ],
        ),
      );
      await _openTab(tester, 'Fitness');
      await _reveal(tester, find.text('Routines'));
      await tester.tap(find.text('Routines'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Push Day'));
      await tester.tap(find.text('Push Day'));
      await tester.pump();
      await countdown(tester);

      // Old "bench_press" history feeds the library's Barbell Bench Press.
      await tester.dragUntilVisible(
        find.text('60×8').first,
        find.byType(Scrollable).first,
        const Offset(0, -150),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('60×8'), findsWidgets);
      expect(find.text('60'), findsWidgets);

      await tester.ensureVisible(
        find.bySemanticsLabel('Plate calculator').first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 120));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.bySemanticsLabel('Plate calculator').first);
      await frames(tester);
      expect(find.textContaining('Each side: 20 kg'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await frames(tester);

      await tester.enterText(find.byType(CupertinoTextField).first, '70');
      await tester.tap(find.bySemanticsLabel('Mark set done').first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('New Personal Record'), findsOneWidget);

      await endWith(tester, 'Discard Workout');
    });

    testWidgets('GPS run measures distance from location updates', (
      tester,
    ) async {
      final h = await _pumpApp(tester, onboarded: true);
      await _openTab(tester, 'Fitness');
      await _reveal(tester, find.text('Outdoor Run'));
      await tester.tap(find.text('Outdoor Run'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start').last);
      await tester.pump();
      await countdown(tester);

      final t0 = DateTime.now();
      for (var i = 0; i <= 3; i++) {
        h.location.emit(
          GeoPoint(
            lat: 51.5 + i * 100 / 111194.9,
            lng: -0.1,
            time: t0.add(Duration(seconds: 30 * i)),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('0.30\u00A0km'), findsOneWidget);
      await endWith(tester, 'Discard Workout');
    });

    testWidgets('workout settings: map style and Health Connect saving', (
      tester,
    ) async {
      final h = await _pumpApp(tester, onboarded: true);
      await _openTab(tester, 'Fitness');
      await tester.tap(find.bySemanticsLabel('Fitness Settings'));
      await tester.pumpAndSettle();

      await _reveal(tester, find.text('Street Map'));
      await tester.tap(find.text('Street Map'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.byType(CupertinoSwitch).first);
      await tester.tap(find.byType(CupertinoSwitch).first);
      await tester.pumpAndSettle();

      expect(h.workouts.settings.mapStyle, MapStyle.street);
      expect(h.workouts.settings.saveToHealthConnect, isTrue);
    });
  });

  testWidgets('Settings (the cog on Profile) open each part\'s settings', (
    tester,
  ) async {
    await _pumpApp(tester, onboarded: true);
    await _openSettings(tester);
    for (final (tile, page) in [
      ('Health', 'Health Settings'),
      ('Food', 'Food Settings'),
      ('Fitness', 'Fitness Settings'),
    ]) {
      final finder = find.descendant(
        of: find.byType(GlowTile),
        matching: find.text(tile),
      );
      await _reveal(tester, finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(find.text(page), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('meal reminders are scheduled from Food Settings', (
    tester,
  ) async {
    final h = await _pumpApp(tester, onboarded: true);
    await _openTab(tester, 'Food');
    await tester.tap(find.bySemanticsLabel('Food Settings'));
    await tester.pumpAndSettle();
    final toggle = find.descendant(
      of: find.ancestor(
        of: find.text('Remind Me to Log Meals'),
        matching: find.byType(CupertinoListTile),
      ),
      matching: find.byType(CupertinoSwitch),
    );
    await _reveal(tester, toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(
      h.notifier.scheduled.map((r) => r.title),
      containsAll(['Log your breakfast', 'Log your lunch', 'Log your dinner']),
    );
  });

  testWidgets('Health tiles open trackers and Health Settings', (tester) async {
    await _pumpApp(tester, onboarded: true);
    await _openTab(tester, 'Health');
    // Trackers are rows of one list.
    await _reveal(tester, find.text('Health Report'));
    expect(find.text('Food & Calories'), findsOneWidget);
    expect(find.text('Achievements'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Health Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Customize Health Tab'), findsOneWidget);
  });

  testWidgets('notification settings schedule reminders', (tester) async {
    final h = await _pumpApp(tester, onboarded: true);
    await _openSettings(tester);
    await _reveal(tester, find.text('Notifications'));
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();

    final ringsSwitch = find.descendant(
      of: find.ancestor(
        of: find.text('Close Your Rings'),
        matching: find.byType(CupertinoListTile),
      ),
      matching: find.byType(CupertinoSwitch),
    );
    await tester.tap(ringsSwitch);
    await tester.pumpAndSettle();

    expect(h.notifier.scheduled.map((r) => r.kind).toSet(), {
      ReminderKind.rings,
    });
  });

  testWidgets('a starter plan fills the week and today\'s card', (
    tester,
  ) async {
    final h = await _pumpApp(tester, onboarded: true);
    await _openTab(tester, 'Fitness');
    await _reveal(tester, find.text('Weekly Plan'));
    await tester.tap(find.text('Weekly Plan'));
    await tester.pumpAndSettle();

    await _reveal(tester, find.text('Push / Pull / Legs'));
    await tester.tap(find.text('Push / Pull / Legs'));
    await tester.pumpAndSettle();

    final monday = h.workouts.plan.days[DateTime.monday];
    expect(h.workouts.routineById(monday)?.name, 'Push');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    // Sunday is a rest day in this plan.
    expect(find.text('Rest day'), findsOneWidget);
  });

  testWidgets('log a workout done without the app', (tester) async {
    final h = await _pumpApp(tester, onboarded: true);
    await _openTab(tester, 'Fitness');
    await _reveal(tester, find.text('History'));
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Log a past workout'));
    await tester.pumpAndSettle();

    expect(find.text('Log Workout'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Longer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final w = h.workouts.all.single;
    expect(w.type, WorkoutType.strength);
    expect(w.activeSeconds, 50 * 60);
    expect(w.activeKcal, greaterThan(0)); // estimated
  });

  group('personalization', () {
    testWidgets('tab bar reads Summary, Health, Fitness, Profile', (
      tester,
    ) async {
      await _pumpApp(tester, onboarded: true);

      final xs = [
        for (final label in const ['Summary', 'Health', 'Fitness', 'Profile'])
          tester.getCenter(_tabButton(label)).dx,
      ];
      expect(xs, orderedEquals([...xs]..sort()));
    });

    testWidgets('Summary shows one health score and a breakdown for each '
        'period', (tester) async {
      await _pumpApp(tester, onboarded: true);

      expect(find.text('HEALTH SCORE'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Health score, [0-9]+')), findsOne);
      // A mini ring for each area, then the activity rings and tiles.
      for (final p in ['Activity', 'Sleep', 'Heart', 'Nutrition', 'Body']) {
        expect(find.bySemanticsLabel(RegExp('^$p, ')), findsWidgets);
      }
      await _scrollDownTo(tester, find.text('Move'));
      for (final p in ['Sleep', 'Heart', 'Nutrition', 'Body']) {
        await _scrollDownTo(tester, find.text(p));
        expect(find.text(p), findsWidgets);
      }
      // The old customizable cards are gone.
      expect(find.text('Edit Summary'), findsNothing);
      expect(find.text('Make Summary Yours'), findsNothing);

      // Each period has its own score.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pumpAndSettle();
      for (final p in ['Week', 'Month', '3M', 'Year', 'Today']) {
        await tester.tap(find.text(p));
        await tester.pumpAndSettle();
        expect(find.text('HEALTH SCORE'), findsOneWidget);
      }
    });

    testWidgets('a Summary tile opens its details', (tester) async {
      await _pumpApp(tester, onboarded: true);
      final tile = find.bySemanticsLabel(RegExp('^Sleep, .*last night'));
      await _scrollDownTo(tester, tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.text('Sleep'), findsWidgets);
      expect(find.text('HEALTH SCORE'), findsNothing);
    });

    testWidgets('the weekly check-in shows on Summary until answered', (
      tester,
    ) async {
      final h = await _pumpApp(tester, onboarded: true);
      final today = h.store.today;
      // Only these weigh-ins, not the sample data's.
      for (final e in [...h.store.entriesFor(MetricType.weight)]) {
        await h.store.deleteEntry(e.id);
      }
      for (var i = 20; i >= 0; i--) {
        await h.store.addEntry(
          MetricType.weight,
          80 - 0.02 * (20 - i),
          date: DateTime(today.year, today.month, today.day - i, 7),
        );
      }
      await h.store.setBodyGoal(
        BodyGoal(
          objective: GoalObjective.lose,
          weeklyRateKg: 0.5,
          startKg: 80,
          startDate: DateTime(today.year, today.month, today.day - 14),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollDownTo(tester, find.text('Weekly Check-In'));
      expect(find.text('Weekly Check-In'), findsOneWidget);
      // Losing about 0.14 kg a week against 0.5 planned: eat a bit less.
      expect(find.textContaining('slower than planned'), findsOneWidget);
      expect(find.textContaining('a day for the next week'), findsOneWidget);
      final before = h.nutrition.goals.kcal;
      await tester.tap(find.textContaining(RegExp(r'^Use ')));
      await tester.pumpAndSettle();
      expect(h.nutrition.goals.kcal, lessThan(before));
      expect(h.store.bodyGoal.checkedIn, h.store.today);
      expect(find.text('Weekly Check-In'), findsNothing);
    });

    testWidgets('Appearance changes the theme colour everywhere', (
      tester,
    ) async {
      final h = await _pumpApp(tester, onboarded: true);
      await _openSettings(tester);
      await _reveal(tester, find.text('Appearance'));
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Indigo'));
      await tester.pumpAndSettle();

      expect(h.store.personalization.accent, AppAccent.indigo);
      final ctx = tester.element(find.text('Theme Colour'.toUpperCase()));
      expect(
        CupertinoTheme.of(ctx).primaryColor.toARGB32(),
        CupertinoDynamicColor.resolve(Palette.indigo, ctx).toARGB32(),
      );

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(h.store.themeMode, ThemeMode.dark);
    });

    testWidgets('Reduce Motion in the app stops animations', (tester) async {
      final h = await _pumpApp(tester, onboarded: true);
      await h.store.setPersonalization(
        h.store.personalization.copyWith(reduceMotion: true),
      );
      await tester.pumpAndSettle();

      final ctx = tester.element(find.text('Activity').first);
      expect(MediaQuery.disableAnimationsOf(ctx), isTrue);
    });

    testWidgets('Health tab opens a category of cards', (tester) async {
      await _pumpApp(tester, onboarded: true);
      await _openTab(tester, 'Health');

      await tester.tap(find.text('Heart').first);
      await tester.pumpAndSettle();
      expect(find.byType(MetricCard), findsWidgets);
      expect(find.text('Resting Heart Rate'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Achievements'));
      expect(find.text('Trends'), findsOneWidget);
      // The store version leaves Medications out.
      expect(
        find.text('Medications'),
        kStoreEdition ? findsNothing : findsOneWidget,
      );
    });

    testWidgets('Health tab: vitals, body lanes and trackers', (tester) async {
      await _pumpApp(tester, onboarded: true);
      await _openTab(tester, 'Health');
      expect(find.text('Resting Heart Rate'), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('^Your vitals')), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
      await _reveal(tester, find.text('Sleep').first);
      await tester.tap(find.bySemanticsLabel(RegExp('^Sleep, ')).first);
      await tester.pumpAndSettle();
      expect(find.byType(MetricCard), findsWidgets);
    });

    testWidgets('Profile shows stats, goals and backup options', (
      tester,
    ) async {
      await _pumpApp(tester, onboarded: true);
      await _openTab(tester, 'Profile');

      expect(find.text('Workouts'), findsWidgets);
      expect(find.text('Day Streak'), findsOneWidget);
      expect(find.text('BMI'), findsOneWidget);
      await _reveal(tester, find.text('Medical ID'));
      // Settings aren't on Profile any more.
      expect(find.text('Backup, Import & Export'), findsNothing);

      await _reveal(tester, find.text('Daily Goals'));
      await tester.tap(find.text('Daily Goals'));
      await tester.pumpAndSettle();
      expect(find.text('DAILY GOALS'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Settings').first);
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Backup, Import & Export'));
      await tester.tap(find.text('Backup, Import & Export'));
      await tester.pumpAndSettle();
      expect(find.text('Back Up Now'), findsOneWidget);
      expect(find.text('Restore from Backup'), findsOneWidget);
      expect(find.text('Export Spreadsheets'), findsOneWidget);

      await tester.tap(find.text('Back Up Now'));
      await tester.pumpAndSettle();
      expect(find.text('Protect Backup?'), findsOneWidget);
      await tester.enterText(find.byType(CupertinoTextField).first, 'short');
      await tester.tap(find.text('Protect'));
      await tester.pumpAndSettle();
      expect(find.textContaining('at least 10'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Protect Backup?'), findsNothing);
    });
  });

  group('new features', () {
    testWidgets('add a medication and take a dose', (tester) async {
      final h = await _pumpApp(tester, onboarded: true);
      await _openTab(tester, 'Health');
      await _reveal(tester, find.text('Medications'));
      await tester.tap(find.text('Medications'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add a Medication'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(CupertinoTextField).first,
        'Vitamin D',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(h.meds.all.single.name, 'Vitamin D');
      expect(h.notifier.medications, isNotEmpty);
      // Default time 8:00 AM; the test clock is 3:30 PM.
      expect(find.text('Take'), findsOneWidget);
      await tester.tap(find.text('Take'));
      await tester.pumpAndSettle();
      expect(h.meds.slotsOn(h.store.today).single.log, isNotNull);
      expect(find.textContaining('Taken'), findsOneWidget);
    }, skip: kStoreEdition);

    testWidgets('cycle tracking: start, log a period, see prediction', (
      tester,
    ) async {
      final h = await _pumpApp(tester, onboarded: true);
      await _openTab(tester, 'Health');
      await _reveal(tester, find.text('Cycle Tracking'));
      await tester.tap(find.text('Cycle Tracking'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      expect(h.cycle.enabled, isTrue);
      await tester.tap(find.text('Period Started'));
      await tester.pumpAndSettle();

      expect(h.cycle.forecast.nextStart, isNotNull);
      expect(find.text('Period in 28 days'), findsOneWidget);
    });

    testWidgets('trends and achievements open from the Health tab', (
      tester,
    ) async {
      await _pumpApp(tester, onboarded: true);
      await _openTab(tester, 'Health');
      await _reveal(tester, find.text('Trends'));
      await tester.tap(find.text('Trends'));
      await tester.pumpAndSettle();
      expect(find.textContaining('last 90 days'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await _reveal(tester, find.text('Achievements'));
      await tester.tap(find.text('Achievements'));
      await tester.pumpAndSettle();
      expect(find.textContaining('medals'), findsWidgets);
      expect(find.byType(Medal), findsWidgets);
    });

    testWidgets('sleep and heart rate show stages and zones', (tester) async {
      await _pumpApp(tester, onboarded: true);
      final ctx = tester.element(find.text('Activity').first);
      unawaited(MetricDetailScreen.open(ctx, MetricType.sleep));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Sleep Stages'));
      expect(find.text('Deep'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      unawaited(MetricDetailScreen.open(ctx, MetricType.heartRate));
      await tester.pumpAndSettle();
      await tester.tap(find.text('W'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Heart Rate Zones'));
      expect(find.text('Zone 2'), findsOneWidget);
    });

    testWidgets('a metric that isn\'t shared says so on its page', (
      tester,
    ) async {
      final h = await _pumpApp(tester, onboarded: true);
      await h.sync.connect();
      await tester.pumpAndSettle();
      final ctx = tester.element(find.text('Activity').first);
      unawaited(MetricDetailScreen.open(ctx, MetricType.heartRate));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Manage Permissions'));
      expect(find.textContaining('isn\'t allowed in'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Shared: no notice.
      unawaited(MetricDetailScreen.open(ctx, MetricType.steps));
      await tester.pumpAndSettle();
      // The notice would sit right above Show All Data.
      await _reveal(tester, find.text('Show All Data'));
      expect(find.text('Manage Permissions'), findsNothing);
      expect(find.textContaining('imported from'), findsOneWidget);
    });

    testWidgets('the Day tab links every reading to the day\'s run', (
      tester,
    ) async {
      final h = await _pumpApp(tester, onboarded: true);
      h.source.grant.add(MetricType.heartRate);
      for (final (minute, bpm) in [(0, 70.0), (35, 150.0), (40, 172.0)]) {
        final at = DateTime(2026, 10, 11, 9, minute);
        h.source.samples.add(
          HealthSample(
            type: MetricType.heartRate,
            value: bpm,
            start: at,
            end: at,
          ),
        );
      }
      await h.workouts.importSessions([
        WorkoutSession(
          id: 'run',
          type: WorkoutType.run,
          start: DateTime(2026, 10, 11, 9, 30),
          end: DateTime(2026, 10, 11, 10),
          activeSeconds: 1800,
        ),
      ]);
      await h.sync.connect();
      await tester.pumpAndSettle();
      final ctx = tester.element(find.text('Activity').first);
      unawaited(MetricDetailScreen.open(ctx, MetricType.heartRate));
      await tester.pumpAndSettle();

      // Opens on the Day tab.
      expect(find.text('3 readings · average 131 bpm'), findsOneWidget);
      expect(find.text('Hour by Hour'), findsOneWidget);
      await _reveal(tester, find.text('Rest of the Day'));
      // The highest reading was during the run.
      expect(find.textContaining('· ${WorkoutType.run.label}'), findsOneWidget);
      expect(find.text('161 bpm'), findsOneWidget); // the run's average
      expect(find.text('70 bpm'), findsWidgets); // the rest of the day

      // Full screen: zoom in, then tap the chart to read the nearest point.
      await _reveal(tester, find.byIcon(Icons.open_in_full_rounded));
      await tester.tap(find.byIcon(Icons.open_in_full_rounded));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tap the chart'), findsOneWidget);
      final view = find.byType(OverflowBox).last;
      bool canZoomOut() =>
          tester
              .widget<CupertinoButton>(
                find.ancestor(
                  of: find.byIcon(Icons.zoom_out_rounded),
                  matching: find.byType(CupertinoButton),
                ),
              )
              .onPressed !=
          null;
      // Pinch apart zooms in; pinch together zooms back out to the whole day.
      Future<void> pinch(double from, double to) async {
        final mid = tester.getCenter(view);
        final a = await tester.startGesture(mid - Offset(from, 0));
        final b = await tester.startGesture(mid + Offset(from, 0), pointer: 2);
        for (var i = 1; i <= 5; i++) {
          final d = from + (to - from) * i / 5;
          await a.moveTo(mid - Offset(d, 0));
          await b.moveTo(mid + Offset(d, 0));
          await tester.pump();
        }
        await a.up();
        await b.up();
        await tester.pumpAndSettle();
      }

      expect(canZoomOut(), isFalse);
      await pinch(20, 120);
      expect(canZoomOut(), isTrue);
      await pinch(120, 10);
      expect(canZoomOut(), isFalse);

      await tester.tap(find.byIcon(Icons.zoom_in_rounded));
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getTopLeft(view) + const Offset(4, 40));
      await tester.pumpAndSettle();
      // Zoomed around noon, the left edge is 6 AM: nearest is 9:00's 70 bpm.
      expect(find.text('70 bpm'), findsOneWidget);
    });

    testWidgets('every chart style draws', (tester) async {
      for (final style in ChartStyle.values) {
        await tester.pumpWidget(
          CupertinoApp(
            home: BarChart(
              values: const [3, 5, null, 4, 6],
              color: const Color(0xFFFF9500),
              style: style,
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: style.name);
      }
    });

    testWidgets('habits: a suggestion adds one, the circle ticks it off', (
      tester,
    ) async {
      final h = await _pumpApp(tester, onboarded: true);
      final ctx = tester.element(find.text('Activity').first);
      final mood = Provider.of<MoodStore>(ctx, listen: false);
      unawaited(HabitsScreen.open(ctx));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Read'));
      await tester.pumpAndSettle();
      expect(mood.habits, ['Read']);
      expect(find.text('0 of 1 done today'), findsOneWidget);

      await tester.tap(find.byIcon(CupertinoIcons.circle));
      await tester.pumpAndSettle();
      expect(mood.didHabit('Read', h.store.today), isTrue);
      expect(find.text('All done today'), findsOneWidget);

      // The strip's left end is 29 days ago.
      // The strip sits in the 44pt band just above its footnote.
      final note = find.text('Done 1 of the last 30 days');
      await tester.tapAt(tester.getTopLeft(note) + const Offset(2, -22));
      await tester.pumpAndSettle();
      final t = h.store.today;
      expect(
        mood.didHabit('Read', DateTime(t.year, t.month, t.day - 29)),
        isTrue,
      );

      // Touch and hold, then choose a new icon and colour.
      await tester.longPress(find.text('Read').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Icon and Colour'));
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();
      await tester.tap(find.bySemanticsLabel('Pets'));
      await tester.tap(find.bySemanticsLabel('Red'));
      semantics.dispose();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(mood.look('Read'), (icon: 'pet', color: 'red'));
      expect(find.byIcon(Icons.pets_rounded), findsOneWidget);
    });

    testWidgets('only Heart Rate has a Day tab', (tester) async {
      await _pumpApp(tester, onboarded: true);
      final ctx = tester.element(find.text('Activity').first);
      unawaited(MetricDetailScreen.open(ctx, MetricType.steps));
      await tester.pumpAndSettle();
      expect(find.text('W'), findsOneWidget);
      expect(find.text('D'), findsNothing);
    });

    testWidgets('imperial units change what is shown', (tester) async {
      final h = await _pumpApp(tester, onboarded: true);
      await _openSettings(tester);
      await _reveal(tester, find.text('Appearance'));
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      // Bring the Units section to the middle of the screen.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Imperial'));
      await tester.pumpAndSettle();
      expect(Units.imperial, isTrue);
      addTearDown(() => Units.system = UnitSystem.metric);

      await _openTab(tester, 'Summary');
      await _scrollDownTo(tester, find.textContaining(RegExp(r'\bfl oz\b')));
      expect(find.textContaining(RegExp(r'\bfl oz\b')), findsWidgets);
      expect(find.textContaining(RegExp(r'\bml\b')), findsNothing);
      await h.store.setPersonalization(
        h.store.personalization.copyWith(units: UnitSystem.metric),
      );
    });

    testWidgets('App Lock turns on and covers the app when locked', (
      tester,
    ) async {
      final h = await _pumpApp(tester, onboarded: true);
      await _openSettings(tester);
      await _reveal(tester, find.text('App Lock'));
      await tester.tap(find.text('App Lock'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CupertinoSwitch).first);
      await tester.pumpAndSettle();
      expect(h.appLock.enabled, isTrue);
      expect(h.appLock.hideInSwitcher, isTrue);

      // Leave for longer than a minute.
      h.appLock.didChangeAppLifecycleState(AppLifecycleState.paused);
      h.appLock.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      // Test clock doesn't move, so "after 1 minute" hasn't passed.
      expect(find.text('Health is Locked'), findsNothing);

      await h.appLock.setLockAfter(LockAfter.immediately);
      h.appLock.didChangeAppLifecycleState(AppLifecycleState.paused);
      h.auth.succeed = false;
      h.appLock.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Health is Locked'), findsOneWidget);
      // Back while locked doesn't close the screen behind the lock.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      h.auth.succeed = true;
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(find.text('Health is Locked'), findsNothing);
      expect(find.text('Hide in App Switcher'), findsOneWidget);
    });

    testWidgets('automatic backups turn on with a folder and password', (
      tester,
    ) async {
      await _pumpApp(tester, onboarded: true);
      await _openSettings(tester);
      await _reveal(tester, find.text('Backup, Import & Export'));
      await tester.tap(find.text('Backup, Import & Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Automatic Backups'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();

      expect(find.text('Backup Password'), findsOneWidget);
      expect(find.text('No Password'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Backup Password'), findsNothing);
    });
  });

  group('workout redesign', () {
    testWidgets('library: grid by default, list toggle, equipment filter', (
      tester,
    ) async {
      await _pumpApp(tester, onboarded: true);
      await _openTab(tester, 'Fitness');
      await _reveal(tester, find.text('Exercise Library'));
      await tester.tap(find.text('Exercise Library'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(ExerciseFigure), findsWidgets);

      await tester.tap(find.text('Assisted'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('· Assisted'), findsWidgets);
      expect(find.textContaining('· Barbell'), findsNothing);

      await tester.tap(find.bySemanticsLabel('List view'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ExerciseFigure), findsNothing);
    });

    testWidgets('Summary is titled by the day, greeting kept small', (
      tester,
    ) async {
      await _pumpApp(tester, onboarded: true);
      expect(find.text('Sunday, October 11'), findsOneWidget);
      expect(find.text('Good afternoon, Alex'), findsOneWidget);
      expect(find.textContaining('to close your'), findsNothing);
    });

    testWidgets('workout detail compares with last time', (tester) async {
      final h = await _pumpApp(tester, onboarded: true);
      for (final (id, day, kg) in [('a', 1, 100.0), ('b', 8, 110.0)]) {
        await h.workouts.save(
          WorkoutSession(
            id: id,
            type: WorkoutType.strength,
            start: DateTime(2026, 10, day, 18),
            end: DateTime(2026, 10, day, 19),
            activeSeconds: 3600,
            exercises: [
              ExerciseLog(
                exerciseId: 'squat',
                sets: [SetLog(reps: 5, weightKg: kg, done: true)],
              ),
            ],
          ),
        );
      }
      final ctx = tester.element(find.text('Activity').first);
      unawaited(WorkoutDetailScreen.open(ctx, h.workouts.byId('b')!));
      // The body map loads off the UI thread (never in tests), so its
      // spinner keeps going: pump frames rather than settle.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Compared with Last Time'), findsOneWidget);
      await tester.dragUntilVisible(
        find.text('PR'),
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      expect(find.text('PR'), findsOneWidget);
    });
  });

  group('food diary', () {
    testWidgets('Food is its own tab between Health and Fitness', (
      tester,
    ) async {
      await _pumpApp(tester, onboarded: true);
      final labels = ['Summary', 'Health', 'Food', 'Fitness', 'Profile'];
      final xs = [for (final l in labels) tester.getCenter(_tabButton(l)).dx];
      expect(xs, orderedEquals([...xs]..sort()));

      await _openTab(tester, 'Food');
      expect(find.text('Breakfast'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Previous day'));
      await tester.pumpAndSettle();
      expect(find.textContaining('YESTERDAY'), findsOneWidget);

      // Links from other tabs switch to the Food tab, not a pushed copy,
      // and show today.
      await _openTab(tester, 'Health');
      await _reveal(tester, find.text('Food & Calories'));
      await tester.tap(find.text('Food & Calories'));
      await tester.pumpAndSettle();
      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.byType(FoodDiaryScreen), findsOneWidget);
      expect(find.textContaining('TODAY'), findsOneWidget);
    });

    testWidgets('search Open Food Facts and log a food to lunch', (
      tester,
    ) async {
      final h = await _pumpApp(tester, onboarded: true);
      await _openTab(tester, 'Health');
      await _reveal(tester, find.text('Food & Calories'));
      await tester.tap(find.text('Food & Calories'));
      await tester.pumpAndSettle();
      expect(find.text('CALORIES'), findsWidgets);

      await _reveal(tester, find.text('Add Food').at(1));
      await tester.tap(find.text('Add Food').at(1)); // Lunch
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoSearchTextField), 'yogurt');
      // Searches by itself once typing pauses; no Enter needed.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Nonfat Greek Yogurt'), findsOneWidget);

      await tester.tap(find.text('Nonfat Greek Yogurt'));
      await tester.pumpAndSettle();
      expect(find.text('Nutrition Facts'), findsOneWidget);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Nonfat Greek Yogurt'), findsOneWidget);
      expect(h.store.todayValue(MetricType.dietaryEnergy), closeTo(52.9, 0.1));
    });

    testWidgets('an unknown barcode can be added from the label', (
      tester,
    ) async {
      final h = await _pumpApp(tester, onboarded: true);
      final ctx = tester.element(find.text('Activity').first);
      Food? result;
      unawaited(foodForBarcode(ctx, '5012345678900').then((f) => result = f));
      await tester.pumpAndSettle();
      expect(find.text('Product Not Found'), findsOneWidget);
      await tester.tap(find.text('Add Food'));
      await tester.pumpAndSettle();
      final fields = find.byType(CupertinoTextField);
      await tester.enterText(fields.at(0), 'Mystery Bar');
      await tester.enterText(fields.at(4), '210');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(result?.name, 'Mystery Bar');
      expect(result?.barcode, '5012345678900');
      expect(result?.perServing.kcal, 210);
      expect(
        Provider.of<NutritionStore>(ctx, listen: false).custom.single.name,
        'Mystery Bar',
      );
      expect(h.store.allEntries, isNotEmpty);
    });
  });

  group('v19 features', () {
    T read<T>(WidgetTester tester) =>
        Provider.of<T>(tester.element(find.byType(HealthApp)), listen: false);

    testWidgets('a fast schedules its end and is recorded when ended', (
      tester,
    ) async {
      final h = await _pumpApp(tester, onboarded: true);
      final fasting = read<FastingStore>(tester);
      await fasting.start();
      expect(
        h.notifier.single[NotificationIds.fastingDone]?.$2,
        'Fast Complete',
      );
      // The live countdown runs to the same end.
      expect(
        h.notifier.fastingEnd,
        h.notifier.single[NotificationIds.fastingDone]?.$1,
      );
      await fasting.end();
      expect(
        h.notifier.single.containsKey(NotificationIds.fastingDone),
        isFalse,
      );
      expect(h.notifier.fastingEnd, isNull);
      expect(fasting.history, isEmpty); // ended at once: zero length
      await tester.pumpAndSettle();
    });

    testWidgets('sleep schedule sets the sleep goal and a wind-down reminder', (
      tester,
    ) async {
      final h = await _pumpApp(tester, onboarded: true);
      final sleep = read<SleepScheduleStore>(tester);
      await sleep.update(
        sleep.schedule.copyWith(
          enabled: true,
          bedtime: (hour: 23, minute: 0),
          wake: (hour: 7, minute: 30),
        ),
      );
      expect(h.store.goals.sleep, 8.5);
      expect(h.notifier.single[NotificationIds.windDown]?.$1, (
        hour: 22,
        minute: 30,
      ));
      await sleep.update(sleep.schedule.copyWith(remind: false));
      expect(h.notifier.single.containsKey(NotificationIds.windDown), isFalse);
    });

    testWidgets('a program can be started from Fitness', (tester) async {
      await _pumpApp(tester, onboarded: true);
      await _openTab(tester, 'Fitness');
      await _reveal(tester, find.text('Programs'));
      await tester.tap(find.text('Programs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Program').first);
      await tester.pumpAndSettle();
      expect(read<ProgramStore>(tester).program, WorkoutProgram.couchTo5k);
      expect(find.text('Week 1 of 9'), findsOneWidget);
    });

    testWidgets('Health trackers open the new screens', (tester) async {
      await _pumpApp(tester, onboarded: true);
      await _openTab(tester, 'Health');
      for (final (tracker, title) in [
        ('Monthly Recap', 'Share Recap'),
        ('Health Report', 'Create & Share PDF'),
        ('Fasting', 'Start Fast'),
        ('Sleep Schedule', 'Bedtime'),
      ]) {
        await _reveal(tester, find.bySemanticsLabel(RegExp('^$tracker, ')));
        await tester.tap(find.bySemanticsLabel(RegExp('^$tracker, ')).first);
        await tester.pumpAndSettle();
        expect(find.text(title), findsWidgets, reason: tracker);
        await tester.tap(find.byType(CupertinoNavigationBarBackButton).first);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('blood pressure is logged as one reading', (tester) async {
      final h = await _pumpApp(tester, onboarded: true);
      final ctx = tester.element(find.text('Activity').first);
      unawaited(AddEntrySheet.show(ctx, MetricType.bloodPressureSystolic));
      await tester.pumpAndSettle();
      expect(find.text('Blood Pressure'), findsWidgets);
      await tester.enterText(find.byType(CupertinoTextField).at(0), '128');
      await tester.enterText(find.byType(CupertinoTextField).at(1), '82');
      await tester.pump();
      await tester.tap(find.text('Add').last);
      await tester.pumpAndSettle();
      expect(
        h.store.latestReading(MetricType.bloodPressureSystolic)?.value,
        128,
      );
      expect(
        h.store.latestReading(MetricType.bloodPressureDiastolic)?.value,
        82,
      );
    });

    testWidgets('water sizes follow the units and log in one tap', (
      tester,
    ) async {
      final h = await _pumpApp(tester, onboarded: true);
      final ctx = tester.element(find.text('Activity').first);
      Iterable<double> logged() =>
          h.store.entriesFor(MetricType.water).map((e) => e.value);
      unawaited(AddEntrySheet.show(ctx, MetricType.water));
      await tester.pumpAndSettle();
      expect(find.text('1 L'), findsOneWidget);
      await tester.tap(find.text('500 ml'));
      await tester.pumpAndSettle();
      expect(logged(), contains(500));

      Units.system = UnitSystem.imperial;
      addTearDown(() => Units.system = UnitSystem.metric);
      unawaited(AddEntrySheet.show(ctx, MetricType.water));
      await tester.pumpAndSettle();
      expect(find.text('8 fl oz'), findsOneWidget);
      await tester.tap(find.text('1 gal'));
      await tester.pumpAndSettle();
      expect(logged().any((v) => (v - 3785.4).abs() < 0.1), isTrue);
    });

    testWidgets('meals can be saved and logged in one tap', (tester) async {
      final h = await _pumpApp(tester, onboarded: true);
      const toast = Food(
        id: 'toast',
        name: 'Toast',
        perServing: Nutrients(kcal: 90),
      );
      await h.nutrition.saveTemplate(
        const MealTemplate(
          id: 't1',
          name: 'Breakfast Usual',
          items: [
            FoodPortion(food: toast, amount: 2),
            FoodPortion(food: toast, amount: 1),
          ],
        ),
      );
      final before = h.nutrition.totalOn(h.store.today).kcal;
      await h.nutrition.logTemplate(
        h.nutrition.templates.single,
        meal: Meal.breakfast,
        date: h.store.now,
      );
      expect(h.nutrition.totalOn(h.store.today).kcal, before + 270);
    });
  });

  group('widget boards', () {
    Finder onBoard(String label) => find.descendant(
      of: find.byType(WidgetBoard),
      matching: find.text(label),
    );

    Future<void> startEditing(WidgetTester tester, String tab) async {
      await tester.tap(find.bySemanticsLabel('Edit $tab'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Done'), findsOneWidget);
    }

    Future<void> openGallery(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel('Add Widget'));
      await tester.pumpAndSettle();
      expect(find.text('Add Widgets'), findsOneWidget);
    }

    Future<void> toggleInGallery(WidgetTester tester, String label) async {
      final row = find.bySemanticsLabel(label);
      await tester.scrollUntilVisible(
        row,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      // Clear of the sheet's bottom edge.
      final bottom =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      if (tester.getCenter(row.last).dy > bottom - 60) {
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -120));
        await tester.pumpAndSettle();
      }
      await tester.tap(row.last);
      await tester.pumpAndSettle();
    }

    Future<void> closeGallery(WidgetTester tester) async {
      await tester.tap(find.text('Done').last);
      await tester.pumpAndSettle();
    }

    testWidgets('Health shows vitals, body, trackers and metric widgets', (
      tester,
    ) async {
      await _pumpApp(tester, onboarded: true);
      await _openTab(tester, 'Health');

      expect(find.bySemanticsLabel(RegExp('^Your vitals')), findsOneWidget);
      for (final label in ['Body', 'Mood', 'Steps']) {
        await _scrollDownTo(tester, onBoard(label));
        expect(onBoard(label), findsWidgets);
      }
    });

    testWidgets('a metric widget opens its metric', (tester) async {
      final h = await _pumpApp(tester, onboarded: true);
      await _withMetricTiles(tester, h);
      await _openTab(tester, 'Health');
      final heartRate = find.bySemanticsLabel(RegExp(r'^Heart Rate, \d'));
      await _scrollDownTo(tester, heartRate);

      await tester.tap(heartRate);
      await tester.pumpAndSettle();

      expect(find.byType(MetricDetailScreen), findsOneWidget);
    });

    testWidgets('editing removes and resizes widgets', (tester) async {
      final h = await _pumpApp(tester, onboarded: true);
      await _withMetricTiles(tester, h);
      await _openTab(tester, 'Health');
      await startEditing(tester, 'Health');

      WidgetSize sleepSize() =>
          h.store.widgets.firstWhere((w) => w.metric == MetricType.sleep).size;
      Future<void> resize(String to) async {
        final badge = find.bySemanticsLabel('Make Sleep $to');
        await _scrollDownTo(tester, badge);
        await tester.tap(badge);
        await tester.pumpAndSettle();
      }

      Finder sleepTile(WidgetSize size) => find.byWidgetPredicate(
        (w) => w is StatWidget && w.size == size && w.title == 'Sleep',
      );

      await resize('medium');
      expect(sleepSize(), WidgetSize.medium);
      // Medium is a whole row, as compact as a small one, with key numbers.
      final medium = sleepTile(WidgetSize.medium);
      expect(tester.getSize(medium).height, WidgetBoard.smallHeight);
      for (final fact in ['Average', 'High', 'Low']) {
        expect(
          find.descendant(of: medium, matching: find.text(fact)),
          findsOneWidget,
        );
      }

      await resize('large');
      expect(sleepSize(), WidgetSize.large);
      // Large adds two rows of facts and the last 30 days under it.
      final large = sleepTile(WidgetSize.large);
      expect(
        tester.getSize(large).height,
        WidgetBoard.smallHeight +
            StatWidget.factsHeight * 2 +
            StatWidget.historyHeight,
      );
      expect(
        find.descendant(of: large, matching: find.text('Last 30 Days')),
        findsOneWidget,
      );
      for (final fact in [
        'Average',
        'High',
        'Low',
        'Last Week',
        '30-Day Average',
        'Days Logged',
      ]) {
        expect(
          find.descendant(of: large, matching: find.text(fact)),
          findsOneWidget,
        );
      }
      await resize('small');
      expect(sleepSize(), WidgetSize.small);

      final remove = find.bySemanticsLabel('Remove Sleep');
      await _scrollDownTo(tester, remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(h.store.isPinned(MetricType.sleep), isFalse);

      await tester.tap(find.bySemanticsLabel('Done'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Edit Health'), findsOneWidget);
    });

    testWidgets('touch and hold starts editing', (tester) async {
      final h = await _pumpApp(tester, onboarded: true);
      await _withMetricTiles(tester, h);
      await _openTab(tester, 'Health');
      final steps = onBoard('Steps');
      await _scrollDownTo(tester, steps);

      await tester.longPress(steps.first);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Done'), findsOneWidget);
      expect(find.bySemanticsLabel('Remove Steps'), findsOneWidget);
    });

    // Known bug, being fixed: a dragged widget never reaches the widget
    // under the finger.
    testWidgets('while editing, widgets can be dragged again and again', (
      tester,
    ) async {
      final h = await _pumpApp(tester, onboarded: true);
      await _openTab(tester, 'Health');
      await startEditing(tester, 'Health');

      Future<void> drag(String from, String to) async {
        final a = tester.getCenter(onBoard(from).first);
        final b = tester.getCenter(onBoard(to).first);
        final g = await tester.startGesture(a);
        await tester.pump(const Duration(milliseconds: 500));
        for (var i = 1; i <= 10; i++) {
          await g.moveTo(Offset.lerp(a, b, i / 10)!);
          await tester.pump(const Duration(milliseconds: 30));
        }
        await tester.pump(const Duration(milliseconds: 600));
        await g.up();
        await tester.pumpAndSettle();
      }

      List<String> ids() => h.store.board(BoardTab.health).ids;
      final start = ids();
      await drag('Activity', 'Heart');
      final once = ids();
      expect(once, isNot(start), reason: 'the first drag moved nothing');
      expect(find.bySemanticsLabel('Done'), findsOneWidget);

      await drag('Activity', 'Heart');
      expect(ids(), isNot(once), reason: 'the second drag moved nothing');
      await drag('Sleep', 'Vitals');
      expect(ids(), isNot(once), reason: 'a third drag moved nothing');
    });

    testWidgets('the gallery adds a Health widget', (tester) async {
      final h = await _pumpApp(tester, onboarded: true);
      await _openTab(tester, 'Health');
      await startEditing(tester, 'Health');
      await openGallery(tester);

      await toggleInGallery(tester, 'Water');
      await closeGallery(tester);

      expect(h.store.isPinned(MetricType.water), isTrue);
    });

    testWidgets('Fitness sections can be removed and added back', (
      tester,
    ) async {
      final h = await _pumpApp(tester, onboarded: true);
      await _openTab(tester, 'Fitness');
      expect(find.text('Start a Workout'), findsOneWidget);
      await startEditing(tester, 'Fitness');

      await tester.tap(find.bySemanticsLabel('Remove Start a Workout'));
      await tester.pumpAndSettle();
      expect(find.text('Start a Workout'), findsNothing);
      expect(
        h.store.board(BoardTab.fitness).ids,
        isNot(contains('fitness.start')),
      );

      await openGallery(tester);
      await toggleInGallery(tester, "Today's Plan");
      await toggleInGallery(tester, 'Start a Workout');
      await toggleInGallery(tester, 'Steps');
      await closeGallery(tester);

      final ids = h.store.board(BoardTab.fitness).ids;
      expect(ids, contains('fitness.today'));
      expect(ids, contains('fitness.start'));
      expect(ids.last, 'metric.steps');
    });

    testWidgets('Fitness follows the board order', (tester) async {
      final h = await _pumpApp(tester, onboarded: true);
      final fitness = h.store.board(BoardTab.fitness);
      await h.store.updateBoard(
        BoardTab.fitness,
        fitness.withMoved(fitness.indexOf('fitness.start'), 0),
      );
      await _openTab(tester, 'Fitness');

      // Start a Workout is now the first section, above This Week.
      expect(
        tester.getTopLeft(find.text('Start a Workout')).dy,
        lessThan(
          tester
              .getTopLeft(find.bySemanticsLabel(RegExp('^This week[:,] ')))
              .dy,
        ),
      );
    });

    testWidgets('Summary starts with water and can show any tab\'s widgets', (
      tester,
    ) async {
      final h = await _pumpApp(tester, onboarded: true);
      final ids = h.store.board(BoardTab.summary).ids;
      expect(ids, contains(BoardIds.water));
      expect(ids, isNot(contains(BoardIds.body)));
      await _openTab(tester, 'Summary');
      await startEditing(tester, 'Summary');

      await _scrollDownTo(tester, find.bySemanticsLabel('Remove What Changed'));
      await tester.tap(find.bySemanticsLabel('Remove What Changed'));
      await tester.pumpAndSettle();
      expect(
        h.store.board(BoardTab.summary).ids,
        isNot(contains(BoardIds.changes)),
      );

      // Widgets from the other tabs are in its gallery too.
      await openGallery(tester);
      await toggleInGallery(tester, 'Macros');
      await closeGallery(tester);
      expect(h.store.board(BoardTab.summary).ids.last, BoardIds.macros);
    });

    testWidgets('Food widgets can be removed and a metric added', (
      tester,
    ) async {
      final h = await _pumpApp(tester, onboarded: true);
      await _openTab(tester, 'Food');
      expect(find.text('Protein'), findsWidgets);
      await startEditing(tester, 'Food');

      await tester.tap(find.bySemanticsLabel('Remove Macros'));
      await tester.pumpAndSettle();
      expect(h.store.board(BoardTab.food).ids, isNot(contains('food.macros')));

      await openGallery(tester);
      await toggleInGallery(tester, 'Water');
      await closeGallery(tester);
      expect(h.store.board(BoardTab.food).ids.last, 'metric.water');
    });

    testWidgets('every widget renders at every size it comes in', (
      tester,
    ) async {
      final h = await _pumpApp(tester, onboarded: true);
      final catalogs = {
        BoardTab.health: HealthScreen.catalog(),
        BoardTab.fitness: WorkoutsScreen.catalog(),
        BoardTab.food: FoodDiaryScreen.catalog(h.store.today),
        // The Summary's own widgets need its data; the board falls back
        // to a size each comes in.
        BoardTab.summary: [
          for (final id in BoardIds.summaryOwn)
            BoardEntry(
              id: id,
              label: id,
              icon: CupertinoIcons.circle,
              color: Palette.grey,
              group: '',
              builder: (_, _) => const SizedBox(),
              sizes: const {
                WidgetSize.small,
                WidgetSize.medium,
                WidgetSize.large,
              },
            ),
        ],
      };
      for (final MapEntry(key: tab, value: catalog) in catalogs.entries) {
        for (final size in WidgetSize.values) {
          await h.store.updateBoard(
            tab,
            Board([
              for (final e in catalog)
                if (e.sizes.contains(size)) BoardItem(e.id, size),
            ]),
          );
          await _openTab(tester, switch (tab) {
            BoardTab.health => 'Health',
            BoardTab.fitness => 'Fitness',
            BoardTab.food => 'Food',
            BoardTab.summary => 'Summary',
          });
          for (var i = 0; i < 40; i++) {
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -500),
            );
            await tester.pumpAndSettle();
          }
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, 100000),
          );
          await tester.pumpAndSettle();
        }
      }
      // Layout overflows would have failed the test with an exception.
    });

    for (final scale in [2.0, 3.0]) {
      testWidgets('boards fit at ${scale}x text', (tester) async {
        await _pumpApp(tester, onboarded: true, textScale: scale);
        for (final tab in ['Summary', 'Health', 'Fitness', 'Food']) {
          await _openTab(tester, tab);
          for (var i = 0; i < 6; i++) {
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -600),
            );
            await tester.pumpAndSettle();
          }
        }
        // Layout overflows would have failed the test with an exception.
      });
    }

    testWidgets('All Health Data lists every metric and searches', (
      tester,
    ) async {
      await _pumpApp(tester, onboarded: true);
      await _openTab(tester, 'Health');
      await _scrollDownTo(tester, find.text('All Health Data'));
      await tester.tap(find.text('All Health Data'));
      await tester.pumpAndSettle();

      expect(find.byType(AllHealthDataScreen), findsOneWidget);
      await tester.enterText(find.byType(CupertinoSearchTextField).last, 'oxy');
      await tester.pumpAndSettle();
      expect(find.byType(MetricRow), findsOneWidget);
      expect(find.text('Blood Oxygen'), findsOneWidget);
    });

    testWidgets('Health search finds trackers as well as metrics', (
      tester,
    ) async {
      await _pumpApp(tester, onboarded: true);
      await _openTab(tester, 'Health');
      final search = find.byType(CupertinoSearchTextField).first;
      await tester.enterText(search, 'habit');
      await tester.pumpAndSettle();
      expect(find.text('Habits'), findsOneWidget);
      expect(find.textContaining('No Results'), findsNothing);

      await tester.enterText(search, 'zzz');
      await tester.pumpAndSettle();
      expect(find.textContaining('No Results'), findsOneWidget);
    });
  });
}
