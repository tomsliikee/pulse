import '../../../data/metric_catalog.dart';
import '../../../data/models.dart';
import '../../../data/morning.dart';
import 'mono_data.dart';

/// The one-sentence statements that open the cards and the pages. They carry
/// no numbers, so they read the same in the simple mode.
extension MonoStatements on MonoCtx {
  String activityStatement() {
    final steps = valueToday(Metric.steps);
    final goal = settings.stepGoal;
    return steps == null
        ? l10n.monoActivityNone
        : steps >= goal
        ? l10n.monoActivityDone
        : steps >= goal / 2
        ? l10n.monoActivityHalf
        : l10n.monoActivityQuiet;
  }

  String sleepStatement(SleepNight? night) {
    if (night == null) return l10n.monoSleepNone;
    final goal = settings.sleepGoalHours * 60;
    return night.totalMinutes >= goal
        ? l10n.monoSleepFull
        : night.totalMinutes >= goal * 0.85
        ? l10n.monoSleepAlmost
        : l10n.monoSleepShort;
  }

  /// Today's resting heart rate against the mean of the 30 days before.
  String heartStatement() {
    final samples = health.snapshot.heart[health.todayIndex];
    final resting = valueToday(Metric.restingHeartRate);
    final before = [
      for (var back = 1; back <= 30; back++)
        ?health.valueOn(
          Metric.restingHeartRate,
          DateTime(today.year, today.month, today.day - back),
        ),
    ];
    final mean = before.length < 5
        ? null
        : before.reduce((a, b) => a + b) / before.length;
    if (resting == null || mean == null) {
      return samples.isEmpty ? l10n.monoHeartNone : l10n.monoHeartUsual;
    }
    return resting < mean - 2
        ? l10n.monoHeartLower
        : resting > mean + 2
        ? l10n.monoHeartHigher
        : l10n.monoHeartUsual;
  }

  Set<Metric> get offVitals => {
    for (final d in vitalDeviations(health.valueOn, today)) d.metric,
  };

  String vitalsStatement() {
    final known = [for (final m in morningVitals) valueToday(m)];
    return known.every((v) => v == null)
        ? l10n.monoVitalsNone
        : offVitals.isEmpty
        ? l10n.monoVitalsOk
        : l10n.monoVitalsOff;
  }

  String nutritionStatement() => valueToday(Metric.energyIntake) == null
      ? l10n.monoNutritionNone
      : l10n.monoNutritionLogged;
}
