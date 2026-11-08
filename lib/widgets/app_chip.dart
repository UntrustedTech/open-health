import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/services.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/motion.dart';

/// The one chip style used across the app for filters and choices: a
/// capsule that inverts (label colour fill) when selected, or fills with
/// [color] when one is given. [outlined]
/// chips are for a second, quieter row of filters.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.icon,
    this.outlined = false,
    this.semanticLabel,
  });

  static const height = 34.0;

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Selected fill; defaults to the label colour (an inverted chip).
  final Color? color;
  final IconData? icon;
  final bool outlined;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.labelColor;
    final Color fill;
    final Color fg;
    final BorderSide side;
    if (outlined) {
      fill = selected ? c.withValues(alpha: 0.14) : const Color(0x00000000);
      fg = selected ? c : context.labelColor;
      side = BorderSide(
        color: selected ? c : context.separatorColor,
        width: selected ? 1.5 : 1,
      );
    } else {
      fill = selected ? c : context.fillColor;
      // Ink on the bright dark-mode accents, white on the deeper light ones.
      fg = selected ? context.onLabel : context.labelColor;
      side = BorderSide.none;
    }
    void tap() {
      HapticFeedback.selectionClick();
      onTap();
    }

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      onTap: tap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        // The pill is [height] tall; the clear band around it makes the
        // tap area the full 44pt.
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: (AppTheme.minTapTarget - height) / 2,
          ),
          child: AnimatedContainer(
            duration: Motion.reduced(context) ? Duration.zero : Motion.fast,
            curve: Motion.curve,
            constraints: const BoxConstraints(minHeight: height),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: ShapeDecoration(
              color: fill,
              shape: StadiumBorder(side: side),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon case final i?) ...[
                  Icon(
                    i,
                    size: 14,
                    color: selected ? fg : context.secondaryLabel,
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: context.subheadline.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A horizontally scrolling row of [AppChip]s.
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: AppTheme.minTapTarget,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) => Center(child: children[i]),
    ),
  );
}
