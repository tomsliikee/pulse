import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/container_route.dart';
import '../../app/formatters.dart';
import '../../data/metric_catalog.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../sleep/sleep_detail_page.dart';
import 'metric_detail_page.dart';

/// How a [Metric] is named and drawn.
@immutable
class MetricSpec {
  const MetricSpec(
    this.title,
    this.icon,
    this.shape, [
    this.tone = Tone.neutral,
  ]);

  final String title;
  final IconData icon;
  final Shapes shape;
  final Tone tone;
}

extension MetricGroupLabel on MetricGroup {
  String get label => switch (this) {
    MetricGroup.activity => 'Aktivität',
    MetricGroup.vitals => 'Vitalwerte',
    MetricGroup.body => 'Körper',
    MetricGroup.sleep => 'Schlaf',
    MetricGroup.nutrition => 'Ernährung',
  };
}

extension MetricPresentation on Metric {
  MetricSpec get spec => switch (this) {
    Metric.steps => const MetricSpec(
      'Schritte',
      Icons.directions_walk_rounded,
      Shapes.c12SidedCookie,
      Tone.primary,
    ),
    Metric.distance => const MetricSpec(
      'Distanz',
      Icons.route_rounded,
      Shapes.pentagon,
      Tone.primary,
    ),
    Metric.floors => const MetricSpec(
      'Etagen',
      Icons.stairs_rounded,
      Shapes.arch,
      Tone.secondary,
    ),
    Metric.activeEnergy => const MetricSpec(
      'Aktive Kalorien',
      Icons.local_fire_department_rounded,
      Shapes.softBurst,
    ),
    Metric.totalEnergy => const MetricSpec(
      'Kalorien gesamt',
      Icons.whatshot_rounded,
      Shapes.burst,
    ),
    Metric.intensityMinutes => const MetricSpec(
      'Aktive Minuten',
      Icons.bolt_rounded,
      Shapes.sunny,
      Tone.tertiary,
    ),
    Metric.speed => const MetricSpec(
      'Geschwindigkeit',
      Icons.speed_rounded,
      Shapes.slanted,
    ),
    Metric.heartRate => const MetricSpec(
      'Puls',
      Icons.monitor_heart_rounded,
      Shapes.heart,
      Tone.tertiary,
    ),
    Metric.restingHeartRate => const MetricSpec(
      'Ruhepuls',
      Icons.favorite_rounded,
      Shapes.l4LeafClover,
      Tone.tertiary,
    ),
    Metric.heartRateVariability => const MetricSpec(
      'Herzfrequenzvariabilität',
      Icons.graphic_eq_rounded,
      Shapes.c6SidedCookie,
      Tone.secondary,
    ),
    Metric.oxygenSaturation => const MetricSpec(
      'Sauerstoffsättigung',
      Icons.air_rounded,
      Shapes.flower,
      Tone.primary,
    ),
    Metric.respiratoryRate => const MetricSpec(
      'Atemfrequenz',
      Icons.waves_rounded,
      Shapes.puffy,
    ),
    Metric.systolic => const MetricSpec(
      'Blutdruck systolisch',
      Icons.compress_rounded,
      Shapes.gem,
    ),
    Metric.diastolic => const MetricSpec(
      'Blutdruck diastolisch',
      Icons.expand_rounded,
      Shapes.gem,
    ),
    Metric.bloodGlucose => const MetricSpec(
      'Blutzucker',
      Icons.bloodtype_rounded,
      Shapes.oval,
    ),
    Metric.bodyTemperature => const MetricSpec(
      'Körpertemperatur',
      Icons.thermostat_rounded,
      Shapes.pill,
    ),
    Metric.skinTemperature => const MetricSpec(
      'Hauttemperatur (Abweichung)',
      Icons.device_thermostat_rounded,
      Shapes.semicircle,
    ),
    Metric.weight => const MetricSpec(
      'Gewicht',
      Icons.monitor_weight_rounded,
      Shapes.c4SidedCookie,
      Tone.secondary,
    ),
    Metric.height => const MetricSpec(
      'Grösse',
      Icons.height_rounded,
      Shapes.arch,
    ),
    Metric.bodyMassIndex => const MetricSpec(
      'Body-Mass-Index',
      Icons.accessibility_new_rounded,
      Shapes.diamond,
    ),
    Metric.bodyFat => const MetricSpec(
      'Körperfett',
      Icons.percent_rounded,
      Shapes.clampShell,
    ),
    Metric.leanMass => const MetricSpec(
      'Magermasse',
      Icons.fitness_center_rounded,
      Shapes.gem,
    ),
    Metric.bodyWater => const MetricSpec(
      'Körperwasser',
      Icons.opacity_rounded,
      Shapes.pill,
    ),
    Metric.basalEnergy => const MetricSpec(
      'Grundumsatz',
      Icons.battery_charging_full_rounded,
      Shapes.fan,
    ),
    Metric.sleep => const MetricSpec(
      'Schlaf',
      Icons.bedtime_rounded,
      Shapes.puffy,
      Tone.secondary,
    ),
    Metric.water => const MetricSpec(
      'Wasser',
      Icons.water_drop_rounded,
      Shapes.pill,
    ),
    Metric.energyIntake => const MetricSpec(
      'Gegessene Kalorien',
      Icons.restaurant_rounded,
      Shapes.bun,
      Tone.tertiary,
    ),
    Metric.carbs => const MetricSpec(
      'Kohlenhydrate',
      Icons.bakery_dining_rounded,
      Shapes.c9SidedCookie,
    ),
    Metric.protein => const MetricSpec(
      'Eiweiss',
      Icons.egg_alt_rounded,
      Shapes.oval,
    ),
    Metric.fat => const MetricSpec(
      'Fett',
      Icons.water_rounded,
      Shapes.puffyDiamond,
    ),
    Metric.fiber => const MetricSpec(
      'Ballaststoffe',
      Icons.grass_rounded,
      Shapes.l8LeafClover,
    ),
    Metric.sugar => const MetricSpec(
      'Zucker',
      Icons.icecream_rounded,
      Shapes.pixelCircle,
    ),
  };

  /// "–" stands for a day without data.
  String format(double? value) {
    if (value == null) return '–';
    return digits == 0
        ? formatInt(value.round())
        : formatDecimal(value, digits: digits);
  }

  String formatWithUnit(double? value) =>
      value == null || unit.isEmpty ? format(value) : '${format(value)} $unit';

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
