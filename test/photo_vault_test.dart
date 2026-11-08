import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:health_app/data/photo_vault.dart';
import 'package:health_app/data/value_cipher.dart';

Uint8List _jpegWithExif() {
  final image = img.Image(width: 64, height: 48);
  img.fill(image, color: img.ColorRgb8(200, 80, 90));
  image.exif.imageIfd['Make'] = 'TestPhone';
  image.exif.gpsIfd['GPSLatitude'] = 51.5;
  return img.encodeJpg(image);
}

bool _hasExifSegment(Uint8List jpeg) {
  // APP1 marker (FF E1) followed by "Exif".
  for (var i = 0; i + 9 < jpeg.length; i++) {
    if (jpeg[i] == 0xFF &&
        jpeg[i + 1] == 0xE1 &&
        String.fromCharCodes(jpeg.sublist(i + 4, i + 8)) == 'Exif') {
      return true;
    }
  }
  return false;
}

void main() {
  late Directory dir;
  late PhotoVault vault;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('vault');
    vault = PhotoVault(
      directory: () async => dir,
      cipher: AesGcmCipher.withKey(List<int>.generate(32, (i) => i)),
    );
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('re-encoding removes location and camera data', () {
    final original = _jpegWithExif();
    expect(_hasExifSegment(original), isTrue);

    final clean = PhotoVault.stripAndResize(original);

    expect(clean, isNotNull);
    expect(_hasExifSegment(clean!), isFalse);
  });

  test('images with huge dimensions are refused before decoding', () {
    final wide = img.encodePng(img.Image(width: 13000, height: 2));
    expect(PhotoVault.stripAndResize(wide), isNull);
  });

  test('oversized files and garbage are refused', () {
    expect(
      PhotoVault.stripAndResize(Uint8List(PhotoVault.maxBytes + 1)),
      isNull,
    );
    expect(
      PhotoVault.stripAndResize(Uint8List.fromList([0xFF, 0xD8, 0xFF, 1])),
      isNull,
    );
  });

  test('photos are stored encrypted and read back intact', () async {
    final clean = PhotoVault.stripAndResize(_jpegWithExif())!;

    await vault.write('p1', clean);

    final onDisk = File('${dir.path}/p1.bin').readAsBytesSync();
    expect(onDisk.take(2), isNot([0xFF, 0xD8])); // not a readable JPEG
    expect(await vault.read('p1'), clean);
  });

  test('a tampered file is rejected', () async {
    await vault.write('p1', Uint8List.fromList([1, 2, 3, 4, 5]));
    final f = File('${dir.path}/p1.bin');
    final bytes = f.readAsBytesSync()..[20] ^= 0xFF;
    f.writeAsBytesSync(bytes);

    expect(await vault.read('p1'), isNull);
  });

  test('a photo copied over another one isn\'t shown in its place', () async {
    await vault.write('p1', Uint8List.fromList([1, 2, 3]));
    await vault.write('p2', Uint8List.fromList([4, 5, 6]));

    File('${dir.path}/p1.bin').copySync('${dir.path}/p2.bin');

    expect(await vault.read('p1'), [1, 2, 3]);
    expect(await vault.read('p2'), isNull);
  });

  test(
    'photos from older versions are read and rewritten bound to their id',
    () async {
      final cipher = AesGcmCipher.withKey(List<int>.generate(32, (i) => i));
      final f = File('${dir.path}/p1.bin')
        ..writeAsBytesSync(await cipher.encryptBytes([7, 8, 9]));

      expect(await vault.read('p1'), [7, 8, 9]);
      expect(f.readAsBytesSync().take(4), 'HPV2'.codeUnits);
      expect(await vault.read('p1'), [7, 8, 9]);
    },
  );

  test('an id that isn\'t a photo id never reaches the file system', () async {
    File('${dir.parent.path}/outside.bin').writeAsBytesSync([1]);
    addTearDown(() => File('${dir.parent.path}/outside.bin').deleteSync());

    expect(await vault.read('../outside'), isNull);
    await vault.delete('../outside');
    expect(File('${dir.parent.path}/outside.bin').existsSync(), isTrue);
    expect(() => vault.write('../outside', Uint8List(1)), throwsArgumentError);
  });

  test('delete and deleteAll remove files', () async {
    await vault.write('a', Uint8List.fromList([1]));
    await vault.write('b', Uint8List.fromList([2]));

    await vault.delete('a');
    expect(await vault.read('a'), isNull);

    await vault.deleteAll();
    expect(await vault.read('b'), isNull);
  });
}
