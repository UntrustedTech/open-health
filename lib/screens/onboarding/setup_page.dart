import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';

/// One page of the welcome setup: a progress bar with Back and Skip, a big
/// glossy icon, a title and explanation, the page's controls and a pinned
/// Continue button.
class SetupPage extends StatelessWidget {
  const SetupPage({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.children,
    required this.onContinue,
    this.step,
    this.steps,
    this.onBack,
    this.onSkip,
    this.continueLabel = 'Continue',
    this.busy = false,
    this.secondary,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<Widget> children;

  /// 1-based position in the setup, for the progress bar.
  final int? step;
  final int? steps;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final VoidCallback? onContinue;
  final String continueLabel;
  final bool busy;

  /// Optional text button under Continue.
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final c = context.resolve(color);
    final step = this.step, steps = this.steps;
    // No leaving the page while its work is in progress.
    final onBack = busy ? null : this.onBack;
    final onSkip = busy ? null : this.onSkip;
    return Stack(
      children: [
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: AppTheme.minTapTarget,
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: onBack == null
                          ? null
                          : CupertinoButton(
                              padding: const EdgeInsets.only(left: 8),
                              onPressed: onBack,
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                semanticLabel: tr('Back'),
                              ),
                            ),
                    ),
                    Expanded(
                      child: step == null || steps == null
                          ? const SizedBox.shrink()
                          : _Progress(step: step, steps: steps),
                    ),
                    SizedBox(
                      width: 72,
                      child: onSkip == null
                          ? null
                          : CupertinoButton(
                              padding: const EdgeInsets.only(right: 8),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                onSkip();
                              },
                              // Shrinks rather than wraps at large text sizes.
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Skip', maxLines: 1),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  // Scrolls only when the page doesn't fit (large text,
                  // small screens); otherwise it stays still.
                  primary: false,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  children: [
                    Center(
                      child: _HeroIcon(icon: icon, color: c),
                    ),
                    const SizedBox(height: 20),
                    Appear(
                      index: 1,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: context.largeTitle,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Appear(
                      index: 2,
                      child: Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: context.body.copyWith(
                          color: context.secondaryLabel,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    for (final (i, child) in children.indexed)
                      Appear(index: 3 + i, child: child),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CupertinoButton.filled(
                      borderRadius: BorderRadius.circular(16),
                      onPressed: busy ? null : onContinue,
                      child: busy
                          ? const CupertinoActivityIndicator(
                              color: CupertinoColors.white,
                            )
                          : Text(continueLabel),
                    ),
                    ?secondary,
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.steps});

  final int step;
  final int steps;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Step $step of $steps',
    excludeSemantics: true,
    child: Row(
      children: [
        for (var i = 1; i <= steps; i++) ...[
          if (i > 1) const SizedBox(width: 4),
          Expanded(
            child: AnimatedContainer(
              duration: Motion.reduced(context) ? Duration.zero : Motion.medium,
              curve: Motion.curve,
              height: 4,
              decoration: ShapeDecoration(
                shape: const StadiumBorder(),
                color: i <= step ? context.tint : context.fillColor,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// A labelled − value + row for setup pages.
class SetupStepper extends StatelessWidget {
  const SetupStepper({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData i, String label, VoidCallback? onTap) =>
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(AppTheme.minTapTarget),
          onPressed: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap();
                },
          child: Icon(i, size: 30, semanticLabel: tr('$label $title')),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          IconTile(icon: icon, color: context.resolve(color)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.subheadline),
                Text(
                  value,
                  style: context.headline.copyWith(
                    color: context.resolve(color),
                  ),
                ),
              ],
            ),
          ),
          button(Icons.remove_circle_rounded, 'Decrease', onMinus),
          button(Icons.add_circle_rounded, 'Increase', onPlus),
        ],
      ),
    );
  }
}

/// The page's big icon: springs in with a soft glow of its colour.
class _HeroIcon extends StatelessWidget {
  const _HeroIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const size = 76.0;
    final tile = Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: color,
        shape: AppTheme.squircle(size * 0.3),
      ),
      child: Icon(icon, size: size * 0.56, color: context.onColor(color)),
    );
    if (Motion.reduced(context)) return tile;
    return tile
        .animate()
        .fadeIn(duration: Motion.fast)
        .scale(
          begin: const Offset(0.7, 0.7),
          end: const Offset(1, 1),
          duration: Motion.medium,
          curve: Motion.spring,
        );
  }
}

/// A selectable option card for setup pages: an icon, a title with an
/// optional badge, a description, and [details] that unfold when chosen.
class SetupChoice extends StatelessWidget {
  const SetupChoice({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.badge,
    this.details,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool selected;

  /// Null shows the option as unavailable.
  final VoidCallback? onTap;

  /// A short tag beside the title, such as "Recommended".
  final String? badge;

  /// More about the option, shown only while it's selected.
  final Widget? details;

  @override
  Widget build(BuildContext context) {
    final tint = context.tint;
    final c = context.resolve(color);
    final duration = Motion.reduced(context) ? Duration.zero : Motion.medium;
    final enabled = onTap != null;
    final details = this.details;
    final badge = this.badge;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: enabled,
      label: [title, ?badge, subtitle].join(', '),
      child: Pressable(
        onTap: onTap,
        scale: 0.98,
        child: AnimatedOpacity(
          duration: duration,
          opacity: enabled ? 1 : 0.45,
          child: AnimatedContainer(
            duration: duration,
            curve: Motion.curve,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: ShapeDecoration(
              color: selected
                  ? Color.alphaBlend(
                      tint.withValues(alpha: 0.10),
                      context.cardBackground,
                    )
                  : context.cardBackground,
              shape: AppTheme.squircle(
                20,
                side: BorderSide(
                  color: selected ? tint : context.separatorColor,
                  width: selected ? 2 : 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconTile(icon: icon, color: c, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ExcludeSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(title, style: context.headline),
                                if (badge != null) _Badge(badge),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: context.footnote.copyWith(
                                color: context.secondaryLabel,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: duration,
                      transitionBuilder: (child, a) =>
                          ScaleTransition(scale: a, child: child),
                      child: Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        key: ValueKey(selected),
                        color: selected ? tint : context.tertiaryLabel,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                if (details != null)
                  AnimatedSize(
                    duration: duration,
                    curve: Motion.curve,
                    alignment: Alignment.topCenter,
                    child: selected
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: details,
                          )
                        : const SizedBox(width: double.infinity),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tint = context.tint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: ShapeDecoration(
        color: tint.withValues(alpha: 0.16),
        shape: const StadiumBorder(),
      ),
      child: Text(
        text.toUpperCase(),
        style: context.caption2.copyWith(
          color: context.isDark ? tint : context.labelColor,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
