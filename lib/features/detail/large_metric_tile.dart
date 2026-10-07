import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/formatters.dart';
import '../../app/layout.dart';
import '../../data/health_controller.dart';
import '../../data/metric_catalog.dart';
import '../../data/settings_controller.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/line_chart.dart';
import '../../widgets/pressable.dart';
import '../../widgets/shape_badge.dart';
import '../../widgets/tile_surface.dart';
import 'metric_spec.dart';
import 'metric_tiles.dart';

/// The goal the user set for [metric], in the metric's unit, if it has one.
double? goalOf(Metric metric, SettingsController settings) => switch (metric) {
  Metric.steps => settings.stepGoal.toDouble(),
  Metric.water => settings.waterGoalMl / 1000,
  Metric.sleep => settings.sleepGoalHours,
  _ => null,
};

/// The large form of a tile: the value, a remark, and the last seven days
/// as bars (for a heart rate, the day's curve).
class LargeMetricTile extends StatelessWidget {
  const LargeMetricTile({
    super.key,
    required this.metric,
    required this.title,
    required this.health,
    required this.settings,
    this.dayIndex,
  });

  final Metric metric;
  final String title;

  /// The day whose value is shown. Without it the tile shows today, or the
  /// latest reading of a measurement that is taken now and then.
  final int? dayIndex;
  final HealthController health;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final spec = metric.spec;
    final colors = scheme.tone(spec.tone);
    final neutral = spec.tone == Tone.neutral;
    final snapshot = health.snapshot;
    final day = dayIndex ?? health.todayIndex;
    final TileReading reading = dayIndex == null
        ? tileReading(snapshot, metric)
        : (value: snapshot.value(metric, day), note: null);
    final night = snapshot.nights[day];
    final heart = snapshot.heart[day];
    final inWeek = day - (snapshot.dayCount - 7);
    final goal = goalOf(metric, settings);
    final muted = colors.onContainer.withValues(alpha: 0.72);

    final week = snapshot.valuesOf(metric).sublist(snapshot.dayCount - 7);
    final known = week.whereType<double>().toList();
    final average = known.isEmpty
        ? null
        : known.reduce((a, b) => a + b) / known.length;
    var low = double.infinity;
    var high = 0.0;
    for (final v in known) {
      if (v < low) low = v;
      if (v > high) high = v;
    }

    // Top right: what puts the large number into proportion.
    final String? aside = switch (metric) {
      Metric.heartRate when heart.isNotEmpty => () {
        var min = heart.first.bpm;
        var max = min;
        for (final s in heart) {
          if (s.bpm < min) min = s.bpm;
          if (s.bpm > max) max = s.bpm;
        }
        return '$min bis $max bpm';
      }(),
      Metric.heartRate => null,
      _ when average != null => 'Ø ${metric.formatWithUnit(average)}',
      _ => null,
    };
    final value = reading.value;
    final String? remark = switch (metric) {
      Metric.sleep when night != null =>
        '${formatClock(night.bedtimeMinute)} bis '
            '${formatClock(night.wakeMinute)} · '
            'Score ${night.estimatedScore} (Schätzung)',
      Metric.water when goal != null =>
        '${((value ?? 0) / goal * 100).round()} % von '
            '${metric.formatWithUnit(goal)}',
      _ => reading.note,
    };

    return Pressable(
      pressedScale: 0.97,
      child: TileSurface(
        color: colors.container,
        radius: AppRadii.extraLargeIncreased,
        child: Builder(
          builder: (context) => InkWell(
            onTap: () {
              final origin = globalRectOf(context);
              if (origin != null) openMetric(context, metric, origin);
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ShapeBadge(
                        shape: spec.shape,
                        icon: spec.icon,
                        size: 44,
                        color: neutral
                            ? scheme.secondaryContainer
                            : colors.accent,
                        iconColor: neutral
                            ? scheme.onSecondaryContainer
                            : colors.container,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colors.onContainer,
                          ),
                        ),
                      ),
                      if (aside != null)
                        Text(
                          aside,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: muted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      DefaultTextStyle.merge(
                        style: context.emphasizedTextTheme.headlineLarge
                            ?.copyWith(color: colors.onContainer),
                        child: metricValueOf(metric, value),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        metric.unit,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: muted,
                        ),
                      ),
                      if (remark != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            remark,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: metric == Metric.heartRate
                        ? (heart.length < 2
                              ? const SizedBox.shrink()
                              : LineChart(
                                  values: [
                                    for (final s in heart) s.bpm.toDouble(),
                                  ],
                                  color: colors.accent,
                                  height: null,
                                ))
                        : LayoutBuilder(
                            builder: (context, box) => BarChart(
                              values: week,
                              labels: [
                                for (var i = 0; i < 7; i++)
                                  weekdayShort[snapshot
                                          .dateAt(snapshot.dayCount - 7 + i)
                                          .weekday -
                                      1],
                              ],
                              selectedIndex: inWeek >= 0 ? inWeek : null,
                              color: colors.accent.withValues(alpha: 0.24),
                              selectedColor: colors.accent,
                              goal: goal,
                              // A series that barely varies would otherwise
                              // show bars of the same height.
                              baseline:
                                  high > low &&
                                      (high - low) < high * 0.4 &&
                                      low > 0
                                  ? low - (high - low) * 0.6
                                  : 0,
                              height: box.maxHeight,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
