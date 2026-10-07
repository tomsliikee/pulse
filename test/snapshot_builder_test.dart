import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/health_snapshot.dart';
import 'package:pulse/data/metric_catalog.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/snapshot_builder.dart';

import 'support/fixtures.dart';

void main() {
  final now = DateTime(2026, 10, 6, 15, 30);
  DateTime at(int daysAgo, int hour, [int minute = 0]) =>
      DateTime(2026, 10, 6 - daysAgo, hour, minute);

  group('day rules', () {
    test('sum, average and last combine a day differently', () {
      expect(Metric.floors.combine([3, 4]), 7);
      expect(Metric.heartRateVariability.combine([40, 50]), 45);
      expect(Metric.weight.combine([74.2, 73.9]), 73.9);
      expect(Metric.weight.combine([]), isNull);
    });

    test('readings outside the plausible range are rejected', () {
      expect(Metric.restingHeartRate.accepts(58), isTrue);
      expect(Metric.restingHeartRate.accepts(900), isFalse);
      expect(Metric.weight.accepts(double.nan), isFalse);
    });
  });

  group('buildSnapshot', () {
    test('a day without readings is null, not zero', () {
      final snapshot = buildSnapshot(
        now: now,
        raw: RawReadings(samples: [RawSample(Metric.weight, at(2, 7), 74.5)]),
      );

      expect(snapshot.dayCount, 30);
      expect(snapshot.value(Metric.weight, 27), 74.5);
      expect(snapshot.value(Metric.weight, 29), isNull);
      expect(snapshot.has(Metric.steps), isFalse);
      expect(snapshot.latestIndex(Metric.weight), 27);
    });

    test('totals aggregated by the store win over raw samples', () {
      // Phone and watch both recorded the walk; the store's total has the
      // overlap removed, the raw samples would count it twice.
      final snapshot = buildSnapshot(
        now: now,
        raw: RawReadings(
          samples: [
            RawSample(Metric.steps, at(0, 9), 4000),
            RawSample(Metric.steps, at(0, 9), 4100),
          ],
          dailyTotals: {
            Metric.steps: {DateTime(2026, 10, 6): 4100},
          },
        ),
      );

      expect(snapshot.value(Metric.steps, 29), 4100);
    });

    test('implausible and out-of-window readings are dropped', () {
      final snapshot = buildSnapshot(
        now: now,
        raw: RawReadings(
          samples: [
            RawSample(Metric.restingHeartRate, at(0, 7), 900),
            RawSample(Metric.restingHeartRate, at(1, 7), 57),
            RawSample(Metric.restingHeartRate, at(45, 7), 60),
          ],
        ),
      );

      expect(snapshot.value(Metric.restingHeartRate, 29), isNull);
      expect(snapshot.value(Metric.restingHeartRate, 28), 57);
      expect(
        snapshot.valuesOf(Metric.restingHeartRate).whereType<double>().length,
        1,
      );
    });

    test('a night belongs to the day it ends on', () {
      final snapshot = buildSnapshot(
        now: now,
        raw: RawReadings(
          sleepSessions: [RawSleepSession(at(1, 23, 10), at(0, 6, 40))],
          sleepStages: [
            RawSleepStage(SleepStage.awake, at(1, 23, 10), at(1, 23, 20)),
            RawSleepStage(SleepStage.deep, at(1, 23, 20), at(0, 1, 20)),
            RawSleepStage(SleepStage.light, at(0, 1, 20), at(0, 6, 40)),
          ],
        ),
      );

      final night = snapshot.nights[29]!;
      expect(snapshot.nights[28], isNull);
      expect(night.bedtimeMinute, 23 * 60 + 10);
      expect(night.totalMinutes, 450);
      expect(night.asleepMinutes, 440);
      expect(night.minutesIn(SleepStage.deep), 120);
      expect(night.segments.first.startMinute, 0);
      expect(snapshot.value(Metric.sleep, 29), closeTo(440 / 60, 0.001));
    });

    test('a night without stages still has a duration', () {
      final snapshot = buildSnapshot(
        now: now,
        raw: RawReadings(sleepSessions: [RawSleepSession(at(1, 23), at(0, 7))]),
      );

      final night = snapshot.nights[29]!;
      expect(night.hasStages, isFalse);
      expect(night.asleepMinutes, 480);
    });

    test('the longest session of a day is the night, a nap is not', () {
      final snapshot = buildSnapshot(
        now: now,
        raw: RawReadings(
          sleepSessions: [
            RawSleepSession(at(1, 23), at(0, 7)),
            RawSleepSession(at(0, 13), at(0, 13, 30)),
          ],
        ),
      );

      expect(snapshot.nights[29]!.totalMinutes, 480);
    });

    test('heart rate is averaged into ten-minute buckets', () {
      final snapshot = buildSnapshot(
        now: now,
        raw: RawReadings(
          samples: [
            RawSample(Metric.heartRate, at(0, 9, 1), 60),
            RawSample(Metric.heartRate, at(0, 9, 8), 70),
            RawSample(Metric.heartRate, at(0, 9, 12), 80),
          ],
        ),
      );

      final day = snapshot.heart[29];
      expect(day.map((s) => s.minuteOfDay), [540, 550]);
      expect(day.map((s) => s.bpm), [65, 80]);
      expect(snapshot.value(Metric.heartRate, 29), closeTo(70, 0.001));
    });

    test('meals add up to the nutrition series', () {
      HealthEntry meal(String id, double kcal, double? protein) => HealthEntry(
        id: id,
        source: 'at.haiden.pulse',
        isOwn: true,
        draft: EntryDraft(
          kind: EntryKind.meal,
          time: at(0, 12),
          amount: kcal,
          protein: protein,
        ),
      );
      final snapshot = buildSnapshot(
        now: now,
        raw: RawReadings(entries: [meal('a', 600, 30), meal('b', 250, null)]),
      );

      expect(snapshot.value(Metric.energyIntake, 29), 850);
      expect(snapshot.value(Metric.protein, 29), 30);
      expect(snapshot.has(Metric.carbs), isFalse);
      expect(snapshot.entriesOn(29, EntryKind.meal), hasLength(2));
      expect(snapshot.entriesOn(28, EntryKind.meal), isEmpty);
    });
  });

  group('HealthSnapshot JSON', () {
    test('survives a round trip through text', () {
      final original = buildSnapshot(now: fixtureNow, raw: fixtureReadings());
      final restored = HealthSnapshot.fromJson(
        jsonDecode(jsonEncode(original.toJson())),
      )!;

      expect(restored.today, original.today);
      expect(restored.series.keys.toSet(), original.series.keys.toSet());
      expect(restored.valuesOf(Metric.steps), original.valuesOf(Metric.steps));
      expect(
        restored.nights[29]!.asleepMinutes,
        original.nights[29]!.asleepMinutes,
      );
      expect(restored.heart[29].length, original.heart[29].length);
      expect(restored.workouts.length, original.workouts.length);
      expect(
        restored.entries.map((e) => e.id),
        original.entries.map((e) => e.id),
      );
    });

    test('rejects documents that are not a current snapshot', () {
      final good = buildSnapshot(now: fixtureNow, raw: fixtureReadings());

      expect(HealthSnapshot.fromJson(null), isNull);
      expect(HealthSnapshot.fromJson('text'), isNull);
      expect(HealthSnapshot.fromJson({'version': 1}), isNull);
      expect(
        HealthSnapshot.fromJson({...good.toJson(), 'version': 99}),
        isNull,
      );
      expect(
        HealthSnapshot.fromJson({...good.toJson(), 'today': 'not a date'}),
        isNull,
      );
    });

    test('drops values that are out of range instead of showing them', () {
      final json = buildSnapshot(
        now: fixtureNow,
        raw: fixtureReadings(),
      ).toJson();
      final series = Map<String, Object?>.of(
        json['series']! as Map<String, Object?>,
      );
      series['steps'] = [for (var i = 0; i < 30; i++) i == 0 ? -5 : 1000];
      series['unknownMetric'] = List.filled(30, 1);
      final restored = HealthSnapshot.fromJson(
        jsonDecode(jsonEncode({...json, 'series': series})),
      )!;

      expect(restored.value(Metric.steps, 0), isNull);
      expect(restored.value(Metric.steps, 1), 1000);
    });
  });

  test('heart rate of days that were not read again is kept', () {
    RawSample beat(int daysAgo, double bpm) =>
        RawSample(Metric.heartRate, at(daysAgo, 9), bpm);
    final previous = buildSnapshot(
      now: at(0, 8),
      raw: RawReadings(samples: [beat(3, 61), beat(1, 70)]),
    );
    // The later read only covers yesterday and today.
    final fresh = buildSnapshot(
      now: now,
      raw: RawReadings(samples: [beat(1, 72), beat(0, 80)]),
    );

    final merged = keepHeartBefore(at(1, 0), fresh: fresh, previous: previous);
    final today = merged.dayCount - 1;

    expect(merged.heart[today - 3].single.bpm, 61);
    expect(merged.value(Metric.heartRate, today - 3), 61);
    // Days that were read win over what was kept.
    expect(merged.heart[today - 1].single.bpm, 72);
    expect(merged.value(Metric.heartRate, today), 80);
    expect(merged.loadedAt, now);
  });

  group('minutesByHour', () {
    test('an interval is split where an hour ends', () {
      expect(minutesByHour([(at(0, 9, 50), at(0, 10, 20))]), {
        at(0, 9): 10,
        at(0, 10): 20,
      });
    });

    test('an interval over midnight belongs to both days', () {
      expect(minutesByHour([(at(1, 23, 45), at(0, 0, 15))]), {
        at(1, 23): 15,
        at(0, 0): 15,
      });
    });

    test('time that two sources both recorded counts once', () {
      final minutes = minutesByHour([
        (at(0, 9, 10), at(0, 9, 40)),
        (at(0, 9, 0), at(0, 9, 30)),
        // Lies inside what is already covered.
        (at(0, 9, 15), at(0, 9, 20)),
      ]);

      expect(minutes, {at(0, 9): 40});
    });

    test('nothing, and intervals without a length, give nothing', () {
      expect(minutesByHour([]), isEmpty);
      expect(minutesByHour([(at(0, 9), at(0, 9))]), isEmpty);
    });
  });
}
