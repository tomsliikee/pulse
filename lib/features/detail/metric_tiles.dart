import 'package:material_ui/material_ui.dart';

import '../../app/formatters.dart';
import '../../data/health_controller.dart';
import '../../data/health_snapshot.dart';
import '../../data/metric_catalog.dart';
import '../../widgets/animated_count.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/tile_board.dart';
import 'metric_spec.dart';

/// What a tile shows for a metric, and a remark when that is not simply
/// today's value.
typedef TileReading = ({double? value, String? note});

/// Totals and averages are today's. A heart rate is the latest sample of
/// today. Measurements taken now and then (weight, blood pressure, the one
/// resting heart rate a day) show the most recent one with its day, because
/// "nothing today" would hide a value that still holds.
TileReading tileReading(HealthSnapshot snapshot, Metric metric) {
  final today = snapshot.dayCount - 1;
  if (metric == Metric.heartRate) {
    final samples = snapshot.heart[today];
    if (samples.isEmpty) return (value: null, note: null);
    return (
      value: samples.last.bpm.toDouble(),
      note: 'Zuletzt um ${formatClock(samples.last.minuteOfDay)}',
    );
  }
  if (metric.rule == DayRule.last || metric == Metric.restingHeartRate) {
    final index = snapshot.latestIndex(metric);
    if (index == null) return (value: null, note: null);
    return (
      value: snapshot.value(metric, index),
      note: index == today
          ? null
          : formatRelativeDay(snapshot.dateAt(index), snapshot.dateAt(today)),
    );
  }
  return (value: snapshot.value(metric, today), note: null);
}

/// The value of [metric] on the selected day, counting up when it is a whole
/// number and showing "–" when there is none.
///
/// [dayIndex] fixes the day; without it the selected day is shown.
Widget metricValue(HealthController health, Metric metric, {int? dayIndex}) {
  final value = dayIndex == null
      ? health.value(metric)
      : health.valueAt(metric, dayIndex);
  return metricValueOf(metric, value);
}

/// [value] of [metric], counting up when it is a whole number and "–" when
/// there is none.
Widget metricValueOf(Metric metric, double? value) {
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
