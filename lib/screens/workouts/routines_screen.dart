import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/exercise_library.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/screens/workouts/routine_editor_screen.dart';
import 'package:health_app/screens/workouts/workout_launcher.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';

/// Every routine: tap one to start it, or make a new one.
class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(title: 'Routines', builder: (_) => const RoutinesScreen()),
  );

  @override
  Widget build(BuildContext context) {
    final routines = context.watch<WorkoutStore>().routines;
    final mine = [
      for (final r in routines)
        if (!r.builtIn) r,
    ];
    final presets = [
      for (final r in routines)
        if (r.builtIn) r,
    ];
    return LargeTitlePage(
      title: 'Routines',
      trailing: HeaderButton(
        icon: Icons.add_rounded,
        semanticLabel: tr('New Routine'),
        onTap: () => RoutineEditorScreen.open(context),
      ),
      children: [
        if (mine.isNotEmpty)
          GroupedSection(
            header: 'My Routines',
            children: [for (final r in mine) _RoutineRow(routine: r)],
          ),
        GroupedSection(
          header: 'Ready-Made',
          footer: 'Tap a routine to start it.',
          children: [for (final r in presets) _RoutineRow(routine: r)],
        ),
      ],
    );
  }
}

class _RoutineRow extends StatelessWidget {
  const _RoutineRow({required this.routine});

  final Routine routine;

  @override
  Widget build(BuildContext context) {
    final r = routine;
    return CupertinoListTile(
      leading: IconTile(
        icon: WorkoutType.strength.icon,
        color: WorkoutType.strength.color,
      ),
      title: Text(r.name),
      subtitle: Text(
        r.items.map((i) => ExerciseLibrary.nameOf(i.exerciseId)).join(', '),
      ),
      trailing: r.builtIn
          ? const CupertinoListTileChevron()
          : CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size.square(AppTheme.minTapTarget),
              onPressed: () => RoutineEditorScreen.open(context, routine: r),
              child: Icon(
                Icons.edit_rounded,
                size: 20,
                color: context.secondaryLabel,
                semanticLabel: tr('Edit routine'),
              ),
            ),
      onTap: () => WorkoutLauncher.start(
        context,
        type: WorkoutType.strength,
        routine: r,
      ),
    );
  }
}
