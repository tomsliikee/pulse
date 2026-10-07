import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

/// Runs the time of a small animated scene and hands it to [builder] as
/// seconds. It stands still where the system asks for no animations.
class SceneClock extends StatefulWidget {
  const SceneClock({super.key, required this.builder});

  final Widget Function(BuildContext context, ValueListenable<double> seconds)
  builder;

  @override
  State<SceneClock> createState() => _SceneClockState();
}

class _SceneClockState extends State<SceneClock>
    with SingleTickerProviderStateMixin {
  /// The moment shown where nothing moves: a little way in, not the start.
  static const double _still = 0.2;

  final ValueNotifier<double> _seconds = ValueNotifier(_still);
  late final Ticker _ticker = createTicker(
    (elapsed) => _seconds.value =
        _still + elapsed.inMicroseconds / Duration.microsecondsPerSecond,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (still && _ticker.isActive) {
      _ticker.stop();
      _seconds.value = _still;
    } else if (!still && !_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    // Its own layer, so a frame of the scene repaints nothing else.
    child: RepaintBoundary(
      child: ClipRect(child: widget.builder(context, _seconds)),
    ),
  );
}

/// Draws the figure the scenes share: limbs as round strokes and a round
/// head, in the theme's primary colour. Every length is given in [u], one
/// hundredth of the scene's height.
class FigurePen {
  const FigurePen(this.canvas, this.scheme, this.u, {this.color});

  final Canvas canvas;
  final ColorScheme scheme;
  final double u;

  /// The colour of the figure; the theme's primary when null.
  final Color? color;

  Color get _body => color ?? scheme.primary;

  /// The stroke of an arm, a leg or the body; paler for the far side.
  Paint limb({bool far = false}) => Paint()
    ..color = far
        ? Color.lerp(_body, scheme.surfaceContainerHighest, 0.45)!
        : _body
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6.5 * u
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// The thin stroke of a thing the figure uses.
  Paint thing([double width = 2.6]) => Paint()
    ..color = scheme.onSurfaceVariant
    ..style = PaintingStyle.stroke
    ..strokeWidth = width * u
    ..strokeCap = StrokeCap.round;

  void line(Paint paint, List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  void head(Offset centre) =>
      canvas.drawCircle(centre, 6.5 * u, Paint()..color = _body);

  /// The joint between [from] and [to] of a limb with parts of [first] and
  /// [second] length; [side] picks to which side it bends.
  static Offset joint(
    Offset from,
    Offset to,
    double first,
    double second,
    double side,
  ) {
    final delta = to - from;
    final reach = delta.distance.clamp(0.001, first + second - 0.001);
    final direction = delta / delta.distance.clamp(0.001, double.infinity);
    final along =
        (first * first - second * second + reach * reach) / (2 * reach);
    final out = math.sqrt(math.max(0, first * first - along * along));
    return from +
        direction * along +
        Offset(-direction.dy, direction.dx) * (out * side);
  }
}
