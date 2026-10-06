import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../app/haptics.dart';
import '../theme/app_motion.dart';

/// Vertical bars that spring up from the baseline.
///
/// The selected bar is drawn in [selectedColor]; tapping a bar selects it.
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.values,
    required this.color,
    required this.selectedColor,
    this.labels,
    this.selectedIndex,
    this.onSelected,
    this.goal,
    this.baseline = 0,
    this.height = 180,
  });

  /// A null entry is a day without data and draws no bar.
  final List<double?> values;
  final List<String>? labels;
  final int? selectedIndex;
  final ValueChanged<int>? onSelected;
  final Color color;
  final Color selectedColor;

  /// Keeps the scale tall enough to show this value even on low days.
  final double? goal;

  /// The value drawn at the bottom of the chart. Raise it for series whose
  /// values sit close together far from zero, such as a resting heart rate.
  final double baseline;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var top = goal ?? 0;
    for (final value in values) {
      if (value != null && value > top) top = value;
    }
    if (top == 0) top = 1;
    // Headroom so an overshooting spring stays inside the chart.
    final scale = (top - baseline) * 1.12;
    final dense = values.length > 10;
    final gap = dense ? 3.0 : 8.0;
    final labels = this.labels;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSelected == null
                    ? null
                    : () {
                        if (i != selectedIndex) Haptics.selection();
                        onSelected!(i);
                      },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: gap / 2),
                  child: Column(
                    children: [
                      Expanded(
                        child: _Bar(
                          fraction: switch (values[i]) {
                            final value? => (value - baseline) / scale,
                            null => null,
                          },
                          color: i == selectedIndex ? selectedColor : color,
                          radius: dense ? 4 : 12,
                        ),
                      ),
                      if (labels != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          labels[i],
                          maxLines: 1,
                          softWrap: false,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: i == selectedIndex
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: i == selectedIndex
                                ? FontWeight.w700
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.color,
    required this.radius,
  });

  final double? fraction;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SingleMotionBuilder(
      from: 0,
      value: fraction ?? 0,
      motion: AppMotion.spatial,
      builder: (context, current, _) => Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          // A day with data always shows at least a stub; a day
          // without shows nothing.
          heightFactor: current
              .clamp(fraction == null ? 0 : 0.02, 1)
              .toDouble(),
          widthFactor: 1,
          child: MotionBuilder<Color>(
            value: color,
            motion: AppMotion.effects,
            converter: MotionConverter.colorRgb,
            builder: (context, animated, _) => DecoratedBox(
              decoration: BoxDecoration(
                color: animated,
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
