import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/screens/legal_screen.dart';
import 'package:health_app/screens/privacy_screen.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/app_mark.dart';
import 'package:health_app/widgets/motion.dart';

/// Who made Health, shown on the welcome page.
const appMaker = 'UntrustedTech';

/// The first thing a new user sees: the app's mark with a slow glow, who
/// made it and why, what it does, and one button to begin.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final tint = context.tint;
    final reduce = Motion.reduced(context);

    // Each part rises into place a moment after the one above it.
    Widget rise(Widget child, int i) => reduce
        ? child
        : child
              .animate(delay: Duration(milliseconds: 260 + 90 * i))
              .fadeIn(duration: Motion.slow, curve: Motion.curve)
              .slideY(
                begin: 0.25,
                end: 0,
                duration: Motion.slow,
                curve: Motion.curve,
              );

    return Stack(
      children: [
        Positioned.fill(child: _Aurora(color: tint)),
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  // Scrolls only when the page doesn't fit (large text,
                  // small screens); otherwise it stays still.
                  primary: false,
                  padding: const EdgeInsets.fromLTRB(28, 48, 28, 16),
                  children: [
                    const Center(child: _Mark()),
                    const SizedBox(height: 28),
                    rise(
                      Text(
                        'Welcome to Health',
                        textAlign: TextAlign.center,
                        style: context.largeTitle,
                      ),
                      0,
                    ),
                    const SizedBox(height: 10),
                    rise(
                      Text(
                        'Made for the people, by the people.',
                        textAlign: TextAlign.center,
                        style: context.body.copyWith(
                          color: context.secondaryLabel,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      1,
                    ),
                    const SizedBox(height: 14),
                    rise(const Center(child: _MakerBadge()), 2),
                    const SizedBox(height: 36),
                    rise(
                      const _Feature(
                        icon: Icons.grid_view_rounded,
                        color: Palette.orange,
                        title: 'Everything in One Place',
                        text:
                            'Activity, heart, sleep, food and workouts, with '
                            'trends over weeks, months and years.',
                      ),
                      3,
                    ),
                    rise(
                      const _Feature(
                        icon: Icons.lock_rounded,
                        color: Palette.green,
                        title: 'Private by Design',
                        text:
                            'No accounts, ads or trackers. Your data stays on '
                            'this device, encrypted.',
                      ),
                      4,
                    ),
                    rise(
                      const _Feature(
                        icon: Icons.code_rounded,
                        color: Palette.blue,
                        title: 'Free & Transparent',
                        text:
                            'Built in the open, so anyone can see how it '
                            'works and help make it better.',
                      ),
                      5,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: rise(
                  CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(16),
                    onPressed: () {
                      unawaited(HapticFeedback.mediumImpact());
                      onStart();
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Get Started'),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                  6,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 4),
                child: rise(const _Consent(), 7),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What tapping Get Started agrees to, with links to read it (each a
/// full-size button).
class _Consent extends StatelessWidget {
  const _Consent();

  @override
  Widget build(BuildContext context) {
    final style = context.footnote.copyWith(color: context.secondaryLabel);
    Widget link(String label, VoidCallback onTap) => CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      minimumSize: const Size(0, AppTheme.minTapTarget),
      onPressed: onTap,
      child: Text(
        label,
        style: style.copyWith(color: context.tint, fontWeight: FontWeight.w600),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'By tapping Get Started, you agree to the Terms of Use and '
          'Privacy Policy.',
          textAlign: TextAlign.center,
          style: style,
        ),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            link('Terms of Use', () => LegalScreen.openTerms(context)),
            link('Privacy Policy', () => PrivacyScreen.open(context)),
          ],
        ),
      ],
    );
  }
}

/// The app's mark: pops in, then breathes inside a soft halo.
class _Mark extends StatefulWidget {
  const _Mark();

  @override
  State<_Mark> createState() => _MarkState();
}

class _MarkState extends State<_Mark> with SingleTickerProviderStateMixin {
  late final _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.ambientOn(context)) {
      if (!_breath.isAnimating) unawaited(_breath.repeat(reverse: true));
    } else {
      _breath.stop();
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tint = context.tint;
    const size = 96.0;
    final mark = AnimatedBuilder(
      animation: _breath,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_breath.value);
        return Container(
          width: size,
          height: size,
          decoration: ShapeDecoration(
            color: tint,
            shape: AppTheme.squircle(size * 0.3),
            shadows: [
              BoxShadow(
                color: tint.withValues(alpha: 0.30 + 0.20 * t),
                blurRadius: 36 + 22 * t,
                spreadRadius: 2 + 6 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Center(
        child: AppMark(size: size * 0.6, color: context.onColor(tint)),
      ),
    );
    if (Motion.reduced(context)) return mark;
    return mark
        .animate()
        .scale(
          begin: const Offset(0.6, 0.6),
          end: const Offset(1, 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: Motion.medium);
  }
}

/// "Created by UntrustedTech", in a quiet pill.
class _MakerBadge extends StatelessWidget {
  const _MakerBadge();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Created by $appMaker',
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: ShapeDecoration(
        color: context.fillColor,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_rounded, size: 14, color: context.tint),
          const SizedBox(width: 6),
          Flexible(
            child: Text.rich(
              TextSpan(
                text: 'Created by ',
                children: [
                  TextSpan(
                    text: appMaker,
                    style: TextStyle(
                      color: context.labelColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              style: context.footnote.copyWith(color: context.secondaryLabel),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A slow wash of the accent colour drifting behind the welcome page.
class _Aurora extends StatefulWidget {
  const _Aurora({required this.color});

  final Color color;

  @override
  State<_Aurora> createState() => _AuroraState();
}

class _AuroraState extends State<_Aurora> with SingleTickerProviderStateMixin {
  late final _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.ambientOn(context)) {
      if (!_drift.isAnimating) unawaited(_drift.repeat());
    } else {
      _drift.stop();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strength = context.isDark ? 0.22 : 0.16;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _drift,
        builder: (context, _) {
          final a = _drift.value * 2 * math.pi;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.5 * math.sin(a), -0.75 + 0.1 * math.cos(a)),
                radius: 1.1,
                colors: [
                  widget.color.withValues(alpha: strength),
                  widget.color.withValues(alpha: 0),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// An icon, bold title and description, as on Apple's welcome screens.
class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.resolve(color);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: ShapeDecoration(
              color: c.withValues(alpha: context.isDark ? 0.16 : 0.12),
              shape: AppTheme.squircle(14),
            ),
            child: Icon(icon, color: c, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.headline),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: context.subheadline.copyWith(
                    color: context.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
