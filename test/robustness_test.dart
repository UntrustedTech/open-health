import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/data/value_cipher.dart';
import 'package:health_app/data/write_queue.dart';

void main() {
  test('the write queue keeps working after an unexpected error', () async {
    final queue = WriteQueue();
    var ran = false;

    await queue.run(() async => throw StateError('bug'));
    await queue.run(() async => ran = true);

    expect(ran, isTrue);
    expect(queue.failed, isFalse);
  });

  test('a failed save stays reported until the same data saves', () async {
    final queue = WriteQueue();

    await queue.run(() async => throw StateError('disk full'), key: 'profile');
    await queue.run(() async {}, key: 'settings');
    expect(queue.failed, isTrue);

    await queue.run(() async {}, key: 'profile');
    expect(queue.failed, isFalse);
  });

  test('truncated ciphertext is reported as unreadable, not a crash', () {
    final cipher = AesGcmCipher.withKey(List<int>.filled(32, 1));
    expect(cipher.decrypt('AAAA'), throwsA(isA<CipherException>()));
  });
}
