import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/models/exercise_media.dart';
import 'package:health_app/widgets/exercise_clip.dart';
import 'package:health_app/widgets/exercise_figure.dart' show demoAnimations;

void main() {
  final bundled = ExerciseMedia.fromJson(
    File('assets/data/exercise_media.json').readAsStringSync(),
  );
  final catalog = ExerciseCatalog.fromBundledJson(
    File('assets/data/exercises.json').readAsStringSync(),
  );

  group('ExerciseMedia', () {
    test('resolves old exercise ids through catalog aliases', () {
      final media = ExerciseMedia.fromJson('{"0025":"010"}');

      expect(media.framesFor('bench_press'), [
        'assets/exercise_media/010_0.webp',
        'assets/exercise_media/010_1.webp',
      ]);
      expect(media.framesFor('0025'), media.framesFor('bench_press'));
      expect(media.has('squat'), isFalse);
    });

    test('ignores malformed entries and documents', () {
      final media = ExerciseMedia.fromJson(
        '{"a":"../../secret","b":7,"c":"12","d":"001"}',
      );

      expect(media.count, 1);
      expect(media.has('d'), isTrue);
      expect(ExerciseMedia.fromJson('[1,2]').count, 0);
    });

    test('every bundled clip has both frames on disk', () {
      expect(bundled.count, greaterThan(250));
      for (final e in catalog.all) {
        for (final path in bundled.framesFor(e.id) ?? const <String>[]) {
          expect(File(path).existsSync(), isTrue, reason: path);
        }
      }
    });

    test('only maps exercises that exist in the catalog', () {
      final raw = File('assets/data/exercise_media.json').readAsStringSync();
      final ids = RegExp(r'"([^"]+)":').allMatches(raw).map((m) => m[1]!);
      for (final id in ids) {
        expect(catalog.byId(id), isNotNull, reason: id);
      }
    });

    test('the app\'s starter exercises have clips', () {
      for (final id in [
        'bench_press',
        'squat',
        'deadlift',
        'pull_up',
        'ohp',
        'barbell_row',
        'lat_pulldown',
        'leg_press',
        'rdl',
        'plank',
        'bicep_curl',
        'tricep_pushdown',
      ]) {
        expect(bundled.has(id), isTrue, reason: id);
      }
    });
  });

  group('ExerciseClip.endFrameOpacity', () {
    test('holds each position, then blends', () {
      expect(ExerciseClip.endFrameOpacity(0), 0);
      expect(ExerciseClip.endFrameOpacity(0.3), 0);
      expect(ExerciseClip.endFrameOpacity(0.44), inExclusiveRange(0, 1));
      expect(ExerciseClip.endFrameOpacity(0.6), 1);
      expect(ExerciseClip.endFrameOpacity(0.94), inExclusiveRange(0, 1));
      expect(ExerciseClip.endFrameOpacity(1), 0);
    });
  });

  group('ExerciseClip widget', () {
    setUp(() {
      ExerciseMedia.instance = ExerciseMedia.fromJson('{"0025":"010"}');
    });
    tearDown(() => ExerciseMedia.instance = ExerciseMedia.fromJson('{}'));

    Widget host(String id, {bool reduceMotion = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: CupertinoApp(
        home: Center(
          child: SizedBox(width: 300, child: ExerciseClip(exerciseId: id)),
        ),
      ),
    );

    Opacity endFrame(WidgetTester tester) => tester.widget<Opacity>(
      find.descendant(
        of: find.byType(ExerciseClip),
        matching: find.byType(Opacity),
      ),
    );

    testWidgets('shows the start and finish side by side, still', (
      tester,
    ) async {
      await tester.pumpWidget(host('bench_press'));
      await tester.pump(ExerciseClip.period);

      expect(find.byType(Image), findsNWidgets(2));
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Finish'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    }, skip: demoAnimations);

    testWidgets(
      'loops between frames and pauses on tap',
      skip: !demoAnimations,
      (tester) async {
        await tester.pumpWidget(host('bench_press'));
        expect(find.byType(Image), findsNWidgets(2));
        expect(endFrame(tester).opacity, 0);

        await tester.pump(ExerciseClip.period * 0.6);
        expect(endFrame(tester).opacity, 1);

        await tester.tap(find.byType(ExerciseClip));
        await tester.pump();
        final paused = endFrame(tester).opacity;
        await tester.pump(ExerciseClip.period * 0.5);
        expect(endFrame(tester).opacity, paused);
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'starts paused when reduce motion is on',
      skip: !demoAnimations,
      (tester) async {
        await tester.pumpWidget(host('bench_press', reduceMotion: true));
        await tester.pump(ExerciseClip.period * 0.6);

        expect(endFrame(tester).opacity, 0);
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      },
    );

    testWidgets('shows nothing for an exercise without a clip', (tester) async {
      await tester.pumpWidget(host('squat'));

      expect(find.byType(Image), findsNothing);
    });
  });
}
