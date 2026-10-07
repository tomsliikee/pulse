import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/health_snapshot.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/sleep_insights.dart';

SleepNight _night({
  int bedtime = 23 * 60,
  int total = 480,
  List<(SleepStage, int)> stages = const [],
}) {
  var cursor = 0;
  return SleepNight(
    date: DateTime(2026, 10, 6),
    bedtimeMinute: bedtime,
    totalMinutes: total,
    segments: [
      for (final (stage, minutes) in stages)
        SleepSegment(
          stage: stage,
          startMinute: (cursor += minutes) - minutes,
          minutes: minutes,
        ),
    ],
  );
}

HealthSnapshot _snapshot({
  required List<SleepNight?> nights,
  required List<List<HeartSample>> heart,
}) => HealthSnapshot(
  today: DateTime(2026, 10, 6),
  loadedAt: DateTime(2026, 10, 6, 12),
  dayCount: nights.length,
  series: const {},
  nights: nights,
  heart: heart,
  workouts: const [],
  entries: const [],
);

void main() {
  group('stage shares', () {
    final night = _night(
      total: 500,
      stages: [
        (SleepStage.awake, 100),
        (SleepStage.deep, 40),
        (SleepStage.rem, 88),
        (SleepStage.light, 272),
      ],
    );

    test('sleep stages are a share of the time asleep', () {
      expect(stageShare(night, SleepStage.deep), closeTo(0.10, 0.0001));
      expect(stageShare(night, SleepStage.rem), closeTo(0.22, 0.0001));
      expect(stageShare(night, SleepStage.light), closeTo(0.68, 0.0001));
    });

    test('awake is a share of the time in bed', () {
      expect(stageShare(night, SleepStage.awake), closeTo(0.20, 0.0001));
    });

    test('each stage is judged against its typical range', () {
      RangeVerdict of(SleepStage stage) =>
          verdictOf(stageShare(night, stage)!, typicalStageShare[stage]!);
      expect(of(SleepStage.deep), RangeVerdict.below);
      expect(of(SleepStage.rem), RangeVerdict.within);
      expect(of(SleepStage.light), RangeVerdict.above);
      expect(of(SleepStage.awake), RangeVerdict.above);
    });

    test('a night without stages has no shares', () {
      expect(stageShare(_night(), SleepStage.deep), isNull);
    });

    test('efficiency is asleep over time in bed', () {
      expect(sleepEfficiency(night), closeTo(0.8, 0.0001));
      expect(sleepEfficiency(_night()), 1);
    });
  });

  group('regularity', () {
    test('bedtimes on both sides of midnight are close together', () {
      final regularity = sleepRegularity([
        _night(bedtime: 23 * 60 + 50, total: 420),
        null,
        _night(bedtime: 10, total: 420),
      ])!;
      expect(regularity.nights, 2);
      expect(regularity.bedtimeMinute, 0);
      expect(regularity.bedtimeSpread, 10);
      expect(regularity.wakeMinute, 7 * 60);
      expect(regularity.wakeSpread, 10);
    });

    test('equal nights have no spread', () {
      final regularity = sleepRegularity([_night(), _night(), _night()])!;
      expect(regularity.bedtimeMinute, 23 * 60);
      expect(regularity.bedtimeSpread, 0);
      expect(regularity.wakeMinute, 7 * 60);
    });

    test('one night is not enough', () {
      expect(sleepRegularity([_night(), null]), isNull);
    });
  });

  group('sleep debt', () {
    test('adds up what is missing and skips nights without data', () {
      final debt = sleepDebt([_night(total: 420), null, _night(total: 450)], 8);
      expect(debt.minutes, 90);
      expect(debt.nights, 2);
    });

    test('a long night pays debt off', () {
      final debt = sleepDebt([_night(total: 420), _night(total: 510)], 8);
      expect(debt.minutes, 30);
    });

    test('more sleep than the goal is not a credit', () {
      final debt = sleepDebt([_night(total: 600)], 8);
      expect(debt.minutes, 0);
      expect(debt.nights, 1);
    });

    test('time awake does not count as sleep', () {
      final night = _night(
        stages: [(SleepStage.awake, 30), (SleepStage.light, 450)],
      );
      expect(sleepDebt([night], 8).minutes, 30);
    });
  });

  group('night heart rate', () {
    List<HeartSample> day(int bpm) => [
      for (var minute = 0; minute < 24 * 60; minute += 60)
        HeartSample(minuteOfDay: minute, bpm: bpm),
    ];

    test('joins the evening before with the morning', () {
      final snapshot = _snapshot(
        nights: [
          null,
          _night(bedtime: 22 * 60 + 30, total: 480),
        ],
        heart: [day(70), day(55)],
      );
      final samples = nightHeart(snapshot, 1);
      // 23:00 of the evening, then 00:00 to 06:00.
      expect(
        [for (final s in samples) s.bpm],
        [70, 55, 55, 55, 55, 55, 55, 55],
      );
      expect(samples.first.minuteOfDay, 23 * 60);
      expect(samples.last.minuteOfDay, 6 * 60);
    });

    test('a night that began after midnight stays within its day', () {
      final snapshot = _snapshot(
        nights: [null, _night(bedtime: 60, total: 300)],
        heart: [day(70), day(55)],
      );
      final samples = nightHeart(snapshot, 1);
      expect(samples.length, 6);
      expect(samples.every((s) => s.bpm == 55), isTrue);
    });

    test('is empty without a night or without a curve', () {
      expect(
        nightHeart(_snapshot(nights: [null], heart: [day(60)]), 0),
        isEmpty,
      );
      expect(
        nightHeart(
          _snapshot(nights: [null, _night()], heart: const [[], []]),
          1,
        ),
        isEmpty,
      );
    });
  });

  group('own range', () {
    test('is the middle half of the values', () {
      final range = ownRange([5, null, 1, 3, 2, 4])!;
      expect(range.$1, 2);
      expect(range.$2, 4);
    });

    test('needs four values', () {
      expect(ownRange([1, 2, 3, null]), isNull);
    });
  });
}
