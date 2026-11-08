import 'package:flutter/cupertino.dart' hide Text;

import 'package:health_app/l10n/text.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/ios.dart';

/// A sheet in the app's style: the plain page background, a grab handle, a
/// bold title between optional actions, and scrolling content.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.children,
    this.controller,
    this.leading,
    this.trailing,
  });

  final String title;
  final List<Widget> children;

  /// The sheet's scroll controller, so dragging the content can close it.
  final ScrollController? controller;
  final Widget? leading;
  final Widget? trailing;

  /// Width kept for each action, so the title stays centred.
  static const _actionWidth = 96.0;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return CupertinoPageScaffold(
      backgroundColor: const Color(0x00000000),
      child: Stack(
        children: [
          const Positioned.fill(child: PageBackground()),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 38,
                  height: 5,
                  decoration: ShapeDecoration(
                    color: context.tertiaryLabel.withValues(alpha: 0.5),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              SizedBox(
                height: 52,
                child: Row(
                  children: [
                    SizedBox(
                      width: _actionWidth,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: leading,
                      ),
                    ),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.headline.copyWith(fontSize: 17),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: _actionWidth,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: trailing,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: EdgeInsets.fromLTRB(
                    AppTheme.margin,
                    4,
                    AppTheme.margin,
                    32 + bottom,
                  ),
                  children: children,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A sheet header action. [primary] is a filled accent capsule (Add,
/// Save); otherwise plain accent text (Cancel).
class SheetAction extends StatelessWidget {
  const SheetAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final tint = context.tint;
    final enabled = onPressed != null;
    if (!primary) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        onPressed: onPressed,
        // Shrinks at large text sizes to stay in the header.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: context.subheadline.copyWith(
              color: enabled ? tint : context.tertiaryLabel,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    final onTint = context.onLabel;
    return Padding(
      padding: const EdgeInsets.only(right: AppTheme.margin),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, AppTheme.minTapTarget),
        onPressed: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            color: enabled ? tint : context.fillColor,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: context.subheadline.copyWith(
                color: enabled ? onTint : context.tertiaryLabel,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Spaced-capitals label above a block of content in a sheet or page.
class BlockLabel extends StatelessWidget {
  const BlockLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Semantics(
      header: true,
      child: Text(text.toUpperCase(), style: context.overline),
    ),
  );
}
