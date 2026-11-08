import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/foundation.dart';

/// A section of a tab that can be moved or hidden.
abstract interface class LayoutSection implements Enum {
  String get label;
  IconData get icon;
}

/// Sections of the Fitness tab, in their default order.
enum FitnessSection implements LayoutSection {
  today('Today\'s Plan', Icons.today_rounded),
  suggestion('Suggested Today', Icons.bolt_rounded),
  week('This Week', Icons.pie_chart_rounded),
  program('Program', Icons.flag_circle_rounded),
  start('Start a Workout', Icons.play_circle_rounded),
  library('Exercise Library', Icons.menu_book_rounded),
  routines('Routines', Icons.format_list_bulleted_rounded),
  progress('Progress', Icons.insights_rounded),
  records('Personal Records', Icons.workspace_premium_rounded),
  history('History', Icons.schedule_rounded);

  const FitnessSection(this.label, this.icon);

  @override
  final String label;
  @override
  final IconData icon;
}

/// Sections of the Health tab, in their default order.
enum HealthSection implements LayoutSection {
  vitals('Vitals Now', Icons.monitor_heart_rounded),
  categories('Categories', Icons.view_agenda_rounded),
  more('Trends & Trackers', Icons.insights_rounded),
  allData('Your Widgets', Icons.widgets_rounded);

  const HealthSection(this.label, this.icon);

  @override
  final String label;
  @override
  final IconData icon;
}

/// The order of a tab's sections and which are hidden. Immutable.
@immutable
class TabLayout<T extends LayoutSection> {
  const TabLayout(this.order, [this.hidden = const {}]);

  /// Every section, in display order.
  final List<T> order;
  final Set<T> hidden;

  List<T> get visible => [
    for (final s in order)
      if (!hidden.contains(s)) s,
  ];

  TabLayout<T> withVisible(T section, bool visible) => TabLayout(
    order,
    Set.unmodifiable(
      visible ? ({...hidden}..remove(section)) : {...hidden, section},
    ),
  );

  /// Moves the section at index [from] so it ends up at [to].
  TabLayout<T> withMoved(int from, int to) {
    if (from < 0 || from >= order.length) return this;
    final list = [...order];
    final s = list.removeAt(from);
    list.insert(to.clamp(0, list.length), s);
    return TabLayout(List.unmodifiable(list), hidden);
  }

  Map<String, Object?> toJson() => {
    'order': [for (final s in order) s.name],
    'hidden': [for (final s in hidden) s.name],
  };

  /// Reads a saved layout; unknown names are dropped and sections added in
  /// later versions appear where they sit in the standard order.
  static TabLayout<T> fromJson<T extends LayoutSection>(
    Object? json,
    List<T> all,
  ) {
    T? byName(Object? n) => all.where((s) => s.name == n).firstOrNull;
    List<Object?> list(Object? v) => v is List ? v : const [];
    final map = json is Map<String, Object?> ? json : const {};
    final saved = {for (final n in list(map['order'])) ?byName(n)};
    final order = [...saved];
    // Sections added later go after the one before them in the standard
    // order (or first).
    for (final s in all) {
      if (order.contains(s)) continue;
      final i = all.indexOf(s);
      final before = all.take(i).lastWhere(order.contains, orElse: () => s);
      order.insert(before == s ? 0 : order.indexOf(before) + 1, s);
    }
    return TabLayout(
      List.unmodifiable(order),
      Set.unmodifiable({for (final n in list(map['hidden'])) ?byName(n)}),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TabLayout<T> &&
      listEquals(other.order, order) &&
      setEquals(other.hidden, hidden);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(order), Object.hashAllUnordered(hidden));
}
