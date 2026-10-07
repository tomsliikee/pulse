import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/container_route.dart';
import '../../app/formatters.dart';
import '../../data/metric_catalog.dart';
import '../../data/models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../sleep/sleep_detail_page.dart';
import 'metric_detail_page.dart';

/// How a [Metric] is drawn.
@immutable
class MetricSpec {
  const MetricSpec(this.icon, this.shape, [this.tone = Tone.neutral]);

  final IconData icon;
  final Shapes shape;
  final Tone tone;
}

extension MetricGroupLabel on MetricGroup {
  String label(AppLocalizations l10n) => switch (this) {
    MetricGroup.activity => l10n.groupActivity,
    MetricGroup.vitals => l10n.groupVitals,
    MetricGroup.body => l10n.groupBody,
    MetricGroup.sleep => l10n.groupSleep,
    MetricGroup.nutrition => l10n.groupNutrition,
  };
}

extension MetricPresentation on Metric {
  MetricSpec get spec => switch (this) {
    Metric.steps => const MetricSpec(
      Icons.directions_walk_rounded,
      Shapes.c12SidedCookie,
      Tone.primary,
    ),
    Metric.distance => const MetricSpec(
      Icons.route_rounded,
      Shapes.pentagon,
      Tone.primary,
    ),
    Metric.floors => const MetricSpec(
      Icons.stairs_rounded,
      Shapes.arch,
      Tone.secondary,
    ),
    Metric.activeEnergy => const MetricSpec(
      Icons.local_fire_department_rounded,
      Shapes.softBurst,
    ),
    Metric.totalEnergy => const MetricSpec(
      Icons.whatshot_rounded,
      Shapes.burst,
    ),
    Metric.intensityMinutes => const MetricSpec(
      Icons.bolt_rounded,
      Shapes.sunny,
      Tone.tertiary,
    ),
    Metric.speed => const MetricSpec(Icons.speed_rounded, Shapes.slanted),
    Metric.heartRate => const MetricSpec(
      Icons.monitor_heart_rounded,
      Shapes.heart,
      Tone.tertiary,
    ),
    Metric.restingHeartRate => const MetricSpec(
      Icons.favorite_rounded,
      Shapes.l4LeafClover,
      Tone.tertiary,
    ),
    Metric.heartRateVariability => const MetricSpec(
      Icons.graphic_eq_rounded,
      Shapes.c6SidedCookie,
      Tone.secondary,
    ),
    Metric.oxygenSaturation => const MetricSpec(
      Icons.air_rounded,
      Shapes.flower,
      Tone.primary,
    ),
    Metric.respiratoryRate => const MetricSpec(
      Icons.waves_rounded,
      Shapes.puffy,
    ),
    Metric.systolic => const MetricSpec(Icons.compress_rounded, Shapes.gem),
    Metric.diastolic => const MetricSpec(Icons.expand_rounded, Shapes.gem),
    Metric.bloodGlucose => const MetricSpec(
      Icons.bloodtype_rounded,
      Shapes.oval,
    ),
    Metric.bodyTemperature => const MetricSpec(
      Icons.thermostat_rounded,
      Shapes.pill,
    ),
    Metric.skinTemperature => const MetricSpec(
      Icons.device_thermostat_rounded,
      Shapes.semicircle,
    ),
    Metric.weight => const MetricSpec(
      Icons.monitor_weight_rounded,
      Shapes.c4SidedCookie,
      Tone.secondary,
    ),
    Metric.height => const MetricSpec(Icons.height_rounded, Shapes.arch),
    Metric.bodyMassIndex => const MetricSpec(
      Icons.accessibility_new_rounded,
      Shapes.diamond,
    ),
    Metric.bodyFat => const MetricSpec(
      Icons.percent_rounded,
      Shapes.clampShell,
    ),
    Metric.leanMass => const MetricSpec(
      Icons.fitness_center_rounded,
      Shapes.gem,
    ),
    Metric.bodyWater => const MetricSpec(Icons.opacity_rounded, Shapes.pill),
    Metric.basalEnergy => const MetricSpec(
      Icons.battery_charging_full_rounded,
      Shapes.fan,
    ),
    Metric.sleep => const MetricSpec(
      Icons.bedtime_rounded,
      Shapes.puffy,
      Tone.secondary,
    ),
    Metric.water => const MetricSpec(Icons.water_drop_rounded, Shapes.pill),
    Metric.energyIntake => const MetricSpec(
      Icons.restaurant_rounded,
      Shapes.bun,
      Tone.tertiary,
    ),
    Metric.carbs => const MetricSpec(
      Icons.bakery_dining_rounded,
      Shapes.c9SidedCookie,
    ),
    Metric.protein => const MetricSpec(Icons.egg_alt_rounded, Shapes.oval),
    Metric.fat => const MetricSpec(Icons.water_rounded, Shapes.puffyDiamond),
    Metric.fiber => const MetricSpec(Icons.grass_rounded, Shapes.l8LeafClover),
    Metric.sugar => const MetricSpec(
      Icons.icecream_rounded,
      Shapes.pixelCircle,
    ),
  };

  String title(AppLocalizations l10n) => switch (this) {
    Metric.steps => l10n.metricSteps,
    Metric.distance => l10n.metricDistance,
    Metric.floors => l10n.metricFloors,
    Metric.activeEnergy => l10n.metricActiveEnergy,
    Metric.totalEnergy => l10n.metricTotalEnergy,
    Metric.intensityMinutes => l10n.metricIntensityMinutes,
    Metric.speed => l10n.metricSpeed,
    Metric.heartRate => l10n.metricHeartRate,
    Metric.restingHeartRate => l10n.metricRestingHeartRate,
    Metric.heartRateVariability => l10n.metricHeartRateVariability,
    Metric.oxygenSaturation => l10n.metricOxygenSaturation,
    Metric.respiratoryRate => l10n.metricRespiratoryRate,
    Metric.systolic => l10n.metricSystolic,
    Metric.diastolic => l10n.metricDiastolic,
    Metric.bloodGlucose => l10n.metricBloodGlucose,
    Metric.bodyTemperature => l10n.metricBodyTemperature,
    Metric.skinTemperature => l10n.metricSkinTemperature,
    Metric.weight => l10n.metricWeight,
    Metric.height => l10n.metricHeight,
    Metric.bodyMassIndex => l10n.metricBodyMassIndex,
    Metric.bodyFat => l10n.metricBodyFat,
    Metric.leanMass => l10n.metricLeanMass,
    Metric.bodyWater => l10n.metricBodyWater,
    Metric.basalEnergy => l10n.metricBasalEnergy,
    Metric.sleep => l10n.metricSleep,
    Metric.water => l10n.metricWater,
    Metric.energyIntake => l10n.metricEnergyIntake,
    Metric.carbs => l10n.metricCarbs,
    Metric.protein => l10n.metricProtein,
    Metric.fat => l10n.metricFat,
    Metric.fiber => l10n.metricFiber,
    Metric.sugar => l10n.metricSugar,
  };

  /// Steps and floors are counted: what follows the number is a word that
  /// changes with it, not a unit.
  bool get isCount => this == Metric.steps || this == Metric.floors;

  /// The unit as it reads after [value].
  String unitFor(AppLocalizations l10n, double? value) => switch (this) {
    Metric.steps => l10n.unitSteps((value ?? 0).round()),
    Metric.floors => l10n.unitFloors((value ?? 0).round()),
    _ => unit,
  };

  /// "–" stands for a day without data.
  String format(Formats formats, double? value) {
    if (value == null) return '–';
    return digits == 0
        ? formats.integer(value.round())
        : formats.decimal(value, digits: digits);
  }

  String formatWithUnit(Formats formats, double? value) {
    final unit = unitFor(formats.l10n, value);
    return value == null || unit.isEmpty
        ? format(formats, value)
        : '${format(formats, value)} $unit';
  }

  /// The kind of entry the app can record for this metric, if any.
  EntryKind? get entryKind => switch (this) {
    Metric.water => EntryKind.water,
    Metric.weight => EntryKind.weight,
    Metric.energyIntake => EntryKind.meal,
    _ => null,
  };
}

/// Opens the detail page for [metric], growing it out of the tile at [origin].
/// Sleep has a page of its own.
void openMetric(BuildContext context, Metric metric, Rect origin) {
  final scheme = Theme.of(context).colorScheme;
  Navigator.of(context).push(
    ContainerRoute<void>(
      origin: origin,
      originColor: scheme.tone(metric.spec.tone).container,
      builder: (_) => metric == Metric.sleep
          ? const SleepDetailPage()
          : MetricDetailPage(metric: metric),
    ),
  );
}
