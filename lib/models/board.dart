import 'package:flutter/foundation.dart';

import 'package:health_app/models/health_widget.dart';

/// The tabs whose content is a customizable board of widgets.
enum BoardTab { health, fitness, food, summary }

/// One widget on a board: what it shows (an id from the tab's catalog,
/// such as `fitness.week` or `metric.steps`) and how big it is.
@immutable
class BoardItem {
  const BoardItem(this.id, this.size);

  final String id;
  final WidgetSize size;

  @override
  bool operator ==(Object other) =>
      other is BoardItem && other.id == id && other.size == size;

  @override
  int get hashCode => Object.hash(id, size);

  @override
  String toString() => 'BoardItem($id, ${size.name})';
}

/// A tab's widgets, in order. Immutable: every change returns a new board.
@immutable
class Board {
  const Board(this.items);

  final List<BoardItem> items;

  List<String> get ids => [for (final i in items) i.id];

  bool contains(String id) => items.any((i) => i.id == id);

  int indexOf(String id) => items.indexWhere((i) => i.id == id);

  /// Adds [id] at the end, unless it's already on the board.
  Board withAdded(String id, WidgetSize size) => contains(id)
      ? this
      : Board(List.unmodifiable([...items, BoardItem(id, size)]));

  Board withRemoved(String id) => contains(id)
      ? Board(
          List.unmodifiable([
            for (final i in items)
              if (i.id != id) i,
          ]),
        )
      : this;

  Board withSize(String id, WidgetSize size) => contains(id)
      ? Board(
          List.unmodifiable([
            for (final i in items) i.id == id ? BoardItem(id, size) : i,
          ]),
        )
      : this;

  /// Moves the item at [from] so it ends up at [to].
  Board withMoved(int from, int to) {
    if (from < 0 || from >= items.length) return this;
    final list = [...items];
    final item = list.removeAt(from);
    list.insert(to.clamp(0, list.length), item);
    return Board(List.unmodifiable(list));
  }

  List<Map<String, Object?>> toJson() => [
    for (final i in items) {'id': i.id, 'size': i.size.name},
  ];

  /// Reads a saved board, keeping only ids in [known], once each.
  static Board fromJson(Object? json, {required Set<String> known}) {
    final seen = <String>{};
    return Board(
      List.unmodifiable([
        if (json is List)
          for (final e in json)
            if (e is Map && e['id'] is String)
              if (known.contains(e['id']) && seen.add(e['id'] as String))
                BoardItem(e['id'] as String, WidgetSize.fromName(e['size'])),
      ]),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Board && listEquals(other.items, items);

  @override
  int get hashCode => Object.hashAll(items);

  @override
  String toString() => 'Board($items)';
}
