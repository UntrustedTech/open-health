import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/models/exercise_media.dart';
import 'package:health_app/state/exercise_store.dart';
import 'package:health_app/state/health_store.dart';

void main() {
  final base = ExerciseCatalog.fromBundledJson(
    File('assets/data/exercises.json').readAsStringSync(),
  );
  late InMemoryHealthRepository repo;
  late HealthStore health;

  Future<ExerciseStore> open() async {
    final s = ExerciseStore(
      repo,
      health,
      loadCatalog: () async => base,
      loadMedia: () async => ExerciseMedia.fromJson('{"0025":"010"}'),
    );
    await s.load();
    return s;
  }

  setUp(() async {
    repo = InMemoryHealthRepository();
    health = HealthStore(repo);
    await health.load();
  });

  test('custom exercises persist and join the catalog', () async {
    final store = await open();

    final e = await store.addCustom(
      name: '  Sandbag Carry ',
      bodyPart: 'upper legs',
      equipment: 'other',
      target: 'quads',
      timed: true,
    );

    expect(e.id, startsWith('c_'));
    expect(e.name, 'Sandbag Carry');
    expect(ExerciseCatalog.instance.byId(e.id)?.timed, isTrue);

    final again = await open();
    expect(again.custom.single.name, 'Sandbag Carry');

    await again.deleteCustom(e.id);
    expect(ExerciseCatalog.instance.byId(e.id), isNull);
  });

  test('owned equipment persists; empty means everything', () async {
    final store = await open();
    expect(store.ownedEquipment, isEmpty);

    await store.setOwnedEquipment({'dumbbell', 'body weight'});

    final again = await open();
    expect(again.ownedEquipment, {'dumbbell', 'body weight'});
  });

  test('loads demo clips, and still works when they fail to load', () async {
    await open();
    expect(ExerciseMedia.instance.has('bench_press'), isTrue);

    ExerciseMedia.instance = ExerciseMedia.fromJson('{}');
    final s = ExerciseStore(
      repo,
      health,
      loadCatalog: () async => base,
      loadMedia: () async => throw const FormatException('bad'),
    );
    await s.load();

    expect(s.loaded, isTrue);
    expect(s.catalog.byId('bench_press'), isNotNull);
    expect(ExerciseMedia.instance.count, 0);
  });
}
