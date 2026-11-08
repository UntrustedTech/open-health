import 'package:flutter/cupertino.dart' hide Text;

import 'package:health_app/l10n/text.dart';
import 'package:health_app/theme/app_theme.dart';

/// Shows [picker] in a bottom sheet and returns true if it was confirmed
/// with [doneLabel]. With a [title] the header also has Cancel; without one
/// it is just the confirm button on the right.
Future<bool> showPickerSheet(
  BuildContext context, {
  required Widget picker,
  required String doneLabel,
  String? title,
}) async {
  final ok = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (context) {
      final done = CupertinoButton(
        onPressed: () => Navigator.pop(context, true),
        child: Text(doneLabel),
      );
      return Container(
        height: 300,
        color: context.cardBackground,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              if (title == null)
                Align(alignment: Alignment.centerRight, child: done)
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    Text(title, style: context.headline),
                    done,
                  ],
                ),
              Expanded(child: picker),
            ],
          ),
        ),
      );
    },
  );
  return ok == true;
}

/// Action sheet listing [options] by [label], with [current] as the default
/// action. Returns the chosen option, or null if cancelled.
Future<T?> pickFromSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required String Function(T) label,
  required T current,
  String? message,
}) => showCupertinoModalPopup<T>(
  context: context,
  builder: (context) => CupertinoActionSheet(
    title: Text(title),
    message: message == null ? null : Text(message),
    actions: [
      for (final o in options)
        CupertinoActionSheetAction(
          isDefaultAction: o == current,
          onPressed: () => Navigator.pop(context, o),
          child: Text(label(o)),
        ),
    ],
    cancelButton: CupertinoActionSheetAction(
      onPressed: () => Navigator.pop(context),
      child: const Text('Cancel'),
    ),
  ),
);

/// A [CupertinoPicker] that starts at [initialItem] and disposes the
/// scroll controller it needs for that.
class WheelPicker extends StatefulWidget {
  const WheelPicker({
    super.key,
    required this.initialItem,
    required this.onSelectedItemChanged,
    required this.children,
    this.itemExtent = 36,
  });

  final int initialItem;
  final ValueChanged<int> onSelectedItemChanged;
  final List<Widget> children;
  final double itemExtent;

  @override
  State<WheelPicker> createState() => _WheelPickerState();
}

class _WheelPickerState extends State<WheelPicker> {
  late final _controller = FixedExtentScrollController(
    initialItem: widget.initialItem,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoPicker(
    itemExtent: widget.itemExtent,
    scrollController: _controller,
    onSelectedItemChanged: widget.onSelectedItemChanged,
    children: widget.children,
  );
}
