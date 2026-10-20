import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../theme/mascot_colors.dart';
import '../../theme/pulse_look.dart';
import '../../widgets/scene_kit.dart';
import '../../widgets/turtle.dart';

/// Plays a night back in a few seconds: the moon crosses a sky that follows
/// the stages of the night, over the figure of the workout scenes asleep in
/// bed. A good night has a clear sky full of stars and a figure that lies
/// still; a poor one has clouds, and the figure sits up whenever the user
/// was awake. The moon has a light around it, now and then a star falls,
/// and when the page opens the moon climbs to its place and the bed comes
/// in.
class SleepScene extends StatelessWidget {
  const SleepScene({
    super.key,
    required this.night,
    required this.score,
    this.height = 150,
    this.stage,
  });

  final SleepNight night;

  /// From 1 to 100; decides how clear the sky is.
  final int score;
  final double height;

  /// The height the scene is drawn for, at the bottom; above it is only
  /// more sky. The whole [height] when null.
  final double? stage;

  @override
  Widget build(BuildContext context) => SceneClock(
    // Clouds, stars and a breath: nothing here moves fast.
    rate: 30,
    builder: (context, seconds) => CustomPaint(
      size: Size(double.infinity, height),
      painter: _NightPainter(
        night: night,
        score: score,
        stage: stage,
        scheme: Theme.of(context).colorScheme,
        seconds: seconds,
        mascot: PulseLook.mascotOf(context),
        still: MediaQuery.disableAnimationsOf(context),
      ),
    ),
  );
}

class _NightPainter extends CustomPainter {
  _NightPainter({
    required this.night,
    required this.score,
    required this.stage,
    required this.scheme,
    required this.seconds,
    this.mascot = false,
    required this.still,
  }) : super(repaint: seconds);

  final SleepNight night;
  final int score;
  final double? stage;
  final ColorScheme scheme;
  final ValueListenable<double> seconds;

  /// Whether the figure is the turtle.
  final bool mascot;

  /// Whether nothing moves, so the scene has come in already.
  final bool still;

  /// Seconds the whole night takes.
  static const double _loop = 12;

  /// The first and the last part of the loop, lying down and getting up.
  static const double _edge = 0.05;

  /// How far around a moment the stages are looked at. An awakening of five
  /// minutes would otherwise pass in a blink.
  static const double _window = 0.03;

  static const double _tau = 2 * math.pi;
  static const Color _navy = Color(0xFF101A38);

  /// The stage at [progress] through the night, from 0 to 1. Null where the
  /// night has no curve.
  SleepStage? _stageAt(double progress) {
    if (progress < 0 || progress > 1) return SleepStage.awake;
    final minute = progress * night.totalMinutes;
    for (final segment in night.segments) {
      if (minute >= segment.startMinute &&
          minute < segment.startMinute + segment.minutes) {
        return segment.stage;
      }
    }
    return null;
  }

  /// How much of the time around [progress] was [stage], from 0 to 1.
  double _share(double progress, SleepStage stage) {
    const samples = 7;
    var hits = 0;
    for (var i = 0; i < samples; i++) {
      final at = progress + _window * (i / (samples - 1) * 2 - 1);
      if (_stageAt(at.clamp(0.0, 1.0)) == stage) hits++;
    }
    return hits / samples;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final time = seconds.value;
    final full = size;
    final stage = math.min(this.stage ?? full.height, full.height);
    size = Size(full.width, stage);
    final u = size.height / 100;
    final loop = time / _loop % 1;
    // The night itself lies between lying down and getting up.
    final progress = ((loop - _edge) / (1 - 2 * _edge)).clamp(0.0, 1.0);
    final curve = night.hasCurve;

    final deep = curve ? _share(progress, SleepStage.deep) : 0.0;
    final rem = curve ? _share(progress, SleepStage.rem) : 0.0;
    // Awake at both ends, and in between whenever the night says so. A
    // night without a curve tosses as often as its time awake is long.
    final ends = math
        .max(1 - loop / _edge, (loop - (1 - _edge)) / _edge)
        .clamp(0.0, 1.0);
    final restless = curve
        ? _share(progress, SleepStage.awake)
        : _tossing(time);
    final up = Curves.easeInOut.transform(math.max(ends, restless));
    final dawn = Curves.easeIn.transform(
      ((loop - 0.82) / 0.18).clamp(0.0, 1.0),
    );

    final enter = SceneEntrance.at(time, still: still);
    final sky = _sky(deep, rem, up, dawn);
    // Darker overhead than at the horizon.
    paintSky(
      canvas,
      Offset.zero & full,
      Color.lerp(sky, Colors.black, 0.28)!,
      Color.lerp(sky, scheme.primary, 0.1)!,
    );
    canvas.translate(0, full.height - stage);
    _stars(canvas, size, u, time, (1 - dawn) * enter.shown);
    if (dawn < 0.5) _shootingStar(canvas, size, u, time);
    _moon(canvas, size, u, loop, time, enter);
    _clouds(canvas, size, u, time);
    canvas.translate(0, enter.drop * 20 * u);
    enter.fade(
      canvas,
      Offset.zero & size,
      () => _bed(canvas, size, u, time, up: up, deep: deep, rem: rem),
    );
  }

  /// A night without a curve: the share of it spent awake says how often
  /// the figure stirs, from never to every few seconds.
  double _tossing(double time) {
    final share = night.totalMinutes <= 0
        ? 0.0
        : night.minutesIn(SleepStage.awake) / night.totalMinutes;
    if (share < 0.04) return 0;
    final every = (0.5 / share).clamp(2.5, 9.0);
    final phase = time % every / every;
    return phase > 0.86 ? math.sin((phase - 0.86) / 0.14 * math.pi) * 0.5 : 0;
  }

  Color _sky(double deep, double rem, double up, double dawn) {
    // A night sky is dark blue under any theme; the theme only tints it.
    final night = Color.lerp(_navy, scheme.primary, 0.12)!;
    // Darkest in deep sleep, a shade lighter in a dream or awake.
    var colour = Color.lerp(night, Colors.black, 0.25 * deep)!;
    colour = Color.lerp(colour, scheme.tertiary, 0.16 * rem)!;
    colour = Color.lerp(colour, scheme.primary, 0.14 * up)!;
    return Color.lerp(colour, scheme.tertiaryContainer, 0.7 * dawn)!;
  }

  void _stars(Canvas canvas, Size size, double u, double time, double shown) {
    final count = 5 + (score.clamp(0, 100) * 0.24).round();
    final random = math.Random(7);
    for (var i = 0; i < count; i++) {
      final at = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height * 0.62,
      );
      // Each star in a rhythm of its own, and bright only for a moment.
      final wave = 0.5 + 0.5 * math.sin(time * (0.6 + i % 7 * 0.23) + i * 1.7);
      final twinkle = 0.45 + 0.55 * wave * wave;
      canvas.drawCircle(
        at,
        (0.7 + random.nextDouble() * 0.9) * u,
        Paint()..color = Colors.white.withValues(alpha: 0.9 * twinkle * shown),
      );
    }
  }

  /// A star that falls every few seconds, with a tail that fades.
  void _shootingStar(Canvas canvas, Size size, double u, double time) {
    final fall = time % 8 / 0.9;
    if (fall >= 1) return;
    final at = Offset(
      size.width * (0.78 - 0.3 * fall),
      size.height * (0.06 + 0.3 * fall),
    );
    final tail = at + Offset(34 * u, -30 * u);
    canvas.drawLine(
      at,
      tail,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.9 * math.sin(math.pi * fall)),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromPoints(at, tail))
        ..strokeWidth = 1.4 * u
        ..strokeCap = StrokeCap.round,
    );
  }

  void _moon(
    Canvas canvas,
    Size size,
    double u,
    double loop,
    double time,
    SceneEntrance enter,
  ) {
    // It climbs to its place when the scene comes in.
    final centre = Offset(
      size.width * (0.1 + 0.8 * loop),
      size.height * (0.44 - 0.3 * math.sin(math.pi * loop)) +
          enter.drop * 40 * u,
    );
    final pale = Color.lerp(scheme.tertiaryContainer, Colors.white, 0.6)!;
    paintGlow(
      canvas,
      centre,
      (29 + 1.6 * math.sin(time * 0.9)) * u,
      pale.withValues(alpha: 0.32),
    );
    // The disc without the part another disc covers leaves a crescent.
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: centre, radius: 8 * u)),
        Path()..addOval(
          Rect.fromCircle(
            center: centre + Offset(3.6 * u, -2.2 * u),
            radius: 7 * u,
          ),
        ),
      ),
      Paint()..color = pale,
    );
  }

  /// The poorer the night, the more clouds drift across.
  void _clouds(Canvas canvas, Size size, double u, double time) {
    final count = ((70 - score) / 14).ceil().clamp(0, 4);
    final paint = Paint()
      ..color = scheme.surfaceContainerHighest.withValues(alpha: 0.3);
    for (var i = 0; i < count; i++) {
      final span = size.width + 60 * u;
      final x = (time * (5 + i * 2) * u + i * span / count) % span - 30 * u;
      final y = (16 + i % 3 * 13) * u;
      for (final (dx, dy, radius) in const [
        (-9.0, 1.5, 6.0),
        (0.0, -1.5, 8.5),
        (10.0, 1.0, 6.5),
      ]) {
        canvas.drawCircle(Offset(x + dx * u, y + dy * u), radius * u, paint);
      }
    }
  }

  void _bed(
    Canvas canvas,
    Size size,
    double u,
    double time, {
    required double up,
    required double deep,
    required double rem,
  }) {
    // The figure in a light tone of the theme, to stand out from the sky.
    final pen = FigurePen(
      canvas,
      scheme,
      u,
      mascot: mascot,
      color: scheme.brightness == Brightness.light
          ? scheme.primaryContainer
          : scheme.primary,
    );
    final x = size.width * 0.5;
    final floor = size.height - 6 * u;
    final top = floor - 15 * u;
    // Slower and deeper in deep sleep.
    final breath = 0.5 - 0.5 * math.cos(_tau * time / (3.4 + 1.4 * deep));

    // Headboard, mattress and legs.
    final frame = Paint()..color = scheme.secondaryContainer;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x - 45 * u, top - 20 * u, x - 39 * u, floor),
          Radius.circular(3 * u),
        ),
        frame,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x - 42 * u, top, x + 42 * u, top + 9 * u),
          Radius.circular(4 * u),
        ),
        frame,
      )
      ..drawRect(
        Rect.fromLTRB(x + 37 * u, top + 9 * u, x + 41 * u, floor),
        frame,
      );
    // Pillow.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x - 38 * u, top - 6 * u, x - 18 * u, top + 1 * u),
        Radius.circular(3.5 * u),
      ),
      Paint()..color = scheme.surfaceBright,
    );

    // Lying flat, or propped up while awake.
    final hip = Offset(x - 2 * u, top - 4 * u);
    final lean = 0.06 + 1.05 * up;
    final along = Offset(-math.cos(lean), -math.sin(lean));
    final shoulder = hip + along * 21 * u;
    if (mascot) {
      // On its belly, the shell up and the head on the pillow, looking
      // away from the shell.
      final colors = MascotColors.of(scheme.brightness);
      Turtle.body(canvas, colors, u, shoulder, hip);
      Turtle.head(
        canvas,
        colors,
        u,
        shoulder + along * 9.5 * u,
        neck: shoulder,
        leftward: true,
        asleep: up < 0.5,
        cap: scheme.tertiaryContainer,
      );
    } else {
      pen
        ..line(pen.limb(), [hip, shoulder])
        ..head(shoulder + along * 9.5 * u);
    }

    // The blanket lies over the figure in one soft line: high over the
    // chest, where it rises and falls with the breath, and low at the feet.
    final rise = (7 + 3.2 * breath) * u;
    final from = x - (12 - 6 * up) * u;
    canvas.drawPath(
      Path()
        ..moveTo(from, top + 2 * u)
        ..lineTo(from, top - rise * 0.5)
        ..cubicTo(
          from + 3 * u,
          top - rise * 1.25,
          x + 12 * u,
          top - rise * 1.1,
          x + 20 * u,
          top - 6.5 * u,
        )
        ..cubicTo(
          x + 28 * u,
          top - 5.5 * u,
          x + 34 * u,
          top - 6.5 * u,
          x + 38 * u,
          top - 2 * u,
        )
        ..lineTo(x + 38 * u, top + 2 * u)
        ..close(),
      Paint()..color = scheme.tertiary,
    );
    final hand = Offset(x + 4 * u, top - rise - 1 * u);
    pen.line(pen.limb(), [
      shoulder,
      FigurePen.joint(shoulder, hand, 12 * u, 11 * u, 1),
      hand,
    ]);

    final above = shoulder + along * 9.5 * u + Offset(8 * u, -9 * u);
    if (deep > 0.5 && up < 0.2) _snores(canvas, u, time, above);
    if (rem > 0.5 && up < 0.2) _dream(canvas, u, time, above);
  }

  /// Three letters z that rise from the head in a curve, tilting as they
  /// go, and fade.
  void _snores(Canvas canvas, double u, double time, Offset from) {
    for (var i = 0; i < 3; i++) {
      final age = (time / 3.2 + i / 3) % 1;
      final size = (3 + 4 * age) * u;
      final at =
          from +
          Offset((9 * age + 3 * math.sin(age * 5 + i)) * u, -28 * age * u);
      canvas
        ..save()
        ..translate(at.dx, at.dy)
        ..rotate(0.25 * math.sin(age * 4 + i));
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.9 * math.sin(math.pi * age))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * u
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas
        ..drawPath(
          Path()
            ..moveTo(0, 0)
            ..relativeLineTo(size, 0)
            ..relativeLineTo(-size, size)
            ..relativeLineTo(size, 0),
          paint,
        )
        ..restore();
    }
  }

  /// The bubbles of a dream.
  void _dream(Canvas canvas, double u, double time, Offset from) {
    final pulse = 0.5 + 0.5 * math.sin(time * 2.2);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55 + 0.25 * pulse);
    for (final (dx, dy, radius) in const [
      (0.0, 0.0, 1.6),
      (5.0, -6.0, 2.6),
      (13.0, -15.0, 6.5),
    ]) {
      canvas.drawCircle(
        from + Offset(dx * u, dy * u),
        (radius + 0.5 * pulse) * u,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_NightPainter oldDelegate) =>
      oldDelegate.mascot != mascot ||
      oldDelegate.night != night ||
      oldDelegate.score != score ||
      oldDelegate.stage != stage ||
      oldDelegate.still != still ||
      oldDelegate.scheme != scheme;
}
