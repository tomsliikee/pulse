import 'dart:math' as math;

import 'health_snapshot.dart';
import 'models.dart';

const int _minutesPerDay = 24 * 60;

/// Where a value lies against a range.
enum RangeVerdict { below, within, above }

RangeVerdict verdictOf(double value, (double, double) range) => value < range.$1
    ? RangeVerdict.below
    : value > range.$2
    ? RangeVerdict.above
    : RangeVerdict.within;

/// Shares that are commonly given as typical for healthy adults. They are a
/// guide, not a diagnosis: the shares shift with age and differ from night
/// to night.
const Map<SleepStage, (double, double)> typicalStageShare = {
  SleepStage.deep: (0.13, 0.23),
  SleepStage.rem: (0.20, 0.25),
  SleepStage.light: (0.45, 0.60),
  SleepStage.awake: (0, 0.10),
};

/// The share of [stage] in [night]: of the time asleep for the sleep stages,
/// of the whole time in bed for the time awake. Null without stages.
double? stageShare(SleepNight night, SleepStage stage) {
  if (!night.hasStages) return null;
  final whole = stage == SleepStage.awake
      ? night.totalMinutes
      : night.asleepMinutes;
  return whole <= 0 ? null : night.minutesIn(stage) / whole;
}

/// The part of the time in bed that was spent asleep.
double sleepEfficiency(SleepNight night) =>
    night.totalMinutes <= 0 ? 0 : night.asleepMinutes / night.totalMinutes;

/// When the nights of a stretch began and ended, and how much that varied.
class SleepRegularity {
  const SleepRegularity({
    required this.bedtimeMinute,
    required this.bedtimeSpread,
    required this.wakeMinute,
    required this.wakeSpread,
    required this.nights,
  });

  /// Mean minute of the day, like [SleepNight.bedtimeMinute].
  final int bedtimeMinute;

  /// Standard deviation in minutes.
  final int bedtimeSpread;
  final int wakeMinute;
  final int wakeSpread;
  final int nights;
}

/// The bedtime of [night] on an axis that runs through midnight: an evening
/// keeps its minute of the day, a bedtime after midnight counts on from 24:00.
/// So 23:50 and 00:10 are twenty minutes apart.
int bedtimeOnAxis(SleepNight night) => night.bedtimeMinute < _minutesPerDay ~/ 2
    ? night.bedtimeMinute + _minutesPerDay
    : night.bedtimeMinute;

/// Null with fewer than two nights; one night has no regularity.
SleepRegularity? sleepRegularity(Iterable<SleepNight?> nights) {
  final bedtimes = <double>[];
  final wakes = <double>[];
  for (final night in nights) {
    if (night == null) continue;
    final bedtime = bedtimeOnAxis(night);
    bedtimes.add(bedtime.toDouble());
    wakes.add((bedtime + night.totalMinutes).toDouble());
  }
  if (bedtimes.length < 2) return null;
  final (bedtime, bedtimeSpread) = _meanAndSpread(bedtimes);
  final (wake, wakeSpread) = _meanAndSpread(wakes);
  return SleepRegularity(
    bedtimeMinute: bedtime.round() % _minutesPerDay,
    bedtimeSpread: bedtimeSpread.round(),
    wakeMinute: wake.round() % _minutesPerDay,
    wakeSpread: wakeSpread.round(),
    nights: bedtimes.length,
  );
}

(double, double) _meanAndSpread(List<double> values) {
  final mean = values.reduce((a, b) => a + b) / values.length;
  var squares = 0.0;
  for (final value in values) {
    squares += (value - mean) * (value - mean);
  }
  return (mean, math.sqrt(squares / values.length));
}

/// How far the sleep of some nights stayed behind the goal.
class SleepDebt {
  const SleepDebt({required this.minutes, required this.nights});

  /// Never negative: sleeping more than the goal pays debt off, it does not
  /// build up credit.
  final int minutes;

  /// Nights that had data and were counted.
  final int nights;
}

/// The debt over [nights] against [goalHours] per night. Nights without data
/// are left out rather than counted as no sleep.
SleepDebt sleepDebt(Iterable<SleepNight?> nights, double goalHours) {
  final goal = (goalHours * 60).round();
  var missing = 0;
  var counted = 0;
  for (final night in nights) {
    if (night == null) continue;
    missing += goal - night.asleepMinutes;
    counted++;
  }
  return SleepDebt(minutes: math.max(0, missing), nights: counted);
}

/// The heart-rate samples between falling asleep and waking of the night that
/// ends on the day at [index], oldest first. Empty when the snapshot holds no
/// curve for those days.
List<HeartSample> nightHeart(HealthSnapshot snapshot, int index) {
  final night = snapshot.nights[index];
  if (night == null) return const [];
  final end = night.bedtimeMinute + night.totalMinutes;
  // A night belongs to the day it ends on, so it began the evening before
  // whenever it reaches midnight.
  if (end < _minutesPerDay) {
    return [
      for (final sample in snapshot.heart[index])
        if (sample.minuteOfDay >= night.bedtimeMinute &&
            sample.minuteOfDay <= end)
          sample,
    ];
  }
  return [
    if (index > 0)
      for (final sample in snapshot.heart[index - 1])
        if (sample.minuteOfDay >= night.bedtimeMinute) sample,
    for (final sample in snapshot.heart[index])
      if (sample.minuteOfDay <= end - _minutesPerDay) sample,
  ];
}

/// The middle half of [values], from the 25th to the 75th percentile: what is
/// usual for this person. Null with fewer than four values.
(double, double)? ownRange(Iterable<double?> values) {
  final sorted = [for (final value in values) ?value]..sort();
  if (sorted.length < 4) return null;
  double at(double share) {
    final position = (sorted.length - 1) * share;
    final below = position.floor();
    final above = position.ceil();
    return sorted[below] + (sorted[above] - sorted[below]) * (position - below);
  }

  return (at(0.25), at(0.75));
}
