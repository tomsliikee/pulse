import 'health_history.dart';
import 'health_snapshot.dart';
import 'metric_catalog.dart';
import 'models.dart';
import 'night_insights.dart';
import 'sleep_insights.dart';
import 'workout_insights.dart' show Trend;

/// The value of a metric on a calendar day, or null when there is none.
typedef DayValue = double? Function(Metric metric, DateTime day);

/// What a day is judged against.
class DayGoals {
  const DayGoals({
    required this.steps,
    required this.activeEnergy,
    required this.waterMl,
    required this.sleepHours,
  });

  final int steps;
  final int activeEnergy;
  final int waterMl;
  final double sleepHours;
}

/// What the score of a day is made of.
enum DayScorePart {
  movement(40),
  sleep(35),
  heart(15),
  water(10);

  const DayScorePart(this.points);

  /// The most this part can give.
  final int points;
}

/// The app's own score of a day, from 1 to 100, with what each part gave.
/// Like the sleep score it is a rule of the app and not a measurement.
class DayScore {
  const DayScore(this.parts);

  /// The points each part earned. A part that could not be judged (nothing
  /// drunk was entered, no night recorded) is missing, and the others are
  /// scaled up to make the hundred.
  final Map<DayScorePart, double> parts;

  /// Null for a day nothing is known about.
  int? get total {
    var earned = 0.0;
    var possible = 0;
    for (final MapEntry(key: part, value: points) in parts.entries) {
      earned += points;
      possible += part.points;
    }
    if (possible == 0) return null;
    return (earned / possible * 100).round().clamp(1, 100);
  }
}

const int _usualDays = 30;

/// Beats above the usual resting heart rate at which the heart part is worth
/// nothing.
const int _pulseSpan = 10;

double _between(double value, double worst, double best) =>
    ((value - worst) / (best - worst)).clamp(0.0, 1.0);

DateTime _daysBefore(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day - days);

/// The night of [nights] (oldest first) that ended on [day].
SleepNight? nightOn(List<SleepNight> nights, DateTime day) {
  final key = dayKey(day);
  for (var i = nights.length - 1; i >= 0; i--) {
    final other = dayKey(nights[i].date);
    if (other == key) return nights[i];
    if (other < key) return null;
  }
  return null;
}

/// The values of [metric] on the [days] days before [day], oldest first,
/// leaving out days without one.
List<double> _valuesBefore(
  DayValue valueOf,
  Metric metric,
  DateTime day,
  int days,
) => [
  for (var back = days; back >= 1; back--)
    ?valueOf(metric, _daysBefore(day, back)),
];

/// The upper end of the resting heart rate usual for the month before
/// [day]; null with too few readings.
double? _usualPulse(DayValue valueOf, DateTime day) =>
    ownRange(_valuesBefore(valueOf, Metric.restingHeartRate, day, _usualDays))
        ?.$2;

/// The score of [day] against [goals], with the [nights] the app knows
/// (oldest first). For today it is the score so far.
DayScore dayScore({
  required DateTime day,
  required DayValue valueOf,
  required List<SleepNight> nights,
  required DayGoals goals,
}) {
  final parts = <DayScorePart, double>{};

  final steps = valueOf(Metric.steps, day);
  final energy = valueOf(Metric.activeEnergy, day);
  if (steps != null || energy != null) {
    // Steps count for five eighths where both are known.
    final share = switch ((steps, energy)) {
      (final steps?, final energy?) =>
        0.625 * _between(steps, 0, goals.steps.toDouble()) +
            0.375 * _between(energy, 0, goals.activeEnergy.toDouble()),
      (final steps?, null) => _between(steps, 0, goals.steps.toDouble()),
      (null, final energy?) => _between(
        energy,
        0,
        goals.activeEnergy.toDouble(),
      ),
      (null, null) => 0.0,
    };
    parts[DayScorePart.movement] = DayScorePart.movement.points * share;
  }

  final night = nightOn(nights, day);
  if (night != null) {
    parts[DayScorePart.sleep] =
        DayScorePart.sleep.points *
        sleepScore(night, goals.sleepHours, nights).total /
        100;
  }

  final pulse = valueOf(Metric.restingHeartRate, day);
  final usual = _usualPulse(valueOf, day);
  if (pulse != null && usual != null) {
    parts[DayScorePart.heart] =
        DayScorePart.heart.points * _between(pulse, usual + _pulseSpan, usual);
  }

  // Water is in litres. Somebody who enters none is not judged by it.
  final water = valueOf(Metric.water, day);
  if (water != null) {
    parts[DayScorePart.water] =
        DayScorePart.water.points *
        _between(water * 1000, 0, goals.waterMl.toDouble());
  }
  return DayScore(parts);
}

/// What can be said about one day in numbers.
enum DayMeasure {
  score,
  steps,
  activeEnergy,
  distance,

  /// Minutes asleep in the night that ended on the day.
  sleep,
  restingHeartRate,
  water;

  /// Whether a higher value is the better one.
  bool get higherIsBetter => this != restingHeartRate;

  /// Differences up to this are the same.
  double get tolerance => switch (this) {
    score || restingHeartRate => 1,
    steps => 100,
    activeEnergy => 10,
    distance || water => 0.1,
    sleep => 5,
  };

  Metric? get metric => switch (this) {
    steps => Metric.steps,
    activeEnergy => Metric.activeEnergy,
    distance => Metric.distance,
    restingHeartRate => Metric.restingHeartRate,
    water => Metric.water,
    score || sleep => null,
  };

  /// Whether the highest day ever is worth a mark.
  bool get hasBest => this == steps || this == activeEnergy || this == distance;
}

class DayComparison {
  const DayComparison({
    required this.measure,
    required this.value,
    this.previous,
    this.average,
    this.isBest = false,
  });

  final DayMeasure measure;
  final double value;

  /// The day before this one.
  final double? previous;

  /// The mean of the days of the week before it that have a value.
  final double? average;

  /// The highest value of all days the app knows, among at least
  /// [DayInsights.bestAmong].
  final bool isBest;

  Trend get againstPrevious => _trend(previous);
  Trend get againstAverage => _trend(average);

  Trend _trend(double? other) {
    if (other == null) return Trend.neutral;
    if ((value - other).abs() <= measure.tolerance) return Trend.same;
    return (value > other) == measure.higherIsBetter
        ? Trend.better
        : Trend.worse;
  }
}

/// The steps of today up to now, next to yesterday's up to the same time.
class StepsSoFar {
  const StepsSoFar({required this.today, required this.yesterday});

  final double today;
  final double yesterday;

  static const double _tolerance = 100;

  Trend get trend {
    if ((today - yesterday).abs() <= _tolerance) return Trend.same;
    return today > yesterday ? Trend.better : Trend.worse;
  }
}

/// Today's steps against yesterday's up to the minute of [now]. Null when
/// the store has no hourly totals for one of the two days. The store keeps
/// hours for two days only, so the comparison cannot reach further back.
StepsSoFar? stepsSoFar(HealthSnapshot snapshot, DateTime now) {
  final last = snapshot.dayCount - 1;
  final today = snapshot.hoursOf(Metric.steps, last);
  final yesterday = snapshot.hoursOf(Metric.steps, last - 1);
  if (today == null || yesterday == null) return null;
  var before = 0.0;
  for (var hour = 0; hour < now.hour; hour++) {
    before += yesterday[hour] ?? 0;
  }
  // The running hour counts by the minutes that have passed.
  before += (yesterday[now.hour] ?? 0) * now.minute / 60;
  var sofar = 0.0;
  for (final hour in today) {
    sofar += hour ?? 0;
  }
  return StepsSoFar(today: sofar, yesterday: before);
}

/// Days in a row that reached [goal] steps, ending on [today] if it has
/// reached it already and on the day before otherwise.
int stepStreak(DayValue valueOf, DateTime today, int goal) {
  bool reached(DateTime day) => (valueOf(Metric.steps, day) ?? 0) >= goal;
  var streak = reached(today) ? 1 : 0;
  // Ten years are as far as the history goes.
  for (var back = 1; back < 3660; back++) {
    if (!reached(_daysBefore(today, back))) break;
    streak++;
  }
  return streak;
}

enum DayTipKind {
  /// Too few days before to say anything.
  fewToCompare,

  /// Minute of the day to go to bed.
  bedtimeNear,

  /// Days of a streak that ends tonight.
  streakAtRisk,

  /// Steps missing to the goal.
  goalClose,

  /// Millilitres drunk so far.
  littleWater,

  /// Beats above the usual.
  pulseHigh,

  /// Percent fewer steps than the week before.
  stepsFalling,

  /// Days in a row at the goal.
  streak,
  keepGoing,
}

class DayTip {
  const DayTip(this.kind, [this.value = 0]);

  final DayTipKind kind;

  /// What the rule measured; see [DayTipKind].
  final int value;
}

/// A day seen against the ones before it. The rules are the app's own and
/// simple on purpose; they are hints, not medicine.
class DayInsights {
  DayInsights._({
    required this.day,
    required this.score,
    required this.night,
    required this.workouts,
    required this.measures,
    required this.streak,
    required this.tips,
  });

  /// Days before the day that count as its week.
  static const int weekDays = 7;

  /// Days with a value a best is picked among at least.
  static const int bestAmong = 7;

  static const int _tipsAtMost = 3;
  static const int _daysAtLeast = 3;
  static const double _goalClose = 0.8;
  static const int _streakWorthSaying = 3;
  static const int _eveningHour = 18;
  static const int _bedtimeAhead = 60;
  static const int _pulseOver = 3;
  static const double _stepsFalling = 0.85;

  /// Waking hours the water goal is spread over, from eight in the morning.
  static const int _drinkFrom = 8;
  static const int _drinkHours = 14;
  static const double _waterBehind = 0.6;

  final DateTime day;
  final DayScore score;

  /// The night that ended on the day.
  final SleepNight? night;

  /// The workouts that started on the day, oldest first.
  final List<Workout> workouts;
  final List<DayComparison> measures;

  /// Days in a row at the step goal up to this day.
  final int streak;
  final List<DayTip> tips;

  DayComparison? measure(DayMeasure wanted) {
    for (final comparison in measures) {
      if (comparison.measure == wanted) return comparison;
    }
    return null;
  }

  /// [day] against the days before it. [now] is given for today only: the
  /// rules about what is left to do need the time. [history] gives the
  /// bests, where the app has loaded it.
  factory DayInsights.of({
    required DateTime day,
    required DayValue valueOf,
    required List<SleepNight> nights,
    required List<Workout> workouts,
    required DayGoals goals,
    HealthHistory? history,
    DateTime? now,
  }) {
    DayScore scoreOf(DateTime other) =>
        dayScore(day: other, valueOf: valueOf, nights: nights, goals: goals);
    double? value(DayMeasure measure, DateTime other) => switch (measure) {
      DayMeasure.score => scoreOf(other).total?.toDouble(),
      DayMeasure.sleep => nightOn(nights, other)?.asleepMinutes.toDouble(),
      _ => valueOf(measure.metric!, other),
    };

    final measures = <DayComparison>[];
    for (final measure in DayMeasure.values) {
      final own = value(measure, day);
      if (own == null) continue;
      final before = [
        for (var back = weekDays; back >= 1; back--)
          ?value(measure, _daysBefore(day, back)),
      ];
      var best = false;
      if (measure.hasBest && history != null && own > 0) {
        final earlier = history.between(
          measure.metric!,
          history.firstDay(measure.metric!) ?? day,
          _daysBefore(day, 1),
        );
        best =
            earlier.length >= bestAmong - 1 &&
            earlier.every((other) => other < own);
      }
      measures.add(
        DayComparison(
          measure: measure,
          value: own,
          previous: value(measure, _daysBefore(day, 1)),
          average: before.isEmpty
              ? null
              : before.reduce((a, b) => a + b) / before.length,
          isBest: best,
        ),
      );
    }

    final key = dayKey(day);
    final streak = stepStreak(valueOf, day, goals.steps);
    return DayInsights._(
      day: day,
      score: scoreOf(day),
      night: nightOn(nights, day),
      workouts: [
        for (final workout in workouts)
          if (dayKey(workout.start) == key) workout,
      ],
      measures: measures,
      streak: streak,
      tips: _tips(day, valueOf, nights, goals, streak, now),
    );
  }

  static List<DayTip> _tips(
    DateTime day,
    DayValue valueOf,
    List<SleepNight> nights,
    DayGoals goals,
    int streak,
    DateTime? now,
  ) {
    final week = _valuesBefore(valueOf, Metric.steps, day, weekDays);
    if (week.length < _daysAtLeast) {
      return const [DayTip(DayTipKind.fewToCompare)];
    }
    final tips = <DayTip>[];
    final steps = valueOf(Metric.steps, day) ?? 0;
    final reached = steps >= goals.steps;

    if (now != null) {
      final minute = now.hour * 60 + now.minute;
      final plan = tonight(nights, goals.sleepHours, day);
      // A bedtime after midnight belongs to the evening before it.
      if (plan != null && now.hour >= _eveningHour) {
        final bedtime = plan.bedtimeMinute < 12 * 60
            ? plan.bedtimeMinute + 24 * 60
            : plan.bedtimeMinute;
        if (minute >= bedtime - _bedtimeAhead) {
          tips.add(DayTip(DayTipKind.bedtimeNear, plan.bedtimeMinute));
        }
      }
      if (!reached &&
          streak >= _streakWorthSaying &&
          now.hour >= _eveningHour) {
        tips.add(DayTip(DayTipKind.streakAtRisk, streak));
      }
      if (!reached && steps >= goals.steps * _goalClose) {
        tips.add(DayTip(DayTipKind.goalClose, (goals.steps - steps).round()));
      }
      // Only for somebody who enters what they drink at all.
      final drinks =
          valueOf(Metric.water, day) != null ||
          _valuesBefore(valueOf, Metric.water, day, weekDays).isNotEmpty;
      if (drinks && now.hour >= 12) {
        final drunk = (valueOf(Metric.water, day) ?? 0) * 1000;
        final due =
            goals.waterMl *
            ((minute / 60 - _drinkFrom) / _drinkHours).clamp(0.0, 1.0);
        if (drunk < due * _waterBehind) {
          tips.add(DayTip(DayTipKind.littleWater, drunk.round()));
        }
      }
    }

    final pulse = valueOf(Metric.restingHeartRate, day);
    final usual = _usualPulse(valueOf, day);
    if (pulse != null && usual != null && pulse > usual + _pulseOver) {
      tips.add(DayTip(DayTipKind.pulseHigh, (pulse - usual).round()));
    }

    final weekBefore = _valuesBefore(
      valueOf,
      Metric.steps,
      _daysBefore(day, weekDays),
      weekDays,
    );
    if (week.length >= 4 && weekBefore.length >= 4) {
      double mean(List<double> values) =>
          values.reduce((a, b) => a + b) / values.length;
      final recent = mean(week);
      final earlier = mean(weekBefore);
      if (earlier > 0 && recent < earlier * _stepsFalling) {
        tips.add(
          DayTip(
            DayTipKind.stepsFalling,
            ((1 - recent / earlier) * 100).round(),
          ),
        );
      }
    }

    if (reached && streak >= _streakWorthSaying) {
      tips.add(DayTip(DayTipKind.streak, streak));
    }

    if (tips.isEmpty) return const [DayTip(DayTipKind.keepGoing)];
    return tips.length <= _tipsAtMost ? tips : tips.sublist(0, _tipsAtMost);
  }
}
