import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/data/value_cipher.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/models/health_entry.dart';
import 'package:health_app/models/metric_type.dart';

void main() {
  late SharedPreferencesAsync prefs;
  final key = List<int>.generate(32, (i) => i);

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
  });

  HealthEntry entry() => HealthEntry(
    id: 'a',
    type: MetricType.weight,
    value: 72.5,
    date: DateTime(2026, 10, 11, 8),
    note: 'after breakfast',
  );

  test('stores entries and documents encrypted on disk', () async {
    final repo = SharedPrefsHealthRepository(
      prefs,
      cipher: AesGcmCipher.withKey(key),
    );

    await repo.saveEntries([entry()]);
    await repo.saveDocument('profile', {'allergies': 'peanuts'});

    final rawEntries = await prefs.getString('entries.v1');
    final rawDoc = await prefs.getString('doc.v1.profile');
    expect(rawEntries, startsWith('enc2:'));
    expect(rawEntries, isNot(contains('breakfast')));
    expect(rawDoc, isNot(contains('peanuts')));

    expect((await repo.loadEntries()).single.note, 'after breakfast');
    expect((await repo.loadDocument('profile'))?['allergies'], 'peanuts');
  });

  test('reads plaintext data from older versions and encrypts it', () async {
    await SharedPrefsHealthRepository(prefs).saveEntries([entry()]);
    expect(await prefs.getString('entries.v1'), contains('breakfast'));

    final repo = SharedPrefsHealthRepository(
      prefs,
      cipher: AesGcmCipher.withKey(key),
    );
    final loaded = await repo.loadEntries();

    expect(loaded.single.value, 72.5);
    expect(await prefs.getString('entries.v1'), startsWith('enc2:'));
  });

  test('a value moved to another key can\'t be read there', () async {
    final repo = SharedPrefsHealthRepository(
      prefs,
      cipher: AesGcmCipher.withKey(key),
    );
    await repo.saveDocument('profile', {'allergies': 'peanuts'});
    await repo.saveDocument('goals', {'steps': 10000});

    await prefs.setString(
      'doc.v1.goals',
      (await prefs.getString('doc.v1.profile'))!,
    );

    expect(await repo.loadDocument('profile'), isNotNull);
    await expectLater(
      repo.loadDocument('goals'),
      throwsA(isA<UnreadableDataException>()),
    );
  });

  test('values from the older format are read and rewritten bound to their '
      'key', () async {
    final cipher = AesGcmCipher.withKey(key);
    await prefs.setString(
      'doc.v1.profile',
      'enc1:${await cipher.encrypt('{"allergies":"peanuts"}')}',
    );

    final repo = SharedPrefsHealthRepository(prefs, cipher: cipher);
    expect((await repo.loadDocument('profile'))?['allergies'], 'peanuts');
    expect(await prefs.getString('doc.v1.profile'), startsWith('enc2:'));
    expect(await repo.hasEncryptedData(), isTrue);
  });

  test('checking for encrypted data ignores other apps\' and flags\' '
      'values', () async {
    // iOS lists every value the app stored, of any type; reading a flag as
    // text throws there, which used to stop the app starting.
    await prefs.setBool('appInForeground', true);
    await prefs.setInt('someCounter', 3);
    final repo = SharedPrefsHealthRepository(prefs);

    expect(await repo.hasEncryptedData(), isFalse);

    await SharedPrefsHealthRepository(
      prefs,
      cipher: AesGcmCipher.withKey(key),
    ).saveDocument('profile', {'a': 1});
    expect(await repo.hasEncryptedData(), isTrue);
  });

  test('data encrypted with another key is kept as a backup', () async {
    await SharedPrefsHealthRepository(
      prefs,
      cipher: AesGcmCipher.withKey(List<int>.filled(32, 7)),
    ).saveEntries([entry()]);

    final repo = SharedPrefsHealthRepository(
      prefs,
      cipher: AesGcmCipher.withKey(key),
    );
    final loaded = await repo.loadEntries();

    expect(loaded, isEmpty);
    final keys = await prefs.getKeys();
    expect(keys.any((k) => k.startsWith('entries.v1.backup.')), isTrue);
  });

  test('deleteDocument removes a document', () async {
    final repo = SharedPrefsHealthRepository(
      prefs,
      cipher: AesGcmCipher.withKey(key),
    );
    await repo.saveDocument('route.1', {'p': 1});

    await repo.deleteDocument('route.1');

    expect(await repo.loadDocument('route.1'), isNull);
  });

  group('device key', () {
    late Map<String, String> secure;

    setUp(() {
      secure = {};
      FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
        secure,
      );
    });

    test('is created once and reused', () async {
      final first = await AesGcmCipher.fromSecureStorage(
        hasEncryptedData: () async => false,
      );
      final encrypted = await first.encrypt('hello');

      final second = await AesGcmCipher.fromSecureStorage(
        hasEncryptedData: () async => true,
      );

      expect(await second.decrypt(encrypted), 'hello');
      expect(secure.keys.where((k) => k.startsWith('health.storage.key')), [
        'health.storage.key.v1',
        'health.storage.key.on_device',
      ]);
    });

    test('is kept on this device only on iPhone', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final writes = <(String, String?)>[];
      FlutterSecureStoragePlatform.instance = _RecordingStorage(secure, writes);

      await AesGcmCipher.fromSecureStorage(hasEncryptedData: () async => false);

      expect(writes, isNotEmpty);
      for (final (_, accessibility) in writes) {
        expect(accessibility, 'first_unlock_this_device');
      }
    });

    test('a key from before is moved on to the device once', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      secure['health.storage.key.v1'] = base64.encode(key);
      final writes = <(String, String?)>[];
      FlutterSecureStoragePlatform.instance = _RecordingStorage(secure, writes);

      final cipher = await AesGcmCipher.fromSecureStorage(
        hasEncryptedData: () async => true,
      );
      await AesGcmCipher.fromSecureStorage(hasEncryptedData: () async => true);

      expect(
        await cipher.decrypt(await AesGcmCipher.withKey(key).encrypt('hi')),
        'hi',
      );
      expect(writes.map((w) => w.$1), [
        'health.storage.key.v1',
        'health.storage.key.on_device',
      ]);
      expect(secure['health.storage.key.v1'], base64.encode(key));
    });

    test('a key that can\'t be moved is put back as it was', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      secure['health.storage.key.v1'] = base64.encode(key);
      FlutterSecureStoragePlatform.instance = _RecordingStorage(
        secure,
        [],
        failOnDevice: true,
      );

      final cipher = await AesGcmCipher.fromSecureStorage(
        hasEncryptedData: () async => true,
      );

      expect(secure['health.storage.key.v1'], base64.encode(key));
      expect(
        await cipher.decrypt(await AesGcmCipher.withKey(key).encrypt('hi')),
        'hi',
      );
    });

    test('is never replaced while encrypted data exists', () async {
      await expectLater(
        AesGcmCipher.fromSecureStorage(hasEncryptedData: () async => true),
        throwsA(isA<CipherException>()),
      );
      expect(secure, isEmpty);
    });
  });

  test('the repository can tell whether encrypted data exists', () async {
    final repo = SharedPrefsHealthRepository(
      prefs,
      cipher: AesGcmCipher.withKey(key),
    );
    expect(await repo.hasEncryptedData(), isFalse);

    await repo.saveDocument('goals', {'steps': 1});

    expect(await repo.hasEncryptedData(), isTrue);
  });

  test('an unreadable document is backed up and reported', () async {
    await SharedPrefsHealthRepository(
      prefs,
      cipher: AesGcmCipher.withKey(List<int>.filled(32, 9)),
    ).saveDocument('workouts', {'items': []});

    final repo = SharedPrefsHealthRepository(
      prefs,
      cipher: AesGcmCipher.withKey(key),
    );

    await expectLater(
      repo.loadDocument('workouts'),
      throwsA(isA<UnreadableDataException>()),
    );
    final keys = await prefs.getKeys();
    expect(keys.any((k) => k.startsWith('backup.doc.workouts.')), isTrue);
    expect(repo.unreadable, {'workouts'});

    // The app tells the user once, until they dismiss it.
    final store = HealthStore(repo);
    await store.load();
    expect(store.showUnreadableNotice, isTrue);
    store.dismissUnreadableNotice();
    expect(store.showUnreadableNotice, isFalse);
  });
}

/// Records each write's key and iPhone keychain accessibility, and can
/// refuse device-only writes like a keychain that won't move the key.
class _RecordingStorage extends TestFlutterSecureStoragePlatform {
  _RecordingStorage(super.data, this.writes, {this.failOnDevice = false});

  final List<(String, String?)> writes;
  final bool failOnDevice;

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    final accessibility = options['accessibility'];
    if (failOnDevice && accessibility == 'first_unlock_this_device') {
      // Like the keychain: the old copy is gone before the new one fails.
      data.remove(key);
      throw Exception('keychain write failed');
    }
    writes.add((key, accessibility));
    await super.write(key: key, value: value, options: options);
  }
}
