import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/screens/habits/habit_look_sheet.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/mood_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/app_route.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/widgets/progress_ring.dart';

/// Daily habits to tick off, each with its streak and last month.
class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(AppRoute<void>(title: 'Habits', builder: (_) => const HabitsScreen()));

  static const suggestions = [
    'Drink water',
    'Walk 10 minutes',
    'Read',
    'Stretch',
    'No phone in bed',
  ];

  static Future<void> add(BuildContext context, [String? name]) async {
    final mood = context.read<MoodStore>();
    final n =
        name ?? await _askName(context, title: 'New Habit', confirm: 'Add');
    if (n == null || n.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    if (!await mood.addHabit(n) && context.mounted) {
      await _alreadyThere(context, n);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mood = context.watch<MoodStore>();
    final habits = mood.habits;
    return CupertinoPageScaffold(
      backgroundColor: context.groupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Habits'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(AppTheme.minTapTarget),
          onPressed: () => add(context),
          child: Icon(CupertinoIcons.add, semanticLabel: tr('Add Habit')),
        ),
      ),
      child: PageList(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.margin,
          12,
          AppTheme.margin,
          32,
        ),
        children: [
          if (habits.isEmpty)
            const _Start()
          else ...[
            const _Today(),
            const SizedBox(height: 12),
            for (final h in habits)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HabitCard(habit: h),
              ),
            Text(
              'Tap the circle to tick a habit off, or a day in its strip to '
              'change that day. Touch and hold a habit to rename it, change '
              'its icon, move it or remove it.',
              style: context.footnote.copyWith(color: context.secondaryLabel),
            ),
          ],
        ],
      ),
    );
  }
}

/// Icons a habit can have, by the name saved for it, with a spoken label.
const habitIcons = <String, (IconData, String)>{
  'task': (Icons.task_alt_rounded, 'Tick'),
  'water': (Icons.water_drop_rounded, 'Water'),
  'run': (Icons.directions_run_rounded, 'Running'),
  'walk': (Icons.directions_walk_rounded, 'Walking'),
  'bike': (Icons.directions_bike_rounded, 'Cycling'),
  'swim': (Icons.pool_rounded, 'Swimming'),
  'gym': (Icons.fitness_center_rounded, 'Weights'),
  'stretch': (Icons.self_improvement_rounded, 'Stretching'),
  'calm': (Icons.spa_rounded, 'Calm'),
  'sleep': (Icons.bedtime_rounded, 'Sleep'),
  'read': (Icons.menu_book_rounded, 'Reading'),
  'journal': (Icons.edit_note_rounded, 'Journal'),
  'food': (Icons.restaurant_rounded, 'Food'),
  'fruit': (Icons.eco_rounded, 'Plants'),
  'no_drink': (Icons.no_drinks_rounded, 'No Drinks'),
  'no_smoke': (Icons.smoke_free_rounded, 'No Smoking'),
  'pill': (Icons.medication_rounded, 'Medicine'),
  'teeth': (Icons.clean_hands_rounded, 'Hygiene'),
  'sun': (Icons.wb_sunny_rounded, 'Outdoors'),
  'music': (Icons.music_note_rounded, 'Music'),
  'learn': (Icons.school_rounded, 'Learning'),
  'money': (Icons.savings_rounded, 'Saving'),
  'pet': (Icons.pets_rounded, 'Pets'),
  'heart': (Icons.favorite_rounded, 'Heart'),
};

/// Colours a habit can have, by the name saved for it.
const habitColors = <String, (Color, String)>{
  'green': (Palette.green, 'Green'),
  'teal': (Palette.teal, 'Teal'),
  'cyan': (Palette.cyan, 'Cyan'),
  'blue': (Palette.blue, 'Blue'),
  'iris': (Palette.iris, 'Iris'),
  'purple': (Palette.purple, 'Purple'),
  'pink': (Palette.pink, 'Pink'),
  'red': (Palette.red, 'Red'),
  'orange': (Palette.orange, 'Orange'),
  'yellow': (Palette.yellow, 'Yellow'),
};

/// A habit's icon and colour names: the ones chosen in [chosen], else an
/// icon guessed from its name and a colour of its own.
/// shortcut: the guess matches English words only; the picker covers others.
({String icon, String color}) habitLookNames(
  String habit, [
  ({String? icon, String? color}) chosen = (icon: null, color: null),
]) {
  final n = habit.toLowerCase();
  bool has(List<String> words) => words.any(n.contains);
  final guess = has(['water', 'drink', 'hydrat'])
      ? 'water'
      : has(['run', 'jog'])
      ? 'run'
      : has(['walk', 'step'])
      ? 'walk'
      : has(['read', 'book'])
      ? 'read'
      : has(['stretch', 'yoga'])
      ? 'stretch'
      : has(['meditat', 'breath', 'calm'])
      ? 'calm'
      : has(['sleep', 'bed', 'phone', 'screen'])
      ? 'sleep'
      : has(['gym', 'lift', 'workout', 'push', 'squat'])
      ? 'gym'
      : has(['sugar', 'eat', 'fruit', 'veg', 'cook', 'meal', 'snack'])
      ? 'food'
      : has(['journal', 'write', 'gratitude'])
      ? 'journal'
      : has(['sun', 'outside', 'outdoor'])
      ? 'sun'
      : 'task';
  const auto = ['green', 'teal', 'cyan', 'iris', 'orange', 'pink'];
  // Summed rather than hashCode, so a habit keeps its colour between runs.
  final sum = habit.codeUnits.fold(0, (a, b) => a + b);
  return (
    icon: habitIcons.containsKey(chosen.icon) ? chosen.icon! : guess,
    color: habitColors.containsKey(chosen.color)
        ? chosen.color!
        : auto[sum % auto.length],
  );
}

({IconData icon, Color color}) habitLook(
  String habit, [
  ({String? icon, String? color}) chosen = (icon: null, color: null),
]) {
  final names = habitLookNames(habit, chosen);
  return (
    icon: habitIcons[names.icon]!.$1,
    color: habitColors[names.color]!.$1,
  );
}

/// Today's progress across every habit.
class _Today extends StatelessWidget {
  const _Today();

  @override
  Widget build(BuildContext context) {
    final mood = context.watch<MoodStore>();
    final today = context.watch<HealthStore>().today;
    final all = mood.habits;
    final done = all.where((h) => mood.didHabit(h, today)).length;
    final streak = all.map(mood.streak).fold(0, (a, b) => a > b ? a : b);
    final green = context.resolve(Palette.green);
    return IosCard(
      child: Row(
        children: [
          ProgressRing(
            progress: done / all.length,
            color: Palette.green,
            size: 84,
            stroke: 9,
            child: Text(
              '$done/${all.length}',
              style: context.title3.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  done == all.length
                      ? 'All done today'
                      : '$done of ${all.length} done today',
                  style: context.headline,
                ),
                if (streak > 0)
                  Text(
                    streak == 1
                        ? 'Longest streak: 1 day'
                        : 'Longest streak: $streak days',
                    style: context.subheadline.copyWith(color: green),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// No habits yet: a line on what they are and some to start with.
class _Start extends StatelessWidget {
  const _Start();

  @override
  Widget build(BuildContext context) => IosCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Build a daily habit', style: context.headline),
        const SizedBox(height: 4),
        Text(
          'Small things to do every day. Tick them off here and watch the '
          'streak grow. Start with one of these or make your own.',
          style: context.subheadline.copyWith(color: context.secondaryLabel),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in HabitsScreen.suggestions) _Suggestion(name: s),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(0, AppTheme.minTapTarget),
              color: context.tint,
              borderRadius: BorderRadius.circular(22),
              onPressed: () => HabitsScreen.add(context),
              child: Text(
                'Your Own',
                style: context.subheadline.copyWith(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Suggestion extends StatelessWidget {
  const _Suggestion({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final look = habitLook(name);
    final color = context.resolve(look.color);
    return Semantics(
      button: true,
      label: tr('Add $name'),
      excludeSemantics: true,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, AppTheme.minTapTarget),
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(22),
        onPressed: () => HabitsScreen.add(context, tr(name)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(look.icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(name, style: context.subheadline),
          ],
        ),
      ),
    );
  }
}

Future<String?> _askName(
  BuildContext context, {
  required String title,
  required String confirm,
  String initial = '',
}) => showTextPrompt(
  context,
  title: title,
  confirm: confirm,
  initial: initial,
  placeholder: 'e.g. Stretch, Read, No sugar',
  inputFormatters: [LengthLimitingTextInputFormatter(MoodStore.maxHabitName)],
);

Future<void> _alreadyThere(BuildContext context, String name) => showMessage(
  context,
  title: 'Already a Habit',
  message: '"${name.trim()}" is already in your habits.',
);

/// One habit: its icon, streak, a big tick for today and the last 30 days.
class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.habit});

  final String habit;

  static const _days = 30;

  Future<void> _rename(BuildContext context) async {
    final mood = context.read<MoodStore>();
    final name = await _askName(
      context,
      title: 'Rename Habit',
      confirm: 'Save',
      initial: habit,
    );
    if (name == null || name.trim().isEmpty) return;
    if (!await mood.renameHabit(habit, name) && context.mounted) {
      await _alreadyThere(context, name);
    }
  }

  Future<void> _remove(BuildContext context) async {
    final mood = context.read<MoodStore>();
    if (await confirmDestructive(
      context,
      title: 'Remove "$habit"?',
      message: 'Its streak and history are removed too.',
      action: 'Remove Habit',
    )) {
      await mood.removeHabit(habit);
    }
  }

  void _toggle(BuildContext context, DateTime day) {
    HapticFeedback.mediumImpact();
    context.read<MoodStore>().toggleHabit(habit, day);
  }

  Future<void> _options(BuildContext context, DateTime yesterday) async {
    final mood = context.read<MoodStore>();
    final doneYesterday = mood.didHabit(habit, yesterday);
    final at = mood.habits.indexOf(habit);
    final choice = await showCupertinoModalPopup<int>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(habit),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 0),
            child: Text(doneLabel(doneYesterday)),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 1),
            child: const Text('Rename'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 3),
            child: const Text('Icon and Colour'),
          ),
          if (at > 0)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, 4),
              child: const Text('Move Up'),
            ),
          if (at < mood.habits.length - 1)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, 5),
              child: const Text('Move Down'),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, 2),
            child: const Text('Remove Habit'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 0:
        _toggle(context, yesterday);
      case 1:
        await _rename(context);
      case 2:
        await _remove(context);
      case 3:
        await HabitLookSheet.show(context, habit);
      case 4:
        await mood.moveHabit(habit, -1);
      case 5:
        await mood.moveHabit(habit, 1);
    }
  }

  static String doneLabel(bool doneYesterday) =>
      doneYesterday ? 'Not Done Yesterday' : 'Done Yesterday';

  @override
  Widget build(BuildContext context) {
    final mood = context.watch<MoodStore>();
    final today = context.watch<HealthStore>().today;
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final done = mood.didHabit(habit, today);
    final streak = mood.streak(habit);
    final best = mood.bestStreak(habit);
    final at = mood.habits.indexOf(habit);
    final month = [
      for (var i = _days - 1; i >= 0; i--)
        mood.didHabit(habit, DateTime(today.year, today.month, today.day - i)),
    ];
    final count = month.where((d) => d).length;
    final look = habitLook(habit, mood.look(habit));
    final color = context.resolve(look.color);
    final reduced = Motion.reduced(context);
    return Semantics(
      container: true,
      customSemanticsActions: {
        CustomSemanticsAction(
          label: tr(doneLabel(mood.didHabit(habit, yesterday))),
        ): () =>
            _toggle(context, yesterday),
        CustomSemanticsAction(label: tr('Rename')): () => _rename(context),
        CustomSemanticsAction(label: tr('Icon and Colour')): () =>
            HabitLookSheet.show(context, habit),
        if (at > 0)
          CustomSemanticsAction(label: tr('Move Up')): () =>
              mood.moveHabit(habit, -1),
        if (at < mood.habits.length - 1)
          CustomSemanticsAction(label: tr('Move Down')): () =>
              mood.moveHabit(habit, 1),
        CustomSemanticsAction(label: tr('Remove Habit')): () =>
            _remove(context),
      },
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.mediumImpact();
          _options(context, yesterday);
        },
        child: IosCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(look.icon, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(habit, style: context.headline),
                        Text(
                          switch (streak) {
                            0 => 'No streak yet',
                            1 => '1-day streak',
                            final n => '$n-day streak',
                          },
                          style: context.subheadline.copyWith(
                            color: streak > 0 ? color : context.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    checked: done,
                    label: habit,
                    excludeSemantics: true,
                    onTap: () => _toggle(context, today),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size.square(52),
                      onPressed: () => _toggle(context, today),
                      child: AnimatedSwitcher(
                        duration: reduced ? Duration.zero : Motion.fast,
                        switchInCurve: Motion.spring,
                        transitionBuilder: (child, a) =>
                            ScaleTransition(scale: a, child: child),
                        child: Icon(
                          done
                              ? CupertinoIcons.checkmark_circle_fill
                              : CupertinoIcons.circle,
                          key: ValueKey(done),
                          size: 40,
                          color: done ? color : context.tertiaryLabel,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Semantics(
                label: tr('Done $count of the last $_days days'),
                excludeSemantics: true,
                // A 44pt band, taller than the 16pt strip, so a day is easy
                // to hit; the day comes from where along it you tap.
                child: LayoutBuilder(
                  builder: (context, c) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) {
                      final i = (d.localPosition.dx / c.maxWidth * _days)
                          .floor()
                          .clamp(0, _days - 1);
                      _toggle(
                        context,
                        DateTime(
                          today.year,
                          today.month,
                          today.day - (_days - 1 - i),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          for (final (i, d) in month.indexed)
                            Expanded(
                              child: Container(
                                height: 16,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: d ? color : context.separatorColor,
                                  borderRadius: BorderRadius.circular(3),
                                  // Today, still to do: outlined so it reads as
                                  // "not yet" rather than "missed".
                                  border: i == month.length - 1 && !d
                                      ? Border.all(color: color, width: 1.5)
                                      : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                best > streak
                    ? 'Done $count of the last $_days days · Best $best'
                    : 'Done $count of the last $_days days',
                style: context.footnote.copyWith(color: context.secondaryLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
