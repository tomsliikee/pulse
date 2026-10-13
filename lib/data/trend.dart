import 'package:flutter/foundation.dart';

import 'health_history.dart';
import 'metric_catalog.dart';
import 'period.dart';

/// One point of a line across a span: a day with a value, or the mean of a
/// month where the span is everything collected.
@immutable
class TrendPoint {
  const TrendPoint({
    required this.day,
    required this.value,
    required this.position,
  });

  /// The day, or the first of the month for a month's mean.
  final DateTime day;
  final double value;

  /// Where the point lies across the span, from 0 to 1 and true to time,
  /// with the middle of the first day half a day in from the edge.
  final double position;
}

int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Where the middle of [day] lies across the span of [view], from 0 to 1.
double trendPosition(PeriodView view, DateTime day, {double days = 1}) =>
    (_daysBetween(view.start, day) + days / 2) /
    (_daysBetween(view.start, view.end) + 1);

/// The line of [metric] across [view]: every day that has a value, and one
/// point a month for everything collected, oldest first. Empty for a single
/// day.
List<TrendPoint> trendPoints({
  required HealthHistory history,
  required Metric metric,
  required PeriodView view,
}) {
  if (view.kind.isDay) return const [];
  final first = dayKey(view.start);
  final last = dayKey(view.end);
  final days = [
    for (final key in history.daysOf(metric))
      if (key >= first && key <= last) dateOfKey(key),
  ];
  if (view.kind != PeriodKind.all) {
    return [
      for (final day in days)
        TrendPoint(
          day: day,
          value: history.value(metric, day)!,
          position: trendPosition(view, day),
        ),
    ];
  }
  final months = <DateTime, List<double>>{};
  for (final day in days) {
    months
        .putIfAbsent(DateTime(day.year, day.month), () => [])
        .add(history.value(metric, day)!);
  }
  return [
    for (final MapEntry(key: month, value: values) in months.entries)
      TrendPoint(
        day: month,
        value: values.reduce((a, b) => a + b) / values.length,
        position: trendPosition(
          view,
          month,
          days: DateTime(month.year, month.month + 1, 0).day.toDouble(),
        ),
      ),
  ];
}

/// How far the last point of [points] lies above the first; null with fewer
/// than two.
double? trendChange(List<TrendPoint> points) =>
    points.length < 2 ? null : points.last.value - points.first.value;

/// The parts of [view] that have a value, newest first, each with its mean:
/// the days of a week, the weeks of a month from Monday to Sunday as far as
/// they lie in it, the months of a year and the years of everything.
List<PeriodBucket> trendRows({
  required HealthHistory history,
  required Metric metric,
  required PeriodView view,
}) {
  var parts = view.buckets;
  if (view.kind == PeriodKind.month) {
    parts = [];
    var from = view.start;
    while (!from.isAfter(view.end)) {
      final sunday = DateTime(
        from.year,
        from.month,
        from.day + 7 - from.weekday,
      );
      final to = sunday.isAfter(view.end) ? view.end : sunday;
      final values = history.between(metric, from, to);
      parts.add(
        PeriodBucket(
          start: from,
          end: to,
          value: values.isEmpty
              ? null
              : values.reduce((a, b) => a + b) / values.length,
        ),
      );
      from = DateTime(to.year, to.month, to.day + 1);
    }
  }
  return [
    for (final part in parts.reversed)
      if (part.value != null) part,
  ];
}
