import '../../app/formatters.dart';
import '../../data/goals.dart';
import '../../data/health_controller.dart';
import '../../data/settings_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../detail/metric_spec.dart';

/// What the goals are counted from, as the app holds it.
GoalData goalDataOf(HealthController health, SettingsController settings) =>
    GoalData(
      valueOf: health.valueOn,
      nights: health.nights,
      workouts: health.workouts,
      sleepGoalHours: settings.sleepGoalHours,
    );

extension GoalGroupText on GoalGroup {
  String label(AppLocalizations l10n) => switch (this) {
    GoalGroup.movement => l10n.dayPartMovement,
    GoalGroup.rest => l10n.goalGroupRest,
    GoalGroup.training => l10n.groupWorkout,
    GoalGroup.nutrition => l10n.groupNutrition,
  };
}

/// How the goals are named and their values written.
extension GoalText on Goal {
  String label(AppLocalizations l10n) => switch (this) {
    Goal.sleepDuration => l10n.sleepDuration,
    Goal.sleepScore => l10n.scoreTitle,
    Goal.workouts => l10n.goalWorkouts,
    Goal.trainingMinutes => l10n.goalTrainingMinutes,
    _ => metric!.title(l10n),
  };

  /// A value or a target of the goal, with its unit.
  String format(Formats formats, double? value) {
    if (value == null) return '–';
    return switch (this) {
      Goal.sleepDuration => formats.duration((value * 60).round()),
      Goal.trainingMinutes => formats.duration(value.round()),
      Goal.sleepScore || Goal.workouts => formats.integer(value.round()),
      // Steps and floors are named by the goal already.
      _ when metric!.isCount => metric!.format(formats, value),
      _ => metric!.formatWithUnit(formats, value),
    };
  }

  /// "1,2 l von 2,4 l", or "1.800 kcal von höchstens 2.200 kcal".
  String formatProgress(Formats formats, GoalProgress progress) {
    final target = format(formats, progress.target);
    return formats.l10n.amountOfGoal(
      format(formats, progress.value ?? 0),
      isLimit ? formats.l10n.goalAtMost(target) : target,
    );
  }
}
