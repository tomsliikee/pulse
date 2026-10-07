import 'day_insights.dart';
import 'health_history.dart';
import 'metric_catalog.dart';
import 'models.dart';
import 'night_insights.dart';

/// What the goals are sorted by where they are chosen.
enum GoalGroup { movement, rest, training, nutrition }

/// Something to reach every day or every week. The catalog the user picks
/// from; a target is in the unit the value is measured in.
enum Goal {
  steps(GoalGroup.movement, 10000, min: 4000, max: 20000, step: 1000),
  activeEnergy(GoalGroup.movement, 500, min: 200, max: 1500, step: 50),
  intensityMinutes(GoalGroup.movement, 30, min: 10, max: 120, step: 5),

  /// Kilometres.
  distance(GoalGroup.movement, 6, min: 1, max: 20, step: 0.5),
  floors(GoalGroup.movement, 10, min: 2, max: 40, step: 1),

  /// Hours asleep in the night that ended on the day.
  sleepDuration(GoalGroup.rest, 8, min: 5, max: 10, step: 0.5),
  sleepScore(GoalGroup.rest, 80, min: 50, max: 95, step: 5),

  /// Litres.
  water(GoalGroup.rest, 2.4, min: 1, max: 4, step: 0.2),
  workouts(GoalGroup.training, 3, min: 1, max: 7, step: 1, weekly: true),
  trainingMinutes(
    GoalGroup.training,
    150,
    min: 30,
    max: 600,
    step: 30,
    weekly: true,
  ),

  /// Kilocalories eaten; a limit to stay under.
  energyIntake(
    GoalGroup.nutrition,
    2200,
    min: 1200,
    max: 4000,
    step: 100,
    isLimit: true,
  ),

  /// Grams.
  protein(GoalGroup.nutrition, 80, min: 30, max: 200, step: 10);

  const Goal(
    this.group,
    this.defaultTarget, {
    required this.min,
    required this.max,
    required this.step,
    this.weekly = false,
    this.isLimit = false,
  });

  final GoalGroup group;
  final double defaultTarget;

  /// The range and the step a target can be set in.
  final double min;
  final double max;
  final double step;

  /// Counted over a week from Monday instead of over a day.
  final bool weekly;

  /// Reached by staying at or under the target instead of getting to it.
  final bool isLimit;

  /// The measurement the goal is about, where it is one of the catalog.
  Metric? get metric => switch (this) {
    steps => Metric.steps,
    activeEnergy => Metric.activeEnergy,
    intensityMinutes => Metric.intensityMinutes,
    distance => Metric.distance,
    floors => Metric.floors,
    water => Metric.water,
    energyIntake => Metric.energyIntake,
    protein => Metric.protein,
    sleepDuration || sleepScore || workouts || trainingMinutes => null,
  };

  static Goal? byName(Object? name) {
    for (final goal in values) {
      if (goal.name == name) return goal;
    }
    return null;
  }
}

/// The goals that are on until the user chooses.
const List<Goal> defaultGoals = [
  Goal.steps,
  Goal.activeEnergy,
  Goal.sleepDuration,
  Goal.water,
];

/// What the goals are counted from.
class GoalData {
  const GoalData({
    required this.valueOf,
    required this.nights,
    required this.workouts,
    required this.sleepGoalHours,
  });

  final DayValue valueOf;

  /// Oldest first.
  final List<SleepNight> nights;

  /// Oldest first.
  final List<Workout> workouts;

  /// The sleep score is judged against it.
  final double sleepGoalHours;
}

DateTime _day(DateTime date, [int plus = 0]) =>
    DateTime(date.year, date.month, date.day + plus);

/// The Monday of the week [day] is in.
DateTime weekStart(DateTime day) => _day(day, 1 - day.weekday);

/// The value of [goal] on [day], or over the week [day] is in for a weekly
/// goal. Null when nothing was recorded; a week without a workout is zero.
double? goalValue(Goal goal, DateTime day, GoalData data) {
  switch (goal) {
    case Goal.sleepDuration:
      final night = nightOn(data.nights, day);
      return night == null ? null : night.asleepMinutes / 60;
    case Goal.sleepScore:
      final night = nightOn(data.nights, day);
      return night == null
          ? null
          : sleepScore(
              night,
              data.sleepGoalHours,
              data.nights,
            ).total.toDouble();
    case Goal.workouts || Goal.trainingMinutes:
      final from = dayKey(weekStart(day));
      var count = 0;
      var minutes = 0;
      for (final workout in data.workouts.reversed) {
        final key = dayKey(workout.start);
        if (key < from) break;
        if (key >= from + 7) continue;
        count++;
        minutes += workout.minutes;
      }
      return (goal == Goal.workouts ? count : minutes).toDouble();
    default:
      return data.valueOf(goal.metric!, day);
  }
}

/// How far a goal has come on a day or in a week.
class GoalProgress {
  const GoalProgress({
    required this.goal,
    required this.value,
    required this.target,
  });

  final Goal goal;
  final double? value;
  final double target;

  /// A limit is only kept by somebody who entered something at all.
  bool get reached {
    final value = this.value;
    if (value == null) return false;
    return goal.isLimit ? value > 0 && value <= target : value >= target;
  }

  /// The value as a share of the target, from 0 to 1.
  double get share => ((value ?? 0) / target).clamp(0.0, 1.0);
}

GoalProgress goalProgress(
  Goal goal,
  double target,
  DateTime day,
  GoalData data,
) =>
    GoalProgress(goal: goal, value: goalValue(goal, day, data), target: target);

/// One day, or one week of a weekly goal, in a row of them.
enum GoalMark {
  reached,
  missed,

  /// Nothing recorded.
  none,

  /// Still running and not reached yet.
  open,

  /// Not begun yet.
  ahead,
}

GoalMark _mark(
  Goal goal,
  double target,
  DateTime day,
  DateTime today,
  GoalData data,
) {
  final unit = goal.weekly ? weekStart(day) : day;
  final current = goal.weekly ? weekStart(today) : today;
  if (dayKey(unit) > dayKey(current)) return GoalMark.ahead;
  final progress = goalProgress(goal, target, day, data);
  if (dayKey(unit) == dayKey(current)) {
    // A limit is only kept once the day is over.
    return progress.reached && !goal.isLimit ? GoalMark.reached : GoalMark.open;
  }
  if (progress.value == null) return GoalMark.none;
  return progress.reached ? GoalMark.reached : GoalMark.missed;
}

/// A goal over a span: one mark per day, or per week for a weekly goal.
class GoalRow {
  const GoalRow(this.goal, this.marks);

  final Goal goal;
  final List<GoalMark> marks;

  int get reached => marks.where((mark) => mark == GoalMark.reached).length;

  /// The days or weeks that are over and have something recorded.
  int get counted => marks
      .where((mark) => mark == GoalMark.reached || mark == GoalMark.missed)
      .length;

  /// The share that was reached; null when nothing counts yet.
  double? get rate => counted == 0 ? null : reached / counted;
}

/// [goal] from [from] to [to], both inclusive. A weekly goal has one mark
/// per week that starts in the span.
GoalRow goalRow(
  Goal goal,
  double target,
  DateTime from,
  DateTime to,
  DateTime today,
  GoalData data,
) {
  final marks = <GoalMark>[];
  final last = dayKey(to);
  for (var day = _day(from); dayKey(day) <= last; day = _day(day, 1)) {
    if (goal.weekly && day.weekday != DateTime.monday) continue;
    marks.add(_mark(goal, target, day, today, data));
  }
  return GoalRow(goal, marks);
}

/// The share of [goal] reached in each month of [year]; null for a month
/// in which nothing counts.
List<double?> goalYear(
  Goal goal,
  double target,
  int year,
  DateTime today,
  GoalData data,
) => [
  for (var month = 1; month <= 12; month++)
    goalRow(
      goal,
      target,
      DateTime(year, month),
      DateTime(year, month + 1, 0),
      today,
      data,
    ).rate,
];

/// Days (or weeks) in a row that reached [goal], up to the one before the
/// current, plus the current once it has reached it.
int goalStreak(Goal goal, double target, DateTime today, GoalData data) {
  final stride = goal.weekly ? 7 : 1;
  var streak = _mark(goal, target, today, today, data) == GoalMark.reached
      ? 1
      : 0;
  // Ten years are as far as the history goes.
  for (var back = 1; back < 3660 ~/ stride; back++) {
    final mark = _mark(goal, target, _day(today, -back * stride), today, data);
    if (mark != GoalMark.reached) break;
    streak++;
  }
  return streak;
}
