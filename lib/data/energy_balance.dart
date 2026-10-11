import 'metric_catalog.dart';

/// The days the real burn is worked out over.
const int balanceDays = 28;

/// The days of the window that need the calories eaten.
const int balanceFoodDays = 24;

/// The weigh-ins the window needs, one of them in its first and one in its
/// last week.
const int balanceWeighIns = 6;

/// The days an estimate needs a value on before its mean is set beside the
/// real burn.
const int balanceEstimateDays = 14;

/// The energy a kilogram of body weight holds, in kcal.
const double kcalPerKg = 7700;

/// What a person really burned per day over the last [balanceDays], worked
/// out backwards from what was eaten and what the weight did.
class EnergyBalance {
  const EnergyBalance({
    required this.foodDays,
    required this.weighIns,
    required this.weighedEarly,
    required this.weighedLate,
    this.eaten,
    this.kgPerWeek,
    this.source,
    this.fine,
  });

  /// Days of the window with calories eaten, and with a weight.
  final int foodDays;
  final int weighIns;

  /// Whether there is a weight in the first and in the last week.
  final bool weighedEarly;
  final bool weighedLate;

  /// The mean of the calories eaten per day. Null until [complete].
  final double? eaten;

  /// What the weight did per week, by a line through the weigh-ins. Null
  /// until [complete].
  final double? kgPerWeek;

  /// The mean total of the source and of the fine values over the window,
  /// where enough days have one.
  final double? source;
  final double? fine;

  bool get enoughFood => foodDays >= balanceFoodDays;
  bool get enoughWeight =>
      weighIns >= balanceWeighIns && weighedEarly && weighedLate;
  bool get complete => enoughFood && enoughWeight;

  /// The energy burned per day: what was eaten, less what went into the
  /// body or plus what came out of it. Null until [complete].
  double? get burn {
    final eaten = this.eaten;
    final kgPerWeek = this.kgPerWeek;
    if (eaten == null || kgPerWeek == null) return null;
    return eaten - kgPerWeek * kcalPerKg / 7;
  }
}

/// The balance of the [balanceDays] before [today], from the values
/// [valueOn] gives per day: the source's own, not the fine view.
EnergyBalance energyBalance({
  required DateTime today,
  required double? Function(Metric metric, DateTime day) valueOn,
}) {
  final days = [
    for (var back = balanceDays; back >= 1; back--)
      DateTime(today.year, today.month, today.day - back),
  ];
  double? mean(Metric metric, {required int atLeast}) {
    final values = [for (final day in days) ?valueOn(metric, day)];
    return values.length < atLeast
        ? null
        : values.reduce((a, b) => a + b) / values.length;
  }

  // The weigh-ins by their place in the window.
  final weights = <(int, double)>[
    for (final (index, day) in days.indexed)
      if (valueOn(Metric.weight, day) case final kg?) (index, kg),
  ];
  final food = [for (final day in days) ?valueOn(Metric.energyIntake, day)];
  final balance = EnergyBalance(
    foodDays: food.length,
    weighIns: weights.length,
    weighedEarly: weights.any((w) => w.$1 < 7),
    weighedLate: weights.any((w) => w.$1 >= balanceDays - 7),
  );
  if (!balance.complete) return balance;

  // A line through the weigh-ins by least squares: its slope is kg a day.
  final count = weights.length;
  final meanDay = weights.fold<double>(0, (sum, w) => sum + w.$1) / count;
  final meanKg = weights.fold<double>(0, (sum, w) => sum + w.$2) / count;
  var over = 0.0;
  var under = 0.0;
  for (final (day, kg) in weights) {
    over += (day - meanDay) * (kg - meanKg);
    under += (day - meanDay) * (day - meanDay);
  }
  return EnergyBalance(
    foodDays: balance.foodDays,
    weighIns: balance.weighIns,
    weighedEarly: true,
    weighedLate: true,
    eaten: food.reduce((a, b) => a + b) / food.length,
    kgPerWeek: under == 0 ? 0 : over / under * 7,
    source: mean(Metric.totalEnergy, atLeast: balanceEstimateDays),
    fine: mean(Metric.fineTotalEnergy, atLeast: balanceEstimateDays),
  );
}
