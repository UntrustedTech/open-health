import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/export/backup.dart';
import 'package:health_app/export/backup_crypto.dart';
import 'package:health_app/export/backup_restorer.dart';
import 'package:health_app/export/data_export.dart';
import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/models/exercise_library.dart';
import 'package:health_app/models/exercise_media.dart';
import 'package:health_app/models/health_entry.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/personalization.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/workout/geo.dart';
import 'package:health_app/notifications/notification_controller.dart';
import 'package:health_app/state/exercise_store.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/workout_store.dart';

import 'fake_notifier.dart';

final _now = DateTime(2026, 10, 11, 15, 30);

final _catalog = ExerciseCatalog.fromBundledJson(
  File('assets/data/exercises.json').readAsStringSync(),
);

/// One device's worth of stores over an in-memory repository.
class _Device {
  _Device._(this.health, this.workouts, this.exercises, this.notifications);

  final HealthStore health;
  final WorkoutStore workouts;
  final ExerciseStore exercises;
  final NotificationController notifications;

  /// Each device gets its own clock, as entry ids come from the time.
  static Future<_Device> open({
    int minute = 0,
    InMemoryHealthRepository? storage,
  }) async {
    final repo = storage ?? InMemoryHealthRepository();
    final clock = _now.add(Duration(minutes: minute));
    final health = HealthStore(repo, clock: () => clock);
    await health.load();
    await health.completeOnboarding(name: 'Sam', withSampleData: false);
    final workouts = WorkoutStore(repo, health, clock: () => _now);
    await workouts.load();
    final exercises = ExerciseStore(
      repo,
      health,
      loadCatalog: () async => _catalog,
      loadMedia: () async => ExerciseMedia.fromJson('{}'),
    );
    await exercises.load();
    final notifications = NotificationController(repo, health, FakeNotifier());
    await notifications.load();
    return _Device._(health, workouts, exercises, notifications);
  }

  BackupRestorer get restorer => BackupRestorer(
    health: health,
    workouts: workouts,
    exercises: exercises,
    notifications: notifications,
  );

  Future<String> export() async => exportAllData(
    exportedAt: _now,
    entries: health.allEntries,
    workouts: workouts.all,
    routines: workouts.routines.where((r) => !r.builtIn).toList(),
    documents: await health.loadDocuments([
      ...Backup.documentKeys,
      ...Backup.routeKeys(workouts.all),
    ]),
  );
}

/// Storage whose entry writes fail once [failEntries] is set, and whose
/// writes of the document [failDocument] fail.
class _FlakyRepository extends InMemoryHealthRepository {
  bool failEntries = false;
  String? failDocument;

  @override
  Future<void> saveDocument(String key, Map<String, Object?> json) async {
    if (key == failDocument) throw const FileSystemException('disk full');
    return super.saveDocument(key, json);
  }

  @override
  Future<void> saveEntries(List<HealthEntry> entries) async {
    if (failEntries) throw const FileSystemException('disk full');
    return super.saveEntries(entries);
  }
}

WorkoutSession _run(String id, DateTime start) => WorkoutSession(
  id: id,
  type: WorkoutType.run,
  start: start,
  end: start.add(const Duration(minutes: 30)),
  activeSeconds: 1800,
  distanceMeters: 5000,
  activeKcal: 300,
);

void main() {
  group('Backup.parse', () {
    test('rejects files that are not Health backups', () {
      expect(() => Backup.parse('not json'), throwsFormatException);
      expect(() => Backup.parse('[1,2]'), throwsFormatException);
      expect(
        () => Backup.parse('{"app":"Other","version":1}'),
        throwsFormatException,
      );
    });

    test('rejects backups from a newer version', () {
      expect(
        () => Backup.parse('{"app":"Health","version":2}'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('newer'),
          ),
        ),
      );
    });

    test('skips damaged records and unknown documents', () {
      final backup = Backup.parse(
        jsonEncode({
          'app': 'Health',
          'version': 1,
          'exportedAt': _now.toIso8601String(),
          'entries': [
            HealthEntry(
              id: 'e1',
              type: MetricType.water,
              value: 250,
              date: _now,
            ).toJson(),
            {'id': 'broken'},
            'nonsense',
          ],
          'workouts': [_run('w1', _now).toJson(), 7],
          'routines': [
            const Routine(id: 'r1', name: 'Mine', items: []).toJson(),
            Routine.presets.first.toJson(),
          ],
          'documents': {
            'profile': {'name': 'Sam'},
            'workoutCheckpoint': {'x': 1},
            'goals': 'not a map',
          },
        }),
      );

      expect(backup.exportedAt, _now);
      expect([for (final e in backup.entries) e.id], ['e1']);
      expect([for (final w in backup.workouts) w.id], ['w1']);
      expect([for (final r in backup.routines) r.id], ['r1']);
      expect(backup.documents.keys, ['profile']);
    });
  });

  group('BackupCrypto', () {
    const rounds = BackupCrypto.minIterations;

    test('encrypts and decrypts with the password', () async {
      const plain = '{"app":"Health","version":1}';
      final sealed = await BackupCrypto.encrypt(
        plain,
        'correct horse',
        iterations: rounds,
      );

      expect(sealed, isNot(contains('Health","version')));
      expect(BackupCrypto.isEncrypted(sealed), isTrue);
      expect(BackupCrypto.isEncrypted(plain), isFalse);
      expect(await BackupCrypto.decrypt(sealed, 'correct horse'), plain);
    });

    test('a wrong password or changed file is refused', () async {
      final sealed = await BackupCrypto.encrypt(
        'secret',
        'password1',
        iterations: rounds,
      );
      await expectLater(
        BackupCrypto.decrypt(sealed, 'password2'),
        throwsA(isA<BackupPasswordException>()),
      );

      final json = jsonDecode(sealed) as Map<String, Object?>;
      final data = base64.decode(json['data']! as String)..[0] ^= 1;
      final tampered = jsonEncode({...json, 'data': base64.encode(data)});
      await expectLater(
        BackupCrypto.decrypt(tampered, 'password1'),
        throwsA(isA<BackupPasswordException>()),
      );
    });

    test('refuses files asking for unreasonable work', () async {
      final sealed = await BackupCrypto.encrypt(
        'x',
        'password1',
        iterations: rounds,
      );
      final json = jsonDecode(sealed) as Map<String, Object?>;
      final greedy = jsonEncode({...json, 'iterations': 1 << 40});
      expect(
        () => BackupCrypto.decrypt(greedy, 'password1'),
        throwsFormatException,
      );
      final broken = jsonEncode({...json, 'salt': 5});
      expect(
        () => BackupCrypto.decrypt(broken, 'password1'),
        throwsFormatException,
      );
    });
  });

  group('BackupRestorer', () {
    test('replace makes a new device match the backup', () async {
      final old = await _Device.open();
      await old.health.addEntry(MetricType.weight, 72);
      await old.health.setPersonalization(
        const Personalization().copyWith(accent: AppAccent.teal),
      );
      await old.workouts.save(_run('w1', DateTime(2026, 10, 10, 7)));
      await old.workouts.saveRoutine(
        const Routine(id: 'r1', name: 'Legs', items: [RoutineItem('squat')]),
      );
      await old.exercises.addCustom(
        name: 'Sled Push',
        bodyPart: 'upper legs',
        equipment: 'other',
        target: 'quads',
      );
      final backup = Backup.parse(await old.export());

      final fresh = await _Device.open(minute: 1);
      await fresh.health.addEntry(MetricType.water, 500);
      final result = await fresh.restorer.restore(backup, RestoreMode.replace);

      expect(result.workouts, 1);
      expect(fresh.health.onboarded, isTrue);
      expect(fresh.health.personalization.accent, AppAccent.teal);
      expect(fresh.health.entriesFor(MetricType.weight).single.value, 72);
      expect(fresh.health.entriesFor(MetricType.water), isEmpty);
      expect(fresh.workouts.byId('w1'), isNotNull);
      expect(fresh.workouts.routines.map((r) => r.name), contains('Legs'));
      expect(fresh.exercises.custom.map((e) => e.name), ['Sled Push']);
    });

    test('merge adds what is missing and keeps current settings', () async {
      final old = await _Device.open();
      await old.health.addEntry(MetricType.weight, 72);
      await old.health.setPersonalization(
        const Personalization().copyWith(accent: AppAccent.teal),
      );
      await old.workouts.save(_run('w1', DateTime(2026, 10, 10, 7)));
      final backup = Backup.parse(await old.export());

      final here = await _Device.open(minute: 1);
      await here.health.addEntry(MetricType.water, 500);
      await here.workouts.save(_run('w2', DateTime(2026, 10, 9, 7)));

      final first = await here.restorer.restore(backup, RestoreMode.merge);
      expect(first.workouts, 1);
      expect(first.entries, greaterThan(0));
      expect(here.health.entriesFor(MetricType.water), hasLength(1));
      expect(here.health.entriesFor(MetricType.weight), hasLength(1));
      expect({for (final w in here.workouts.all) w.id}, {'w1', 'w2'});
      expect(here.health.personalization.accent, AppAccent.iris);

      // Restoring the same backup again changes nothing.
      final again = await here.restorer.restore(backup, RestoreMode.merge);
      expect(again, (entries: 0, workouts: 0, routines: 0));
    });

    test('replace removes settings the backup does not have', () async {
      final old = await _Device.open();
      await old.workouts.save(_run('w1', DateTime(2026, 10, 10, 7)));
      final backup = Backup.parse(await old.export());
      expect(backup.documents.containsKey('trainingPlan'), isFalse);

      final here = await _Device.open(minute: 1);
      await here.workouts.saveRoutine(
        const Routine(id: 'r9', name: 'Old', items: []),
      );
      await here.workouts.setPlan(
        here.workouts.plan.copyWith(days: {DateTime.monday: 'r9'}),
      );
      await here.restorer.restore(backup, RestoreMode.replace);

      expect(here.workouts.plan.days, isEmpty);
      expect(here.workouts.routines.map((r) => r.id), isNot(contains('r9')));
    });

    test('a failed replace puts the previous data back', () async {
      final old = await _Device.open();
      await old.health.addEntry(MetricType.weight, 72);
      await old.workouts.save(_run('w1', DateTime(2026, 10, 10, 7)));
      final backup = Backup.parse(await old.export());

      final storage = _FlakyRepository();
      final here = await _Device.open(minute: 1, storage: storage);
      await here.health.addEntry(MetricType.water, 500);
      await here.workouts.save(_run('w2', DateTime(2026, 10, 9, 7)));

      storage.failEntries = true;
      await expectLater(
        here.restorer.restore(backup, RestoreMode.replace),
        throwsA(isA<RestoreException>()),
      );
      storage.failEntries = false;
      await here.health.load();
      await here.workouts.load();

      expect({for (final w in here.workouts.all) w.id}, {'w2'});
      expect(here.health.entriesFor(MetricType.water), hasLength(1));
      expect(here.health.entriesFor(MetricType.weight), isEmpty);
    });

    test('GPS routes travel with their workouts', () async {
      final old = await _Device.open();
      final start = DateTime(2026, 10, 10, 7);
      await old.workouts.save(
        WorkoutSession(
          id: 'gps1',
          type: WorkoutType.run,
          start: start,
          end: start.add(const Duration(minutes: 30)),
          activeSeconds: 1800,
          distanceMeters: 5000,
          activeKcal: 300,
          hasRoute: true,
        ),
        route: [
          GeoPoint(lat: 51.5, lng: -0.12, time: start),
          GeoPoint(
            lat: 51.51,
            lng: -0.13,
            time: start.add(const Duration(minutes: 5)),
          ),
        ],
      );
      final backup = Backup.parse(await old.export());

      final replaced = await _Device.open(minute: 1);
      await replaced.restorer.restore(backup, RestoreMode.replace);
      expect(await replaced.workouts.routeOf('gps1'), hasLength(2));

      final merged = await _Device.open(minute: 2);
      await merged.restorer.restore(backup, RestoreMode.merge);
      expect(await merged.workouts.routeOf('gps1'), hasLength(2));
    });

    test('a failed write is caught even when a later one succeeds', () async {
      final old = await _Device.open();
      await old.health.addEntry(MetricType.weight, 72);
      await old.workouts.save(_run('w1', DateTime(2026, 10, 10, 7)));
      final backup = Backup.parse(await old.export());

      final storage = _FlakyRepository();
      final here = await _Device.open(minute: 1, storage: storage);
      // Workouts are written before entries, which still succeed last.
      storage.failDocument = 'workouts';
      await expectLater(
        here.restorer.restore(backup, RestoreMode.replace),
        throwsA(isA<RestoreException>()),
      );
    });
  });

  test('parse counts damaged and repeated records', () {
    final entry = HealthEntry(
      id: 'e1',
      type: MetricType.water,
      value: 250,
      date: _now,
    ).toJson();
    final backup = Backup.parse(
      jsonEncode({
        'app': 'Health',
        'version': 1,
        'entries': [entry, entry, 'junk'],
      }),
    );
    expect(backup.entries, hasLength(1));
    expect(backup.skipped, 2);
  });

  test('decrypt refuses a damaged nonce', () async {
    final sealed = await BackupCrypto.encrypt(
      'x',
      'password1',
      iterations: BackupCrypto.minIterations,
    );
    final json = jsonDecode(sealed) as Map<String, Object?>;
    final bad = jsonEncode({
      ...json,
      'nonce': base64.encode([1, 2, 3]),
    });
    expect(() => BackupCrypto.decrypt(bad, 'password1'), throwsFormatException);
  });

  group('v19 documents', () {
    test('merging joins habits and their ticks from both phones', () async {
      final old = await _Device.open();
      await old.health.saveDocument('mood', {
        'days': <String, Object?>{},
        'habits': ['Read', 'Stretch'],
        'habitDays': {
          '20261001': ['Read'],
          '20261002': ['Stretch'],
        },
      });
      final backup = Backup.parse(await old.export());

      final here = await _Device.open(minute: 1);
      await here.health.saveDocument('mood', {
        'days': <String, Object?>{},
        'habits': ['Water'],
        'habitDays': {
          '20261001': ['Water'],
        },
      });
      await here.restorer.restore(backup, RestoreMode.merge);

      final mood = (await here.health.loadDocument('mood'))!;
      expect(mood['habits'], ['Water', 'Read', 'Stretch']);
      final ticks = mood['habitDays']! as Map;
      expect(ticks['20261001'], ['Water', 'Read']);
      expect(ticks['20261002'], ['Stretch']);
    });

    test(
      'merging keeps journal days and past fasts, not a stale fast',
      () async {
        final old = await _Device.open();
        await old.health.saveDocument('mood', {
          'days': {
            '20261001': {'m': 4},
            '20261002': {'m': 2},
          },
        });
        await old.health.saveDocument('fasting', {
          'preset': 'eighteen',
          'started': '2026-10-01T20:00:00.000',
          'history': [
            {
              's': '2026-09-30T20:00:00.000',
              'e': '2026-10-01T12:00:00.000',
              'g': 960,
            },
          ],
        });
        final backup = Backup.parse(await old.export());

        final here = await _Device.open(minute: 1);
        await here.health.saveDocument('mood', {
          'days': {
            '20261002': {'m': 5},
          },
        });
        await here.restorer.restore(backup, RestoreMode.merge);

        final mood = (await here.health.loadDocument('mood'))!['days']! as Map;
        expect(mood.keys, containsAll(['20261001', '20261002']));
        // Days already here win.
        expect((mood['20261002'] as Map)['m'], 5);
        final fasting = (await here.health.loadDocument('fasting'))!;
        expect(fasting['started'], isNull);
        expect(fasting['preset'], 'eighteen');
        expect(fasting['history'], hasLength(1));
      },
    );

    test('merging keeps this phone\'s membership and joins visits', () async {
      final old = await _Device.open();
      await old.health.saveDocument('gym', {
        'membership': {'gym': 'Old Gym', 'code': 'OLD1'},
        'visits': ['2026-10-01T18:00:00.000', '2026-10-02T18:00:00.000'],
      });
      final backup = Backup.parse(await old.export());

      final here = await _Device.open(minute: 1);
      await here.health.saveDocument('gym', {
        'membership': {'gym': 'New Gym', 'code': 'NEW1'},
        'visits': ['2026-10-02T18:00:00.000', '2026-10-05T07:00:00.000'],
      });
      await here.restorer.restore(backup, RestoreMode.merge);

      final gym = (await here.health.loadDocument('gym'))!;
      expect((gym['membership']! as Map)['gym'], 'New Gym');
      expect(gym['visits'], [
        '2026-10-01T18:00:00.000',
        '2026-10-02T18:00:00.000',
        '2026-10-05T07:00:00.000',
      ]);
    });

    test('merging brings the membership to a phone without one', () async {
      final old = await _Device.open();
      await old.health.saveDocument('gym', {
        'membership': {'gym': 'Old Gym', 'code': 'OLD1'},
        'visits': ['2026-10-01T18:00:00.000'],
      });
      final backup = Backup.parse(await old.export());

      final here = await _Device.open(minute: 1);
      await here.health.saveDocument('gym', {
        'visits': ['2026-10-05T07:00:00.000'],
      });
      await here.restorer.restore(backup, RestoreMode.merge);

      final gym = (await here.health.loadDocument('gym'))!;
      expect((gym['membership']! as Map)['gym'], 'Old Gym');
      expect(gym['visits'], hasLength(2));
    });
  });
}
