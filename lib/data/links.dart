import 'dart:math' as math;

import 'day_insights.dart';
import 'goals.dart';
import 'health_history.dart';
import 'metric_catalog.dart';
import 'models.dart';
import 'night_insights.dart';
import 'recovery.dart';
import 'sleep_insights.dart';

/// What is set against what.
enum LinkKind {
  /// A day against the night that followed it.
  dayToNight,

  /// A night against the day it ended on.
  nightToDay,

  /// One day of the week against the other six.
  weekday,

  /// Weeks against weeks, over a year.
  weeks,
}

/// What the days, nights or weeks are split by.
enum LinkCause {
  workout,
  steps,
  activeEnergy,
  intensity,
  water,
  intake,
  asleep,
  earlyBed,
  sleepScore,
  weekday,
  weekSteps,
  weekWorkouts,
}

/// Where the line between the two sides lies.
enum LinkSplit {
  /// Something happened or did not: a workout, a day of the week.
  yesNo,

  /// At the user's goal.
  goal,

  /// At the own median of the stretch.
  usual,
}

/// What differs between the two sides.
enum LinkEffect {
  /// Minutes.
  asleep,
  sleepScore,

  /// Minutes.
  deep,

  /// Minutes on the axis of [bedtimeOnAxis].
  bedtime,
  recovery,
  restingPulse,
  variability,
  steps,

  /// Kilograms.
  weight;

  /// The smallest difference worth a sentence, in the effect's own unit. A
  /// few minutes can pass every test of chance in very even numbers and
  /// still tell nobody anything.
  double get worthSaying => switch (this) {
    asleep || deep || bedtime => 10,
    sleepScore || recovery => 3,
    restingPulse => 2,
    variability => 3,
    steps => 500,
    weight => 0.5,
  };
}

/// A connection: how [effect] differs between the days, nights or weeks on
/// one side of [cause] and those on the other. It says what went together,
/// not what caused what.
class Link {
  const Link({
    required this.kind,
    required this.cause,
    required this.split,
    required this.effect,
    required this.withMean,
    required this.withoutMean,
    required this.countWith,
    required this.countWithout,
    required this.strength,
    this.weekday,
  });

  final LinkKind kind;
  final LinkCause cause;
  final LinkSplit split;
  final LinkEffect effect;

  /// The mean of [effect] on the side [cause] names, and on the other.
  final double withMean;
  final double withoutMean;

  /// Days, nights or weeks on each side.
  final int countWith;
  final int countWithout;

  /// The difference in standard deviations, without its sign.
  final double strength;

  /// [DateTime.weekday] for [LinkCause.weekday]. For a night it is the day
  /// the night ended on.
  final int? weekday;

  double get difference => withMean - withoutMean;
}

/// Days a connection looks back, and weeks for [LinkKind.weeks]: three
/// months hold too few weeks to compare.
const int linkDays = 90;
const int linkWeeks = 52;

/// Days, nights or weeks a connection needs on each side.
const int linkDaysAtLeast = 10;
const int linkWeeksAtLeast = 8;

/// The difference a connection needs, in pooled standard deviations.
const double _differenceAtLeast = 0.5;

/// Welch's t a connection needs. Higher than the usual 2, because some sixty
/// comparisons are made and at 2 a few of them would pass by chance.
const double _tAtLeast = 2.8;

/// Days with a value a week needs to count for a mean of steps.
const int _weekDaysAtLeast = 4;

DateTime _day(DateTime date, [int plus = 0]) =>
    DateTime(date.year, date.month, date.day + plus);

double _mean(List<double> values) =>
    values.reduce((a, b) => a + b) / values.length;

double _variance(List<double> values, double mean) {
  var sum = 0.0;
  for (final value in values) {
    sum += (value - mean) * (value - mean);
  }
  return sum / (values.length - 1);
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

/// The one rule every connection has to pass: enough on both sides, a
/// difference that is [worthSaying] and half a standard deviation, and more
/// than chance explains.
({double withMean, double withoutMean, double strength})? _judge(
  List<double> yes,
  List<double> no,
  int atLeast,
  double worthSaying,
) {
  if (yes.length < atLeast || no.length < atLeast) return null;
  final withMean = _mean(yes);
  final withoutMean = _mean(no);
  final withVariance = _variance(yes, withMean);
  final withoutVariance = _variance(no, withoutMean);
  final pooled = math.sqrt(
    ((yes.length - 1) * withVariance + (no.length - 1) * withoutVariance) /
        (yes.length + no.length - 2),
  );
  final difference = withMean - withoutMean;
  if (difference.abs() < worthSaying) return null;
  // Two sides that never vary and still differ are as clear as it gets.
  if (pooled == 0) {
    return (
      withMean: withMean,
      withoutMean: withoutMean,
      strength: double.infinity,
    );
  }
  final strength = (difference / pooled).abs();
  if (strength < _differenceAtLeast) return null;
  final error = math.sqrt(
    withVariance / yes.length + withoutVariance / no.length,
  );
  if ((difference / error).abs() < _tAtLeast) return null;
  return (withMean: withMean, withoutMean: withoutMean, strength: strength);
}

/// What was measured for one cause and one effect: the cause's value and
/// the effect's, pair by pair.
typedef _Pairs = List<(double, double)>;

Link? _linkOf(
  LinkKind kind,
  LinkCause cause,
  LinkSplit split,
  LinkEffect effect,
  _Pairs pairs,
  bool Function(double cause) onSide,
  int atLeast, {
  int? weekday,
}) {
  final judged = _judge(
    [
      for (final (value, result) in pairs)
        if (onSide(value)) result,
    ],
    [
      for (final (value, result) in pairs)
        if (!onSide(value)) result,
    ],
    atLeast,
    effect.worthSaying,
  );
  if (judged == null) return null;
  var yes = 0;
  for (final (value, _) in pairs) {
    if (onSide(value)) yes++;
  }
  return Link(
    kind: kind,
    cause: cause,
    split: split,
    effect: effect,
    withMean: judged.withMean,
    withoutMean: judged.withoutMean,
    countWith: yes,
    countWithout: pairs.length - yes,
    strength: judged.strength,
    weekday: weekday,
  );
}

/// Splits at [goal] where both sides then hold enough, and at the own
/// median otherwise: somebody who never reaches a goal still has days with
/// more and days with less.
Link? _thresholdLink(
  LinkKind kind,
  LinkCause cause,
  LinkEffect effect,
  _Pairs pairs,
  int atLeast, {
  double? goal,
  bool below = false,
}) {
  if (pairs.length < atLeast * 2) return null;
  if (goal != null) {
    var reached = 0;
    for (final (value, _) in pairs) {
      if (value >= goal) reached++;
    }
    if (reached >= atLeast && pairs.length - reached >= atLeast) {
      return _linkOf(
        kind,
        cause,
        LinkSplit.goal,
        effect,
        pairs,
        (value) => value >= goal,
        atLeast,
      );
    }
  }
  final median = _median([for (final (value, _) in pairs) value]);
  return _linkOf(
    kind,
    cause,
    LinkSplit.usual,
    effect,
    pairs,
    below ? (value) => value < median : (value) => value > median,
    atLeast,
  );
}

double? _nightEffect(LinkEffect effect, SleepNight night, GoalData data) =>
    switch (effect) {
      LinkEffect.asleep => night.asleepMinutes.toDouble(),
      LinkEffect.sleepScore => sleepScore(
        night,
        data.sleepGoalHours,
        data.nights,
      ).total.toDouble(),
      LinkEffect.deep =>
        night.hasStages ? night.minutesIn(SleepStage.deep).toDouble() : null,
      LinkEffect.bedtime => bedtimeOnAxis(night).toDouble(),
      _ => null,
    };

const _nightEffects = [
  LinkEffect.asleep,
  LinkEffect.sleepScore,
  LinkEffect.deep,
  LinkEffect.bedtime,
];

const _dayEffects = [
  LinkEffect.recovery,
  LinkEffect.restingPulse,
  LinkEffect.variability,
  LinkEffect.steps,
];

/// The connections in the numbers of the [linkDays] days up to [until], the
/// strongest first. [until] is the last day that counts, so a caller that
/// shows today passes yesterday: today is not over. Only what passes the
/// rule of [_judge] is returned, which may be nothing.
List<Link> findLinks({
  required GoalData data,
  required double Function(Goal goal) targetOf,
  required DateTime until,
  Set<LinkKind> kinds = const {
    LinkKind.dayToNight,
    LinkKind.nightToDay,
    LinkKind.weekday,
    LinkKind.weeks,
  },
}) {
  final last = _day(until);
  final nights = [
    ...nightsBefore(data.nights, last, linkDays - 1),
    ?nightOn(data.nights, last),
  ];
  final links = <Link>[];
  void add(Link? link) {
    if (link != null) links.add(link);
  }

  if (kinds.contains(LinkKind.dayToNight)) {
    final workoutDays = {
      for (final workout in data.workouts) dayKey(workout.start),
    };
    for (final effect in _nightEffects) {
      final results = [
        for (final night in nights)
          if (_nightEffect(effect, night, data) case final value?)
            (_day(night.date, -1), value),
      ];
      add(
        _linkOf(
          LinkKind.dayToNight,
          LinkCause.workout,
          LinkSplit.yesNo,
          effect,
          [
            for (final (day, value) in results)
              (workoutDays.contains(dayKey(day)) ? 1.0 : 0.0, value),
          ],
          (value) => value > 0,
          linkDaysAtLeast,
        ),
      );
      for (final (cause, metric, goal) in const [
        (LinkCause.steps, Metric.steps, Goal.steps),
        (LinkCause.activeEnergy, Metric.activeEnergy, Goal.activeEnergy),
        (LinkCause.intensity, Metric.intensityMinutes, Goal.intensityMinutes),
        (LinkCause.water, Metric.water, Goal.water),
        (LinkCause.intake, Metric.energyIntake, null),
      ]) {
        add(
          _thresholdLink(
            LinkKind.dayToNight,
            cause,
            effect,
            [
              for (final (day, value) in results)
                if (data.valueOf(metric, day) case final amount?)
                  (amount, value),
            ],
            linkDaysAtLeast,
            goal: goal == null ? null : targetOf(goal),
          ),
        );
      }
    }
  }

  if (kinds.contains(LinkKind.nightToDay)) {
    double? dayEffect(LinkEffect effect, DateTime day) => switch (effect) {
      LinkEffect.recovery => recoveryOf(
        day: day,
        valueOf: data.valueOf,
        nights: data.nights,
        sleepGoalHours: data.sleepGoalHours,
      ).total?.toDouble(),
      LinkEffect.restingPulse => data.valueOf(Metric.restingHeartRate, day),
      LinkEffect.variability => data.valueOf(Metric.heartRateVariability, day),
      LinkEffect.steps => data.valueOf(Metric.steps, day),
      _ => null,
    };
    for (final effect in _dayEffects) {
      final results = [
        for (final night in nights)
          if (dayEffect(effect, night.date) case final value?) (night, value),
      ];
      // The recovery counts the night's length itself, so setting it
      // against that length or the score would find what was put in.
      if (effect != LinkEffect.recovery) {
        add(
          _thresholdLink(
            LinkKind.nightToDay,
            LinkCause.asleep,
            effect,
            [
              for (final (night, value) in results)
                (night.asleepMinutes.toDouble(), value),
            ],
            linkDaysAtLeast,
            goal: data.sleepGoalHours * 60,
          ),
        );
        add(
          _thresholdLink(LinkKind.nightToDay, LinkCause.sleepScore, effect, [
            for (final (night, value) in results)
              (
                sleepScore(
                  night,
                  data.sleepGoalHours,
                  data.nights,
                ).total.toDouble(),
                value,
              ),
          ], linkDaysAtLeast),
        );
      }
      add(
        _thresholdLink(
          LinkKind.nightToDay,
          LinkCause.earlyBed,
          effect,
          [
            for (final (night, value) in results)
              (bedtimeOnAxis(night).toDouble(), value),
          ],
          linkDaysAtLeast,
          below: true,
        ),
      );
    }
  }

  if (kinds.contains(LinkKind.weekday)) {
    final first = _day(last, 1 - linkDays);
    final measured = <LinkEffect, List<(DateTime, double)>>{
      LinkEffect.steps: [
        for (var day = first; !day.isAfter(last); day = _day(day, 1))
          if (data.valueOf(Metric.steps, day) case final value?) (day, value),
      ],
      LinkEffect.asleep: [
        for (final night in nights)
          (night.date, night.asleepMinutes.toDouble()),
      ],
      LinkEffect.bedtime: [
        for (final night in nights)
          (night.date, bedtimeOnAxis(night).toDouble()),
      ],
    };
    for (final MapEntry(key: effect, value: values) in measured.entries) {
      Link? strongest;
      for (var weekday = 1; weekday <= 7; weekday++) {
        final link = _linkOf(
          LinkKind.weekday,
          LinkCause.weekday,
          LinkSplit.yesNo,
          effect,
          [
            for (final (day, value) in values)
              (day.weekday == weekday ? 1.0 : 0.0, value),
          ],
          (value) => value > 0,
          linkDaysAtLeast,
          weekday: weekday,
        );
        if (link != null &&
            (strongest == null || link.strength > strongest.strength)) {
          strongest = link;
        }
      }
      add(strongest);
    }
  }

  if (kinds.contains(LinkKind.weeks)) {
    // The last whole week ends on the Sunday on or before [until].
    final lastMonday = _day(last, -((last.weekday % 7) + 6));
    final byWeek = <int, int>{};
    for (final workout in data.workouts) {
      final key = dayKey(weekStart(workout.start));
      byWeek[key] = (byWeek[key] ?? 0) + 1;
    }
    double? weekMean(Metric metric, DateTime monday, int atLeast) {
      final values = [
        for (var i = 0; i < 7; i++) ?data.valueOf(metric, _day(monday, i)),
      ];
      return values.length < atLeast ? null : _mean(values);
    }

    final weeks = [
      for (var back = linkWeeks - 1; back >= 0; back--)
        _day(lastMonday, -7 * back),
    ];
    for (final (effect, metric, atLeast) in const [
      (LinkEffect.restingPulse, Metric.restingHeartRate, 3),
      (LinkEffect.variability, Metric.heartRateVariability, 3),
      (LinkEffect.weight, Metric.weight, 1),
    ]) {
      final results = [
        for (final monday in weeks)
          if (weekMean(metric, monday, atLeast) case final value?)
            (monday, value),
      ];
      add(
        _thresholdLink(LinkKind.weeks, LinkCause.weekSteps, effect, [
          for (final (monday, value) in results)
            if (weekMean(Metric.steps, monday, _weekDaysAtLeast)
                case final steps?)
              (steps, value),
        ], linkWeeksAtLeast),
      );
      add(
        _thresholdLink(LinkKind.weeks, LinkCause.weekWorkouts, effect, [
          for (final (monday, value) in results)
            // A week without steps is a week the app knows nothing of,
            // not a week without workouts.
            if (weekMean(Metric.steps, monday, _weekDaysAtLeast) != null)
              ((byWeek[dayKey(monday)] ?? 0).toDouble(), value),
        ], linkWeeksAtLeast),
      );
    }
  }

  return links..sort((a, b) => b.strength.compareTo(a.strength));
}

/// Nights in the stretch a connection looks at: what the page says is still
/// missing while there are too few.
int linkNights(List<SleepNight> nights, DateTime until) =>
    nightsBefore(nights, _day(until, 1), linkDays).length;
