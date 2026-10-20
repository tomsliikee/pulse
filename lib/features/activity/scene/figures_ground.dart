import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../data/models.dart';
import '../../../widgets/scene_kit.dart';
import 'stage.dart';

/// Strokes of wind that fall behind a figure, [x] from its place.
void paintWind(Stage s, [double x = 0]) {
  final u = s.u;
  for (var i = 0; i < 5; i++) {
    final age = (s.time * 1.7 + i * 0.37) % 1;
    final from = s.at(x - 16 - age * 46, 16.0 + i * 9);
    final length = (10 + i % 3 * 6) * u * (1 - age * 0.5);
    s.canvas.drawLine(
      from,
      from - Offset(length, 0),
      s.stroke(s.scheme.primary.withValues(alpha: 0.3 * (1 - age)), 1.8),
    );
  }
}

/// What a foot or a ski raises behind the figure: twice in each of the
/// [strides] counted so far, or all the time where [steady].
void paintDust(
  Stage s,
  double strides, {
  Color? color,
  bool steady = false,
  double x = 0,
}) {
  final u = s.u;
  final tone = color ?? s.scheme.onSurfaceVariant;
  for (var puff = 0; puff < (steady ? 4 : 2); puff++) {
    final age = steady
        ? (strides * 1.6 + puff * 0.25) % 1
        : (strides + puff * 0.5) % 1 * 1.6;
    if (age >= 1) continue;
    final paint = s.fill(
      tone.withValues(alpha: (steady ? 0.6 : 0.26) * (1 - age)),
    );
    for (var i = 0; i < 4; i++) {
      s.canvas.drawCircle(
        s.at(x - 6 - age * (14 + i * 7), -2 + age * (2 + i * 2.2)),
        (1.2 + age * 2.2) * u,
        paint,
      );
    }
  }
}

/// Seen from the side, moving to the right: walking, running or hiking
/// with a stick and a pack.
void paintWalker(Stage s, {bool running = false, bool hiking = false}) {
  final u = s.u;
  final pen = s.pen;
  final turn = s.turn;
  if (pen.mascot) {
    // The turtle carries its pack on its back already, and goes on four.
    pen.walker(Offset(s.centre, s.floor), turn, running: running);
    return;
  }
  const part = 17.0;
  final swing = running ? 0.95 : (hiking ? 0.5 : 0.55);
  final knee = running ? 1.7 : 0.7;
  final lean = running ? 0.24 : (hiking ? 0.2 : 0.07);
  // Off the ground twice a stride when running, with a moment in the air
  // and a short one on the ground.
  final lift = running
      ? 6 * math.pow(math.sin(turn).abs(), 1.4)
      : 1.2 * math.cos(2 * turn).abs();
  final hip = s.at(0, 2 * part * 0.95 + lift);

  List<Offset> leg(double phase) {
    final thigh = swing * math.sin(phase);
    // The knee bends while the leg comes forward; a runner's never
    // straightens.
    final shin =
        thigh - knee * math.max(0.0, math.cos(phase)) - (running ? 0.25 : 0);
    final kneeAt = hip + Offset(math.sin(thigh), math.cos(thigh)) * part * u;
    final foot = kneeAt + Offset(math.sin(shin), math.cos(shin)) * part * u;
    return [hip, kneeAt, foot];
  }

  final up = Offset(math.sin(lean), -math.cos(lean));
  final shoulder = hip + up * 24 * u;

  List<Offset> arm(double phase) {
    final upper = -swing * 0.9 * math.sin(phase);
    final lower = upper + (running ? 1.5 : 0.35);
    final elbow = shoulder + Offset(math.sin(upper), math.cos(upper)) * 12 * u;
    final hand = elbow + Offset(math.sin(lower), math.cos(lower)) * 11 * u;
    return [shoulder, elbow, hand];
  }

  final farArm = arm(turn + math.pi);
  pen.line(pen.limb(far: true), leg(turn + math.pi));
  pen.line(pen.limb(far: true), farArm);
  if (hiking) {
    // The stick goes with the far hand; the pack sits on the back.
    s.canvas.drawLine(
      farArm.last,
      Offset(farArm.last.dx + 5 * u, s.ground + 2 * u),
      pen.thing(),
    );
    final back =
        hip + up * 13 * u + Offset(-math.cos(lean), -math.sin(lean)) * 7 * u;
    s.canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: back, width: 10 * u, height: 17 * u),
        Radius.circular(4 * u),
      ),
      s.fill(s.accent),
    );
  }
  pen.line(pen.limb(), [hip, shoulder]);
  pen.head(shoulder + up * 9.5 * u);
  pen.line(pen.limb(), leg(turn));
  pen.line(pen.limb(), arm(turn));
}

/// The belt of a treadmill under a runner, and its handle.
void paintTreadmill(Stage s) {
  final u = s.u;
  final frame = s.pen.thing(3);
  final belt = Rect.fromLTRB(
    s.centre - 30 * u,
    s.floor,
    s.centre + 30 * u,
    s.floor + 6 * u,
  );
  s.canvas.drawRRect(
    RRect.fromRectAndRadius(belt, Radius.circular(3 * u)),
    s.fill(s.scheme.onSurfaceVariant.withValues(alpha: 0.75)),
  );
  // Marks on the belt that run backwards.
  final gap = 12 * u;
  final passed = s.time / s.cycle * 34 * u;
  for (var x = belt.right - passed % gap; x > belt.left + 3 * u; x -= gap) {
    s.canvas.drawLine(
      Offset(x, belt.top + 3 * u),
      Offset(x - 4 * u, belt.top + 3 * u),
      s.stroke(s.scheme.surfaceBright.withValues(alpha: 0.7), 1.4),
    );
  }
  s.canvas
    ..drawLine(s.at(28, -3), s.at(34, 48), frame)
    ..drawLine(s.at(34, 48), s.at(22, 46), frame);
}

void paintRider(Stage s, {bool onStand = false}) {
  final u = s.u;
  final pen = s.pen;
  final canvas = s.canvas;
  const radius = 15.0;
  final rear = s.at(-23, radius);
  final front = s.at(23, radius);
  final crank = s.at(-2, radius - 1);
  final saddle = s.at(-10, radius + 25);
  final bars = s.at(14, radius + 26);
  final frame = pen.thing(3);
  // On a stand the wheel turns with the pedals and goes nowhere.
  final spin = onStand ? s.turn * 2.5 : s.travelled / (radius * u);

  for (final wheel in [rear, front]) {
    canvas.drawCircle(wheel, radius * u, frame);
    for (var spoke = 0; spoke < 3; spoke++) {
      final angle = spin + spoke * math.pi / 3;
      final reach = Offset(math.cos(angle), math.sin(angle)) * (radius - 2) * u;
      canvas.drawLine(wheel - reach, wheel + reach, pen.thing(1.2));
    }
  }
  if (onStand) {
    // What holds the rear wheel off the ground.
    canvas
      ..drawLine(rear, s.at(-34, -3.4), frame)
      ..drawLine(rear, s.at(-12, -3.4), frame);
  }

  Offset pedal(double phase) =>
      crank + Offset(math.cos(phase), math.sin(phase)) * 6 * u;
  final hip = saddle + Offset(0, -3 * u);
  List<Offset> leg(double phase) {
    final foot = pedal(phase);
    return [hip, FigurePen.joint(hip, foot, 17 * u, 17 * u, -1), foot];
  }

  final turn = s.turn;
  pen
    ..line(pen.limb(far: true), leg(turn + math.pi))
    ..line(frame, [rear, crank, saddle, rear])
    ..line(frame, [crank, bars, saddle])
    ..line(frame, [bars, front]);
  canvas
    ..drawLine(pedal(turn), pedal(turn + math.pi), pen.thing(2))
    ..drawLine(
      saddle + Offset(-4 * u, -1 * u),
      saddle + Offset(4 * u, -1 * u),
      pen.thing(3.4),
    );

  final shoulder = hip + Offset(13 * u, -19 * u);
  final hand = bars + Offset(-1 * u, -2 * u);
  pen
    ..body(hip, shoulder)
    ..head(shoulder + Offset(6 * u, -8 * u), neck: shoulder)
    ..line(pen.limb(), leg(turn))
    ..line(pen.limb(), [
      shoulder,
      FigurePen.joint(shoulder, hand, 12 * u, 11 * u, 1),
      hand,
    ]);
}

/// Climbing stairs that pass down to the left, a step with every stride.
void paintStairs(Stage s) {
  const wide = 15.0;
  const high = 9.0;
  // Treads passed so far: two in a cycle, one for each foot.
  final passed = s.time / s.cycle * 2;
  final within = passed % 1;

  final steps = Path();
  for (var k = -14; k <= 14; k++) {
    final at = k - within;
    final left = s.at((at - 0.5) * wide, at * high - 3.4);
    final right = s.at((at + 0.5) * wide, at * high - 3.4);
    if (k == -14) {
      steps.moveTo(left.dx, s.size.height + 4);
    }
    steps
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy);
  }
  steps
    ..lineTo(s.size.width + 400, s.size.height + 4)
    ..close();
  s.canvas
    ..save()
    ..translate(0, s.drop * 2)
    ..drawPath(steps, s.fill(Color.lerp(s.soft, s.scheme.secondary, 0.25)!))
    ..drawPath(
      steps,
      s.stroke(s.scheme.onSurfaceVariant.withValues(alpha: 0.55), 2),
    )
    ..restore();

  // A foot rides its tread down and back, then swings two treads up.
  (double, double) foot(double shift) {
    final p = (passed / 2 + shift) % 1;
    if (p < 0.7) {
      final at = 1 - p * 2;
      return (at * wide, at * high);
    }
    final swung = (p - 0.7) / 0.3;
    final at = -0.4 + 1.4 * Curves.easeInOut.transform(swung);
    return (at * wide, at * high + 7 * math.sin(math.pi * swung));
  }

  final near = foot(0);
  final far = foot(0.5);
  final swing = math.sin(s.turn);
  s.pen.shadow(s.at(4, -3.4), 12);
  paintPose(
    s,
    Pose(
      3,
      34 + 1.2 * math.cos(2 * s.turn).abs(),
      0.2,
      near.$1,
      near.$2,
      far.$1,
      far.$2,
      10 + 8 * swing,
      37 + 2 * swing.abs(),
      10 - 8 * swing,
      37 + 2 * swing.abs(),
    ),
  );
}

/// Seen from the side in a wheelchair, pushing the wheel with every
/// stroke.
void paintWheelchair(Stage s) {
  final u = s.u;
  final pen = s.pen;
  final canvas = s.canvas;
  const radius = 17.0;
  final wheel = s.at(-5, radius - 3.4);
  final frame = pen.thing(3);
  final spin = s.travelled / (radius * u);

  // A push from behind the top of the wheel to in front of it, then the
  // hand comes back through the air.
  final p = s.phase;
  final pushing = p < 0.55;
  final along = pushing
      ? Curves.easeIn.transform(p / 0.55)
      : 1 - Curves.easeInOut.transform((p - 0.55) / 0.45);
  final angle = 2.1 - 1.5 * along;
  final reach =
      radius + (pushing ? 0 : 5 * math.sin(math.pi * (p - 0.55) / 0.45));
  final handX = -5 + reach * math.cos(angle);
  final handY = radius - 3.4 + reach * math.sin(angle);

  pen.shadow(s.at(2, -3.4), 26);
  canvas
    ..drawLine(s.at(-12, 21), s.at(-15, 44), frame)
    ..drawLine(s.at(-15, 44), s.at(-21, 45), frame);
  paintPose(
    s,
    Pose(-6, 25, 0.06 + 0.2 * along, 14, 7, 14, 7, handX, handY, handX, handY),
  );
  canvas
    ..drawLine(s.at(-12, 21), s.at(9, 21), frame)
    ..drawLine(s.at(9, 21), s.at(15, 3), frame)
    ..drawLine(s.at(15, 3), s.at(22, 3), frame)
    ..drawCircle(s.at(15, 0.6), 4 * u, frame)
    ..drawCircle(wheel, radius * u, frame)
    ..drawCircle(wheel, (radius - 3.5) * u, pen.thing(1.2));
  for (var spoke = 0; spoke < 4; spoke++) {
    final turned = spin + spoke * math.pi / 4;
    final out = Offset(math.cos(turned), math.sin(turned)) * (radius - 3.5) * u;
    canvas.drawLine(wheel - out, wheel + out, pen.thing(1.2));
  }
}

/// Whether [type] is done on a machine that stands in a hall.
bool onMachine(WorkoutType type) =>
    type == WorkoutType.treadmill ||
    type == WorkoutType.stationaryBike ||
    type == WorkoutType.stairMachine ||
    type == WorkoutType.rowingMachine ||
    type == WorkoutType.elliptical;
