import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:health_app/models/metric_type.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/utils/log.dart';
import 'package:health_app/utils/units.dart';

/// One measured value over the report's period.
@immutable
class ReportRow {
  const ReportRow({
    required this.label,
    required this.average,
    required this.low,
    required this.high,
    required this.days,
    this.note = '',
  });

  final String label;
  final String average;
  final String low;
  final String high;

  /// Days with a reading.
  final int days;

  /// A reference range or remark.
  final String note;
}

/// How a report looks. In the store version only Classic is free; the
/// rest come with the Report Designs add-on.
enum ReportDesign {
  classic(
    'Classic',
    'Black and grey, plain and simple.',
    accent: PdfColors.black,
    fill: PdfColors.grey200,
  ),
  clinical(
    'Clinical',
    'Calm blue headings and rules, like a lab report.',
    accent: PdfColor.fromInt(0xFF1F5A8C),
    fill: PdfColor.fromInt(0xFFE3EDF6),
    rules: true,
  ),
  bold(
    'Bold',
    'A coloured title band and striped tables.',
    accent: PdfColor.fromInt(0xFF0E7C66),
    fill: PdfColor.fromInt(0xFFDDF1EC),
    band: true,
    stripes: true,
  ),
  compact(
    'Compact',
    'Smaller text and margins, so more fits on a page.',
    accent: PdfColors.black,
    fill: PdfColors.grey200,
    scale: 0.85,
    margin: 24,
  );

  const ReportDesign(
    this.label,
    this.blurb, {
    required this.accent,
    required this.fill,
    this.rules = false,
    this.band = false,
    this.stripes = false,
    this.scale = 1,
    this.margin = 36,
  });

  final String label;
  final String blurb;

  /// Headings and the title band.
  final PdfColor accent;

  /// Table headers.
  final PdfColor fill;

  /// A line under each heading.
  final bool rules;

  /// The title on a band of [accent].
  final bool band;

  /// Every other table row shaded.
  final bool stripes;

  /// Text size, relative to Classic.
  final double scale;

  /// Page margin in points.
  final double margin;
}

/// Everything in a health report, gathered from the app's data.
@immutable
class HealthReport {
  const HealthReport({
    required this.from,
    required this.to,
    required this.created,
    required this.patient,
    required this.vitals,
    required this.activity,
    this.medications = const [],
    this.adherence,
    this.cycle,
    this.moodAverage,
  });

  final DateTime from;
  final DateTime to;
  final DateTime created;

  /// Label → value pairs from the profile and Medical ID.
  final List<(String, String)> patient;
  final List<ReportRow> vitals;
  final List<ReportRow> activity;

  /// Name, dose and schedule of each current medication.
  final List<(String, String, String)> medications;

  /// Share of scheduled doses taken over the period.
  final double? adherence;

  /// e.g. "Average cycle 29 days, period 5 days; last period Oct 2".
  final String? cycle;
  final double? moodAverage;

  /// Metrics in the vitals table, in order.
  static const vitalMetrics = [
    MetricType.restingHeartRate,
    MetricType.heartRate,
    MetricType.hrv,
    MetricType.bloodPressureSystolic,
    MetricType.bloodPressureDiastolic,
    MetricType.bloodGlucose,
    MetricType.bloodOxygen,
    MetricType.weight,
    MetricType.sleep,
  ];

  /// Metrics in the activity table.
  static const activityMetrics = [
    MetricType.steps,
    MetricType.activeEnergy,
    MetricType.exerciseMinutes,
  ];

  static const _notes = {
    MetricType.restingHeartRate: 'Typical adult 60-100 bpm',
    MetricType.bloodPressureSystolic: 'Normal under 120 mmHg',
    MetricType.bloodPressureDiastolic: 'Normal under 80 mmHg',
    MetricType.bloodOxygen: 'Typical 95-100%',
    MetricType.sleep: 'Adults: 7-9 hours',
  };

  /// Daily values of [type] from [from] to [to] as a table row, or null
  /// without any.
  static ReportRow? rowFor(
    MetricType type,
    DateTime from,
    DateTime to,
    double? Function(MetricType, DateTime) dailyValue,
  ) {
    final values = [
      for (
        var d = from;
        !d.isAfter(to);
        d = DateTime(d.year, d.month, d.day + 1)
      )
        ?dailyValue(type, d),
    ];
    if (values.isEmpty) return null;
    String f(double v) => '${formatValue(type, v)} ${unitLabel(type)}'
        .replaceAll(' ', ' ')
        .trim();
    final avg = values.reduce((a, b) => a + b) / values.length;
    var note = _notes[type] ?? '';
    if (type == MetricType.bloodGlucose) {
      note = Units.imperial ? 'Typical 70-140 mg/dL' : 'Typical 3.9-7.8 mmol/L';
    }
    return ReportRow(
      label: type.label,
      average: f(avg),
      low: f(values.reduce((a, b) => a < b ? a : b)),
      high: f(values.reduce((a, b) => a > b ? a : b)),
      days: values.length,
      note: note,
    );
  }

  /// The report as a PDF in [design]. Uses the app's font when it can be
  /// loaded.
  Future<Uint8List> toPdf({ReportDesign design = ReportDesign.classic}) async {
    final s = design.scale;
    pw.ThemeData? theme;
    try {
      theme = pw.ThemeData.withFont(
        base: pw.Font.ttf(
          await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
        ),
        bold: pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf')),
      );
      // A missing asset throws an Error, not an Exception.
    } catch (e) {
      logError('Report: app font unavailable, using default: $e');
    }
    // English, as the rest of the report, in a font without CJK glyphs.
    final date = DateFormat.yMMMd('en_US');
    final doc = pw.Document(
      title: 'Health Report',
      creator: 'Health',
      theme: theme,
    );
    final body = pw.TextStyle(fontSize: 12 * s);
    pw.Widget heading(String text) => pw.Container(
      width: double.infinity,
      margin: pw.EdgeInsets.only(top: 18 * s, bottom: 6 * s),
      padding: design.rules ? const pw.EdgeInsets.only(bottom: 3) : null,
      decoration: design.rules
          ? pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: design.accent)),
            )
          : null,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 14 * s,
          fontWeight: pw.FontWeight.bold,
          color: design.accent,
        ),
      ),
    );
    pw.Widget grid(List<String> headers, List<List<String>> data) =>
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: data,
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9 * s,
          ),
          cellStyle: pw.TextStyle(fontSize: 9 * s),
          headerDecoration: pw.BoxDecoration(color: design.fill),
          oddRowDecoration: design.stripes
              ? const pw.BoxDecoration(color: PdfColors.grey100)
              : null,
          cellAlignment: pw.Alignment.centerLeft,
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        );
    final title = [
      pw.Text(
        'Health Report',
        style: pw.TextStyle(
          fontSize: 24 * s,
          fontWeight: pw.FontWeight.bold,
          color: design.band ? PdfColors.white : design.accent,
        ),
      ),
      pw.Text(
        '${date.format(from)} - ${date.format(to)}',
        style: pw.TextStyle(
          fontSize: 11 * s,
          color: design.band ? PdfColors.grey200 : PdfColors.grey700,
        ),
      ),
    ];
    pw.Widget table(List<ReportRow> rows) => grid(
      ['Measure', 'Average', 'Low', 'High', 'Days', 'Reference'],
      [
        for (final r in rows)
          [r.label, r.average, r.low, r.high, '${r.days}', r.note],
      ],
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(design.margin),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Made with Health on ${date.format(created)}. Self-recorded and '
              'device data; not a medical record or diagnosis.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              '${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
        build: (context) => [
          if (design.band)
            pw.Container(
              width: double.infinity,
              color: design.accent,
              padding: const pw.EdgeInsets.all(14),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: title,
              ),
            )
          else
            ...title,
          if (patient.isNotEmpty) ...[
            heading('Patient'),
            pw.Wrap(
              spacing: 24,
              runSpacing: 6,
              children: [
                for (final (label, value) in patient)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        label,
                        style: pw.TextStyle(
                          fontSize: 8 * s,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.Text(value, style: pw.TextStyle(fontSize: 10 * s)),
                    ],
                  ),
              ],
            ),
          ],
          heading('Vitals'),
          if (vitals.isEmpty)
            pw.Text('No readings in this period.', style: body)
          else
            table(vitals),
          if (activity.isNotEmpty) ...[
            heading('Daily Activity'),
            table(activity),
          ],
          if (medications.isNotEmpty) ...[
            heading('Medications'),
            grid(
              ['Medication', 'Dose', 'Schedule'],
              [
                for (final (name, dose, schedule) in medications)
                  [name, dose, schedule],
              ],
            ),
            if (adherence case final a?)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 6),
                child: pw.Text(
                  'Doses taken as scheduled: ${(a * 100).round()}%',
                  style: pw.TextStyle(fontSize: 10 * s),
                ),
              ),
          ],
          if (cycle case final c?) ...[
            heading('Cycle'),
            pw.Text(c, style: body),
          ],
          if (moodAverage case final m?) ...[
            heading('Mood'),
            pw.Text(
              'Average self-rated mood: ${m.toStringAsFixed(1)} out of 5.',
              style: body,
            ),
          ],
        ],
      ),
    );
    return doc.save();
  }
}
