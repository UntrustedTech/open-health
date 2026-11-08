import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/widgets/motion.dart';

/// The app's segmented control: a capsule track with a raised neutral
/// thumb that slides to the chosen segment. Segments share the width.
class AppSegmented<T extends Object> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.groupValue,
    required this.children,
    required this.onValueChanged,
  });

  static const height = 40.0;

  /// Tall enough that each segment is a comfortable tap target.
  static const minTrack = 44.0;
  static const _inset = 3.0;

  final T? groupValue;
  final Map<T, Widget> children;

  /// Null disables the control.
  final ValueChanged<T?>? onValueChanged;

  @override
  Widget build(BuildContext context) {
    final keys = children.keys.toList();
    final index = groupValue == null ? -1 : keys.indexOf(groupValue as T);
    final dark = context.isDark;
    final thumb = dark ? const Color(0xFF3A3A3F) : CupertinoColors.white;
    final onThumb = context.labelColor;
    final duration = Motion.reduced(context) ? Duration.zero : Motion.medium;
    final enabled = onValueChanged != null;
    // Grows a little with large text; labels shrink to fit beyond that.
    final trackHeight = MediaQuery.textScalerOf(context)
        .scale(height)
        .clamp(minTrack, height * 1.4);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        height: trackHeight,
        padding: const EdgeInsets.all(_inset),
        decoration: ShapeDecoration(
          color: context.fillColor,
          shape: const StadiumBorder(),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            // In a row with no width limit, size to the labels instead.
            if (!c.hasBoundedWidth) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, key) in keys.indexed)
                    AnimatedContainer(
                      duration: duration,
                      constraints: const BoxConstraints(minWidth: 56),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: ShapeDecoration(
                        shape: const StadiumBorder(),
                        color: i == index ? thumb : null,
                      ),
                      child: _segment(
                        context,
                        key,
                        selected: i == index,
                        onThumb: onThumb,
                      ),
                    ),
                ],
              );
            }
            final w = c.maxWidth / keys.length;
            return Stack(
              children: [
                if (index >= 0)
                  AnimatedPositioned(
                    duration: duration,
                    curve: Motion.spring,
                    left: w * index,
                    width: w,
                    top: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: const StadiumBorder(),
                        color: thumb,
                      ),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, key) in keys.indexed)
                      Expanded(
                        child: _segment(
                          context,
                          key,
                          selected: i == index,
                          onThumb: onThumb,
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    T key, {
    required bool selected,
    required Color onThumb,
  }) {
    final onChanged = onValueChanged;
    final color = selected ? onThumb : context.secondaryLabel;
    final VoidCallback? tap = onChanged == null || selected
        ? null
        : () {
            HapticFeedback.selectionClick();
            onChanged(key);
          };
    return Semantics(
      button: true,
      selected: selected,
      enabled: onChanged != null,
      onTap: tap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Center(
            // Long labels at large text sizes shrink rather than cut off.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: IconTheme.merge(
                data: IconThemeData(color: color, size: 18),
                child: DefaultTextStyle.merge(
                  style: context.subheadline.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  child: children[key]!,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
