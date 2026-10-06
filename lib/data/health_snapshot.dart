import 'package:flutter/foundation.dart';

import 'metric_catalog.dart';
import 'models.dart';

/// Everything the app shows, for a window of days ending on [today].
///
/// Index 0 is the oldest day; the last index is [today]. A `null` value means
/// there is no data for that day, which is not the same as zero.
@immutable
class HealthSnapshot {
  const HealthSnapshot({
    required this.today,
    required this.loadedAt,
    required this.dayCount,
    required this.series,
    required this.nights,
    required this.heart,
    required this.workouts,
    required this.entries,
    this.hourly = const {},
  });

  static const int schemaVersion = 1;
  static const int defaultDayCount = 30;

  final DateTime today;
  final DateTime loadedAt;
  final int dayCount;
  final Map<Metric, List<double?>> series;
  final List<SleepNight?> nights;

  /// Ten-minute heart-rate averages per day; an empty list for days without.
  final List<List<HeartSample>> heart;

  /// Oldest first.
  final List<Workout> workouts;

  /// Oldest first.
  final List<HealthEntry> entries;

  /// Hourly totals of yesterday and today for the metrics the store can
  /// total: [hoursPerDay] slots for yesterday followed by the same for today.
  final Map<Metric, List<double?>> hourly;

  static const int hoursPerDay = 24;

  /// The hourly totals of the day at [index], if that day has any.
  List<double?>? hoursOf(Metric metric, int index) {
    final slots = hourly[metric];
    final daysBack = dayCount - 1 - index;
    if (slots == null || daysBack < 0 || daysBack > 1) return null;
    final start = (1 - daysBack) * hoursPerDay;
    final day = slots.sublist(start, start + hoursPerDay);
    return day.any((v) => v != null) ? day : null;
  }

  DateTime dateAt(int index) =>
      DateTime(today.year, today.month, today.day - (dayCount - 1 - index));

  /// The index of [time]'s calendar day, or null outside the window.
  int? indexOf(DateTime time) {
    // Compared in UTC so a daylight-saving change cannot shift the count.
    final daysAgo = DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime.utc(time.year, time.month, time.day)).inDays;
    final index = dayCount - 1 - daysAgo;
    return index >= 0 && index < dayCount ? index : null;
  }

  double? value(Metric metric, int index) => series[metric]?[index];

  List<double?> valuesOf(Metric metric) =>
      series[metric] ?? List<double?>.filled(dayCount, null);

  bool has(Metric metric) => series[metric]?.any((v) => v != null) ?? false;

  /// Index of the most recent day that has a value for [metric].
  int? latestIndex(Metric metric) {
    final values = series[metric];
    if (values == null) return null;
    for (var i = values.length - 1; i >= 0; i--) {
      if (values[i] != null) return i;
    }
    return null;
  }

  List<HealthEntry> entriesOn(int index, EntryKind kind) {
    final day = dateAt(index);
    return [
      for (final entry in entries)
        if (entry.draft.kind == kind &&
            entry.draft.time.year == day.year &&
            entry.draft.time.month == day.month &&
            entry.draft.time.day == day.day)
          entry,
    ];
  }

  Map<String, Object?> toJson() => {
    'version': schemaVersion,
    'today': today.toIso8601String(),
    'loadedAt': loadedAt.toIso8601String(),
    'dayCount': dayCount,
    'series': {
      for (final MapEntry(:key, :value) in series.entries) key.name: value,
    },
    'nights': [for (final night in nights) night?.toJson()],
    'heart': [
      for (final day in heart)
        [
          for (final sample in day) ...[sample.minuteOfDay, sample.bpm],
        ],
    ],
    'workouts': [for (final workout in workouts) workout.toJson()],
    'entries': [for (final entry in entries) entry.toJson()],
    'hourly': {
      for (final MapEntry(:key, :value) in hourly.entries) key.name: value,
    },
  };

  /// Returns null for anything that is not a snapshot of the current schema,
  /// so a damaged or outdated file is ignored instead of trusted.
  static HealthSnapshot? fromJson(Object? json) {
    if (json
        case {
          'version': schemaVersion,
          'today': final String today,
          'loadedAt': final String loadedAt,
          'dayCount': final int dayCount,
          'series': final Map<String, Object?> series,
          'nights': final List<Object?> nights,
          'heart': final List<Object?> heart,
          'workouts': final List<Object?> workouts,
          'entries': final List<Object?> entries,
        }
        when dayCount > 0 && dayCount <= 366) {
      final parsedToday = DateTime.tryParse(today);
      final parsedLoadedAt = DateTime.tryParse(loadedAt);
      if (parsedToday == null || parsedLoadedAt == null) return null;
      if (nights.length != dayCount || heart.length != dayCount) return null;

      final parsedSeries = <Metric, List<double?>>{};
      for (final MapEntry(:key, :value) in series.entries) {
        final metric = Metric.byName(key);
        if (metric == null || value is! List<Object?>) continue;
        if (value.length != dayCount) continue;
        parsedSeries[metric] = [
          for (final v in value)
            if (v is num && metric.accepts(v.toDouble()))
              v.toDouble()
            else
              null,
        ];
      }

      return HealthSnapshot(
        today: parsedToday,
        loadedAt: parsedLoadedAt,
        dayCount: dayCount,
        series: parsedSeries,
        nights: [for (final night in nights) SleepNight.fromJson(night)],
        heart: [for (final day in heart) _heartFromJson(day)],
        workouts: [for (final w in workouts) ?Workout.fromJson(w)],
        entries: [for (final e in entries) ?HealthEntry.fromJson(e)],
        hourly: _hourlyFromJson(json['hourly']),
      );
    }
    return null;
  }

  static Map<Metric, List<double?>> _hourlyFromJson(Object? json) {
    if (json is! Map<String, Object?>) return const {};
    final result = <Metric, List<double?>>{};
    for (final MapEntry(:key, :value) in json.entries) {
      final metric = Metric.byName(key);
      if (metric == null || value is! List<Object?>) continue;
      if (value.length != hoursPerDay * 2) continue;
      result[metric] = [
        for (final v in value)
          if (v is num && metric.accepts(v.toDouble())) v.toDouble() else null,
      ];
    }
    return result;
  }

  static List<HeartSample> _heartFromJson(Object? json) {
    if (json is! List<Object?>) return const [];
    final samples = <HeartSample>[];
    for (var i = 0; i + 1 < json.length; i += 2) {
      if ((json[i], json[i + 1]) case (final int minute, final int bpm)
          when minute >= 0 &&
              minute < 24 * 60 &&
              Metric.heartRate.accepts(bpm.toDouble())) {
        samples.add(HeartSample(minuteOfDay: minute, bpm: bpm));
      }
    }
    return samples;
  }
}
