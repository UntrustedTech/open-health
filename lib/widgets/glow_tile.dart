import 'dart:math' as math;

import 'package:flutter/cupertino.dart' hide Text;

import 'package:health_app/l10n/text.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';

/// The app's data tile: a small coloured glyph and title, a big value, and
/// a chart or ring, on a white card with a pastel icon chip. Used for
/// Health categories, trackers and settings so they all share one look.
class GlowTile extends StatelessWidget {
  const GlowTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.value,
    this.placeholder = 'No data yet',
    this.accessory,
    this.semanticLabel,
  });

  final IconData icon;

  /// A plain or dynamic colour; resolved for light and dark.
  final Color color;
  final String title;

  /// The headline number or state. Shows [placeholder] if null.
  final String? value;
  final String placeholder;

  /// Top-right decoration, e.g. a [Sparkline] or [MiniRing] (32 high).
  final Widget? accessory;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final titleStyle = context.footnote.copyWith(
      color: context.secondaryLabel,
      fontWeight: FontWeight.w600,
    );
    final c = context.resolve(color);
    final value = this.value;
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel ?? '$title, ${value ?? placeholder}',
      onTap: onTap,
      excludeSemantics: true,
      child: IosCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.pastel(c),
                  ),
                  child: Icon(icon, color: c, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  // One long word (e.g. in a wide theme font) shrinks to
                  // fit instead of breaking mid-word.
                  child: title.contains(' ')
                      ? Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(title, maxLines: 1, style: titleStyle),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Wraps rather than shrinking, so large text stays large.
            Text(
              value ?? placeholder,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: value == null
                  ? context.footnote.copyWith(color: context.secondaryLabel)
                  : context
                        .number(19, weight: FontWeight.w600)
                        .copyWith(color: context.labelColor),
            ),
            // Room for a chart or ring only when there is one.
            if (accessory case final a?) ...[
              const SizedBox(height: 8),
              SizedBox(height: 32, width: double.infinity, child: a),
            ],
          ],
        ),
      ),
    );
  }
}

/// Two-column grid of tiles; a lone last tile spans the row. Each tile
/// fades in after the one before it.
class GlowGrid extends StatelessWidget {
  const GlowGrid({super.key, required this.children});

  static const gap = 10.0;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final w = (c.maxWidth - gap) / 2;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final (i, tile) in children.indexed)
            SizedBox(
              width: i == children.length - 1 && children.length.isOdd
                  ? c.maxWidth
                  : w,
              child: Appear(index: i, child: tile),
            ),
        ],
      );
    },
  );
}

/// A small progress ring for a tile's corner.
class MiniRing extends StatelessWidget {
  const MiniRing({super.key, required this.progress, required this.color});

  /// 0..1.
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: SizedBox.square(
      dimension: 30,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress.clamp(0, 1).toDouble()),
        duration: Motion.reduced(context) ? Duration.zero : Motion.slow,
        curve: Motion.curve,
        builder: (context, p, _) => CustomPaint(
          painter: _RingPainter(
            p,
            context.resolve(color),
            context.resolve(color).withValues(alpha: 0.18),
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color, this.track);

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

/// Big icon, title and a line of explanation at the top of a settings
/// page.
class SettingsHero extends StatelessWidget {
  const SettingsHero({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.resolve(color);
    return IosCard(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 22),
      child: Column(
        children: [
          IconTile(icon: icon, color: c, size: 56, solid: true),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.title2.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: context.subheadline.copyWith(color: context.secondaryLabel),
          ),
        ],
      ),
    );
  }
}
