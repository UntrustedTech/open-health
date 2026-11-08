import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/user_profile.dart';
import 'package:health_app/screens/onboarding/setup_page.dart';
import 'package:health_app/screens/onboarding/setup_steps.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';
import 'package:health_app/widgets/motion.dart';

/// Oldest birthday offered, in years before today.
const _maxYears = 120;

/// The user's first name and birthday; their age follows from it.
class AboutStep extends StatefulWidget {
  const AboutStep({super.key, required this.nav, required this.name});

  final StepNav nav;

  /// Kept by the setup so the name is saved when it finishes.
  final TextEditingController name;

  @override
  State<AboutStep> createState() => _AboutStepState();
}

class _AboutStepState extends State<AboutStep> {
  late final _store = context.read<HealthStore>();
  late final DateTime? _saved = _store.profile.birthDate;

  /// The birthday on the wheel: the saved one, or a starting guess.
  late DateTime _birth =
      _saved ?? DateTime(_store.today.year - 30, _store.today.month, 1);

  /// Set once the wheel is moved, so an untouched wheel never saves the
  /// starting guess.
  bool _moved = false;
  bool _busy = false;

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_moved && _birth != _saved) {
        await _store.updateProfile(_store.profile.copyWith(birthDate: _birth));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) widget.nav.onDone(false);
  }

  @override
  Widget build(BuildContext context) {
    final nav = widget.nav;
    final today = _store.today;
    final chosen = _moved || _saved != null;
    final age = UserProfile(birthDate: _birth).ageOn(today);
    return SetupPage(
      icon: Icons.waving_hand_rounded,
      color: Palette.yellow,
      title: 'Nice to Meet You',
      subtitle:
          'What should Health call you? Your birthday helps it estimate '
          'calories and heart rate zones.',
      step: nav.step,
      steps: nav.steps,
      onBack: nav.onBack,
      onSkip: () => nav.onDone(true),
      onContinue: _save,
      busy: _busy,
      children: [
        Text(
          'YOUR NAME',
          style: context.overline.copyWith(color: context.secondaryLabel),
        ),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: widget.name,
          placeholder: tr('First name'),
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.givenName],
          style: context.title3,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefix: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Icon(Icons.person_rounded, color: context.secondaryLabel),
          ),
          decoration: BoxDecoration(
            color: context.cardBackground,
            borderRadius: context.cardBorderRadius(AppTheme.listRadius),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: Text(
                'YOUR BIRTHDAY',
                style: context.overline.copyWith(color: context.secondaryLabel),
              ),
            ),
            _AgeBadge(text: chosen && age != null ? '$age years old' : null),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          decoration: ShapeDecoration(
            color: context.cardBackground,
            shape: AppTheme.squircle(context.cardRadius(AppTheme.listRadius)),
          ),
          clipBehavior: Clip.antiAlias,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: _birth,
            minimumDate: DateTime(today.year - _maxYears),
            maximumDate: today,
            onDateTimeChanged: (d) {
              HapticFeedback.selectionClick();
              setState(() {
                _birth = DateTime(d.year, d.month, d.day);
                _moved = true;
              });
            },
          ),
        ),
      ],
    );
  }
}

/// The age worked out from the birthday, or a hint to scroll.
class _AgeBadge extends StatelessWidget {
  const _AgeBadge({required this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final text = this.text;
    return AnimatedSwitcher(
      duration: Motion.reduced(context) ? Duration.zero : Motion.medium,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: a, child: child),
      ),
      child: text == null
          ? Text(
              'Scroll to choose',
              key: const ValueKey('hint'),
              style: context.caption1.copyWith(color: context.tertiaryLabel),
            )
          : Container(
              key: ValueKey(text),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: ShapeDecoration(
                color: context.tint.withValues(alpha: 0.16),
                shape: const StadiumBorder(),
              ),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  text,
                  style: context.caption1.copyWith(
                    color: context.isDark ? context.tint : context.labelColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
    );
  }
}
