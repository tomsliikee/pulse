import 'health_snapshot.dart';
import 'metric_catalog.dart';
import 'models.dart';

/// One reading as it came from the health store, already in the catalog's
/// unit for its metric.
class RawSample {
  const RawSample(this.metric, this.time, this.value);

  final Metric metric;
  final DateTime time;
  final double value;
}

class RawSleepSession {
  const RawSleepSession(this.start, this.end);

  final DateTime start;
  final DateTime end;
}

class RawSleepStage {
  const RawSleepStage(this.stage, this.start, this.end);

  final SleepStage stage;
  final DateTime start;
  final DateTime end;
}

/// Everything read from the health store for one snapshot.
class RawReadings {
  const RawReadings({
    this.samples = const [],
    this.dailyTotals = const {},
    this.sleepSessions = const [],
    this.sleepStages = const [],
    this.workouts = const [],
    this.entries = const [],
    this.hourlyTotals = const {},
  });

  final List<RawSample> samples;

  /// Per-day totals the store aggregated itself, keyed by the day they belong
  /// to. They win over [samples], because the store removes the overlap
  /// between sources (phone and watch both count the same steps).
  final Map<Metric, Map<DateTime, double>> dailyTotals;
  final List<RawSleepSession> sleepSessions;
  final List<RawSleepStage> sleepStages;
  final List<Workout> workouts;
  final List<HealthEntry> entries;

  /// Totals per hour, keyed by the start of the hour. Only yesterday and
  /// today are used.
  final Map<Metric, Map<DateTime, double>> hourlyTotals;
}

const int _heartBucketMinutes = 10;

/// Turns raw readings into the snapshot the app shows. Pure, so it can be
/// tested without a device.
HealthSnapshot buildSnapshot({
  required DateTime now,
  required RawReadings raw,
  int dayCount = HealthSnapshot.defaultDayCount,
}) {
  final today = DateTime(now.year, now.month, now.day);
  // Only used for its date arithmetic while the real lists are built.
  final frame = HealthSnapshot(
    today: today,
    loadedAt: now,
    dayCount: dayCount,
    series: const {},
    nights: const [],
    heart: const [],
    workouts: const [],
    entries: const [],
  );

  final readings = <Metric, List<List<double>>>{};
  final sorted = [...raw.samples]..sort((a, b) => a.time.compareTo(b.time));
  for (final sample in sorted) {
    final index = frame.indexOf(sample.time);
    if (index == null || !sample.metric.accepts(sample.value)) continue;
    readings
        .putIfAbsent(
          sample.metric,
          () => List.generate(dayCount, (_) => <double>[]),
        )[index]
        .add(sample.value);
  }

  final series = <Metric, List<double?>>{
    for (final MapEntry(key: metric, value: days) in readings.entries)
      metric: [for (final day in days) metric.combine(day)],
  };

  for (final MapEntry(key: metric, value: totals) in raw.dailyTotals.entries) {
    final values = List<double?>.filled(dayCount, null);
    for (final MapEntry(key: day, value: total) in totals.entries) {
      final index = frame.indexOf(day);
      if (index == null || !metric.accepts(total)) continue;
      values[index] = (values[index] ?? 0) + total;
    }
    series[metric] = values;
  }

  final nights = _nights(frame, raw);
  series[Metric.sleep] = [
    for (final night in nights) night == null ? null : night.asleepMinutes / 60,
  ];

  final entries = [
    for (final entry in raw.entries)
      if (frame.indexOf(entry.draft.time) != null) entry,
  ]..sort((a, b) => a.draft.time.compareTo(b.draft.time));
  _addNutrition(frame, entries, series);

  final workouts = [
    for (final workout in raw.workouts)
      if (frame.indexOf(workout.start) != null) workout,
  ]..sort((a, b) => a.start.compareTo(b.start));

  return HealthSnapshot(
    today: today,
    loadedAt: now,
    dayCount: dayCount,
    series: series,
    nights: nights,
    heart: _heart(frame, sorted),
    workouts: workouts,
    entries: entries,
    hourly: _hourly(today, raw.hourlyTotals),
  );
}

Map<Metric, List<double?>> _hourly(
  DateTime today,
  Map<Metric, Map<DateTime, double>> totals,
) {
  const hours = HealthSnapshot.hoursPerDay;
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  final result = <Metric, List<double?>>{};
  for (final MapEntry(key: metric, value: byHour) in totals.entries) {
    final slots = List<double?>.filled(hours * 2, null);
    for (final MapEntry(key: hour, :value) in byHour.entries) {
      final day = DateTime(hour.year, hour.month, hour.day);
      final offset = day == today
          ? hours
          : day == yesterday
          ? 0
          : null;
      if (offset == null || !metric.accepts(value)) continue;
      slots[offset + hour.hour] = (slots[offset + hour.hour] ?? 0) + value;
    }
    if (slots.any((v) => v != null)) result[metric] = slots;
  }
  return result;
}

List<List<HeartSample>> _heart(HealthSnapshot frame, List<RawSample> sorted) {
  final buckets = List.generate(frame.dayCount, (_) => <int, List<double>>{});
  for (final sample in sorted) {
    if (sample.metric != Metric.heartRate) continue;
    final index = frame.indexOf(sample.time);
    if (index == null || !Metric.heartRate.accepts(sample.value)) continue;
    final minute = sample.time.hour * 60 + sample.time.minute;
    final bucket = minute - minute % _heartBucketMinutes;
    buckets[index].putIfAbsent(bucket, () => []).add(sample.value);
  }
  return [
    for (final day in buckets)
      [
        for (final minute in day.keys.toList()..sort())
          HeartSample(
            minuteOfDay: minute,
            bpm: (day[minute]!.reduce((a, b) => a + b) / day[minute]!.length)
                .round(),
          ),
      ],
  ];
}

List<SleepNight?> _nights(HealthSnapshot frame, RawReadings raw) {
  final nights = List<SleepNight?>.filled(frame.dayCount, null);
  for (final session in raw.sleepSessions) {
    final total = session.end.difference(session.start).inMinutes;
    // A night belongs to the day it ends on. Sessions longer than a day are
    // faulty records.
    final index = frame.indexOf(session.end);
    if (index == null || total <= 0 || total > 24 * 60) continue;
    // Several sessions can end on one day (a nap); the longest is the night.
    if ((nights[index]?.totalMinutes ?? 0) >= total) continue;

    final segments = <SleepSegment>[];
    for (final stage in raw.sleepStages) {
      if (stage.start.isBefore(session.start) ||
          stage.end.isAfter(session.end)) {
        continue;
      }
      final minutes = stage.end.difference(stage.start).inMinutes;
      if (minutes <= 0) continue;
      segments.add(
        SleepSegment(
          stage: stage.stage,
          startMinute: stage.start.difference(session.start).inMinutes,
          minutes: minutes,
        ),
      );
    }
    segments.sort((a, b) => a.startMinute.compareTo(b.startMinute));

    nights[index] = SleepNight(
      date: frame.dateAt(index),
      bedtimeMinute: session.start.hour * 60 + session.start.minute,
      totalMinutes: total,
      segments: segments,
    );
  }
  return nights;
}

/// Meals are stored as entries; their daily sums are what the charts show.
void _addNutrition(
  HealthSnapshot frame,
  List<HealthEntry> entries,
  Map<Metric, List<double?>> series,
) {
  final parts = <Metric, double? Function(EntryDraft)>{
    Metric.energyIntake: (d) => d.amount,
    Metric.carbs: (d) => d.carbs,
    Metric.protein: (d) => d.protein,
    Metric.fat: (d) => d.fat,
    Metric.fiber: (d) => d.fiber,
    Metric.sugar: (d) => d.sugar,
  };
  for (final entry in entries) {
    if (entry.draft.kind != EntryKind.meal) continue;
    final index = frame.indexOf(entry.draft.time);
    if (index == null) continue;
    for (final MapEntry(key: metric, value: read) in parts.entries) {
      final value = read(entry.draft);
      if (value == null || !metric.accepts(value)) continue;
      final values = series.putIfAbsent(
        metric,
        () => List<double?>.filled(frame.dayCount, null),
      );
      values[index] = (values[index] ?? 0) + value;
    }
  }
}

/// The minutes covered by [intervals], per hour and keyed by the start of
/// the hour. Time that several intervals cover counts once, so two sources
/// recording the same activity do not double it.
Map<DateTime, double> minutesByHour(List<(DateTime, DateTime)> intervals) {
  final sorted = [
    for (final interval in intervals)
      if (interval.$2.isAfter(interval.$1)) interval,
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  final minutes = <DateTime, double>{};
  DateTime? covered;
  for (final (start, end) in sorted) {
    var from = covered != null && covered.isAfter(start) ? covered : start;
    if (!end.isAfter(from)) continue;
    covered = end;
    while (from.isBefore(end)) {
      final hour = DateTime(from.year, from.month, from.day, from.hour);
      final next = DateTime(from.year, from.month, from.day, from.hour + 1);
      final to = next.isBefore(end) ? next : end;
      minutes[hour] =
          (minutes[hour] ?? 0) +
          to.difference(from).inMilliseconds / Duration.millisecondsPerMinute;
      from = to;
    }
  }
  return minutes;
}

/// [fresh] with the heart rate of the days before [from] taken from
/// [previous]. Those days were not read again: their samples cannot change
/// any more, and a wearable writes thousands per day.
HealthSnapshot keepHeartBefore(
  DateTime from, {
  required HealthSnapshot fresh,
  required HealthSnapshot previous,
}) {
  final heart = [...fresh.heart];
  final average = [...fresh.valuesOf(Metric.heartRate)];
  for (var i = 0; i < fresh.dayCount; i++) {
    final day = fresh.dateAt(i);
    if (!day.isBefore(from)) break;
    final kept = previous.indexOf(day);
    if (kept == null) continue;
    heart[i] = previous.heart[kept];
    average[i] = previous.value(Metric.heartRate, kept);
  }
  return HealthSnapshot(
    today: fresh.today,
    loadedAt: fresh.loadedAt,
    dayCount: fresh.dayCount,
    series: {
      ...fresh.series,
      if (average.any((v) => v != null)) Metric.heartRate: average,
    },
    nights: fresh.nights,
    heart: heart,
    workouts: fresh.workouts,
    entries: fresh.entries,
    hourly: fresh.hourly,
  );
}
