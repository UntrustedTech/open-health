import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/export/data_export.dart';
import 'package:health_app/export/routine_share.dart';
import 'package:health_app/models/exercise_library.dart';
import 'package:health_app/models/health_entry.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/workout/progression.dart';

void main() {
  const routine = Routine(
    id: 'r1',
    name: 'My Push',
    items: [
      RoutineItem(
        '0025',
        sets: 4,
        reps: 6,
        weightKg: 80,
        restSeconds: 180,
        progression: ProgressionRule(kind: ProgressionKind.linear),
      ),
      RoutineItem('c_123', sets: 3, reps: 12),
    ],
  );

  test('export holds everything as readable JSON', () {
    final json = exportAllData(
      exportedAt: DateTime(2026, 10, 11),
      entries: [
        HealthEntry(
          id: 'e1',
          type: MetricType.steps,
          value: 1000,
          date: DateTime(2026, 10, 11),
        ),
      ],
      workouts: [
        WorkoutSession(
          id: 'w1',
          type: WorkoutType.run,
          start: DateTime(2026, 10, 11),
          end: DateTime(2026, 10, 11, 0, 30),
          activeSeconds: 1800,
        ),
      ],
      routines: const [routine],
      documents: {
        'profile': {'name': 'Alex'},
      },
    );
    final decoded = jsonDecode(json) as Map<String, Object?>;
    expect(decoded['app'], 'Health');
    expect((decoded['entries'] as List).single, containsPair('type', 'steps'));
    expect((decoded['workouts'] as List).single, containsPair('id', 'w1'));
    expect(
      (decoded['routines'] as List).single,
      containsPair('name', 'My Push'),
    );
    expect((decoded['documents'] as Map)['profile'], {'name': 'Alex'});
  });

  test('a shared routine round-trips, carrying exercise names', () {
    final text = routineToJson(
      routine,
      nameOf: (id) => id == 'c_123' ? 'Sandbag Carry' : 'Bench',
    );

    final shared = routineFromJson(text);

    expect(shared?.routine.name, 'My Push');
    expect(shared?.routine.items.first.restSeconds, 180);
    expect(
      shared?.routine.items.first.progression.kind,
      ProgressionKind.linear,
    );
    expect(shared?.names['c_123'], 'Sandbag Carry');
    expect(routineFromJson('{"nope":1}'), isNull);
  });

  test('a routine prints as a PDF', () async {
    final bytes = await routineToPdf(routine, nameOf: (id) => 'Exercise $id');
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('a hostile routine file is clamped to sane values', () {
    final text = jsonEncode({
      'format': 'health-routine',
      'routine': {
        'id': 'x',
        'name': 'N' * 500,
        'items': [
          for (var i = 0; i < 200; i++)
            {
              'e': 'e$i',
              's': 1000000,
              'r': -5,
              'w': 1e12,
              'wu': 99999,
              'rest': -1,
              'ss': 42,
              'prog': {'k': 'double', 'inc': 1e9, 'min': 15, 'max': 3},
            },
        ],
      },
      'names': {'e0': 'B' * 500},
    });

    final shared = routineFromJson(text)!;
    final item = shared.routine.items.first;

    expect(shared.routine.name.length, lessThanOrEqualTo(80));
    expect(shared.routine.items.length, lessThanOrEqualTo(50));
    expect(shared.names['e0']!.length, lessThanOrEqualTo(80));
    expect(item.sets, inInclusiveRange(1, 20));
    expect(item.reps, inInclusiveRange(1, 999));
    expect(item.weightKg, inInclusiveRange(0, 1000));
    expect(item.warmupSets, inInclusiveRange(0, 10));
    expect(item.restSeconds, isNull);
    expect(item.superset, isNull);
    expect(item.progression.increment, lessThanOrEqualTo(50));
    expect(item.progression.repMin, lessThanOrEqualTo(item.progression.repMax));
  });
}
