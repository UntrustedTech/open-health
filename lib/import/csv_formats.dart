import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:health_app/models/workout.dart';

enum CsvFormat {
  strong('Strong'),
  hevy('Hevy'),
  fitNotes('FitNotes'),
  unknown('Unknown');

  const CsvFormat(this.label);

  final String label;
}

/// An exercise as named in another app, with its sets (weights in kg).
@immutable
class ImportedExercise {
  const ImportedExercise(this.name, this.sets);

  final String name;
  final List<SetLog> sets;
}

@immutable
class ImportedWorkout {
  const ImportedWorkout({
    required this.title,
    required this.start,
    required this.duration,
    required this.exercises,
  });

  final String title;
  final DateTime start;
  final Duration duration;
  final List<ImportedExercise> exercises;
}

typedef ParsedCsv = ({CsvFormat format, List<ImportedWorkout> workouts});

const _lbToKg = 0.45359237;

/// Longest exercise name kept from an import.
const _maxName = 80;

/// Reads a workout export from Strong, Hevy or FitNotes. The format is
/// recognised from the column names; unknown files return no workouts.
ParsedCsv parseWorkoutCsv(String text) {
  final rows = Csv().decode(text.replaceFirst('﻿', ''));
  if (rows.length < 2) return (format: CsvFormat.unknown, workouts: const []);
  final header = [for (final h in rows.first) '$h'.trim().toLowerCase()];
  int col(bool Function(String) test) => header.indexWhere(test);
  final body = rows.skip(1).toList();

  if (header.contains('exercise_title') && header.contains('start_time')) {
    return (format: CsvFormat.hevy, workouts: _hevy(body, header));
  }
  if (header.contains('exercise name') && header.contains('set order')) {
    return (format: CsvFormat.strong, workouts: _strong(body, header));
  }
  if (header.contains('exercise') &&
      col((h) => h.startsWith('weight')) >= 0 &&
      header.contains('date')) {
    return (format: CsvFormat.fitNotes, workouts: _fitNotes(body, header));
  }
  return (format: CsvFormat.unknown, workouts: const []);
}

String _cell(List<dynamic> row, int i) =>
    i >= 0 && i < row.length ? '${row[i]}'.trim() : '';

/// A number from a cell, or 0. "NaN", "Infinity" and the like are 0 too:
/// they can't be saved.
double _num(String s) => switch (double.tryParse(s.replaceAll(',', '.'))) {
  final v? when v.isFinite => v,
  _ => 0,
};

SetType _setType(String s) => switch (s.toLowerCase()) {
  'w' || 'warmup' || 'warm-up' || 'warm up' => SetType.warmup,
  'd' || 'dropset' || 'drop' || 'drop set' => SetType.drop,
  'f' || 'failure' => SetType.failure,
  _ => SetType.normal,
};

/// Groups rows into workouts by key, keeping exercise order.
List<ImportedWorkout> _group(
  Iterable<
    ({
      String key,
      String title,
      DateTime start,
      Duration duration,
      String exercise,
      SetLog set,
    })
  >
  rows,
) {
  final workouts =
      <
        String,
        ({
          String title,
          DateTime start,
          Duration duration,
          Map<String, List<SetLog>> ex,
        })
      >{};
  for (final r in rows) {
    final w = workouts.putIfAbsent(
      r.key,
      () => (
        title: r.title,
        start: r.start,
        duration: r.duration,
        ex: <String, List<SetLog>>{},
      ),
    );
    // Files are untrusted: skip nameless rows, cap long names.
    final name = r.exercise.trim();
    if (name.isEmpty) continue;
    final key = name.length > _maxName ? name.substring(0, _maxName) : name;
    w.ex.putIfAbsent(key, () => []).add(r.set);
  }
  return [
    for (final w in workouts.values)
      if (w.ex.isNotEmpty)
        ImportedWorkout(
          title: w.title,
          start: w.start,
          duration: w.duration,
          exercises: [
            for (final e in w.ex.entries) ImportedExercise(e.key, e.value),
          ],
        ),
  ]..sort((a, b) => a.start.compareTo(b.start));
}

/// "1h 5m", "45m", "3600" (seconds) → duration.
Duration _strongDuration(String s) {
  final h = RegExp(r'(\d+)\s*h').firstMatch(s)?.group(1);
  final m = RegExp(r'(\d+)\s*m').firstMatch(s)?.group(1);
  if (h == null && m == null) return Duration(seconds: int.tryParse(s) ?? 0);
  return Duration(
    hours: int.tryParse(h ?? '0') ?? 0,
    minutes: int.tryParse(m ?? '0') ?? 0,
  );
}

/// A done set from the column positions Strong and Hevy share.
SetLog _loggedSet(
  List<dynamic> row, {
  required int reps,
  required int weight,
  required bool lbs,
  required int type,
  required int secs,
  required int rpe,
}) {
  final seconds = _num(_cell(row, secs));
  final effort = _num(_cell(row, rpe));
  return SetLog(
    reps: _num(_cell(row, reps)).clamp(0, 10000).round(),
    weightKg: _num(_cell(row, weight)).clamp(0, 2000) * (lbs ? _lbToKg : 1),
    done: true,
    type: _setType(_cell(row, type)),
    seconds: seconds > 0 ? seconds.clamp(0, 86400).round() : null,
    rpe: effort > 0 ? effort.clamp(0, 10).toDouble() : null,
  );
}

List<ImportedWorkout> _strong(List<List<dynamic>> body, List<String> h) {
  final date = h.indexOf('date'),
      name = h.indexOf('workout name'),
      dur = h.indexOf('duration');
  final ex = h.indexOf('exercise name'), order = h.indexOf('set order');
  final weight = h.indexWhere((x) => x.startsWith('weight'));
  final lbs = weight >= 0 && h[weight].contains('lb');
  final reps = h.indexOf('reps'),
      secs = h.indexOf('seconds'),
      rpe = h.indexOf('rpe');
  return _group([
    for (final row in body)
      if (DateTime.tryParse(_cell(row, date)) case final start?)
        (
          key: _cell(row, date),
          title: _cell(row, name),
          start: start,
          duration: _strongDuration(_cell(row, dur)),
          exercise: _cell(row, ex),
          set: _loggedSet(
            row,
            reps: reps,
            weight: weight,
            lbs: lbs,
            type: order,
            secs: secs,
            rpe: rpe,
          ),
        ),
  ]);
}

final _hevyDate = DateFormat('d MMM yyyy, HH:mm', 'en_US');

DateTime? _parseHevy(String s) {
  try {
    return _hevyDate.parseLoose(s);
  } on FormatException {
    return DateTime.tryParse(s);
  }
}

List<ImportedWorkout> _hevy(List<List<dynamic>> body, List<String> h) {
  final title = h.indexOf('title'),
      start = h.indexOf('start_time'),
      end = h.indexOf('end_time');
  final ex = h.indexOf('exercise_title'), type = h.indexOf('set_type');
  final weight = h.indexWhere((x) => x.startsWith('weight'));
  final lbs = weight >= 0 && h[weight].contains('lb');
  final reps = h.indexOf('reps'),
      secs = h.indexOf('duration_seconds'),
      rpe = h.indexOf('rpe');
  return _group([
    for (final row in body)
      if (_parseHevy(_cell(row, start)) case final s?)
        (
          key: _cell(row, start),
          title: _cell(row, title),
          start: s,
          duration: (_parseHevy(_cell(row, end)) ?? s).difference(s),
          exercise: _cell(row, ex),
          set: _loggedSet(
            row,
            reps: reps,
            weight: weight,
            lbs: lbs,
            type: type,
            secs: secs,
            rpe: rpe,
          ),
        ),
  ]);
}

List<ImportedWorkout> _fitNotes(List<List<dynamic>> body, List<String> h) {
  final date = h.indexOf('date'), ex = h.indexOf('exercise');
  final weight = h.indexWhere(
    (x) => x.startsWith('weight') && !x.contains('unit'),
  );
  final unit = h.indexOf('weight unit');
  final reps = h.indexOf('reps');
  return _group([
    for (final row in body)
      if (DateTime.tryParse(_cell(row, date)) case final day?)
        (
          key: _cell(row, date),
          title: 'Workout',
          // FitNotes has no times: midday, with no duration so imports
          // don't add made-up exercise minutes.
          start: DateTime(day.year, day.month, day.day, 12),
          duration: Duration.zero,
          exercise: _cell(row, ex),
          set: SetLog(
            reps: _num(_cell(row, reps)).clamp(0, 10000).round(),
            weightKg:
                _num(_cell(row, weight)).clamp(0, 2000) *
                ((h[weight].contains('lb') ||
                        _cell(row, unit).toLowerCase().startsWith('lb'))
                    ? _lbToKg
                    : 1),
            done: true,
          ),
        ),
  ]);
}
