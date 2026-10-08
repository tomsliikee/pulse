import 'dart:math' as math;

import 'day_insights.dart';
import 'metric_catalog.dart';
import 'models.dart';

/// What the recovery of a day is made of, and the most each part can give.
/// The readings are those a recovery is commonly judged by; the weights are
/// this app's own.
enum RecoveryPart {
  variability(50),
  restingPulse(20),
  sleep(20),
  breathing(10);

  const RecoveryPart(this.points);

  final int points;

  /// The metric the part reads; null for the night.
  Metric? get metric => switch (this) {
    RecoveryPart.variability => Metric.heartRateVariability,
    RecoveryPart.restingPulse => Metric.restingHeartRate,
    RecoveryPart.breathing => Metric.respiratoryRate,
    RecoveryPart.sleep => null,
  };
}

enum RecoveryZone {
  red,
  yellow,
  green;

  static const int yellowFrom = 34;
  static const int greenFrom = 67;

  static RecoveryZone of(int percent) => percent >= greenFrom
      ? RecoveryZone.green
      : percent >= yellowFrom
      ? RecoveryZone.yellow
      : RecoveryZone.red;
}

/// One part of a recovery: what was measured, what it is set against, and
/// how much of the part that gave, from 0 to 1.
class RecoveryReading {
  const RecoveryReading({
    required this.value,
    required this.usual,
    required this.share,
  });

  /// The reading of the day; for the night, the minutes asleep.
  final double value;

  /// The own average of the month before; for the night, the minutes aimed
  /// at.
  final double usual;
  final double share;
}

/// How rested the body starts a day, from 0 to 100, from the readings of the
/// night before set against what is usual for this person. An estimate of
/// the app and not a measurement.
class Recovery {
  const Recovery(this.parts);

  final Map<RecoveryPart, RecoveryReading> parts;

  /// Null where neither the variability nor the resting pulse is known: the
  /// night alone says too little. Parts that are missing are left out and
  /// the others scaled up to make the hundred.
  int? get total {
    if (!parts.containsKey(RecoveryPart.variability) &&
        !parts.containsKey(RecoveryPart.restingPulse)) {
      return null;
    }
    var earned = 0.0;
    var possible = 0;
    for (final MapEntry(key: part, value: reading) in parts.entries) {
      earned += part.points * reading.share;
      possible += part.points;
    }
    return (earned / possible * 100).round().clamp(0, 100);
  }

  RecoveryZone? get zone => switch (total) {
    final total? => RecoveryZone.of(total),
    null => null,
  };
}

const int _usualDays = 30;

/// Days with a reading the usual is taken from at least.
const int _daysAtLeast = 5;

/// What a reading at its own average gives, and what one standard deviation
/// to the better side adds.
const double _atUsual = 0.6;
const double _perDeviation = 0.2;

/// The recovery on [day], with the [nights] the app knows (oldest first) and
/// the hours of sleep aimed at.
Recovery recoveryOf({
  required DateTime day,
  required DayValue valueOf,
  required List<SleepNight> nights,
  required double sleepGoalHours,
}) {
  final parts = <RecoveryPart, RecoveryReading>{};
  for (final part in RecoveryPart.values) {
    final metric = part.metric;
    if (metric == null) continue;
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
    // Readings that hardly differ would make every small change a large
    // one; a twentieth of the average is the least that counts as spread.
    final deviation = math.max(
      math.sqrt(spread / before.length),
      mean.abs() * 0.05,
    );
    if (deviation == 0) continue;
    final better = switch (part) {
      RecoveryPart.variability => (value - mean) / deviation,
      RecoveryPart.restingPulse => (mean - value) / deviation,
      // Breathing faster than usual counts against; slower is no gain.
      _ => math.min(0.0, (mean - value) / deviation),
    };
    final base = part == RecoveryPart.breathing ? 1.0 : _atUsual;
    parts[part] = RecoveryReading(
      value: value,
      usual: mean,
      share: (base + _perDeviation * better).clamp(0.0, 1.0),
    );
  }

  final night = nightOn(nights, day);
  final aimed = sleepGoalHours * 60;
  if (night != null && aimed > 0) {
    final asleep = night.asleepMinutes.toDouble();
    parts[RecoveryPart.sleep] = RecoveryReading(
      value: asleep,
      usual: aimed,
      share: (asleep / aimed).clamp(0.0, 1.0),
    );
  }
  return Recovery(parts);
}
