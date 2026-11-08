import 'dart:ui';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/services.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';
import 'package:health_app/widgets/motion.dart';

class GlassTab {
  const GlassTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Floating frosted-glass tab bar, as on iPhone: a translucent capsule
/// that blurs the content behind it, an icon and label for every tab, and
/// a soft glass highlight that glides to the selected tab.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({
    super.key,
    required this.tabs,
    required this.index,
    required this.onTap,
  });

  /// The glass: mostly see-through, so content shows blurred behind it.
  static const _glass = CupertinoDynamicColor.withBrightness(
    color: Color(0xA6FFFFFF),
    darkColor: Color(0x8C1C1C22),
  );

  /// The thin bright rim that catches the light on the glass's edge.
  static const _rim = CupertinoDynamicColor.withBrightness(
    color: Color(0x99FFFFFF),
    darkColor: Color(0x1FFFFFFF),
  );

  /// The highlight behind the selected tab.
  static const _highlight = CupertinoDynamicColor.withBrightness(
    color: Color(0x14000000),
    darkColor: Color(0x24FFFFFF),
  );

  /// How far the highlight sits inside the capsule.
  static const _inset = 5.0;

  /// A gentle spring: it settles with a hint of overshoot, never a bounce.
  static const _glide = Cubic(0.25, 1.1, 0.4, 1);

  final List<GlassTab> tabs;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    // A style draws the bar as one of its cards.
    final skin = context.skin;
    final outline = context.cardOutline;
    final duration = Motion.reduced(context)
        ? Duration.zero
        : const Duration(milliseconds: 380);
    final docked = skin?.dockedTabBar ?? false;
    final tabsRow = LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth / tabs.length;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: duration,
              curve: _glide,
              left: w * index + _inset,
              top: _inset,
              bottom: _inset,
              width: w - _inset * 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.resolve(_highlight),
                  borderRadius: BorderRadius.circular(docked ? 8 : 27),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(child: _item(context, i, duration)),
              ],
            ),
          ],
        );
      },
    );
    if (docked) {
      // Full width along the bottom edge, like a classic tab bar.
      return DecoratedBox(
        decoration: BoxDecoration(
          color: context.cardBackground,
          border: Border(
            top: outline == BorderSide.none
                ? BorderSide(color: context.separatorColor)
                : outline,
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(height: 64, child: tabsRow),
        ),
      );
    }
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: skin != null && skin.shadow == SkinShadow.hard
                ? context.cardShadows
                : [
                    BoxShadow(
                      color: context.isDark
                          ? const Color(0x66000000)
                          : const Color(0x1F101828),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                height: 64,
                decoration: ShapeDecoration(
                  color: skin == null
                      ? context.resolve(_glass)
                      : context.cardBackground.withValues(alpha: 0.94),
                  shape: context.outlinedShape(
                    32,
                    outline == BorderSide.none
                        ? BorderSide(color: context.resolve(_rim), width: 0.8)
                        : outline,
                  ),
                ),
                child: tabsRow,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int i, Duration duration) {
    final selected = i == index;
    final color = selected ? context.tint : context.secondaryLabel;
    void tap() {
      HapticFeedback.selectionClick();
      onTap(i);
    }

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: tabs[i].label,
      onTap: tap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.08 : 1,
              duration: duration,
              curve: _glide,
              child: Icon(tabs[i].icon, color: color, size: 22),
            ),
            const SizedBox(height: 2),
            Text(
              tabs[i].label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: AppTheme.type(
                10,
                selected ? FontWeight.w700 : FontWeight.w600,
                color: color,
                family: context.skin?.fontFamily,
              ),
              textScaler: MediaQuery.textScalerOf(context)
                  .clamp(maxScaleFactor: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}
