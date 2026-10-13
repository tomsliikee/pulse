import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../data/models.dart';
import 'settings.dart';
import 'stage.dart';

/// Swimming the crawl, the water in front covering what is under it. In a
/// pool a lane rope floats along.
void paintSwimmer(Stage s) {
  final u = s.u;
  final pen = s.pen;
  final turn = s.turn;
  // How high above the ground the water stands.
  final level = (s.ground - s.size.height * 0.56) / u;
  paintWater(s, level + 3, s.travelled * 0.5, opacity: 0.7);

  final hip = s.at(-14, level - 3);
  final shoulder = s.at(10, level);
  List<Offset> arm(double phase) => [
    shoulder,
    shoulder + Offset(math.cos(phase), math.sin(phase)) * 21 * u,
  ];
  List<Offset> leg(double phase) {
    final kick = math.pi + 0.28 * math.sin(phase);
    return [hip, hip + Offset(math.cos(kick), -math.sin(kick)) * 27 * u];
  }

  pen
    ..line(pen.limb(far: true), arm(turn + math.pi))
    ..line(pen.limb(far: true), leg(2 * turn + math.pi))
    ..line(pen.limb(), [hip, shoulder])
    ..head(shoulder + Offset(10 * u, -2 * u))
    ..line(pen.limb(), leg(2 * turn))
    ..line(pen.limb(), arm(turn));
  // Drops where the hand goes in.
  _splash(s, 30, level + 1, s.phase);
  paintWater(s, level - 2, s.travelled);
  if (s.type == WorkoutType.swim) _laneRope(s, level - 9);
}

/// A few drops thrown up at ([x], [y]) at the start of each cycle.
void _splash(Stage s, double x, double y, double phase) {
  final age = phase % 1 * 2.2;
  if (age >= 1) return;
  final paint = s.fill(s.pale.withValues(alpha: 0.9 * (1 - age)));
  for (var i = 0; i < 5; i++) {
    final out = (i - 2) * 3.2 * age;
    s.canvas.drawCircle(
      s.at(x + out, y + 9 * age * (1 - age) * (2 + i % 2)),
      (1.5 - 0.6 * age) * s.u,
      paint,
    );
  }
}

/// Floats on a line, every third one in the colour of the page.
void _laneRope(Stage s, double level) {
  final gap = 7 * s.u;
  var index = (s.travelled / gap).floor();
  for (var x = -(s.travelled % gap); x < s.size.width + gap; x += gap) {
    s.canvas.drawCircle(
      Offset(x, s.ground - level * s.u + 1.2 * s.u * math.sin(x / (16 * s.u))),
      2.3 * s.u,
      s.fill(index % 3 == 0 ? s.accent : s.pale),
    );
    index++;
  }
}

/// The long strokes of rowing: in a boat on the water with its back to
/// where it goes, or on a machine.
void paintPaddle(Stage s) {
  const reach = Pose(-2, 10, 0.5, 18, 7, 18, 7, 17, 25, 17, 25);
  const pulled = Pose(-13, 10, -0.35, 18, 7, 18, 7, -6, 26, -6, 26);
  const back = Pose(-13, 10, -0.3, 18, 7, 18, 7, -4, 21, -4, 21);
  const ready = Pose(-2, 10, 0.45, 18, 7, 18, 7, 16, 20, 16, 20);
  // A hard pull, then a slower way back with the blade out of the water.
  final pose = Pose.loop(const [reach, pulled, back, ready], s.phase);
  final frame = s.pen.thing(3);

  if (s.type == WorkoutType.rowingMachine) {
    s.pen.shadow(s.at(4, -3.4), 34);
    s.canvas
      ..drawLine(s.at(-26, 3), s.at(34, 3), frame)
      ..drawLine(s.at(-22, 3), s.at(-22, -3.4), frame)
      ..drawLine(s.at(30, 3), s.at(30, -3.4), frame)
      ..drawCircle(s.at(32, 16), 10 * s.u, frame);
    for (var spoke = 0; spoke < 3; spoke++) {
      final angle = s.time * 9 + spoke * math.pi / 3;
      final out = Offset(math.cos(angle), math.sin(angle)) * 8 * s.u;
      s.canvas.drawLine(
        s.at(32, 16) - out,
        s.at(32, 16) + out,
        s.pen.thing(1.2),
      );
    }
    final limbs = paintPose(s, pose);
    s.canvas
      ..drawLine(limbs.nearHand, s.at(32, 16), s.pen.thing(1.4))
      ..drawLine(
        s.at(pose.hipX - 5, pose.hipY - 4.5),
        s.at(pose.hipX + 5, pose.hipY - 4.5),
        s.stroke(s.accent, 3),
      );
    return;
  }

  final bob = 1.2 * math.sin(s.time * 2.1);
  paintWater(s, seaLevel + 3, s.travelled * 0.5, opacity: 0.7);
  s.mirrored(() {
    s.rocking(0, seaLevel, 0.02 * math.sin(s.time * 1.7), bob, () {
      // The hull is long and low and pointed at both ends.
      final hull = Path()
        ..moveTo(s.at(-54, 15).dx, s.at(-54, 15).dy)
        ..quadraticBezierTo(
          s.at(0, -8).dx,
          s.at(0, -8).dy,
          s.at(54, 15).dx,
          s.at(54, 15).dy,
        )
        ..close();
      s.canvas.drawPath(hull, s.fill(s.accent));
      final limbs = paintPose(s, pose);
      // The oar turns about its lock on the side of the boat.
      final lock = s.at(2, 15);
      final hand = limbs.nearHand;
      final out = (lock - hand) / (lock - hand).distance;
      final blade = lock + out * 30 * s.u;
      s.canvas
        ..drawLine(hand, blade, s.pen.thing(2))
        ..drawLine(lock + out * 22 * s.u, blade, s.stroke(s.accent, 4.2));
    });
  });
  paintWater(s, seaLevel - 4, s.travelled);
}

/// Carried by wave or wind: standing on a surfboard, sitting in a sailing
/// boat, or hanging under a paraglider.
void paintBoard(Stage s) {
  switch (s.type) {
    case WorkoutType.sailing:
      _sailor(s);
    case WorkoutType.paragliding:
      _glider(s);
    default:
      _surfer(s);
  }
}

void _surfer(Stage s) {
  final sway = math.sin(s.time * 1.9);
  // The wave it rides rises behind it.
  final crest = Path()..moveTo(0, s.size.height);
  for (var x = 0.0; x <= s.size.width + 4; x += 4) {
    final from = (x - s.centre) / s.u;
    final rise =
        30 * math.exp(-math.pow((from + 34) / 30, 2)) +
        2 * math.sin((x + s.travelled) / (14 * s.u));
    crest.lineTo(x, s.ground - (seaLevel + 2 + rise) * s.u + s.drop);
  }
  crest
    ..lineTo(s.size.width, s.size.height)
    ..close();
  s.canvas.drawPath(
    crest,
    s.fill(s.scheme.secondaryContainer.withValues(alpha: 0.75)),
  );
  s.rocking(0, seaLevel, 0.1 + 0.07 * sway, 1.5 * sway, () {
    s.canvas.drawLine(
      s.at(-24, seaLevel + 1),
      s.at(26, seaLevel + 1),
      s.stroke(s.accent, 4.4),
    );
    paintPose(
      s,
      Pose(
        -1,
        seaLevel + 25 + 2 * sway,
        0.3,
        11,
        seaLevel + 4.5,
        -11,
        seaLevel + 4.5,
        21,
        seaLevel + 44 + 5 * sway,
        -17,
        seaLevel + 48 - 5 * sway,
      ),
    );
  });
  // Spray where the board cuts the water.
  final spray = s.fill(s.pale.withValues(alpha: 0.85));
  for (var i = 0; i < 7; i++) {
    final age = (s.time * 1.5 + i / 7) % 1;
    s.canvas.drawCircle(
      s.at(-22 - age * 26, seaLevel + 2 + 14 * age * (1 - age) * (1 + i % 3)),
      (2.2 - 1.2 * age) * s.u,
      spray,
    );
  }
  paintWater(s, seaLevel, s.travelled);
}

void _sailor(Stage s) {
  final rock = 0.05 * math.sin(s.time * 1.3);
  paintWater(s, seaLevel + 3, s.travelled * 0.5, opacity: 0.7);
  s.rocking(0, seaLevel, rock - 0.04, 1.2 * math.sin(s.time * 1.9), () {
    final base = seaLevel + 2;
    // The sail fills and slackens a little with the wind.
    final belly = 9 + 2 * math.sin(s.time * 1.1);
    Offset p(double x, double y) => s.at(x, base + y);
    final sail = Path()
      ..moveTo(p(4, 70).dx, p(4, 70).dy)
      ..quadraticBezierTo(
        p(24 + belly, 40).dx,
        p(24 + belly, 40).dy,
        p(38, 12).dx,
        p(38, 12).dy,
      )
      ..lineTo(p(4, 12).dx, p(4, 12).dy)
      ..close();
    final jib = Path()
      ..moveTo(p(1, 62).dx, p(1, 62).dy)
      ..quadraticBezierTo(
        p(-12 + belly * 0.4, 34).dx,
        p(-12 + belly * 0.4, 34).dy,
        p(-22, 11).dx,
        p(-22, 11).dy,
      )
      ..lineTo(p(1, 11).dx, p(1, 11).dy)
      ..close();
    s.canvas
      ..drawPath(sail, s.fill(s.pale))
      ..drawPath(sail, s.stroke(s.scheme.onSurfaceVariant, 1.2))
      ..drawPath(jib, s.fill(s.accent.withValues(alpha: 0.8)))
      ..drawLine(p(2.5, 6), p(2.5, 74), s.pen.thing(2.4))
      ..drawLine(p(2.5, 12), p(40, 12), s.pen.thing(2));
    paintPose(
      s,
      Pose(
        -27,
        base + 10,
        -0.25,
        -12,
        base + 8,
        -12,
        base + 8,
        -12,
        base + 22,
        -14,
        base + 20,
      ),
    );
    final hull = Path()
      ..moveTo(p(-42, 9).dx, p(-42, 9).dy)
      ..lineTo(p(46, 10).dx, p(46, 10).dy)
      ..quadraticBezierTo(
        p(34, -3).dx,
        p(34, -3).dy,
        p(20, -3).dx,
        p(20, -3).dy,
      )
      ..lineTo(p(-34, -3).dx, p(-34, -3).dy)
      ..close();
    s.canvas.drawPath(hull, s.fill(s.scheme.onSurfaceVariant));
  });
  paintWater(s, seaLevel, s.travelled);
}

void _glider(Stage s) {
  final sway = 0.07 * math.sin(s.time * 0.9);
  // Everything hangs from the wing and swings under it.
  s.rocking(0, 84, sway, 2 * math.sin(s.time * 0.6), () {
    final wing = Path()
      ..moveTo(s.at(-44, 62).dx, s.at(-44, 62).dy)
      ..quadraticBezierTo(
        s.at(0, 96).dx,
        s.at(0, 96).dy,
        s.at(44, 62).dx,
        s.at(44, 62).dy,
      )
      ..quadraticBezierTo(
        s.at(0, 82).dx,
        s.at(0, 82).dy,
        s.at(-44, 62).dx,
        s.at(-44, 62).dy,
      )
      ..close();
    final line = s.stroke(
      s.scheme.onSurfaceVariant.withValues(alpha: 0.7),
      0.9,
    );
    for (final x in [-38.0, -22.0, -6.0, 8.0, 24.0, 38.0]) {
      s.canvas.drawLine(
        s.at(x, 65 + 9 * (1 - (x / 44) * (x / 44))),
        s.at(x < 0 ? -3 : 5, 36),
        line,
      );
    }
    s.canvas.drawPath(wing, s.fill(s.accent));
    // Sitting in the harness, the hands on the brakes.
    paintPose(s, const Pose(-2, 16, -0.2, 15, 12, 13, 9, 4, 36, -4, 36));
  });
}

/// Under water with fins and a tank, bubbles rising, a few fish passing.
void paintDiver(Stage s) {
  final u = s.u;
  final kick = math.sin(s.turn);
  final drift = 1.5 * math.sin(s.time * 0.8);
  // Fish that swim the other way.
  final wide = s.size.width / u + 60;
  for (var i = 0; i < 3; i++) {
    final x = wide - (s.time * (9 + i * 4) + i * wide / 3) % wide - 30;
    final at = Offset(
      x * u,
      (22 + i * 24 + 2 * math.sin(s.time * 1.4 + i)) * u,
    );
    final fish = s.fill(s.accent.withValues(alpha: 0.7));
    s.canvas
      ..drawOval(
        Rect.fromCenter(center: at, width: 10 * u, height: 5 * u),
        fish,
      )
      ..drawPath(
        Path()
          ..moveTo(at.dx + 4 * u, at.dy)
          ..lineTo(at.dx + 9 * u, at.dy - 3.5 * u)
          ..lineTo(at.dx + 9 * u, at.dy + 3.5 * u)
          ..close(),
        fish,
      );
  }
  final limbs = paintPose(
    s,
    Pose(
      -8,
      36 + drift,
      1.45,
      -41,
      36 + drift + 6 * kick,
      -41,
      36 + drift - 6 * kick,
      32,
      28 + drift,
      30,
      31 + drift,
    ),
  );
  // Fins, and the tank along the back.
  for (final foot in [limbs.farFoot, limbs.nearFoot]) {
    s.canvas.drawPath(
      Path()
        ..moveTo(foot.dx, foot.dy)
        ..lineTo(foot.dx - 13 * u, foot.dy - 5 * u)
        ..lineTo(foot.dx - 13 * u, foot.dy + 5 * u)
        ..close(),
      s.fill(s.accent),
    );
  }
  final tank = Offset.lerp(limbs.hip, limbs.neck, 0.55)! + Offset(0, -6.5 * u);
  s.canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: tank, width: 20 * u, height: 7 * u),
      Radius.circular(3.5 * u),
    ),
    s.fill(s.scheme.onSurfaceVariant),
  );
  for (var i = 0; i < 6; i++) {
    final age = (s.time * 0.6 + i / 6) % 1;
    s.canvas.drawCircle(
      limbs.head +
          Offset(
            (4 - 16 * age + 2 * math.sin(age * 9 + i)) * u,
            -(6 + age * 60) * u,
          ),
      (1 + 2.2 * age) * u,
      s.stroke(s.pale.withValues(alpha: 0.9 * (1 - age)), 1),
    );
  }
}
