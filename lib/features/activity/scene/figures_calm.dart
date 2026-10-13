import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../data/models.dart';
import 'stage.dart';

/// Yoga that flows from one posture into the next, pilates on the mat, or
/// sitting and breathing.
void paintPosture(Stage s) {
  switch (s.type) {
    case WorkoutType.breathing:
      _breather(s);
    case WorkoutType.pilates:
      // Lying on the back, the legs passing each other like scissors.
      const one = Pose(4, 3, -1.47, 16, 34, 36, 9, 2, 6, 2, 3);
      const other = Pose(4, 3, -1.47, 36, 9, 16, 34, 2, 3, 2, 6);
      s.pen.shadow(s.at(0, -3.4), 32);
      paintPose(s, Pose.loop(const [one, other], s.phase, hold: 0.2));
    default:
      const mountain = Pose(0, 32, 0, 3, 0, -3, 0, 5, 77, -5, 77, front: 1);
      const warrior = Pose(4, 24, 0, 21, 0, -23, 0, 34, 47, -26, 47, front: 1);
      const tree = Pose(0, 32, 0, -1, 17, -3, 0, 2, 78, -2, 78, front: 1);
      const dog = Pose(-6, 32, 2.3, -20, 0, -21, 0, 26, 0, 25, 0);
      final pose = Pose.loop(
        const [mountain, warrior, mountain, tree, mountain, dog],
        s.phase,
        hold: 0.5,
      );
      s.pen.shadow(s.at(pose.hipX, -3.4), 14 + 14 * (pose.lean / 2.3));
      paintPose(s, pose);
  }
}

/// Seen from the front, sitting cross-legged; the arms rise with a breath,
/// and so does a circle of light.
void _breather(Stage s) {
  final u = s.u;
  final pen = s.pen;
  final breath = 0.5 - 0.5 * math.cos(s.turn);
  final hip = s.at(0, 5);
  final neck = hip + Offset(0, -(24 + breath) * u);
  s.canvas.drawCircle(
    hip + Offset(0, -20 * u),
    (30 + 9 * breath) * u,
    s.fill(s.accent.withValues(alpha: 0.12 + 0.1 * breath)),
  );
  pen.shadow(s.at(0, -3.4), 22);
  for (final side in const [-1.0, 1.0]) {
    pen.line(pen.limb(far: side < 0), [
      hip,
      s.at(18 * side, 2),
      s.at(-5 * side, 0),
    ]);
  }
  pen
    ..line(pen.limb(), [hip, neck])
    ..head(neck + Offset(0, -9.5 * u));
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
