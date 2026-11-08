import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:health_app/l10n/text.dart';

/// Shared motion values (see DESIGN.md): quick to respond, smooth to
/// settle, and never in the way.
abstract final class Motion {
  /// Press-down and toggles.
  static const instant = Duration(milliseconds: 90);

  /// Small fades and selection changes.
  static const fast = Duration(milliseconds: 150);

  /// Section entrances, the tab indicator and cross-fades.
  static const medium = Duration(milliseconds: 240);

  /// Numbers counting, and rings and bars filling.
  static const slow = Duration(milliseconds: 400);

  /// Delay between staggered entrances, and how many items stagger; the
  /// rest appear with the last, so a sequence stays under 400 ms.
  static const stagger = Duration(milliseconds: 25);
  static const staggerCount = 6;

  static const curve = Curves.easeOutCubic;
  static const spring = Curves.easeOutBack;

  /// True when the user asked the system to reduce or remove animations.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Endless decorative animations (a beating heart, a pulse line, cards
  /// wiggling while editing). Tests turn them off so screens can settle.
  static bool ambient = true;

  /// Whether endless animations should run here.
  static bool ambientOn(BuildContext context) =>
      ambient && !reduced(context) && TickerMode.valuesOf(context).enabled;
}

/// Fades, lifts and gently scales [child] into place when it first appears,
/// staggered by
/// [index]. Plays once; rebuilds don't replay it.
class Appear extends StatefulWidget {
  const Appear({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> {
  /// Fixed when first built, so later rebuilds never restart the animation.
  late final Duration _delay;

  /// Sections built because the list scrolled (including ones rebuilt when
  /// scrolled back to) just appear, so long lists never flicker.
  late final bool _animate;

  @override
  void initState() {
    super.initState();
    // Staggered on first show only.
    final p = context.findAncestorStateOfType<ScrollableState>()?.position;
    final scrolled =
        p != null &&
        p.hasPixels &&
        p.hasContentDimensions &&
        p.pixels > p.minScrollExtent + 1;
    _animate = !scrolled;
    _delay = Motion.stagger * widget.index.clamp(0, Motion.staggerCount);
  }

  @override
  Widget build(BuildContext context) {
    if (!_animate || Motion.reduced(context)) return widget.child;
    return widget.child
        .animate(delay: _delay)
        .fadeIn(duration: Motion.medium, curve: Motion.curve)
        .slideY(
          begin: 0.06,
          end: 0,
          duration: Motion.medium,
          curve: Motion.curve,
        )
        .scaleXY(
          begin: 0.98,
          end: 1,
          duration: Motion.medium,
          curve: Motion.curve,
        );
  }
}

/// Shrinks slightly while pressed and springs back, with a light haptic.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.97,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    if (onTap == null) return widget.child;
    void tap() {
      HapticFeedback.selectionClick();
      onTap();
    }

    final label = widget.semanticLabel;
    return Semantics(
      button: true,
      label: label,
      // A given label replaces the content's own text, keeping the tap,
      // and stays a separate item for screen readers.
      container: label != null,
      excludeSemantics: label != null,
      onTap: label != null ? tap : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: tap,
        // Shrinks and dims a touch while held, then springs back, as
        // iOS cards do.
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: _down ? Motion.instant : Motion.medium,
          curve: _down ? Curves.easeOut : Motion.spring,
          child: AnimatedOpacity(
            opacity: _down ? 0.86 : 1,
            duration: _down ? Motion.instant : Motion.medium,
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// A number that counts smoothly to its new value.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.maxLines = 1,
    this.suffix,
    this.suffixStyle,
  });

  final double value;
  final String Function(double) format;
  final TextStyle? style;
  final int maxLines;

  /// Smaller trailing text such as a unit ("KCAL").
  final String? suffix;
  final TextStyle? suffixStyle;

  Widget _text(String text) {
    final s = suffix;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text, style: style),
          if (s != null) TextSpan(text: s, style: suffixStyle ?? style),
        ],
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = format(value);
    if (Motion.reduced(context)) return _text(text);
    return Semantics(
      label: '$text${suffix ?? ''}',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value),
        duration: Motion.slow,
        curve: Motion.curve,
        builder: (context, v, _) => _text(format(v)),
      ),
    );
  }
}
