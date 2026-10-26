import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/mascot_colors.dart';
import '../theme/pulse_look.dart';
import 'turtle.dart';

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

  /// The seconds a scene starts at, and stands at where nothing moves.
  static const double start = 0.2;

  @override
  State<SceneClock> createState() => _SceneClockState();
}

class _SceneClockState extends State<SceneClock>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// The moment shown where nothing moves: a little way in, not the start.
  static const double _still = SceneClock.start;

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
        !PulseLook.calmOf(context) &&
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
  Widget build(BuildContext context) => PulseLook.calmOf(context)
      // No scene at all; what stands around it keeps its place.
      ? const SizedBox.shrink()
      : ExcludeSemantics(
          // Its own layer, so a frame of the scene repaints nothing else.
          child: RepaintBoundary(
            child: ClipRect(child: widget.builder(context, _seconds)),
          ),
        );
}

/// How far a scene has come in since its page opened: the land rises, what
/// is in the sky climbs to its place and the figure appears. A scene that
/// does not move has come in already.
class SceneEntrance {
  const SceneEntrance._(this._progress);

  /// At [seconds] of a [SceneClock]; [still] where nothing moves.
  factory SceneEntrance.at(double seconds, {required bool still}) =>
      SceneEntrance._(still ? _done : (seconds - SceneClock.start) / _length);

  /// Seconds the land takes to settle.
  static const double _length = 1.3;
  static const double _done = 4;

  final double _progress;

  /// From 0 to 1 on a spring that goes a little too far before it settles.
  double get rise {
    if (_progress <= 0) return 0;
    if (_progress >= _done) return 1;
    return 1 - math.exp(-5.5 * _progress) * math.cos(7 * _progress);
  }

  /// How far what rises still has to go, from 1 to 0.
  double get drop => 1 - rise;

  /// How visible the figure is, from 0 to 1.
  double get shown => (_progress * 2.5).clamp(0.0, 1.0);

  /// How far the figure has walked in, from 0 to 1.
  double get arrived =>
      Curves.easeInOut.transform((_progress * 1.2).clamp(0.0, 1.0));

  /// Draws what [paint] draws as faint as [shown] says. The figure is made
  /// of strokes that overlap, so it fades as one picture.
  void fade(Canvas canvas, Rect bounds, VoidCallback paint) {
    if (shown >= 1) return paint();
    if (shown <= 0) return;
    canvas.saveLayer(
      bounds,
      Paint()..color = Colors.white.withValues(alpha: shown),
    );
    paint();
    canvas.restore();
  }
}

/// Fills [rect] with a sky that is [top] above and [bottom] at the ground.
void paintSky(Canvas canvas, Rect rect, Color top, Color bottom) {
  canvas.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, bottom],
      ).createShader(rect),
  );
}

/// A light of [color] that is strongest at [centre] and gone at [radius].
void paintGlow(Canvas canvas, Offset centre, double radius, Color color) {
  canvas.drawCircle(
    centre,
    radius,
    Paint()
      ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: centre, radius: radius)),
  );
}

/// Draws the figure the scenes share: limbs as round strokes and a round
/// head, in the theme's primary colour. Every length is given in [u], one
/// hundredth of the scene's height. Where [mascot] is on it draws the
/// turtle instead: a shell for the trunk, a turtle's head, green limbs.
class FigurePen {
  const FigurePen(
    this.canvas,
    this.scheme,
    this.u, {
    this.color,
    this.mascot = false,
  });

  final Canvas canvas;
  final ColorScheme scheme;
  final double u;

  /// The colour of the figure; the theme's primary when null. The turtle
  /// keeps its own.
  final Color? color;

  /// Whether the figure is the turtle.
  final bool mascot;

  Color get _body => color ?? scheme.primary;

  MascotColors get _turtle => MascotColors.of(scheme.brightness);

  /// The stroke of an arm, a leg or the body; paler for the far side.
  Paint limb({bool far = false}) {
    if (mascot) return Turtle.limb(_turtle, u, far: far);
    return Paint()
      ..color = far
          ? Color.lerp(_body, scheme.surfaceContainerHighest, 0.45)!
          : _body
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5 * u
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
  }

  /// The trunk from [hip] to [neck]: a stroke, or the turtle's shell with
  /// its dome on the back. [front] is 1 for a figure seen from the front.
  void body(Offset hip, Offset neck, {double front = 0}) {
    if (mascot) {
      Turtle.body(canvas, _turtle, u, hip, neck, front: front);
    } else {
      line(limb(), [hip, neck]);
    }
  }

  /// On four legs where the figure is the turtle: going right with its
  /// feet at [feet], [turn] through a stride. See [Turtle.walker].
  void walker(
    Offset feet,
    double turn, {
    double pace = 1,
    bool running = false,
    double breath = 0,
    bool blink = false,
  }) => Turtle.walker(
    canvas,
    _turtle,
    u,
    feet,
    turn,
    pace: pace,
    running: running,
    breath: breath,
    blink: blink,
    band: running ? scheme.tertiary : null,
  );

  /// The turtle asleep on the ground at [at]. See [Turtle.resting].
  void resting(Offset at, {double breath = 0, Color? cap}) =>
      Turtle.resting(canvas, _turtle, u, at, breath: breath, cap: cap);

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

  /// The head at [centre]. The turtle's sits on a neck from [neck] and
  /// looks the way the neck points, turned a quarter clockwise; [front]
  /// shows its face from the front, [asleep] closes its eyes.
  void head(
    Offset centre, {
    Offset? neck,
    double front = 0,
    bool asleep = false,
  }) {
    if (!mascot) {
      canvas.drawCircle(centre, 6.5 * u, Paint()..color = _body);
      return;
    }
    final up = neck == null || neck == centre
        ? const Offset(0, -1)
        : (centre - neck) / (centre - neck).distance;
    Turtle.head(
      canvas,
      _turtle,
      u,
      centre,
      neck: neck,
      up: up,
      front: front,
      asleep: asleep,
    );
  }

  /// The shadow the figure throws on the ground at [at], [width] wide to
  /// each side; fainter the higher the figure is off the ground.
  void shadow(Offset at, double width, {double strength = 1}) =>
      canvas.drawOval(
        Rect.fromCenter(center: at, width: 2 * width * u, height: 4.4 * u),
        Paint()
          ..color = scheme.shadow.withValues(
            alpha: (0.13 * strength).clamp(0.0, 1.0),
          ),
      );

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
