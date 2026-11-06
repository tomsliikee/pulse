import '../../../data/goals.dart';
import '../../../data/metric_catalog.dart';
import 'mono_data.dart';

/// The calories of today as the card shows them: what was burned, in its
/// parts, against the day's rest plus the active goal, and what was eaten,
/// in protein, carbohydrates and fat, against the intake goal. Read from the
/// app's values; nothing is estimated here that the app does not estimate.
class MonoEnergy {
  const MonoEnergy({
    required this.burned,
    required this.burnedParts,
    required this.burnedGoal,
    required this.eaten,
    required this.eatenParts,
    required this.eatenGoal,
    required this.split,
  });

  factory MonoEnergy.of(MonoCtx c) {
    final burned =
        c.valueToday(Metric.totalEnergy) ??
        c.valueToday(Metric.fineTotalEnergy);
    final active =
        c.valueToday(Metric.activeEnergy) ??
        c.valueToday(Metric.fineActiveEnergy);
    final workouts = c.valueToday(Metric.fineWorkoutEnergy);
    final basal =
        c.valueToday(Metric.basalEnergy) ??
        (burned != null && active != null ? burned - active : null);
    final split = workouts != null && active != null;
    final burnedParts = [
      basal ?? 0,
      if (split) ...[
        workouts.clamp(0, active).toDouble(),
        (active - workouts).clamp(0, active).toDouble(),
      ] else
        active ?? 0,
    ];

    final eaten = c.valueToday(Metric.energyIntake);
    // Four, four and nine kilocalories to the gram; what the macros do not
    // cover stays as the rest of the ring.
    final eatenParts = [
      (c.valueToday(Metric.protein) ?? 0) * 4,
      (c.valueToday(Metric.carbs) ?? 0) * 4,
      (c.valueToday(Metric.fat) ?? 0) * 9,
    ];

    return MonoEnergy(
      burned: burned,
      burnedParts: burnedParts,
      burnedGoal: _restOfDay(c) + c.settings.activeEnergyGoal,
      eaten: eaten,
      eatenParts: eatenParts,
      eatenGoal: c.settings.goalTarget(Goal.energyIntake),
      split: split,
    );
  }

  /// What the body burns at rest in a whole day: the mean of the last seven
  /// days that have it, or today's so far carried to midnight.
  static double _restOfDay(MonoCtx c) {
    final days = [
      for (var back = 1; back <= 7; back++)
        ?c.health.valueOn(
          Metric.basalEnergy,
          DateTime(c.today.year, c.today.month, c.today.day - back),
        ),
    ];
    if (days.isNotEmpty) return days.reduce((a, b) => a + b) / days.length;
    final today = c.valueToday(Metric.basalEnergy);
    final now = c.health.now;
    final minutes = now.hour * 60 + now.minute;
    if (today != null && minutes > 60) return today * 24 * 60 / minutes;
    // Without any value: a common resting burn, so the ring still has an end.
    return 1600;
  }

  final double? burned;

  /// Rest, workouts and everyday movement; rest and active where the app
  /// does not tell workouts apart ([split] false).
  final List<double> burnedParts;
  final double burnedGoal;
  final double? eaten;

  /// Protein, carbohydrates and fat, in kilocalories.
  final List<double> eatenParts;
  final double eatenGoal;
  final bool split;

  bool get burnedReached => (burned ?? 0) >= burnedGoal;
  bool get eatenReached => (eaten ?? 0) >= eatenGoal;
  bool get bothReached => burnedReached && eatenReached;

  /// Burned less eaten; positive is a deficit.
  double? get balance =>
      burned == null || eaten == null ? null : burned! - eaten!;
}
