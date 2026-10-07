import '../../app/formatters.dart';
import '../../data/models.dart';
import '../../data/workout_insights.dart';
import '../../l10n/generated/app_localizations.dart';

/// How the measures of a workout are named and written.
extension WorkoutMeasureText on WorkoutMeasure {
  String label(AppLocalizations l10n) => switch (this) {
    WorkoutMeasure.duration => l10n.measureDuration,
    WorkoutMeasure.distance => l10n.measureDistance,
    WorkoutMeasure.pace => l10n.measurePace,
    WorkoutMeasure.speed => l10n.measureSpeed,
    WorkoutMeasure.energy => l10n.measureEnergy,
    WorkoutMeasure.steps => l10n.measureSteps,
    WorkoutMeasure.avgHeartRate => l10n.measureAvgHeart,
    WorkoutMeasure.maxHeartRate => l10n.measureMaxHeart,
  };

  /// 5.7 minutes per kilometre become "5:42 min/km".
  String format(Formats formats, WorkoutType type, double value) =>
      switch (this) {
        WorkoutMeasure.duration => formats.duration(value.round()),
        WorkoutMeasure.distance => '${_km(formats, value)} km',
        WorkoutMeasure.pace =>
          type == WorkoutType.swim
              ? '${_clock(value / 10)} min/100 m'
              : '${_clock(value)} min/km',
        WorkoutMeasure.speed => '${formats.decimal(value)} km/h',
        WorkoutMeasure.energy => '${formats.integer(value.round())} kcal',
        WorkoutMeasure.steps => formats.integer(value.round()),
        WorkoutMeasure.avgHeartRate ||
        WorkoutMeasure.maxHeartRate => '${value.round()} bpm',
      };

  /// The size of a difference, without a sign: 0.2 minutes per kilometre
  /// become "12 s".
  String formatDifference(Formats formats, WorkoutType type, double value) {
    final size = value.abs();
    return switch (this) {
      WorkoutMeasure.pace => _seconds(
        formats,
        type == WorkoutType.swim ? size / 10 : size,
      ),
      _ => format(formats, type, size),
    };
  }

  static String _km(Formats formats, double km) =>
      formats.decimal(km, digits: km < 10 ? 2 : 1);

  static String _clock(double minutes) {
    final seconds = (minutes * 60).round();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  static String _seconds(Formats formats, double minutes) {
    final seconds = (minutes * 60).round();
    return seconds < 60
        ? formats.l10n.durationSeconds(seconds)
        : '${_clock(minutes)} min';
  }
}

/// "12 s schneller als letztes Mal", for the one comparison of [insights]
/// that is worth a sentence.
String workoutHeadline(Formats formats, WorkoutInsights insights) {
  final l10n = formats.l10n;
  final comparison = insights.headline;
  final previous = comparison?.previous;
  if (comparison == null || previous == null) return l10n.cmpFirst;
  final trend = comparison.againstPrevious;
  if (trend == Trend.same) return l10n.cmpSame;
  final diff = comparison.measure.formatDifference(
    formats,
    insights.workout.type,
    comparison.value - previous,
  );
  final better = trend == Trend.better;
  return switch (comparison.measure) {
    WorkoutMeasure.pace || WorkoutMeasure.speed =>
      better ? l10n.cmpFaster(diff) : l10n.cmpSlower(diff),
    WorkoutMeasure.distance =>
      better ? l10n.cmpFarther(diff) : l10n.cmpLessFar(diff),
    _ => better ? l10n.cmpLonger(diff) : l10n.cmpShorter(diff),
  };
}

/// The text of a hint.
String workoutTip(AppLocalizations l10n, WorkoutTip tip) => switch (tip.kind) {
  WorkoutTipKind.fewToCompare => l10n.tipFew,
  WorkoutTipKind.longBreak => l10n.tipLongBreak(tip.value),
  WorkoutTipKind.lessOften => l10n.tipLessOften,
  WorkoutTipKind.bigJump => l10n.tipBigJump(tip.value),
  WorkoutTipKind.higherPulse => l10n.tipHigherPulse,
  WorkoutTipKind.strengthTwice => l10n.tipStrength,
  WorkoutTipKind.keepGoing => l10n.tipKeepGoing,
};
