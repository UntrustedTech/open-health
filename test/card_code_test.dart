import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as scan;

import 'package:health_app/gym/card_code.dart';
import 'package:health_app/models/gym.dart';

void main() {
  test('every format can be drawn and is read back from the camera', () {
    for (final f in CardFormat.values) {
      expect(CardCode.barcodeFor(f), isNotNull);
    }
    final read = {for (final f in CardCode.scannable) ?CardCode.fromScanned(f)};
    expect(read, CardFormat.values.toSet());
  });

  test('checks a code fits its format', () {
    expect(CardCode.canDraw('IW-0042', CardFormat.code128), isTrue);
    expect(CardCode.canDraw('IW-0042', CardFormat.ean13), isFalse);
    expect(CardCode.canDraw('5000159484695', CardFormat.ean13), isTrue);
    expect(CardCode.canDraw('', CardFormat.qr), isFalse);
    expect(CardCode.canDraw('any text at all', CardFormat.qr), isTrue);
  });

  test('a format the card can\'t be drawn in is not offered', () {
    expect(CardCode.fromScanned(scan.BarcodeFormat.unknown), isNull);
  });
}
