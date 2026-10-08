import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../theme/app_motion.dart';

/// A circular progress track whose arc springs to [value] (0 to 1). A ring
/// that is full turns into a wave that travels slowly around it; the wave
/// stands still where the system asks for no animations.
class ProgressRing extends StatefulWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    required this.trackColor,
    this.strokeWidth = 16,
    this.wavyWhenFull = true,
  });

  final double value;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  /// Whether a full ring is drawn as a travelling wave.
  final bool wavyWhenFull;

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with SingleTickerProviderStateMixin {
  /// One wave passes a point of the ring in this time.
  late final AnimationController _travel = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  bool get _full => widget.wavyWhenFull && widget.value >= 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final wanted = _full && !MediaQuery.disableAnimationsOf(context);
    if (wanted && !_travel.isAnimating) {
      _travel.repeat();
    } else if (!wanted && _travel.isAnimating) {
      _travel.stop();
    }
  }

  @override
  void dispose() {
    _travel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleMotionBuilder(
      from: 0,
      value: widget.value.clamp(0, 1).toDouble(),
      motion: AppMotion.spatialSlow,
      builder: (context, current, _) {
        final value = current.clamp(0, 1).toDouble();
        return CustomPaint(
          painter: RingPainter(
            value: value,
            // The wave rises over the last of the way, so nothing jumps.
            wave: _full
                ? Curves.easeInOut.transform(
                    ((value - 0.94) / 0.06).clamp(0.0, 1.0),
                  )
                : 0,
            travel: _travel,
            color: widget.color,
            trackColor: widget.trackColor,
            strokeWidth: widget.strokeWidth,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

/// Paints a [ProgressRing].
@visibleForTesting
class RingPainter extends CustomPainter {
  RingPainter({
    required this.value,
    required this.wave,
    required this.travel,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  }) : super(repaint: travel);

  final double value;

  /// How much of a wave the arc is, from 0 (a plain arc) to 1.
  final double wave;

  /// How far the wave has travelled, from 0 to 1 of one wavelength.
  final Animation<double> travel;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = trackColor);
    if (value <= 0) return;
    paint.color = color;
    if (wave <= 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, paint);
      return;
    }
    final radius = rect.width / 2;
    final centre = rect.center;
    // A whole number of waves, each about two strokes long.
    final waves = math
        .max(6, (math.pi * 2 * radius / (strokeWidth * 2.4)))
        .round();
    final height = strokeWidth * 0.2 * wave;
    final phase = travel.value * math.pi * 2;
    final sweep = math.pi * 2 * value;
    const step = math.pi / 180;
    final path = Path();
    for (var angle = 0.0; angle <= sweep + step / 2; angle += step) {
      final at = math.min(angle, sweep) - math.pi / 2;
      final r = radius + height * math.sin(at * waves - phase);
      final point = centre + Offset(math.cos(at), math.sin(at)) * r;
      angle == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    if (value >= 1) path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(RingPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.wave != wave ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
