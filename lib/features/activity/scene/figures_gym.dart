import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../data/models.dart';
import 'stage.dart';

/// Seen from the front with a barbell: squats, then presses overhead, then
/// lifts from the floor, a few of each.
void paintLift(Stage s) {
  const rack = Pose(0, 32, 0, 10, 0, -10, 0, 15, 57, -15, 57, front: 1);
  const squat = Pose(0, 17, 0, 10, 0, -10, 0, 15, 42, -15, 42, front: 1);
  const press = Pose(0, 32, 0, 10, 0, -10, 0, 13, 76, -13, 76, front: 1);
  const down = Pose(0, 15, 0, 11, 0, -11, 0, 14, 13, -14, 13, front: 1);
  const up = Pose(0, 32, 0, 10, 0, -10, 0, 14, 32, -14, 32, front: 1);
  const frames = [
    rack, squat, rack, squat, rack, //
    press, rack, press, rack, //
    down, up, down, up, down,
  ];
  final pose = Pose.loop(frames, s.phase, hold: 0.22);
  s.pen.shadow(s.at(0, -3.4), 17);
  final limbs = paintPose(s, pose);

  // The bar lies in the hands and bends a little under its plates.
  final y = (limbs.nearHand.dy + limbs.farHand.dy) / 2;
  final x = s.centre;
  final u = s.u;
  final sag = 1.2 * u;
  s.canvas.drawPath(
    Path()
      ..moveTo(x - 37 * u, y + sag)
      ..quadraticBezierTo(x, y - sag, x + 37 * u, y + sag),
    s.pen.thing(2.4),
  );
  for (final side in const [-1.0, 1.0]) {
    for (final (out, high) in const [(30.0, 21.0), (34.5, 15.0)]) {
      s.canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x + out * side * u, y + sag * 0.6),
            width: 4 * u,
            height: high * u,
          ),
          Radius.circular(1.8 * u),
        ),
        s.fill(s.accent),
      );
    }
  }
}

/// Exercises with the body's own weight: push-ups on the floor, then
/// pull-ups on a bar.
void paintBodyweight(Stage s) {
  const plank = Pose(-6, 15.5, 1.25, -39, 0, -39, 0, 17, 0, 17, 0);
  const lowered = Pose(-6, 8, 1.45, -39, 0, -39, 0, 17, 0, 17, 0);
  // Seen from the front at the bar, so the arms show beside the head.
  const stand = Pose(0, 31, 0, 5, 0, -5, 0, 13, 70, -13, 70, front: 1);
  const hang = Pose(0, 28, 0, 4, 1, -4, 1, 13, 72, -13, 72, front: 1);
  const pulled = Pose(0, 40, 0, 4, 13, -4, 13, 13, 72, -13, 72, front: 1);
  const frames = [
    plank, lowered, plank, lowered, plank, //
    stand, hang, pulled, hang, pulled, hang, stand,
  ];
  // The bar hangs from the ceiling.
  final bar = s.pen.thing(2.6);
  s.canvas
    ..drawLine(s.at(-21, 75.5), s.at(21, 75.5), bar)
    ..drawLine(s.at(-18, 75.5), s.at(-18, 100), bar)
    ..drawLine(s.at(18, 75.5), s.at(18, 100), bar);
  final pose = Pose.loop(frames, s.phase, hold: 0.2);
  s.pen.shadow(
    s.at(pose.hipX, -3.4),
    12 + 14 * (pose.lean / 1.45).clamp(0.0, 1.0),
  );
  paintPose(s, pose);
}

/// Seen from behind on a rock face: one hand or foot after the other
/// reaches for the next hold, and the wall passes downwards.
void paintClimb(Stage s) {
  // What the wall passes in one cycle, which is how far holds are apart.
  final rise = s.travel * s.cycle * 100;
  const limbs = [
    // x, the height it reaches around, when in the cycle it reaches.
    (12.0, 62.0, 0.0),
    (-9.0, 8.0, 0.25),
    (-12.0, 62.0, 0.5),
    (9.0, 8.0, 0.75),
  ];
  final hold = s.fill(s.accent);
  final at = <(double, double)>[];
  for (final (x, around, shift) in limbs) {
    final p = (s.phase + shift) % 1;
    for (var k = -3; k <= 4; k++) {
      s.canvas.drawCircle(
        s.at(x, around + (0.375 - p + k) * rise),
        2.6 * s.u,
        hold,
      );
    }
    // It holds on while the wall takes it down, then reaches up again.
    final y = p < 0.75
        ? around + (0.375 - p) * rise
        : around +
              (-0.375 + 0.75 * Curves.easeInOut.transform((p - 0.75) / 0.25)) *
                  rise;
    final out = p < 0.75 ? 0.0 : 3 * math.sin(math.pi * (p - 0.75) / 0.25);
    at.add((x + out * x.sign, y));
  }
  final sway = 2 * math.sin(s.turn);
  // The rope goes up to where it is fixed.
  s.canvas.drawLine(
    s.at(sway, 34),
    s.at(2, 110),
    s.stroke(s.scheme.onSurfaceVariant.withValues(alpha: 0.7), 1.4),
  );
  paintPose(
    s,
    Pose(
      sway,
      30 + 1.5 * math.sin(2 * s.turn),
      0,
      at[3].$1,
      at[3].$2,
      at[1].$1,
      at[1].$2,
      at[0].$1,
      at[0].$2,
      at[2].$1,
      at[2].$2,
      front: 1,
    ),
  );
}

/// Boxing at a bag, martial arts with a kick, or fencing with a lunge.
void paintFight(Stage s) {
  if (s.type == WorkoutType.fencing) return _fence(s);
  const guard = Pose(0, 29, 0.12, 9, 0, -9, 0, 12, 54, 9, 50);
  const jab = Pose(2, 29, 0.18, 11, 0, -9, 0, 27, 52, 8, 50);
  const cross = Pose(4, 29, 0.3, 11, 0, -10, 1, 10, 52, 29, 50);
  const duck = Pose(0, 23, 0.32, 9, 0, -9, 0, 13, 46, 10, 43);
  const kick = Pose(-3, 31, -0.28, 27, 38, -8, 0, 4, 50, -8, 46);
  final frames = [
    guard,
    jab,
    guard,
    cross,
    guard,
    s.type == WorkoutType.martialArts ? kick : duck,
  ];
  final pose = Pose.loop(frames, s.phase, hold: 0.15);

  // The bag swings from each of the two blows and comes to rest again.
  final sinceJab = ((s.phase - 1.6 / 6) % 1) * s.cycle;
  final sinceCross = ((s.phase - 3.6 / 6) % 1) * s.cycle;
  final since = math.min(sinceJab, sinceCross);
  final swing = 0.16 * math.exp(-2.6 * since) * math.sin(9 * since);
  final top = s.at(40, 100);
  s.canvas
    ..save()
    ..translate(top.dx, top.dy)
    ..rotate(-swing)
    ..drawLine(Offset.zero, Offset(0, 24 * s.u), s.pen.thing(1.8))
    ..drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-8 * s.u, 24 * s.u, 16 * s.u, 44 * s.u),
        Radius.circular(7 * s.u),
      ),
      s.fill(s.scheme.onSurfaceVariant.withValues(alpha: 0.75)),
    )
    ..restore();

  s.pen.shadow(s.at(1, -3.4), 15);
  final limbs = paintPose(s, pose);
  s.canvas
    ..drawCircle(
      limbs.farHand,
      4.6 * s.u,
      s.fill(Color.lerp(s.accent, s.scheme.surfaceContainerHighest, 0.4)!),
    )
    ..drawCircle(limbs.nearHand, 4.6 * s.u, s.fill(s.accent));
}

void _fence(Stage s) {
  const garde = Pose(0, 27, 0, 12, 0, -10, 0, 16, 44, -13, 56, tool: 0.18);
  const lunge = Pose(11, 21, 0.26, 31, 0, -13, 0, 35, 43, -15, 33, tool: 0.02);
  const step = Pose(3, 27, 0, 15, 0, -7, 0, 19, 45, -10, 56, tool: 0.3);
  final pose = Pose.loop(const [garde, lunge, garde, step], s.phase, hold: 0.3);
  s.pen.shadow(s.at(pose.hipX, -3.4), 18);
  final limbs = paintPose(s, pose);
  final hand = limbs.nearHand;
  s.canvas
    ..drawLine(hand, along(hand, pose.tool, 36 * s.u), s.pen.thing(1.4))
    ..drawCircle(along(hand, pose.tool, 2 * s.u), 3.2 * s.u, s.fill(s.accent));
}

/// Moving to music, jumping jacks for an interval session, or striding on
/// a cross trainer.
void paintDance(Stage s) {
  switch (s.type) {
    case WorkoutType.hiit:
      const closed = Pose(0, 32, 0, 3, 0, -3, 0, 9, 33, -9, 33, front: 1);
      const open = Pose(0, 35, 0, 15, 2, -15, 2, 15, 76, -15, 76, front: 1);
      final pose = Pose.loop(const [closed, open], s.phase);
      s.pen.shadow(s.at(0, -3.4), 10 + 8 * (pose.hipY - 32) / 3);
      paintPose(s, pose);
    case WorkoutType.elliptical:
      _crossTrainer(s);
    default:
      const frames = [
        Pose(-5, 30, -0.08, 10, 0, -8, 0, 21, 70, -19, 40, front: 1),
        Pose(0, 32, 0, 7, 0, -7, 2, 13, 50, -13, 50, front: 1),
        Pose(5, 30, 0.08, 8, 0, -10, 0, 19, 40, -21, 70, front: 1),
        Pose(0, 32, 0, 7, 2, -7, 0, 13, 50, -13, 50, front: 1),
      ];
      _notes(s);
      s.pen.shadow(s.at(0, -3.4), 15);
      paintPose(s, Pose.loop(frames, s.phase));
  }
}

/// Notes that rise beside the dancer and fade.
void _notes(Stage s) {
  final u = s.u;
  for (var i = 0; i < 4; i++) {
    final age = (s.time * 0.33 + i * 0.25) % 1;
    final side = i.isEven ? 1.0 : -1.0;
    final head = s.at(
      side * (36 + i * 5) + 4 * math.sin(age * tau),
      28 + age * 46,
    );
    final color = s.accent.withValues(alpha: 0.8 * math.sin(math.pi * age));
    final stem = s.stroke(color, 1.4);
    s.canvas
      ..drawOval(
        Rect.fromCenter(center: head, width: 5.4 * u, height: 4 * u),
        s.fill(color),
      )
      ..drawLine(
        head + Offset(2.4 * u, 0),
        head + Offset(2.4 * u, -11 * u),
        stem,
      )
      ..drawLine(
        head + Offset(2.4 * u, -11 * u),
        head + Offset(6.5 * u, -8 * u),
        stem,
      );
  }
}

void _crossTrainer(Stage s) {
  final turn = s.turn;
  final frame = s.pen.thing(3);
  (double, double) pedal(double phase) =>
      (10 * math.cos(phase), 7 - 4 * math.sin(phase));
  final near = pedal(turn);
  final far = pedal(turn + math.pi);
  final reach = 7 * math.sin(turn);
  s.pen.shadow(s.at(0, -3.4), 26);
  s.canvas
    ..drawLine(s.at(-26, -3), s.at(30, -3), frame)
    ..drawCircle(s.at(-20, 8), 9 * s.u, frame)
    ..drawLine(s.at(24, -3), s.at(21, 30), frame);
  // The levers the hands push and pull, and the bars the feet stand on.
  for (final (foot, hand) in [(far, 16 - reach), (near, 16 + reach)]) {
    s.canvas
      ..drawLine(s.at(21, 30), s.at(hand, 50), frame)
      ..drawLine(s.at(-20, 8), s.at(foot.$1 + 9, foot.$2 - 4.5), frame)
      ..drawLine(
        s.at(foot.$1 - 7, foot.$2 - 4.5),
        s.at(foot.$1 + 9, foot.$2 - 4.5),
        s.stroke(s.accent, 2.6),
      );
  }
  paintPose(
    s,
    Pose(
      0,
      37 + 0.8 * math.cos(2 * turn),
      0.12,
      near.$1,
      near.$2,
      far.$1,
      far.$2,
      16 + reach,
      50,
      16 - reach,
      50,
    ),
  );
}
