import 'dart:io';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:health_app/app_edition.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/export/health_report.dart';
import 'package:health_app/export/share_files.dart';
import 'package:health_app/models/mood.dart';
import 'package:health_app/state/cycle_store.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/medication_store.dart';
import 'package:health_app/state/mood_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/log.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/app_chip.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';

/// Periods a report can cover.
enum ReportPeriod {
  month('30 Days', 30),
  quarter('3 Months', 91),
  half('6 Months', 182),
  year('1 Year', 365);

  const ReportPeriod(this.label, this.days);

  final String label;
  final int days;
}

/// Builds a PDF summary to share with a doctor. Nothing leaves the phone
/// until the user chooses where to send it.
class HealthReportScreen extends StatefulWidget {
  const HealthReportScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(
      title: 'Health Report',
      builder: (_) => const HealthReportScreen(),
    ),
  );

  @override
  State<HealthReportScreen> createState() => _HealthReportScreenState();
}

class _HealthReportScreenState extends State<HealthReportScreen> {
  ReportPeriod _period = ReportPeriod.quarter;
  bool _profile = true;
  bool _meds = !kStoreEdition;
  bool _cycle = true;
  bool _mood = true;
  bool _busy = false;
  ReportDesign get _design =>
      context.read<HealthStore>().personalization.reportDesign;

  /// The report for the chosen period and sections.
  HealthReport _report() {
    final health = context.read<HealthStore>();
    final to = health.today;
    final from = DateTime(to.year, to.month, to.day - _period.days + 1);
    final p = health.profile;
    final age = p.ageOn(to);
    final meds = context.read<MedicationStore>();
    final cycle = context.read<CycleStore>();
    final mood = context.read<MoodStore>();
    final moods = [
      for (final MapEntry(:key, :value) in mood.days.entries)
        if (!key.isBefore(from) && !key.isAfter(to)) value,
    ];
    final f = cycle.forecast;
    return HealthReport(
      from: from,
      to: to,
      created: health.now,
      patient: _profile
          ? [
              if (p.name.isNotEmpty) ('Name', p.name),
              if (p.birthDate case final b?)
                (
                  'Date of Birth',
                  '${DateFormat.yMMMd().format(b)}'
                      '${age == null ? '' : ' ($age)'}',
                ),
              if (p.sex.isNotEmpty) ('Sex', p.sex),
              if (p.heightCm case final h?) ('Height', Units.height(h)),
              if (p.bloodType.isNotEmpty) ('Blood Type', p.bloodType),
              if (p.allergies.isNotEmpty) ('Allergies', p.allergies),
              if (p.conditions.isNotEmpty) ('Conditions', p.conditions),
            ]
          : const [],
      vitals: [
        for (final t in HealthReport.vitalMetrics)
          ?HealthReport.rowFor(t, from, to, health.dailyValue),
      ],
      activity: [
        for (final t in HealthReport.activityMetrics)
          ?HealthReport.rowFor(t, from, to, health.dailyValue),
      ],
      medications: _meds
          ? [for (final m in meds.active) (m.name, m.dose, m.scheduleText)]
          : const [],
      adherence: _meds ? meds.adherence(days: _period.days) : null,
      cycle: _cycle && cycle.enabled && f.basedOn > 0
          ? 'Average cycle ${f.cycleLength} days, period '
                '${f.periodLength} days (from ${f.basedOn} '
                '${f.basedOn == 1 ? 'cycle' : 'cycles'}).'
                '${f.periods.isEmpty ? '' : ' Last period started '
                          '${DateFormat.yMMMd().format(f.periods.last.start)}.'}'
          : null,
      moodAverage: _mood ? MoodInsights.average(moods) : null,
    );
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final report = _report();
      final bytes = await report.toPdf(design: _design);
      final dir = await ShareFiles.prepare();
      final stamp = DateFormat('yyyy-MM-dd').format(report.to);
      final file = File('${dir.path}/Health-Report-$stamp.pdf');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: 'Health Report'),
      );
    } catch (e) {
      logError('Report failed: $e');
      if (mounted) {
        await showMessage(
          context,
          title: 'Couldn\'t Create Report',
          message: 'Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<HealthStore>();
    final report = _report();
    Widget toggle(
      String title,
      IconData icon,
      bool value,
      ValueChanged<bool> on,
    ) => CupertinoListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: CupertinoSwitch(value: value, onChanged: on),
    );
    return CupertinoPageScaffold(
      backgroundColor: context.groupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Health Report'),
      ),
      child: PageList(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.margin,
          12,
          AppTheme.margin,
          32,
        ),
        children: [
          const _Intro(),
          const SectionTitle('Period'),
          ChipRow(
            children: [
              for (final p in ReportPeriod.values)
                AppChip(
                  label: p.label,
                  selected: p == _period,
                  onTap: () => setState(() => _period = p),
                ),
            ],
          ),
          const SectionTitle('Design'),
          ChipRow(
            children: [
              for (final d in ReportDesign.values)
                AppChip(
                  label: d.label,
                  selected: d == _design,
                  onTap: () {
                    final store = context.read<HealthStore>();
                    store.setPersonalization(
                      store.personalization.copyWith(reportDesign: d),
                    );
                  },
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              _design.blurb,
              style: context.footnote.copyWith(color: context.secondaryLabel),
            ),
          ),
          GroupedSection(
            header: 'Include',
            footer:
                'Vitals and daily activity are always included: '
                '${report.vitals.length} vital '
                '${report.vitals.length == 1 ? 'measure' : 'measures'} '
                'and ${report.activity.length} activity '
                '${report.activity.length == 1 ? 'measure' : 'measures'} '
                'have data in this period.',
            children: [
              toggle(
                'Health Details',
                Icons.badge_rounded,
                _profile,
                (v) => setState(() => _profile = v),
              ),
              if (!kStoreEdition)
                toggle(
                  'Medications',
                  Icons.medication_rounded,
                  _meds,
                  (v) => setState(() => _meds = v),
                ),
              toggle(
                'Cycle Tracking',
                Icons.donut_large_rounded,
                _cycle,
                (v) => setState(() => _cycle = v),
              ),
              toggle(
                'Mood',
                Icons.emoji_emotions_rounded,
                _mood,
                (v) => setState(() => _mood = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CupertinoButton(
            color: context.labelColor,
            borderRadius: BorderRadius.circular(14),
            onPressed: _busy ? null : _share,
            child: _busy
                ? CupertinoActivityIndicator(color: context.onLabel)
                : Text(
                    'Create & Share PDF',
                    style: context.headline.copyWith(color: context.onLabel),
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            'The report is made on your phone. It\'s only shared where you '
            'choose to send it, and the copy is deleted the next time you '
            'share or open the app.',
            style: context.footnote.copyWith(color: context.secondaryLabel),
          ),
        ],
      ),
    );
  }
}

/// The page intro: what the report is for.
class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) => IosCard(
    child: Row(
      children: [
        const IconTile(
          icon: Icons.description_rounded,
          color: Palette.blue,
          size: 44,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            kStoreEdition
                ? 'A clean PDF of your vitals, activity and more, to bring to '
                      'an appointment.'
                : 'A clean PDF of your vitals, activity, medications and '
                      'more, to bring to an appointment.',
            style: context.subheadline.copyWith(color: context.secondaryLabel),
          ),
        ),
      ],
    ),
  );
}
