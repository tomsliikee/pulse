import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/metric_catalog.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/recovery.dart';

final _day = DateTime(2026, 10, 6);

/// Values of thirty days before the day that swing by [swing] around
/// [mean], and [today] on the day itself.
double? Function(Metric, DateTime) _values(
  Map<Metric, (double mean, double swing, double? today)> metrics, {
  int days = 30,
}) => (metric, day) {
  final entry = metrics[metric];
  if (entry == null) return null;
  final (mean, swing, today) = entry;
  if (day == _day) return today;
  final back = _day.difference(day).inDays;
  if (back < 1 || back > days) return null;
  return mean + (back.isEven ? swing : -swing);
};

SleepNight _night(int asleep) => SleepNight(
  date: _day,
  bedtimeMinute: 23 * 60,
  totalMinutes: asleep,
  segments: const [],
);

Recovery _recovery(
  double? Function(Metric, DateTime) valueOf, {
  List<SleepNight> nights = const [],
}) =>
    recoveryOf(day: _day, valueOf: valueOf, nights: nights, sleepGoalHours: 8);

void main() {
  test('a reading at its own average gives six tenths of its part', () {
    final recovery = _recovery(
      _values({Metric.heartRateVariability: (50, 5, 50)}),
    );
    final reading = recovery.parts[RecoveryPart.variability]!;
    expect(reading.usual, 50);
    expect(reading.share, closeTo(0.6, 1e-9));
    expect(recovery.total, 60);
    expect(recovery.zone, RecoveryZone.yellow);
  });

  test('variability above the usual is better, a pulse above it worse', () {
    final high = _recovery(_values({Metric.heartRateVariability: (50, 5, 55)}));
    expect(high.parts[RecoveryPart.variability]!.share, closeTo(0.8, 1e-9));
    final low = _recovery(_values({Metric.heartRateVariability: (50, 5, 40)}));
    expect(low.parts[RecoveryPart.variability]!.share, closeTo(0.2, 1e-9));

    final calm = _recovery(_values({Metric.restingHeartRate: (56, 4, 52)}));
    expect(calm.parts[RecoveryPart.restingPulse]!.share, closeTo(0.8, 1e-9));
    final racing = _recovery(_values({Metric.restingHeartRate: (56, 4, 72)}));
    expect(racing.parts[RecoveryPart.restingPulse]!.share, 0);
  });

  test('a part never gives less than nothing or more than all', () {
    final best = _recovery(_values({Metric.heartRateVariability: (50, 5, 90)}));
    expect(best.total, 100);
    expect(best.zone, RecoveryZone.green);
    final worst = _recovery(_values({Metric.heartRateVariability: (50, 5, 5)}));
    expect(worst.total, 0);
    expect(worst.zone, RecoveryZone.red);
  });

  test('breathing only counts against when it is faster than usual', () {
    final pulse = (56.0, 2.0, 56.0);
    final slower = _recovery(
      _values({
        Metric.restingHeartRate: pulse,
        Metric.respiratoryRate: (14, 1, 12),
      }),
    );
    expect(slower.parts[RecoveryPart.breathing]!.share, 1);
    final faster = _recovery(
      _values({
        Metric.restingHeartRate: pulse,
        Metric.respiratoryRate: (14, 1, 16),
      }),
    );
    expect(faster.parts[RecoveryPart.breathing]!.share, closeTo(0.6, 1e-9));
  });

  test('the night gives its share of the hours aimed at', () {
    final recovery = _recovery(
      _values({Metric.restingHeartRate: (56, 2, 56)}),
      nights: [_night(360)],
    );
    final reading = recovery.parts[RecoveryPart.sleep]!;
    expect(reading.usual, 480);
    expect(reading.share, 0.75);
    // 20 points at 0.6 and 20 at 0.75, of 40.
    expect(recovery.total, 68);
    expect(
      _recovery(
        _values({Metric.restingHeartRate: (56, 2, 56)}),
        nights: [_night(600)],
      ).parts[RecoveryPart.sleep]!.share,
      1,
    );
  });

  test('the parts are weighed, and a missing one is left out', () {
    final recovery = _recovery(
      _values({
        Metric.heartRateVariability: (50, 5, 55),
        Metric.restingHeartRate: (56, 4, 60),
      }),
    );
    // 50 points at 0.8 and 20 at 0.4, of 70.
    expect(recovery.total, 69);
    expect(recovery.parts.keys, [
      RecoveryPart.variability,
      RecoveryPart.restingPulse,
    ]);
  });

  test('without variability and resting pulse there is no recovery', () {
    final recovery = _recovery(
      _values({Metric.respiratoryRate: (14, 1, 14)}),
      nights: [_night(480)],
    );
    expect(recovery.parts, isNotEmpty);
    expect(recovery.total, isNull);
    expect(recovery.zone, isNull);
    expect(_recovery((_, _) => null).total, isNull);
  });

  test('a part needs five days to be set against', () {
    Recovery withDays(int days) => _recovery(
      _values({Metric.heartRateVariability: (50, 5, 50)}, days: days),
    );
    expect(withDays(4).parts, isEmpty);
    expect(withDays(5).parts, contains(RecoveryPart.variability));
    // A day without a reading has no part either.
    expect(
      _recovery(_values({Metric.heartRateVariability: (50, 5, null)})).parts,
      isEmpty,
    );
  });

  test('readings that hardly differ do not make a small change a large '
      'one', () {
    final recovery = _recovery(_values({Metric.restingHeartRate: (60, 0, 61)}));
    // A twentieth of 60 is the least spread: one beat is a third of it.
    expect(
      recovery.parts[RecoveryPart.restingPulse]!.share,
      closeTo(0.6 - 0.2 / 3, 1e-9),
    );
  });

  test('the zones change at 34 and 67', () {
    expect(RecoveryZone.of(0), RecoveryZone.red);
    expect(RecoveryZone.of(33), RecoveryZone.red);
    expect(RecoveryZone.of(34), RecoveryZone.yellow);
    expect(RecoveryZone.of(66), RecoveryZone.yellow);
    expect(RecoveryZone.of(67), RecoveryZone.green);
    expect(RecoveryZone.of(100), RecoveryZone.green);
  });
}
