import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../theme/app_motion.dart';

/// A smoothed line with a soft fill that draws in from the left.
class LineChart extends StatelessWidget {
  const LineChart({
    super.key,
    required this.values,
    required this.color,
    this.height = 160,
    this.strokeWidth = 4,
  });

  final List<double> values;
  final Color color;

  /// Null lets the chart fill the height it is given.
  final double? height;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: SingleMotionBuilder(
        from: 0,
        value: 1,
        motion: AppMotion.effectsSlow,
        builder: (context, reveal, _) => CustomPaint(
          painter: _LinePainter(
            values: values,
            color: color,
            strokeWidth: strokeWidth,
            reveal: reveal.clamp(0, 1).toDouble(),
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  const _LinePainter({
    required this.values,
    required this.color,
    required this.strokeWidth,
    required this.reveal,
  });

  final List<double> values;
  final Color color;
  final double strokeWidth;
  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    var low = values.first;
    var high = values.first;
    for (final value in values) {
      if (value < low) low = value;
      if (value > high) high = value;
    }
    final range = high - low == 0 ? 1.0 : high - low;
    final inset = strokeWidth * 2;
    final drawHeight = size.height - inset * 2;

    Offset point(int i) => Offset(
      size.width * i / (values.length - 1),
      inset + drawHeight * (1 - (values[i] - low) / range),
    );

    final line = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      final previous = point(i - 1);
      final current = point(i);
      final middle = (previous.dx + current.dx) / 2;
      line.cubicTo(
        middle,
        previous.dy,
        middle,
        current.dy,
        current.dx,
        current.dy,
      );
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas
      ..save()
      ..clipRect(Rect.fromLTWH(0, 0, size.width * reveal, size.height))
      ..drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      )
      ..drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_LinePainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.reveal != reveal;
}
