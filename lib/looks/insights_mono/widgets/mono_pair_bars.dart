import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/mono_tokens.dart';
import 'mono_motion.dart';

/// Two bars a day side by side, such as burned and eaten, growing in once.
class MonoPairBars extends StatelessWidget {
  const MonoPairBars({
    super.key,
    required this.first,
    required this.second,
    required this.firstColor,
    required this.secondColor,
    required this.semantics,
    this.height = 140,
  });

  final List<double?> first;
  final List<double?> second;
  final Color firstColor;
  final Color secondColor;
  final String semantics;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    return Semantics(
      label: semantics,
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: MonoDrawIn(
            duration: const Duration(milliseconds: 900),
            builder: (context, p) => CustomPaint(
              painter: _PairPainter(
                first: first,
                second: second,
                firstColor: firstColor,
                secondColor: secondColor,
                stub: t.fill,
                t: p,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PairPainter extends CustomPainter {
  _PairPainter({
    required this.first,
    required this.second,
    required this.firstColor,
    required this.secondColor,
    required this.stub,
    required this.t,
  });

  final List<double?> first;
  final List<double?> second;
  final Color firstColor;
  final Color secondColor;
  final Color stub;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final n = math.max(first.length, second.length);
    if (n == 0) return;
    final top = [...first, ...second].whereType<double>().fold(0.0, math.max);
    final slot = size.width / n;
    final gap = n > 14 ? 1.0 : 3.0;
    final bar = math.max(1.5, (slot - gap * 3) / 2);
    final radius = Radius.circular(math.min(4, bar / 2));
    void draw(double? v, double x, Color color) {
      if (v == null || v <= 0 || top <= 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, size.height - 3, bar, 3),
            radius,
          ),
          Paint()..color = stub,
        );
        return;
      }
      final h = math.max(3.0, size.height * v / top * t);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, size.height - h, bar, h),
          topLeft: radius,
          topRight: radius,
        ),
        Paint()..color = color,
      );
    }

    for (var i = 0; i < n; i++) {
      final x = i * slot + gap;
      draw(i < first.length ? first[i] : null, x, firstColor);
      draw(i < second.length ? second[i] : null, x + bar + gap, secondColor);
    }
  }

  @override
  bool shouldRepaint(_PairPainter old) =>
      old.t != t || old.first != first || old.second != second;
}
