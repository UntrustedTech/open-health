import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/export/csv_export.dart';
import 'package:health_app/import/csv_formats.dart';
import 'package:health_app/models/health_entry.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/workout.dart';

void main() {
  List<List<dynamic>> rows(String csv) =>
      Csv().decode(csv.replaceFirst('﻿', ''));

  test('health entries export oldest first, without samples', () {
    final csv = healthEntriesCsv([
      HealthEntry(
        id: '2',
        type: MetricType.weight,
        value: 72.5,
        date: DateTime(2026, 10, 2, 8, 5),
        note: '=HYPERLINK("x")',
      ),
      HealthEntry(
        id: '1',
        type: MetricType.water,
        value: 250,
        date: DateTime(2026, 10, 1, 9),
      ),
      HealthEntry(
        id: 's',
        type: MetricType.steps,
        value: 1,
        date: DateTime(2026, 10, 1),
        source: EntrySource.sample,
      ),
    ]);
    final r = rows(csv);

    expect(csv.startsWith('﻿'), isTrue);
    expect(r.first, [
      'Date',
      'Time',
      'Type',
      'Value',
      'Unit',
      'Source',
      'Note',
    ]);
    expect(r, hasLength(3));
    expect(r[1].take(3), ['2026-10-01', '09:00', 'Water']);
    expect(r[2][3].toString(), '72.5');
    // Formula-like text can't run when opened in a spreadsheet.
    expect(r[2][6], "'=HYPERLINK(\"x\")");
  });

  test('safeCell only changes formula-like text', () {
    expect(safeCell('Bench Press'), 'Bench Press');
    expect(safeCell('-5 kg'), "'-5 kg");
    expect(safeCell('@cmd'), "'@cmd");
  });

  test('strength workouts round-trip through the Strong importer', () {
    final csv = workoutsCsv([
      WorkoutSession(
        id: 'w1',
        type: WorkoutType.strength,
        start: DateTime(2026, 10, 9, 18),
        end: DateTime(2026, 10, 9, 19, 5),
        activeSeconds: 3900,
        exercises: const [
          ExerciseLog(
            exerciseId: 'squat',
            sets: [
              SetLog(reps: 8, weightKg: 60, done: true, type: SetType.warmup),
              SetLog(reps: 5, weightKg: 100, done: true, rpe: 8),
            ],
          ),
        ],
      ),
      WorkoutSession(
        id: 'w2',
        type: WorkoutType.run,
        start: DateTime(2026, 10, 8, 7),
        end: DateTime(2026, 10, 8, 7, 30),
        activeSeconds: 1800,
        distanceMeters: 5000,
        activeKcal: 320,
      ),
    ], (id) => id == 'squat' ? 'Squat (Barbell)' : 'Exercise');

    final parsed = parseWorkoutCsv(csv.replaceFirst('﻿', ''));
    expect(parsed.format, CsvFormat.strong);
    // Cardio summary rows have no exercise, so they aren't re-imported.
    final strength = parsed.workouts.single;
    expect(strength.start, DateTime(2026, 10, 9, 18));
    expect(strength.duration, const Duration(hours: 1, minutes: 5));
    final squat = strength.exercises.single;
    expect(squat.name, 'Squat (Barbell)');
    expect(squat.sets.first.type, SetType.warmup);
    expect(squat.sets.last.weightKg, 100);
    expect(squat.sets.last.rpe, 8);

    final run = rows(csv).firstWhere((r) => '${r[0]}'.startsWith('2026-10-08'));
    expect(run[7], '5.00');
    expect('${run[10]}', '320');
  });

  test('an encrypted export opens only with its password', () {
    final zip = encryptedZip([
      ('a.csv', 'Date,Steps\n2026-11-07,4625'),
    ], 'long password 1');
    // The data isn't readable in the file itself.
    expect(utf8.decode(zip, allowMalformed: true), isNot(contains('4625')));
    final opened = ZipDecoder().decodeBytes(zip, password: 'long password 1');
    expect(utf8.decode(opened.findFile('a.csv')!.content), contains('4625'));
    expect(
      () => ZipDecoder()
          .decodeBytes(zip, password: 'wrong password!')
          .findFile('a.csv')!
          .content,
      throwsA(anything),
    );
  });
}
