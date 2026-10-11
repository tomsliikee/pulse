import 'day_insights.dart';
import 'goals.dart';
import 'health_history.dart';
import 'metric_catalog.dart';
import 'models.dart';
import 'night_insights.dart';
import 'recovery.dart';
import 'sleep_insights.dart';
import 'workout_insights.dart' show Trend;

/// The weekday and hour the report of a week is ready: Sunday evening, when
/// most of the last day is known.
const int weekReportWeekday = DateTime.sunday;
const int weekReportHour = 19;

/// What a week is summed up in, each as a mean per day or night.
enum WeekMeasure {
  steps,
  activeEnergy,

  /// Minutes.
  asleep,
  sleepScore,
  recovery,
  restingPulse;

  bool get higherIsBetter => this != restingPulse;

  /// Differences up to this are the same.
  double get tolerance => switch (this) {
    steps => 100,
    activeEnergy => 10,
    asleep => 5,
    sleepScore || recovery || restingPulse => 1,
  };
}

/// One number of a week against the weeks before.
class WeekComparison {
  const WeekComparison({
    required this.measure,
    required this.value,
    this.previous,
    this.usual,
  });

  final WeekMeasure measure;
  final double value;

  /// The week before.
  final double? previous;

  /// The mean of the four weeks before that have a value.
  final double? usual;

  Trend get againstPrevious => _trend(previous);
  Trend get againstUsual => _trend(usual);

  Trend _trend(double? other) {
    if (other == null) return Trend.neutral;
    if ((value - other).abs() <= measure.tolerance) return Trend.same;
    return (value > other) == measure.higherIsBetter
        ? Trend.better
        : Trend.worse;
  }
}

/// A day of the week that was the highest the app has ever seen.
class WeekRecord {
  const WeekRecord({
    required this.measure,
    required this.day,
    required this.value,
  });

  /// One with [DayMeasure.hasBest].
  final DayMeasure measure;
  final DateTime day;
  final double value;
}

/// A goal over the week.
class WeekGoal {
  const WeekGoal({
    required this.row,
    required this.target,
    required this.streak,
  });

  /// Seven marks, or one for a weekly goal.
  final GoalRow row;
  final double target;

  /// Days or weeks in a row at the goal, counted from the end of the week.
  final int streak;
}

/// One week, Monday to Sunday, seen against the weeks before it.
class WeekReport {
  const WeekReport({
    required this.monday,
    required this.running,
    required this.dayScores,
    required this.score,
    required this.previousScore,
    required this.measures,
    required this.bestDay,
    required this.bestNight,
    required this.bestNightScore,
    required this.records,
    required this.goals,
    required this.workouts,
    required this.nights,
    required this.debt,
    required this.regularity,
  });

  final DateTime monday;

  /// Whether the week is not over yet.
  final bool running;

  /// The day score of each of the seven days; null for a day nothing is
  /// known about or that has not come.
  final List<int?> dayScores;

  /// The mean of [dayScores]; null for a week without any.
  final int? score;
  final int? previousScore;
  final List<WeekComparison> measures;

  /// Index into [dayScores] of the highest; the earlier one on a tie.
  final int? bestDay;
  final SleepNight? bestNight;
  final int? bestNightScore;
  final List<WeekRecord> records;
  final List<WeekGoal> goals;

  /// The workouts that started in the week, oldest first.
  final List<Workout> workouts;

  /// The nights that ended in the week, oldest first.
  final List<SleepNight> nights;
  final SleepDebt debt;
  final SleepRegularity? regularity;

  DateTime get sunday => DateTime(monday.year, monday.month, monday.day + 6);

  /// Whether the app knows anything about the week.
  bool get isEmpty =>
      score == null && workouts.isEmpty && nights.isEmpty && measures.isEmpty;

  WeekComparison? measure(WeekMeasure wanted) {
    for (final comparison in measures) {
      if (comparison.measure == wanted) return comparison;
    }
    return null;
  }

  int get workoutMinutes =>
      workouts.fold(0, (sum, workout) => sum + workout.minutes);

  int get workoutEnergy =>
      workouts.fold(0, (sum, workout) => sum + (workout.kcal ?? 0));
}

DateTime _day(DateTime date, [int plus = 0]) =>
    DateTime(date.year, date.month, date.day + plus);

double? _meanOf(Iterable<double?> values) {
  var sum = 0.0;
  var count = 0;
  for (final value in values) {
    if (value == null) continue;
    sum += value;
    count++;
  }
  return count == 0 ? null : sum / count;
}

/// The Monday of the week whose report is the latest one ready at [now]:
/// this week from Sunday evening, the week before until then.
DateTime latestReportWeek(DateTime now) {
  final monday = weekStart(now);
  final ready = now.weekday == weekReportWeekday && now.hour >= weekReportHour;
  return ready ? monday : _day(monday, -7);
}

/// Whether the Today page shows the report's tile at [now]: from Sunday
/// evening until Monday ends.
bool weekTileShown(DateTime now) =>
    now.weekday == DateTime.monday ||
    (now.weekday == weekReportWeekday && now.hour >= weekReportHour);

/// The next moment after [now] at which [weekTileShown] changes.
DateTime weekTileEdge(DateTime now) {
  if (now.weekday == DateTime.monday) return _day(now, 1);
  if (weekTileShown(now)) return _day(now, 2);
  final sunday = _day(now, weekReportWeekday - now.weekday);
  return DateTime(sunday.year, sunday.month, sunday.day, weekReportHour);
}

/// The day score of each of the seven days from [monday]; null for a day
/// nothing is known about or that lies after [today].
List<int?> weekDayScores({
  required DateTime monday,
  required DayValue valueOf,
  required List<SleepNight> nights,
  required DayGoals goals,
  required DateTime today,
}) => [
  for (var i = 0; i < 7; i++)
    if (dayKey(_day(monday, i)) > dayKey(today))
      null
    else
      dayScore(
        day: _day(monday, i),
        valueOf: valueOf,
        nights: nights,
        goals: goals,
      ).total,
];

/// The score of a week from its [weekDayScores]: their mean, or null for a
/// week without any.
int? weekScoreOf(List<int?> scores) =>
    _meanOf(scores.map((score) => score?.toDouble()))?.round();

/// The week that begins on [monday]. [today] decides what is still running.
/// [history] gives the records, where the app has loaded it; [goals] are
/// the goals the user follows with their targets.
WeekReport weekReport({
  required DateTime monday,
  required GoalData data,
  required DayGoals dayGoals,
  required Map<Goal, double> goals,
  required DateTime today,
  HealthHistory? history,
}) {
  final start = _day(monday);
  final todayKey = dayKey(today);

  List<int?> scoresOf(DateTime from) => weekDayScores(
    monday: from,
    valueOf: data.valueOf,
    nights: data.nights,
    goals: dayGoals,
    today: today,
  );

  double? value(WeekMeasure measure, DateTime from) {
    Iterable<double?> days(double? Function(DateTime day) of) sync* {
      for (var i = 0; i < 7; i++) {
        final day = _day(from, i);
        if (dayKey(day) <= todayKey) yield of(day);
      }
    }

    return _meanOf(switch (measure) {
      WeekMeasure.steps => days((day) => data.valueOf(Metric.steps, day)),
      WeekMeasure.activeEnergy => days(
        (day) => data.valueOf(Metric.activeEnergy, day),
      ),
      WeekMeasure.asleep => days(
        (day) => nightOn(data.nights, day)?.asleepMinutes.toDouble(),
      ),
      WeekMeasure.sleepScore => days((day) {
        final night = nightOn(data.nights, day);
        return night == null
            ? null
            : sleepScore(
                night,
                data.sleepGoalHours,
                data.nights,
              ).total.toDouble();
      }),
      WeekMeasure.recovery => days(
        (day) => recoveryOf(
          day: day,
          valueOf: data.valueOf,
          nights: data.nights,
          sleepGoalHours: data.sleepGoalHours,
        ).total?.toDouble(),
      ),
      WeekMeasure.restingPulse => days(
        (day) => data.valueOf(Metric.restingHeartRate, day),
      ),
    });
  }

  final measures = <WeekComparison>[];
  for (final measure in WeekMeasure.values) {
    final own = value(measure, start);
    if (own == null) continue;
    measures.add(
      WeekComparison(
        measure: measure,
        value: own,
        previous: value(measure, _day(start, -7)),
        usual: _meanOf([
          for (var back = 1; back <= 4; back++)
            value(measure, _day(start, -7 * back)),
        ]),
      ),
    );
  }

  final scores = scoresOf(start);
  int? bestDay;
  for (var i = 0; i < scores.length; i++) {
    final score = scores[i];
    if (score != null && (bestDay == null || score > scores[bestDay]!)) {
      bestDay = i;
    }
  }

  final nights = [...nightsBefore(data.nights, _day(start, 7), 7)];
  SleepNight? bestNight;
  int? bestNightScore;
  for (final night in nights) {
    final score = sleepScore(night, data.sleepGoalHours, data.nights).total;
    if (bestNightScore == null || score > bestNightScore) {
      bestNight = night;
      bestNightScore = score;
    }
  }

  final records = <WeekRecord>[];
  if (history != null) {
    for (final measure in DayMeasure.values) {
      if (!measure.hasBest) continue;
      final metric = measure.metric!;
      DateTime? day;
      var highest = 0.0;
      for (var i = 0; i < 7; i++) {
        final other = _day(start, i);
        if (dayKey(other) > todayKey) break;
        final own = data.valueOf(metric, other) ?? 0;
        if (own > highest) {
          highest = own;
          day = other;
        }
      }
      if (day == null) continue;
      final earlier = history.between(
        metric,
        history.firstDay(metric) ?? start,
        _day(start, -1),
      );
      if (earlier.length >= DayInsights.bestAmong - 1 &&
          earlier.every((other) => other < highest)) {
        records.add(WeekRecord(measure: measure, day: day, value: highest));
      }
    }
  }

  final sunday = _day(start, 6);
  // A streak is counted up to the week's end, or to today while it runs.
  final streakDay = dayKey(sunday) > todayKey ? today : sunday;
  final startKey = dayKey(start);
  return WeekReport(
    monday: start,
    running: dayKey(sunday) >= todayKey,
    dayScores: scores,
    score: weekScoreOf(scores),
    previousScore: weekScoreOf(scoresOf(_day(start, -7))),
    measures: measures,
    bestDay: bestDay,
    bestNight: bestNight,
    bestNightScore: bestNightScore,
    records: records,
    goals: [
      for (final MapEntry(key: goal, value: target) in goals.entries)
        WeekGoal(
          row: goalRow(goal, target, start, sunday, today, data),
          target: target,
          streak: goalStreak(goal, target, streakDay, data),
        ),
    ],
    workouts: [
      for (final workout in data.workouts)
        if (dayKey(workout.start) >= startKey &&
            dayKey(workout.start) < startKey + 7)
          workout,
    ],
    nights: nights,
    debt: sleepDebt(nights, data.sleepGoalHours),
    regularity: sleepRegularity(nights),
  );
}
