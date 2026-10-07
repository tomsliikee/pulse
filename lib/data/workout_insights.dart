import 'models.dart';

/// What can be said about one workout in numbers.
enum WorkoutMeasure {
  duration,
  distance,

  /// Minutes per kilometre; lower is faster.
  pace,

  /// Kilometres per hour, for workouts on wheels.
  speed,
  energy,
  steps,
  avgHeartRate,
  maxHeartRate;

  /// Whether a higher value is the better one; null where neither is.
  bool? get higherIsBetter => switch (this) {
    duration || distance || speed || steps => true,
    pace => false,
    energy || avgHeartRate || maxHeartRate => null,
  };
}

enum Trend { better, same, worse, neutral }

/// The value of [measure] for [workout], or null when it was not recorded.
double? measureOf(Workout workout, WorkoutMeasure measure) {
  final km = workout.distanceKm;
  final moved = km != null && km > 0 && workout.minutes > 0;
  final wheels = workout.type == WorkoutType.ride;
  return switch (measure) {
    WorkoutMeasure.duration => workout.minutes.toDouble(),
    WorkoutMeasure.distance => km != null && km > 0 ? km : null,
    WorkoutMeasure.pace => moved && !wheels ? workout.minutes / km : null,
    WorkoutMeasure.speed => moved && wheels ? km / workout.minutes * 60 : null,
    WorkoutMeasure.energy => workout.kcal?.toDouble(),
    WorkoutMeasure.steps => workout.steps?.toDouble(),
    WorkoutMeasure.avgHeartRate => workout.avgBpm?.toDouble(),
    WorkoutMeasure.maxHeartRate => workout.maxBpm?.toDouble(),
  };
}

/// One measure of a workout next to the same measure of earlier ones.
class MeasureComparison {
  const MeasureComparison({
    required this.measure,
    required this.value,
    this.previous,
    this.average,
    this.isBest = false,
    this.judged = true,
  });

  final WorkoutMeasure measure;
  final double value;

  /// The workout of the same kind before this one.
  final double? previous;

  /// The mean of up to [WorkoutInsights.averageOver] workouts before it.
  final double? average;

  /// The best the user has done in this kind, among at least two.
  final bool isBest;

  /// Whether more or less of it says anything. How long a run took does
  /// not, next to how far and how fast it went.
  final bool judged;

  Trend get againstPrevious => _trend(previous);
  Trend get againstAverage => _trend(average);

  Trend _trend(double? other) {
    final higher = measure.higherIsBetter;
    if (other == null || higher == null || !judged) return Trend.neutral;
    // Within one percent it is the same; nobody walks to the metre.
    if ((value - other).abs() <= other.abs() * 0.01) return Trend.same;
    return (value > other) == higher ? Trend.better : Trend.worse;
  }
}

enum WorkoutTipKind {
  /// Too few workouts of the kind to say anything.
  fewToCompare,
  longBreak,
  lessOften,
  bigJump,
  higherPulse,
  strengthTwice,
  keepGoing,
}

class WorkoutTip {
  const WorkoutTip(this.kind, [this.value = 0]);

  final WorkoutTipKind kind;

  /// Days for [WorkoutTipKind.longBreak], percent for
  /// [WorkoutTipKind.bigJump].
  final int value;
}

/// A workout seen against the earlier ones of its kind: what got better,
/// what did not, and what to do about it. The rules are the app's own and
/// simple on purpose; they are hints, not training science.
class WorkoutInsights {
  WorkoutInsights._({
    required this.workout,
    required this.earlier,
    required this.measures,
    required this.trend,
    required this.perWeekRecent,
    required this.perWeekBefore,
    required this.tips,
  });

  /// Earlier workouts the average is taken over.
  static const int averageOver = 5;

  /// Workouts shown in the chart of the kind, this one included.
  static const int trendLength = 12;

  static const int _weeks = 4;
  static const int _tipsAtMost = 3;
  static const int _breakDays = 14;

  /// How far above the average counts as a jump.
  static const double _jump = 1.25;

  final Workout workout;

  /// The workouts of the same kind before this one, oldest first.
  final List<Workout> earlier;
  final List<MeasureComparison> measures;

  /// The last workouts of the kind up to this one, oldest first.
  final List<Workout> trend;

  /// Workouts of the kind per week in the four weeks up to this one.
  final double perWeekRecent;

  /// The same for the four weeks before those; null when the app has not
  /// been collecting for that long.
  final double? perWeekBefore;
  final List<WorkoutTip> tips;

  MeasureComparison? measure(WorkoutMeasure measure) {
    for (final comparison in measures) {
      if (comparison.measure == measure) return comparison;
    }
    return null;
  }

  /// The one comparison worth a sentence: how fast, else how far, else how
  /// long, against the workout before. Null for the first of its kind.
  MeasureComparison? get headline {
    for (final wanted in const [
      WorkoutMeasure.pace,
      WorkoutMeasure.speed,
      WorkoutMeasure.distance,
      WorkoutMeasure.duration,
    ]) {
      final comparison = measure(wanted);
      if (comparison?.previous != null) return comparison;
    }
    return null;
  }

  /// [workout] against [all] workouts the app knows, in any order.
  factory WorkoutInsights.of(Workout workout, List<Workout> all) {
    final sameKind = [
      for (final other in all)
        if (other.type == workout.type) other,
    ]..sort((a, b) => a.start.compareTo(b.start));
    final earlier = [
      for (final other in sameKind)
        if (other.start.isBefore(workout.start)) other,
    ];
    final upToHere = [...earlier, workout];
    final recent = earlier.length <= averageOver
        ? earlier
        : earlier.sublist(earlier.length - averageOver);

    final measures = <MeasureComparison>[];
    for (final measure in WorkoutMeasure.values) {
      final value = measureOf(workout, measure);
      if (value == null) continue;
      final before = [for (final other in recent) ?measureOf(other, measure)];
      final higher = measure.higherIsBetter;
      final ever = [for (final other in earlier) ?measureOf(other, measure)];
      final judged =
          measure != WorkoutMeasure.duration ||
          measureOf(workout, WorkoutMeasure.distance) == null;
      measures.add(
        MeasureComparison(
          measure: measure,
          value: value,
          previous: earlier.isEmpty ? null : measureOf(earlier.last, measure),
          average: before.isEmpty
              ? null
              : before.reduce((a, b) => a + b) / before.length,
          judged: judged,
          isBest:
              judged &&
              higher != null &&
              ever.isNotEmpty &&
              ever.every((other) => higher ? value > other : value < other),
        ),
      );
    }

    int countBetween(int fromDays, int toDays) {
      final from = workout.start.subtract(Duration(days: fromDays));
      final to = workout.start.subtract(Duration(days: toDays));
      return upToHere
          .where((w) => w.start.isAfter(from) && !w.start.isAfter(to))
          .length;
    }

    const span = _weeks * 7;
    final oldest = all.isEmpty
        ? workout.start
        : all.map((w) => w.start).reduce((a, b) => a.isBefore(b) ? a : b);
    final reachesBack = !oldest.isAfter(
      workout.start.subtract(const Duration(days: 2 * span)),
    );
    final perWeekRecent = countBetween(span, 0) / _weeks;
    final perWeekBefore = reachesBack
        ? countBetween(2 * span, span) / _weeks
        : null;

    return WorkoutInsights._(
      workout: workout,
      earlier: earlier,
      measures: measures,
      trend: upToHere.length <= trendLength
          ? upToHere
          : upToHere.sublist(upToHere.length - trendLength),
      perWeekRecent: perWeekRecent,
      perWeekBefore: perWeekBefore,
      tips: _tips(workout, earlier, measures, perWeekRecent, perWeekBefore),
    );
  }

  static List<WorkoutTip> _tips(
    Workout workout,
    List<Workout> earlier,
    List<MeasureComparison> measures,
    double perWeekRecent,
    double? perWeekBefore,
  ) {
    MeasureComparison? measure(WorkoutMeasure wanted) {
      for (final comparison in measures) {
        if (comparison.measure == wanted) return comparison;
      }
      return null;
    }

    if (earlier.length < 2) {
      return const [WorkoutTip(WorkoutTipKind.fewToCompare)];
    }
    final tips = <WorkoutTip>[];

    final pause = workout.start.difference(earlier.last.start).inDays;
    if (pause > _breakDays) {
      tips.add(WorkoutTip(WorkoutTipKind.longBreak, pause));
    }

    final before = perWeekBefore;
    if (before != null && before >= 0.5 && perWeekRecent < before * 0.75) {
      tips.add(const WorkoutTip(WorkoutTipKind.lessOften));
    }

    // How far, or for a workout without a distance, how long.
    final volume =
        measure(WorkoutMeasure.distance) ?? measure(WorkoutMeasure.duration);
    final usual = volume?.average;
    if (volume != null && usual != null && volume.value > usual * _jump) {
      tips.add(
        WorkoutTip(
          WorkoutTipKind.bigJump,
          ((volume.value / usual - 1) * 100).round(),
        ),
      );
    }

    final tempo = measure(WorkoutMeasure.pace) ?? measure(WorkoutMeasure.speed);
    final pulse = measure(WorkoutMeasure.avgHeartRate);
    final usualTempo = tempo?.average;
    final usualPulse = pulse?.average;
    if (tempo != null &&
        pulse != null &&
        usualTempo != null &&
        usualPulse != null &&
        (tempo.value - usualTempo).abs() <= usualTempo * 0.03 &&
        pulse.value > usualPulse + 5) {
      tips.add(const WorkoutTip(WorkoutTipKind.higherPulse));
    }

    if (workout.type == WorkoutType.strength && perWeekRecent < 2) {
      tips.add(const WorkoutTip(WorkoutTipKind.strengthTwice));
    }

    if (tips.isEmpty) return const [WorkoutTip(WorkoutTipKind.keepGoing)];
    return tips.length <= _tipsAtMost ? tips : tips.sublist(0, _tipsAtMost);
  }
}
