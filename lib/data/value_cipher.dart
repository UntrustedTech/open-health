import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:health_app/utils/log.dart';

/// Encrypts stored values so health data is never kept as plain text.
abstract interface class ValueCipher {
  /// Encrypts [plain]. When [context] is given (such as the storage key),
  /// the result can only be decrypted with the same [context], so a value
  /// can't be copied over another one unnoticed.
  Future<String> encrypt(String plain, {String context = ''});

  /// Throws [CipherException] if [encoded] can't be decrypted, including
  /// when [context] isn't the one it was encrypted with.
  Future<String> decrypt(String encoded, {String context = ''});

  /// Like [encrypt], for bytes.
  Future<List<int>> encryptBytes(List<int> plain, {String context = ''});

  /// Throws [CipherException] if the data can't be decrypted, including
  /// when [context] isn't the one it was encrypted with.
  Future<List<int>> decryptBytes(List<int> data, {String context = ''});
}

class CipherException implements Exception {
  const CipherException(this.message);

  final String message;

  @override
  String toString() => 'CipherException: $message';
}

/// Encrypted data exists but its key isn't on this device, such as after
/// moving to a new phone: the key never leaves the phone it was made on.
class StorageKeyMissing extends CipherException {
  const StorageKeyMissing() : super('storage key missing for encrypted data');
}

/// AES-256-GCM (authenticated encryption). The key is kept in the Android
/// Keystore / iOS Keychain via flutter_secure_storage.
class AesGcmCipher implements ValueCipher {
  AesGcmCipher._(this._key);

  /// For tests: uses a fixed 32-byte key.
  AesGcmCipher.withKey(List<int> key) : _key = SecretKey(key);

  static const _keyName = 'health.storage.key.v1';

  /// Set once the key is kept on this device only, so it's moved once.
  /// It doesn't move to a new device either, so it's set again there.
  static const _onDeviceName = 'health.storage.key.on_device';

  /// On iPhone, the key stays on this device: it's left out of iCloud
  /// Keychain and backups, so health data copied there can't be read.
  static const _secureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  static final _algorithm = AesGcm.with256bits();

  final SecretKey _key;

  /// Loads the device key, creating it on first use.
  ///
  /// A new key is only ever created when no encrypted data exists. If the
  /// key can't be read but encrypted data is present, this throws instead of
  /// replacing the key, which would make that data unreadable for good.
  static Future<AesGcmCipher> fromSecureStorage({
    required Future<bool> Function() hasEncryptedData,
    FlutterSecureStorage storage = _secureStorage,
  }) async {
    final existing = await storage.read(key: _keyName);
    if (existing != null) {
      await _keepOnDevice(storage, existing);
      return AesGcmCipher._(SecretKey(base64.decode(existing)));
    }
    if (await hasEncryptedData()) {
      throw const StorageKeyMissing();
    }
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    await storage.write(key: _keyName, value: base64.encode(bytes));
    await storage.write(key: _onDeviceName, value: '1');
    return AesGcmCipher._(SecretKey(bytes));
  }

  /// Saves a key made before it was kept on the device only, so it no
  /// longer syncs. Rewriting it replaces the old copy; if that fails, the
  /// key is put back as it was, so it's never lost.
  static Future<void> _keepOnDevice(
    FlutterSecureStorage storage,
    String key,
  ) async {
    if (await storage.read(key: _onDeviceName) != null) return;
    try {
      await storage.write(key: _keyName, value: key);
      await storage.write(key: _onDeviceName, value: '1');
    } on Exception catch (e) {
      logError('Storage key: could not keep it on this device: $e');
      try {
        await storage.write(
          key: _keyName,
          value: key,
          iOptions: IOSOptions.defaultOptions,
        );
      } on Exception catch (e) {
        logError('Storage key: could not put it back: $e');
      }
    }
  }

  @override
  Future<String> encrypt(String plain, {String context = ''}) async {
    final box = await _algorithm.encrypt(
      utf8.encode(plain),
      secretKey: _key,
      aad: utf8.encode(context),
    );
    return base64.encode(box.concatenation());
  }

  @override
  Future<List<int>> encryptBytes(
    List<int> plain, {
    String context = '',
  }) async => (await _algorithm.encrypt(
    plain,
    secretKey: _key,
    aad: utf8.encode(context),
  )).concatenation();

  @override
  Future<List<int>> decryptBytes(List<int> data, {String context = ''}) async {
    try {
      final box = SecretBox.fromConcatenation(
        data,
        nonceLength: _algorithm.nonceLength,
        macLength: _algorithm.macAlgorithm.macLength,
      );
      return await _algorithm.decrypt(
        box,
        secretKey: _key,
        aad: utf8.encode(context),
      );
    } on SecretBoxAuthenticationError {
      throw const CipherException('wrong key or corrupted data');
    } on ArgumentError catch (e) {
      throw CipherException('malformed data: ${e.message}');
    }
  }

  @override
  Future<String> decrypt(String encoded, {String context = ''}) async {
    try {
      final box = SecretBox.fromConcatenation(
        base64.decode(encoded),
        nonceLength: _algorithm.nonceLength,
        macLength: _algorithm.macAlgorithm.macLength,
      );
      return utf8.decode(
        await _algorithm.decrypt(
          box,
          secretKey: _key,
          aad: utf8.encode(context),
        ),
      );
    } on SecretBoxAuthenticationError {
      throw const CipherException('wrong key or corrupted data');
    } on FormatException catch (e) {
      throw CipherException('malformed data: ${e.message}');
    } on ArgumentError catch (e) {
      // Too short to hold a nonce and MAC (e.g. truncated data).
      throw CipherException('malformed data: ${e.message}');
    }
  }
}
