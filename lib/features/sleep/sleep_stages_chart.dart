import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../../data/models.dart';
import '../../theme/app_motion.dart';

/// A hypnogram: one lane per sleep stage, one rounded block per segment.
class SleepStagesChart extends StatelessWidget {
  const SleepStagesChart({
    super.key,
    required this.night,
    required this.colors,
    this.height,
  });

  final SleepNight night;
  final Map<SleepStage, Color> colors;

  /// Null lets the chart fill the height it is given.
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: SingleMotionBuilder(
        // Redraw from the left for every night.
        key: ValueKey(night.date),
        from: 0,
        value: 1,
        motion: AppMotion.effectsSlow,
        builder: (context, reveal, _) => CustomPaint(
          painter: _StagesPainter(
            night: night,
            colors: colors,
            reveal: reveal.clamp(0, 1).toDouble(),
          ),
        ),
      ),
    );
  }
}

class _StagesPainter extends CustomPainter {
  const _StagesPainter({
    required this.night,
    required this.colors,
    required this.reveal,
  });

  final SleepNight night;
  final Map<SleepStage, Color> colors;
  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    final total = night.totalMinutes;
    if (total == 0) return;
    const lanes = SleepStage.values;
    final laneHeight = size.height / lanes.length;
    final blockHeight = laneHeight - 8;

    canvas
      ..save()
      ..clipRect(Rect.fromLTWH(0, 0, size.width * reveal, size.height));
    for (final segment in night.segments) {
      final color = colors[segment.stage];
      if (color == null) continue;
      final left = size.width * segment.startMinute / total;
      final width = size.width * segment.minutes / total;
      final top = laneHeight * lanes.indexOf(segment.stage) + 4;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, width, blockHeight).deflate(0.75),
          const Radius.circular(8),
        ),
        Paint()..color = color,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StagesPainter oldDelegate) =>
      oldDelegate.night != night ||
      oldDelegate.colors != colors ||
      oldDelegate.reveal != reveal;
}
