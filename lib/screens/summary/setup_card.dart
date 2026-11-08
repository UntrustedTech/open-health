import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/personalization.dart';
import 'package:health_app/screens/appearance_screen.dart';
import 'package:health_app/screens/edit_profile_screen.dart';
import 'package:health_app/screens/food/food_diary_screen.dart' show foodOrange;
import 'package:health_app/screens/food/food_settings_screen.dart';
import 'package:health_app/screens/goal/body_goal_screen.dart';
import 'package:health_app/screens/goals_screen.dart';
import 'package:health_app/screens/health_connect_screen.dart';
import 'package:health_app/screens/notification_settings_screen.dart';
import 'package:health_app/screens/workouts/workout_settings_screen.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/glow_tile.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';

/// Lists the welcome-setup steps that were skipped. Each opens the screen
/// where it's done; the card disappears once all are done or dismissed.
class SetupCard extends StatelessWidget {
  const SetupCard({super.key});

  static (IconData, Color) _look(SetupStep step) => switch (step) {
    SetupStep.about => (Icons.waving_hand_rounded, Palette.yellow),
    SetupStep.profile => (Icons.person_rounded, Palette.blue),
    SetupStep.connect => (Icons.sync_rounded, AppTheme.accent),
    SetupStep.preferences => (Icons.tune_rounded, Palette.indigo),
    SetupStep.bodyGoal => (Icons.flag_rounded, Palette.teal),
    SetupStep.goals => (Icons.track_changes_rounded, Palette.orange),
    SetupStep.food => (Icons.restaurant_rounded, foodOrange),
    SetupStep.fitness => (Icons.local_fire_department_rounded, Palette.green),
    SetupStep.reminders => (Icons.notifications_rounded, Palette.red),
  };

  static Future<void> _open(BuildContext context, SetupStep step) async {
    final store = context.read<HealthStore>();
    // Visiting the step counts as doing it; the screen saves as you go.
    await switch (step) {
      SetupStep.about || SetupStep.profile => EditProfileScreen.open(context),
      SetupStep.bodyGoal => BodyGoalScreen.open(context),
      SetupStep.connect => HealthConnectScreen.open(context),
      SetupStep.preferences => AppearanceScreen.open(context),
      SetupStep.goals => GoalsScreen.open(context),
      SetupStep.food => FoodSettingsScreen.open(context),
      SetupStep.fitness => WorkoutSettingsScreen.open(context),
      SetupStep.reminders => NotificationSettingsScreen.open(context),
    };
    await store.completeSetupStep(step);
  }

  static Future<void> _dismiss(BuildContext context) async {
    final store = context.read<HealthStore>();
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Hide Setup?'),
        content: const Text(
          'You can still change everything in Profile › Settings.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hide'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await store.setPersonalization(
        store.personalization.copyWith(setupLeft: {}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final left = [
      for (final s in SetupStep.values)
        if (store.personalization.setupLeft.contains(s)) s,
    ];
    final total = SetupStep.values.length;
    final done = total - left.length;
    final tint = context.tint;
    return AnimatedSize(
      duration: Motion.reduced(context) ? Duration.zero : Motion.medium,
      curve: Motion.curve,
      alignment: Alignment.topCenter,
      child: left.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: IosCard(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 34,
                          child: MiniRing(progress: done / total, color: tint),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  'Finish Setting Up',
                                  style: context.headline,
                                ),
                              ),
                              Text(
                                '$done of $total done',
                                style: context.footnote.copyWith(
                                  color: context.secondaryLabel,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size.square(AppTheme.minTapTarget),
                          onPressed: () => _dismiss(context),
                          child: Icon(
                            Icons.cancel_rounded,
                            color: context.tertiaryLabel,
                            semanticLabel: tr('Dismiss setup'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (final step in left)
                      _StepRow(
                        step: step,
                        look: _look(step),
                        onTap: () => _open(context, step),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.look, required this.onTap});

  final SetupStep step;
  final (IconData, Color) look;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = look;
    return Semantics(
      container: true,
      button: true,
      label: '${step.label}. ${step.detail}',
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              IconTile(icon: icon, color: context.resolve(color), size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.label,
                      style: context.subheadline.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      step.detail,
                      style: context.footnote.copyWith(
                        color: context.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: context.tertiaryLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
