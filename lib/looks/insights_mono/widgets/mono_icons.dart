import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// The icon of Longevity: the age ring in small, five arcs with air between
/// them and the gap at the top, where the years start.
class MonoLongevityIcon extends StatelessWidget {
  const MonoLongevityIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final icon = IconTheme.of(context);
    final size = icon.size ?? 24;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(icon.color ?? const Color(0xFF000000)),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.13;
    final rect = Offset.zero & size;
    final arcs = rect.deflate(stroke / 2 + size.width * 0.06);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    const n = 5;
    const top = 0.9;
    final cap = stroke / arcs.width;
    const gap = 0.42;
    final sweep = (2 * math.pi - top - gap * (n - 1)) / n - cap;
    var start = -math.pi / 2 + top / 2 + cap / 2;
    for (var i = 0; i < n; i++) {
      canvas.drawArc(arcs, start, sweep, false, paint);
      start += sweep + cap + gap;
    }
    // The hand at the top: a dot where the ring begins.
    canvas.drawCircle(
      Offset(size.width / 2, arcs.top),
      stroke * 0.62,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color;
}
