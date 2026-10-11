import 'package:flutter/foundation.dart';

import 'models.dart';

/// The minutes at a moderate pulse or above that have to follow one another
/// before they count as activity in the fine values.
const int fineRunMinutes = 10;

/// The longest gap between two readings, in minutes, that is filled with the
/// pulse on the way from the one to the other. A wearable does not write
/// every minute; beyond this nobody knows what the pulse did.
const int fineBridgeMinutes = 5;

/// The maximum heart rate the fine values take for someone [age] years old:
/// 208 less 0.7 times the age (Tanaka).
int fineMaxHeartRate(double age) => (208 - 0.7 * age).round();

/// What the fine values have to know about the person.
@immutable
class FineProfile {
  const FineProfile({
    required this.age,
    this.sex,
    this.heightCm,
    this.weightKg,
    this.removedWorkouts = const {},
  });

  final double age;
  final Sex? sex;
  final int? heightCm;

  /// The weight where the days read hold none.
  final double? weightKg;

  /// The keys of the workouts the user took out of the app. The store still
  /// has them; they count for nothing.
  final Set<String> removedWorkouts;

  int get maxHeartRate => fineMaxHeartRate(age);

  @override
  bool operator ==(Object other) =>
      other is FineProfile &&
      other.age == age &&
      other.sex == sex &&
      other.heightCm == heightCm &&
      other.weightKg == weightKg &&
      setEquals(other.removedWorkouts, removedWorkouts);

  @override
  int get hashCode => Object.hash(age, sex, heightCm, weightKg);
}

/// The energy a minute at [bpm] costs in all, in kcal, estimated from the
/// heart rate (Keytel et al., 2005).
double keytelPerMinute(
  double bpm, {
  required double kg,
  required double age,
  required Sex sex,
}) => switch (sex) {
  Sex.male => (-55.0969 + 0.6309 * bpm + 0.1988 * kg + 0.2017 * age) / 4.184,
  Sex.female => (-20.4022 + 0.4472 * bpm - 0.1263 * kg + 0.074 * age) / 4.184,
};

/// The energy a day at rest costs, in kcal (Mifflin-St Jeor).
double restingBurnPerDay({
  required double kg,
  required int heightCm,
  required double age,
  required Sex sex,
}) => 10 * kg + 6.25 * heightCm - 5 * age + (sex == Sex.male ? 5 : -161);

/// What a minute at rest may plausibly cost, in kcal. A base worked out from
/// a source's totals outside of it is not believed.
const double _leastRestingPerMinute = 0.5;
const double _mostRestingPerMinute = 2.5;

/// The energy a minute at rest costs: the estimate from [profile] and [kg]
/// where they allow one, else the source's own base of the day ([total]
/// less [active], over the [minutes] the day has had) where that is
/// plausible. Null where neither can be had.
///
/// The source's base comes second because sources do not agree with
/// themselves: a total that two apps wrote holds the base twice.
double? restingPerMinute({
  required double? total,
  required double? active,
  required int minutes,
  required FineProfile profile,
  required double? kg,
}) {
  final sex = profile.sex;
  final height = profile.heightCm;
  if (sex != null && height != null && kg != null) {
    return restingBurnPerDay(
          kg: kg,
          heightCm: height,
          age: profile.age,
          sex: sex,
        ) /
        Duration.minutesPerDay;
  }
  if (total != null && active != null && minutes > 0) {
    final base = (total - active) / minutes;
    if (base >= _leastRestingPerMinute && base <= _mostRestingPerMinute) {
      return base;
    }
  }
  return null;
}

/// How the fine values work out the energy of a workout.
enum FineEnergy {
  /// From the heart rate, minute by minute.
  pulse,

  /// A fixed rate for each of its minutes.
  fixed,

  /// From its steps, like the rest of the day.
  steps,
}

/// The effort of a workout that is counted at a fixed rate, as a multiple
/// of rest (Compendium of Physical Activities). In strength training and
/// the like the pulse rises further than the energy spent does.
const double _strengthMet = 3.5;
const double _yogaMet = 2.5;
const double _otherMet = 3.5;

/// How a workout of [type] is counted. Walking at a moderate pulse costs
/// far less than the pulse suggests, so walks and hikes go by their steps.
FineEnergy fineEnergyOf(WorkoutType type) => switch (type) {
  WorkoutType.run || WorkoutType.ride || WorkoutType.swim => FineEnergy.pulse,
  WorkoutType.strength ||
  WorkoutType.yoga ||
  WorkoutType.other => FineEnergy.fixed,
  WorkoutType.walk || WorkoutType.hike => FineEnergy.steps,
};

/// The energy a minute of a workout of [type] costs beyond rest at [kg], in
/// kcal, where that is a fixed rate. Null for the other kinds.
double? fixedNetPerMinute(WorkoutType type, double kg) {
  final met = switch (type) {
    WorkoutType.strength => _strengthMet,
    WorkoutType.yoga => _yogaMet,
    WorkoutType.other => _otherMet,
    _ => null,
  };
  return met == null ? null : (met - 1) * 3.5 * kg / 200;
}

/// What walking a kilometre costs beyond rest, in kcal per kg.
const double _walkingPerKgKm = 0.5;

/// The length of a step as a share of the height, and where no height is
/// known, in metres.
const double _stepPerHeight = 0.414;
const double _plainStepMetres = 0.7;

/// The steps a minute of a workout that is not counted by its steps is
/// taken to hold: brisk walking. They are not counted again as steps.
const int fineStepsPerCountedMinute = 100;

/// The energy one step costs beyond rest, in kcal.
double kcalPerStep({required double kg, int? heightCm}) =>
    _walkingPerKgKm *
    kg *
    (heightCm == null ? _plainStepMetres : _stepPerHeight * heightCm / 100) /
    1000;

/// A workout as the fine values need it.
@immutable
class FineWorkout {
  const FineWorkout({
    required this.start,
    required this.end,
    required this.type,
    this.steps,
    this.km,
  });

  FineWorkout.of(Workout workout)
    : start = workout.start,
      end = workout.end,
      type = workout.type,
      steps = workout.steps,
      km = workout.distanceKm;

  final DateTime start;
  final DateTime end;
  final WorkoutType type;
  final int? steps;
  final double? km;
}

/// The fine values of one day.
class FineDay {
  const FineDay({
    required this.minutesByHour,
    required this.kcalByHour,
    required this.workoutKcal,
    this.unplacedKcal = 0,
    this.stepKcal = 0,
  });

  /// Intensity minutes, keyed by the start of the hour.
  final Map<DateTime, double> minutesByHour;

  /// Active energy, keyed by the start of the hour. Null where it cannot be
  /// worked out.
  final Map<DateTime, double>? kcalByHour;

  /// Active energy of the day that no hour can be named for: the steps of a
  /// day whose steps are only known as a whole.
  final double unplacedKcal;

  /// The active energy of each workout handed in, by its place in the list.
  /// A workout that is counted by its steps has its share of [kcal] here
  /// and not in [stepKcal].
  final Map<int, double> workoutKcal;

  /// The part of the active energy that comes from the steps beside the
  /// workouts.
  final double stepKcal;

  /// The part of the active energy that comes from the workouts.
  double get workoutsKcal =>
      workoutKcal.values.fold(0, (sum, value) => sum + value);

  double get minutes => _sum(minutesByHour);
  double? get kcal =>
      kcalByHour == null ? null : _sum(kcalByHour!) + unplacedKcal;

  static double _sum(Map<DateTime, double> byHour) =>
      byHour.values.fold(0, (sum, value) => sum + value);
}

/// The fine values of the day [on], or the day the [beats] (time and beats
/// per minute) are from. The beats of a minute are averaged, and a gap of up
/// to [fineBridgeMinutes] between two readings is filled with the pulse on
/// the way from one to the other.
///
/// Intensity minutes: a minute at the moderate pulse or above counts inside
/// one of the [workouts], or as one of at least [fineRunMinutes] in a row; a
/// single minute below, or without a pulse, does not end such a stretch and
/// does not count itself. Moderate once, vigorous twice.
///
/// Active energy, never less than nothing, in two parts:
/// - workouts by their kind, see [fineEnergyOf]: what [netPerMinute] says
///   for the pulse of each of their minutes, or a fixed rate for each
///   minute, see [fixedNetPerMinute], with [kg];
/// - the steps at [perStep] each: of every hour in [stepsByHour] (by the
///   hour of the day), or where only the day's [steps] are known, those.
///   A minute of a workout that is counted by pulse or rate takes
///   [fineStepsPerCountedMinute] steps out of its hour, so they are not
///   counted twice. A workout that is counted by its steps is part of them;
///   its own steps (or its distance) say how much of them is its.
FineDay fineDay(
  Iterable<(DateTime, double)> beats, {
  DateTime? on,
  required double moderate,
  required double vigorous,
  List<FineWorkout> workouts = const [],
  double Function(double bpm)? netPerMinute,
  double? kg,
  Map<int, double>? stepsByHour,
  double? steps,
  double? perStep,
}) {
  final sums = <int, (double, int)>{};
  var day = on == null ? null : DateTime(on.year, on.month, on.day);
  for (final (time, bpm) in beats) {
    day ??= DateTime(time.year, time.month, time.day);
    final minute = time.hour * 60 + time.minute;
    final (sum, count) = sums[minute] ?? (0.0, 0);
    sums[minute] = (sum + bpm, count + 1);
  }
  final minutesByHour = <DateTime, double>{};
  final kcalByHour = netPerMinute == null ? null : <DateTime, double>{};
  final workoutKcal = <int, double>{};
  if (day == null) {
    return FineDay(
      minutesByHour: minutesByHour,
      kcalByHour: kcalByHour,
      workoutKcal: workoutKcal,
    );
  }

  final means = List<double?>.filled(Duration.minutesPerDay, null);
  final read = sums.keys.toList()..sort();
  for (var i = 0; i < read.length; i++) {
    final (sum, count) = sums[read[i]]!;
    final mean = means[read[i]] = sum / count;
    if (i == 0) continue;
    final before = read[i - 1];
    final gap = read[i] - before;
    if (gap < 2 || gap > fineBridgeMinutes + 1) continue;
    final from = means[before]!;
    for (var step = 1; step < gap; step++) {
      means[before + step] = from + (mean - from) * step / gap;
    }
  }
  bool raised(int minute) =>
      minute < means.length && (means[minute] ?? 0) >= moderate;

  // The minutes of the stretches that are long enough.
  final inStretch = List<bool>.filled(Duration.minutesPerDay, false);
  var minute = 0;
  while (minute < means.length) {
    if (!raised(minute)) {
      minute++;
      continue;
    }
    final stretch = <int>[];
    while (raised(minute) || (stretch.isNotEmpty && raised(minute + 1))) {
      if (raised(minute)) stretch.add(minute);
      minute++;
    }
    if (stretch.length >= fineRunMinutes) {
      for (final counted in stretch) {
        inStretch[counted] = true;
      }
    }
  }

  // The workout each minute of the day lies in.
  final workoutOf = List<int?>.filled(Duration.minutesPerDay, null);
  for (var i = 0; i < workouts.length; i++) {
    final workout = workouts[i];
    final from = workout.start.isBefore(day)
        ? 0
        : workout.start.difference(day).inMinutes;
    final to = workout.end.difference(day).inMinutes;
    for (var m = from; m < to && m < workoutOf.length; m++) {
      if (m >= 0) workoutOf[m] ??= i;
    }
  }

  // The minutes of each hour whose energy is counted without their steps.
  final countedOf = List<int>.filled(Duration.hoursPerDay, 0);
  for (var m = 0; m < means.length; m++) {
    final mean = means[m];
    final workout = workoutOf[m];
    if (workout == null && !inStretch[m]) continue;
    final hour = day.add(Duration(hours: m ~/ 60));
    if (mean != null && mean >= moderate) {
      minutesByHour[hour] =
          (minutesByHour[hour] ?? 0) + (mean >= vigorous ? 2 : 1);
    }
    if (workout == null) continue;
    final type = workouts[workout].type;
    final way = fineEnergyOf(type);
    if (way == FineEnergy.steps) continue;
    countedOf[m ~/ 60]++;
    if (netPerMinute == null) continue;
    final net = way == FineEnergy.fixed
        ? (kg == null ? 0.0 : fixedNetPerMinute(type, kg)!)
        : (mean == null ? 0.0 : netPerMinute(mean));
    if (net <= 0) continue;
    kcalByHour![hour] = (kcalByHour[hour] ?? 0) + net;
    workoutKcal[workout] = (workoutKcal[workout] ?? 0) + net;
  }

  var unplaced = 0.0;
  var stepKcal = 0.0;
  if (kcalByHour != null && perStep != null) {
    if (stepsByHour != null) {
      for (final MapEntry(key: hour, value: taken) in stepsByHour.entries) {
        if (hour < 0 || hour >= countedOf.length) continue;
        final left = taken - fineStepsPerCountedMinute * countedOf[hour];
        if (left <= 0) continue;
        final at = day.add(Duration(hours: hour));
        kcalByHour[at] = (kcalByHour[at] ?? 0) + left * perStep;
        stepKcal += left * perStep;
      }
    } else if (steps != null) {
      final counted = countedOf.fold<int>(0, (sum, count) => sum + count);
      final left = steps - fineStepsPerCountedMinute * counted;
      if (left > 0) unplaced = stepKcal = left * perStep;
    }

    // What of the steps belongs to the workouts that are counted by them.
    final walked = <int, double>{};
    for (var i = 0; i < workouts.length; i++) {
      final workout = workouts[i];
      if (fineEnergyOf(workout.type) != FineEnergy.steps) continue;
      // A walk over midnight belongs to the day it began on.
      if (workout.start.isBefore(day) ||
          !workout.start.isBefore(day.add(const Duration(days: 1)))) {
        continue;
      }
      final kcal = workout.steps != null
          ? workout.steps! * perStep
          : workout.km != null && kg != null
          ? _walkingPerKgKm * kg * workout.km!
          : 0.0;
      if (kcal > 0) walked[i] = kcal;
    }
    final all = walked.values.fold<double>(0, (sum, kcal) => sum + kcal);
    if (all > 0) {
      // Never more than the steps of the day gave.
      final share = all > stepKcal ? stepKcal / all : 1.0;
      for (final MapEntry(key: i, value: kcal) in walked.entries) {
        workoutKcal[i] = kcal * share;
      }
      stepKcal -= all * share;
    }
  }
  return FineDay(
    minutesByHour: minutesByHour,
    kcalByHour: kcalByHour,
    workoutKcal: workoutKcal,
    unplacedKcal: unplaced,
    stepKcal: stepKcal,
  );
}
