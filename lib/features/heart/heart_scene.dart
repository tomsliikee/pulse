import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/pulse_look.dart';
import '../../widgets/scene_kit.dart';

/// The figure of the other scenes sitting still under a pale sky, a heart
/// beating beside its chest at [bpm], and the line of a heart monitor behind
/// it. A bright dot draws the line, one spike in the time of one beat, and
/// the line fades behind the dot; with every spike the heart swells and a
/// ring leaves it. Drawn by the app in the colours of the theme. Without a
/// rate the line is flat and the heart rests; it stands still where the
/// system asks for no animations.
class HeartScene extends StatelessWidget {
  const HeartScene({
    super.key,
    required this.bpm,
    this.height = 150,
    this.stage,
  });

  /// The rate the heart beats at; null where nothing was measured.
  final int? bpm;
  final double height;

  /// The height the scene is drawn for, at the bottom; above it is only
  /// its sky. The whole [height] when null.
  final double? stage;

  @override
  Widget build(BuildContext context) => SceneClock(
    builder: (context, seconds) => CustomPaint(
      size: Size(double.infinity, height),
      painter: _HeartPainter(
        bpm: bpm,
        stage: stage,
        scheme: Theme.of(context).colorScheme,
        seconds: seconds,
        mascot: PulseLook.mascotOf(context),
        still: MediaQuery.disableAnimationsOf(context),
      ),
    ),
  );
}

class _HeartPainter extends CustomPainter {
  _HeartPainter({
    required this.bpm,
    required this.stage,
    required this.scheme,
    required this.seconds,
    this.mascot = false,
    required this.still,
  }) : super(repaint: seconds);

  final int? bpm;
  final double? stage;
  final ColorScheme scheme;
  final ValueListenable<double> seconds;

  /// Whether the figure is the turtle.
  final bool mascot;

  /// Whether nothing moves, so the scene has come in already.
  final bool still;

  static const double _tau = 2 * math.pi;

  /// Seconds one breath takes.
  static const double _breath = 4.6;

  /// Where in a beat's stretch of the line its spike stands.
  static const double _spike = 0.5;

  /// How high the line stands at [phase] through one beat, from -1 to 1.
  static double _trace(double phase) {
    double bump(double at, double width, double height) {
      final d = (phase - at) / width;
      return d.abs() >= 1 ? 0 : height * (0.5 + 0.5 * math.cos(d * math.pi));
    }

    return bump(_spike - 0.16, 0.06, 0.14) +
        bump(_spike - 0.035, 0.022, -0.22) +
        bump(_spike, 0.03, 1) +
        bump(_spike + 0.04, 0.025, -0.34) +
        bump(_spike + 0.2, 0.09, 0.22);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final time = seconds.value;
    final full = size;
    size = Size(full.width, math.min(stage ?? full.height, full.height));
    final enter = SceneEntrance.at(time, still: still);
    final sky = Color.lerp(scheme.errorContainer, scheme.surfaceBright, 0.5)!;
    paintSky(
      canvas,
      Offset.zero & full,
      Color.lerp(sky, scheme.errorContainer, 0.5)!,
      Color.lerp(sky, scheme.surfaceBright, 0.5)!,
    );
    canvas.translate(0, full.height - size.height);
    // One hundredth of the height: every length is in these.
    final u = size.height / 100;
    final ground = size.height - 14 * u;
    final centre = size.width * 0.5;

    // One beat is this long on the line. The line stands still, and the dot
    // that draws it passes one beat's stretch in one beat's time.
    final stretch = 64 * u;
    final beats = bpm == null ? 0.0 : time * bpm! / 60;
    double phaseAt(double x) => x / stretch % 1;
    // The dot crosses the scene and a little more, then starts again.
    final lap = size.width + 40 * u;
    final dot = bpm == null ? null : beats * stretch % lap - 20 * u;

    final drop = enter.drop * 26 * u;
    _hills(canvas, size, ground + drop, 24 * u, 0.9, 0.5);
    _hills(canvas, size, ground + drop * 0.6, 13 * u, 1.7, 0.85);
    _line(canvas, size, u, dot, lap, phaseAt, enter.shown);
    canvas.drawLine(
      Offset(8 * u, ground + 3.4 * u),
      Offset(size.width - 8 * u, ground + 3.4 * u),
      Paint()
        ..color = scheme.outlineVariant
        ..strokeWidth = 2.2 * u
        ..strokeCap = StrokeCap.round,
    );

    // How far the dot is through its beat; the heart swells while it draws
    // the spike, and a ring leaves the heart from then on.
    final through = dot == null ? null : phaseAt(dot + lap);
    final passing = through == null
        ? 0.0
        : (1 - ((through - _spike).abs() / 0.14)).clamp(0.0, 1.0);
    enter.fade(
      canvas,
      Offset.zero & size,
      () => _figure(
        canvas,
        u,
        centre,
        ground,
        breath: 0.5 - 0.5 * math.cos(_tau * (time / _breath % 1)),
        beat: Curves.easeOut.transform(passing),
        sinceSpike: through == null ? null : (through - _spike) % 1,
      ),
    );
  }

  /// A row of soft hills that stand still: this figure goes nowhere.
  void _hills(
    Canvas canvas,
    Size size,
    double ground,
    double height,
    double waves,
    double opacity,
  ) {
    final length = size.width / waves;
    // Down to the edge, so a row that is still rising has no gap below it.
    final path = Path()..moveTo(0, size.height);
    for (var x = 0.0; x <= size.width + 4; x += 4) {
      final along = x / length * _tau + waves;
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
          scheme.errorContainer,
          scheme.error,
          0.12,
        )!.withValues(alpha: opacity),
    );
  }

  /// The line of the monitor across the sky. The dot at [dot] draws it and
  /// it fades behind the dot over one [lap]; without a dot it is flat.
  void _line(
    Canvas canvas,
    Size size,
    double u,
    double? dot,
    double lap,
    double Function(double x) phaseAt,
    double shown,
  ) {
    final base = 30 * u;
    double heightAt(double x) => base - _trace(phaseAt(x + lap)) * 20 * u;
    final path = Path()..moveTo(0, base);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * u
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (dot == null) {
      canvas.drawPath(
        path..lineTo(size.width, base),
        stroke..color = scheme.error.withValues(alpha: 0.6 * shown),
      );
      return;
    }
    for (var x = 0.0; x <= size.width + 1; x += 1) {
      path.lineTo(x, heightAt(x));
    }
    if (still) {
      // Nothing draws a line that does not move: it is there as a whole.
      canvas.drawPath(
        path,
        stroke..color = scheme.error.withValues(alpha: 0.6),
      );
      return;
    }
    // Strongest at the dot and gone one lap behind it, where the dot is
    // about to draw again.
    canvas.drawPath(
      path,
      stroke
        ..shader = LinearGradient(
          colors: [
            scheme.error.withValues(alpha: 0),
            scheme.error.withValues(alpha: 0.12 * shown),
            scheme.error.withValues(alpha: 0.8 * shown),
          ],
          stops: const [0, 0.45, 1],
          tileMode: TileMode.repeated,
        ).createShader(Rect.fromLTRB(dot - lap, 0, dot, 1)),
    );
    final at = Offset(dot, heightAt(dot));
    paintGlow(canvas, at, 7 * u, scheme.error.withValues(alpha: 0.6 * shown));
    canvas.drawCircle(
      at,
      1.9 * u,
      Paint()..color = scheme.error.withValues(alpha: shown),
    );
  }

  /// Seen from the front, cross-legged, the hands on the knees.
  void _figure(
    Canvas canvas,
    double u,
    double x,
    double ground, {
    required double breath,
    required double beat,
    required double? sinceSpike,
  }) {
    final pen = FigurePen(canvas, scheme, u, mascot: mascot);
    final hip = Offset(x, ground - 5 * u);
    final neck = hip + Offset(0, -(23 + 1.6 * breath) * u);
    pen.shadow(Offset(x, ground + 3.4 * u), 22);
    for (final side in const [-1.0, 1.0]) {
      pen.line(pen.limb(far: side < 0), [
        hip,
        Offset(x + 18 * side * u, ground - 2 * u),
        Offset(x - 5 * side * u, ground),
      ]);
    }
    pen
      ..body(hip, neck, front: 1)
      ..head(neck + Offset(0, -9.5 * u), neck: neck, front: 1);
    for (final side in const [-1.0, 1.0]) {
      final shoulder = neck + Offset(7 * side * u, 2 * u);
      // The hands rise a little with the shoulders.
      final hand = Offset(x + 17 * side * u, ground - (6 + 0.8 * breath) * u);
      pen.line(pen.limb(), [
        shoulder,
        FigurePen.joint(shoulder, hand, 11 * u, 11 * u, -side),
        hand,
      ]);
    }

    // The heart, on the figure's left and so on the right of the picture.
    final at = neck + Offset(2.2 * u, 8.5 * u);
    // A ring leaves the heart with the spike, and one before it is still
    // on its way.
    if (sinceSpike != null) {
      for (final behind in const [0.0, 0.5]) {
        final age = (sinceSpike + behind) % 1;
        canvas.drawCircle(
          at,
          (6 + 26 * age) * u,
          Paint()
            ..color = scheme.error.withValues(alpha: 0.34 * (1 - age))
            ..style = PaintingStyle.stroke
            ..strokeWidth = (2.2 - 1.4 * age) * u,
        );
      }
    }
    canvas.drawCircle(
      at,
      (9 + 7 * beat) * u,
      Paint()..color = scheme.error.withValues(alpha: 0.10 + 0.14 * beat),
    );
    _heart(canvas, at, (4.6 + 1.5 * beat) * u, scheme.error);
  }

  /// A heart [size] wide and high around [centre].
  void _heart(Canvas canvas, Offset centre, double size, Color color) {
    final half = size / 2;
    final top = centre.dy - half * 0.5;
    canvas.drawPath(
      Path()
        ..moveTo(centre.dx, centre.dy + half)
        ..cubicTo(
          centre.dx - half * 2.1,
          centre.dy - half * 0.2,
          centre.dx - half * 0.9,
          top - half * 1.1,
          centre.dx,
          top + half * 0.1,
        )
        ..cubicTo(
          centre.dx + half * 0.9,
          top - half * 1.1,
          centre.dx + half * 2.1,
          centre.dy - half * 0.2,
          centre.dx,
          centre.dy + half,
        )
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_HeartPainter oldDelegate) =>
      oldDelegate.mascot != mascot ||
      oldDelegate.bpm != bpm ||
      oldDelegate.stage != stage ||
      oldDelegate.still != still ||
      oldDelegate.scheme != scheme;
}
