import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../widgets/scene_kit.dart';

/// A small figure doing a workout of [type] in front of a passing
/// landscape: walking, running, hiking, riding, swimming, lifting or
/// breathing. Drawn by the app in the colours of the theme. It stands still
/// where the system asks for no animations.
class WorkoutScene extends StatelessWidget {
  const WorkoutScene({
    super.key,
    required this.type,
    this.height = 150,
    this.stage,
  });

  final WorkoutType type;
  final double height;

  /// The height the scene is drawn for, at the bottom; above it is only
  /// its sky. The whole [height] when null.
  final double? stage;

  @override
  Widget build(BuildContext context) => SceneClock(
    builder: (context, seconds) => CustomPaint(
      size: Size(double.infinity, height),
      painter: _ScenePainter(
        type: type,
        stage: stage,
        scheme: Theme.of(context).colorScheme,
        seconds: seconds,
      ),
    ),
  );
}

/// How one kind of workout moves.
class _Gait {
  const _Gait({required this.cycle, required this.travel});

  /// Seconds one stride, turn of the pedals or breath takes.
  final double cycle;

  /// How fast the ground passes, in scene heights per second.
  final double travel;

  static _Gait of(WorkoutType type) => switch (type) {
    WorkoutType.run => const _Gait(cycle: 0.72, travel: 1.3),
    WorkoutType.ride => const _Gait(cycle: 0.9, travel: 1.9),
    WorkoutType.hike => const _Gait(cycle: 1.3, travel: 0.4),
    WorkoutType.swim => const _Gait(cycle: 1.7, travel: 0.45),
    WorkoutType.strength => const _Gait(cycle: 2.6, travel: 0),
    WorkoutType.yoga => const _Gait(cycle: 5.5, travel: 0),
    WorkoutType.walk ||
    WorkoutType.other => const _Gait(cycle: 1.1, travel: 0.55),
  };
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.type,
    required this.stage,
    required this.scheme,
    required this.seconds,
  }) : super(repaint: seconds);

  final WorkoutType type;
  final double? stage;
  final ColorScheme scheme;
  final ValueListenable<double> seconds;

  static const double _tau = 2 * math.pi;

  /// A pale sky in the colour of the page, so the scene has an end to fade
  /// from.
  Color get _sky =>
      Color.lerp(scheme.secondaryContainer, scheme.surfaceBright, 0.5)!;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final gait = _Gait.of(type);
    final time = seconds.value;
    final full = size;
    size = Size(full.width, math.min(stage ?? full.height, full.height));
    canvas
      ..drawRect(Offset.zero & full, Paint()..color = _sky)
      ..translate(0, full.height - size.height);
    // One hundredth of the height: every length of the figure is in these.
    final u = size.height / 100;
    final ground = size.height - 14 * u;
    final turn = _tau * (time / gait.cycle % 1);
    final travelled = time * gait.travel * size.height;
    final centre = size.width * 0.5;

    _sun(canvas, size, u);
    if (type == WorkoutType.swim) {
      _swimmer(canvas, size, u, centre, turn, travelled);
      return;
    }
    _hills(canvas, size, ground, travelled * 0.18, 26 * u, 0.9, 0.55);
    _hills(canvas, size, ground, travelled * 0.45, 15 * u, 1.7, 0.9);
    _ground(canvas, size, u, ground, travelled);
    switch (type) {
      case WorkoutType.ride:
        _rider(canvas, u, centre, ground, turn, travelled);
      case WorkoutType.strength:
        _lifter(canvas, u, centre, ground, turn);
      case WorkoutType.yoga:
        _yogi(canvas, u, centre, ground, turn);
      case WorkoutType.run:
        _walker(canvas, u, centre, ground, turn, running: true);
      case WorkoutType.hike:
        _walker(canvas, u, centre, ground, turn, hiking: true);
      case WorkoutType.walk || WorkoutType.other || WorkoutType.swim:
        _walker(canvas, u, centre, ground, turn);
    }
  }

  void _sun(Canvas canvas, Size size, double u) {
    canvas.drawCircle(
      Offset(size.width - 26 * u, 24 * u),
      11 * u,
      Paint()..color = scheme.tertiary.withValues(alpha: 0.35),
    );
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
  ) {
    final length = size.width / waves;
    final path = Path()..moveTo(0, ground);
    for (var x = 0.0; x <= size.width + 4; x += 4) {
      final along = (x + shift) / length * _tau;
      final rise = 0.5 + 0.32 * math.sin(along) + 0.18 * math.sin(along * 2.3);
      path.lineTo(x, ground - height * rise);
    }
    path
      ..lineTo(size.width, ground)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = Color.lerp(
          scheme.secondaryContainer,
          scheme.secondary,
          0.2,
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
  ) {
    final line = Paint()
      ..color = scheme.outlineVariant
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

  /// Seen from the side, moving to the right.
  void _walker(
    Canvas canvas,
    double u,
    double x,
    double ground,
    double turn, {
    bool running = false,
    bool hiking = false,
  }) {
    final pen = FigurePen(canvas, scheme, u);
    const part = 17.0;
    final swing = running ? 0.85 : (hiking ? 0.5 : 0.55);
    final knee = running ? 1.5 : 0.7;
    final lean = running ? 0.26 : (hiking ? 0.2 : 0.07);
    // Lifted off the ground twice a stride when running.
    final lift = running
        ? 5 * math.sin(turn).abs()
        : 1.2 * math.cos(2 * turn).abs();
    final hip = Offset(x, ground - (2 * part * 0.95 + lift) * u);

    List<Offset> leg(double phase) {
      final thigh = swing * math.sin(phase);
      // The knee bends while the leg comes forward.
      final shin = thigh - knee * math.max(0.0, math.cos(phase));
      final kneeAt = hip + Offset(math.sin(thigh), math.cos(thigh)) * part * u;
      final foot = kneeAt + Offset(math.sin(shin), math.cos(shin)) * part * u;
      return [hip, kneeAt, foot];
    }

    final up = Offset(math.sin(lean), -math.cos(lean));
    final shoulder = hip + up * 24 * u;

    List<Offset> arm(double phase) {
      final upper = -swing * 0.9 * math.sin(phase);
      final lower = upper + (running ? 1.5 : 0.35);
      final elbow =
          shoulder + Offset(math.sin(upper), math.cos(upper)) * 12 * u;
      final hand = elbow + Offset(math.sin(lower), math.cos(lower)) * 11 * u;
      return [shoulder, elbow, hand];
    }

    final farArm = arm(turn + math.pi);
    pen.line(pen.limb(far: true), leg(turn + math.pi));
    pen.line(pen.limb(far: true), farArm);
    if (hiking) {
      // The stick goes with the far hand; the pack sits on the back.
      canvas.drawLine(
        farArm.last,
        Offset(farArm.last.dx + 5 * u, ground + 2 * u),
        pen.thing(),
      );
      final back =
          hip + up * 13 * u + Offset(-math.cos(lean), -math.sin(lean)) * 7 * u;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: back, width: 10 * u, height: 17 * u),
          Radius.circular(4 * u),
        ),
        Paint()..color = scheme.tertiary,
      );
    }
    pen.line(pen.limb(), [hip, shoulder]);
    pen.head(shoulder + up * 9.5 * u);
    pen.line(pen.limb(), leg(turn));
    pen.line(pen.limb(), arm(turn));
  }

  void _rider(
    Canvas canvas,
    double u,
    double x,
    double ground,
    double turn,
    double travelled,
  ) {
    final pen = FigurePen(canvas, scheme, u);
    const radius = 15.0;
    final axle = ground - radius * u;
    final rear = Offset(x - 23 * u, axle);
    final front = Offset(x + 23 * u, axle);
    final crank = Offset(x - 2 * u, axle + 1 * u);
    final saddle = Offset(x - 10 * u, axle - 25 * u);
    final bars = Offset(x + 14 * u, axle - 26 * u);
    final frame = pen.thing(3);

    for (final wheel in [rear, front]) {
      canvas.drawCircle(wheel, radius * u, frame);
      final spin = travelled / (radius * u);
      for (var spoke = 0; spoke < 3; spoke++) {
        final angle = spin + spoke * math.pi / 3;
        final reach =
            Offset(math.cos(angle), math.sin(angle)) * (radius - 2) * u;
        canvas.drawLine(wheel - reach, wheel + reach, pen.thing(1.2));
      }
    }

    Offset pedal(double phase) =>
        crank + Offset(math.cos(phase), math.sin(phase)) * 6 * u;
    final hip = saddle + Offset(0, -3 * u);
    List<Offset> leg(double phase) {
      final foot = pedal(phase);
      return [hip, FigurePen.joint(hip, foot, 17 * u, 17 * u, -1), foot];
    }

    pen.line(pen.limb(far: true), leg(turn + math.pi));
    pen.line(frame, [rear, crank, saddle, rear]);
    pen.line(frame, [crank, bars, saddle]);
    pen.line(frame, [bars, front]);
    canvas.drawLine(pedal(turn), pedal(turn + math.pi), pen.thing(2));
    canvas.drawLine(
      saddle + Offset(-4 * u, -1 * u),
      saddle + Offset(4 * u, -1 * u),
      pen.thing(3.4),
    );

    final shoulder = hip + Offset(13 * u, -19 * u);
    final hand = bars + Offset(-1 * u, -2 * u);
    pen.line(pen.limb(), [hip, shoulder]);
    pen.head(shoulder + Offset(6 * u, -8 * u));
    pen.line(pen.limb(), leg(turn));
    pen.line(pen.limb(), [
      shoulder,
      FigurePen.joint(shoulder, hand, 12 * u, 11 * u, 1),
      hand,
    ]);
  }

  /// Seen from the front, pressing a barbell overhead.
  void _lifter(Canvas canvas, double u, double x, double ground, double turn) {
    final pen = FigurePen(canvas, scheme, u);
    final raised = 0.5 - 0.5 * math.cos(turn);
    final hip = Offset(x, ground - (31 - 2.5 * (1 - raised)) * u);
    final neck = hip + Offset(0, -24 * u);
    final hands = neck.dy + (1 - 21 * raised) * u;

    for (final side in const [-1.0, 1.0]) {
      final start = hip + Offset(4 * side * u, 0);
      final foot = Offset(x + 10 * side * u, ground);
      pen.line(pen.limb(), [
        start,
        FigurePen.joint(start, foot, 17 * u, 17 * u, -side),
        foot,
      ]);
    }
    pen.line(pen.limb(), [hip, neck]);
    pen.head(neck + Offset(0, -9.5 * u));

    final bar = pen.thing(2.4);
    canvas.drawLine(Offset(x - 36 * u, hands), Offset(x + 36 * u, hands), bar);
    for (final side in const [-1.0, 1.0]) {
      final shoulder = neck + Offset(8 * side * u, 2 * u);
      final hand = Offset(x + 15 * side * u, hands);
      pen.line(pen.limb(), [
        shoulder,
        FigurePen.joint(shoulder, hand, 12 * u, 11 * u, -side),
        hand,
      ]);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x + 30 * side * u, hands),
            width: 5 * u,
            height: 20 * u,
          ),
          Radius.circular(2 * u),
        ),
        Paint()..color = scheme.tertiary,
      );
    }
  }

  /// Seen from the front, sitting cross-legged; the arms rise with a breath.
  void _yogi(Canvas canvas, double u, double x, double ground, double turn) {
    final pen = FigurePen(canvas, scheme, u);
    final breath = 0.5 - 0.5 * math.cos(turn);
    final hip = Offset(x, ground - 5 * u);
    final neck = hip + Offset(0, -(24 + breath) * u);
    canvas.drawCircle(
      hip + Offset(0, -20 * u),
      (30 + 9 * breath) * u,
      Paint()..color = scheme.tertiary.withValues(alpha: 0.12 + 0.1 * breath),
    );
    for (final side in const [-1.0, 1.0]) {
      pen.line(pen.limb(far: side < 0), [
        hip,
        Offset(x + 18 * side * u, ground - 2 * u),
        Offset(x - 5 * side * u, ground),
      ]);
    }
    pen.line(pen.limb(), [hip, neck]);
    pen.head(neck + Offset(0, -9.5 * u));
    // From hanging beside the body to nearly touching above the head.
    final raise = 0.6 + (math.pi - 0.75) * breath;
    for (final side in const [-1.0, 1.0]) {
      final shoulder = neck + Offset(7 * side * u, 2 * u);
      pen.line(pen.limb(), [
        shoulder,
        shoulder + Offset(math.sin(raise) * side, math.cos(raise)) * 22 * u,
      ]);
    }
  }

  void _swimmer(
    Canvas canvas,
    Size size,
    double u,
    double x,
    double turn,
    double travelled,
  ) {
    final pen = FigurePen(canvas, scheme, u);
    final level = size.height * 0.56;
    Path water(double shift, double depth) {
      final path = Path()..moveTo(0, size.height);
      for (var px = 0.0; px <= size.width + 4; px += 4) {
        path.lineTo(
          px,
          level + depth + 2.4 * u * math.sin((px + shift) / (16 * u)),
        );
      }
      return path
        ..lineTo(size.width, size.height)
        ..close();
    }

    canvas.drawPath(
      water(travelled * 0.5, -3 * u),
      Paint()..color = scheme.secondaryContainer.withValues(alpha: 0.7),
    );

    final hip = Offset(x - 14 * u, level + 3 * u);
    final shoulder = Offset(x + 10 * u, level);
    List<Offset> arm(double phase) => [
      shoulder,
      shoulder + Offset(math.cos(phase), math.sin(phase)) * 21 * u,
    ];
    List<Offset> leg(double phase) {
      final kick = math.pi + 0.28 * math.sin(phase);
      return [hip, hip + Offset(math.cos(kick), -math.sin(kick)) * 27 * u];
    }

    pen.line(pen.limb(far: true), arm(turn + math.pi));
    pen.line(pen.limb(far: true), leg(2 * turn + math.pi));
    pen.line(pen.limb(), [hip, shoulder]);
    pen.head(shoulder + Offset(10 * u, -2 * u));
    pen.line(pen.limb(), leg(2 * turn));
    pen.line(pen.limb(), arm(turn));
    // The water in front covers what is under it.
    canvas.drawPath(
      water(travelled, 2 * u),
      Paint()..color = scheme.secondaryContainer.withValues(alpha: 0.88),
    );
  }

  @override
  bool shouldRepaint(_ScenePainter oldDelegate) =>
      oldDelegate.type != type ||
      oldDelegate.stage != stage ||
      oldDelegate.scheme != scheme;
}
