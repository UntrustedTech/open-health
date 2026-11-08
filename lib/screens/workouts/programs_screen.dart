import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/workout_program.dart';
import 'package:health_app/screens/readiness/suggestions.dart';
import 'package:health_app/state/program_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';

/// Multi-week workout programs: pick one, follow it week by week.
class ProgramsScreen extends StatelessWidget {
  const ProgramsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    AppRoute<void>(title: 'Programs', builder: (_) => const ProgramsScreen()),
  );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ProgramStore>();
    final current = store.program;
    return CupertinoPageScaffold(
      backgroundColor: context.groupedBackground,
      navigationBar: const CupertinoNavigationBar(middle: Text('Programs')),
      child: PageList(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.margin,
          12,
          AppTheme.margin,
          32,
        ),
        children: [
          if (current != null) ...[
            const ProgramCard(),
            const SizedBox(height: 4),
            _Weeks(progress: store.progress!),
            CupertinoButton(
              onPressed: () async {
                final ok = await confirmDestructive(
                  context,
                  message:
                      'Stop ${current.name}? Your workouts are kept; '
                      'progress starts over if you begin it again.',
                  action: 'Stop Program',
                );
                if (ok) await store.stop();
              },
              child: Text(
                'Stop Program',
                style: context.body.copyWith(color: context.destructive),
              ),
            ),
          ],
          SectionTitle(current == null ? 'Choose a Program' : 'All Programs'),
          for (final p in WorkoutProgram.all)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ProgramOption(program: p, current: p == current),
            ),
        ],
      ),
    );
  }
}

class _ProgramOption extends StatelessWidget {
  const _ProgramOption({required this.program, required this.current});

  final WorkoutProgram program;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final store = context.read<ProgramStore>();
    return IosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(
                icon: program.type.icon,
                color: program.type.color,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(program.name, style: context.headline),
                    Text(
                      '${program.weeks.length} weeks · '
                      '${program.sessionsPerWeek} sessions a week',
                      style: context.footnote.copyWith(
                        color: context.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            program.summary,
            style: context.subheadline.copyWith(color: context.secondaryLabel),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: current ? null : context.fillColor,
              borderRadius: BorderRadius.circular(12),
              padding: const EdgeInsets.symmetric(vertical: 10),
              onPressed: current
                  ? null
                  : () async {
                      if (store.program != null) {
                        final ok = await confirmDestructive(
                          context,
                          message:
                              'Switch to ${program.name}? '
                              '${store.program!.name} will stop.',
                          action: 'Switch Program',
                        );
                        if (!ok) return;
                      }
                      await store.start(program);
                    },
              child: Text(
                current ? 'Following' : 'Start Program',
                style: context.subheadline.copyWith(
                  color: current ? context.secondaryLabel : context.labelColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Every week of the program with each session's state.
class _Weeks extends StatelessWidget {
  const _Weeks({required this.progress});

  final ProgramProgress progress;

  @override
  Widget build(BuildContext context) {
    var index = 0;
    final green = context.resolve(Palette.green);
    return GroupedSection(
      children: [
        for (final (w, week) in progress.program.weeks.indexed)
          for (final (i, s) in week.indexed)
            Builder(
              builder: (context) {
                final n = index++;
                final done = n < progress.completed;
                final isNext = n == progress.completed;
                return InfoRow(
                  leading: Icon(
                    done
                        ? Icons.check_circle_rounded
                        : isNext
                        ? Icons.play_circle_rounded
                        : Icons.circle_outlined,
                    color: done
                        ? green
                        : isNext
                        ? context.labelColor
                        : context.tertiaryLabel,
                  ),
                  title: 'Week ${w + 1} · Session ${i + 1}',
                  subtitle: [
                    s.title,
                    if (s.minutes case final m?) '$m min',
                  ].join(' · '),
                  value: done
                      ? DateFormat.MMMd().format(progress.done[n].start)
                      : null,
                );
              },
            ),
      ],
    );
  }
}

/// The current program on Fitness: this week, overall progress and the
/// next session. Offers to choose one when none is running.
class ProgramCard extends StatelessWidget {
  const ProgramCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ProgramStore>();
    final progress = store.progress;
    if (progress == null) {
      return IosCard(
        onTap: () => ProgramsScreen.open(context),
        child: Row(
          children: [
            const IconTile(
              icon: Icons.flag_circle_rounded,
              color: Palette.mint,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Follow a Program', style: context.headline),
                  Text(
                    'Couch to 5K, Beginner Strength or Mobility & Core.',
                    style: context.footnote.copyWith(
                      color: context.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.tertiaryLabel),
          ],
        ),
      );
    }
    final p = progress.program;
    final next = progress.next;
    final week = p.weeks[progress.week];
    final color = context.resolve(p.type.color);
    return IosCard(
      onTap: () => ProgramsScreen.open(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.name,
                  style: context.footnote.copyWith(
                    color: context.secondaryLabel,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${progress.completed} of ${p.sessionCount} sessions',
                style: context.footnote.copyWith(color: context.secondaryLabel),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            progress.finished
                ? 'Program complete'
                : 'Week ${progress.week + 1} of ${p.weeks.length}',
            style: context.title3,
          ),
          const SizedBox(height: 10),
          CapsuleProgress(value: progress.fraction, color: color, height: 6),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < week.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: i < progress.doneThisWeek
                          ? color
                          : context.fillColor,
                    ),
                    child: Text(
                      'Session ${i + 1}',
                      style: context.caption1.copyWith(
                        fontWeight: FontWeight.w600,
                        color: i < progress.doneThisWeek
                            ? context.onColor(color)
                            : context.secondaryLabel,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (next != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next',
                        style: context.caption1.copyWith(
                          color: context.secondaryLabel,
                        ),
                      ),
                      Text(
                        [
                          next.title,
                          if (next.minutes case final m?) '$m min',
                        ].join(' · '),
                        style: context.subheadline.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: const Size(0, AppTheme.minTapTarget),
                  color: context.labelColor,
                  borderRadius: BorderRadius.circular(
                    AppTheme.minTapTarget / 2,
                  ),
                  onPressed: () =>
                      WorkoutSuggestion.session(next, p.name).start(context),
                  child: Text(
                    'Start',
                    style: context.footnote.copyWith(
                      color: context.onLabel,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
