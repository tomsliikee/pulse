import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../../data/models.dart';
import '../../data/sleep_insights.dart';
import '../../theme/app_motion.dart';

/// One floating bar per night, from bedtime at the top to waking at the
/// bottom, so nights that began and ended alike line up.
class SleepScheduleChart extends StatelessWidget {
  const SleepScheduleChart({
    super.key,
    required this.nights,
    required this.color,
    required this.selectedColor,
    this.selectedIndex,
    this.height = 168,
  });

  /// Oldest first; a null entry leaves a gap.
  final List<SleepNight?> nights;
  final Color color;
  final Color selectedColor;
  final int? selectedIndex;
  final double height;

  /// The earliest bedtime and the latest waking on the axis of
  /// [bedtimeOnAxis], or null without any night.
  static (int, int)? span(List<SleepNight?> nights) {
    int? first;
    int? last;
    for (final night in nights) {
      if (night == null) continue;
      final start = bedtimeOnAxis(night);
      final end = start + night.totalMinutes;
      if (first == null || start < first) first = start;
      if (last == null || end > last) last = end;
    }
    return first == null || last == null ? null : (first, last);
  }

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
          painter: _SchedulePainter(
            nights: nights,
            color: color,
            selectedColor: selectedColor,
            selectedIndex: selectedIndex,
            reveal: reveal.clamp(0, 1).toDouble(),
          ),
        ),
      ),
    );
  }
}

class _SchedulePainter extends CustomPainter {
  const _SchedulePainter({
    required this.nights,
    required this.color,
    required this.selectedColor,
    required this.selectedIndex,
    required this.reveal,
  });

  final List<SleepNight?> nights;
  final Color color;
  final Color selectedColor;
  final int? selectedIndex;
  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    final span = SleepScheduleChart.span(nights);
    if (span == null || nights.isEmpty) return;
    final (first, last) = span;
    final minutes = last - first;
    if (minutes <= 0) return;
    final slot = size.width / nights.length;
    final gap = slot > 10 ? 3.0 : 1.0;

    canvas
      ..save()
      ..clipRect(Rect.fromLTWH(0, 0, size.width * reveal, size.height));
    for (var i = 0; i < nights.length; i++) {
      final night = nights[i];
      if (night == null) continue;
      final start = bedtimeOnAxis(night);
      final top = size.height * (start - first) / minutes;
      final bottom =
          size.height * (start + night.totalMinutes - first) / minutes;
      final rect = Rect.fromLTRB(
        slot * i + gap / 2,
        top,
        slot * (i + 1) - gap / 2,
        bottom,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(rect.width / 2)),
        Paint()..color = i == selectedIndex ? selectedColor : color,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SchedulePainter oldDelegate) =>
      oldDelegate.nights != nights ||
      oldDelegate.color != color ||
      oldDelegate.selectedColor != selectedColor ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.reveal != reveal;
}
