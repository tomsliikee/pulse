import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../data/models.dart';
import '../../theme/app_motion.dart';

/// A hypnogram: one lane per sleep stage, one rounded block per segment.
///
/// With [interactive], a finger on the chart picks the block under it and a
/// line above says which stage it is, from when to when and for how long;
/// the hours of the night are marked below.
class SleepStagesChart extends StatefulWidget {
  const SleepStagesChart({
    super.key,
    required this.night,
    required this.colors,
    this.height,
    this.interactive = false,
  });

  final SleepNight night;
  final Map<SleepStage, Color> colors;

  /// The height of the lanes. Null lets the chart fill the height it is
  /// given; an [interactive] chart needs it.
  final double? height;
  final bool interactive;

  @override
  State<SleepStagesChart> createState() => _SleepStagesChartState();
}

class _SleepStagesChartState extends State<SleepStagesChart> {
  /// The block under the finger; null until the chart is touched.
  int? _picked;

  SleepNight get night => widget.night;

  @override
  void didUpdateWidget(SleepStagesChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.night.date != night.date) _picked = null;
  }

  void _pick(double dx, double width) {
    if (width <= 0 || night.totalMinutes <= 0) return;
    final minute = dx / width * night.totalMinutes;
    for (var i = 0; i < night.segments.length; i++) {
      final segment = night.segments[i];
      if (minute >= segment.startMinute &&
          minute < segment.startMinute + segment.minutes) {
        if (i != _picked) {
          Haptics.selection();
          setState(() => _picked = i);
        }
        return;
      }
    }
  }

  Widget _lanes() => SizedBox(
    height: widget.height,
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
          colors: widget.colors,
          reveal: reveal.clamp(0, 1).toDouble(),
          picked: _picked,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!widget.interactive) return _lanes();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final label = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final picked = _picked == null ? null : night.segments[_picked!];
    String clock(int minuteOfNight) =>
        formatClock(night.bedtimeMinute + minuteOfNight);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 24,
          child: Text(
            picked == null
                ? l10n.rangeFromTo(clock(0), clock(night.totalMinutes))
                : [
                    switch (picked.stage) {
                      SleepStage.awake => l10n.stageAwake,
                      SleepStage.rem => l10n.stageRem,
                      SleepStage.light => l10n.stageLight,
                      SleepStage.deep => l10n.stageDeep,
                    },
                    l10n.rangeFromTo(
                      clock(picked.startMinute),
                      clock(picked.startMinute + picked.minutes),
                    ),
                    formats.duration(picked.minutes),
                  ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.emphasizedTextTheme.labelLarge?.copyWith(
              color: picked == null ? scheme.onSurfaceVariant : scheme.primary,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, box) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) =>
                _pick(details.localPosition.dx, box.maxWidth),
            onHorizontalDragStart: (details) =>
                _pick(details.localPosition.dx, box.maxWidth),
            onHorizontalDragUpdate: (details) =>
                _pick(details.localPosition.dx, box.maxWidth),
            child: _lanes(),
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, box) {
            // The full hours of the night, thinned out to fit the width.
            final first = (60 - night.bedtimeMinute % 60) % 60;
            final hours = [
              for (var at = first; at <= night.totalMinutes; at += 60) at,
            ];
            final every = (hours.length * 30 / box.maxWidth).ceil().clamp(1, 6);
            return SizedBox(
              height: 16,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < hours.length; i += every)
                    Positioned(
                      left: box.maxWidth * hours[i] / night.totalMinutes,
                      child: FractionalTranslation(
                        translation: const Offset(-0.5, 0),
                        child: Text(
                          '${(night.bedtimeMinute + hours[i]) ~/ 60 % 24}',
                          style: label,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _StagesPainter extends CustomPainter {
  const _StagesPainter({
    required this.night,
    required this.colors,
    required this.reveal,
    this.picked,
  });

  final SleepNight night;
  final Map<SleepStage, Color> colors;
  final double reveal;

  /// The block that stands out; the others are drawn paler.
  final int? picked;

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
    for (var i = 0; i < night.segments.length; i++) {
      final segment = night.segments[i];
      final full = colors[segment.stage];
      if (full == null) continue;
      final color = picked == null || picked == i
          ? full
          : full.withValues(alpha: full.a * 0.4);
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
      oldDelegate.reveal != reveal ||
      oldDelegate.picked != picked;
}
