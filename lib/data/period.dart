import 'package:flutter/foundation.dart';

import 'health_history.dart';
import 'metric_catalog.dart';

/// The time spans the detail page can show.
enum PeriodKind {
  today,
  yesterday,
  week,
  month,
  year,
  all;

  /// A single day rather than a span of days.
  bool get isDay => this == today || this == yesterday;

  /// Whether earlier spans of this kind can be paged through.
  bool get pages => this == week || this == month || this == year;
}

/// One bar of a period: a day, a month or a year. [value] is null when the
/// bar's span has no data.
@immutable
class PeriodBucket {
  const PeriodBucket({required this.start, required this.end, this.value});

  /// First and last day the bar covers, both inclusive.
  final DateTime start;
  final DateTime end;
  final double? value;
}

/// What the detail page shows for one metric and one span.
@immutable
class PeriodView {
  const PeriodView({
    required this.kind,
    required this.start,
    required this.end,
    required this.buckets,
    required this.headline,
    required this.previous,
    required this.canGoBack,
    required this.canGoForward,
  });

  final PeriodKind kind;

  /// First and last day of the span, both inclusive.
  final DateTime start;
  final DateTime end;

  /// Empty for a single day; its bars come from hourly data, if any.
  final List<PeriodBucket> buckets;

  /// The day's value for a single day, otherwise the average per day over
  /// the days that have data. Null without any data.
  final double? headline;

  /// [headline] of the span directly before this one, for comparison.
  final double? previous;
  final bool canGoBack;
  final bool canGoForward;
}

/// The mean of the days that have data. A day without a measurement is
/// unknown, not zero, and must not pull the average down.
double? _mean(List<double> values) =>
    values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;

DateTime _day(DateTime date, [int shift = 0]) =>
    DateTime(date.year, date.month, date.day + shift);

(DateTime, DateTime) _span(PeriodKind kind, DateTime today, int offset) {
  switch (kind) {
    case PeriodKind.today:
      return (_day(today, -offset), _day(today, -offset));
    case PeriodKind.yesterday:
      return (_day(today, -1 - offset), _day(today, -1 - offset));
    case PeriodKind.week:
      // Weeks run from Monday to Sunday.
      final monday = _day(today, 1 - today.weekday - 7 * offset);
      return (monday, _day(monday, 6));
    case PeriodKind.month:
      final first = DateTime(today.year, today.month - offset);
      return (first, DateTime(first.year, first.month + 1, 0));
    case PeriodKind.year:
      return (
        DateTime(today.year - offset),
        DateTime(today.year - offset, 12, 31),
      );
    case PeriodKind.all:
      final first = today.year - HistoryArchive.retentionYears + 1;
      return (DateTime(first), DateTime(today.year, 12, 31));
  }
}

double? _average(
  HealthHistory history,
  Metric metric,
  DateTime start,
  DateTime end,
) => _mean(history.between(metric, start, end));

/// Builds the view of [metric] for the span of [kind] that lies [offset]
/// spans before the one containing [today] (0 is the current span).
PeriodView buildPeriod({
  required HealthHistory history,
  required Metric metric,
  required PeriodKind kind,
  required DateTime today,
  int offset = 0,
}) {
  final (start, end) = _span(kind, today, offset);
  final (previousStart, previousEnd) = _span(kind, today, offset + 1);
  final first = history.firstDay(metric);

  final buckets = <PeriodBucket>[];
  switch (kind) {
    case PeriodKind.today || PeriodKind.yesterday:
      break;
    case PeriodKind.week || PeriodKind.month:
      for (var day = start; !day.isAfter(end); day = _day(day, 1)) {
        buckets.add(
          PeriodBucket(start: day, end: day, value: history.value(metric, day)),
        );
      }
    case PeriodKind.year:
      for (var month = 1; month <= 12; month++) {
        final from = DateTime(start.year, month);
        final to = DateTime(start.year, month + 1, 0);
        buckets.add(
          PeriodBucket(
            start: from,
            end: to,
            // The average per day, so a month that has only just begun does
            // not look smaller than a full one.
            value: _average(history, metric, from, to),
          ),
        );
      }
    case PeriodKind.all:
      // Starts with the first year that has data, not with ten empty bars.
      final firstYear = first == null
          ? today.year
          : (first.year < start.year ? start.year : first.year);
      for (var year = firstYear; year <= today.year; year++) {
        final from = DateTime(year);
        final to = DateTime(year, 12, 31);
        buckets.add(
          PeriodBucket(
            start: from,
            end: to,
            value: _average(history, metric, from, to),
          ),
        );
      }
  }

  return PeriodView(
    kind: kind,
    start: kind == PeriodKind.all && buckets.isNotEmpty
        ? buckets.first.start
        : start,
    end: end,
    buckets: buckets,
    headline: kind.isDay
        ? history.value(metric, start)
        : _average(history, metric, start, end),
    previous: switch (kind) {
      PeriodKind.all => null,
      _ when kind.isDay => history.value(metric, previousStart),
      _ => _average(history, metric, previousStart, previousEnd),
    },
    canGoBack: kind.pages && first != null && first.isBefore(start),
    canGoForward: kind.pages && offset > 0,
  );
}
