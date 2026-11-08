import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';

import 'package:health_app/models/activity_level.dart';
import 'package:health_app/models/body_goal.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/screens/goal/body_goal_editor.dart';
import 'package:health_app/screens/goal/body_goal_screen.dart';
import 'package:health_app/screens/goal/calorie_breakdown.dart';
import 'package:health_app/screens/onboarding/setup_page.dart';
import 'package:health_app/screens/onboarding/setup_steps.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/theme/app_theme.dart';

/// What the user wants from Health, with a target weight and pace for
/// weight goals. Shapes the calorie goal suggested next.
class BodyGoalStep extends StatefulWidget {
  const BodyGoalStep({super.key, required this.nav});

  final StepNav nav;

  @override
  State<BodyGoalStep> createState() => _BodyGoalStepState();
}

class _BodyGoalStepState extends State<BodyGoalStep> {
  late final _health = context.read<HealthStore>();
  late BodyGoal _goal = _health.bodyGoal;
  late double? _target = _health.goals.weightKg;
  bool _busy = false;

  double? get _current => _health.latestReading(MetricType.weight)?.value;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await BodyGoalScreen.apply(
        _health,
        _goal,
        targetKg: _goal.objective.changesWeight
            ? _target ?? BodyGoalEditor.defaultTarget(_goal.objective, _current)
            : null,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) widget.nav.onDone(false);
  }

  @override
  Widget build(BuildContext context) {
    final nav = widget.nav;
    return SetupPage(
      icon: Icons.flag_rounded,
      color: Palette.teal,
      title: 'Your Goal',
      subtitle:
          'What would you like Health to help with? Your calorie goal and '
          'Summary follow from this.',
      step: nav.step,
      steps: nav.steps,
      onBack: nav.onBack,
      onSkip: () => nav.onDone(true),
      onContinue: _save,
      busy: _busy,
      children: [
        BodyGoalEditor(
          goal: _goal,
          targetKg: _target,
          currentKg: _current,
          today: _health.today,
          onGoal: (g) => setState(() {
            // A new weight goal starts from a fresh default target.
            if (g.objective != _goal.objective) _target = null;
            _goal = g;
          }),
          onTarget: (kg) => setState(() => _target = kg),
        ),
        ActivityLevelSection(
          value: _goal.activity,
          measured: switch (_health.recentActivity().averageSteps) {
            final s? => ActivityLevel.fromSteps(s),
            null => null,
          },
          onChanged: (level) => setState(
            () => _goal = _goal.copyWith(
              activity: level,
              autoActivity: level == null,
            ),
          ),
        ),
      ],
    );
  }
}
