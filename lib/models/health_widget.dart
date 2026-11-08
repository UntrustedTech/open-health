import 'package:flutter/foundation.dart';

import 'package:health_app/models/metric_type.dart';

/// How much room a widget takes: small is half a row; medium is a whole
/// row laid out like a small one; large is a whole row with a bigger
/// visual and more data (or a full card).
enum WidgetSize {
  small('Small'),
  medium('Medium'),
  large('Large');

  const WidgetSize(this.label);

  final String label;

  /// Whether it takes a row of its own.
  bool get fullWidth => this != small;

  /// The next of [sizes] after this one, back to the first after the
  /// largest: what tapping the resize badge changes it to.
  WidgetSize nextIn(Set<WidgetSize> sizes) {
    final ordered = [
      for (final s in values)
        if (sizes.contains(s)) s,
    ];
    if (ordered.isEmpty) return this;
    return ordered.firstWhere(
      (s) => s.index > index,
      orElse: () => ordered.first,
    );
  }

  /// Reads a saved size. Before there were three sizes, the full-row size
  /// was saved as "wide": what large is now.
  static WidgetSize fromName(Object? name) => name == 'wide'
      ? large
      : values.firstWhere((s) => s.name == name, orElse: () => small);
}

/// One metric on the Health tab's customizable widget grid.
@immutable
class HealthWidget {
  const HealthWidget(this.metric, this.size);

  final MetricType metric;
  final WidgetSize size;

  @override
  bool operator ==(Object other) =>
      other is HealthWidget && other.metric == metric && other.size == size;

  @override
  int get hashCode => Object.hash(metric, size);

  @override
  String toString() => 'HealthWidget(${metric.name}, ${size.name})';
}

/// Where a widget sits in the two-column grid. Widgets fill rows in order:
/// small ones pair up, and a medium or large one takes a row of its own (starting
/// a new row if a small one is waiting for a partner).
@immutable
class WidgetSlot {
  const WidgetSlot(this.widget, this.row, this.column);

  final HealthWidget widget;
  final int row;

  /// 0 (left) or 1 (right); always 0 for a full-row widget.
  final int column;

  static List<WidgetSlot> layout(List<HealthWidget> widgets) {
    final slots = <WidgetSlot>[];
    var row = 0;
    var column = 0;
    for (final w in widgets) {
      if (w.size.fullWidth) {
        if (column == 1) row++;
        slots.add(WidgetSlot(w, row, 0));
        row++;
        column = 0;
      } else {
        slots.add(WidgetSlot(w, row, column));
        if (column == 1) row++;
        column = 1 - column;
      }
    }
    return List.unmodifiable(slots);
  }

  /// Rows the [slots] take up.
  static int rows(List<WidgetSlot> slots) => slots.isEmpty
      ? 0
      : slots.map((s) => s.row).reduce((a, b) => a > b ? a : b) + 1;
}
