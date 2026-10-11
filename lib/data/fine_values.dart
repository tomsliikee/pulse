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
  });

  final double age;
  final Sex? sex;
  final int? heightCm;

  /// The weight where the days read hold none.
  final double? weightKg;

  int get maxHeartRate => fineMaxHeartRate(age);

  @override
  bool operator ==(Object other) =>
      other is FineProfile &&
      other.age == age &&
      other.sex == sex &&
      other.heightCm == heightCm &&
      other.weightKg == weightKg;

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

/// The energy a minute at rest costs: the source's own base of the day
/// ([total] less [active], over the [minutes] the day has had) where that is
/// plausible, else the estimate from [profile] and [kg]. Null where neither
/// can be had.
double? restingPerMinute({
  required double? total,
  required double? active,
  required int minutes,
  required FineProfile profile,
  required double? kg,
}) {
  if (total != null && active != null && minutes > 0) {
    final base = (total - active) / minutes;
    if (base >= _leastRestingPerMinute && base <= _mostRestingPerMinute) {
      return base;
    }
  }
  final sex = profile.sex;
  final height = profile.heightCm;
  if (sex == null || height == null || kg == null) return null;
  return restingBurnPerDay(
        kg: kg,
        heightCm: height,
        age: profile.age,
        sex: sex,
      ) /
      Duration.minutesPerDay;
}

/// The effort of a workout that is not judged by the pulse, as a multiple
/// of rest (Compendium of Physical Activities). In strength training and
/// the like the pulse rises further than the energy spent does.
const double _strengthMet = 3.5;
const double _yogaMet = 2.5;
const double _otherMet = 3.5;

/// The energy a minute of a workout of [type] costs beyond rest at [kg], in
/// kcal, where that is taken from its kind. Null for the kinds that are
/// judged by the pulse.
double? fixedNetPerMinute(WorkoutType type, double kg) {
  final met = switch (type) {
    WorkoutType.strength => _strengthMet,
    WorkoutType.yoga => _yogaMet,
    WorkoutType.other => _otherMet,
    WorkoutType.run ||
    WorkoutType.ride ||
    WorkoutType.walk ||
    WorkoutType.hike ||
    WorkoutType.swim => null,
  };
  return met == null ? null : (met - 1) * 3.5 * kg / 200;
}

/// What walking a kilometre costs beyond rest, in kcal per kg.
const double _walkingPerKgKm = 0.5;

/// The length of a step as a share of the height, and where no height is
/// known, in metres.
const double _stepPerHeight = 0.414;
const double _plainStepMetres = 0.7;

/// The steps a minute of a workout or of a raised stretch is taken to hold:
/// brisk walking. They are not counted again as everyday steps.
const int fineStepsPerCountedMinute = 100;

/// The energy one step costs beyond rest, in kcal.
double kcalPerStep({required double kg, int? heightCm}) =>
    _walkingPerKgKm *
    kg *
    (heightCm == null ? _plainStepMetres : _stepPerHeight * heightCm / 100) /
    1000;

/// The fine values of one day.
class FineDay {
  const FineDay({
    required this.minutesByHour,
    required this.kcalByHour,
    required this.workoutKcal,
    this.unplacedKcal = 0,
    this.stretchKcal = 0,
    this.stepKcal = 0,
  });

  /// Intensity minutes, keyed by the start of the hour.
  final Map<DateTime, double> minutesByHour;

  /// Active energy, keyed by the start of the hour. Null where it cannot be
  /// worked out.
  final Map<DateTime, double>? kcalByHour;

  /// Active energy of the day that no hour can be named for: the everyday
  /// steps of a day whose steps are only known as a whole.
  final double unplacedKcal;

  /// The active energy of each workout handed in, by its place in the list.
  final Map<int, double> workoutKcal;

  /// The parts of the active energy beside the workouts: the raised
  /// stretches, and the everyday steps.
  final double stretchKcal;
  final double stepKcal;

  /// The active energy of the workouts, as far as it fell on this day.
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
/// the way from one to the other. A minute counts inside one of the
/// [workouts] (start, end and kind), or as one of at least [fineRunMinutes]
/// at the moderate pulse or above; a single minute below, or without a
/// pulse, does not end such a stretch and does not count itself.
///
/// Intensity minutes: a counted minute in the moderate zone once, in the
/// vigorous zone twice.
///
/// Active energy, never less than nothing for a minute, in three parts:
/// - a counted minute gives what [netPerMinute] says for its pulse; a minute
///   of a workout counts for it at any pulse;
/// - a workout of a kind that is not judged by the pulse gives a fixed rate
///   for each of its minutes instead, see [fixedNetPerMinute], with [kg];
/// - the steps beside all that give [perStep] each: of every hour in
///   [stepsByHour] (by the hour of the day) what is left after
///   [fineStepsPerCountedMinute] for each of its counted minutes; or, where
///   only the day's [steps] are known, those less [workoutSteps] and the
///   same for each minute of a stretch.
FineDay fineDay(
  Iterable<(DateTime, double)> beats, {
  DateTime? on,
  required double moderate,
  required double vigorous,
  List<(DateTime, DateTime, WorkoutType)> workouts = const [],
  double Function(double bpm)? netPerMinute,
  double? kg,
  Map<int, double>? stepsByHour,
  double? steps,
  double workoutSteps = 0,
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
    final (start, end, _) = workouts[i];
    final from = start.isBefore(day) ? 0 : start.difference(day).inMinutes;
    final to = end.difference(day).inMinutes;
    for (var m = from; m < to && m < workoutOf.length; m++) {
      if (m >= 0) workoutOf[m] ??= i;
    }
  }

  // The minutes of each hour that are counted, whatever they give.
  final countedOf = List<int>.filled(Duration.hoursPerDay, 0);
  var stretchMinutes = 0;
  var stretchKcal = 0.0;
  for (var m = 0; m < means.length; m++) {
    final mean = means[m];
    final workout = workoutOf[m];
    if (workout == null && !inStretch[m]) continue;
    countedOf[m ~/ 60]++;
    if (workout == null) stretchMinutes++;
    final hour = day.add(Duration(hours: m ~/ 60));
    if (mean != null && mean >= moderate) {
      minutesByHour[hour] =
          (minutesByHour[hour] ?? 0) + (mean >= vigorous ? 2 : 1);
    }
    if (netPerMinute == null) continue;
    final fixed = workout == null || kg == null
        ? null
        : fixedNetPerMinute(workouts[workout].$3, kg);
    final net = fixed ?? (mean == null ? 0.0 : netPerMinute(mean));
    if (net <= 0) continue;
    kcalByHour![hour] = (kcalByHour[hour] ?? 0) + net;
    if (workout != null) {
      workoutKcal[workout] = (workoutKcal[workout] ?? 0) + net;
    } else {
      stretchKcal += net;
    }
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
      final left =
          steps - workoutSteps - fineStepsPerCountedMinute * stretchMinutes;
      if (left > 0) unplaced = stepKcal = left * perStep;
    }
  }
  return FineDay(
    minutesByHour: minutesByHour,
    kcalByHour: kcalByHour,
    workoutKcal: workoutKcal,
    unplacedKcal: unplaced,
    stretchKcal: stretchKcal,
    stepKcal: stepKcal,
  );
}
