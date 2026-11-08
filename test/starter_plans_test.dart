import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/models/starter_plans.dart';

void main() {
  test('every starter plan exercise exists in the library', () {
    final catalog = ExerciseCatalog.fromBundledJson(
      File('assets/data/exercises.json').readAsStringSync(),
    );
    for (final plan in StarterPlan.all) {
      for (final r in plan.routines) {
        for (final item in r.items) {
          expect(
            catalog.byId(item.exerciseId),
            isNotNull,
            reason: '${plan.name}: ${item.exerciseId}',
          );
        }
      }
      for (final i in plan.days.values) {
        expect(i, lessThan(plan.routines.length));
      }
    }
  });
}
