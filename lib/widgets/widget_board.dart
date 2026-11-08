import 'dart:async';

import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:health_app/l10n/language.dart';
import 'package:health_app/l10n/text.dart';
import 'package:health_app/models/board.dart';
import 'package:health_app/models/health_widget.dart';
import 'package:health_app/state/health_store.dart';
import 'package:health_app/theme/app_theme.dart';
import 'package:health_app/theme/skin.dart';
import 'package:health_app/widgets/flip_slot.dart';
import 'package:health_app/widgets/ios.dart';
import 'package:health_app/widgets/motion.dart';

/// Something that can be a widget on a tab's board.
@immutable
class BoardEntry {
  const BoardEntry({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.group,
    required this.builder,
    this.sizes = const {WidgetSize.small, WidgetSize.medium, WidgetSize.large},
    this.preferred = WidgetSize.small,
    this.detail,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;

  /// The heading it's listed under in the gallery.
  final String group;

  /// A line under the label in the gallery.
  final String? detail;

  /// The sizes it comes in.
  final Set<WidgetSize> sizes;

  /// The size it's added at, when it comes in that size.
  final WidgetSize preferred;

  /// Builds the widget at [size]. Small widgets get a fixed height; medium
  /// and large ones take a row and are as tall as their content.
  final Widget Function(BuildContext context, WidgetSize size) builder;

  WidgetSize get addedSize =>
      sizes.contains(preferred) ? preferred : sizes.first;

  bool get resizable => sizes.length > 1;
}

/// Whether a board is being edited. Shared by the board and its controls
/// in the page's header.
class BoardController extends ValueNotifier<bool> {
  BoardController() : super(false);

  bool get editing => value;

  void setEditing(bool editing) {
    if (editing == value) return;
    HapticFeedback.mediumImpact();
    value = editing;
  }
}

/// A tab's content as a board of widgets, like the iPhone home screen.
/// While editing, widgets jiggle and can be dragged into a new order,
/// resized and removed; a long press starts editing and dragging at once.
/// Widgets glide to their new places whenever the board changes.
class WidgetBoard extends StatefulWidget {
  const WidgetBoard({
    super.key,
    required this.tab,
    required this.catalog,
    required this.controller,
  });

  final BoardTab tab;
  final List<BoardEntry> catalog;
  final BoardController controller;

  /// Height of a small widget at the standard text size.
  static const smallHeight = 168.0;

  static const gap = AppTheme.gap;

  @override
  State<WidgetBoard> createState() => _WidgetBoardState();
}

class _WidgetBoardState extends State<WidgetBoard> {
  final _boardKey = GlobalKey();

  /// One key per widget, so each keeps its place in memory (and its glide)
  /// when it moves to another row.
  final _keys = <String, GlobalKey>{};

  /// Widgets on the board at the last build; ones not among them are new
  /// and pop in.
  Set<String> _shown = {};

  /// When the last drag swap happened (in frame time); see [_onHover].
  Duration? _lastSwap;

  GlobalKey _keyFor(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  HealthStore get _store => context.read<HealthStore>();

  Board get _board => _store.board(widget.tab);

  void _update(Board board) => _store.updateBoard(widget.tab, board);

  /// A dragged widget over another takes its place. Hovers just after a
  /// swap are ignored while widgets glide, so ones passing under a still
  /// finger don't set off more swaps.
  bool _onHover(String dragged, String target) {
    if (dragged == target) return false;
    // Frame time: the glide this waits for runs on it too.
    final now = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    final last = _lastSwap;
    if (last != null && now - last < Motion.medium + Motion.stagger * 2) {
      return true;
    }
    final b = _board;
    final from = b.indexOf(dragged);
    final to = b.indexOf(target);
    if (from >= 0 && to >= 0) {
      _lastSwap = now;
      HapticFeedback.selectionClick();
      _update(b.withMoved(from, to));
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild only when this tab's board changes; widgets watch their own
    // data.
    context.select<HealthStore, Board>((h) => h.board(widget.tab));
    final entries = {for (final e in widget.catalog) e.id: e};
    final items = [
      for (final i in _board.items)
        if (entries[i.id] case final e?)
          (
            item: i,
            entry: e,
            size: e.sizes.contains(i.size) ? i.size : e.addedSize,
          ),
    ];
    final previous = _shown;
    _shown = {for (final i in items) i.item.id};
    _keys.removeWhere((id, _) => !_shown.contains(id));
    return ValueListenableBuilder<bool>(
      valueListenable: widget.controller,
      builder: (context, editing, _) {
        if (items.isEmpty) {
          return _EmptyBoard(onEdit: () => widget.controller.setEditing(true));
        }
        final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 3.2);
        final smallHeight = WidgetBoard.smallHeight * scale;
        Widget slot(int index) {
          final (:item, :entry, :size) = items[index];
          return FlipSlot(
            key: _keyFor(item.id),
            boardKey: _boardKey,
            child: _BoardTile(
              entry: entry,
              size: size,
              index: index,
              count: items.length,
              editing: editing,
              isNew: previous.isNotEmpty && !previous.contains(item.id),
              onStartEditing: () => widget.controller.setEditing(true),
              onHover: (dragged) => _onHover(dragged, item.id),
              onRemove: () {
                HapticFeedback.lightImpact();
                _update(_board.withRemoved(item.id));
              },
              onResize: () {
                HapticFeedback.selectionClick();
                _update(_board.withSize(item.id, size.nextIn(entry.sizes)));
              },
              onMove: (by) {
                final at = _board.indexOf(item.id);
                _update(_board.withMoved(at, at + by));
              },
            ),
          );
        }

        // Medium and large widgets take a row each; small ones pair up.
        final rows = <Widget>[];
        for (var i = 0; i < items.length; i++) {
          if (rows.isNotEmpty) {
            rows.add(const SizedBox(height: WidgetBoard.gap));
          }
          if (items[i].size.fullWidth) {
            rows.add(slot(i));
            continue;
          }
          final pair =
              i + 1 < items.length && items[i + 1].size == WidgetSize.small;
          rows.add(
            SizedBox(
              height: smallHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: slot(i)),
                  const SizedBox(width: WidgetBoard.gap),
                  Expanded(child: pair ? slot(i + 1) : const SizedBox()),
                ],
              ),
            ),
          );
          if (pair) i++;
        }
        return Column(
          key: _boardKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}

/// One widget on the board, with its editing behaviour: long-press to
/// drag, jiggle, remove and resize badges, and screen reader actions to
/// move it.
class _BoardTile extends StatefulWidget {
  const _BoardTile({
    required this.entry,
    required this.size,
    required this.index,
    required this.count,
    required this.editing,
    required this.isNew,
    required this.onStartEditing,
    required this.onHover,
    required this.onRemove,
    required this.onResize,
    required this.onMove,
  });

  final BoardEntry entry;
  final WidgetSize size;
  final int index;
  final int count;
  final bool editing;
  final bool isNew;
  final VoidCallback onStartEditing;
  final bool Function(String dragged) onHover;
  final VoidCallback onRemove;
  final VoidCallback onResize;
  final ValueChanged<int> onMove;

  @override
  State<_BoardTile> createState() => _BoardTileState();
}

class _BoardTileState extends State<_BoardTile> {
  /// The tile's size when last laid out, for the copy that follows a
  /// dragging finger.
  Size? _size;

  /// Where the dragging finger is, and the ticks that scroll the page
  /// while it's held near the top or bottom edge.
  double? _dragY;
  Timer? _scroller;

  void _startAutoScroll() {
    _scroller?.cancel();
    _scroller = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final y = _dragY;
      if (y != null && mounted) _autoScroll(context, y);
    });
  }

  void _stopAutoScroll() {
    _scroller?.cancel();
    _scroller = null;
    _dragY = null;
  }

  @override
  void dispose() {
    _scroller?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final content = w.entry.builder(context, w.size);
    final reduced = Motion.reduced(context);
    final tile = _Measure(
      onSize: (s) => _size = s,
      // While editing, the widget's own buttons step aside for dragging.
      // Absorbed rather than ignored: the touch still lands on the tile,
      // so the drag around it can start and other tiles see it pass.
      child: AbsorbPointer(
        absorbing: w.editing,
        // Changing size cross-fades to the other layout, which settles in
        // with a slight zoom, rather than stretching the old one.
        child: AnimatedSwitcher(
          duration: reduced ? Duration.zero : Motion.medium,
          switchInCurve: Motion.curve,
          switchOutCurve: Curves.easeIn,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topLeft,
            children: [
              // The outgoing size: no flying chip and not read out. It
              // keeps its own height as it fades, clipped to the new one.
              for (final p in previous)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ExcludeSemantics(
                    child: HeroMode(enabled: false, child: p),
                  ),
                ),
              ?current,
            ],
          ),
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(
              scale: Tween(begin: 0.94, end: 1.0).animate(a),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(w.size), child: content),
        ),
      ),
    );
    // The same shape whether editing or not, so the widget isn't rebuilt
    // from scratch (replaying its animations) when editing starts.
    final body = _PopIn(
      animate: w.isNew && !Motion.reduced(context),
      child: Semantics(
        label: w.editing
            ? '${w.entry.label}, ${w.index + 1} of ${w.count}'
            : null,
        customSemanticsActions: w.editing
            ? {
                if (w.index > 0)
                  const CustomSemanticsAction(label: 'Move earlier'): () =>
                      w.onMove(-1),
                if (w.index < w.count - 1)
                  const CustomSemanticsAction(label: 'Move later'): () =>
                      w.onMove(1),
              }
            : null,
        child: _Jiggle(
          index: w.index,
          active: w.editing,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              tile,
              if (w.editing)
                Positioned(
                  left: -10,
                  top: -10,
                  child: _Badge(
                    icon: Icons.remove_rounded,
                    label: 'Remove ${w.entry.label}',
                    onTap: w.onRemove,
                  ),
                ),
              if (w.editing && w.entry.resizable)
                Positioned(
                  right: -10,
                  top: -10,
                  child: _ResizeBadge(
                    label: w.entry.label,
                    size: w.size,
                    next: w.size.nextIn(w.entry.sizes),
                    onTap: w.onResize,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => w.onHover(d.data),
      // A hover that landed during a swap's glide is retried as the
      // finger moves.
      onMove: (d) => w.onHover(d.data),
      builder: (context, _, _) => LongPressDraggable<String>(
        data: w.entry.id,
        delay: const Duration(milliseconds: 300),
        // Starting to edit gives the haptic.
        hapticFeedbackOnStart: false,
        onDragStarted: () {
          w.onStartEditing();
          _startAutoScroll();
        },
        onDragUpdate: (d) => _dragY = d.globalPosition.dy,
        onDragEnd: (_) => _stopAutoScroll(),
        onDraggableCanceled: (_, _) => _stopAutoScroll(),
        onDragCompleted: _stopAutoScroll,
        feedback: _DragCopy(size: _size, child: content),
        childWhenDragging: Opacity(opacity: 0.25, child: body),
        child: body,
      ),
    );
  }
}

/// How close to the screen's top or bottom edge a dragged widget scrolls
/// the page, and how far each frame.
const _edge = 90.0;
const _edgeStep = 14.0;

/// Scrolls the page a step when a dragged widget is near the top or bottom
/// of the screen, so it can reach widgets out of view.
void _autoScroll(BuildContext context, double y) {
  final position = Scrollable.maybeOf(context)?.position;
  if (position == null) return;
  final height = MediaQuery.sizeOf(context).height;
  final double delta = y < _edge
      ? -_edgeStep
      : y > height - _edge
      ? _edgeStep
      : 0;
  if (delta == 0) return;
  position.jumpTo(
    (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    ),
  );
}

/// The lifted copy of a widget that follows the finger.
class _DragCopy extends StatelessWidget {
  const _DragCopy({required this.size, required this.child});

  final Size? size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = size ?? const Size(160, WidgetBoard.smallHeight);
    return SizedBox.fromSize(
      size: s,
      child: Transform.scale(
        scale: 1.04,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: context.cardBorderRadius(AppTheme.radius),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33101828),
                blurRadius: 30,
                offset: Offset(0, 14),
              ),
            ],
          ),
          // No flying chips from the copy.
          child: HeroMode(enabled: false, child: IgnorePointer(child: child)),
        ),
      ),
    );
  }
}

/// Reports its child's size after layout.
class _Measure extends SingleChildRenderObjectWidget {
  const _Measure({required this.onSize, super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasure(onSize);

  @override
  void updateRenderObject(BuildContext context, _RenderMeasure renderObject) {
    renderObject.onSize = onSize;
  }
}

class _RenderMeasure extends RenderProxyBox {
  _RenderMeasure(this.onSize);

  ValueChanged<Size> onSize;

  @override
  void performLayout() {
    super.performLayout();
    onSize(size);
  }
}

/// Scales a newly added widget up into place. When [animate] is false it
/// shows [child] as is (it's always present, so the tree keeps its shape).
class _PopIn extends StatelessWidget {
  const _PopIn({required this.animate, required this.child});

  final bool animate;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: animate ? 0.85 : 1, end: 1),
    duration: Motion.medium,
    curve: Motion.spring,
    builder: (context, t, child) => Opacity(
      opacity: ((t - 0.85) / 0.15).clamp(0, 1),
      child: Transform.scale(scale: t, child: child),
    ),
    child: child,
  );
}

/// The resize badge: steps to the [next] size, growing until the largest
/// and then back to the smallest, with an icon saying which way it goes.
class _ResizeBadge extends StatelessWidget {
  const _ResizeBadge({
    required this.label,
    required this.size,
    required this.next,
    required this.onTap,
  });

  final String label;
  final WidgetSize size;
  final WidgetSize next;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Badge(
    icon: next.index > size.index
        ? Icons.open_in_full_rounded
        : Icons.close_fullscreen_rounded,
    label: 'Make $label ${next.label.toLowerCase()}',
    onTap: onTap,
  );
}

/// A round grey button on a widget's corner while editing.
class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    semanticLabel: label,
    onTap: onTap,
    scale: 0.85,
    // A 44 pt target around the 26 pt badge.
    child: SizedBox.square(
      dimension: AppTheme.minTapTarget,
      child: Center(
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.isDark
                ? const Color(0xFF3A3B44)
                : const Color(0xFFE4E5EA),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26101828),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 16, color: context.labelColor),
        ),
      ),
    ),
  );
}

/// Rocks [child] gently back and forth, as icons do while the iPhone home
/// screen is being edited. Neighbours are out of step so it looks natural.
class _Jiggle extends StatefulWidget {
  const _Jiggle({
    required this.index,
    required this.active,
    required this.child,
  });

  final int index;
  final bool active;
  final Widget child;

  @override
  State<_Jiggle> createState() => _JiggleState();
}

class _JiggleState extends State<_Jiggle> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 260 + (widget.index % 3) * 20),
    value: 0.5,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Jiggle old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  void _sync() {
    if (widget.active && Motion.ambientOn(context)) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      // Settle upright rather than freezing mid-tilt.
      _controller
        ..stop()
        ..value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = widget.index.isEven ? 1.0 : -1.0;
    return AnimatedBuilder(
      animation: _controller,
      // Its own layer, so tilting it only recomposites rather than
      // repainting the whole board each frame.
      child: RepaintBoundary(child: widget.child),
      // Wide widgets tilt less, so their edges move about as far.
      builder: (context, child) => Transform.rotate(
        angle: phase * (_controller.value - 0.5) * 0.018,
        child: child,
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => IosCard(
    onTap: onEdit,
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
    child: Column(
      children: [
        Icon(Icons.widgets_rounded, size: 34, color: context.tint),
        const SizedBox(height: 10),
        Text('No Widgets', style: context.headline),
        const SizedBox(height: 4),
        Text(
          'Tap Edit, then + to add the widgets you want here.',
          textAlign: TextAlign.center,
          style: context.footnote.copyWith(color: context.secondaryLabel),
        ),
      ],
    ),
  );
}

/// The header controls for a board: an edit button, then "+" and Done
/// while editing.
class BoardEditControls extends StatelessWidget {
  const BoardEditControls({
    super.key,
    required this.controller,
    required this.tab,
    required this.catalog,
    required this.label,
    this.trailing,
  });

  final BoardController controller;
  final BoardTab tab;
  final List<BoardEntry> Function() catalog;

  /// Names what's edited, for screen readers ("Edit Health").
  final String label;

  /// Shown after the edit button when not editing (e.g. settings).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final duration = Motion.reduced(context) ? Duration.zero : Motion.fast;
    return ValueListenableBuilder<bool>(
      valueListenable: controller,
      builder: (context, editing, _) => AnimatedSwitcher(
        duration: duration,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween(begin: 0.9, end: 1.0).animate(a),
            child: child,
          ),
        ),
        child: editing
            ? Row(
                key: const ValueKey(true),
                mainAxisSize: MainAxisSize.min,
                children: [
                  HeaderButton(
                    icon: Icons.add_rounded,
                    semanticLabel: tr('Add Widget'),
                    onTap: () => BoardGallery.show(
                      context,
                      tab: tab,
                      catalog: catalog(),
                    ),
                  ),
                  Pressable(
                    semanticLabel: tr('Done'),
                    onTap: () => controller.setEditing(false),
                    child: SizedBox(
                      height: AppTheme.minTapTarget + 4,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 9,
                          ),
                          decoration: ShapeDecoration(
                            shape: const StadiumBorder(),
                            color: context.tint,
                          ),
                          child: Text(
                            'Done',
                            style: context.subheadline.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.onColor(context.tint),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                key: const ValueKey(false),
                mainAxisSize: MainAxisSize.min,
                children: [
                  HeaderButton(
                    icon: Icons.dashboard_customize_rounded,
                    semanticLabel: label,
                    onTap: () => controller.setEditing(true),
                  ),
                  ?trailing,
                ],
              ),
      ),
    );
  }
}

/// Everything a tab can show, by group, to add to or take off its board.
/// Opens as an iOS sheet the page behind steps back from.
class BoardGallery extends StatelessWidget {
  const BoardGallery({
    super.key,
    required this.tab,
    required this.catalog,
    this.controller,
  });

  final BoardTab tab;
  final List<BoardEntry> catalog;

  /// Lets the list's overscroll pull the sheet down to close it.
  final ScrollController? controller;

  static Future<void> show(
    BuildContext context, {
    required BoardTab tab,
    required List<BoardEntry> catalog,
  }) => showCupertinoSheet<void>(
    context: context,
    scrollableBuilder: (_, controller) =>
        BoardGallery(tab: tab, catalog: catalog, controller: controller),
  );

  @override
  Widget build(BuildContext context) {
    final board = context.watch<HealthStore>().board(tab);
    final groups = <String, List<BoardEntry>>{};
    for (final e in catalog) {
      (groups[e.group] ??= []).add(e);
    }
    return CupertinoPageScaffold(
      backgroundColor: context.groupedBackground,
      navigationBar: CupertinoNavigationBar(
        // Sheets don't morph the title from the page below, as on iOS;
        // every bar shares one hero tag, so it would fly into the sheet.
        transitionBetweenRoutes: false,
        middle: const Text('Add Widgets'),
        automaticallyImplyLeading: false,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Done',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(
            AppTheme.margin,
            8,
            AppTheme.margin,
            40,
          ),
          children: [
            Text(
              'Tap to add or remove a widget. Tap Edit on the tab to reorder, '
              'resize or remove them there.',
              style: context.footnote.copyWith(color: context.secondaryLabel),
            ),
            for (final MapEntry(key: group, value: entries)
                in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
                child: Text(group, style: context.headline),
              ),
              Container(
                decoration: cardSurface(context, radius: AppTheme.listRadius),
                child: Column(
                  children: [
                    for (final (i, e) in entries.indexed) ...[
                      if (i > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 56),
                          child: Container(
                            height: 0.5,
                            color: context.separatorColor,
                          ),
                        ),
                      _GalleryRow(
                        entry: e,
                        added: board.contains(e.id),
                        onToggle: () {
                          HapticFeedback.selectionClick();
                          final store = context.read<HealthStore>();
                          final b = store.board(tab);
                          store.updateBoard(
                            tab,
                            b.contains(e.id)
                                ? b.withRemoved(e.id)
                                : b.withAdded(e.id, e.addedSize),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GalleryRow extends StatelessWidget {
  const _GalleryRow({
    required this.entry,
    required this.added,
    required this.onToggle,
  });

  final BoardEntry entry;
  final bool added;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final duration = Motion.reduced(context) ? Duration.zero : Motion.fast;
    final c = context.resolve(entry.color);
    final detail = entry.detail;
    return Semantics(
      button: true,
      toggled: added,
      label: entry.label,
      hint: added ? 'Remove from the tab' : 'Add to the tab',
      excludeSemantics: true,
      onTap: onToggle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.pastel(c),
                ),
                child: Icon(entry.icon, size: 16, color: c),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.label, style: context.body),
                    if (detail != null)
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.footnote.copyWith(
                          color: context.secondaryLabel,
                        ),
                      ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: duration,
                transitionBuilder: (child, a) => ScaleTransition(
                  scale: CurvedAnimation(parent: a, curve: Motion.spring),
                  child: child,
                ),
                child: Icon(
                  added
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  key: ValueKey(added),
                  size: 26,
                  color: added ? context.tint : context.tertiaryLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
