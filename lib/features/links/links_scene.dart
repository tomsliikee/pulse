import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/pulse_look.dart';
import '../../widgets/scene_kit.dart';

/// What goes together: three marks on a line that ties them, and the
/// figure of the other scenes looking at them through a magnifier. Drawn at
/// the head of the page in the expressive rework.
class LinksScene extends StatelessWidget {
  const LinksScene({super.key, this.height = 150});

  final double height;

  @override
  Widget build(BuildContext context) => SceneClock(
    // A slow sway and a breath: nothing here moves fast.
    rate: 30,
    builder: (context, seconds) => CustomPaint(
      size: Size(double.infinity, height),
      painter: _LinksPainter(
        scheme: Theme.of(context).colorScheme,
        seconds: seconds,
        still: MediaQuery.disableAnimationsOf(context),
        mascot: PulseLook.mascotOf(context),
      ),
    ),
  );
}

class _LinksPainter extends CustomPainter {
  _LinksPainter({
    required this.scheme,
    required this.seconds,
    required this.still,
    required this.mascot,
  }) : super(repaint: seconds);

  final ColorScheme scheme;
  final ValueListenable<double> seconds;
  final bool still;
  final bool mascot;

  static const double _tau = 2 * math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final time = seconds.value;
    final enter = SceneEntrance.at(time, still: still);
    final u = size.height / 100;
    final sky = Color.lerp(scheme.primaryContainer, scheme.surfaceBright, 0.6)!;
    paintSky(canvas, Offset.zero & size, sky, scheme.surfaceContainer);

    final ground = size.height - 14 * u + enter.drop * 26 * u;
    // Soft hills behind, in a tone of the sky.
    final hills = Path()..moveTo(0, size.height);
    for (var x = 0.0; x <= size.width + 6; x += 6) {
      hills.lineTo(
        x,
        ground - (8 + 6 * math.sin(x / size.width * _tau * 1.2 + 0.8)) * u,
      );
    }
    hills
      ..lineTo(size.width, size.height)
      ..close();
    canvas
      ..drawPath(
        hills,
        Paint()..color = Color.lerp(sky, scheme.secondaryContainer, 0.8)!,
      )
      ..drawRect(
        Rect.fromLTRB(0, ground, size.width, size.height),
        Paint()..color = Color.lerp(sky, scheme.secondaryContainer, 1)!,
      );

    // Three marks on a line that sways a little, as if tied together.
    final sway = still ? 0.0 : math.sin(time * _tau / 6);
    final marks = [
      Offset(size.width * 0.12, ground - (26 + 4 * sway) * u),
      Offset(size.width * 0.3, ground - (46 - 5 * sway) * u),
      Offset(size.width * 0.46, ground - (30 + 3 * sway) * u),
    ];
    final line = Path()..moveTo(marks[0].dx, marks[0].dy);
    for (var i = 1; i < marks.length; i++) {
      final from = marks[i - 1];
      final to = marks[i];
      final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2 + 12 * u);
      line.quadraticBezierTo(mid.dx, mid.dy, to.dx, to.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = scheme.primary.withValues(alpha: 0.7 * enter.rise)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * u
        ..strokeCap = StrokeCap.round,
    );
    final colors = [scheme.tertiary, scheme.primary, scheme.secondary];
    for (final (i, mark) in marks.indexed) {
      _flower(canvas, mark, (9 + (i == 1 ? 2 : 0)) * u, colors[i], time + i);
    }

    // The figure on the right looks at them through its magnifier.
    final x = size.width * 0.74;
    final pen = FigurePen(canvas, scheme, u, mascot: mascot);
    final breath = still ? 0.0 : math.sin(time * _tau / 4);
    enter.fade(canvas, Offset.zero & size, () {
      pen.shadow(Offset(x, ground + 3.4 * u), mascot ? 26 : 13);
      final Offset eye;
      final Offset hand;
      if (mascot) {
        pen.walker(Offset(x, ground + 2 * u), 0, pace: 0, breath: breath);
        // The turtle's head sits ahead of its shell, a little raised.
        eye = Offset(x + 33 * u, ground - 29 * u);
        hand = Offset(x + 21 * u, ground - 8 * u);
      } else {
        final hip = Offset(x, ground - 32 * u);
        final neck = hip + Offset(0, -(24 + breath * 0.6) * u);
        final head = neck + Offset(0, -9.5 * u);
        for (final side in const [-1.0, 1.0]) {
          pen.line(pen.limb(far: side < 0), [
            hip,
            Offset(x + 5 * side * u, ground + 2 * u),
          ]);
        }
        pen
          ..line(pen.limb(far: true), [
            neck + Offset(0, 2 * u),
            neck + Offset(-6 * u, 14 * u),
            hip + Offset(-2 * u, 4 * u),
          ])
          ..body(hip, neck)
          ..head(head, neck: neck);
        eye = head + Offset(-12 * u, -1 * u);
        hand = neck + Offset(-12 * u, 8 * u);
        pen.line(pen.limb(), [
          neck + Offset(0, 2 * u),
          neck + Offset(-4 * u, 12 * u),
          hand,
        ]);
      }
      // The magnifier: a handle to the hand, a ring around a pale glass.
      final glass = mascot ? eye + Offset(6 * u, -1 * u) : eye;
      canvas
        ..drawLine(
          hand,
          glass + Offset(2 * u, 6 * u),
          Paint()
            ..color = scheme.onSurfaceVariant
            ..strokeWidth = 2.6 * u
            ..strokeCap = StrokeCap.round,
        )
        ..drawCircle(
          glass,
          7.5 * u,
          Paint()..color = Colors.white.withValues(alpha: 0.45),
        )
        ..drawCircle(
          glass,
          7.5 * u,
          Paint()
            ..color = scheme.primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4 * u,
        );
    });
  }

  /// A small flower of six petals around a pale middle.
  void _flower(Canvas canvas, Offset at, double r, Color color, double time) {
    final paint = Paint()..color = color;
    final turn = still ? 0.0 : time * 0.15;
    for (var k = 0; k < 6; k++) {
      final angle = turn + k * _tau / 6;
      canvas.drawCircle(
        at + Offset(math.cos(angle), math.sin(angle)) * r * 0.55,
        r * 0.5,
        paint,
      );
    }
    canvas.drawCircle(at, r * 0.42, Paint()..color = scheme.surfaceBright);
  }

  @override
  bool shouldRepaint(_LinksPainter oldDelegate) =>
      oldDelegate.mascot != mascot ||
      oldDelegate.still != still ||
      oldDelegate.scheme != scheme;
}
