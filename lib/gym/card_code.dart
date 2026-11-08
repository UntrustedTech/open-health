import 'package:barcode/barcode.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as scan;

import 'package:health_app/models/gym.dart';

/// Draws and reads membership card codes: [CardFormat] as the `barcode`
/// package draws it and as the camera scanner reports it.
abstract final class CardCode {
  static Barcode barcodeFor(CardFormat f) => switch (f) {
    CardFormat.code128 => Barcode.code128(),
    CardFormat.code39 => Barcode.code39(),
    CardFormat.code93 => Barcode.code93(),
    CardFormat.qr => Barcode.qrCode(),
    CardFormat.ean13 => Barcode.ean13(),
    CardFormat.ean8 => Barcode.ean8(),
    CardFormat.upcA => Barcode.upcA(),
    CardFormat.upcE => Barcode.upcE(),
    CardFormat.itf => Barcode.itf(),
    CardFormat.codabar => Barcode.codabar(),
    CardFormat.pdf417 => Barcode.pdf417(),
    CardFormat.dataMatrix => Barcode.dataMatrix(),
    CardFormat.aztec => Barcode.aztec(),
  };

  /// Whether [code] can be drawn as [format] (some take only digits, or
  /// a set length).
  static bool canDraw(String code, CardFormat format) =>
      code.isNotEmpty && barcodeFor(format).isValid(code);

  /// The format a scanned code was in, or null for one we can't draw.
  static CardFormat? fromScanned(scan.BarcodeFormat f) => switch (f) {
    scan.BarcodeFormat.code128 => CardFormat.code128,
    scan.BarcodeFormat.code39 => CardFormat.code39,
    scan.BarcodeFormat.code93 => CardFormat.code93,
    scan.BarcodeFormat.qrCode => CardFormat.qr,
    scan.BarcodeFormat.ean13 => CardFormat.ean13,
    scan.BarcodeFormat.ean8 => CardFormat.ean8,
    scan.BarcodeFormat.upcA => CardFormat.upcA,
    scan.BarcodeFormat.upcE => CardFormat.upcE,
    scan.BarcodeFormat.itf14 => CardFormat.itf,
    scan.BarcodeFormat.codabar => CardFormat.codabar,
    scan.BarcodeFormat.pdf417 => CardFormat.pdf417,
    scan.BarcodeFormat.dataMatrix => CardFormat.dataMatrix,
    scan.BarcodeFormat.aztec => CardFormat.aztec,
    _ => null,
  };

  /// Everything the camera looks for when scanning a card.
  static const scannable = [
    scan.BarcodeFormat.code128,
    scan.BarcodeFormat.code39,
    scan.BarcodeFormat.code93,
    scan.BarcodeFormat.qrCode,
    scan.BarcodeFormat.ean13,
    scan.BarcodeFormat.ean8,
    scan.BarcodeFormat.upcA,
    scan.BarcodeFormat.upcE,
    scan.BarcodeFormat.itf14,
    scan.BarcodeFormat.codabar,
    scan.BarcodeFormat.pdf417,
    scan.BarcodeFormat.dataMatrix,
    scan.BarcodeFormat.aztec,
  ];
}
