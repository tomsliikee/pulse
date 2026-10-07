import '../../app/formatters.dart';
import '../../data/night_insights.dart';
import '../../data/workout_insights.dart' show Trend;
import '../../l10n/generated/app_localizations.dart';

/// How the measures of a night are named and written.
extension NightMeasureText on NightMeasure {
  String label(AppLocalizations l10n) => switch (this) {
    NightMeasure.score => l10n.scoreShort,
    NightMeasure.asleep => l10n.nightAsleep,
    NightMeasure.deep => l10n.stageDeep,
    NightMeasure.rem => l10n.stageRem,
    NightMeasure.light => l10n.stageLight,
    NightMeasure.awake => l10n.stageAwake,
    NightMeasure.efficiency => l10n.efficiency,
    NightMeasure.bedtime => l10n.nightBedtime,
    NightMeasure.wake => l10n.nightWake,
  };

  String format(Formats formats, double value) => switch (this) {
    NightMeasure.score => '${value.round()}',
    NightMeasure.efficiency => '${(value * 100).round()} %',
    NightMeasure.bedtime || NightMeasure.wake => formatClock(value.round()),
    _ => formats.duration(value.round()),
  };

  /// The size of a difference, without a sign.
  String formatDifference(Formats formats, double value) => switch (this) {
    NightMeasure.score => '${value.abs().round()}',
    NightMeasure.efficiency => '${(value.abs() * 100).round()} %',
    _ => formats.duration(value.abs().round()),
  };
}

extension ScorePartText on ScorePart {
  String label(AppLocalizations l10n) => switch (this) {
    ScorePart.duration => l10n.sleepDuration,
    ScorePart.stages => l10n.scorePartStages,
    ScorePart.efficiency => l10n.efficiency,
    ScorePart.regularity => l10n.regularity,
  };
}

/// "40 min länger als die Nacht davor".
String nightHeadline(Formats formats, NightInsights insights) {
  final l10n = formats.l10n;
  final asleep = insights.measure(NightMeasure.asleep);
  final previous = asleep?.previous;
  if (asleep == null || previous == null) return l10n.nightFirst;
  final diff = formats.duration((asleep.value - previous).abs().round());
  return switch (asleep.againstPrevious) {
    Trend.better => l10n.nightLonger(diff),
    Trend.worse => l10n.nightShorter(diff),
    Trend.same || Trend.neutral => l10n.nightSame,
  };
}

/// The text of a hint.
String nightTip(Formats formats, NightTip tip) {
  final l10n = formats.l10n;
  return switch (tip.kind) {
    NightTipKind.fewToCompare => l10n.nightTipFew,
    NightTipKind.debt => l10n.nightTipDebt(formats.duration(tip.minutes)),
    NightTipKind.irregular => l10n.nightTipIrregular(tip.minutes),
    NightTipKind.lateToBed => l10n.nightTipLate(formats.duration(tip.minutes)),
    NightTipKind.longAwake => l10n.nightTipAwake(formats.duration(tip.minutes)),
    NightTipKind.littleDeep => l10n.nightTipDeep,
    NightTipKind.keepGoing => l10n.nightTipKeepGoing,
  };
}

/// The sentence of an observation.
String sleepLinkText(Formats formats, SleepLink link) {
  final l10n = formats.l10n;
  final diff = formats.duration(link.minutes.abs());
  final direction = link.minutes > 0 ? 'more' : 'less';
  final deep = link.measure == NightMeasure.deep;
  return switch (link.kind) {
    SleepLinkKind.workout =>
      deep
          ? l10n.linkWorkoutDeep(diff, direction)
          : l10n.linkWorkoutAsleep(diff, direction),
    SleepLinkKind.steps =>
      deep
          ? l10n.linkStepsDeep(diff, direction)
          : l10n.linkStepsAsleep(diff, direction),
  };
}
