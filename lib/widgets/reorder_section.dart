import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';

import 'package:health_app/l10n/text.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';
import 'package:health_app/widgets/motion.dart';
import 'package:health_app/widgets/ios.dart';

/// Navigation bar for a sheet, with a bold "Done".
CupertinoNavigationBar sheetBar(BuildContext context, String title) =>
    CupertinoNavigationBar(
      // Sheets don't morph the title from the page below, as on iOS;
      // every bar shares one hero tag, so it would fly into the sheet.
      transitionBetweenRoutes: false,
      automaticallyImplyLeading: false,
      middle: Text(title),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.of(context).pop(),
        child: const Text(
          'Done',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );

/// An inset-grouped section whose rows can be dragged into a new order by
/// their handles, as in iOS edit mode. Rows should be [ReorderRow]s.
class ReorderSection extends StatelessWidget {
  const ReorderSection({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.onReorder,
    this.header,
    this.footer,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Called with the item's old index and its new final index.
  final void Function(int from, int to) onReorder;
  final String? header;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final h = header, f = footer;
    final note = context.footnote.copyWith(color: context.secondaryLabel);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (h != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Text(h.toUpperCase(), style: note),
            ),
          ClippedCard(
            child: ReorderableList(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: itemCount,
              itemBuilder: itemBuilder,
              onReorderStart: (_) => HapticFeedback.selectionClick(),
              onReorderItem: (from, to) {
                HapticFeedback.lightImpact();
                onReorder(from, to);
              },
              proxyDecorator: (child, _, animation) => AnimatedBuilder(
                animation: animation,
                builder: (context, child) => Transform.scale(
                  scale: 1 + 0.03 * Motion.curve.transform(animation.value),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: context.cardBackground,
                      shape: AppTheme.squircle(
                        context.cardRadius(AppTheme.listRadius),
                      ),
                      shadows: [
                        BoxShadow(
                          color: const Color(0x33000000),
                          blurRadius: 18 * animation.value,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
                child: child,
              ),
            ),
          ),
          if (f != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(f, style: note),
            ),
        ],
      ),
    );
  }
}

/// A row in a [ReorderSection], with a drag handle on the right.
class ReorderRow extends StatelessWidget {
  const ReorderRow({
    required super.key,
    required this.index,
    required this.title,
    this.leading,
    this.trailing,
    this.subtitle,
  });

  final int index;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final lead = leading, trail = trailing, sub = subtitle;
    return Container(
      constraints: const BoxConstraints(minHeight: AppTheme.minTapTarget + 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.separatorColor, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        children: [
          if (lead != null) ...[lead, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: context.body),
                if (sub != null)
                  Text(
                    sub,
                    style: context.footnote.copyWith(
                      color: context.secondaryLabel,
                    ),
                  ),
              ],
            ),
          ),
          ?trail,
          ReorderableDragStartListener(
            index: index,
            child: Semantics(
              label: 'Reorder $title',
              child: SizedBox.square(
                dimension: AppTheme.minTapTarget,
                child: Icon(
                  Icons.drag_handle_rounded,
                  color: context.tertiaryLabel,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
