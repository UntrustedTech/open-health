import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import 'package:health_app/models/health_entry.dart';
import 'package:health_app/models/workout.dart';

final _date = DateFormat('yyyy-MM-dd');
final _time = DateFormat('HH:mm');
final _stamp = DateFormat('yyyy-MM-dd HH:mm:ss');

/// Spreadsheets open with a byte-order mark as UTF-8 (needed by Excel).
final _csv = Csv(addBom: true);

/// Health data as a spreadsheet: one row per entry, oldest first. Sample
/// data is left out.
String healthEntriesCsv(List<HealthEntry> entries) {
  final rows = [...entries.where((e) => !e.isSample)]
    ..sort((a, b) => a.date.compareTo(b.date));
  return _csv.encode([
    const ['Date', 'Time', 'Type', 'Value', 'Unit', 'Source', 'Note'],
    for (final e in rows)
      [
        _date.format(e.date),
        _time.format(e.date),
        e.type.label,
        e.value,
        e.type.unit,
        _source(e.source),
        safeCell(e.note ?? ''),
      ],
  ]);
}

/// Strength workouts in Strong's CSV layout, so they open in a spreadsheet
/// and can be imported back into Health, Strong or Hevy. Cardio workouts
/// get one summary row each.
String workoutsCsv(
  List<WorkoutSession> workouts,
  String Function(String exerciseId) nameOf,
) {
  final sorted = [...workouts]..sort((a, b) => a.start.compareTo(b.start));
  return _csv.encode([
    const [
      'Date',
      'Workout Name',
      'Duration',
      'Exercise Name',
      'Set Order',
      'Weight (kg)',
      'Reps',
      'Distance (km)',
      'Seconds',
      'RPE',
      'Calories',
    ],
    for (final w in sorted) ..._workoutRows(w, nameOf),
  ]);
}

List<List<Object>> _workoutRows(
  WorkoutSession w,
  String Function(String) nameOf,
) {
  final date = _stamp.format(w.start);
  final duration = _duration(w.end.difference(w.start));
  final title = safeCell(w.type.label);
  if (w.exercises.isEmpty) {
    return [
      [
        date,
        title,
        duration,
        '',
        '',
        '',
        '',
        (w.distanceMeters / 1000).toStringAsFixed(2),
        w.activeSeconds,
        '',
        w.activeKcal.round(),
      ],
    ];
  }
  return [
    for (final ex in w.exercises)
      for (final (i, set) in ex.sets.indexed)
        [
          date,
          title,
          duration,
          safeCell(nameOf(ex.exerciseId)),
          switch (set.type) {
            SetType.warmup => 'W',
            SetType.drop => 'D',
            SetType.failure => 'F',
            _ => i + 1,
          },
          set.weightKg,
          set.reps,
          '',
          set.seconds ?? '',
          set.rpe ?? '',
          '',
        ],
  ];
}

/// "1h 5m", as Strong writes it.
String _duration(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}

String _source(EntrySource s) => switch (s) {
  EntrySource.manual => 'Manual',
  EntrySource.healthConnect => 'Health Connect',
  EntrySource.workout => 'Workout',
  EntrySource.food => 'Food Diary',
  EntrySource.sample => 'Sample',
  EntrySource.plugin => 'Other',
};

/// Stops text that starts like a formula from running as one when the
/// file is opened in a spreadsheet (CSV injection).
String safeCell(String text) => _formulaStart.hasMatch(text) ? "'$text" : text;

final _formulaStart = RegExp(r'^[=+\-@\t\r]');

/// [files] (name, text) in one zip encrypted with AES-256 under
/// [password] (WinZip's format: 7-Zip, WinZip and most file apps open it).
List<int> encryptedZip(List<(String, String)> files, String password) {
  final archive = Archive();
  for (final (name, text) in files) {
    archive.addFile(ArchiveFile.bytes(name, utf8.encode(text)));
  }
  return ZipEncoder(password: password).encode(archive);
}
