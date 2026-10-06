import 'package:material_ui/material_ui.dart';

import '../../data/health_controller.dart';
import '../../data/metric_catalog.dart';
import '../../widgets/animated_count.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/tile_board.dart';
import 'metric_spec.dart';

/// The value of [metric] on the selected day, counting up when it is a whole
/// number and showing "–" when there is none.
///
/// [dayIndex] fixes the day; without it the selected day is shown.
Widget metricValue(HealthController health, Metric metric, {int? dayIndex}) {
  final value = dayIndex == null
      ? health.value(metric)
      : health.valueAt(metric, dayIndex);
  if (value != null && metric.digits == 0) {
    return AnimatedCount(value: value.round());
  }
  return Text(metric.format(value), maxLines: 1);
}

/// A half-width tile with the large value of [metric]; opens its detail page.
BoardTile metricTile(
  BuildContext context,
  HealthController health,
  Metric metric, {
  Widget? footer,
  String? title,
  int? dayIndex,
}) {
  final spec = metric.spec;
  return BoardTile(
    id: metric.name,
    span: TileSpan.half,
    height: 176,
    child: MetricCard(
      label: title ?? spec.title,
      value: metricValue(health, metric, dayIndex: dayIndex),
      unit: metric.unit,
      icon: spec.icon,
      shape: spec.shape,
      tone: spec.tone,
      footer: footer,
      onTap: (origin) => openMetric(context, metric, origin),
    ),
  );
}

/// A compact tile for [metric]; opens its detail page.
BoardTile statTile(
  BuildContext context,
  HealthController health,
  Metric metric, {
  TileSpan span = TileSpan.half,
  String? title,
}) {
  final spec = metric.spec;
  return BoardTile(
    id: metric.name,
    span: span,
    height: 132,
    child: StatTile(
      label: title ?? spec.title,
      value: span == TileSpan.third
          ? metric.format(health.value(metric))
          : metric.formatWithUnit(health.value(metric)),
      icon: spec.icon,
      shape: spec.shape,
      tone: spec.tone,
      onTap: (origin) => openMetric(context, metric, origin),
    ),
  );
}
