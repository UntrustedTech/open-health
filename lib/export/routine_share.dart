import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:health_app/utils/units.dart';
import 'package:health_app/models/exercise_library.dart';
import 'package:health_app/workout/progression.dart';

const _format = 'health-routine';

/// Most exercises a shared routine may hold.
const maxSharedItems = 50;

/// Longest routine or exercise name taken from a shared file.
const maxNameLength = 80;

String _short(String s) {
  final t = s.trim();
  return t.length <= maxNameLength ? t : t.substring(0, maxNameLength);
}

/// A routine as a small file to send to a friend.
String routineToJson(
  Routine routine, {
  required String Function(String id) nameOf,
}) => const JsonEncoder.withIndent('  ').convert({
  'format': _format,
  'version': 1,
  'routine': routine.toJson(),
  // Names let the receiver match exercises they don't have.
  'names': {for (final i in routine.items) i.exerciseId: nameOf(i.exerciseId)},
});

/// Reads a shared routine, or null if the file isn't one.
({Routine routine, Map<String, String> names})? routineFromJson(String text) {
  try {
    final json = jsonDecode(text);
    if (json is! Map || json['format'] != _format) return null;
    final parsed = Routine.tryFromJson(json['routine']);
    if (parsed == null) return null;
    // Shared files are untrusted: limit their size.
    final name = _short(parsed.name);
    final routine = Routine(
      id: parsed.id,
      name: name.isEmpty ? 'Shared Routine' : name,
      items: parsed.items.take(maxSharedItems).toList(),
    );
    final ids = {for (final i in routine.items) i.exerciseId};
    final names = json['names'];
    return (
      routine: routine,
      names: names is Map
          ? {
              for (final e in names.entries)
                if (e.value is String && ids.contains('${e.key}'))
                  '${e.key}': _short(e.value as String),
            }
          : const {},
    );
  } on FormatException {
    return null;
  }
}

/// A printable one-page summary of a routine.
Future<Uint8List> routineToPdf(
  Routine routine, {
  required String Function(String id) nameOf,
}) {
  final doc = pw.Document(title: routine.name, creator: 'Health');
  String reps(RoutineItem i) => i.progression.kind == ProgressionKind.double
      ? '${i.progression.repMin}-${i.progression.repMax}'
      : '${i.reps}';
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            routine.name,
            style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Exercise', 'Sets', 'Reps', 'Weight', 'Rest'],
            data: [
              for (final i in routine.items)
                [
                  nameOf(i.exerciseId),
                  '${i.sets}${i.warmupSets > 0 ? ' (+${i.warmupSets} warm-up)' : ''}',
                  reps(i),
                  i.weightKg > 0 ? Units.weight(i.weightKg) : '-',
                  i.restSeconds == null
                      ? '-'
                      : '${i.restSeconds! ~/ 60}:${(i.restSeconds! % 60).toString().padLeft(2, '0')}',
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.Spacer(),
          pw.Text(
            'Made with Health',
            style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}
