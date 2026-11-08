import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:health_app/widgets/motion.dart';

/// Glides [child] from where it was to where it now is whenever the
/// layout moves it, however big it is (the "FLIP" technique). Positions
/// are measured against the widget with [boardKey], so scrolling doesn't
/// count as a move.
///
/// Give each slot a [GlobalKey] so it keeps its place in memory when it
/// moves to a different row.
class FlipSlot extends StatefulWidget {
  const FlipSlot({super.key, required this.boardKey, required this.child});

  final GlobalKey boardKey;
  final Widget child;

  @override
  State<FlipSlot> createState() => _FlipSlotState();
}

class _FlipSlotState extends State<FlipSlot>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Motion.medium,
  );

  /// Where the child starts gliding from, relative to its new place.
  Offset _from = Offset.zero;

  /// Counts glides started, so the render object knows when a glide it
  /// asked for has taken over from its one-frame stand-in.
  int _generation = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Called while painting the frame in which the slot moved: the frame is
  /// already drawn at the old place, so start the glide from there.
  void _moved(Offset from) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _from = from;
        _generation++;
      });
      if (Motion.reduced(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    });
  }

  Offset get _shift =>
      _from * (1 - Motion.curve.transform(_controller.value.clamp(0, 1)));

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) => _FlipBox(
      shift: _shift,
      reduced: Motion.reduced(context),
      generation: _generation,
      board: () =>
          widget.boardKey.currentContext?.findRenderObject() as RenderBox?,
      onMoved: _moved,
      child: child,
    ),
    child: widget.child,
  );
}

class _FlipBox extends SingleChildRenderObjectWidget {
  const _FlipBox({
    required this.shift,
    required this.reduced,
    required this.generation,
    required this.board,
    required this.onMoved,
    super.child,
  });

  final Offset shift;
  final bool reduced;
  final int generation;
  final RenderBox? Function() board;
  final ValueChanged<Offset> onMoved;

  @override
  _RenderFlip createRenderObject(BuildContext context) => _RenderFlip(
    shift: shift,
    reduced: reduced,
    generation: generation,
    board: board,
    onMoved: onMoved,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderFlip renderObject) {
    renderObject
      ..shift = shift
      ..reduced = reduced
      ..generation = generation
      ..board = board
      ..onMoved = onMoved;
  }
}

class _RenderFlip extends RenderProxyBox {
  _RenderFlip({
    required this._shift,
    required this.reduced,
    required this._generation,
    required this.board,
    required this.onMoved,
  });

  int _generation;
  set generation(int value) {
    if (value == _generation) return;
    _generation = value;
    // The glide asked for has started; it carries the offset from now on.
    _pending = Offset.zero;
    markNeedsPaint();
  }

  RenderBox? Function() board;

  /// With Reduce Motion, moves happen at once, with no glide.
  bool reduced;
  ValueChanged<Offset> onMoved;

  Offset _shift;
  Offset get shift => _shift;
  set shift(Offset value) {
    if (value == _shift) return;
    _shift = value;
    markNeedsPaint();
  }

  /// Where the slot was last painted, relative to the board.
  Offset? _last;

  /// The extra shift for the frame in which a move was noticed, before the
  /// glide has started.
  Offset _pending = Offset.zero;

  /// Until the glide takes over, [_pending] stands in for it.
  Offset get _paintShift => _pending != Offset.zero ? _pending : _shift;

  @override
  void paint(PaintingContext context, Offset offset) {
    final b = board();
    if (b != null && b.attached && attached) {
      final now = localToGlobal(Offset.zero, ancestor: b);
      final last = _last;
      if (last != null && !reduced && (now - last).distance > 0.5) {
        // Draw this frame where it was (plus any glide in progress) and
        // glide from there.
        _pending = last - now + _shift;
        onMoved(_pending);
      }
      _last = now;
    }
    super.paint(context, offset + _paintShift);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(_paintShift.dx, _paintShift.dy, 0, 1);
  }

  // Touches go by where the slot is, not where its glide is drawing it:
  // a widget dragged over another swaps places at once, and the one
  // gliding away mustn't still catch the finger and swap them back.
}
