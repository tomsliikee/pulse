import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/mono_tokens.dart';
import '../theme/mono_type.dart';
import 'mono_motion.dart';

/// The bands of the recovery gauge: Recover below 40, Pace yourself to 64,
/// Ready to 84 and Go for it from 85.
const List<(double, double)> monoGaugeBands = [
  (0, 0.40),
  (0.40, 0.65),
  (0.65, 0.85),
  (0.85, 1),
];

/// Which of the four bands [percent] lies in.
int monoGaugeBand(int percent) => percent < 40
    ? 0
    : percent < 65
    ? 1
    : percent < 85
    ? 2
    : 3;

/// The recovery as a half circle in four bands. The active band is in full
/// colour, the marker sits on the value and the percentage in the middle.
class MonoGauge extends StatelessWidget {
  const MonoGauge({
    super.key,
    required this.percent,
    required this.labels,
    required this.semantics,
  });

  /// Null where there is no recovery to show.
  final int? percent;

  /// The four band names, from Recover to Go.
  final List<String> labels;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final value = percent;
    return Semantics(
      label: semantics,
      image: true,
      child: ExcludeSemantics(
        child: MonoDrawIn(
          duration: const Duration(milliseconds: 1400),
          builder: (context, p) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 260,
                  height: 134,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _GaugePainter(
                            value: value,
                            color: t.recovery,
                            track: t.recovery,
                            card: t.card,
                            t: p,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: value == null
                                    ? '–'
                                    : '${(value * p).round()}',
                                style: MonoType.number(t, size: 44),
                              ),
                              if (value != null)
                                TextSpan(text: ' %', style: MonoType.unit(t)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 260,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < labels.length; i++)
                        Text(
                          labels[i],
                          style: MonoType.inter(
                            13,
                            18,
                            value != null && monoGaugeBand(value) == i
                                ? FontWeight.w600
                                : FontWeight.w500,
                            value != null && monoGaugeBand(value) == i
                                ? t.ink
                                : t.ink2,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.value,
    required this.color,
    required this.track,
    required this.card,
    required this.t,
  });

  final int? value;
  final Color color;
  final Color track;
  final Color card;
  final double t;

  static const double _gap = 0.05;

  @override
  void paint(Canvas canvas, Size size) {
    const r = 104.0, stroke = 16.0;
    final centre = Offset(size.width / 2, size.height - stroke / 2 - 2);
    final rect = Rect.fromCircle(center: centre, radius: r);
    final active = value == null ? -1 : monoGaugeBand(value!);
    for (var i = 0; i < monoGaugeBands.length; i++) {
      final (a, b) = monoGaugeBands[i];
      // Band after band: each one gets its quarter of the time.
      final k = ((t * 4) - i).clamp(0.0, 1.0);
      if (k <= 0) continue;
      final start = math.pi + math.pi * a + (i > 0 ? _gap / 2 : 0);
      final end = math.pi + math.pi * b - (i < 3 ? _gap / 2 : 0);
      final opacity = i == active ? 1.0 : (value == null ? 0.18 : 0.3);
      canvas.drawArc(
        rect,
        start,
        (end - start) * Curves.easeOutCubic.transform(k),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = color.withValues(alpha: opacity),
      );
    }
    if (value != null) {
      // The marker pops in last.
      final pop = ((t - 0.75) / 0.25).clamp(0.0, 1.0);
      if (pop > 0) {
        final angle = math.pi + math.pi * value! / 100;
        final at = centre + Offset(math.cos(angle), math.sin(angle)) * r;
        final scale = Curves.elasticOut.transform(pop);
        canvas.drawCircle(at, 11 * scale, Paint()..color = card);
        canvas.drawCircle(at, 7.5 * scale, Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.t != t || old.value != value || old.color != color;
}
