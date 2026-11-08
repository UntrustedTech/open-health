import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/screens/habits/habits_screen.dart';
import 'package:health_app/state/mood_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/ios.dart';

/// Pick a habit's icon and colour.
class HabitLookSheet extends StatefulWidget {
  const HabitLookSheet({
    super.key,
    required this.habit,
    required this.controller,
  });

  final String habit;
  final ScrollController controller;

  static Future<void> show(BuildContext context, String habit) =>
      showCupertinoSheet<void>(
        context: context,
        scrollableBuilder: (context, controller) =>
            HabitLookSheet(habit: habit, controller: controller),
      );

  @override
  State<HabitLookSheet> createState() => _HabitLookSheetState();
}

class _HabitLookSheetState extends State<HabitLookSheet> {
  late var _names = habitLookNames(
    widget.habit,
    context.read<MoodStore>().look(widget.habit),
  );

  void _pick({String? icon, String? color}) {
    HapticFeedback.selectionClick();
    setState(
      () => _names = (icon: icon ?? _names.icon, color: color ?? _names.color),
    );
  }

  Future<void> _save() async {
    await context.read<MoodStore>().setLook(
      widget.habit,
      icon: _names.icon,
      color: _names.color,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.resolve(habitColors[_names.color]!.$1);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        // Every bar shares one hero tag, so it would fly into the sheet.
        transitionBetweenRoutes: false,
        automaticallyImplyLeading: false,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        middle: const Text('Icon and Colour'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _save,
          child: const Text(
            'Save',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      child: PageList(
        controller: widget.controller,
        padding: const EdgeInsets.fromLTRB(
          AppTheme.margin,
          16,
          AppTheme.margin,
          32,
        ),
        children: [
          Center(
            child: ExcludeSemantics(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  habitIcons[_names.icon]!.$1,
                  color: color,
                  size: 40,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.habit,
            textAlign: TextAlign.center,
            style: context.headline,
          ),
          const SizedBox(height: 20),
          Text('Colour', style: context.headline),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final MapEntry(key: name, value: (c, label))
                  in habitColors.entries)
                _Choice(
                  label: label,
                  selected: name == _names.color,
                  color: context.resolve(c),
                  onTap: () => _pick(color: name),
                  child: name == _names.color
                      ? Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: context.onColor(context.resolve(c)),
                        )
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Icon', style: context.headline),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final MapEntry(key: name, value: (icon, label))
                  in habitIcons.entries)
                _Choice(
                  label: label,
                  selected: name == _names.icon,
                  color: name == _names.icon
                      ? color
                      : context.resolve(Palette.fill),
                  onTap: () => _pick(icon: name),
                  child: Icon(
                    icon,
                    size: 24,
                    color: name == _names.icon
                        ? context.onColor(color)
                        : context.labelColor,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A round 48pt button, marked by a ring as well as its fill when chosen.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.child,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: tr(label),
    excludeSemantics: true,
    onTap: onTap,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? context.labelColor : const Color(0x00000000),
            width: 2,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          child: Center(child: child),
        ),
      ),
    ),
  );
}
