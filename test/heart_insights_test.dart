import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/heart_insights.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/workout_insights.dart' show Trend;

/// A day measured every ten minutes from midnight for [hours], at [bpm]
/// except for [peakMinutes] at [peak] from 10:00.
List<HeartSample> _day(
  int bpm, {
  int hours = 24,
  int peak = 0,
  int peakMinutes = 0,
}) => [
  for (var minute = 0; minute < hours * 60; minute += 10)
    HeartSample(
      minuteOfDay: minute,
      bpm: minute >= 600 && minute < 600 + peakMinutes ? peak : bpm,
    ),
];

void main() {
  test('a day without a curve has nothing to compare and one calm hint', () {
    final insights = HeartDayInsights.of(samples: const [], before: const []);
    expect(insights.comparisons, isEmpty);
    expect(insights.headline, HeartHeadline.first);
    expect(insights.tips.single.kind, HeartTipKind.keepGoing);
  });

  test('the first day with a curve says so', () {
    final insights = HeartDayInsights.of(
      samples: _day(64, peak: 120, peakMinutes: 20),
      before: const [],
    );
    expect(insights.headline, HeartHeadline.first);
    final average = insights.measure(HeartMeasure.average)!;
    expect(average.previous, isNull);
    expect(average.mean, isNull);
    expect(insights.measure(HeartMeasure.resting), isNull);
  });

  test('each number stands against the day before and the mean of all '
      'earlier days, a day without a curve left out', () {
    final insights = HeartDayInsights.of(
      samples: _day(70, peak: 130, peakMinutes: 30),
      before: [_day(60), const [], _day(64, peak: 120, peakMinutes: 10)],
      resting: 58,
      restingBefore: const [54, null, 56],
    );
    final highest = insights.measure(HeartMeasure.highest)!;
    expect(highest.value, 130);
    expect(highest.previous, 120);
    expect(highest.mean, 90);
    final active = insights.measure(HeartMeasure.active)!;
    expect(active.value, 30);
    expect(active.previous, 10);
    expect(active.mean, 5);
    // Only a resting rate is better or worse.
    expect(highest.againstPrevious, Trend.neutral);
    final resting = insights.measure(HeartMeasure.resting)!;
    expect(resting.previous, 56);
    expect(resting.mean, 55);
    expect(resting.againstPrevious, Trend.worse);
    expect(insights.headline, HeartHeadline.livelier);
    expect(insights.difference, greaterThan(0));
  });

  test('where the day before has no curve, only the mean is there', () {
    final insights = HeartDayInsights.of(
      samples: _day(60),
      before: [_day(60), const []],
    );
    final average = insights.measure(HeartMeasure.average)!;
    expect(average.previous, isNull);
    expect(average.mean, 60);
    expect(insights.headline, HeartHeadline.usual);
  });

  test('a day still running is set against the same hours of the others', () {
    // The earlier day was calm until noon and busy after it.
    final earlier = [
      for (final sample in _day(60))
        HeartSample(
          minuteOfDay: sample.minuteOfDay,
          bpm: sample.minuteOfDay < 720 ? 60 : 100,
        ),
    ];
    final insights = HeartDayInsights.of(
      samples: _day(60, hours: 12),
      before: [earlier],
      isToday: true,
    );
    expect(insights.measure(HeartMeasure.average)!.previous, 60);
    expect(insights.headline, HeartHeadline.usual);
    expect(insights.tips.single.kind, HeartTipKind.keepGoing);
  });

  test('a calmer day is called calmer by how much', () {
    final insights = HeartDayInsights.of(
      samples: _day(58),
      before: [_day(66), _day(64)],
    );
    expect(insights.headline, HeartHeadline.calmer);
    expect(insights.difference, -7);
  });

  test('a resting rate above the usual range asks for an easier day, and a '
      'lower one than before is better', () {
    final high = HeartDayInsights.of(
      samples: _day(60, peak: 120, peakMinutes: 10),
      before: const [],
      resting: 63,
      usualResting: (54, 58),
    );
    expect(high.tips.first.kind, HeartTipKind.restingHigh);
    expect(high.tips.first.value, 63);

    final low = HeartDayInsights.of(
      samples: _day(60),
      before: [_day(60)],
      resting: 52,
      restingBefore: const [56],
      usualResting: (54, 58),
    );
    expect(low.measure(HeartMeasure.resting)!.againstPrevious, Trend.better);
    expect([
      for (final tip in low.tips) tip.kind,
    ], isNot(contains(HeartTipKind.restingHigh)));
  });

  test('half an hour in the peak zone asks for recovery; a short peak is '
      'only noted where no workout explains it', () {
    final long = HeartDayInsights.of(
      samples: _day(60, peak: 150, peakMinutes: 40),
      before: const [],
    );
    expect(long.tips.single.kind, HeartTipKind.longPeak);
    expect(long.tips.single.value, 40);

    final short = _day(60, peak: 150, peakMinutes: 10);
    final alone = HeartDayInsights.of(samples: short, before: const []);
    expect(alone.tips.single.kind, HeartTipKind.peakWithoutWorkout);
    expect(alone.tips.single.value, 150);
    final trained = HeartDayInsights.of(
      samples: short,
      before: const [],
      workedOut: true,
    );
    expect(trained.tips.single.kind, HeartTipKind.keepGoing);
  });

  test('three measured days in a row without cardio are said', () {
    final still = HeartDayInsights.of(
      samples: _day(60),
      before: [_day(60), const [], _day(62)],
    );
    expect(still.tips.single.kind, HeartTipKind.noCardio);
    expect(still.tips.single.value, 3);

    final moved = HeartDayInsights.of(
      samples: _day(60),
      before: [_day(60), _day(62, peak: 120, peakMinutes: 10)],
    );
    expect(moved.tips.single.kind, HeartTipKind.keepGoing);
    final few = HeartDayInsights.of(samples: _day(60), before: [_day(60)]);
    expect(few.tips.single.kind, HeartTipKind.keepGoing);
  });

  test('a finished day with few measurements says to wear the watch; '
      'today does not', () {
    final short = _day(60, hours: 3);
    expect(
      HeartDayInsights.of(samples: short, before: const []).tips.single.kind,
      HeartTipKind.fewMeasurements,
    );
    expect(
      HeartDayInsights.of(
        samples: short,
        before: const [],
        isToday: true,
      ).tips.single.kind,
      HeartTipKind.keepGoing,
    );
  });
}
