import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../widgets/scene_kit.dart';

/// Plays a day back in a few seconds, from the early morning to [untilMinute]:
/// the sun crosses a sky that follows the time of day, over the figure of
/// the other scenes. It sleeps until the night is over, walks as fast as the
/// steps of the hour say, runs during a workout and then stands at the
/// moment the day has reached. A good day has a clear sky, a poor one clouds.
class DayScene extends StatelessWidget {
  const DayScene({
    super.key,
    required this.untilMinute,
    required this.score,
    this.hours,
    this.steps = 0,
    this.wakeMinute,
    this.workouts = const [],
    this.height = 150,
  });

  /// Minute of the day the scene runs to: now for today, the evening for a
  /// day that is over.
  final int untilMinute;

  /// From 1 to 100; decides how clear the sky is.
  final int score;

  /// The steps of each hour of the day, where the store has them.
  final List<double?>? hours;

  /// The steps of the whole day, used where [hours] is missing.
  final double steps;

  /// When the night ended, as a minute of the day.
  final int? wakeMinute;

  /// The workouts that started on the day.
  final List<Workout> workouts;
  final double height;

  @override
  Widget build(BuildContext context) => SceneClock(
    builder: (context, seconds) => CustomPaint(
      size: Size(double.infinity, height),
      painter: _DayPainter(
        scene: this,
        scheme: Theme.of(context).colorScheme,
        seconds: seconds,
        // Where nothing moves, the scene shows the moment the day is at.
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
    required this.still,
  }) : super(repaint: seconds);

  final DayScene scene;
  final ColorScheme scheme;
  final ValueListenable<double> seconds;
  final bool still;

  /// Seconds the loop takes, and the share of it the day plays in; the rest
  /// rests on the moment the day has reached.
  static const double _loop = 12;
  static const double _play = 0.68;

  /// Where the playback starts, and how long it is at least.
  static const int _start = 4 * 60 + 30;
  static const int _shortest = 90;
  static const int _wakeDefault = 6 * 60 + 30;

  /// Steps an hour that are a brisk walk.
  static const double _brisk = 1500;

  static const double _tau = 2 * math.pi;
  static const Color _navy = Color(0xFF101A38);

  /// The sun is warm under any theme; the theme only tints it.
  static const Color _sunlight = Color(0xFFFFC55A);

  /// Where the figure stands, as a share of the width: left of the middle,
  /// so the sun at noon does not sit on its head.
  static const double _figureAt = 0.4;

  int get _end => math.max(scene.untilMinute, _start + _shortest);

  /// How light it is at [minute], from 0 at night to 1 in the day.
  static double _daylight(double minute) {
    double ramp(double from, double to) =>
        Curves.easeInOut.transform(((minute - from) / (to - from)).clamp(0, 1));
    return math.min(ramp(5 * 60, 7.5 * 60), 1 - ramp(18.5 * 60, 21 * 60));
  }

  /// The steps an hour around [minute].
  double _stepsAnHour(double minute) {
    final hours = scene.hours;
    if (hours == null) {
      // Without hours the day's steps are spread over its waking part.
      final awake = minute >= 8 * 60 && minute <= 20 * 60;
      return awake ? scene.steps / 12 : 0;
    }
    // Between the middles of two hours, so the pace changes smoothly.
    final at = (minute / 60 - 0.5).clamp(0.0, 23.0);
    final below = at.floor();
    final above = math.min(below + 1, 23);
    final a = hours[below] ?? 0;
    final b = hours[above] ?? 0;
    return a + (b - a) * (at - below);
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

  bool _inWorkout(double minute) {
    for (final workout in scene.workouts) {
      final from = workout.start.hour * 60 + workout.start.minute;
      if (minute >= from && minute < from + workout.minutes) return true;
    }
    return false;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final time = seconds.value;
    final u = size.height / 100;
    final loop = still ? 1.0 : time / _loop % 1;
    final played = Curves.easeInOut.transform((loop / _play).clamp(0.0, 1.0));
    final minute = _start + (_end - _start) * played;
    final resting = loop >= _play;
    final light = _daylight(minute);

    final sky = _sky(minute, light);
    canvas.drawRect(Offset.zero & size, Paint()..color = sky);
    _stars(canvas, size, u, time, 1 - light);
    _sunOrMoon(canvas, size, u, minute, light, sky);
    _clouds(canvas, size, u, time, light);

    final ground = size.height - 14 * u;
    // A hundred steps move the ground by a third of the scene's height.
    final travelled = _stepsUntil(minute) / 100 * size.height / 3;
    _hills(canvas, size, ground, travelled * 0.18, 24 * u, 0.9, 0.5, light);
    _hills(canvas, size, ground, travelled * 0.45, 14 * u, 1.7, 0.85, light);
    _ground(canvas, size, u, ground, travelled, light);

    final pen = FigurePen(
      canvas,
      scheme,
      u,
      color: Color.lerp(_nightFigure, scheme.primary, light),
    );
    final x = size.width * _figureAt;
    final wake = scene.wakeMinute ?? _wakeDefault;
    if (minute < wake && !resting) {
      _sleeper(canvas, pen, u, x, ground, time);
    } else {
      final running = !resting && _inWorkout(minute);
      final pace = resting
          ? 0.0
          : running
          ? 1.0
          : (_stepsAnHour(minute) / _brisk).clamp(0.0, 1.0);
      // The strides follow the ground, so the feet do not slide.
      final turn = _tau * (travelled / (running ? 62 : 38) / u % 1);
      _walker(pen, u, x, ground, turn, time, pace: pace, running: running);
    }
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
    Color sky,
  ) {
    // The sun is up from six to nine in the evening, the moon before it.
    final across = ((minute - 6 * 60) / (15 * 60)).clamp(0.0, 1.0);
    final centre = Offset(
      size.width * (0.1 + 0.8 * across),
      size.height * (0.46 - 0.37 * math.sin(math.pi * across)),
    );
    if (light > 0.3) {
      final sun = Color.lerp(_sunlight, scheme.primary, 0.15)!;
      canvas
        ..drawCircle(
          centre,
          12 * u,
          Paint()..color = sun.withValues(alpha: 0.22 * light),
        )
        ..drawCircle(
          centre,
          7 * u,
          Paint()..color = sun.withValues(alpha: light),
        );
      return;
    }
    final moon = Offset(size.width * 0.8, size.height * 0.24);
    canvas
      ..drawCircle(
        moon,
        8 * u,
        Paint()
          ..color = Color.lerp(scheme.tertiaryContainer, Colors.white, 0.6)!,
      )
      // The sky's colour over a part of the disc leaves a crescent.
      ..drawCircle(
        moon + Offset(3.6 * u, -2.2 * u),
        7 * u,
        Paint()..color = sky,
      );
  }

  /// The poorer the day, the more clouds drift across.
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
      ..line(pen.limb(), [hip, shoulder])
      ..head(shoulder + up * 9.5 * u)
      ..line(pen.limb(), leg(turn))
      ..line(pen.limb(), arm(turn));
  }

  /// Lying on the ground under a blanket, before the night is over.
  void _sleeper(
    Canvas canvas,
    FigurePen pen,
    double u,
    double x,
    double ground,
    double time,
  ) {
    final breath = 0.5 - 0.5 * math.cos(_tau * time / 4);
    final hip = Offset(x + 2 * u, ground - 3 * u);
    final shoulder = hip + Offset(-21 * u, -1.5 * u);
    final head = shoulder + Offset(-9.5 * u, -1 * u);
    pen
      ..line(pen.limb(), [hip, shoulder])
      ..head(head);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          x - 12 * u,
          ground - (9 + 2.2 * breath) * u,
          x + 34 * u,
          ground + 2 * u,
        ),
        Radius.circular(5 * u),
      ),
      Paint()..color = scheme.tertiary,
    );
    // Three letters z that rise from the head and fade.
    for (var i = 0; i < 3; i++) {
      final age = (time / 2.6 + i / 3) % 1;
      final size = (3 + 4 * age) * u;
      final at = head + Offset((8 + 9 * age) * u, (-10 - 26 * age) * u);
      canvas.drawPath(
        Path()
          ..moveTo(at.dx, at.dy)
          ..relativeLineTo(size, 0)
          ..relativeLineTo(-size, size)
          ..relativeLineTo(size, 0),
        Paint()
          ..color = Colors.white.withValues(
            alpha: 0.9 * math.sin(math.pi * age),
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * u
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_DayPainter oldDelegate) =>
      oldDelegate.scene.untilMinute != scene.untilMinute ||
      oldDelegate.scene.score != scene.score ||
      oldDelegate.scene.hours != scene.hours ||
      oldDelegate.scene.steps != scene.steps ||
      oldDelegate.scheme != scheme ||
      oldDelegate.still != still;
}
