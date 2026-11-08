import 'dart:async';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/medication.dart';
import 'package:health_app/screens/medications/medication_editor.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/medication_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';

/// Today's doses, your medications and how consistently you take them.
class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(
      title: 'Medications',
      builder: (_) => const MedicationsScreen(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final meds = context.watch<MedicationStore>();
    final today = context.select<HealthStore, DateTime>((s) => s.today);
    final slots = meds.slotsOn(today);
    final asNeeded = meds.active.where((m) => m.asNeeded).toList();
    final adherence = meds.adherence();
    return LargeTitlePage(
      title: 'Medications',
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => MedicationEditor.show(context),
        child: Icon(Icons.add_rounded, semanticLabel: tr('Add Medication')),
      ),
      children: [
        if (meds.remindersFailed)
          GroupedSection(
            footer:
                'Health couldn\'t set up your medication reminders. Check '
                'that notifications are allowed for Health, then reopen it.',
            hasLeading: false,
            children: [
              InfoRow(
                title: 'Reminders Aren\'t Working',
                titleColor: context.destructive,
                onTap: meds.reschedule,
              ),
            ],
          ),
        if (meds.all.isEmpty)
          const _Empty()
        else ...[
          if (adherence != null)
            Appear(child: _AdherenceCard(adherence: adherence)),
          if (slots.isNotEmpty) ...[
            const SectionTitle('Today'),
            for (final (i, s) in slots.indexed) ...[
              Appear(
                index: i,
                child: DoseTile(slot: s),
              ),
              const SizedBox(height: 8),
            ],
          ],
          if (asNeeded.isNotEmpty) ...[
            const SectionTitle('As Needed'),
            for (final m in asNeeded) ...[
              _AsNeededTile(med: m, today: today),
              const SizedBox(height: 8),
            ],
          ],
          GroupedSection(
            header: 'Your Medications',
            children: [
              for (final m in meds.all)
                InfoRow(
                  leading: IconTile(
                    icon: m.form.icon,
                    color: m.archived
                        ? context.resolve(Palette.grey)
                        : context.resolve(m.color),
                  ),
                  title: m.name,
                  subtitle: m.archived ? 'Archived' : m.scheduleText,
                  chevron: true,
                  onTap: () => MedicationEditor.show(context, med: m),
                ),
            ],
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            'Health doesn\'t give medical advice. Always follow your '
            'doctor\'s or pharmacist\'s instructions.',
            style: context.footnote.copyWith(color: context.secondaryLabel),
          ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          IconTile(
            icon: Icons.medication_rounded,
            color: context.resolve(Palette.teal),
            size: 72,
          ),
          const SizedBox(height: 16),
          Text('Track Your Medications', style: context.title2),
          const SizedBox(height: 6),
          Text(
            'Add medications, vitamins and supplements, get reminders, and '
            'keep a record of every dose.',
            textAlign: TextAlign.center,
            style: context.subheadline.copyWith(color: context.secondaryLabel),
          ),
          const SizedBox(height: 16),
          CupertinoButton.filled(
            onPressed: () => MedicationEditor.show(context),
            child: const Text('Add a Medication'),
          ),
        ],
      ),
    );
  }
}

class _AdherenceCard extends StatelessWidget {
  const _AdherenceCard({required this.adherence});

  final double adherence;

  @override
  Widget build(BuildContext context) {
    final color = context.resolve(Palette.teal);
    return IosCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last 30 Days',
                  style: context.subheadline.copyWith(
                    color: context.labelColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AnimatedNumber(
                  value: adherence * 100,
                  format: (v) => '${v.round()}%',
                  style: context.number(34),
                ),
                Text(
                  'of scheduled doses taken',
                  style: context.footnote.copyWith(
                    color: context.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 64,
            height: 64,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: adherence),
              duration: Motion.reduced(context) ? Duration.zero : Motion.slow,
              curve: Motion.curve,
              builder: (context, v, _) =>
                  CustomPaint(painter: _Ring(v, color, context.fillColor)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Ring extends CustomPainter {
  _Ring(this.value, this.color, this.track);

  final double value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(5), 0, 6.283, false, paint..color = track);
    canvas.drawArc(
      rect.deflate(5),
      -1.5708,
      6.283 * value.clamp(0, 1),
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_Ring old) =>
      old.value != value || old.color != color || old.track != track;
}

/// One scheduled dose with Take / Skip, or what was recorded.
class DoseTile extends StatelessWidget {
  const DoseTile({super.key, required this.slot, this.flat = false});

  final DoseSlot slot;

  /// Without its own card, for use inside another card.
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final store = context.read<MedicationStore>();
    final s = slot;
    final log = s.log;
    final color = context.resolve(s.med.color);
    final row = Row(
      children: [
        IconTile(icon: s.med.form.icon, color: color, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat.jm().format(s.time),
                style: context.footnote.copyWith(
                  color: context.secondaryLabel,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(s.med.name, style: context.headline),
              if (s.med.dose.isNotEmpty)
                Text(
                  s.med.dose,
                  style: context.footnote.copyWith(
                    color: context.secondaryLabel,
                  ),
                ),
            ],
          ),
        ),
        AnimatedSwitcher(
          duration: Motion.reduced(context) ? Duration.zero : Motion.fast,
          child: log == null
              ? Row(
                  key: const ValueKey('ask'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size.square(AppTheme.minTapTarget),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        store.record(s.med, DoseStatus.skipped, slot: s.time);
                      },
                      child: Text(
                        'Skip',
                        style: TextStyle(color: context.secondaryLabel),
                      ),
                    ),
                    CupertinoButton.tinted(
                      color: color,
                      sizeStyle: CupertinoButtonSize.small,
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        store.record(s.med, DoseStatus.taken, slot: s.time);
                      },
                      child: Text(
                        'Take',
                        style: context.subheadline.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                )
              : GestureDetector(
                  key: ValueKey(log.status),
                  behavior: HitTestBehavior.opaque,
                  // Asks first: one stray tap shouldn't erase a dose.
                  onTap: () async {
                    final ok = await confirmDestructive(
                      context,
                      title: 'Undo ${s.med.name}?',
                      message:
                          'This dose will go back to not taken or skipped.',
                      action: 'Undo',
                    );
                    if (ok) await store.undo(s.med, s.time);
                  },
                  child: Semantics(
                    button: true,
                    hint: 'Double tap to undo',
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            log.status == DoseStatus.taken
                                ? Icons.check_circle_rounded
                                : Icons.remove_circle_rounded,
                            color: log.status == DoseStatus.taken
                                ? context.resolve(Palette.green)
                                : context.tertiaryLabel,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            log.status == DoseStatus.taken
                                ? 'Taken ${DateFormat.jm().format(log.at)}'
                                : 'Skipped',
                            style: context.footnote.copyWith(
                              color: context.secondaryLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
    if (flat) return row;
    return IosCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: row,
    );
  }
}

class _AsNeededTile extends StatelessWidget {
  /// A dose logged within this long of the last asks for confirmation.
  static const _repeatWindow = Duration(minutes: 10);

  const _AsNeededTile({required this.med, required this.today});

  final Medication med;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MedicationStore>();
    final taken = store.extraOn(today).where((l) => l.medId == med.id).toList();
    final color = context.resolve(med.color);
    return IosCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(
        children: [
          IconTile(icon: med.form.icon, color: color, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(med.name, style: context.headline),
                Text(
                  taken.isEmpty
                      ? 'Not taken today'
                      : 'Taken ${taken.length}× · last '
                            '${DateFormat.jm().format(taken.last.at)}',
                  style: context.footnote.copyWith(
                    color: context.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton.tinted(
            color: color,
            sizeStyle: CupertinoButtonSize.small,
            onPressed: () async {
              // A second dose this soon is more likely a double tap.
              final last = taken.isEmpty ? null : taken.last.at;
              if (last != null &&
                  DateTime.now().difference(last) < _repeatWindow) {
                final ok = await confirmDestructive(
                  context,
                  title: 'Log Another Dose?',
                  message:
                      'You logged ${med.name} at '
                      '${DateFormat.jm().format(last)}.',
                  action: 'Log Another Dose',
                );
                if (!ok) return;
              }
              unawaited(HapticFeedback.mediumImpact());
              await store.record(med, DoseStatus.taken);
            },
            child: Text(
              'Log Dose',
              style: context.subheadline.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
