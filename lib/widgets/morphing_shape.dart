import 'dart:math' as math;

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../theme/app_motion.dart';

/// Paints one of the expressive [Shapes] and morphs to the next one with a
/// spatial spring whenever [shape] changes.
class MorphingShape extends StatefulWidget {
  const MorphingShape({
    super.key,
    required this.shape,
    required this.color,
    required this.size,
    this.child,
  });

  final Shapes shape;
  final Color color;
  final double size;
  final Widget? child;

  @override
  State<MorphingShape> createState() => _MorphingShapeState();
}

class _MorphingShapeState extends State<MorphingShape> {
  /// Matching the curves of two shapes takes long enough to be felt in the
  /// first frame of a page that shows several, and the result never
  /// changes, so each pair is matched once.
  static final Map<(Shapes, Shapes), Morph> _morphs = {};

  static Morph _between(Shapes from, Shapes to) =>
      _morphs[(from, to)] ??= Morph(from.polygon, to.polygon);

  late Morph _morph = _between(widget.shape, widget.shape);
  int _generation = 0;

  @override
  void didUpdateWidget(MorphingShape oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shape != widget.shape) {
      _morph = _between(oldWidget.shape, widget.shape);
      _generation++;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: SingleMotionBuilder(
        // A new key restarts the spring for every new pair of shapes.
        key: ValueKey(_generation),
        from: 0,
        value: 1,
        motion: AppMotion.spatial,
        builder: (context, progress, child) => CustomPaint(
          painter: _MorphPainter(
            morph: _morph,
            progress: progress,
            color: widget.color,
          ),
          child: child,
        ),
        child: widget.child == null ? null : Center(child: widget.child),
      ),
    );
  }
}

class _MorphPainter extends CustomPainter {
  const _MorphPainter({
    required this.morph,
    required this.progress,
    required this.color,
  });

  final Morph morph;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = morph.toPath(progress: progress);
    final bounds = path.getBounds();
    final longest = math.max(bounds.width, bounds.height);
    if (longest == 0) return;
    final scale = size.shortestSide / longest;
    canvas
      ..translate(size.width / 2, size.height / 2)
      ..scale(scale)
      ..translate(-bounds.center.dx, -bounds.center.dy)
      ..drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MorphPainter oldDelegate) =>
      oldDelegate.morph != morph ||
      oldDelegate.progress != progress ||
      oldDelegate.color != color;
}
