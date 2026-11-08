import 'package:flutter/widgets.dart';

/// Lets screens inside the shell switch tabs (e.g. the Summary avatar opens
/// Profile).
class ShellTabs extends InheritedWidget {
  const ShellTabs({super.key, required this.select, required super.child});

  static const summary = 0;
  static const health = 1;
  static const food = 2;
  static const fitness = 3;
  static const profile = 4;

  final ValueChanged<int> select;

  static ShellTabs? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellTabs>();

  @override
  bool updateShouldNotify(ShellTabs old) => false;
}
