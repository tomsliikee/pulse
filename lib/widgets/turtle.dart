import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/mascot_colors.dart';

/// The turtle the scenes show in place of the stick figure where the
/// mascot is switched on. Its shell, plates and scales are paths built once
/// in units of their own; a frame only moves, turns and scales them.
///
/// In the shell's units the long side runs along x from -17 to 17, the
/// dome rises towards negative y and the belly lies on y = 0.
abstract final class Turtle {
  /// The length of the shell along the trunk of a figure that stands, in
  /// the shell's units, for a trunk of [trunk] hundredths of the scene.
  static const double trunk = 24;

  static final Path _dome = Path()
    ..moveTo(-17, 1.2)
    ..cubicTo(-17.5, -9, -9, -14.5, 0, -14.5)
    ..cubicTo(9, -14.5, 17.5, -9, 17, 1.2)
    ..close();

  static final Path _plates = () {
    final path = Path();
    for (final (x, y, r) in const [
      (-8.6, -5.6, 4.4),
      (0.0, -9.2, 4.6),
      (8.6, -5.6, 4.4),
      (0.0, -2.4, 3.4),
    ]) {
      path.addPolygon([
        for (var k = 0; k < 6; k++)
          Offset(
            x + r * math.cos(math.pi / 6 + k * math.pi / 3),
            y + r * math.sin(math.pi / 6 + k * math.pi / 3),
          ),
      ], true);
    }
    return path;
  }();

  static final Path _rim = () {
    final path = Path();
    for (var k = 0; k < 8; k++) {
      path.addOval(
        Rect.fromCircle(center: Offset(-15.4 + k * 4.4, 0.8), radius: 2.5),
      );
    }
    return path;
  }();

  /// A light along the top of the dome.
  static final Path _shine = Path()
    ..moveTo(-9, -12.2)
    ..quadraticBezierTo(-4, -14.4, 2, -13.6);

  /// The plate of the belly, in front of the trunk.
  static final RRect _belly = RRect.fromLTRBR(
    -15,
    0.2,
    15,
    4.4,
    const Radius.circular(2.2),
  );

  /// The shell seen from the front: a ring around the belly.
  static final Rect _frontShell = Rect.fromCenter(
    center: Offset.zero,
    width: 36,
    height: 31,
  );
  static final Rect _frontBelly = Rect.fromCenter(
    center: const Offset(0, 1),
    width: 22,
    height: 23,
  );
  static final Path _frontSeams = Path()
    ..moveTo(-10, -2)
    ..lineTo(10, -2)
    ..moveTo(-9.6, 4.6)
    ..lineTo(9.6, 4.6)
    ..moveTo(0, -10)
    ..lineTo(0, 12);

  /// The shell over a trunk from [hip] to [neck]: its dome on the back and
  /// the belly towards the front, the side the figure looks to. Seen from
  /// the front where [front] is past one half.
  static void body(
    Canvas canvas,
    MascotColors colors,
    double u,
    Offset hip,
    Offset neck, {
    double front = 0,
  }) {
    final axis = neck - hip;
    final length = axis.distance;
    if (length == 0) return;
    final scale = length / trunk;
    canvas
      ..save()
      ..translate((hip.dx + neck.dx) / 2, (hip.dy + neck.dy) / 2)
      ..rotate(math.atan2(axis.dy, axis.dx))
      ..scale(scale);
    if (front > 0.5) {
      // Turned so the trunk runs up the screen and the belly faces out.
      canvas.rotate(math.pi / 2);
      canvas
        ..drawOval(_frontShell, Paint()..color = colors.shell)
        ..drawOval(_frontBelly, Paint()..color = colors.belly)
        ..drawPath(
          _frontSeams,
          Paint()
            ..color = colors.plates
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
    } else {
      _side(canvas, colors);
      canvas.drawRRect(_belly, Paint()..color = colors.belly);
    }
    canvas.restore();
  }

  static void _side(Canvas canvas, MascotColors colors) {
    canvas
      ..drawPath(_dome, Paint()..color = colors.shell)
      ..drawPath(_plates, Paint()..color = colors.plates)
      ..drawPath(
        _shine,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      )
      ..drawPath(_rim, Paint()..color = colors.rim);
  }

  /// The head at [centre], on a neck from [neck] where one is given. It
  /// looks the way [up] turned a quarter clockwise points: to the right
  /// for a head held straight up. [front] shows the face from the front.
  static void head(
    Canvas canvas,
    MascotColors colors,
    double u,
    Offset centre, {
    Offset? neck,
    Offset up = const Offset(0, -1),
    double front = 0,
    bool asleep = false,
    bool leftward = false,
    Color? band,
    Color? cap,
  }) {
    if (neck != null) {
      canvas.drawLine(
        neck,
        centre,
        Paint()
          ..color = colors.skin
          ..strokeWidth = 7 * u
          ..strokeCap = StrokeCap.round,
      );
    }
    final ahead = Offset(-up.dy, up.dx);
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..rotate(math.atan2(ahead.dy, ahead.dx))
      ..scale(leftward ? -u : u, u);
    final skin = Paint()..color = colors.skin;
    final ink = Paint()
      ..color = colors.pupil
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    if (front > 0.5) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 16, height: 14),
        skin,
      );
      for (final side in const [-1.0, 1.0]) {
        _eye(canvas, colors, ink, Offset(3.6 * side, -1.8), 0, asleep);
        canvas.drawCircle(
          Offset(5.2 * side, 2.6),
          1.7,
          Paint()..color = colors.cheek,
        );
      }
      canvas.drawArc(
        Rect.fromCenter(center: const Offset(0, 2.4), width: 4, height: 3),
        0.25 * math.pi,
        0.5 * math.pi,
        false,
        ink,
      );
    } else {
      canvas
        ..drawOval(
          Rect.fromCenter(center: const Offset(1.4, 0), width: 18, height: 14),
          skin,
        )
        ..drawCircle(const Offset(3, 2.6), 1.9, Paint()..color = colors.cheek)
        ..drawArc(
          Rect.fromCenter(center: const Offset(6.4, 1.8), width: 4, height: 3),
          0.15 * math.pi,
          0.6 * math.pi,
          false,
          ink,
        );
      _eye(canvas, colors, ink, const Offset(3.6, -2.4), 0.9, asleep);
    }
    if (band != null) {
      final paint = Paint()
        ..color = band
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      canvas
        ..drawArc(
          Rect.fromCenter(center: const Offset(1.4, 0), width: 18, height: 14),
          -0.95 * math.pi,
          0.62 * math.pi,
          false,
          paint,
        )
        ..drawLine(const Offset(-7.4, -2.6), const Offset(-11.6, -4.4), paint)
        ..drawLine(const Offset(-7.4, -2.6), const Offset(-11.2, -0.4), paint);
    }
    if (cap != null) {
      // A night cap that droops behind the head, with a ball at its tip.
      canvas
        ..drawPath(
          Path()
            ..moveTo(-7.6, -1.2)
            ..quadraticBezierTo(-2, -10.4, 6.4, -4.6)
            ..quadraticBezierTo(-4, -8, -13.6, 1.6)
            ..close(),
          Paint()..color = cap,
        )
        ..drawCircle(const Offset(-13.6, 2), 2.2, Paint()..color = colors.eye);
    }
    canvas.restore();
  }

  static void _eye(
    Canvas canvas,
    MascotColors colors,
    Paint ink,
    Offset at,
    double looking,
    bool asleep,
  ) {
    if (asleep) {
      canvas.drawArc(
        Rect.fromCenter(center: at, width: 4.4, height: 3),
        0.1 * math.pi,
        0.8 * math.pi,
        false,
        ink,
      );
      return;
    }
    canvas
      ..drawCircle(at, 3.1, Paint()..color = colors.eye)
      ..drawCircle(
        at + Offset(looking, 0.1),
        1.7,
        Paint()..color = colors.pupil,
      )
      ..drawCircle(
        at + Offset(looking + 0.6, -0.7),
        0.6,
        Paint()..color = colors.eye,
      );
  }

  /// The paint of an arm or a leg; darker on the far side.
  static Paint limb(MascotColors colors, double u, {bool far = false}) =>
      Paint()
        ..color = far ? colors.farSkin : colors.skin
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7.4 * u
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

  /// How much larger the turtle on four legs is than its shell's units.
  static const double _walkerScale = 1.5;

  /// On four legs, seen from the side and going right, its feet on the
  /// ground at [feet]. [turn] is how far through a stride it is, in
  /// radians; [pace] from 0 where it stands to 1 where it goes. A runner
  /// takes longer strides, bounces and wears a [band].
  static void walker(
    Canvas canvas,
    MascotColors colors,
    double u,
    Offset feet,
    double turn, {
    double pace = 1,
    bool running = false,
    double breath = 0,
    bool blink = false,
    Color? band,
  }) {
    final k = _walkerScale * u;
    final bounce = running
        ? 2.2 * math.sin(2 * turn).abs()
        : 0.7 * pace * math.cos(2 * turn).abs();
    final belly = feet.dy - (9 + bounce + 0.5 * breath) * k;
    final stride = (running ? 6.5 : 4.5) * pace;
    final step = (running ? 3.2 : 2.2) * pace;

    // Diagonal legs go together, as a turtle's do.
    void leg(double x, double phase, {required bool far}) {
      final hip = Offset(feet.dx + x * k, belly - 1 * k);
      final foot = Offset(
        hip.dx + stride * math.sin(phase) * k,
        feet.dy - step * math.max(0.0, math.cos(phase)) * k,
      );
      final paint = Paint()
        ..color = far ? colors.farSkin : colors.skin
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.6 * k
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(hip, foot - Offset(0, 2.4 * k), paint);
    }

    leg(-9.5, turn, far: true);
    leg(11.5, turn + math.pi, far: true);
    // The tail, a short point behind the shell.
    canvas.drawPath(
      Path()
        ..moveTo(feet.dx - 15 * k, belly - 2.6 * k)
        ..lineTo(feet.dx - 21 * k, belly + 0.6 * k)
        ..lineTo(feet.dx - 14 * k, belly + 0.8 * k)
        ..close(),
      Paint()..color = colors.skin,
    );
    leg(-12, turn + math.pi, far: false);
    leg(9, turn, far: false);

    canvas
      ..save()
      ..translate(feet.dx, belly)
      ..scale(k);
    _side(canvas, colors);
    canvas.restore();

    final nod = running
        ? 1.2 * math.sin(2 * turn)
        : 0.6 * pace * math.sin(2 * turn) + 0.4 * breath;
    final neck = Offset(feet.dx + 14 * k, belly - 3 * k);
    final head = Offset(feet.dx + 21 * k, belly - (10.5 + nod) * k);
    canvas.drawLine(
      neck,
      head,
      Paint()
        ..color = colors.skin
        ..strokeWidth = 6 * k
        ..strokeCap = StrokeCap.round,
    );
    Turtle.head(
      canvas,
      colors,
      k * 0.92,
      head,
      up: const Offset(-0.12, -1),
      asleep: blink,
      band: band,
    );
  }

  /// Asleep on the ground, facing right, as the walker stands still: the
  /// shell on the belly, the head laid down ahead of it with closed eyes
  /// and the feet drawn in. [at] is the ground under the middle of the
  /// shell; [breath] from 0 to 1 lifts the shell. [cap] is a night cap.
  static void resting(
    Canvas canvas,
    MascotColors colors,
    double u,
    Offset at, {
    double breath = 0,
    Color? cap,
  }) {
    final k = _walkerScale * u;
    final belly = at.dy - 4.5 * k;
    for (final x in const [-9.5, 9.5]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(at.dx + x * k, at.dy - 1.6 * k),
          width: 9 * k,
          height: 3.6 * k,
        ),
        Paint()..color = colors.farSkin,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(at.dx - 15 * k, belly - 1.2 * k)
        ..lineTo(at.dx - 21 * k, belly + 1.6 * k)
        ..lineTo(at.dx - 14 * k, belly + 1.8 * k)
        ..close(),
      Paint()..color = colors.skin,
    );
    canvas
      ..save()
      ..translate(at.dx, belly)
      ..scale(k, k * (1 + 0.035 * breath));
    _side(canvas, colors);
    canvas.restore();
    final head = Offset(at.dx + 22 * k, belly - 1.5 * k);
    canvas.drawLine(
      Offset(at.dx + 14 * k, belly - 1 * k),
      head,
      Paint()
        ..color = colors.skin
        ..strokeWidth = 6 * k
        ..strokeCap = StrokeCap.round,
    );
    Turtle.head(
      canvas,
      colors,
      k * 0.92,
      head,
      up: const Offset(0.35, -1),
      asleep: true,
      cap: cap,
    );
  }
}
