import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/app_edition.dart';
import 'package:health_app/backup/auto_backup.dart';
import 'package:health_app/data/health_repository.dart';
import 'package:health_app/export/backup.dart';
import 'package:health_app/export/backup_crypto.dart';
import 'package:health_app/insights/achievements.dart';
import 'package:health_app/insights/heart_zones.dart';
import 'package:health_app/insights/trends.dart';
import 'package:health_app/models/cycle.dart';
import 'package:health_app/models/medication.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/user_profile.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/notifications/reminder_plan.dart';
import 'package:health_app/platform/home_widgets.dart';
import 'package:health_app/security/app_lock.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/medication_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/sync/health_sample.dart';
import 'package:health_app/sync/health_sync_service.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/utils/units.dart';

import 'fake_authenticator.dart';
import 'fake_backup_folder.dart';
import 'fake_health_source.dart';
import 'fake_notifier.dart';

final _now = DateTime(2026, 10, 11, 15, 30);

Future<HealthStore> _store() async {
  final s = HealthStore(InMemoryHealthRepository(), clock: () => _now);
  await s.load();
  return s;
}

void main() {
  tearDown(() => Units.system = UnitSystem.metric);

  group('Units', () {
    test('metric shows stored values as they are', () {
      expect(formatValue(MetricType.weight, 72.5), '72.5');
      expect(unitLabel(MetricType.distance), 'km');
      expect(formatDistance(5240), '5.24 km');
    });

    test('imperial converts weight, distance, water, pace and height', () {
      Units.system = UnitSystem.imperial;
      expect(formatValue(MetricType.weight, 100), '220.5');
      expect(unitLabel(MetricType.weight), 'lb');
      expect(formatValue(MetricType.water, 236.6), '8.0');
      expect(unitLabel(MetricType.water), 'fl oz');
      expect(formatDistance(1609.344), '1.00 mi');
      expect(formatPace(300), "8'03\""); // 5:00/km ≈ 8:03/mi
      expect(Units.height(177.8), '5 ft 10 in');
      expect(Units.weightIn(Units.weightOut(80)), closeTo(80, 1e-9));
    });

    test('the unit setting follows personalization', () async {
      final s = await _store();
      await s.setPersonalization(
        s.personalization.copyWith(units: UnitSystem.imperial),
      );
      expect(Units.imperial, isTrue);
      await s.eraseAll();
      expect(Units.imperial, isFalse);
    });

    test('widget text uses the chosen units', () {
      Units.system = UnitSystem.imperial;
      final t = HomeWidgets.widgetText(goalMl: 2000);
      expect(t['waterGoalText'], 'of 67.6 fl oz');
      expect(t['waterButton'], '+ 8.5 fl oz');
    });
  });

  group('Heart zones', () {
    test('samples become minutes per band, with gaps capped', () {
      final t = DateTime(2026, 10, 11, 8);
      final bins = HeartBins.fromSamples([
        HealthSample(type: MetricType.heartRate, value: 65, start: t, end: t),
        HealthSample(
          type: MetricType.heartRate,
          value: 150,
          start: t.add(const Duration(minutes: 2)),
          end: t,
        ),
        HealthSample(
          type: MetricType.heartRate,
          value: 152,
          start: t.add(const Duration(hours: 1)),
          end: t,
        ),
      ])[DateTime(2026, 10, 11)]!;
      expect(bins[HeartBins.binOf(65)], 2);
      // 150 bpm counts 5 minutes (capped gap), 152 counts 1 (last).
      expect(bins[HeartBins.binOf(150)], 6);
    });

    test('bands map onto zones by max heart rate', () {
      final bins = List<double>.filled(HeartBins.count, 0);
      bins[HeartBins.binOf(145)] = 30; // 76% of 190 → zone 3
      bins[HeartBins.binOf(60)] = 500; // resting, not counted
      final z = ZoneMinutes.of([bins], maxHeartRate(30));
      expect(z.minutes[HeartZone.z3], 30);
      expect(z.total, 30);
      expect(maxHeartRate(null), 190);
    });

    test('the store keeps bands, and real data replaces samples', () async {
      final s = await _store();
      await s.loadSampleData();
      expect(s.hasHeartBins, isTrue);
      final day = DateTime(2026, 10, 11);
      await s.mergeHeartBins({day: List.filled(HeartBins.count, 1)});
      expect(s.heartBinsOn(DateTime(2026, 10, 1)), isNull);
      expect(s.heartBinsOn(day)!.first, 1);
      await s.removeSampleData();
      expect(s.heartBinsOn(day), isNotNull);
    });
  });

  group('Trends', () {
    test('compares the last 90 days with the months before', () {
      final trends = buildTrends(
        today: DateTime(2026, 10, 11),
        dailyValue: (type, day) {
          if (type != MetricType.steps) return null;
          final daysAgo = DateTime(2026, 10, 11).difference(day).inDays;
          return daysAgo <= 90 ? 10000 : 8000;
        },
      );
      final steps = trends.single;
      expect(steps.trend, Trend.up);
      expect(steps.change, closeTo(0.25, 0.01));
      expect(steps.isGood, isTrue);
    });

    test('needs enough history', () {
      final trends = buildTrends(
        today: DateTime(2026, 10, 11),
        dailyValue: (type, day) =>
            type == MetricType.steps && day.day == 1 ? 5000 : null,
      );
      expect(trends, isEmpty);
    });
  });

  group('Medications', () {
    const vitD = Medication(
      id: 'm1',
      name: 'Vitamin D',
      dose: '1000 IU',
      times: [8 * 60, 20 * 60],
    );

    test('round-trips and ignores bad values', () {
      final m = vitD.copyWith(days: {1, 3});
      expect(Medication.tryFromJson(m.toJson())!.toJson(), m.toJson());
      expect(Medication.tryFromJson({'id': 'x', 'name': ' '}), isNull);
      final odd = Medication.tryFromJson({
        'id': 'x',
        'name': 'A',
        'times': [-5, 600, 9999],
        'days': [0, 2, 9],
      })!;
      expect(odd.times, [600]);
      expect(odd.days, {2});
      expect(odd.scheduleText, startsWith('Tue at'));
    });

    test('reminders: daily, weekly per day, none when off', () {
      final plan = planMedicationReminders([
        vitD,
        vitD.copyWith(days: {1, 5}, name: 'Weekly'),
        vitD.copyWith(reminders: false, name: 'Quiet'),
        const Medication(id: 'p', name: 'Pain relief'),
      ], now: _now);
      expect(plan.where((r) => r.repeat == Repeat.daily), hasLength(2));
      expect(plan.where((r) => r.repeat == Repeat.weekly), hasLength(4));
      // 8 AM has passed today, so it starts tomorrow; 8 PM is still today.
      expect(plan[0].first, DateTime(2026, 10, 12, 8));
      expect(plan[1].first, DateTime(2026, 10, 11, 20));
      expect(plan.first.title, 'Time for Vitamin D');
      expect(
        plan.map((r) => r.id).toSet(),
        hasLength(plan.length),
        reason: 'ids are unique',
      );
    });

    test('store records doses, adherence and reschedules', () async {
      final s = await _store();
      final notifier = FakeNotifier();
      final meds = MedicationStore(s, notifier);
      await meds.load();
      expect(
        await meds.save(vitD.copyWith(created: DateTime(2026, 10, 1))),
        isTrue,
      );
      expect(notifier.medications, isNotEmpty);

      final slots = meds.slotsOn(_now);
      expect(slots, hasLength(2));
      await meds.record(vitD, DoseStatus.taken, slot: slots.first.time);
      expect(meds.slotsOn(_now).first.log?.status, DoseStatus.taken);
      // 8 AM taken; 8 PM is still to come today.
      expect(meds.adherence(days: 1), 1);

      final reloaded = MedicationStore(s, notifier);
      await reloaded.load();
      expect(reloaded.slotsOn(_now).first.log, isNotNull);

      // Added this afternoon: this morning's dose isn't counted as missed.
      await meds.save(const Medication(id: 'm2', name: 'New', times: [9 * 60]));
      expect(meds.byId('m2')!.created, _now);
      expect(meds.adherence(days: 1), 1);

      await meds.delete('m2');
      await meds.delete('m1');
      expect(meds.all, isEmpty);
      expect(notifier.medications, isEmpty);

      // A reminder that can't be set up is reported, then clears.
      notifier.failMedications = true;
      await meds.reschedule();
      expect(meds.remindersFailed, isTrue);
      notifier.failMedications = false;
      await meds.reschedule();
      expect(meds.remindersFailed, isFalse);
    }, skip: kStoreEdition);
  });

  group('Cycle forecast', () {
    Map<DateTime, CycleDay> periods(List<DateTime> starts, {int days = 5}) => {
      for (final s in starts)
        for (var i = 0; i < days; i++)
          addDays(s, i): const CycleDay(flow: PeriodFlow.medium),
    };

    test('averages cycles and predicts the next period', () {
      final f = CycleForecast.from(
        periods([
          DateTime(2026, 7, 1),
          DateTime(2026, 7, 31),
          DateTime(2026, 8, 30),
          DateTime(2026, 9, 29),
        ]),
        DateTime(2026, 10, 11),
      );
      expect(f.periods, hasLength(4));
      expect(f.cycleLength, 30);
      expect(f.periodLength, 5);
      expect(f.nextStart, DateTime(2026, 10, 29));
      expect(f.ovulation, DateTime(2026, 10, 15));
      expect(f.cycleDay, 13);
      expect(f.phase, CyclePhase.fertile);
      expect(f.isPredictedPeriod(DateTime(2026, 10, 30)), isTrue);
      expect(f.isFertile(DateTime(2026, 10, 12)), isTrue);
    });

    test('uses typical values with one period, and spotting starts none', () {
      final days = {
        ...periods([DateTime(2026, 10, 1)]),
        DateTime(2026, 9, 10): const CycleDay(flow: PeriodFlow.spotting),
      };
      final f = CycleForecast.from(days, DateTime(2026, 10, 11));
      expect(f.periods, hasLength(1));
      expect(f.cycleLength, CycleForecast.defaultCycle);
      expect(f.basedOn, 0);
      expect(f.nextStart, DateTime(2026, 10, 29));
    });

    test('a late period rolls the prediction forward', () {
      final f = CycleForecast.from(
        periods([DateTime(2026, 8, 1)]),
        DateTime(2026, 10, 11),
      );
      expect(
        daysBetween(DateTime(2026, 10, 11), f.nextStart!),
        inInclusiveRange(0, 28),
      );
    });
  });

  group('Achievements', () {
    test('progress and earning from data and workouts', () {
      final list = evaluateAchievements(
        AchievementInputs(
          dailyValue: (type, day) => switch (type) {
            MetricType.steps => 12000,
            MetricType.activeEnergy => 600,
            MetricType.exerciseMinutes => 40,
            _ => null,
          },
          today: DateTime(2026, 10, 11),
          goals: const Goals(),
          workouts: [
            WorkoutSession(
              id: 'r',
              type: WorkoutType.run,
              start: DateTime(2026, 10, 1, 7),
              end: DateTime(2026, 10, 1, 7, 40),
              activeSeconds: 2400,
              distanceMeters: 6000,
            ),
          ],
          daysLogged: 40,
        ),
      );
      Achievement a(String id) => list.firstWhere((x) => x.id == id);
      // 12,000 steps: bronze (10k), on the way to silver (15k).
      expect(a('steps').tier, Tier.bronze);
      expect(a('steps').nextTier, Tier.silver);
      expect(a('steps').progress, closeTo(0.4, 1e-9));
      expect(a('steps').detail, 'Walk 15,000 steps in a day');
      // Rings closed every day for the whole look-back: diamond.
      expect(a('ringStreak').tier, Tier.diamond);
      expect(a('ringStreak').maxed, isTrue);
      expect(a('ringStreak').progress, 1);
      // A 6 km run: bronze 5 km.
      expect(a('longestRun').tier, Tier.bronze);
      // 40 days logged: silver (30), next gold (100).
      expect(a('logged').tier, Tier.silver);
      expect(a('logged').progress, closeTo(10 / 70, 1e-9));
      expect(a('foodDays').earned, isFalse);
      expect({for (final x in list) x.id}, hasLength(list.length));
      expect(list.length, greaterThanOrEqualTo(30));
      for (final x in list) {
        expect(
          x.targets,
          orderedEquals([...x.targets]..sort()),
          reason: '${x.id} tiers rise',
        );
      }
    });
  });

  group('Automatic backups', () {
    late HealthStore health;
    late WorkoutStore workouts;
    late FakeBackupFolder folder;
    late AutoBackup auto;

    setUp(() async {
      health = await _store();
      workouts = WorkoutStore(InMemoryHealthRepository(), health);
      await workouts.load();
      folder = FakeBackupFolder();
      auto = AutoBackup(
        health,
        workouts,
        folder: folder,
        secret: FakeSecret(),
        iterations: BackupCrypto.minIterations,
      );
      await auto.load();
    });

    test(
      'writes an encrypted backup that restores with the password',
      () async {
        await health.addEntry(MetricType.weight, 70);
        await auto.enable((tree: 't', name: 'Backups'), 'password1');
        expect(await auto.runNow(), isTrue);

        final file = folder.files.values.single;
        expect(file.name, startsWith('Health Backup 2026-10-11'));
        expect(BackupCrypto.isEncrypted(file.text), isTrue);
        final backup = Backup.parse(
          await BackupCrypto.decrypt(file.text, 'password1'),
        );
        expect(backup.entries.single.value, 70);
        expect(auto.lastBackup, _now);
        expect(auto.isDue, isFalse);
      },
    );

    test('keeps only the newest backups', () async {
      await auto.enable((tree: 't', name: 'Backups'), 'password1');
      await auto.setKeep(3);
      for (var i = 0; i < 5; i++) {
        folder.files['doc:old$i'] = (
          name: 'Health Backup 2025-01-0${i + 1} 0900.json',
          text: '',
          modified: DateTime(2025, 1, i + 1),
        );
      }
      await auto.runNow();
      expect(folder.files, hasLength(3));
      // The newest (just written) is kept.
      expect(
        folder.files.values.map((f) => f.name),
        contains(startsWith('Health Backup 2026-10-11')),
      );
    });

    test('a same-minute copy named "(1)" counts as the newer one', () async {
      await auto.enable((tree: 't', name: 'Backups'), 'password1');
      await auto.setKeep(3);
      folder.files
        ..['doc:a'] = (
          name: 'Health Backup 2025-01-01 0900.json',
          text: '',
          modified: DateTime(2025),
        )
        ..['doc:b'] = (
          name: 'Health Backup 2025-01-02 0900.json',
          text: '',
          modified: DateTime(2025),
        )
        ..['doc:c'] = (
          name: 'Health Backup 2025-01-02 0900 (1).json',
          text: '',
          modified: DateTime(2025),
        );
      await auto.runNow();
      expect(folder.files.keys, isNot(contains('doc:a')));
      expect(folder.files.keys, containsAll(['doc:b', 'doc:c']));

      // With one fewer kept, the plain name goes first.
      await auto.setKeep(2);
      await auto.runNow();
      expect(folder.files.keys, isNot(contains('doc:b')));
    });

    test('a lost folder is reported, not thrown', () async {
      await auto.enable((tree: 't', name: 'Backups'), 'password1');
      folder.access = false;
      expect(await auto.runNow(), isFalse);
      expect(auto.error, contains('folder'));
    });

    test('off or not due does nothing', () async {
      await auto.maybeRun();
      expect(folder.files, isEmpty);
    });
  });

  group('App lock', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test(
      'locks on start and after time away, unlocks with the check',
      () async {
        final health = await _store();
        var now = _now;
        final auth = FakeAuthenticator();
        final lock = AppLock(health, authenticator: auth, clock: () => now);
        await lock.load();
        expect(await lock.setEnabled(true), LockChange.changed);
        await lock.setLockAfter(LockAfter.oneMinute);

        final again = AppLock(health, authenticator: auth, clock: () => now);
        await again.load();
        expect(again.locked, isTrue);
        expect(await again.unlock(), isTrue);
        expect(again.locked, isFalse);

        again.didChangeAppLifecycleState(AppLifecycleState.paused);
        now = now.add(const Duration(seconds: 30));
        again.didChangeAppLifecycleState(AppLifecycleState.resumed);
        expect(again.locked, isFalse, reason: 'back within a minute');

        again.didChangeAppLifecycleState(AppLifecycleState.paused);
        now = now.add(const Duration(minutes: 2));
        again.didChangeAppLifecycleState(AppLifecycleState.resumed);
        expect(again.locked, isTrue);

        auth.succeed = false;
        expect(await again.unlock(), isFalse);
        expect(again.locked, isTrue);
        lock.dispose();
        again.dispose();
      },
    );

    test('leaving the app while a prompt shows locks it', () async {
      final health = await _store();
      final auth = _LeavingAuthenticator();
      final lock = AppLock(health, authenticator: auth);
      await lock.load();
      auth.inner.succeed = true;
      await lock.setEnabled(true);
      expect(lock.locked, isFalse);

      // Home pressed during the prompt: the system cancels it.
      auth.lock = lock;
      expect(await lock.confirm('Back up'), isFalse);
      expect(lock.locked, isTrue);

      // A prompt simply declined in the app doesn't lock.
      auth.lock = null;
      auth.inner.succeed = true;
      expect(await lock.unlock(), isTrue);
      auth.inner.succeed = false;
      expect(await lock.confirm('Back up'), isFalse);
      expect(lock.locked, isFalse);
      lock.dispose();
    });

    test(
      'sensitive actions ask for a check only while the lock is on',
      () async {
        final health = await _store();
        final auth = FakeAuthenticator();
        final lock = AppLock(health, authenticator: auth);
        await lock.load();

        expect(await lock.confirm('Export'), isTrue);
        expect(auth.prompts, 0);

        await lock.setEnabled(true);
        auth.succeed = false;
        expect(await lock.confirm('Export'), isFalse);
        auth.succeed = true;
        expect(await lock.confirm('Export'), isTrue);
      },
    );

    test(
      'widgets hide data while locked unless allowed, and it is saved',
      () async {
        final health = await _store();
        final lock = AppLock(health, authenticator: FakeAuthenticator());
        await lock.load();
        expect(lock.hidesWidgets, isFalse);

        await lock.setEnabled(true);
        expect(lock.hidesWidgets, isTrue);

        await lock.setShowWidgetData(true);
        final again = AppLock(health, authenticator: FakeAuthenticator());
        await again.load();
        expect(again.showWidgetData, isTrue);
        expect(again.hidesWidgets, isFalse);
      },
    );

    test('needs a screen lock, and a check to change', () async {
      final health = await _store();
      final auth = FakeAuthenticator()..hasLock = false;
      final lock = AppLock(health, authenticator: auth);
      await lock.load();
      expect(await lock.setEnabled(true), LockChange.noScreenLock);
      auth
        ..hasLock = true
        ..succeed = false;
      expect(await lock.setEnabled(true), LockChange.failed);
      expect(lock.enabled, isFalse);
      lock.dispose();
    });

    test('says so when the screen lock is removed later', () async {
      final health = await _store();
      final auth = FakeAuthenticator();
      final lock = AppLock(health, authenticator: auth);
      await lock.load();
      await lock.setEnabled(true);
      expect(lock.screenLockMissing, isFalse);

      auth.hasLock = false;
      final again = AppLock(health, authenticator: auth);
      await again.load();
      expect(again.screenLockMissing, isTrue);
      // Nothing to check against: the user isn't locked out.
      expect(await again.unlock(), isTrue);

      auth.hasLock = true;
      expect(await again.confirm('Export'), isTrue);
      expect(again.screenLockMissing, isFalse);
      lock.dispose();
      again.dispose();
    });

    test(
      'a failed screen lock check still asks, rather than unlocking',
      () async {
        final health = await _store();
        final auth = FakeAuthenticator();
        final lock = AppLock(health, authenticator: auth);
        await lock.load();
        await lock.setEnabled(true);

        final again = AppLock(health, authenticator: auth);
        await again.load();
        auth
          ..checkFails = true
          ..succeed = false;
        expect(await again.unlock(), isFalse);
        expect(again.locked, isTrue);
        expect(await again.confirm('Export'), isFalse);
        lock.dispose();
        again.dispose();
      },
    );

    test('can be turned off once the screen lock is gone', () async {
      final health = await _store();
      final auth = FakeAuthenticator();
      final lock = AppLock(health, authenticator: auth);
      await lock.load();
      await lock.setEnabled(true);

      auth
        ..hasLock = false
        ..succeed = false;
      expect(await lock.setEnabled(false), LockChange.changed);
      expect(lock.enabled, isFalse);
      lock.dispose();
    });
  });

  test('new data is part of backups', () {
    expect(
      Backup.documentKeys,
      containsAll(['medications', 'cycle', 'achievements', 'heartZones']),
    );
    expect(Backup.documentKeys, isNot(contains('security')));
  });

  group('review fixes', () {
    test('App Lock starts locked when its settings can\'t be read', () async {
      final repo = _BrokenDocs({'security'});
      final health = HealthStore(repo, clock: () => _now);
      await health.load();
      final lock = AppLock(health, authenticator: FakeAuthenticator());
      await lock.load();
      expect(lock.locked, isTrue);
      expect(await lock.unlock(), isTrue);
      lock.dispose();
    });

    test('unreadable medications are never overwritten', () async {
      final repo = _BrokenDocs({MedicationStore.docKey});
      final health = HealthStore(repo, clock: () => _now);
      await health.load();
      final meds = MedicationStore(health, FakeNotifier());
      await meds.load();
      await meds.save(const Medication(id: 'x', name: 'New', times: [600]));
      expect(repo.saved, isNot(contains(MedicationStore.docKey)));
    });

    test(
      'disconnecting removes heart rate bands from Health Connect',
      () async {
        final repo = InMemoryHealthRepository();
        final health = HealthStore(repo, clock: () => _now);
        await health.load();
        final source = FakeHealthSource(grant: {MetricType.heartRate});
        source.samples.add(
          HealthSample(
            type: MetricType.heartRate,
            value: 120,
            start: DateTime(2026, 10, 11, 9),
            end: DateTime(2026, 10, 11, 9),
          ),
        );
        final sync = HealthSyncService(
          source: source,
          store: health,
          repo: repo,
          clock: () => _now,
        );
        await sync.init();
        await sync.connect();
        await sync.sync(force: true);
        expect(health.heartBinsOn(DateTime(2026, 10, 11)), isNotNull);
        await sync.disconnect();
        expect(health.hasHeartBins, isFalse);
      },
    );
  });
}

/// Storage where some documents exist but can't be read.
class _BrokenDocs extends InMemoryHealthRepository {
  _BrokenDocs(this.broken);

  final Set<String> broken;
  final saved = <String>{};

  @override
  Future<Map<String, Object?>?> loadDocument(String key) async {
    if (broken.contains(key)) throw UnreadableDataException(key);
    return super.loadDocument(key);
  }

  @override
  Future<void> saveDocument(String key, Map<String, Object?> value) async {
    saved.add(key);
    return super.saveDocument(key, value);
  }
}

/// Leaves the app (as pressing Home would) while its prompt shows, which
/// cancels it.
class _LeavingAuthenticator implements Authenticator {
  final inner = FakeAuthenticator();
  AppLock? lock;

  @override
  Future<bool> available() async => true;

  @override
  Future<bool> authenticate(String reason) async {
    final l = lock;
    if (l == null) return inner.authenticate(reason);
    l.didChangeAppLifecycleState(AppLifecycleState.paused);
    return false;
  }
}
