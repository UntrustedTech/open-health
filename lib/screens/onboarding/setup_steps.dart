import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:health_app/utils/log.dart';
import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/widgets/number_input.dart';
import 'package:health_app/models/food.dart';
import 'package:health_app/models/goal_presets.dart';
import 'package:health_app/models/reminder_presets.dart';
import 'package:health_app/models/health_entry.dart';
import 'package:health_app/models/metric_type.dart';
import 'package:health_app/models/user_profile.dart';
import 'package:health_app/notifications/notification_controller.dart';
import 'package:health_app/notifications/reminder_plan.dart';
import 'package:health_app/nutrition/calorie_estimate.dart';
import 'package:health_app/screens/food/food_diary_screen.dart'
    show foodOrange, kcalText;
import 'package:health_app/screens/food/food_settings_screen.dart';
import 'package:health_app/screens/edit_profile_screen.dart';
import 'package:health_app/screens/notification_settings_screen.dart';
import 'package:health_app/screens/goal/calorie_breakdown.dart';
import 'package:health_app/screens/onboarding/setup_page.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/state/nutrition_store.dart';
import 'package:health_app/state/workout_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/utils/format.dart';
import 'package:health_app/utils/units.dart';
import 'package:health_app/widgets/app_chip.dart';
import 'package:health_app/widgets/height_picker.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/app_segmented.dart';

/// Where a setup step sits and what happens when it's finished.
class StepNav {
  const StepNav({
    required this.step,
    required this.steps,
    required this.onBack,
    required this.onDone,
  });

  final int step;
  final int steps;
  final VoidCallback onBack;

  /// Called with true when the step was skipped.
  final ValueChanged<bool> onDone;
}

/// Sex, height and weight (age is asked on About You).
class ProfileStep extends StatefulWidget {
  const ProfileStep({super.key, required this.nav});

  final StepNav nav;

  @override
  State<ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends State<ProfileStep> {
  static const _sexes = ['Female', 'Male', 'Other'];

  late final _initial = context.read<HealthStore>().profile;
  late String _sex = _sexes.contains(_initial.sex) ? _initial.sex : '';

  /// Centimetres, picked with the height wheels.
  late double? _heightCm = _initial.heightCm;
  final _weight = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  Future<void> _pickHeight() async {
    final cm = await pickHeight(context, _heightCm);
    if (cm != null && mounted) setState(() => _heightCm = cm);
  }

  static double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    if (_busy) return;
    final store = context.read<HealthStore>();
    final heightCm = _heightCm;
    final shownWeight = _num(_weight);
    final weightKg = shownWeight == null ? null : Units.weightIn(shownWeight);
    final error = heightCm != null && (heightCm < 30 || heightCm > 272)
        ? 'Check your height.'
        : weightKg != null && (weightKg < 2 || weightKg > 635)
        ? 'Check your weight.'
        : null;
    if (error != null) {
      HapticFeedback.heavyImpact();
      setState(() => _error = error);
      return;
    }
    setState(() => _busy = true);
    try {
      await store.updateProfile(
        _initial.copyWith(sex: _sex, heightCm: heightCm ?? _initial.heightCm),
      );
      final latest = store.latestReading(MetricType.weight)?.value;
      // Going back and continuing again doesn't log the same weight twice.
      if (weightKg != null &&
          (latest == null || (latest - weightKg).abs() > 0.01)) {
        final now = store.now;
        await store.addEntries([
          HealthEntry(
            id: 'setup${now.microsecondsSinceEpoch}',
            type: MetricType.weight,
            value: double.parse(weightKg.toStringAsFixed(2)),
            date: now,
          ),
        ]);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    widget.nav.onDone(false);
  }

  Widget _field(TextEditingController c, String label, String unit) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        Expanded(child: Text(label, style: context.body)),
        SizedBox(
          width: 90,
          child: CupertinoTextField.borderless(
            controller: c,
            textAlign: TextAlign.end,
            placeholder: tr('Optional'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: numberInput(),
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 28,
          child: Text(
            unit,
            style: context.body.copyWith(color: context.secondaryLabel),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final nav = widget.nav;
    return SetupPage(
      icon: Icons.person_rounded,
      color: Palette.blue,
      title: 'Health Details',
      subtitle:
          'Used to estimate calories and show accurate numbers. It stays on '
          'this device.',
      step: nav.step,
      steps: nav.steps,
      onBack: nav.onBack,
      onSkip: () => nav.onDone(true),
      onContinue: _save,
      busy: _busy,
      children: [
        GroupedSection(
          hasLeading: false,
          footer: _error,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: AppSegmented<String>(
                  groupValue: _sex.isEmpty ? null : _sex,
                  children: {for (final s in _sexes) s: Text(s)},
                  onValueChanged: (v) => setState(() => _sex = v ?? ''),
                ),
              ),
            ),
            InfoRow(
              title: 'Height',
              value: switch (_heightCm) {
                final cm? => Units.height(cm),
                null => 'Not Set',
              },
              chevron: true,
              onTap: _pickHeight,
            ),
            _field(_weight, 'Weight', Units.weightUnit),
          ],
        ),
      ],
    );
  }
}

/// Move, exercise, steps and water targets: a preset that suits the
/// user, or each one set by hand.
class GoalsStep extends StatefulWidget {
  const GoalsStep({super.key, required this.nav});

  final StepNav nav;

  @override
  State<GoalsStep> createState() => _GoalsStepState();
}

class _GoalsStepState extends State<GoalsStep> {
  /// Stepper size and limits for each target.
  static const _limits = {
    MetricType.activeEnergy: (50.0, 50.0, 5000.0),
    MetricType.exerciseMinutes: (5.0, 5.0, 600.0),
    MetricType.steps: (500.0, 500.0, 100000.0),
    MetricType.water: (250.0, 250.0, 10000.0),
  };

  late final List<GoalPreset> _presets = () {
    final health = context.read<HealthStore>();
    return goalPresets(
      level: health.bodyGoal.activity,
      current: targetsOf(health.goals),
    );
  }();

  /// Goals someone already changed stay selected; otherwise the
  /// recommendation is.
  late GoalPresetKind _kind = () {
    final current = targetsOf(context.read<HealthStore>().goals);
    final customised = current != targetsOf(const Goals());
    return customised && _presets.any((p) => p.kind == GoalPresetKind.current)
        ? GoalPresetKind.current
        : _presets.first.kind;
  }();
  late DailyTargets _custom = _presets.last.targets;

  DailyTargets get _targets => _kind == GoalPresetKind.custom
      ? _custom
      : _presets.firstWhere((p) => p.kind == _kind).targets;

  Future<void> _save() async {
    final store = context.read<HealthStore>();
    final targets = _targets;
    for (final t in dailyTargetMetrics) {
      final value = targetFor(targets, t);
      if (store.goals.forMetric(t) != value) await store.updateGoal(t, value);
    }
    widget.nav.onDone(false);
  }

  void _nudge(MetricType t, double by) => setState(
    () => _custom = withTarget(_custom, t, targetFor(_custom, t) + by),
  );

  @override
  Widget build(BuildContext context) {
    final nav = widget.nav;
    return SetupPage(
      icon: Icons.track_changes_rounded,
      color: Palette.orange,
      title: 'Daily Goals',
      subtitle:
          'Your rings fill as you get closer. Pick what suits you; you can '
          'change these any time.',
      step: nav.step,
      steps: nav.steps,
      onBack: nav.onBack,
      onSkip: () => nav.onDone(true),
      onContinue: _save,
      children: [
        for (final p in _presets) ...[
          SetupChoice(
            icon: switch (p.kind) {
              GoalPresetKind.recommended => Icons.auto_awesome_rounded,
              GoalPresetKind.current => Icons.history_rounded,
              GoalPresetKind.easier => Icons.spa_rounded,
              GoalPresetKind.harder => Icons.bolt_rounded,
              GoalPresetKind.custom => Icons.tune_rounded,
            },
            color: switch (p.kind) {
              GoalPresetKind.recommended => Palette.orange,
              GoalPresetKind.current => Palette.blue,
              GoalPresetKind.easier => Palette.green,
              GoalPresetKind.harder => Palette.red,
              GoalPresetKind.custom => Palette.indigo,
            },
            title: p.title,
            subtitle: p.subtitle,
            badge: p.kind == GoalPresetKind.recommended ? 'For You' : null,
            selected: _kind == p.kind,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _kind = p.kind);
            },
            details: p.kind == GoalPresetKind.custom
                ? _customEditor()
                : TargetSummary(targets: p.targets),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _customEditor() => Column(
    children: [
      for (final t in dailyTargetMetrics)
        if (_limits[t] case (final step, final lo, final hi))
          SetupStepper(
            icon: t.icon,
            color: t.color,
            title: t.label,
            value: '${formatValue(t, targetFor(_custom, t))} ${unitLabel(t)}'
                .trim(),
            onMinus: targetFor(_custom, t) - step >= lo
                ? () => _nudge(t, -step)
                : null,
            onPlus: targetFor(_custom, t) + step <= hi
                ? () => _nudge(t, step)
                : null,
          ),
    ],
  );
}

/// A preset's four targets, two to a row.
class TargetSummary extends StatelessWidget {
  const TargetSummary({super.key, required this.targets});

  final DailyTargets targets;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final t in dailyTargetMetrics)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: ShapeDecoration(
            color: context.resolve(t.color).withValues(alpha: 0.12),
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(t.icon, size: 14, color: context.resolve(t.color)),
              const SizedBox(width: 5),
              Text(
                '${formatValue(t, targetFor(targets, t))} ${unitLabel(t)}'
                    .trim(),
                style: context.footnote.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

/// Daily calories and macro split.
class FoodStep extends StatefulWidget {
  const FoodStep({super.key, required this.nav});

  final StepNav nav;

  @override
  State<FoodStep> createState() => _FoodStepState();
}

class _FoodStepState extends State<FoodStep> {
  /// A goal already chosen (e.g. when coming back to this step) wins over
  /// the estimate; otherwise the goal follows the estimate until changed.
  late double? _chosen = () {
    final saved = context.read<NutritionStore>().goals.kcal;
    return saved != const NutritionGoals().kcal ? saved : null;
  }();

  CalorieEstimate? _suggestion(HealthStore health) => suggestCalories(
    health,
    exerciseAdded: context.read<NutritionStore>().goals.addExercise,
  );

  double _kcalFor(CalorieEstimate? suggestion) =>
      _chosen ??
      suggestion?.target ??
      context.read<NutritionStore>().goals.kcal;

  void _step(CalorieEstimate? suggestion, double by) =>
      setState(() => _chosen = _kcalFor(suggestion) + by);

  late int _preset = () {
    final g = context.read<NutritionStore>().goals;
    final i = macroPresets.indexWhere(
      (p) =>
          (g.proteinShare - p.$2).abs() < 0.01 &&
          (g.carbsShare - p.$3).abs() < 0.01,
    );
    return i < 0 ? 0 : i;
  }();

  Future<void> _save() async {
    final store = context.read<NutritionStore>();
    final (_, p, c, f) = macroPresets[_preset];
    final suggestion = _suggestion(context.read<HealthStore>());
    final kcal = _kcalFor(suggestion);
    await store.setGoals(
      store.goals.copyWith(
        kcal: kcal,
        includesActivity: !(suggestion?.countsExercise ?? false),
        proteinShare: p,
        carbsShare: c,
        fatShare: f,
      ),
    );
    widget.nav.onDone(false);
  }

  @override
  Widget build(BuildContext context) {
    final nav = widget.nav;
    final health = context.watch<HealthStore>();
    final suggestion = _suggestion(health);
    final kcal = _kcalFor(suggestion);
    return SetupPage(
      icon: Icons.restaurant_rounded,
      color: foodOrange,
      title: 'Food & Calories',
      subtitle:
          'Your daily calorie budget, worked out from your details, '
          'activity and goal. Scan barcodes in the Food tab to count what '
          'you eat.',
      step: nav.step,
      steps: nav.steps,
      onBack: nav.onBack,
      onSkip: () => nav.onDone(true),
      onContinue: _save,
      children: [
        CalorieBreakdown(
          estimate: suggestion,
          goal: health.bodyGoal,
          missing: CalorieEstimate.missingFor(
            health.profile,
            health.latestReading(MetricType.weight)?.value,
            health.today,
          ),
          onAddDetails: () => EditProfileScreen.open(context),
        ),
        GroupedSection(
          hasLeading: false,
          footer: suggestion != null && (kcal - suggestion.target).abs() >= 10
              ? 'Changed from the suggested ${kcalText(suggestion.target)} '
                    'Cal.'
              : null,
          children: [
            SetupStepper(
              icon: Icons.local_fire_department_rounded,
              color: foodOrange,
              title: 'Daily Calories',
              value: '${kcalText(kcal)} Cal',
              onMinus: kcal > 1000 ? () => _step(suggestion, -50) : null,
              onPlus: kcal < 6000 ? () => _step(suggestion, 50) : null,
            ),
          ],
        ),
        GroupedSection(
          header: 'Macros',
          footer: () {
            final (_, p, c, f) = macroPresets[_preset];
            return 'Protein ${(p * 100).round()}% · Carbs '
                '${(c * 100).round()}% · Fat ${(f * 100).round()}%';
          }(),
          hasLeading: false,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 0,
                children: [
                  for (final (i, (name, _, _, _)) in macroPresets.indexed)
                    AppChip(
                      label: name,
                      color: foodOrange,
                      selected: _preset == i,
                      onTap: () => setState(() => _preset = i),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A weekly activity goal in minutes of any activity, or none.
class FitnessStep extends StatefulWidget {
  const FitnessStep({super.key, required this.nav});

  final StepNav nav;

  @override
  State<FitnessStep> createState() => _FitnessStepState();
}

class _FitnessStepState extends State<FitnessStep> {
  /// Ready-made weekly goals: (label, minutes).
  static const _presets = [
    ('Light', 75),
    ('Recommended', 150),
    ('Active', 300),
  ];

  late WorkoutSettings _s = context.read<WorkoutStore>().settings;

  /// The goal to go back to when it's turned on again.
  late int _lastGoal = _s.weeklyGoalMinutes > 0
      ? _s.weeklyGoalMinutes
      : WorkoutSettings.defaultWeeklyGoal;

  Future<void> _save() async {
    await context.read<WorkoutStore>().updateSettings(_s);
    widget.nav.onDone(false);
  }

  void _setGoal(int minutes) => setState(() {
    if (minutes > 0) _lastGoal = minutes;
    _s = _s.copyWith(weeklyGoalMinutes: minutes);
  });

  @override
  Widget build(BuildContext context) {
    final nav = widget.nav;
    final goal = _s.weeklyGoalMinutes;
    final on = goal > 0;
    return SetupPage(
      icon: Icons.local_fire_department_rounded,
      color: Palette.green,
      title: 'Fitness',
      subtitle:
          'How active would you like to be each week? Walks, workouts, '
          'sports and yoga all count.',
      step: nav.step,
      steps: nav.steps,
      onBack: nav.onBack,
      onSkip: () => nav.onDone(true),
      onContinue: _save,
      children: [
        SetupChoice(
          icon: Icons.calendar_month_rounded,
          color: Palette.green,
          title: 'Weekly Activity Goal',
          subtitle: 'A target for minutes of activity each week.',
          badge: 'Recommended',
          selected: on,
          onTap: () {
            HapticFeedback.selectionClick();
            _setGoal(_lastGoal);
          },
          details: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 0,
                children: [
                  for (final (label, minutes) in _presets)
                    AppChip(
                      label: label,
                      color: Palette.green,
                      selected: goal == minutes,
                      onTap: () => _setGoal(minutes),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              SetupStepper(
                icon: Icons.timer_rounded,
                color: Palette.green,
                title: 'Each Week',
                value: '$goal min',
                onMinus: goal > 30 ? () => _setGoal(goal - 15) : null,
                onPlus: goal < 1500 ? () => _setGoal(goal + 15) : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SetupChoice(
          icon: Icons.do_not_disturb_on_rounded,
          color: Palette.grey,
          title: 'No Weekly Goal',
          subtitle: 'Just log your activity, with no target to reach.',
          selected: !on,
          onTap: () {
            HapticFeedback.selectionClick();
            _setGoal(0);
          },
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Health organisations recommend at least 150 minutes of '
            'activity a week. Change this any time in Fitness settings.',
            style: context.footnote.copyWith(color: context.secondaryLabel),
          ),
        ),
      ],
    );
  }
}

/// Which reminders to turn on, each with a recommended schedule or one of
/// the user's own. Workout days follow the weekly goal from Fitness.
class RemindersStep extends StatefulWidget {
  const RemindersStep({super.key, required this.nav});

  final StepNav nav;

  @override
  State<RemindersStep> createState() => _RemindersStepState();
}

class _RemindersStepState extends State<RemindersStep> {
  late final int _weeklyGoal = context
      .read<WorkoutStore>()
      .settings
      .weeklyGoalMinutes;

  late var _s = () {
    final saved = context.read<NotificationController>().settings;
    // Workout days start from the weekly goal unless already set up.
    return saved.workout
        ? saved
        : saved.copyWith(
            workoutDays: workoutDaysForGoal(_weeklyGoal),
            workoutHour: recommendedWorkoutHour,
          );
  }();

  late bool _customWater = _s.water && !isRecommendedWater(_s);
  late bool _customWorkout =
      _s.workout &&
      (!setEquals(_s.workoutDays, workoutDaysForGoal(_weeklyGoal)) ||
          _s.workoutHour != recommendedWorkoutHour);
  bool _busy = false;

  Future<void> _save() async {
    final controller = context.read<NotificationController>();
    setState(() => _busy = true);
    var allowed = false;
    try {
      // Asked here whatever is chosen: medication reminders and the
      // workout timer need notifications too.
      allowed = await controller.notifier.requestPermission();
      if (allowed || !_s.anyOn) await controller.update(_s);
    } on Object catch (e) {
      // Treated as a refusal below, so setup can carry on.
      logError('Setup: reminders could not be set: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (!allowed && _s.anyOn) {
      await showMessage(
        context,
        title: 'Notifications Are Off',
        message:
            'Allow notifications for Health in your phone\'s Settings to get '
            'reminders. You can turn them on later in Profile.',
      );
      if (!mounted) return;
      widget.nav.onDone(true);
      return;
    }
    widget.nav.onDone(false);
  }

  void _set(NotificationSettings s) {
    HapticFeedback.selectionClick();
    setState(() => _s = s);
  }

  String _hour(int h) => TimeOfDayFormat.format(context, h);

  Future<void> _pick(int hour, ValueChanged<int> onPicked) =>
      NotificationSettingsScreen.pickHour(context, hour, onPicked);

  @override
  Widget build(BuildContext context) {
    final nav = widget.nav;
    return SetupPage(
      icon: Icons.notifications_rounded,
      color: Palette.red,
      title: 'Reminders',
      subtitle:
          'Gentle nudges to help you build habits. Tap any you\'d like; '
          'Health will then ask to send notifications.',
      step: nav.step,
      steps: nav.steps,
      onBack: nav.onBack,
      onSkip: () => nav.onDone(true),
      onContinue: _save,
      busy: _busy,
      children: [
        SetupChoice(
          icon: Icons.water_drop_rounded,
          color: Palette.blue,
          title: 'Water',
          subtitle: 'Reminders to drink through the day.',
          selected: _s.water,
          onTap: () => _set(_s.copyWith(water: !_s.water)),
          details: _waterDetails(),
        ),
        const SizedBox(height: 10),
        SetupChoice(
          icon: Icons.restaurant_rounded,
          color: foodOrange,
          title: 'Meals',
          subtitle: 'A nudge to log breakfast, lunch and dinner.',
          selected: _s.meals,
          onTap: () => _set(_s.copyWith(meals: !_s.meals)),
          details: _mealDetails(),
        ),
        const SizedBox(height: 10),
        SetupChoice(
          icon: Icons.local_fire_department_rounded,
          color: Palette.green,
          title: 'Workouts',
          subtitle: 'A reminder on the days you plan to be active.',
          selected: _s.workout,
          onTap: () => _set(_s.copyWith(workout: !_s.workout)),
          details: _workoutDetails(),
        ),
        const SizedBox(height: 10),
        SetupChoice(
          icon: Icons.donut_large_rounded,
          color: Palette.pink,
          title: 'Close Your Rings',
          subtitle: 'In the evening, if your rings aren\'t closed yet.',
          selected: _s.rings,
          onTap: () => _set(_s.copyWith(rings: !_s.rings)),
        ),
      ],
    );
  }

  Widget _waterDetails() {
    final rec = recommendedWater;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Options(
          selectedCustom: _customWater,
          recommended:
              'Every ${rec.everyHours} hours, ${_hour(rec.startHour)} to '
              '${_hour(rec.endHour)}',
          onRecommended: () {
            setState(() => _customWater = false);
            _set(withRecommendedWater(_s));
          },
          onCustom: () => setState(() => _customWater = true),
        ),
        if (_customWater) ...[
          SetupStepper(
            icon: Icons.repeat_rounded,
            color: context.tint,
            title: 'Remind Every',
            value: _s.waterEveryHours == 1
                ? '1 hour'
                : '${_s.waterEveryHours} hours',
            onMinus: _s.waterEveryHours > 1
                ? () =>
                      _set(_s.copyWith(waterEveryHours: _s.waterEveryHours - 1))
                : null,
            onPlus: _s.waterEveryHours < 6
                ? () =>
                      _set(_s.copyWith(waterEveryHours: _s.waterEveryHours + 1))
                : null,
          ),
          _TimeRow(
            title: 'From',
            value: _hour(_s.waterStartHour),
            onTap: () => _pick(_s.waterStartHour, (h) {
              if (h < _s.waterEndHour) _set(_s.copyWith(waterStartHour: h));
            }),
          ),
          _TimeRow(
            title: 'Until',
            value: _hour(_s.waterEndHour),
            onTap: () => _pick(_s.waterEndHour, (h) {
              if (h > _s.waterStartHour) _set(_s.copyWith(waterEndHour: h));
            }),
          ),
        ],
      ],
    );
  }

  Widget _mealDetails() {
    final (b, l, d) = _s.mealHours;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'When do you usually eat?',
          style: context.subheadline.copyWith(fontWeight: FontWeight.w700),
        ),
        _TimeRow(
          title: 'Breakfast',
          value: _hour(b),
          onTap: () => _pick(b, (h) => _set(_s.copyWith(mealHours: (h, l, d)))),
        ),
        _TimeRow(
          title: 'Lunch',
          value: _hour(l),
          onTap: () => _pick(l, (h) => _set(_s.copyWith(mealHours: (b, h, d)))),
        ),
        _TimeRow(
          title: 'Dinner',
          value: _hour(d),
          onTap: () => _pick(d, (h) => _set(_s.copyWith(mealHours: (b, l, h)))),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.cookie_rounded, size: 16, color: context.secondaryLabel),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Snacks can be logged any time of day, so there\'s no '
                'reminder for them.',
                style: context.footnote.copyWith(color: context.secondaryLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _workoutDetails() {
    final days = workoutDaysForGoal(_weeklyGoal);
    final basis = _weeklyGoal > 0
        ? 'Fits your $_weeklyGoal min weekly goal'
        : 'A steady three days a week';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Options(
          selectedCustom: _customWorkout,
          recommended:
              '${dayList(days)} at ${_hour(recommendedWorkoutHour)}. $basis.',
          onRecommended: () {
            setState(() => _customWorkout = false);
            _set(
              _s.copyWith(
                workoutDays: days,
                workoutHour: recommendedWorkoutHour,
              ),
            );
          },
          onCustom: () => setState(() => _customWorkout = true),
        ),
        if (_customWorkout) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var d = 1; d <= 7; d++)
                  Flexible(
                    child: DayToggle(
                      letter: dayNames[d - 1][0],
                      label: weekdayNames[d - 1],
                      selected: _s.workoutDays.contains(d),
                      onTap: () {
                        final next = {..._s.workoutDays};
                        if (!next.remove(d)) next.add(d);
                        _set(_s.copyWith(workoutDays: next));
                      },
                    ),
                  ),
              ],
            ),
          ),
          _TimeRow(
            title: 'Time',
            value: _hour(_s.workoutHour),
            onTap: () =>
                _pick(_s.workoutHour, (h) => _set(_s.copyWith(workoutHour: h))),
          ),
        ],
      ],
    );
  }
}

/// Recommended or custom, as two chips in the theme colour with the
/// recommendation spelled out.
class _Options extends StatelessWidget {
  const _Options({
    required this.selectedCustom,
    required this.recommended,
    required this.onRecommended,
    required this.onCustom,
  });

  final bool selectedCustom;
  final String recommended;
  final VoidCallback onRecommended;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 0,
        children: [
          AppChip(
            label: 'Recommended',
            color: context.tint,
            selected: !selectedCustom,
            onTap: onRecommended,
          ),
          AppChip(
            label: 'Custom',
            color: context.tint,
            selected: selectedCustom,
            onTap: onCustom,
          ),
        ],
      ),
      if (!selectedCustom)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            recommended,
            style: context.footnote.copyWith(color: context.secondaryLabel),
          ),
        ),
    ],
  );
}

/// A time with a chevron, to open the time wheel.
class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.title,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$title, $value',
    excludeSemantics: true,
    onTap: onTap,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppTheme.minTapTarget),
        child: Row(
          children: [
            Expanded(child: Text(title, style: context.body)),
            Text(
              value,
              style: context.body.copyWith(
                color: context.tint,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: context.tertiaryLabel,
            ),
          ],
        ),
      ),
    ),
  );
}
