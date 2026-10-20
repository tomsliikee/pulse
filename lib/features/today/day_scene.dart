import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/pulse_look.dart';
import '../../widgets/scene_kit.dart';

/// The day at [untilMinute]: the sun stands where the time of day puts it,
/// in a sky that follows it, over the figure of the other scenes. By day
/// the figure walks, the livelier the more steps the hour has; at night it
/// stands and breathes. Hills pass in three rows, grass sways and now and
/// then birds cross. A good day has a clear sky, a poor one clouds. When the
/// page opens the land rises, the sun climbs to its place and the figure
/// walks in.
class DayScene extends StatelessWidget {
  const DayScene({
    super.key,
    required this.untilMinute,
    required this.score,
    this.hours,
    this.steps = 0,
    this.height = 150,
    this.stage,
    this.figure = true,
  });

  /// Whether the sky of the scene is dark at [minute] of the day, so what
  /// is written over it has to be light.
  static bool isDarkAt(int minute) =>
      _DayPainter._daylight(minute.toDouble()) < 0.5;

  /// Minute of the day the scene stands at: now for today, the evening for
  /// a day that is over.
  final int untilMinute;

  /// From 1 to 100; decides how clear the sky is.
  final int score;

  /// The steps of each hour of the day, where the store has them.
  final List<double?>? hours;

  /// The steps of the whole day, used where [hours] is missing.
  final double steps;

  final double height;

  /// The height the scene is drawn for, at the bottom of [height]; above it
  /// there is only more sky. The whole height when null.
  final double? stage;

  /// False for a small picture of the day's sky without the walker.
  final bool figure;

  @override
  Widget build(BuildContext context) => SceneClock(
    // Clouds, stars and a breath: nothing here moves fast.
    rate: 30,
    builder: (context, seconds) => CustomPaint(
      size: Size(double.infinity, height),
      painter: _DayPainter(
        scene: this,
        scheme: Theme.of(context).colorScheme,
        seconds: seconds,
        mascot: PulseLook.mascotOf(context),
        still: MediaQuery.disableAnimationsOf(context),
      ),
    ),
  );
}

class _DayPainter extends CustomPainter {
  _DayPainter({
    required this.scene,
    required this.scheme,
    required this.seconds,
    this.mascot = false,
    required this.still,
  }) : super(repaint: seconds);

  final DayScene scene;
  final ColorScheme scheme;
  final ValueListenable<double> seconds;

  /// Whether the figure is the turtle.
  final bool mascot;

  /// Whether nothing moves, so the scene has come in already.
  final bool still;

  /// How much ground a walking figure covers in a second, in hundredths of
  /// the scene's height: one stride in a little over a second.
  static const double _walk = 30;

  static const double _tau = 2 * math.pi;
  static const Color _navy = Color(0xFF101A38);

  /// The sun is warm under any theme; the theme only tints it.
  static const Color _sunlight = Color(0xFFFFC55A);

  /// Where the figure stands, as a share of the width: left of the middle,
  /// so the sun at noon does not sit on its head.
  static const double _figureAt = 0.4;

  /// How light it is at [minute], from 0 at night to 1 in the day.
  static double _daylight(double minute) {
    double ramp(double from, double to) =>
        Curves.easeInOut.transform(((minute - from) / (to - from)).clamp(0, 1));
    return math.min(ramp(5 * 60, 7.5 * 60), 1 - ramp(18.5 * 60, 21 * 60));
  }

  /// The steps taken up to [minute], which is how far the ground has passed.
  double _stepsUntil(double minute) {
    final hours = scene.hours;
    if (hours == null) {
      return scene.steps * ((minute - 8 * 60) / (12 * 60)).clamp(0.0, 1.0);
    }
    var sum = 0.0;
    final whole = (minute / 60).floor().clamp(0, 24);
    for (var hour = 0; hour < whole; hour++) {
      sum += hours[hour] ?? 0;
    }
    if (whole < 24) sum += (hours[whole] ?? 0) * (minute / 60 - whole);
    return sum;
  }

  /// How lively the figure walks at [minute], from 0 standing to 1. It walks
  /// by day, and more so in an hour with many steps.
  double _pace(double minute, double light) {
    if (light < 0.5) return 0;
    final hour = (minute / 60).floor().clamp(0, 23);
    final steps = scene.hours?[hour] ?? scene.steps / 14;
    return 0.5 + 0.35 * (steps / 3000).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final time = seconds.value;
    final full = size;
    final stage = math.min(scene.stage ?? full.height, full.height);
    size = Size(full.width, stage);
    final u = size.height / 100;
    // The scene shows its minute as it is, however early; the day is not
    // played back, only what is in the picture moves.
    final minute = scene.untilMinute.toDouble();
    final light = _daylight(minute);

    final enter = SceneEntrance.at(time, still: still);
    final sky = _sky(minute, light);
    // Lighter towards the ground by day; a night sky is one colour.
    paintSky(
      canvas,
      Offset.zero & full,
      sky,
      Color.lerp(sky, scheme.surfaceBright, 0.5 * light)!,
    );
    canvas.translate(0, full.height - stage);
    _stars(canvas, size, u, time, 1 - light);
    _sunOrMoon(canvas, size, u, minute, light, time, enter);
    _clouds(canvas, size, u, time, light);
    if (scene.figure && light > 0.6) _birds(canvas, size, u, time);

    final ground = size.height - 14 * u;
    final pace = scene.figure ? _pace(minute, light) : 0.0;
    // A hundred steps move the ground by a third of the scene's height, and
    // a figure that walks moves it on.
    final travelled =
        _stepsUntil(minute) / 100 * size.height / 3 +
        (pace > 0 ? time * _walk * u : 0);
    final drop = enter.drop * 26 * u;
    _hills(
      canvas,
      size,
      ground + drop * 1.4,
      travelled * 0.07,
      31 * u,
      0.7,
      0.32,
      light,
    );
    _hills(
      canvas,
      size,
      ground + drop,
      travelled * 0.18,
      24 * u,
      0.9,
      0.5,
      light,
    );
    _hills(
      canvas,
      size,
      ground + drop * 0.6,
      travelled * 0.45,
      14 * u,
      1.7,
      0.85,
      light,
    );
    if (scene.figure) _grass(canvas, size, u, ground, travelled, time, light);
    _ground(canvas, size, u, ground, travelled, light);
    if (!scene.figure) return;

    final pen = FigurePen(
      canvas,
      scheme,
      u,
      mascot: mascot,
      color: Color.lerp(_nightFigure, scheme.primary, light),
    );
    final x = size.width * (_figureAt - 0.2 * (1 - enter.arrived));
    // The strides follow the ground, so the feet do not slide.
    final turn = _tau * (travelled / 38 / u % 1);
    enter.fade(
      canvas,
      Offset.zero & size,
      () => _walker(pen, u, x, ground, turn, time, pace: pace, running: false),
    );
  }

  /// The figure in a light tone at night, to stand out from the dark sky.
  Color get _nightFigure => scheme.brightness == Brightness.light
      ? scheme.primaryContainer
      : scheme.primary;

  Color _sky(double minute, double light) {
    final night = Color.lerp(_navy, scheme.primary, 0.12)!;
    final day = Color.lerp(
      scheme.primaryContainer,
      scheme.surfaceBright,
      0.25,
    )!;
    final colour = Color.lerp(night, day, light)!;
    // Dawn and dusk tint the sky while it is neither dark nor light.
    return Color.lerp(
      colour,
      scheme.tertiaryContainer,
      0.75 * 4 * light * (1 - light),
    )!;
  }

  void _stars(Canvas canvas, Size size, double u, double time, double shown) {
    if (shown <= 0.02) return;
    final count = 5 + (scene.score.clamp(0, 100) * 0.2).round();
    final random = math.Random(11);
    for (var i = 0; i < count; i++) {
      final at = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height * 0.55,
      );
      final twinkle = 0.55 + 0.45 * math.sin(time * (0.8 + i % 5 * 0.3) + i);
      canvas.drawCircle(
        at,
        (0.7 + random.nextDouble() * 0.9) * u,
        Paint()..color = Colors.white.withValues(alpha: 0.85 * twinkle * shown),
      );
    }
  }

  void _sunOrMoon(
    Canvas canvas,
    Size size,
    double u,
    double minute,
    double light,
    double time,
    SceneEntrance enter,
  ) {
    // Both climb to their place when the scene comes in.
    final climb = Offset(0, enter.drop * 60 * u);
    // The sun is up from six to nine in the evening, the moon before it.
    final across = ((minute - 6 * 60) / (15 * 60)).clamp(0.0, 1.0);
    final centre =
        Offset(
          size.width * (0.1 + 0.8 * across),
          size.height * (0.46 - 0.37 * math.sin(math.pi * across)),
        ) +
        climb;
    if (light > 0.3) {
      final sun = Color.lerp(_sunlight, scheme.primary, 0.15)!;
      // The light around it breathes, and its rays turn slowly.
      paintGlow(
        canvas,
        centre,
        (25 + 1.3 * math.sin(time * 1.3)) * u,
        sun.withValues(alpha: 0.5 * light),
      );
      final ray = Paint()..color = sun.withValues(alpha: 0.3 * light);
      const rays = 10;
      for (var i = 0; i < rays; i++) {
        final angle = time * 0.12 + i * _tau / rays;
        final out = Offset(math.cos(angle), math.sin(angle));
        final across = Offset(-out.dy, out.dx) * 1.6 * u;
        final from = centre + out * 9.5 * u;
        canvas.drawPath(
          Path()
            ..moveTo(from.dx - across.dx, from.dy - across.dy)
            ..lineTo(
              centre.dx + out.dx * (14.5 + 1.5 * math.sin(time * 2 + i)) * u,
              centre.dy + out.dy * (14.5 + 1.5 * math.sin(time * 2 + i)) * u,
            )
            ..lineTo(from.dx + across.dx, from.dy + across.dy)
            ..close(),
          ray,
        );
      }
      canvas.drawCircle(
        centre,
        7 * u,
        Paint()..color = sun.withValues(alpha: light),
      );
      return;
    }
    final moon = Offset(size.width * 0.8, size.height * 0.24) + climb;
    final pale = Color.lerp(scheme.tertiaryContainer, Colors.white, 0.6)!;
    paintGlow(
      canvas,
      moon,
      (28 + 1.5 * math.sin(time * 0.9)) * u,
      pale.withValues(alpha: 0.3),
    );
    // The disc without the part another disc covers leaves a crescent.
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: moon, radius: 8 * u)),
        Path()..addOval(
          Rect.fromCircle(
            center: moon + Offset(3.6 * u, -2.2 * u),
            radius: 7 * u,
          ),
        ),
      ),
      Paint()..color = pale,
    );
  }

  /// Two birds that cross the sky every few seconds.
  void _birds(Canvas canvas, Size size, double u, double time) {
    final flight = time % 11 / 5;
    if (flight >= 1) return;
    final paint = Paint()
      ..color = scheme.onSurfaceVariant.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3 * u
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final (behind, scale) in const [(0.0, 1.0), (0.06, 0.8)]) {
      final at = Offset(
        size.width * (1.05 - 1.2 * (flight + behind)),
        (22 + 3 * math.sin(flight * 9 + behind * 20) + behind * 60) * u,
      );
      final flap = math.sin(time * 9 + behind * 30) * 2.2 * u * scale;
      canvas.drawPath(
        Path()
          ..moveTo(at.dx - 4 * u * scale, at.dy - flap)
          ..lineTo(at.dx, at.dy)
          ..lineTo(at.dx + 4 * u * scale, at.dy - flap),
        paint,
      );
    }
  }

  /// Tufts of grass along the ground that pass by and sway.
  void _grass(
    Canvas canvas,
    Size size,
    double u,
    double ground,
    double travelled,
    double time,
    double light,
  ) {
    final paint = Paint()
      ..color = Color.lerp(
        Color.lerp(_navy, scheme.secondary, 0.4),
        Color.lerp(scheme.secondaryContainer, scheme.secondary, 0.35),
        light,
      )!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * u
      ..strokeCap = StrokeCap.round;
    final gap = 29 * u;
    final first = (travelled / gap).floor();
    for (var i = 0; -(travelled % gap) + i * gap < size.width; i++) {
      final x = -(travelled % gap) + i * gap;
      if (x < 12 * u || x > size.width - 12 * u) continue;
      // Not a fence: two of five places on the ground are bare.
      if (const [1, 3].contains((first + i) % 5)) continue;
      // Each tuft sways by where it stands on the ground, not on the screen.
      final sway = math.sin(time * 1.6 + (x + travelled) / gap) * 1.6 * u;
      for (final blade in const [-1.0, 0.0, 1.0]) {
        final tip = Offset(
          x + blade * 3 * u + sway,
          ground - (blade == 0 ? 6 : 4) * u,
        );
        canvas.drawPath(
          Path()
            ..moveTo(x + blade * 1.6 * u, ground + 2.4 * u)
            ..quadraticBezierTo(
              x + blade * 2 * u,
              ground - 2 * u,
              tip.dx,
              tip.dy,
            ),
          paint,
        );
      }
    }
  }

  /// The poorer the day, the more clouds drift across, each bobbing a
  /// little.
  void _clouds(Canvas canvas, Size size, double u, double time, double light) {
    final count = ((70 - scene.score) / 14).ceil().clamp(0, 4);
    final paint = Paint()
      ..color = Color.lerp(
        scheme.surfaceContainerHighest,
        scheme.surfaceBright,
        light,
      )!.withValues(alpha: 0.3 + 0.45 * light);
    for (var i = 0; i < count; i++) {
      final span = size.width + 60 * u;
      final x = (time * (5 + i * 2) * u + i * span / count) % span - 30 * u;
      final y = (16 + i % 3 * 13 + math.sin(time * 0.5 + i * 2)) * u;
      for (final (dx, dy, radius) in const [
        (-9.0, 1.5, 6.0),
        (0.0, -1.5, 8.5),
        (10.0, 1.0, 6.5),
      ]) {
        canvas.drawCircle(Offset(x + dx * u, y + dy * u), radius * u, paint);
      }
    }
  }

  /// A row of soft hills, [shift] pixels along.
  void _hills(
    Canvas canvas,
    Size size,
    double ground,
    double shift,
    double height,
    double waves,
    double opacity,
    double light,
  ) {
    final length = size.width / waves;
    final path = Path()..moveTo(0, size.height);
    for (var x = 0.0; x <= size.width + 4; x += 4) {
      final along = (x + shift) / length * _tau;
      final rise = 0.5 + 0.32 * math.sin(along) + 0.18 * math.sin(along * 2.3);
      path.lineTo(x, ground - height * rise);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = Color.lerp(
          Color.lerp(_navy, scheme.secondary, 0.3),
          scheme.secondaryContainer,
          light,
        )!.withValues(alpha: opacity),
    );
  }

  /// The line the figure stands on, with marks that pass by.
  void _ground(
    Canvas canvas,
    Size size,
    double u,
    double ground,
    double travelled,
    double light,
  ) {
    final line = Paint()
      ..color = Color.lerp(scheme.outline, scheme.outlineVariant, light)!
      ..strokeWidth = 2.2 * u
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(8 * u, ground + 3.4 * u),
      Offset(size.width - 8 * u, ground + 3.4 * u),
      line,
    );
    final gap = 38 * u;
    for (var x = -(travelled % gap); x < size.width; x += gap) {
      if (x < 12 * u || x > size.width - 20 * u) continue;
      canvas.drawLine(
        Offset(x, ground + 8.5 * u),
        Offset(x + 9 * u, ground + 8.5 * u),
        line,
      );
    }
  }

  /// Seen from the side, moving to the right; standing where [pace] is zero.
  void _walker(
    FigurePen pen,
    double u,
    double x,
    double ground,
    double turn,
    double time, {
    required double pace,
    required bool running,
  }) {
    const part = 17.0;
    final swing = (running ? 0.85 : 0.55) * pace;
    final knee = (running ? 1.5 : 0.7) * pace;
    final lean = (running ? 0.26 : 0.07) * pace;
    // Standing, the figure only breathes.
    final breath = (1 - pace) * 0.6 * math.sin(time * 1.8);
    final lift = running
        ? 5 * math.sin(turn).abs()
        : 1.2 * pace * math.cos(2 * turn).abs();
    final hip = Offset(x, ground - (2 * part * 0.95 + lift) * u);
    pen.shadow(Offset(x, ground + 3.4 * u), pen.mascot ? 26 : 13);
    if (pen.mascot) {
      pen.walker(
        Offset(x, ground + 2 * u),
        turn,
        pace: pace,
        running: running,
        breath: breath,
      );
      return;
    }

    List<Offset> leg(double phase) {
      final thigh = swing * math.sin(phase);
      final shin = thigh - knee * math.max(0.0, math.cos(phase));
      final kneeAt = hip + Offset(math.sin(thigh), math.cos(thigh)) * part * u;
      final foot = kneeAt + Offset(math.sin(shin), math.cos(shin)) * part * u;
      return [hip, kneeAt, foot];
    }

    final up = Offset(math.sin(lean), -math.cos(lean));
    final shoulder = hip + up * (24 + breath) * u;

    List<Offset> arm(double phase) {
      final upper = -swing * 0.9 * math.sin(phase);
      final lower = upper + (running ? 1.5 : 0.35) * math.max(pace, 0.25);
      final elbow =
          shoulder + Offset(math.sin(upper), math.cos(upper)) * 12 * u;
      final hand = elbow + Offset(math.sin(lower), math.cos(lower)) * 11 * u;
      return [shoulder, elbow, hand];
    }

    pen
      ..line(pen.limb(far: true), leg(turn + math.pi))
      ..line(pen.limb(far: true), arm(turn + math.pi))
      ..body(hip, shoulder)
      ..head(shoulder + up * 9.5 * u, neck: shoulder)
      ..line(pen.limb(), leg(turn))
      ..line(pen.limb(), arm(turn));
  }

  @override
  bool shouldRepaint(_DayPainter oldDelegate) =>
      oldDelegate.mascot != mascot ||
      oldDelegate.scene.untilMinute != scene.untilMinute ||
      oldDelegate.scene.score != scene.score ||
      oldDelegate.scene.hours != scene.hours ||
      oldDelegate.scene.steps != scene.steps ||
      oldDelegate.still != still ||
      oldDelegate.scheme != scheme;
}
