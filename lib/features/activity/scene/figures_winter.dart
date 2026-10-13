import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../data/models.dart';
import 'figures_ground.dart';
import 'stage.dart';

/// Downhill on skis or on a snowboard, swinging from turn to turn with
/// snow flying up behind.
void paintGlide(Stage s) {
  final sway = math.sin(s.turn);
  final deep = sway.abs();
  final edge = s.stroke(s.scheme.onSurfaceVariant, 2.8);
  paintDust(s, s.time * 1.4, color: s.pale, steady: true, x: -8);
  s.pen.shadow(s.at(0, -3.4), 20);
  if (s.type == WorkoutType.snowboard) {
    // Sideways on the board, the arms out for balance.
    s.rocking(0, -2, 0.1 * sway, 0, () {
      s.canvas.drawLine(s.at(-19, -1.6), s.at(19, -1.6), s.stroke(s.accent, 4));
      paintPose(
        s,
        Pose(
          -1 + 2 * sway,
          22 + 3 * deep,
          0.16 + 0.1 * sway,
          11,
          1.5,
          -11,
          1.5,
          22,
          42 + 6 * sway,
          -19,
          44 - 6 * sway,
        ),
      );
    });
    return;
  }
  final pose = Pose(
    -3,
    23 + 4 * (1 - deep),
    0.55 - 0.12 * (1 - deep),
    4,
    0.5,
    -2,
    0.5,
    13,
    30 + 2 * sway,
    10,
    30 - 2 * sway,
  );
  // The far ski and pole first, then the figure, then the near ones.
  s.canvas.drawLine(s.at(-16, -2.2), s.at(17, -2.2), edge);
  final limbs = paintPose(s, pose);
  final pole = s.pen.thing(1.8);
  s.canvas
    ..drawLine(limbs.farHand, limbs.farHand + Offset(-24 * s.u, 22 * s.u), pole)
    ..drawLine(
      limbs.nearHand,
      limbs.nearHand + Offset(-26 * s.u, 24 * s.u),
      pole,
    )
    ..drawPath(
      Path()
        ..moveTo(s.at(-13, -1.6).dx, s.at(-13, -1.6).dy)
        ..lineTo(s.at(20, -1.6).dx, s.at(20, -1.6).dy)
        ..lineTo(s.at(24, 1).dx, s.at(24, 1).dy),
      edge,
    );
}

/// Skating with long strides, on ice or on wheels; with a stick and a puck
/// for hockey.
void paintSkate(Stage s) {
  final hockey = s.type == WorkoutType.iceHockey;
  final wheels = s.type == WorkoutType.skating;
  const frames = [
    Pose(0, 25, 0.6, 4, 1, -25, 11, -12, 35, 19, 41),
    Pose(0, 27, 0.52, 1, 1, 2, 3, 5, 34, 5, 34),
    Pose(0, 25, 0.6, -25, 11, 4, 1, 19, 41, -12, 35),
    Pose(0, 27, 0.52, 2, 3, 1, 1, 5, 34, 5, 34),
  ];
  var pose = Pose.loop(frames, s.phase);
  if (hockey) {
    // Both hands stay on the stick.
    pose = Pose(
      pose.hipX,
      pose.hipY,
      pose.lean,
      pose.nearFootX,
      pose.nearFootY,
      pose.farFootX,
      pose.farFootY,
      20,
      30,
      12,
      36,
    );
  }
  paintDust(
    s,
    s.time * 1.2,
    color: wheels ? null : s.pale,
    steady: true,
    x: -6,
  );
  s.pen.shadow(s.at(0, -3.4), 16);
  final limbs = paintPose(s, pose);

  final blade = s.stroke(s.scheme.onSurfaceVariant, wheels ? 1.6 : 2.2);
  for (final foot in [limbs.farFoot, limbs.nearFoot]) {
    final under = foot + Offset(0, 4.2 * s.u);
    if (wheels) {
      for (final dx in [-4.0, 0.0, 4.0]) {
        s.canvas.drawCircle(
          under + Offset(dx * s.u, 0.6 * s.u),
          1.7 * s.u,
          s.fill(s.scheme.onSurfaceVariant),
        );
      }
    } else {
      s.canvas.drawLine(
        under + Offset(-6 * s.u, 0),
        under + Offset(7 * s.u, 0),
        blade,
      );
    }
  }
  if (hockey) {
    final heel = s.at(36, -2.4);
    s.canvas
      ..drawLine(limbs.farHand, heel, s.pen.thing(2.4))
      ..drawLine(heel, s.at(44, -2.4), s.stroke(s.accent, 3))
      ..drawOval(
        Rect.fromCenter(
          center: s.at(47 + 2 * math.sin(s.turn * 2), -2.2),
          width: 6 * s.u,
          height: 2.6 * s.u,
        ),
        s.fill(s.scheme.onSurfaceVariant),
      );
  }
}
