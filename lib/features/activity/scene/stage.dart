import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../data/models.dart';
import '../../../widgets/scene_kit.dart';

const double tau = 2 * math.pi;

/// One frame of a workout's scene: where it is drawn, in which colours and
/// at what moment. Every figure and every setting draws on it.
///
/// Lengths are in hundredths of the scene's height. A point given as
/// ([x], [y]) lies [x] to the right of the figure's place and [y] above the
/// ground it stands on.
class Stage {
  Stage({
    required this.canvas,
    required this.size,
    required this.scheme,
    required this.type,
    required this.time,
    required this.cycle,
    required this.travel,
    required this.enter,
    this.walksIn = true,
    this.mascot = false,
  });

  final Canvas canvas;
  final Size size;
  final ColorScheme scheme;
  final WorkoutType type;

  /// Seconds since the scene began.
  final double time;

  /// Seconds one stride, stroke or round of exercises takes.
  final double cycle;

  /// How fast the ground passes, in scene heights per second.
  final double travel;
  final SceneEntrance enter;

  /// Whether a figure that travels comes in from the left.
  final bool walksIn;

  /// Whether the figure is the turtle.
  final bool mascot;

  double get u => size.height / 100;

  /// Where the middle of a foot is that stands on the ground.
  double get ground => size.height - 14 * u;

  /// The line a standing foot rests on.
  double get floor => ground + 3.4 * u;

  /// How far through its [cycle] the figure is, from 0 to 1.
  double get phase => time / cycle % 1;
  double get turn => tau * phase;

  /// How far the ground has passed, in pixels.
  double get travelled => time * travel * size.height;

  /// A figure that goes somewhere comes in from the left.
  double get centre =>
      size.width *
      (0.5 - (walksIn && travel > 0 ? 0.25 * (1 - enter.arrived) : 0));

  /// How far the setting still has to rise, in pixels.
  double get drop => enter.drop * 26 * u;

  Rect get bounds => Offset.zero & size;

  Offset at(double x, double y) => Offset(centre + x * u, ground - y * u);

  FigurePen get pen => FigurePen(canvas, scheme, u, mascot: mascot);

  /// The colour of land, floors and water.
  Color get soft =>
      Color.lerp(scheme.secondaryContainer, scheme.secondary, 0.2)!;

  /// The colour of what the figure plays with.
  Color get accent => scheme.tertiary;

  /// Something pale that stands out from the setting: snow, a ball, a sail.
  Color get pale => scheme.brightness == Brightness.light
      ? scheme.surfaceBright
      : Color.lerp(scheme.secondaryContainer, scheme.onSurface, 0.6)!;

  Paint fill(Color color) => Paint()..color = color;

  Paint stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width * u
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// A ball of [radius] at ([x], [y]).
  void ball(double x, double y, double radius, {Color? color}) {
    final centre = at(x, y);
    canvas
      ..drawCircle(centre, radius * u, fill(color ?? pale))
      ..drawCircle(centre, radius * u, stroke(scheme.onSurfaceVariant, 1.1));
  }

  /// Draws what [paint] draws as seen in a mirror, so that the figure
  /// faces left.
  void mirrored(VoidCallback paint) {
    canvas
      ..save()
      ..translate(2 * centre, 0)
      ..scale(-1, 1);
    paint();
    canvas.restore();
  }

  /// Draws what [paint] draws turned by [angle] about ([x], [y]) and lifted
  /// by [rise]: something that rocks on water or hangs in the wind.
  void rocking(
    double x,
    double y,
    double angle,
    double rise,
    VoidCallback paint,
  ) {
    final pivot = at(x, y);
    canvas
      ..save()
      ..translate(pivot.dx, pivot.dy - rise * u)
      ..rotate(angle)
      ..translate(-pivot.dx, -pivot.dy);
    paint();
    canvas.restore();
  }
}

/// How a figure holds itself at one moment: where its hip, feet and hands
/// are. Knees, elbows, shoulders and head follow from these.
class Pose {
  const Pose(
    this.hipX,
    this.hipY,
    this.lean,
    this.nearFootX,
    this.nearFootY,
    this.farFootX,
    this.farFootY,
    this.nearHandX,
    this.nearHandY,
    this.farHandX,
    this.farHandY, {
    this.tool = 0,
    this.front = 0,
  });

  final double hipX;
  final double hipY;

  /// How far the body leans forward, in radians; a quarter turn lies flat.
  final double lean;
  final double nearFootX;
  final double nearFootY;
  final double farFootX;
  final double farFootY;
  final double nearHandX;
  final double nearHandY;
  final double farHandX;
  final double farHandY;

  /// The direction of what the hands hold, in radians from pointing right,
  /// turning upwards.
  final double tool;

  /// 0 for a figure seen from the side, 1 for one seen from the front,
  /// whose near limbs are those on the right.
  final double front;

  static Pose lerp(Pose a, Pose b, double t) {
    double mix(double from, double to) => from + (to - from) * t;
    return Pose(
      mix(a.hipX, b.hipX),
      mix(a.hipY, b.hipY),
      mix(a.lean, b.lean),
      mix(a.nearFootX, b.nearFootX),
      mix(a.nearFootY, b.nearFootY),
      mix(a.farFootX, b.farFootX),
      mix(a.farFootY, b.farFootY),
      mix(a.nearHandX, b.nearHandX),
      mix(a.nearHandY, b.nearHandY),
      mix(a.farHandX, b.farHandX),
      mix(a.farHandY, b.farHandY),
      tool: mix(a.tool, b.tool),
      front: mix(a.front, b.front),
    );
  }

  /// The pose at [phase], from 0 to 1, of a round through [frames]. Each
  /// frame is held for the share [hold] of its time before the figure moves
  /// on to the next.
  static Pose loop(List<Pose> frames, double phase, {double hold = 0}) {
    final at = phase % 1 * frames.length;
    final index = at.floor() % frames.length;
    final within = at - at.floor();
    final moved = within <= hold ? 0.0 : (within - hold) / (1 - hold);
    return lerp(
      frames[index],
      frames[(index + 1) % frames.length],
      Curves.easeInOut.transform(moved.clamp(0.0, 1.0)),
    );
  }
}

/// Where the parts of a drawn figure ended up, for what it holds or wears.
class Limbs {
  const Limbs({
    required this.hip,
    required this.neck,
    required this.head,
    required this.nearHand,
    required this.farHand,
    required this.nearFoot,
    required this.farFoot,
  });

  final Offset hip;
  final Offset neck;
  final Offset head;
  final Offset nearHand;
  final Offset farHand;
  final Offset nearFoot;
  final Offset farFoot;
}

const double _thigh = 17;
const double _shin = 17;
const double _upperArm = 12;
const double _forearm = 11;
const double _trunk = 24;

/// Draws the figure in [pose] and says where its parts are.
Limbs paintPose(Stage s, Pose pose) {
  final u = s.u;
  final pen = s.pen;
  final front = pose.front.clamp(0.0, 1.0);
  final hip = s.at(pose.hipX, pose.hipY);
  final up = Offset(math.sin(pose.lean), -math.cos(pose.lean));
  final neck = hip + up * _trunk * u;
  final head = neck + up * 9.5 * u;

  // The far side is paler seen from the side, and the same seen from the
  // front.
  Paint limb({required bool far}) {
    if (pen.mascot) return pen.limb(far: far && front < 0.5);
    final paint = pen.limb();
    if (!far) return paint;
    return paint
      ..color = Color.lerp(
        paint.color,
        s.scheme.surfaceContainerHighest,
        0.45 * (1 - front),
      )!;
  }

  List<Offset> reach(
    Offset from,
    Offset target,
    double first,
    double second,
    double side,
    double outward,
  ) {
    final delta = target - from;
    final longest = (first + second) * u * 0.999;
    final to = delta.distance > longest
        ? from + delta / delta.distance * longest
        : target;
    final seenFromSide = FigurePen.joint(from, to, first * u, second * u, side);
    if (front == 0) return [from, seenFromSide, to];
    // Seen from the front a knee or an elbow points away from the body.
    final one = FigurePen.joint(from, to, first * u, second * u, 1);
    final other = FigurePen.joint(from, to, first * u, second * u, -1);
    final away = (one.dx - hip.dx) * outward > (other.dx - hip.dx) * outward
        ? one
        : other;
    return [from, Offset.lerp(seenFromSide, away, front)!, to];
  }

  List<Offset> leg(double x, double y, double outward) => reach(
    hip + Offset(4 * outward * front * u, 0),
    s.at(x, y),
    _thigh,
    _shin,
    -1,
    outward,
  );
  List<Offset> arm(double x, double y, double outward) => reach(
    neck + Offset(7 * outward * u, 2 * u) * front,
    s.at(x, y),
    _upperArm,
    _forearm,
    1,
    outward,
  );

  final farLeg = leg(pose.farFootX, pose.farFootY, -1);
  final farArm = arm(pose.farHandX, pose.farHandY, -1);
  final nearLeg = leg(pose.nearFootX, pose.nearFootY, 1);
  final nearArm = arm(pose.nearHandX, pose.nearHandY, 1);
  pen
    ..line(limb(far: true), farLeg)
    ..line(limb(far: true), farArm)
    ..body(hip, neck, front: front)
    ..head(head, neck: neck, front: front)
    ..line(limb(far: false), nearLeg)
    ..line(limb(far: false), nearArm);
  return Limbs(
    hip: hip,
    neck: neck,
    head: head,
    nearHand: nearArm.last,
    farHand: farArm.last,
    nearFoot: nearLeg.last,
    farFoot: farLeg.last,
  );
}

/// A point [length] from [from] in the direction [angle], which is in
/// radians from pointing right, turning upwards.
Offset along(Offset from, double angle, double length) =>
    from + Offset(math.cos(angle), -math.sin(angle)) * length;
