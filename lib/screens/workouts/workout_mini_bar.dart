import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/screens/workouts/active_workout.dart';
import 'package:health_app/screens/workouts/live_workout_screen.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/workout/workout_tracker.dart';

/// A minimized workout, floating above the tab bar as Apple Music's mini
/// player does: what it is, its time, pause, and a tap to bring it back.
class WorkoutMiniBar extends StatelessWidget {
  const WorkoutMiniBar({super.key});

  static const height = 64.0;

  @override
  Widget build(BuildContext context) {
    final active = ActiveWorkout.instance;
    final t = active.tracker;
    if (t == null || !active.minimized) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: t,
      builder: (context, _) {
        final paused = t.status == TrackerStatus.paused;
        final color = context.resolve(t.type.color);
        final time = formatClock(t.elapsed);
        return Semantics(
          button: true,
          label:
              '${tr(t.type.label)}, $time${paused ? ', ${tr('Paused')}' : ''}. '
              '${tr('Open workout')}',
          excludeSemantics: true,
          onTap: () => LiveWorkoutScreen.reopen(context),
          child: Pressable(
            onTap: () => LiveWorkoutScreen.reopen(context),
            child: Container(
              height: height,
              padding: const EdgeInsets.only(left: 10, right: 4),
              decoration: ShapeDecoration(
                color: context.cardRaised,
                shape: AppTheme.squircle(20),
                shadows: [
                  BoxShadow(
                    color: const Color(0x33000000),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconTile(icon: t.type.icon, color: t.type.color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.type.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.subheadline.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          paused ? 'Paused' : 'Recording',
                          style: context.caption1.copyWith(
                            color: paused
                                ? context.resolve(Palette.yellow)
                                : context.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    time,
                    style: context
                        .number(22, weight: FontWeight.w700)
                        .copyWith(color: color),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size.square(AppTheme.minTapTarget),
                    onPressed: active.togglePause,
                    child: Icon(
                      paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 28,
                      color: context.labelColor,
                      semanticLabel: tr(paused ? 'Resume' : 'Pause'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
