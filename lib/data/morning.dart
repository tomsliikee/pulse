import 'dart:math' as math;

import 'day_insights.dart';
import 'metric_catalog.dart';
import 'models.dart';
import 'recovery.dart';

/// How long after getting up the morning lasts.
const Duration morningLasts = Duration(hours: 3);

/// The morning of a day without a recorded night.
const int _plainFromHour = 4;
const int _plainUntilHour = 12;

/// The stretch of a day in which the app says good morning by itself.
class MorningWindow {
  const MorningWindow(this.from, this.until, {required this.fromNight});

  final DateTime from;
  final DateTime until;

  /// Whether the stretch starts where the night ended, and is not the plain
  /// morning of a day without one.
  final bool fromNight;

  bool holds(DateTime now) => !now.isBefore(from) && now.isBefore(until);
}

/// The morning of the day of [now]: from the end of the night that ended on
/// it for [morningLasts], or from four to noon where the [nights] (oldest
/// first) hold none for the day.
MorningWindow morningWindow(List<SleepNight> nights, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final night = nightOn(nights, today);
  if (night == null) {
    return MorningWindow(
      today.add(const Duration(hours: _plainFromHour)),
      today.add(const Duration(hours: _plainUntilHour)),
      fromNight: false,
    );
  }
  final woke = today.add(Duration(minutes: night.wakeMinute));
  return MorningWindow(woke, woke.add(morningLasts), fromNight: true);
}

/// The readings of a night that are worth a word when they are unusual.
const List<Metric> morningVitals = [
  Metric.heartRateVariability,
  Metric.restingHeartRate,
  Metric.respiratoryRate,
  Metric.oxygenSaturation,
  Metric.skinTemperature,
];

/// A reading that lies outside what is usual for this person.
class VitalDeviation {
  const VitalDeviation({
    required this.metric,
    required this.value,
    required this.usual,
  });

  final Metric metric;
  final double value;

  /// The own average of the month before.
  final double usual;

  bool get above => value > usual;
}

const int _usualDays = 30;
const int _daysAtLeast = 5;

/// Standard deviations from the own average at which a reading is unusual.
const double _unusualFrom = 1.5;

/// The least that counts as the spread of [metric] around [mean]: a
/// twentieth of the average as in the recovery, but a fixed amount for the
/// two readings whose scale does not start at zero.
double _leastSpread(Metric metric, double mean) => switch (metric) {
  Metric.oxygenSaturation => 1,
  Metric.skinTemperature => 0.3,
  _ => mean.abs() * 0.05,
};

/// The [morningVitals] of [day] that lie further from the own average of
/// the month before than is usual. A rule of the app, not a diagnosis.
List<VitalDeviation> vitalDeviations(DayValue valueOf, DateTime day) {
  final found = <VitalDeviation>[];
  for (final metric in morningVitals) {
    final value = valueOf(metric, day);
    if (value == null) continue;
    final before = [
      for (var back = _usualDays; back >= 1; back--)
        ?valueOf(metric, DateTime(day.year, day.month, day.day - back)),
    ];
    if (before.length < _daysAtLeast) continue;
    final mean = before.reduce((a, b) => a + b) / before.length;
    var spread = 0.0;
    for (final other in before) {
      spread += (other - mean) * (other - mean);
    }
    // Readings that hardly differ would make every small change an unusual
    // one, so the spread has a floor.
    final deviation = math.max(
      math.sqrt(spread / before.length),
      _leastSpread(metric, mean),
    );
    if (deviation == 0) continue;
    if ((value - mean).abs() >= _unusualFrom * deviation) {
      found.add(VitalDeviation(metric: metric, value: value, usual: mean));
    }
  }
  return found;
}

/// How hard the day should be.
enum DayEffort { easy, normal, push }

/// Days before today whose workouts count as recent load.
const int _loadDays = 3;

/// The share of the sleep goal below which a night alone says: take it easy.
const double _shortNight = 0.75;

/// What the body is up to on [day], from how rested it starts and on how
/// many of the three days before there was a workout. Null where neither
/// the recovery nor a night is known. A rule of the app and not validated.
DayEffort? effortFor({
  required DateTime day,
  required Recovery recovery,
  required List<Workout> workouts,
}) {
  final trained = <int>{};
  for (final workout in workouts.reversed) {
    final start = DateTime(
      workout.start.year,
      workout.start.month,
      workout.start.day,
    );
    final back = DateTime(
      day.year,
      day.month,
      day.day,
    ).difference(start).inHours;
    // Hours, rounded to days, so a change of the clocks does not shift one.
    final days = (back / 24).round();
    if (days > _loadDays) break;
    if (days >= 1) trained.add(days);
  }
  switch (recovery.zone) {
    case RecoveryZone.red:
      return DayEffort.easy;
    case RecoveryZone.yellow:
      // Two days of training in a row on a middling recovery are enough.
      return trained.containsAll(const [1, 2])
          ? DayEffort.easy
          : DayEffort.normal;
    case RecoveryZone.green:
      return trained.length == _loadDays ? DayEffort.normal : DayEffort.push;
    case null:
      final night = recovery.parts[RecoveryPart.sleep];
      if (night == null) return null;
      return night.share < _shortNight ? DayEffort.easy : DayEffort.normal;
  }
}
