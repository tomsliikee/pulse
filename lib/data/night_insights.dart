import 'dart:math' as math;

import 'health_history.dart';
import 'models.dart';
import 'sleep_insights.dart';
import 'workout_insights.dart' show Trend;

const int _minutesPerDay = 24 * 60;

/// The nights of [all] (oldest first) that ended on the [days] days before
/// [date], oldest first.
List<SleepNight> nightsBefore(List<SleepNight> all, DateTime date, int days) {
  final end = dayKey(date);
  // The first night that is not before [date].
  var low = 0;
  var high = all.length;
  while (low < high) {
    final middle = (low + high) ~/ 2;
    if (dayKey(all[middle].date) < end) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  var from = low;
  while (from > 0 && dayKey(all[from - 1].date) >= end - days) {
    from--;
  }
  return all.sublist(from, low);
}

/// What the score of a night is made of.
enum ScorePart {
  duration(40),
  stages(25),
  efficiency(20),
  regularity(15);

  const ScorePart(this.points);

  /// The most this part can give.
  final int points;
}

/// The app's own score of a night, from 1 to 100, with what each part gave.
/// Health Connect stores no score; this one is a rule of the app and not a
/// measurement, and is shown as an estimate.
class SleepScore {
  const SleepScore(this.parts);

  /// The points each part earned. A part that could not be judged (no
  /// stages recorded, too few nights before) is missing, and the others are
  /// scaled up to make the hundred.
  final Map<ScorePart, double> parts;

  int get total {
    var earned = 0.0;
    var possible = 0;
    for (final MapEntry(key: part, value: points) in parts.entries) {
      earned += points;
      possible += part.points;
    }
    if (possible == 0) return 1;
    return (earned / possible * 100).round().clamp(1, 100);
  }
}

/// Nights before that the regularity of a bedtime is judged against.
const int _regularityNights = 7;
const int _regularityAtLeast = 3;

double _between(double value, double worst, double best) =>
    ((value - worst) / (best - worst)).clamp(0.0, 1.0);

/// The score of [night] against a goal of [goalHours], with [all] nights the
/// app knows (oldest first) for the regularity.
SleepScore sleepScore(
  SleepNight night,
  double goalHours,
  List<SleepNight> all,
) {
  final parts = <ScorePart, double>{
    ScorePart.duration:
        ScorePart.duration.points *
        _between(night.asleepMinutes.toDouble(), 0, goalHours * 60),
  };

  if (night.hasStages) {
    // Each of the two counts half, against the lower end of what is typical.
    var stages = 0.0;
    for (final stage in const [SleepStage.deep, SleepStage.rem]) {
      final share = stageShare(night, stage) ?? 0;
      stages += _between(share, 0, typicalStageShare[stage]!.$1) / 2;
    }
    parts[ScorePart.stages] = ScorePart.stages.points * stages;
    // Without stages nobody knows how long the user lay awake.
    parts[ScorePart.efficiency] =
        ScorePart.efficiency.points *
        _between(sleepEfficiency(night), 0.70, 0.90);
  }

  final before = nightsBefore(all, night.date, _regularityNights);
  if (before.length >= _regularityAtLeast) {
    final usual =
        before.map(bedtimeOnAxis).reduce((a, b) => a + b) / before.length;
    final off = (bedtimeOnAxis(night) - usual).abs();
    parts[ScorePart.regularity] =
        ScorePart.regularity.points * _between(off, 90, 15);
  }
  return SleepScore(parts);
}

/// What can be said about one night in numbers.
enum NightMeasure {
  score,
  asleep,
  deep,
  rem,
  light,
  awake,

  /// The share of the time in bed spent asleep, from 0 to 1.
  efficiency,

  /// Minutes on the axis of [bedtimeOnAxis].
  bedtime,
  wake;

  /// Whether a higher value is the better one; null where neither is.
  bool? get higherIsBetter => switch (this) {
    score || asleep || deep || rem || efficiency => true,
    awake => false,
    light || bedtime || wake => null,
  };

  /// Differences up to this are the same; nobody sleeps to the minute.
  double get tolerance => switch (this) {
    score => 1,
    efficiency => 0.01,
    asleep => 5,
    _ => 3,
  };

  SleepStage? get stage => switch (this) {
    deep => SleepStage.deep,
    rem => SleepStage.rem,
    light => SleepStage.light,
    awake => SleepStage.awake,
    _ => null,
  };
}

class NightComparison {
  const NightComparison({
    required this.measure,
    required this.value,
    this.previous,
    this.average,
  });

  final NightMeasure measure;
  final double value;

  /// The night before this one.
  final double? previous;

  /// The mean of the nights of the week before it.
  final double? average;

  Trend get againstPrevious => _trend(previous);
  Trend get againstAverage => _trend(average);

  Trend _trend(double? other) {
    final higher = measure.higherIsBetter;
    if (other == null || higher == null) return Trend.neutral;
    if ((value - other).abs() <= measure.tolerance) return Trend.same;
    return (value > other) == higher ? Trend.better : Trend.worse;
  }
}

enum NightTipKind {
  /// Too few nights before to say anything.
  fewToCompare,
  irregular,
  debt,
  littleDeep,
  longAwake,
  lateToBed,
  keepGoing,
}

class NightTip {
  const NightTip(this.kind, [this.minutes = 0]);

  final NightTipKind kind;

  /// What the rule measured, in minutes.
  final int minutes;
}

/// A night seen against the ones before it: what was better, what was not,
/// and what to do about it. The rules are the app's own and simple on
/// purpose; they are hints, not sleep medicine.
class NightInsights {
  NightInsights._({
    required this.night,
    required this.score,
    required this.week,
    required this.measures,
    required this.tips,
  });

  /// Days before the night that count as its week.
  static const int weekDays = 7;

  static const int _usualDays = 30;
  static const int _tipsAtMost = 3;
  static const int _irregularSpread = 60;
  static const int _debtMinutes = 180;
  static const int _awakeMinutes = 45;
  static const int _lateMinutes = 60;

  final SleepNight night;
  final SleepScore score;

  /// The nights of the week before this one, oldest first.
  final List<SleepNight> week;
  final List<NightComparison> measures;
  final List<NightTip> tips;

  NightComparison? measure(NightMeasure wanted) {
    for (final comparison in measures) {
      if (comparison.measure == wanted) return comparison;
    }
    return null;
  }

  /// The value of [measure] for [night], or null when it was not recorded.
  static double? valueOf(
    SleepNight night,
    NightMeasure measure,
    double goalHours,
    List<SleepNight> all,
  ) => switch (measure) {
    NightMeasure.score => sleepScore(night, goalHours, all).total.toDouble(),
    NightMeasure.asleep => night.asleepMinutes.toDouble(),
    NightMeasure.efficiency => night.hasStages ? sleepEfficiency(night) : null,
    NightMeasure.bedtime => bedtimeOnAxis(night).toDouble(),
    NightMeasure.wake => (bedtimeOnAxis(night) + night.totalMinutes).toDouble(),
    _ => night.hasStages ? night.minutesIn(measure.stage!).toDouble() : null,
  };

  /// [night] against [all] nights the app knows, oldest first, with a goal
  /// of [goalHours] a night.
  factory NightInsights.of(
    SleepNight night,
    List<SleepNight> all,
    double goalHours,
  ) {
    final week = nightsBefore(all, night.date, weekDays);
    double? value(SleepNight of, NightMeasure measure) =>
        valueOf(of, measure, goalHours, all);

    final measures = <NightComparison>[];
    for (final measure in NightMeasure.values) {
      final own = value(night, measure);
      if (own == null) continue;
      final before = [for (final other in week) ?value(other, measure)];
      measures.add(
        NightComparison(
          measure: measure,
          value: own,
          previous: week.isEmpty ? null : value(week.last, measure),
          average: before.isEmpty
              ? null
              : before.reduce((a, b) => a + b) / before.length,
        ),
      );
    }

    return NightInsights._(
      night: night,
      score: sleepScore(night, goalHours, all),
      week: week,
      measures: measures,
      tips: _tips(night, all, week, goalHours),
    );
  }

  static List<NightTip> _tips(
    SleepNight night,
    List<SleepNight> all,
    List<SleepNight> week,
    double goalHours,
  ) {
    if (week.length < 3) return const [NightTip(NightTipKind.fewToCompare)];
    final tips = <NightTip>[];
    // The seven nights up to this one, as the debt is shown on the page.
    final withThis = [...week, night];
    if (withThis.length > weekDays) withThis.removeAt(0);

    final debt = sleepDebt(withThis, goalHours);
    if (debt.minutes >= _debtMinutes) {
      tips.add(NightTip(NightTipKind.debt, debt.minutes));
    }

    final spread = sleepRegularity(withThis)?.bedtimeSpread ?? 0;
    if (spread > _irregularSpread) {
      tips.add(NightTip(NightTipKind.irregular, spread));
    }

    final usualBedtime =
        week.map(bedtimeOnAxis).reduce((a, b) => a + b) / week.length;
    final late = (bedtimeOnAxis(night) - usualBedtime).round();
    if (late > _lateMinutes) tips.add(NightTip(NightTipKind.lateToBed, late));

    if (night.hasStages) {
      final awake = night.minutesIn(SleepStage.awake);
      if (awake > _awakeMinutes) {
        tips.add(NightTip(NightTipKind.longAwake, awake));
      }
      final deep = night.minutesIn(SleepStage.deep);
      final usual = ownRange([
        for (final other in nightsBefore(all, night.date, _usualDays))
          if (other.hasStages) other.minutesIn(SleepStage.deep).toDouble(),
      ]);
      if (usual != null && deep < usual.$1) {
        tips.add(NightTip(NightTipKind.littleDeep, deep));
      }
    }

    if (tips.isEmpty) return const [NightTip(NightTipKind.keepGoing)];
    return tips.length <= _tipsAtMost ? tips : tips.sublist(0, _tipsAtMost);
  }
}

/// What the day before a night is split by.
enum SleepLinkKind { workout, steps }

/// An observation: nights after one kind of day against the other nights.
/// It says what went together, not what caused what.
class SleepLink {
  const SleepLink({
    required this.kind,
    required this.measure,
    required this.minutes,
    required this.nightsWith,
    required this.nightsWithout,
  });

  final SleepLinkKind kind;

  /// [NightMeasure.asleep] or [NightMeasure.deep].
  final NightMeasure measure;

  /// How much more (or, negative, less) of [measure] the nights after such a
  /// day had on average.
  final int minutes;
  final int nightsWith;
  final int nightsWithout;
}

/// Nights a link needs on each side before it is shown.
const int sleepLinkNights = 5;
const int _linkMinutes = 10;
const int _linkDays = 90;

/// How the [nights] up to [until] differ after days with a workout and
/// after days that reached [stepGoal], looking back three months. [stepsOn]
/// gives the steps of a day, or null when there are none.
List<SleepLink> sleepLinks({
  required List<SleepNight> nights,
  required DateTime until,
  required List<Workout> workouts,
  required double? Function(DateTime day) stepsOn,
  required int stepGoal,
}) {
  final recent = [
    ...nightsBefore(nights, until, _linkDays),
    for (final night in nights)
      if (dayKey(night.date) == dayKey(until)) night,
  ];
  final workoutDays = {for (final workout in workouts) dayKey(workout.start)};
  final links = <SleepLink>[];

  void compare(SleepLinkKind kind, bool? Function(DateTime dayBefore) split) {
    for (final measure in const [NightMeasure.asleep, NightMeasure.deep]) {
      final yes = <int>[];
      final no = <int>[];
      for (final night in recent) {
        if (measure == NightMeasure.deep && !night.hasStages) continue;
        final side = split(
          DateTime(night.date.year, night.date.month, night.date.day - 1),
        );
        if (side == null) continue;
        (side ? yes : no).add(
          measure == NightMeasure.deep
              ? night.minutesIn(SleepStage.deep)
              : night.asleepMinutes,
        );
      }
      if (yes.length < sleepLinkNights || no.length < sleepLinkNights) continue;
      double mean(List<int> values) =>
          values.reduce((a, b) => a + b) / values.length;
      final difference = (mean(yes) - mean(no)).round();
      if (difference.abs() < _linkMinutes) continue;
      links.add(
        SleepLink(
          kind: kind,
          measure: measure,
          minutes: difference,
          nightsWith: yes.length,
          nightsWithout: no.length,
        ),
      );
    }
  }

  compare(SleepLinkKind.workout, (day) => workoutDays.contains(dayKey(day)));
  compare(SleepLinkKind.steps, (day) {
    final steps = stepsOn(day);
    return steps == null ? null : steps >= stepGoal;
  });
  return links;
}

/// When to go to bed tonight.
class Tonight {
  const Tonight({
    required this.bedtimeMinute,
    required this.wakeMinute,
    required this.catchUpMinutes,
  });

  /// Minute of the day, like [SleepNight.bedtimeMinute].
  final int bedtimeMinute;

  /// When the user usually gets up.
  final int wakeMinute;

  /// What was added to the goal to pay off some of the week's debt.
  final int catchUpMinutes;
}

const int _wakeDays = 14;
const int _catchUpAtMost = 30;

/// The bedtime that gives [goalHours] of sleep before the usual time of
/// getting up, a little earlier while the week is in debt. Null with fewer
/// than three nights in the two weeks before [today].
Tonight? tonight(List<SleepNight> all, double goalHours, DateTime today) {
  final tomorrow = DateTime(today.year, today.month, today.day + 1);
  final recent = nightsBefore(all, tomorrow, _wakeDays);
  if (recent.length < 3) return null;
  final wake =
      recent
          .map((night) => bedtimeOnAxis(night) + night.totalMinutes)
          .reduce((a, b) => a + b) /
      recent.length;
  final debt = sleepDebt(
    nightsBefore(all, tomorrow, NightInsights.weekDays),
    goalHours,
  );
  // A seventh of the debt a night, in steps of five minutes.
  final catchUp = math.min(
    _catchUpAtMost,
    (debt.minutes / NightInsights.weekDays / 5).round() * 5,
  );
  final bedtime = wake - goalHours * 60 - catchUp;
  return Tonight(
    bedtimeMinute: ((bedtime / 5).round() * 5) % _minutesPerDay,
    wakeMinute: ((wake / 5).round() * 5) % _minutesPerDay,
    catchUpMinutes: catchUp,
  );
}
