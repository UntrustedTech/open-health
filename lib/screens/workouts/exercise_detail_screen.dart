import 'package:flutter/cupertino.dart' hide Text;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/screens/workouts/custom_exercise_sheet.dart'
    show capitalize;
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/exercise_catalog.dart';
import 'package:health_app/models/muscles.dart';
import 'package:health_app/screens/workouts/workout_insights.dart'
    show BodyMapPair;
import 'package:health_app/state/exercise_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/exercise_clip.dart';
import 'package:health_app/widgets/exercise_figure.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/utils/units.dart';

/// One exercise: muscles worked, how to do it, and your history with it.
class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final String exerciseId;

  static Future<void> open(BuildContext context, String id) =>
      Navigator.of(context).push(
        AppRoute<void>(
          title: ExerciseCatalog.instance.nameOf(id),
          builder: (_) => ExerciseDetailScreen(exerciseId: id),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ExerciseStore>();
    final e = store.catalog.byId(exerciseId);
    if (e == null) {
      return const CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text('Exercise')),
        child: Center(child: Text('This exercise was removed.')),
      );
    }
    final intensity = {
      for (final m in e.secondaryMuscles) m: 0.4,
      for (final m in e.primaryMuscles) m: 1.0,
    };
    return CupertinoPageScaffold(
      // The large title below names the exercise.
      navigationBar: const CupertinoNavigationBar(),
      child: PageList(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.margin,
          12,
          AppTheme.margin,
          32,
        ),
        children: [
          Appear(child: ExerciseDemo(exerciseId: exerciseId)),
          const SizedBox(height: 18),
          Appear(index: 1, child: Text(e.name, style: context.title1)),
          const SizedBox(height: 14),
          Appear(
            index: 1,
            child: Wrap(
              spacing: 26,
              runSpacing: 12,
              children: [
                _Fact(
                  label: 'Primary',
                  value: e.primaryMuscles.isEmpty
                      ? capitalize(e.target)
                      : e.primaryMuscles.map((m) => m.label).join(', '),
                ),
                if (e.secondaryMuscles.isNotEmpty)
                  _Fact(
                    label: 'Secondary',
                    value: e.secondaryMuscles.map((m) => m.label).join(', '),
                  ),
                _Fact(label: 'Equipment', value: capitalize(e.equipment)),
              ],
            ),
          ),
          if (e.timed || e.perSide || e.custom) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final t in [
                  if (e.timed) 'Timed',
                  if (e.perSide) 'Each Side',
                  if (e.custom) 'My Exercise',
                ])
                  _Tag(text: t),
              ],
            ),
          ],
          if (e.steps.isNotEmpty) ExerciseSteps(steps: e.steps),
          const SizedBox(height: 12),
          Appear(
            index: 1,
            child: IosCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BodyMapPair(height: 260, intensity: intensity),
                  const SizedBox(height: 12),
                  _MuscleLine(
                    label: 'Primary',
                    muscles: e.primaryMuscles,
                    strong: true,
                  ),
                  if (e.secondaryMuscles.isNotEmpty)
                    _MuscleLine(
                      label: 'Also works',
                      muscles: e.secondaryMuscles,
                    ),
                ],
              ),
            ),
          ),
          const _History(),
          if (e.custom)
            GroupedSection(
              hasLeading: false,
              footer: 'Workouts that used it keep their data.',
              children: [
                InfoRow(
                  title: 'Delete Exercise',
                  titleColor: context.destructive,
                  onTap: () async {
                    final ok = await confirmDestructive(
                      context,
                      message: 'Delete "${e.name}" from your exercises?',
                      action: 'Delete Exercise',
                    );
                    if (!ok || !context.mounted) return;
                    await context.read<ExerciseStore>().deleteCustom(e.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Personal best and last session for this exercise.
class _History extends StatelessWidget {
  const _History();

  @override
  Widget build(BuildContext context) {
    final screen = context
        .findAncestorWidgetOfExactType<ExerciseDetailScreen>()!;
    final workouts = context.watch<WorkoutStore>();
    final id = ExerciseCatalog.canonical(screen.exerciseId);
    final best = workouts.records.bestLifts[id];
    final last = workouts.previousSets(id).where((s) => s.done).toList();
    final sessions = workouts.all
        .where(
          (w) => w.exercises.any(
            (e) => ExerciseCatalog.canonical(e.exerciseId) == id,
          ),
        )
        .length;
    if (best == null && last.isEmpty) return const SizedBox.shrink();
    return GroupedSection(
      header: 'Your History',
      hasLeading: false,
      children: [
        if (best != null) ...[
          InfoRow(
            title: 'Best Set',
            value: '${Units.weight(best.weightKg)} × ${best.reps}',
          ),
          InfoRow(
            title: 'Estimated 1RM',
            value: Units.weight(best.estimatedOneRepMax, decimals: 0),
          ),
          InfoRow(
            title: 'Best On',
            value: DateFormat.yMMMd().format(best.date),
          ),
        ],
        if (last.isNotEmpty)
          InfoRow(
            title: 'Last Time',
            value: last
                .map((s) => '${Units.weight(s.weightKg)}×${s.reps}')
                .join(', '),
          ),
        InfoRow(title: 'Sessions', value: '$sessions'),
      ],
    );
  }
}

class _MuscleLine extends StatelessWidget {
  const _MuscleLine({
    required this.label,
    required this.muscles,
    this.strong = false,
  });

  final String label;
  final List<Muscle> muscles;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    if (muscles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5, right: 8),
            decoration: BoxDecoration(
              color: context.tint.withValues(alpha: strong ? 1 : 0.45),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: context.subheadline.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: muscles.map((m) => m.label).join(', '),
                    style: context.subheadline,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled fact under the exercise's name ("PRIMARY · Shoulders").
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label.toUpperCase(),
        style: context.caption1.copyWith(
          color: context.tertiaryLabel,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 3),
      Text(value, style: context.body),
    ],
  );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(
        color: context.fillColor,
        shape: AppTheme.squircle(10),
      ),
      child: Text(
        text,
        style: context.footnote.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
