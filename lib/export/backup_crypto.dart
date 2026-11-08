import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Password protection for backup files: AES-256-GCM with a key derived
/// from the password by PBKDF2-HMAC-SHA256 (OWASP's 600,000 iterations).
///
/// The file stays JSON, so it can be told apart from a plain backup:
/// `{"app":"Health","format":"encrypted-backup","version":1,...}`.
abstract final class BackupCrypto {
  static const format = 'encrypted-backup';
  static const iterations = 600000;

  /// Files asking for more work than this are refused, so a crafted file
  /// can't hang the app.
  static const maxIterations = 2000000;
  static const minIterations = 100000;

  static final _aes = AesGcm.with256bits();

  /// True when [text] looks like a password-protected backup.
  static bool isEncrypted(String text) {
    // Cheap check first: big plain backups aren't parsed on the UI thread.
    if (!text.contains('"$format"')) return false;
    final json = _tryDecode(text);
    return json != null && json['format'] == format;
  }

  /// Encrypts [plain] with [password]. Runs off the UI thread.
  static Future<String> encrypt(
    String plain,
    String password, {
    int iterations = BackupCrypto.iterations,
  }) => Isolate.run(() => _encrypt(plain, password, iterations));

  /// Decrypts a file made by [encrypt]. Runs off the UI thread. Throws
  /// [BackupPasswordException] for a wrong password (or a file changed
  /// after it was made), and [FormatException] if [text] isn't a readable
  /// encrypted backup.
  static Future<String> decrypt(String text, String password) {
    final json = _tryDecode(text);
    if (json == null || json['format'] != format || json['version'] != 1) {
      throw const FormatException('Not an encrypted Health backup');
    }
    final rounds = json['iterations'];
    if (rounds is! int || rounds < minIterations || rounds > maxIterations) {
      throw const FormatException('Unsupported backup settings');
    }
    final parts = [
      for (final k in const ['salt', 'nonce', 'data', 'mac'])
        switch (json[k]) {
          final String v => v,
          _ => throw const FormatException('Damaged backup file'),
        },
    ];
    final [salt, nonce, cipher, mac] = [
      for (final p in parts) base64.decode(p),
    ];
    // AES-GCM's nonce is 12 bytes and its tag 16; anything else is damage.
    if (salt.length < 16 || nonce.length != 12 || mac.length != 16) {
      throw const FormatException('Damaged backup file');
    }
    return Isolate.run(
      () => _decrypt(password, rounds, salt, nonce, cipher, mac),
    );
  }

  static Future<String> _encrypt(
    String plain,
    String password,
    int iterations,
  ) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final key = await _derive(password, salt, iterations);
    final box = await _aes.encrypt(utf8.encode(plain), secretKey: key);
    return jsonEncode({
      'app': 'Health',
      'format': format,
      'version': 1,
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': iterations,
      'cipher': 'aes-256-gcm',
      'salt': base64.encode(salt),
      'nonce': base64.encode(box.nonce),
      'data': base64.encode(box.cipherText),
      'mac': base64.encode(box.mac.bytes),
    });
  }

  static Future<String> _decrypt(
    String password,
    int iterations,
    List<int> salt,
    List<int> nonce,
    List<int> cipher,
    List<int> mac,
  ) async {
    final key = await _derive(password, salt, iterations);
    final List<int> plain;
    try {
      plain = await _aes.decrypt(
        SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
    } on SecretBoxAuthenticationError {
      throw const BackupPasswordException();
    }
    // Authenticated but not text: the file was made wrongly, not the
    // password. Throws FormatException.
    return utf8.decode(plain);
  }

  static Future<SecretKey> _derive(
    String password,
    List<int> salt,
    int iterations,
  ) => Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  ).deriveKeyFromPassword(password: password, nonce: salt);

  static Map<String, Object?>? _tryDecode(String text) {
    try {
      final v = jsonDecode(text);
      return v is Map<String, Object?> ? v : null;
    } on FormatException {
      return null;
    }
  }
}

/// The password was wrong, or the file was changed after it was made.
class BackupPasswordException implements Exception {
  const BackupPasswordException();

  @override
  String toString() => 'BackupPasswordException: wrong password';
}
