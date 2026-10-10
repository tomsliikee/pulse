import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/formatters.dart';
import '../../data/heart_day.dart';
import '../../data/heart_insights.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/app_theme.dart';

/// A rate with its unit.
String bpmText(int bpm) => '$bpm bpm';

/// How the day went against the days before, in a line.
String heartHeadline(Formats formats, HeartDayInsights insights) {
  final l10n = formats.l10n;
  return switch (insights.headline) {
    HeartHeadline.first => l10n.heartFirst,
    HeartHeadline.calmer => l10n.heartCalmer(insights.difference.abs()),
    HeartHeadline.livelier => l10n.heartLivelier(insights.difference.abs()),
    HeartHeadline.usual => l10n.heartUsual,
  };
}

/// The text of a hint.
String heartTipText(Formats formats, HeartTip tip) {
  final l10n = formats.l10n;
  return switch (tip.kind) {
    HeartTipKind.restingHigh => l10n.heartTipResting(tip.value),
    HeartTipKind.longPeak => l10n.heartTipPeak(formats.duration(tip.value)),
    HeartTipKind.noCardio => l10n.heartTipNoCardio(tip.value),
    HeartTipKind.peakWithoutWorkout => l10n.heartTipPeakNoWorkout(tip.value),
    HeartTipKind.fewMeasurements => l10n.heartTipFew,
    HeartTipKind.keepGoing => l10n.heartTipKeepGoing,
  };
}

extension HeartMeasureText on HeartMeasure {
  String label(AppLocalizations l10n) => switch (this) {
    HeartMeasure.average => l10n.heartAverage,
    HeartMeasure.lowest => l10n.lowest,
    HeartMeasure.highest => l10n.highest,
    HeartMeasure.active => l10n.heartActive,
    HeartMeasure.resting => l10n.metricRestingHeartRate,
  };

  /// A difference in this measure, without its sign.
  String formatDifference(Formats formats, double difference) =>
      this == HeartMeasure.active
      ? formats.duration(difference.abs().round())
      : bpmText(difference.abs().round());
}

extension DayPartLook on DayPart {
  String label(AppLocalizations l10n) => switch (this) {
    DayPart.night => l10n.partNight,
    DayPart.morning => l10n.partMorning,
    DayPart.afternoon => l10n.partAfternoon,
    DayPart.evening => l10n.partEvening,
  };

  IconData get icon => switch (this) {
    DayPart.night => Icons.bedtime_rounded,
    DayPart.morning => Icons.wb_twilight_rounded,
    DayPart.afternoon => Icons.wb_sunny_rounded,
    DayPart.evening => Icons.nights_stay_rounded,
  };

  Shapes get shape => switch (this) {
    DayPart.night => Shapes.l4LeafClover,
    DayPart.morning => Shapes.softBurst,
    DayPart.afternoon => Shapes.gem,
    DayPart.evening => Shapes.bun,
  };

  Tone get tone => switch (this) {
    DayPart.night => Tone.tertiary,
    DayPart.morning => Tone.secondary,
    DayPart.afternoon => Tone.primary,
    DayPart.evening => Tone.neutral,
  };
}

/// The rates zone [index] of [heartZoneFloors] covers.
String zoneSpan(AppLocalizations l10n, int index) {
  final from = heartZoneFloors[index];
  if (index == 0) return l10n.zoneBelow(heartZoneFloors[1]);
  if (index == heartZoneFloors.length - 1) return l10n.zoneFrom(from);
  return l10n.bpmRange(from, heartZoneFloors[index + 1] - 1);
}
