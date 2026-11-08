import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:health_app/data/value_cipher.dart';
import 'package:health_app/utils/log.dart';

/// Stores progress photos encrypted in the app's private storage (never in
/// the gallery, never backed up).
class PhotoVault {
  PhotoVault({required this._directory, required this._cipher});

  /// Longest side kept, in pixels.
  static const maxSide = 1600;

  /// Largest file accepted.
  static const maxBytes = 30 * 1024 * 1024;

  /// Largest image accepted (so a tiny file can't decode to gigabytes).
  static const maxPixels = 50 * 1000 * 1000;
  static const maxInputSide = 12000;

  /// Starts files encrypted with the photo's id as context (see
  /// [ValueCipher.encryptBytes]), so one can't be swapped for another.
  /// Older files have no marker and no context; they're rewritten on read.
  static const _bound = [0x48, 0x50, 0x56, 0x32]; // "HPV2"

  final Future<Directory> Function() _directory;
  final ValueCipher _cipher;

  /// Decodes, shrinks and re-encodes a photo. Re-encoding keeps only the
  /// pixels, so location, camera and other metadata are dropped. Returns
  /// null if [bytes] isn't an image. Run in an isolate (it's CPU heavy).
  static Uint8List? stripAndResize(Uint8List bytes) {
    if (bytes.length > maxBytes) return null;
    try {
      final decoder = img.findDecoderForData(bytes);
      final info = decoder?.startDecode(bytes);
      if (decoder == null || info == null) return null;
      if (info.width > maxInputSide ||
          info.height > maxInputSide ||
          info.width * info.height > maxPixels) {
        return null;
      }
      final decoded = decoder.decode(bytes);
      return decoded == null ? null : _clean(decoded);
    } on Exception catch (e) {
      logError('PhotoVault: unreadable image: $e');
      return null;
    }
  }

  static Uint8List _clean(img.Image decoded) {
    // Apply the camera's rotation before the orientation tag is dropped.
    var image = img.bakeOrientation(decoded);
    final longest = image.width > image.height ? image.width : image.height;
    if (longest > maxSide) {
      image = image.width >= image.height
          ? img.copyResize(image, width: maxSide)
          : img.copyResize(image, height: maxSide);
    }
    image.exif = img.ExifData();
    return img.encodeJpg(image, quality: 85);
  }

  /// Ids are made by the app (letters and digits); anything else, such as
  /// a path from a tampered document, is refused.
  static final _validId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  Future<File?> _file(String id) async =>
      _validId.hasMatch(id) ? File('${(await _dir()).path}/$id.bin') : null;

  Future<Directory> _dir() async {
    final d = await _directory();
    if (!d.existsSync()) await d.create(recursive: true);
    return d;
  }

  Future<void> write(String id, Uint8List jpeg) async {
    final data = await _cipher.encryptBytes(jpeg, context: id);
    final file = await _file(id);
    if (file == null) throw ArgumentError.value(id, 'id');
    // Written beside it, then moved over it in one step, so a crash
    // mid-write never leaves a half-written photo.
    final temp = File('${file.path}.${DateTime.now().microsecondsSinceEpoch}');
    await temp.writeAsBytes([..._bound, ...data], flush: true);
    await temp.rename(file.path);
  }

  /// The photo, or null if it's missing or can't be decrypted.
  Future<Uint8List?> read(String id) async {
    final f = await _file(id);
    if (f == null || !f.existsSync()) return null;
    final data = await f.readAsBytes();
    try {
      if (_isBound(data)) {
        try {
          return Uint8List.fromList(
            await _cipher.decryptBytes(
              data.sublist(_bound.length),
              context: id,
            ),
          );
        } on CipherException {
          // Possibly an older file that happens to start the same way.
        }
      }
      final jpeg = Uint8List.fromList(await _cipher.decryptBytes(data));
      try {
        // Unless it was deleted while being decrypted: rewriting would
        // bring back a photo that is gone from the list.
        if (f.existsSync()) await write(id, jpeg);
      } on FileSystemException catch (e) {
        // Still readable as it is; rewritten next time.
        logError('PhotoVault: could not rewrite $id: $e');
      }
      return jpeg;
    } on CipherException catch (e) {
      logError('PhotoVault: could not open $id: $e');
      return null;
    }
  }

  static bool _isBound(List<int> data) {
    if (data.length < _bound.length) return false;
    for (var i = 0; i < _bound.length; i++) {
      if (data[i] != _bound[i]) return false;
    }
    return true;
  }

  Future<void> delete(String id) async {
    final f = await _file(id);
    if (f != null && f.existsSync()) await f.delete();
  }

  Future<void> deleteAll() async {
    final d = await _directory();
    if (d.existsSync()) await d.delete(recursive: true);
  }
}
