import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../widgets/scene_kit.dart';

/// The week as a range of seven hills, Monday on the left under the days'
/// names: each as high as its day's score, the best one with a flag on top. A day without a score
/// is a low rise in a quiet colour.
class WeekScene extends StatelessWidget {
  const WeekScene({
    super.key,
    required this.scores,
    required this.best,
    required this.letters,
    this.height = 160,
  });

  /// Seven, from 1 to 100 or null.
  final List<int?> scores;

  /// Index of the hill that carries the flag.
  final int? best;

  /// What stands under each hill: the days' short names.
  final List<String> letters;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SceneClock(
      rate: 30,
      builder: (context, seconds) => CustomPaint(
        size: Size(double.infinity, height),
        painter: _WeekPainter(
          scores: scores,
          best: best,
          letters: letters,
          scheme: theme.colorScheme,
          letterStyle: theme.textTheme.labelSmall,
          seconds: seconds,
        ),
      ),
    );
  }
}

class _WeekPainter extends CustomPainter {
  _WeekPainter({
    required this.scores,
    required this.best,
    required this.letters,
    required this.scheme,
    required this.letterStyle,
    required this.seconds,
  }) : super(repaint: seconds);

  final List<int?> scores;
  final int? best;
  final List<String> letters;
  final ColorScheme scheme;
  final TextStyle? letterStyle;
  final ValueListenable<double> seconds;

  static const double _tau = 2 * math.pi;

  /// Heights in hundredths of the scene: the line of the letters from the
  /// top, a hill without a score, and what a score of nothing and of a
  /// hundred reach. The letters stand in the sky: the lower left corner is
  /// where the page hangs the week's score over the scene.
  static const double _letters = 9;
  static const double _unknown = 8;
  static const double _lowest = 14;
  static const double _highest = 62;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final time = seconds.value;
    final u = size.height / 100;
    final ground = size.height;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [scheme.primaryContainer, scheme.surfaceBright],
        ).createShader(Offset.zero & size),
    );

    // Two clouds that drift below the letters.
    final cloud = Paint()..color = scheme.surfaceBright.withValues(alpha: 0.8);
    for (final (start, y, speed) in const [
      (0.1, 24.0, 0.012),
      (0.55, 32.0, 0.008),
    ]) {
      final x = ((start + time * speed) % 1.2 - 0.1) * size.width;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, y * u),
            width: 26 * u,
            height: 7 * u,
          ),
          Radius.circular(4 * u),
        ),
        cloud,
      );
      canvas.drawCircle(Offset(x - 4 * u, (y - 3) * u), 5 * u, cloud);
    }

    final step = size.width / scores.length;
    // Wider than its place, so neighbours run into each other like a range.
    final half = step * 0.78;
    double heightOf(int? score) => score == null
        ? _unknown * u
        : (_lowest + (_highest - _lowest) * score / 100) * u;

    // From the back: the odd hills first, so the even ones overlap them.
    for (final parity in const [1, 0]) {
      for (var i = 0; i < scores.length; i++) {
        if (i.isOdd != (parity == 1)) continue;
        final score = scores[i];
        final center = step * (i + 0.5);
        final top = heightOf(score);
        final hill = Path()..moveTo(center - half, ground);
        for (var t = -1.0; t <= 1.0; t += 0.05) {
          hill.lineTo(
            center + half * t,
            ground - top * (0.5 + 0.5 * math.cos(t * math.pi)),
          );
        }
        hill
          ..lineTo(center + half, ground)
          ..close();
        canvas.drawPath(
          hill,
          Paint()
            ..color = score == null
                ? scheme.outlineVariant
                : Color.lerp(
                    scheme.primary,
                    scheme.primaryContainer,
                    i.isOdd ? 0.35 : 0,
                  )!,
        );
      }
    }

    final flagged = best;
    if (flagged != null && scores[flagged] != null) {
      final foot = Offset(
        step * (flagged + 0.5),
        ground - heightOf(scores[flagged]),
      );
      final tip = foot.translate(0, -15 * u);
      canvas.drawLine(
        foot,
        tip,
        Paint()
          ..color = scheme.onSurface
          ..strokeWidth = 1.2 * u
          ..strokeCap = StrokeCap.round,
      );
      // The cloth waves a little at its free end.
      final wave = math.sin(time * _tau / 1.6) * 1.2 * u;
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(tip.dx + 10 * u, tip.dy + 3.5 * u + wave)
          ..lineTo(tip.dx, tip.dy + 7 * u)
          ..close(),
        Paint()..color = scheme.tertiary,
      );
    }

    for (var i = 0; i < scores.length && i < letters.length; i++) {
      final text = TextPainter(
        text: TextSpan(
          text: letters[i],
          style: letterStyle?.copyWith(
            color: i == flagged ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: i == flagged ? FontWeight.w800 : null,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset(
          step * (i + 0.5) - text.width / 2,
          _letters * u - text.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_WeekPainter old) =>
      !listEquals(old.scores, scores) ||
      old.best != best ||
      !listEquals(old.letters, letters) ||
      old.scheme != scheme ||
      old.letterStyle != letterStyle;
}
