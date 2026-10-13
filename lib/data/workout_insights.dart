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
  maxHeartRate,

  /// The average heart rate as a percentage of the highest the user's age
  /// allows. The app's own rule of thumb, not a measurement.
  intensity;

  /// Whether a higher value is the better one; null where neither is.
  bool? get higherIsBetter => switch (this) {
    duration || distance || speed || steps => true,
    pace => false,
    energy || avgHeartRate || maxHeartRate || intensity => null,
  };

  /// The measures of a workout with [focus], what it is about first.
  static List<WorkoutMeasure> orderFor(WorkoutFocus focus) => switch (focus) {
    WorkoutFocus.distance => const [
      distance,
      pace,
      duration,
      energy,
      avgHeartRate,
      maxHeartRate,
      intensity,
      steps,
    ],
    WorkoutFocus.speed => const [
      distance,
      speed,
      duration,
      energy,
      avgHeartRate,
      maxHeartRate,
      intensity,
      steps,
    ],
    WorkoutFocus.effort => const [
      duration,
      energy,
      intensity,
      avgHeartRate,
      maxHeartRate,
      distance,
      speed,
      steps,
    ],
    WorkoutFocus.calm => const [
      duration,
      avgHeartRate,
      energy,
      maxHeartRate,
      intensity,
      distance,
      speed,
      steps,
    ],
  };

  /// Whether this measure is a by-product of a workout with [focus]: the
  /// few hundred metres walked between the machines of a gym.
  bool isMinorFor(WorkoutFocus focus) => switch (focus) {
    WorkoutFocus.distance || WorkoutFocus.speed => false,
    WorkoutFocus.effort ||
    WorkoutFocus.calm => this == distance || this == speed || this == steps,
  };
}

/// How hard an [WorkoutMeasure.intensity] is.
enum IntensityLevel {
  easy,
  moderate,
  hard,
  allOut;

  /// The level of [percent] of the highest heart rate. The limits are the
  /// app's own, close to the usual training zones.
  static IntensityLevel of(double percent) => percent < 60
      ? easy
      : percent < 70
      ? moderate
      : percent < 85
      ? hard
      : allOut;
}

enum Trend { better, same, worse, neutral }

/// Below this distance a workout has no pace or speed: a strength session
/// that drifted a few metres would come out at thousands of minutes per
/// kilometre.
const double _minKmForPace = 0.1;

/// The value of [measure] for [workout], or null when it was not recorded.
/// [maxHeartRate] is the highest the user's age allows, where it is known.
double? measureOf(
  Workout workout,
  WorkoutMeasure measure, {
  int? maxHeartRate,
}) {
  final km = workout.distanceKm;
  final moved = km != null && km >= _minKmForPace && workout.minutes > 0;
  final wheels = workout.type.rolls;
  return switch (measure) {
    WorkoutMeasure.duration => workout.minutes.toDouble(),
    WorkoutMeasure.distance => km != null && km > 0 ? km : null,
    WorkoutMeasure.pace =>
      moved && workout.type.paced ? workout.minutes / km : null,
    WorkoutMeasure.speed => moved && wheels ? km / workout.minutes * 60 : null,
    WorkoutMeasure.energy => workout.kcal?.toDouble(),
    WorkoutMeasure.steps => workout.steps?.toDouble(),
    WorkoutMeasure.avgHeartRate => workout.avgBpm?.toDouble(),
    WorkoutMeasure.maxHeartRate => workout.maxBpm?.toDouble(),
    WorkoutMeasure.intensity => switch ((workout.avgBpm, maxHeartRate)) {
      (final bpm?, final highest?) when highest > 0 => bpm / highest * 100,
      _ => null,
    },
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
    this.minor = false,
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

  /// Whether it is a by-product of this kind of workout, shown last and
  /// never judged.
  final bool minor;

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

  /// The number the workout is about: how far for a run, how long for a
  /// strength session, and how long as well for a run without a distance.
  MeasureComparison get primary => measures.first;

  /// The one comparison worth a sentence, against the workout before: how
  /// fast, else how far, else how long, and for a kind that is not about
  /// distance only how long. Null for the first of its kind.
  MeasureComparison? get headline {
    for (final wanted in const [
      WorkoutMeasure.pace,
      WorkoutMeasure.speed,
      WorkoutMeasure.distance,
      WorkoutMeasure.duration,
    ]) {
      final comparison = measure(wanted);
      if (comparison == null || comparison.minor) continue;
      if (comparison.previous != null) return comparison;
    }
    return null;
  }

  /// [workout] against [all] workouts the app knows, in any order. With
  /// [maxHeartRate], the highest the user's age allows, it has an
  /// intensity.
  factory WorkoutInsights.of(
    Workout workout,
    List<Workout> all, {
    int? maxHeartRate,
  }) {
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

    double? of(Workout workout, WorkoutMeasure measure) =>
        measureOf(workout, measure, maxHeartRate: maxHeartRate);

    final focus = workout.type.focus;
    // Where the workout is about its distance, how long it took says
    // nothing next to how far and how fast it went.
    final byDistance =
        (focus == WorkoutFocus.distance || focus == WorkoutFocus.speed) &&
        of(workout, WorkoutMeasure.distance) != null;
    final measures = <MeasureComparison>[];
    for (final measure in [
      // A workout about distance that has none is about its length.
      if (!byDistance) WorkoutMeasure.duration,
      ...WorkoutMeasure.orderFor(focus),
      // Whatever the order of the kind leaves out comes last.
      ...WorkoutMeasure.values,
    ]) {
      if (measures.any((known) => known.measure == measure)) continue;
      final value = of(workout, measure);
      if (value == null) continue;
      final before = [for (final other in recent) ?of(other, measure)];
      final higher = measure.higherIsBetter;
      final ever = [for (final other in earlier) ?of(other, measure)];
      final minor = measure.isMinorFor(focus);
      final judged =
          !minor && (measure != WorkoutMeasure.duration || !byDistance);
      measures.add(
        MeasureComparison(
          measure: measure,
          value: value,
          minor: minor,
          previous: earlier.isEmpty ? null : of(earlier.last, measure),
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
    // A by-product of the kind says nothing about how much was done.
    MeasureComparison? measure(WorkoutMeasure wanted) {
      for (final comparison in measures) {
        if (comparison.measure == wanted && !comparison.minor) {
          return comparison;
        }
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

    if (workout.type.buildsStrength && perWeekRecent < 2) {
      tips.add(const WorkoutTip(WorkoutTipKind.strengthTwice));
    }

    if (tips.isEmpty) return const [WorkoutTip(WorkoutTipKind.keepGoing)];
    return tips.length <= _tipsAtMost ? tips : tips.sublist(0, _tipsAtMost);
  }
}
