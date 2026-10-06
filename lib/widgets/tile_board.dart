import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../app/haptics.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';

/// How much of a row a tile takes. A row has six units.
enum TileSpan {
  full(6),
  half(3),
  third(2);

  const TileSpan(this.units);

  final int units;
}

@immutable
class BoardTile {
  const BoardTile({
    required this.id,
    required this.height,
    required this.child,
    this.span = TileSpan.full,
    this.large = false,
    this.onRemove,
    this.onResize,
  });

  /// Stable across releases; the saved order refers to it.
  final String id;
  final TileSpan span;
  final double height;
  final Widget child;

  /// Whether the tile is in its large form; picks the resize button's icon.
  final bool large;

  /// Offered as a minus in the corner while the board is edited.
  final VoidCallback? onRemove;

  /// Offered as a second corner button while the board is edited.
  final VoidCallback? onResize;
}

/// The tiles in display order: the [saved] ids that still exist, followed by
/// tiles the saved order does not know, so a new tile is never lost.
List<String> resolveTileOrder(List<BoardTile> tiles, List<String> saved) {
  final ids = {for (final tile in tiles) tile.id};
  final seen = <String>{};
  return [
    for (final id in saved)
      if (ids.contains(id) && seen.add(id)) id,
    for (final tile in tiles)
      if (seen.add(tile.id)) tile.id,
  ];
}

/// Packs [ordered] tiles row by row into [width] and returns each tile's
/// rectangle and the total height.
({Map<String, Rect> rects, double height}) packTiles(
  List<BoardTile> ordered,
  double width, {
  double gap = 12,
}) {
  const rowUnits = 6;
  final unit = (width - gap * (rowUnits - 1)) / rowUnits;
  final rects = <String, Rect>{};
  var used = 0;
  var top = 0.0;
  var rowHeight = 0.0;
  for (final tile in ordered) {
    final units = tile.span.units;
    if (used + units > rowUnits) {
      top += rowHeight + gap;
      used = 0;
      rowHeight = 0;
    }
    rects[tile.id] = Rect.fromLTWH(
      used * (unit + gap),
      top,
      units * unit + (units - 1) * gap,
      tile.height,
    );
    used += units;
    rowHeight = math.max(rowHeight, tile.height);
  }
  return (rects: rects, height: ordered.isEmpty ? 0 : top + rowHeight);
}

/// Lays tiles out in the user's order. While [editing], the tiles wiggle and
/// can be picked up after a short hold and dropped elsewhere; the others make
/// room with a spring.
class TileBoard extends StatefulWidget {
  const TileBoard({
    super.key,
    required this.tiles,
    required this.order,
    required this.editing,
    required this.onReorder,
    this.gap = 12,
  });

  final List<BoardTile> tiles;

  /// The saved order of tile ids. May be empty or outdated.
  final List<String> order;
  final bool editing;
  final ValueChanged<List<String>> onReorder;
  final double gap;

  @override
  State<TileBoard> createState() => _TileBoardState();
}

class _TileBoardState extends State<TileBoard>
    with SingleTickerProviderStateMixin {
  /// Short enough to feel immediate, long enough that a swipe still scrolls.
  static const _holdDelay = Duration(milliseconds: 150);

  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  late List<String> _order = resolveTileOrder(widget.tiles, widget.order);
  double _width = 0;

  String? _dragId;
  Offset _finger = Offset.zero;
  Offset _grab = Offset.zero;
  Rect _dragRect = Rect.zero;
  EdgeDraggingAutoScroller? _scroller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncWiggle();
  }

  @override
  void didUpdateWidget(TileBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // While a tile is in the air the working order is ahead of the saved one.
    if (_dragId == null) {
      _order = resolveTileOrder(widget.tiles, widget.order);
    }
    _syncWiggle();
  }

  void _syncWiggle() {
    final wanted = widget.editing && !MediaQuery.disableAnimationsOf(context);
    if (wanted && !_wiggle.isAnimating) {
      _wiggle.repeat();
    } else if (!wanted && _wiggle.isAnimating) {
      _wiggle
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _scroller?.stopAutoScroll();
    _wiggle.dispose();
    super.dispose();
  }

  List<BoardTile> _ordered() {
    final byId = {for (final tile in widget.tiles) tile.id: tile};
    return [for (final id in _order) ?byId[id]];
  }

  Drag? _startDrag(String id, Offset position) {
    final box = context.findRenderObject();
    final rect = packTiles(_ordered(), _width, gap: widget.gap).rects[id];
    if (box is! RenderBox || rect == null) return null;
    Haptics.lift();
    setState(() {
      _dragId = id;
      _finger = position;
      _grab = box.globalToLocal(position) - rect.topLeft;
      _dragRect = rect;
    });
    _scroller = EdgeDraggingAutoScroller(
      Scrollable.of(context),
      onScrollViewScrolled: _follow,
      velocityScalar: 20,
    );
    return _BoardDrag(
      onUpdate: (details) {
        _finger = details.globalPosition;
        _follow();
      },
      onEnd: _endDrag,
    );
  }

  /// Keeps the lifted tile under the finger, also while the page scrolls
  /// beneath it, and moves it in the order when it is over another tile.
  void _follow() {
    final id = _dragId;
    final box = context.findRenderObject();
    if (id == null || box is! RenderBox || !mounted) return;
    setState(() {
      _dragRect = (box.globalToLocal(_finger) - _grab) & _dragRect.size;
      final slots = packTiles(_ordered(), _width, gap: widget.gap).rects;
      for (final MapEntry(key: other, value: slot) in slots.entries) {
        // Only the inner half of a slot takes the tile. At the very edge two
        // tiles of different size would otherwise swap back and forth.
        final core = slot.deflate(slot.shortestSide / 4);
        if (other != id && core.contains(_dragRect.center)) {
          final target = _order.indexOf(other);
          _order
            ..remove(id)
            ..insert(target, id);
          Haptics.selection();
          break;
        }
      }
    });
    _scroller?.startAutoScrollIfNecessary(
      box.localToGlobal(_dragRect.topLeft) & _dragRect.size,
    );
  }

  void _endDrag() {
    _scroller?.stopAutoScroll();
    _scroller = null;
    if (!mounted) return;
    setState(() => _dragId = null);
    widget.onReorder(List.of(_order));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        final ordered = _ordered();
        final packed = packTiles(ordered, _width, gap: widget.gap);
        // The lifted tile is painted last so it floats above the others.
        final paintOrder = [
          for (final tile in ordered)
            if (tile.id != _dragId) tile,
          for (final tile in ordered)
            if (tile.id == _dragId) tile,
        ];
        return SizedBox(
          height: packed.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final tile in paintOrder)
                _Slot(
                  key: ValueKey(tile.id),
                  tile: tile,
                  rect: tile.id == _dragId ? _dragRect : packed.rects[tile.id]!,
                  lifted: tile.id == _dragId,
                  editing: widget.editing,
                  wiggle: _wiggle,
                  // Neighbours swing out of step, as if each were loose.
                  phase: (_order.indexOf(tile.id) * 0.37) % 1,
                  holdDelay: _holdDelay,
                  onDragStart: (position) => _startDrag(tile.id, position),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    super.key,
    required this.tile,
    required this.rect,
    required this.lifted,
    required this.editing,
    required this.wiggle,
    required this.phase,
    required this.holdDelay,
    required this.onDragStart,
  });

  final BoardTile tile;
  final Rect rect;
  final bool lifted;
  final bool editing;
  final Animation<double> wiggle;
  final double phase;
  final Duration holdDelay;
  final Drag? Function(Offset position) onDragStart;

  /// How far the slot reaches beyond its tile, so the corner buttons can
  /// sit on the tile's corner and still be hit.
  static const _reach = 12.0;

  @override
  Widget build(BuildContext context) {
    final shadow = Theme.of(context).colorScheme.shadow;

    // The tile is always laid out at the size it is heading for and scaled
    // into the slot, so a tile that is growing or shrinking never has to fit
    // its content into a size it was not made for.
    Widget content = IgnorePointer(
      ignoring: editing,
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox.fromSize(size: rect.size, child: tile.child),
      ),
    );
    content = SingleMotionBuilder(
      value: lifted ? 1 : 0,
      motion: AppMotion.spatialFast,
      builder: (context, lift, child) => Transform.scale(
        scale: 1 + 0.04 * lift,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.extraLarge),
            boxShadow: [
              BoxShadow(
                color: shadow.withValues(
                  alpha: 0.24 * lift.clamp(0, 1).toDouble(),
                ),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
      child: content,
    );
    final onRemove = tile.onRemove;
    final onResize = tile.onResize;
    content = Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.all(_reach),
          child: RawGestureDetector(
            gestures: {
              if (editing)
                DelayedMultiDragGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      DelayedMultiDragGestureRecognizer
                    >(
                      () => DelayedMultiDragGestureRecognizer(delay: holdDelay),
                      (recognizer) => recognizer.onStart = onDragStart,
                    ),
            },
            child: content,
          ),
        ),
        // Above the drag area, so a tap on a button never lifts the tile.
        if (onRemove != null)
          Positioned(
            top: 0,
            right: 0,
            child: _CornerButton(
              visible: editing && !lifted,
              icon: Icons.remove_rounded,
              tooltip: 'Entfernen',
              onPressed: onRemove,
            ),
          ),
        if (onResize != null)
          Positioned(
            bottom: 0,
            right: 0,
            child: _CornerButton(
              visible: editing && !lifted,
              icon: tile.large
                  ? Icons.close_fullscreen_rounded
                  : Icons.open_in_full_rounded,
              tooltip: tile.large ? 'Verkleinern' : 'Vergrössern',
              onPressed: onResize,
            ),
          ),
      ],
    );
    content = AnimatedBuilder(
      animation: wiggle,
      // The swing shrinks with the tile's width so a wide tile's corners do
      // not travel further than a small tile's.
      builder: (context, child) => Transform.rotate(
        angle: editing && !lifted && wiggle.isAnimating
            ? math.sin((wiggle.value + phase) * 2 * math.pi) * 3 / rect.width
            : 0,
        child: child,
      ),
      child: content,
    );
    return MotionBuilder<Rect>(
      value: rect,
      motion: AppMotion.spatial,
      // A lifted tile follows the finger exactly: inactive, the builder sets
      // the value at once. Released, the spring takes it home.
      active: !lifted,
      converter: MotionConverter.rect,
      builder: (context, current, child) =>
          Positioned.fromRect(rect: current.inflate(_reach), child: child!),
      child: content,
    );
  }
}

/// A small round button in a tile's corner, shown only while editing.
class _CornerButton extends StatelessWidget {
  const _CornerButton({
    required this.visible,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final bool visible;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleMotionBuilder(
      value: visible ? 1 : 0,
      motion: AppMotion.spatialFast,
      builder: (context, t, child) => t <= 0.01
          ? const SizedBox.shrink()
          : Transform.scale(scale: t, child: child),
      child: IgnorePointer(
        ignoring: !visible,
        child: IconButton(
          onPressed: () {
            Haptics.tap();
            onPressed();
          },
          tooltip: tooltip,
          iconSize: 16,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 26, height: 26),
          style: IconButton.styleFrom(
            backgroundColor: scheme.inverseSurface,
            foregroundColor: scheme.onInverseSurface,
            // The visible disc is small; the touch area around it is not.
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
          icon: Icon(icon),
        ),
      ),
    );
  }
}

class _BoardDrag extends Drag {
  _BoardDrag({required this.onUpdate, required this.onEnd});

  final ValueChanged<DragUpdateDetails> onUpdate;
  final VoidCallback onEnd;

  @override
  void update(DragUpdateDetails details) => onUpdate(details);

  @override
  void end(DragEndDetails details) => onEnd();

  @override
  void cancel() => onEnd();
}
