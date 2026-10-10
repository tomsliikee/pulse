import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

/// Runs the time of a small animated scene and hands it to [builder] as
/// seconds. It stands still where the system asks for no animations, and
/// while nobody can see it: scrolled out of the screen, under another page
/// or with the app in the background.
class SceneClock extends StatefulWidget {
  const SceneClock({super.key, required this.builder, this.rate});

  final Widget Function(BuildContext context, ValueListenable<double> seconds)
  builder;

  /// How many pictures a second the scene is drawn with, for one in which
  /// everything moves slowly. Every frame of the display when null.
  final int? rate;

  @override
  State<SceneClock> createState() => _SceneClockState();
}

class _SceneClockState extends State<SceneClock>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// The moment shown where nothing moves: a little way in, not the start.
  static const double _still = 0.2;

  /// How often a scene that is out of sight looks whether it is back.
  static const Duration _look = Duration(milliseconds: 250);

  final ValueNotifier<double> _seconds = ValueNotifier(_still);

  /// The seconds the scene had reached when the ticker last started.
  double _from = _still;
  late final Ticker _ticker = createTicker((elapsed) {
    if (!_inSight()) {
      _park();
      return;
    }
    _seconds.value =
        _from + elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  });

  /// Steps a scene with a [SceneClock.rate], or looks for a parked one.
  Timer? _timer;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  @override
  void didUpdateWidget(SceneClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rate != widget.rate) {
      _stop();
      _sync();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _sync();

  bool get _running => _ticker.isActive || _timer != null;

  void _sync() {
    final state = WidgetsBinding.instance.lifecycleState;
    final still = MediaQuery.disableAnimationsOf(context);
    final wanted =
        !still &&
        _enabled &&
        (state == null || state == AppLifecycleState.resumed);
    if (still) _seconds.value = _still;
    if (wanted && !_running) {
      _start();
    } else if (!wanted && _running) {
      _stop();
    }
  }

  void _start() {
    final rate = widget.rate;
    if (rate == null) {
      _from = _seconds.value;
      _ticker.start();
      return;
    }
    // A timer and not a ticker: a ticker has the whole screen drawn again
    // with every frame of the display, also when the scene has not moved.
    _timer = Timer.periodic(Duration(microseconds: 1000000 ~/ rate), (_) {
      if (_inSight()) _seconds.value += 1 / rate;
    });
  }

  void _stop() {
    _ticker.stop();
    _timer?.cancel();
    _timer = null;
  }

  /// Rests the ticker of a scene that is out of sight until it is back.
  void _park() {
    _stop();
    _timer = Timer.periodic(_look, (_) {
      if (!_inSight()) return;
      _stop();
      _start();
    });
  }

  /// Whether any of the scene is on the screen.
  bool _inSight() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return true;
    final view = View.maybeOf(context);
    if (view == null) return true;
    final screen = Offset.zero & view.physicalSize / view.devicePixelRatio;
    return MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    ).overlaps(screen);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
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
