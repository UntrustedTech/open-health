import 'package:flutter/cupertino.dart' hide Text;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/starter_plans.dart';
import 'package:health_app/models/training_plan.dart';
import 'package:health_app/screens/workouts/routine_editor_screen.dart';
import 'package:health_app/screens/workouts/today_card.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/workout/plan_scheduler.dart';
import 'package:health_app/widgets/app_segmented.dart';

/// Choose routines for each weekday, or a rotation, or load a starter plan.
class PlanEditorScreen extends StatelessWidget {
  const PlanEditorScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(title: 'Plan', builder: (_) => const PlanEditorScreen()),
  );

  Future<String?> _chooseRoutine(
    BuildContext context, {
    bool allowRest = true,
  }) {
    final routines = context.read<WorkoutStore>().routines;
    return showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Choose a Routine'),
        actions: [
          if (allowRest)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('Rest Day'),
            ),
          for (final r in routines)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, r.id),
              child: Text(r.name),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _applyStarter(BuildContext context, StarterPlan starter) async {
    final store = context.read<WorkoutStore>();
    final replace = !store.plan.isEmpty;
    if (replace) {
      final ok = await confirmDestructive(
        context,
        title: 'Use ${starter.name}?',
        message: 'This replaces your current schedule. Your routines are kept.',
        action: 'Use This Plan',
      );
      if (!ok) return;
    }
    await store.applyStarter(starter);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkoutStore>();
    final plan = store.plan;
    String routineName(String? id) => store.routineById(id)?.name ?? 'Rest';
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Training Plan'),
      ),
      child: PageList(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.margin,
          12,
          AppTheme.margin,
          32,
        ),
        children: [
          AppSegmented<PlanMode>(
            groupValue: plan.mode,
            children: {for (final e in planModes.entries) e.key: Text(e.value)},
            onValueChanged: (m) {
              if (m != null) store.setPlan(plan.copyWith(mode: m));
            },
          ),
          const SizedBox(height: 6),
          Text(
            plan.mode == PlanMode.weekday
                ? 'A routine on fixed days of the week.'
                : 'Routines in order. The next one is whichever comes after the last you did, however your week went.',
            style: context.footnote.copyWith(color: context.secondaryLabel),
          ),
          if (plan.mode == PlanMode.weekday)
            GroupedSection(
              header: 'Week',
              hasLeading: false,
              children: [
                for (final d in weekOrder(plan.weekStart))
                  InfoRow(
                    title: DateFormat.EEEE().format(DateTime(2026, 10, 4 + d)),
                    value: routineName(plan.days[d]),
                    chevron: true,
                    onTap: () async {
                      final id = await _chooseRoutine(context);
                      if (id == null) return;
                      final days = {...plan.days};
                      if (id.isEmpty) {
                        days.remove(d);
                      } else {
                        days[d] = id;
                      }
                      await store.setPlan(plan.copyWith(days: days));
                    },
                  ),
              ],
            )
          else
            GroupedSection(
              header: 'Rotation',
              footer: 'Swipe left to remove.',
              hasLeading: false,
              children: [
                for (final (i, id) in plan.rotation.indexed)
                  Dismissible(
                    key: ValueKey('$i-$id'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: context.destructive,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child: const Text(
                        'Remove',
                        style: TextStyle(color: CupertinoColors.white),
                      ),
                    ),
                    onDismissed: (_) => store.setPlan(
                      plan.copyWith(rotation: [...plan.rotation]..removeAt(i)),
                    ),
                    child: InfoRow(
                      title:
                          '${String.fromCharCode(65 + i % 26)}.  ${routineName(id)}',
                    ),
                  ),
                InfoRow(
                  title: 'Add Routine',
                  titleColor: context.tint,
                  onTap: () async {
                    final id = await _chooseRoutine(context, allowRest: false);
                    if (id == null || id.isEmpty) return;
                    await store.setPlan(
                      plan.copyWith(rotation: [...plan.rotation, id]),
                    );
                  },
                ),
              ],
            ),
          GroupedSection(
            hasLeading: false,
            children: [
              CupertinoListTile(
                title: const Text('Week Starts On'),
                trailing: AppSegmented<int>(
                  groupValue: plan.weekStart,
                  children: const {
                    DateTime.monday: Text('Mon'),
                    DateTime.sunday: Text('Sun'),
                  },
                  onValueChanged: (v) {
                    if (v != null) store.setPlan(plan.copyWith(weekStart: v));
                  },
                ),
              ),
              InfoRow(
                title: 'New Routine',
                titleColor: context.tint,
                onTap: () => RoutineEditorScreen.open(context),
              ),
            ],
          ),
          GroupedSection(
            header: 'Starter Plans',
            footer:
                'Starter plans add editable routines and fill in your week.',
            hasLeading: false,
            children: [
              for (final s in StarterPlan.all)
                CupertinoListTile(
                  title: Text(s.name),
                  subtitle: Text(s.summary, maxLines: 2),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _applyStarter(context, s),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
