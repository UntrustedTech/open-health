// Writes every exercise's matched animation next to its description, for
// review:
//   AUDIT_OUT=audit.tsv flutter test test_screenshots/demo_audit_test.dart
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/demo/demo_matcher.dart';
import 'package:health_app/demo/exercise_description.dart';
import 'package:health_app/models/exercise_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('audit', () async {
    final catalog = await ExerciseCatalog.loadBundled(rootBundle);
    ExerciseCatalog.instance = catalog;
    final out = StringBuffer();
    for (final e in catalog.all) {
      final d = DemoMatcher.forExercise(e);
      final x = ExerciseDescription.read(e.name, e.steps);
      out.writeln(
        '${d.movement.id}\t${d.hold.name}\t${e.name}\t${e.equipment}\t'
        '${x.posture.name},${x.bench.name},${x.sides.name},${x.limbs.name},'
        '${x.grip.name},${x.props.map((p) => p.name).join('+')},'
        '${x.slowLowering ? 'slow' : ''}${x.explosive ? 'fast' : ''}\t'
        '${e.target}\t${e.steps.join(' | ')}',
      );
    }
    File(Platform.environment['AUDIT_OUT']!).writeAsStringSync(out.toString());
  }, skip: !Platform.environment.containsKey('AUDIT_OUT'));
}
