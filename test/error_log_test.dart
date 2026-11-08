import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/utils/log.dart';

void main() {
  tearDown(ErrorLog.clear);

  test('keeps an error and its stack, but not data quoted after it', () {
    logError(
      'FormatException: Unexpected character\n'
      '{"weight": 81.4, "note": "private"}\n'
      '#0      jsonDecode (dart:convert)\n'
      '#1      HealthStore.load (health_store.dart:12)',
    );

    final message = ErrorLog.entries.single.message;
    expect(message, startsWith('FormatException: Unexpected character'));
    expect(message, contains('#1      HealthStore.load'));
    expect(message, isNot(contains('private')));
    expect(message, isNot(contains('81.4')));
  });

  test('keeps only the most recent errors', () {
    for (var i = 0; i < ErrorLog.max + 10; i++) {
      logError('problem $i');
    }

    expect(ErrorLog.entries, hasLength(ErrorLog.max));
    expect(ErrorLog.entries.last.message, 'problem ${ErrorLog.max + 9}');
    expect(ErrorLog.asText(), startsWith('[')); // newest first, dated
  });
}
