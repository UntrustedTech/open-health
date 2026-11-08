import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/insights/readiness.dart';
import 'package:health_app/models/exercise_library.dart';
import 'package:health_app/models/workout.dart';
import 'package:health_app/models/workout_program.dart';
import 'package:health_app/screens/readiness/readiness_screen.dart';
import 'package:health_app/screens/workouts/workout_launcher.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/program_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/workout/intervals.dart';

/// A workout that suits today.
@immutable
class WorkoutSuggestion {
  const WorkoutSuggestion({
    required this.title,
    required this.detail,
    required this.type,
    this.program,
    this.routine,
  });

  WorkoutSuggestion.session(ProgramSession s, String programName)
    : title = s.title,
      detail = 'Next in $programName',
      type = s.type,
      program = s.interval,
      routine = s.routine;

  final String title;
  final String detail;
  final WorkoutType type;
  final IntervalProgram? program;
  final Routine? routine;

  Future<void> start(BuildContext context) {
    if (program == null && routine == null) {
      return WorkoutLauncher.showSetup(context, type);
    }
    return WorkoutLauncher.start(
      context,
      type: type,
      program: program,
      routine: routine,
    );
  }

  static IntervalProgram _named(String name) =>
      IntervalProgram.presets.firstWhere((p) => p.name == name);

  static Routine _routine(String id) =>
      Routine.presets.firstWhere((r) => r.id == id);

  /// Workouts for [level] (unknown when null), leading with the next
  /// program session unless today calls for rest.
  static List<WorkoutSuggestion> forToday(
    ReadinessLevel? level,
    ProgramProgress? progress,
  ) {
    final next = progress?.next;
    final fromProgram = next == null
        ? null
        : WorkoutSuggestion.session(next, progress!.program.name);
    final easy = [
      WorkoutSuggestion(
        title: 'Morning Mobility',
        detail: 'Gentle stretches to help you recover',
        type: WorkoutType.stretching,
        program: _named('Morning Mobility'),
      ),
      const WorkoutSuggestion(
        title: 'Easy Walk',
        detail: 'Low effort keeps you moving',
        type: WorkoutType.walk,
      ),
      WorkoutSuggestion(
        title: 'Tai Chi Basics',
        detail: 'Slow, calming movement',
        type: WorkoutType.taiChi,
        program: _named('Tai Chi Basics'),
      ),
    ];
    return switch (level) {
      ReadinessLevel.rest => easy,
      ReadinessLevel.steady => [
        ?fromProgram,
        const WorkoutSuggestion(
          title: 'Easy Run',
          detail: 'A conversational pace',
          type: WorkoutType.run,
        ),
        WorkoutSuggestion(
          title: 'Pilates Core 15',
          detail: 'Moderate core work',
          type: WorkoutType.pilates,
          program: _named('Pilates Core 15'),
        ),
        const WorkoutSuggestion(
          title: 'Outdoor Cycle',
          detail: 'Steady endurance',
          type: WorkoutType.cycle,
        ),
      ],
      ReadinessLevel.ready => [
        ?fromProgram,
        WorkoutSuggestion(
          title: 'Tabata',
          detail: 'Short and intense intervals',
          type: WorkoutType.hiit,
          program: _named('Tabata'),
        ),
        WorkoutSuggestion(
          title: 'Full Body',
          detail: 'A strength session',
          type: WorkoutType.strength,
          routine: _routine('preset_full'),
        ),
        const WorkoutSuggestion(
          title: 'Outdoor Run',
          detail: 'Push the pace',
          type: WorkoutType.run,
        ),
      ],
      null => [?fromProgram, ...easy.take(2)],
    };
  }
}

List<WorkoutSuggestion> _today(BuildContext context) {
  final r = readinessOf(context.watch<HealthStore>());
  final program = context.watch<ProgramStore>().progress;
  return WorkoutSuggestion.forToday(r?.level, program);
}

/// Every suggestion for today, as a list with Start buttons.
class SuggestionList extends StatelessWidget {
  const SuggestionList({super.key});

  @override
  Widget build(BuildContext context) => GroupedSection(
    children: [
      for (final s in _today(context))
        InfoRow(
          leading: IconTile(icon: s.type.icon, color: s.type.color),
          title: s.title,
          subtitle: s.detail,
          trailing: _StartButton(onTap: () => s.start(context)),
        ),
    ],
  );
}

/// Fitness: today's best workout given readiness and any program.
class SuggestionCard extends StatelessWidget {
  const SuggestionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final r = readinessOf(context.watch<HealthStore>());
    final list = _today(context);
    final top = list.first;
    final level = r?.level;
    final color = level == null
        ? context.secondaryLabel
        : context.resolve(readinessColor(level));
    return IosCard(
      onTap: () => ReadinessScreen.open(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  level == null
                      ? 'Suggested Today'
                      : 'Readiness ${r!.score} · ${level.label}',
                  style: context.footnote.copyWith(
                    color: context.secondaryLabel,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: context.tertiaryLabel,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconTile(icon: top.type.icon, color: top.type.color, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(top.title, style: context.headline),
                    Text(
                      level == ReadinessLevel.rest
                          ? 'Recovery day. ${top.detail}.'
                          : top.detail,
                      style: context.footnote.copyWith(
                        color: context.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              _StartButton(onTap: () => top.start(context)),
            ],
          ),
          if (list.length > 1) ...[
            const SizedBox(height: 10),
            Text(
              'Also good: ${list.skip(1).map((s) => s.title).join(', ')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.caption1.copyWith(color: context.secondaryLabel),
            ),
          ],
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onTap});

  final VoidCallback onTap;

  /// A secondary pill (several can share a list), drawn 34 tall inside a
  /// full-size tap target.
  @override
  Widget build(BuildContext context) => Pressable(
    semanticLabel: tr('Start'),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: context.fillColor,
          shape: const StadiumBorder(),
        ),
        child: Text(
          'Start',
          style: context.footnote.copyWith(
            color: context.labelColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}
