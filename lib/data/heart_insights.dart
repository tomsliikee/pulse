import 'health_controller.dart';
import 'heart_day.dart';
import 'metric_catalog.dart';
import 'models.dart';
import 'sleep_insights.dart';
import 'workout_insights.dart' show Trend;

/// What of a day's pulse is set against the days before.
enum HeartMeasure { average, lowest, highest, active, resting }

/// One number of a day's pulse against the day before and against the mean
/// of the days before.
class HeartComparison {
  const HeartComparison({
    required this.measure,
    required this.value,
    this.previous,
    this.mean,
  });

  final HeartMeasure measure;
  final double value;

  /// The day before; null where it has no curve.
  final double? previous;

  /// The mean of every earlier day with a curve.
  final double? mean;

  Trend get againstPrevious => _trend(previous);
  Trend get againstMean => _trend(mean);

  /// Only a resting rate is better or worse: a pulse that was higher over
  /// the day may have been a walk or a worry.
  Trend _trend(double? other) {
    if (other == null || measure != HeartMeasure.resting) return Trend.neutral;
    final diff = value - other;
    if (diff.abs() < 1) return Trend.same;
    return diff < 0 ? Trend.better : Trend.worse;
  }
}

/// How the day went against the days before.
enum HeartHeadline { first, calmer, usual, livelier }

enum HeartTipKind {
  restingHigh,
  longPeak,
  noCardio,
  peakWithoutWorkout,
  fewMeasurements,
  keepGoing,
}

/// A hint with the number it is about: a rate, or minutes.
class HeartTip {
  const HeartTip(this.kind, [this.value = 0]);

  final HeartTipKind kind;
  final int value;
}

/// What the app can say about the pulse of one day.
class HeartDayInsights {
  const HeartDayInsights({
    required this.comparisons,
    required this.headline,
    required this.difference,
    required this.tips,
  });

  /// Empty for a day without a curve.
  final List<HeartComparison> comparisons;
  final HeartHeadline headline;

  /// How far the day's average is from the mean of the days before.
  final int difference;
  final List<HeartTip> tips;

  /// A mean this far from that of the days before is another kind of day.
  static const int _apart = 3;

  /// Minutes in the peak zone from which a day asks for rest.
  static const int _longPeak = 30;

  /// Days in a row without cardio before the app says so.
  static const int _stillDays = 3;

  /// A finished day with less than this was hardly measured.
  static const int _fewMinutes = 6 * 60;

  static const int _tipsAtMost = 3;

  HeartComparison? measure(HeartMeasure measure) {
    for (final comparison in comparisons) {
      if (comparison.measure == measure) return comparison;
    }
    return null;
  }

  /// [before] are the curves of the earlier days, oldest first, one entry a
  /// day and empty where nothing was measured; [restingBefore] their
  /// resting rates in the same order. [usualResting] is the range usual for
  /// this person.
  factory HeartDayInsights.of({
    required List<HeartSample> samples,
    required List<List<HeartSample>> before,
    double? resting,
    List<double?> restingBefore = const [],
    (double, double)? usualResting,
    bool workedOut = false,
    bool isToday = false,
  }) {
    final summary = heartSummary(samples);
    if (summary == null) {
      return const HeartDayInsights(
        comparisons: [],
        headline: HeartHeadline.first,
        difference: 0,
        tips: [HeartTip(HeartTipKind.keepGoing)],
      );
    }
    // A day still running is set against the same stretch of the others.
    final until = samples.last.minuteOfDay;
    final earlier = [
      for (final day in before)
        [
          for (final sample in day)
            if (sample.minuteOfDay <= until) sample,
        ],
    ];

    double? mean(Iterable<double?> values) {
      final known = [for (final value in values) ?value];
      if (known.isEmpty) return null;
      return known.reduce((a, b) => a + b) / known.length;
    }

    HeartComparison compare(
      HeartMeasure measure,
      double value,
      double? Function(List<HeartSample> day) of,
    ) => HeartComparison(
      measure: measure,
      value: value,
      previous: earlier.isEmpty ? null : of(earlier.last),
      mean: mean(earlier.map(of)),
    );

    final comparisons = [
      compare(
        HeartMeasure.average,
        summary.average.toDouble(),
        (day) => heartSummary(day)?.average.toDouble(),
      ),
      compare(
        HeartMeasure.lowest,
        summary.low.toDouble(),
        (day) => heartSummary(day)?.low.toDouble(),
      ),
      compare(
        HeartMeasure.highest,
        summary.high.toDouble(),
        (day) => heartSummary(day)?.high.toDouble(),
      ),
      compare(
        HeartMeasure.active,
        activeMinutes(samples).toDouble(),
        (day) => day.isEmpty ? null : activeMinutes(day).toDouble(),
      ),
      if (resting != null)
        HeartComparison(
          measure: HeartMeasure.resting,
          value: resting,
          previous: restingBefore.isEmpty ? null : restingBefore.last,
          mean: mean(restingBefore),
        ),
    ];

    final usual = comparisons.first.mean;
    final difference = usual == null ? 0 : (summary.average - usual).round();
    final headline = usual == null
        ? HeartHeadline.first
        : difference <= -_apart
        ? HeartHeadline.calmer
        : difference >= _apart
        ? HeartHeadline.livelier
        : HeartHeadline.usual;

    final tips = <HeartTip>[];
    if (resting != null && usualResting != null && resting > usualResting.$2) {
      tips.add(HeartTip(HeartTipKind.restingHigh, resting.round()));
    }
    final peak = zoneMinutes(samples).last;
    if (peak >= _longPeak) {
      tips.add(HeartTip(HeartTipKind.longPeak, peak));
    } else if (summary.high >= heartZoneFloors.last && !workedOut) {
      tips.add(HeartTip(HeartTipKind.peakWithoutWorkout, summary.high));
    }
    final lastDays = [
      samples,
      for (final day in before.reversed)
        if (day.isNotEmpty) day,
    ].take(_stillDays).toList();
    if (lastDays.length == _stillDays &&
        lastDays.every((day) => activeMinutes(day) == 0)) {
      tips.add(const HeartTip(HeartTipKind.noCardio, _stillDays));
    }
    if (!isToday && samples.length * heartBucketMinutes < _fewMinutes) {
      tips.add(const HeartTip(HeartTipKind.fewMeasurements));
    }

    return HeartDayInsights(
      comparisons: comparisons,
      headline: headline,
      difference: difference,
      tips: tips.isEmpty
          ? const [HeartTip(HeartTipKind.keepGoing)]
          : tips.take(_tipsAtMost).toList(),
    );
  }
}

/// The pulse of [date] as far as the snapshot of [health] has it.
List<HeartSample> heartSamplesOn(HealthController health, DateTime date) {
  final index = health.snapshot.indexOf(date);
  return index == null ? const [] : health.snapshot.heart[index];
}

/// The days of the snapshot that have a curve, oldest first.
List<DateTime> heartDays(HealthController health) {
  final snapshot = health.snapshot;
  return [
    for (var i = 0; i < snapshot.dayCount; i++)
      if (snapshot.heart[i].length >= 2) snapshot.dateAt(i),
  ];
}

/// The insights of [date] from what [health] has loaded.
HeartDayInsights heartInsightsOf(HealthController health, DateTime date) {
  final snapshot = health.snapshot;
  final index = snapshot.indexOf(date);
  if (index == null) {
    return HeartDayInsights.of(samples: const [], before: const []);
  }
  // Only the days back to the first that has a curve.
  var first = index;
  for (var i = index - 1; i >= 0; i--) {
    if (snapshot.heart[i].isNotEmpty) first = i;
  }
  final resting = snapshot.valuesOf(Metric.restingHeartRate);
  return HeartDayInsights.of(
    samples: snapshot.heart[index],
    before: snapshot.heart.sublist(first, index),
    resting: resting[index],
    restingBefore: resting.sublist(first, index),
    usualResting: ownRange(resting),
    workedOut: health.workouts.any(
      (workout) =>
          workout.start.year == date.year &&
          workout.start.month == date.month &&
          workout.start.day == date.day,
    ),
    isToday: date == health.today,
  );
}
