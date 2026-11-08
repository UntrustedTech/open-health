import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/data/photo_vault.dart';
import 'package:health_app/data/value_cipher.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/photo_store.dart';

void main() {
  late Directory dir;
  late InMemoryHealthRepository repo;
  late HealthStore health;
  late PhotoVault vault;

  final jpeg = img.encodeJpg(img.Image(width: 20, height: 30));

  Future<PhotoStore> open() async {
    final s = PhotoStore(
      repo,
      health,
      vault,
      clock: () => DateTime(2026, 10, 11, 9),
    );
    await s.load();
    return s;
  }

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('photos');
    repo = InMemoryHealthRepository();
    health = HealthStore(repo);
    await health.load();
    vault = PhotoVault(
      directory: () async => dir,
      cipher: AesGcmCipher.withKey(List<int>.filled(32, 3)),
    );
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('adding a photo stores it and remembers it', () async {
    final store = await open();

    final p = await store.add(jpeg, pose: PhotoPose.side, weightKg: 72.4);

    expect(p, isNotNull);
    expect(await store.image(p!.id), isNotNull);
    final again = await open();
    expect(again.photos.single.pose, PhotoPose.side);
    expect(again.photos.single.weightKg, 72.4);
  });

  test('something that is not an image is refused', () async {
    final store = await open();
    expect(
      await store.add(List<int>.filled(10, 1), pose: PhotoPose.front),
      isNull,
    );
    expect(store.photos, isEmpty);
  });

  test('deleting removes the photo and its file', () async {
    final store = await open();
    final p = (await store.add(jpeg, pose: PhotoPose.front))!;

    await store.delete(p.id);

    expect(store.photos, isEmpty);
    expect(await vault.read(p.id), isNull);
  });

  test('erase removes every photo file', () async {
    final store = await open();
    await store.add(jpeg, pose: PhotoPose.front);

    await store.eraseAll();

    expect(store.photos, isEmpty);
    expect(dir.existsSync(), isFalse);
  });
}
