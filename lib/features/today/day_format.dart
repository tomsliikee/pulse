import '../../app/formatters.dart';
import '../../data/day_insights.dart';
import '../../data/health_controller.dart';
import '../../data/metric_catalog.dart';
import '../../data/settings_controller.dart';
import '../../data/workout_insights.dart' show Trend;
import '../../l10n/generated/app_localizations.dart';
import '../detail/metric_spec.dart';

/// What the user's days are judged against.
DayGoals dayGoalsOf(SettingsController settings) => DayGoals(
  steps: settings.stepGoal,
  activeEnergy: settings.activeEnergyGoal,
  waterMl: settings.waterGoalMl,
  sleepHours: settings.sleepGoalHours,
);

/// Everything the app can say about [day]. The time of day only counts for
/// today.
DayInsights dayInsightsOf(
  HealthController health,
  SettingsController settings,
  DateTime day,
) => DayInsights.of(
  day: day,
  valueOf: health.valueOn,
  nights: health.nights,
  workouts: health.workouts,
  goals: dayGoalsOf(settings),
  history: health.history,
  now: day == health.today ? health.now : null,
);

/// How the measures of a day are named and written.
extension DayMeasureText on DayMeasure {
  String label(AppLocalizations l10n) => switch (this) {
    DayMeasure.score => l10n.dayScore,
    DayMeasure.sleep => l10n.groupSleep,
    _ => metric!.title(l10n),
  };

  String format(Formats formats, double value) => switch (this) {
    DayMeasure.score => '${value.round()}',
    DayMeasure.sleep => formats.duration(value.round()),
    _ => metric!.formatWithUnit(formats, value),
  };

  /// Under a label that already names it: steps without "steps".
  String formatAlone(Formats formats, double value) => metric?.isCount ?? false
      ? metric!.format(formats, value)
      : format(formats, value);

  /// The size of a difference, without a sign.
  String formatDifference(Formats formats, double value) => switch (this) {
    DayMeasure.score => '${value.abs().round()}',
    DayMeasure.sleep => formats.duration(value.abs().round()),
    _ => metric!.format(formats, value.abs()),
  };
}

extension DayScorePartText on DayScorePart {
  String label(AppLocalizations l10n) => switch (this) {
    DayScorePart.movement => l10n.dayPartMovement,
    DayScorePart.sleep => l10n.groupSleep,
    DayScorePart.heart => Metric.restingHeartRate.title(l10n),
    DayScorePart.water => Metric.water.title(l10n),
  };
}

/// "1.200 Schritte mehr als gestern um diese Zeit" for today, and against
/// the day before for any other day.
String dayHeadline(Formats formats, DayInsights insights, {StepsSoFar? soFar}) {
  final l10n = formats.l10n;
  if (soFar != null) {
    final diff = formats.integer((soFar.today - soFar.yesterday).abs().round());
    return switch (soFar.trend) {
      Trend.better => l10n.daySoFarAhead(diff),
      Trend.worse => l10n.daySoFarBehind(diff),
      Trend.same || Trend.neutral => l10n.daySoFarSame,
    };
  }
  final steps = insights.measure(DayMeasure.steps);
  final previous = steps?.previous;
  if (steps == null || previous == null) return l10n.dayNoCompare;
  final diff = formats.integer((steps.value - previous).abs().round());
  return switch (steps.againstPrevious) {
    Trend.better => l10n.dayMoreSteps(diff),
    Trend.worse => l10n.dayFewerSteps(diff),
    Trend.same || Trend.neutral => l10n.daySameSteps,
  };
}

/// The text of a hint.
String dayTip(Formats formats, DayTip tip) {
  final l10n = formats.l10n;
  return switch (tip.kind) {
    DayTipKind.fewToCompare => l10n.dayTipFew,
    DayTipKind.bedtimeNear => l10n.dayTipBedtime(formatClock(tip.value)),
    DayTipKind.streakAtRisk => l10n.dayTipStreakRisk(tip.value),
    DayTipKind.goalClose => l10n.dayTipGoalClose(formats.integer(tip.value)),
    DayTipKind.littleWater => l10n.dayTipWater(
      Metric.water.formatWithUnit(formats, tip.value / 1000),
    ),
    DayTipKind.pulseHigh => l10n.dayTipPulse(tip.value),
    DayTipKind.stepsFalling => l10n.dayTipStepsFalling(tip.value),
    DayTipKind.streak => l10n.dayTipStreak(tip.value),
    DayTipKind.keepGoing => l10n.dayTipKeepGoing,
  };
}
