import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../data/models.dart';
import 'stage.dart';

double _ease(double t) => Curves.easeInOut.transform(t.clamp(0.0, 1.0));

/// The height of something thrown, [t] of the way from [from] to [to],
/// that rises [over] above the straight line between them.
double _arc(double from, double to, double over, double t) =>
    from + (to - from) * t + over * 4 * t * (1 - t);

/// Keeping a ball up with the feet, one after the other.
void paintKick(Stage s) {
  const stand = Pose(0, 32, 0.04, 4, 0, -6, 0, 8, 37, -8, 36);
  const frames = [
    stand,
    Pose(-1, 32.5, -0.1, 17, 13, -6, 0, -9, 42, 12, 44),
    Pose(0, 32, 0.04, -5, 0, 5, 0, 8, 37, -8, 36),
    Pose(-1, 32.5, -0.1, -5, 0, 17, 13, 12, 44, -9, 42),
  ];
  s.pen.shadow(s.at(0, -3.4), 13);
  paintPose(s, Pose.loop(frames, s.phase, hold: 0.15));

  // The ball leaves a foot at every other frame and is back for the next.
  final flown = (s.phase * 2 + 0.44) % 1;
  final x = 19.0;
  final y = _arc(19, 19, 30, flown);
  final shade = s.at(x, -3.4);
  s.canvas.drawOval(
    Rect.fromCenter(center: shade, width: 9 * s.u, height: 2.6 * s.u),
    s.fill(s.scheme.shadow.withValues(alpha: 0.1)),
  );
  if (s.type == WorkoutType.soccer) {
    s.ball(x, y, 5);
    s.canvas.drawCircle(
      s.at(x, y),
      1.7 * s.u,
      s.fill(s.scheme.onSurfaceVariant),
    );
  } else {
    // The ball of rugby and of football is long, and tumbles.
    final centre = s.at(x, y);
    s.canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..rotate(s.time * 5)
      ..drawOval(
        Rect.fromCenter(center: Offset.zero, width: 13 * s.u, height: 8 * s.u),
        s.fill(s.accent),
      )
      ..restore();
  }
}

/// Hitting a ball back with a racket: it comes over the net, is struck and
/// flies off again.
void paintRacket(Stage s) {
  final table = s.type == WorkoutType.tableTennis;
  final shuttle = s.type == WorkoutType.badminton;
  final reach = table ? 9.0 : 17.0;
  const frames = [
    Pose(0, 29, 0.12, 8, 0, -8, 0, 12, 38, 10, 36, tool: 1.0),
    Pose(-3, 29, 0.02, 8, 0, -10, 0, -15, 44, 9, 42, tool: 2.5),
    Pose(3, 31, 0.2, 12, 0, -10, 0, 22, 42, -6, 40, tool: 1.15),
    Pose(4, 31, 0.24, 12, 0, -8, 2, 11, 60, -8, 37, tool: 2.6),
  ];
  final phase = s.phase;
  final pose = Pose.loop(frames, phase, hold: 0.1);
  s.pen.shadow(s.at(1, -3.4), 15);

  // Struck in the middle of the round, where the racket is furthest out.
  const hitX = 28.0;
  final hitY = table ? 46.0 : 56.0;
  final surface = table ? 22.0 : 0.0;
  final double x;
  final double y;
  if (phase < 0.3 && !shuttle) {
    final t = phase / 0.3;
    x = 135 - (135 - 58) * t;
    y = surface + (table ? 34 : 50) * (1 - t * t);
  } else if (phase < 0.5) {
    final t = shuttle ? phase / 0.5 : (phase - 0.3) / 0.2;
    x = shuttle ? 135 - (135 - hitX) * t : 58 - (58 - hitX) * t;
    y = shuttle
        ? _arc(70, hitY, 14, t)
        : surface + (hitY - surface) * (1 - (1 - t) * (1 - t));
  } else {
    final t = (phase - 0.5) / 0.5;
    x = hitX + (150 - hitX) * t;
    y = _arc(hitY, 44, table ? 6 : 22, t);
  }

  final limbs = paintPose(s, pose);
  final grip = limbs.nearHand;
  final head = along(grip, pose.tool, reach * s.u);
  final middle = along(grip, pose.tool, (reach + (table ? 4 : 6)) * s.u);
  s.canvas
    ..drawLine(grip, head, s.pen.thing(2.4))
    ..save()
    ..translate(middle.dx, middle.dy)
    ..rotate(-pose.tool)
    ..drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: (table ? 9 : 13) * s.u,
        height: (table ? 8 : 9) * s.u,
      ),
      table ? s.fill(s.accent) : (s.stroke(s.accent, 2)),
    )
    ..restore();
  s.ball(x, y, table ? 1.8 : 2.6, color: shuttle ? s.pale : s.accent);
}

/// Playing a ball with the hands: thrown at a basket or a goal and back
/// again, or kept in the air over a net.
void paintToss(Stage s) {
  if (s.type == WorkoutType.volleyball) return _volley(s);
  final disc = s.type == WorkoutType.frisbee;
  final basket = s.type == WorkoutType.basketball;
  final inWater = s.type == WorkoutType.waterPolo;
  // In the water only head, arms and shoulders show.
  final sunk = inWater ? 16.0 : 0.0;
  Pose lowered(Pose pose) => sunk == 0
      ? pose
      : Pose(
          pose.hipX,
          pose.hipY - sunk,
          pose.lean,
          pose.nearFootX,
          pose.nearFootY - sunk,
          pose.farFootX,
          pose.farFootY - sunk,
          pose.nearHandX,
          pose.nearHandY - sunk,
          pose.farHandX,
          pose.farHandY - sunk,
        );
  const frames = [
    Pose(0, 30, 0.05, 6, 0, -6, 0, 11, 46, 9, 44),
    Pose(0, 25, 0.12, 7, 0, -7, 0, 11, 40, 9, 38),
    Pose(1, 32, -0.04, 3, 1, -3, 0, 9, 74, 5, 72),
    Pose(0, 29, 0.08, 6, 0, -6, 0, 13, 60, 8, 50),
    Pose(0, 31, 0.05, 6, 0, -6, 0, 16, 45, 12, 41),
  ];
  final phase = s.phase;
  final pose = lowered(Pose.loop(frames, phase, hold: 0.1));
  if (!inWater) {
    s.pen.shadow(s.at(0, -3.4), 13 - 4 * _ease((pose.hipY - 30) / 8));
  }
  final limbs = paintPose(s, pose);

  // Where it is aimed, and how it comes back.
  final (targetX, targetY) = basket
      ? (72.0, 60.0)
      : disc
      ? (150.0, 52.0)
      : (92.0, 22.0 - sunk * 0.3);
  final held =
      Offset.lerp(limbs.nearHand, limbs.farHand, 0.5)! +
      Offset(3 * s.u, -5 * s.u);
  final releaseX = 10.0;
  final releaseY = 78.0 - sunk;
  final catchX = 17.0;
  final catchY = 48.0 - sunk;
  final Offset at;
  if (phase < 0.42) {
    at = held;
  } else if (phase < 0.68) {
    final t = (phase - 0.42) / 0.26;
    at = s.at(
      releaseX + (targetX - releaseX) * t,
      _arc(releaseY, targetY, basket ? 14 : 4, t),
    );
  } else if (basket && phase < 0.8) {
    // Through the ring and down to the floor.
    final t = (phase - 0.68) / 0.12;
    at = s.at(targetX + 3 * t, targetY - (targetY - 1) * t * t);
  } else {
    final from = basket ? 0.8 : 0.68;
    final t = (phase - from) / (1 - from);
    final startX = basket ? targetX + 3 : targetX;
    final startY = basket ? 1.0 : targetY;
    at = s.at(
      startX + (catchX - startX) * t,
      _arc(startY, catchY, disc ? 10 : 18, t),
    );
  }
  if (disc) {
    s.canvas.drawOval(
      Rect.fromCenter(center: at, width: 15 * s.u, height: 4 * s.u),
      s.fill(s.accent),
    );
  } else {
    s.canvas
      ..drawCircle(at, 5.5 * s.u, s.fill(basket ? s.accent : s.pale))
      ..drawCircle(at, 5.5 * s.u, s.stroke(s.scheme.onSurfaceVariant, 1.1));
  }
}

/// Keeping a ball in the air with the forearms.
void _volley(Stage s) {
  const frames = [
    Pose(0, 31, 0.1, 7, 0, -7, 0, 13, 45, 12, 44),
    Pose(1, 26, 0.22, 8, 0, -8, 0, 20, 37, 19, 36),
  ];
  // Struck when the arms are lowest, halfway through the round.
  final pose = Pose.loop(frames, s.phase + 0.5, hold: 0.2);
  s.pen.shadow(s.at(0, -3.4), 13);
  paintPose(s, pose);
  final flown = (s.phase + 0.1) % 1;
  s.ball(21, _arc(42, 42, 40, flown), 5.5);
}

/// Hitting a ball with a bat, or with a club off the ground.
void paintBat(Stage s) {
  if (s.type == WorkoutType.golf) return _golf(s);
  const frames = [
    Pose(0, 30, 0.1, 8, 0, -8, 0, -4, 52, -6, 50, tool: 1.9),
    Pose(-2, 29, 0.05, 6, 2, -9, 0, -8, 54, -10, 52, tool: 2.3),
    Pose(3, 30, 0.15, 12, 0, -9, 0, 16, 42, 14, 40, tool: 0.1),
    Pose(4, 31, 0.1, 12, 0, -8, 1, 4, 58, 2, 56, tool: 3.7),
  ];
  final phase = s.phase;
  final pose = Pose.loop(frames, phase, hold: 0.25);
  s.pen.shadow(s.at(1, -3.4), 15);
  final limbs = paintPose(s, pose);
  final cricket = s.type == WorkoutType.cricket;
  s.canvas.drawLine(
    limbs.nearHand,
    along(limbs.nearHand, pose.tool, 25 * s.u),
    s.stroke(s.accent, cricket ? 5 : 3.6),
  );

  // The ball comes in for the swing and leaves it high.
  if (phase > 0.3 && phase < 0.56) {
    final t = (phase - 0.3) / 0.26;
    s.ball(150 - (150 - 34) * t, _arc(46, 42, 6, t), 2.8);
  } else if (phase >= 0.56 && phase < 0.9) {
    final t = (phase - 0.56) / 0.34;
    s.ball(34 + 130 * t, 42 + 60 * math.sqrt(t), 2.8);
  }
}

void _golf(Stage s) {
  const frames = [
    Pose(0, 29, 0.35, 7, 0, -7, 0, 10, 25, 9, 24, tool: -1.25),
    Pose(-1, 30, 0.22, 7, 0, -7, 0, -10, 58, -11, 57, tool: -3.9),
    Pose(1, 29, 0.35, 7, 0, -7, 0, 11, 25, 10, 24, tool: -1.25),
    Pose(3, 32, 0, 7, 0, -5, 2, 2, 62, 0, 60, tool: 2.8),
  ];
  final phase = s.phase;
  final pose = Pose.loop(frames, phase, hold: 0.3);
  s.pen.shadow(s.at(0, -3.4), 14);
  final limbs = paintPose(s, pose);
  final head = along(limbs.nearHand, pose.tool, 26 * s.u);
  s.canvas
    ..drawLine(limbs.nearHand, head, s.pen.thing(2))
    ..drawLine(
      head,
      along(head, pose.tool + 1.4, 4 * s.u),
      s.stroke(s.accent, 3),
    );

  // Struck at the bottom of the swing, which is where frame two ends.
  const struck = 0.5 + 0.3 / 4;
  if (phase < struck) {
    s.ball(18, 0, 2.2);
  } else if (phase < struck + 0.22) {
    final t = (phase - struck) / 0.22;
    s.ball(18 + 150 * t, 70 * math.sqrt(t), 2.2);
  }
}
