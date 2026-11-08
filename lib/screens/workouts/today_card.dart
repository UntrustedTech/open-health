import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/exercise_library.dart';
import 'package:health_app/models/training_plan.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/screens/workouts/plan_editor_screen.dart';
import 'package:health_app/screens/workouts/workout_launcher.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/workout/plan_scheduler.dart';

/// Today's planned workout with a Start button, plus this week at a glance.
class TodayCard extends StatelessWidget {
  const TodayCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkoutStore>();
    final plan = store.plan;
    if (plan.isEmpty) return const _SetUpCard();
    final today = store.todaySession();
    final routine = store.routineById(today.routineId);
    final next = store.nextPlanned();
    final color = WorkoutType.strength.color;

    final String title;
    final String subtitle;
    if (routine != null && !today.done) {
      title = routine.name;
      subtitle = routine.items
          .map((i) => ExerciseLibrary.nameOf(i.exerciseId))
          .join(', ');
    } else {
      title = today.done ? 'Done for Today' : 'Rest Day';
      final nextRoutine = store.routineById(next?.routineId);
      subtitle = next == null || nextRoutine == null
          ? 'Nothing else planned yet.'
          : 'Next: ${nextRoutine.name}, ${_when(next.date, store.today)}';
    }

    return IosCard(
      onTap: () => PlanEditorScreen.open(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'TODAY',
                style: context.caption1.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (routine != null && !today.done)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size.square(AppTheme.minTapTarget),
                  onPressed: () => _move(context, today),
                  child: Text(
                    'Move',
                    style: context.subheadline.copyWith(color: context.tint),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (today.done)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.verified_rounded,
                    color: context.resolve(Palette.green),
                    semanticLabel: tr('Done'),
                  ),
                ),
              Expanded(child: Text(title, style: context.title2)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.subheadline.copyWith(color: context.secondaryLabel),
          ),
          if (routine != null && !today.done) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: () => WorkoutLauncher.start(
                  context,
                  type: WorkoutType.strength,
                  routine: routine,
                ),
                child: const Text('Start Workout'),
              ),
            ),
          ],
          const SizedBox(height: 14),
          _WeekStrip(store: store),
        ],
      ),
    );
  }

  static String _when(DateTime date, DateTime today) {
    // UTC dates: a daylight-saving day is 23 or 25 hours long locally.
    final days = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    if (days == 0) return 'today';
    if (days == 1) return 'tomorrow';
    return DateFormat.EEEE().format(date);
  }

  /// Moves today's session to another day this week.
  static Future<void> _move(BuildContext context, PlannedDay today) async {
    final store = context.read<WorkoutStore>();
    final base = store.today;
    final options = [
      for (var i = 1; i <= 6; i++)
        DateTime(base.year, base.month, base.day + i),
    ];
    final picked = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Move today\'s workout to'),
        actions: [
          for (final d in options)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, d),
              child: Text(DateFormat.MMMEd().format(d)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (picked == null) return;
    await store.setPlan(
      store.plan.moveSession(
        from: today.date,
        to: picked,
        routineId: today.routineId,
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.store});

  final WorkoutStore store;

  @override
  Widget build(BuildContext context) {
    final today = store.today;
    final order = weekOrder(store.plan.weekStart);
    final offset = order.indexOf(today.weekday);
    final start = DateTime(today.year, today.month, today.day - offset);
    final green = context.resolve(Palette.green);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 7; i++)
          () {
            final day = DateTime(start.year, start.month, start.day + i);
            final p = store.plannedOn(day);
            final isToday = i == offset;
            final past = day.isBefore(
              DateTime(today.year, today.month, today.day),
            );
            final color = p.done
                ? green
                : p.isRest
                ? context.fillColor
                : context.tint.withValues(alpha: past ? 0.35 : 1);
            return Semantics(
              label:
                  '${DateFormat.EEEE().format(day)}: '
                  '${p.done
                      ? 'done'
                      : p.isRest
                      ? 'rest'
                      : store.routineById(p.routineId)?.name ?? 'workout'}',
              excludeSemantics: true,
              child: Column(
                children: [
                  Text(
                    DateFormat('EEEEE').format(day),
                    style: context.caption1.copyWith(
                      color: isToday
                          ? context.labelColor
                          : context.secondaryLabel,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.isRest && !p.done ? null : color,
                      border: Border.all(
                        color: isToday
                            ? context.labelColor
                            : const Color(0x00000000),
                        width: 1.5,
                      ),
                    ),
                    child: p.done
                        ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: CupertinoColors.white,
                          )
                        : p.isRest
                        ? Center(
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: context.tertiaryLabel,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            );
          }(),
      ],
    );
  }
}

class _SetUpCard extends StatelessWidget {
  const _SetUpCard();

  @override
  Widget build(BuildContext context) {
    return IosCard(
      onTap: () => PlanEditorScreen.open(context),
      child: Row(
        children: [
          const IconTile(
            icon: Icons.calendar_month_rounded,
            color: Palette.orange,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Plan Your Week', style: context.headline),
                Text(
                  'Pick a starter plan or schedule your own routines.',
                  style: context.footnote.copyWith(
                    color: context.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 14,
            color: context.tertiaryLabel,
          ),
        ],
      ),
    );
  }
}

/// Exposed for the plan editor.
const planModes = {PlanMode.weekday: 'Weekly', PlanMode.rotation: 'Rotation'};
