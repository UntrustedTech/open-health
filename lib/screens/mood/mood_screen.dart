import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/mood.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/mood_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/widgets/app_chip.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/sheet_scaffold.dart';

/// The mood journal colour.
const moodColor = Palette.yellow;

/// Mood journal: today's mood, the last month and patterns.
class MoodScreen extends StatelessWidget {
  const MoodScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context)
      .push(AppRoute<void>(title: 'Mood', builder: (_) => const MoodScreen()));

  @override
  Widget build(BuildContext context) {
    final mood = context.watch<MoodStore>();
    final store = context.watch<HealthStore>();
    final month = mood.recent(30);
    final avg = MoodInsights.average([for (final (_, e) in month) e]);
    final patterns = _patterns(context, mood.days);
    return CupertinoPageScaffold(
      backgroundColor: context.groupedBackground,
      navigationBar: const CupertinoNavigationBar(middle: Text('Mood')),
      child: PageList(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.margin,
          12,
          AppTheme.margin,
          32,
        ),
        children: [
          const MoodCard(),
          if (month.isNotEmpty) ...[
            const SectionTitle('Last 30 Days'),
            IosCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MoodStrip(days: mood.days, today: store.today),
                  const SizedBox(height: 12),
                  Text(
                    '${month.length} ${month.length == 1 ? 'day' : 'days'} '
                    'logged · average ${avg!.toStringAsFixed(1)} of 5',
                    style: context.footnote.copyWith(
                      color: context.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (patterns.isNotEmpty) ...[
            const SectionTitle('Patterns'),
            GroupedSection(
              hasLeading: false,
              footer:
                  'Average mood (1–5) on days with and without each. '
                  'Patterns appear once there are a few days of each.',
              children: [
                for (final p in patterns)
                  InfoRow(
                    title: p.label,
                    value:
                        '${p.withIt.toStringAsFixed(1)} vs '
                        '${p.without.toStringAsFixed(1)}',
                  ),
              ],
            ),
          ],
          if (month.isNotEmpty) ...[
            const SectionTitle('Journal'),
            GroupedSection(
              children: [
                for (final (day, e) in month)
                  InfoRow(
                    leading: Text(e.mood.emoji, style: context.title3),
                    title: formatDay(day, store.today),
                    subtitle: e.tags.isEmpty && e.note.isEmpty
                        ? null
                        : [
                            if (e.tags.isNotEmpty)
                              e.tags.map((t) => t.label).join(', '),
                            if (e.note.isNotEmpty) e.note,
                          ].join(' · '),
                    chevron: true,
                    onTap: () => MoodLogSheet.show(context, day),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Mood against workouts, sleep and steps.
  static List<MoodPattern> _patterns(
    BuildContext context,
    Map<DateTime, MoodEntry> days,
  ) {
    final health = context.read<HealthStore>();
    final workouts = context.read<WorkoutStore>().all;
    final workoutDays = {
      for (final w in workouts)
        DateTime(w.start.year, w.start.month, w.start.day),
    };
    final sleepGoal = health.goals.sleep;
    final stepGoal = health.goals.steps;
    return [
      ?MoodInsights.compare(
        'After a workout',
        days,
        (d) => workoutDays.contains(d),
      ),
      ?MoodInsights.compare('After a full night\'s sleep', days, (d) {
        final h = health.dailyValue(MetricType.sleep, d);
        return h == null ? null : h >= sleepGoal - 0.5;
      }),
      ?MoodInsights.compare('On days you hit your step goal', days, (d) {
        final s = health.dailyValue(MetricType.steps, d);
        return s == null ? null : s >= stepGoal;
      }),
    ];
  }
}

/// A row of dots for the last 30 days, coloured by mood.
class _MoodStrip extends StatelessWidget {
  const _MoodStrip({required this.days, required this.today});

  final Map<DateTime, MoodEntry> days;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final c = context.resolve(moodColor);
    return SizedBox(
      height: 56,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 29; i >= 0; i--)
            Expanded(
              child: Builder(
                builder: (context) {
                  final d = DateTime(today.year, today.month, today.day - i);
                  final m = days[d]?.mood.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: FractionallySizedBox(
                      heightFactor: m == null ? 0.08 : m / 5,
                      alignment: Alignment.bottomCenter,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: m == null
                              ? context.fillColor
                              : c.withValues(alpha: 0.35 + m * 0.13),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// "How are you today?" with five faces; tapping one logs it, and the
/// rest of the entry can be added in a sheet.
class MoodCard extends StatelessWidget {
  const MoodCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MoodStore>();
    final today = context.select<HealthStore, DateTime>((s) => s.today);
    final logged = store.on(today);
    return IosCard(
      onTap: () => MoodLogSheet.show(context, today),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            logged == null ? 'How are you today?' : 'Today you feel',
            style: context.footnote.copyWith(
              color: context.secondaryLabel,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _MoodPicker(
            selected: logged?.mood,
            onPick: (m) {
              HapticFeedback.selectionClick();
              store.log(
                today,
                MoodEntry(
                  mood: m,
                  tags: logged?.tags ?? const {},
                  note: logged?.note ?? '',
                ),
              );
            },
          ),
          if (logged != null && logged.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              logged.tags.map((t) => t.label).join(' · '),
              style: context.caption1.copyWith(color: context.secondaryLabel),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoodPicker extends StatelessWidget {
  const _MoodPicker({required this.selected, required this.onPick});

  final Mood? selected;
  final ValueChanged<Mood> onPick;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final m in Mood.values)
        // Shares the width, shrinking at large text sizes.
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Semantics(
              button: true,
              selected: m == selected,
              label: m.label,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onPick(m),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: m == selected
                            ? context.labelColor
                            : context.fillColor,
                      ),
                      child: Text(
                        m.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m.label,
                      style: context.caption2.copyWith(
                        color: m == selected
                            ? context.labelColor
                            : context.secondaryLabel,
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
}

/// The full journal entry for a day: mood, tags and a note.
class MoodLogSheet extends StatefulWidget {
  const MoodLogSheet({super.key, required this.day, this.controller});

  final DateTime day;
  final ScrollController? controller;

  static Future<void> show(BuildContext context, DateTime day) =>
      showCupertinoSheet<void>(
        context: context,
        scrollableBuilder: (context, controller) =>
            MoodLogSheet(day: day, controller: controller),
      );

  @override
  State<MoodLogSheet> createState() => _MoodLogSheetState();
}

class _MoodLogSheetState extends State<MoodLogSheet> {
  late final MoodEntry? _initial = context.read<MoodStore>().on(widget.day);
  late Mood? _mood = _initial?.mood;
  late final Set<MoodTag> _tags = {...?_initial?.tags};
  late final _note = TextEditingController(text: _initial?.note ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final m = _mood;
    if (m == null) return;
    context.read<MoodStore>().log(
      widget.day,
      MoodEntry(mood: m, tags: _tags, note: _note.text.trim()),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final today = context.read<HealthStore>().today;
    return SheetScaffold(
      title: widget.day == today
          ? 'Today'
          : DateFormat.MMMMEEEEd().format(widget.day),
      controller: widget.controller,
      leading: _initial == null
          ? null
          : SheetAction(
              label: 'Delete',
              onPressed: () {
                context.read<MoodStore>().log(widget.day, null);
                Navigator.of(context).pop();
              },
            ),
      trailing: SheetAction(
        label: 'Save',
        primary: true,
        onPressed: _mood == null ? null : _save,
      ),
      children: [
        IosCard(
          child: _MoodPicker(
            selected: _mood,
            onPick: (m) {
              HapticFeedback.selectionClick();
              setState(() => _mood = m);
            },
          ),
        ),
        const SectionTitle('What Shaped Your Day?'),
        Wrap(
          spacing: 8,
          runSpacing: 0,
          children: [
            for (final t in MoodTag.values)
              AppChip(
                label: t.label,
                selected: _tags.contains(t),
                onTap: () => setState(
                  () => _tags.contains(t) ? _tags.remove(t) : _tags.add(t),
                ),
              ),
          ],
        ),
        const SectionTitle('Note'),
        CupertinoTextField(
          controller: _note,
          placeholder: tr('Anything on your mind?'),
          maxLength: MoodEntry.maxNote,
          maxLines: 5,
          minLines: 3,
          padding: const EdgeInsets.all(14),
          textCapitalization: TextCapitalization.sentences,
          decoration: BoxDecoration(
            color: context.cardBackground,
            borderRadius: context.cardBorderRadius(AppTheme.listRadius),
          ),
        ),
      ],
    );
  }
}
