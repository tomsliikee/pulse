import 'package:material_ui/material_ui.dart';

import '../../data/morning.dart';
import '../../data/weather.dart';
import '../../l10n/generated/app_localizations.dart';

/// "Guten Morgen, Thomas", or without the name where none is set.
String morningGreeting(AppLocalizations l10n, String? name) =>
    name == null ? l10n.morningTitle : l10n.morningGreetingName(name);

extension SkyText on Sky {
  String label(AppLocalizations l10n) => switch (this) {
    Sky.clear => l10n.skyClear,
    Sky.partlyCloudy => l10n.skyPartlyCloudy,
    Sky.cloudy => l10n.skyCloudy,
    Sky.fog => l10n.skyFog,
    Sky.rain => l10n.skyRain,
    Sky.snow => l10n.skySnow,
    Sky.thunder => l10n.skyThunder,
  };

  IconData get icon => switch (this) {
    Sky.clear => Icons.wb_sunny_rounded,
    Sky.partlyCloudy => Icons.wb_cloudy_rounded,
    Sky.cloudy => Icons.cloud_rounded,
    Sky.fog => Icons.foggy,
    Sky.rain => Icons.water_drop_rounded,
    Sky.snow => Icons.ac_unit_rounded,
    Sky.thunder => Icons.thunderstorm_rounded,
  };
}

extension DayEffortText on DayEffort {
  String sentence(AppLocalizations l10n) => switch (this) {
    DayEffort.easy => l10n.morningEffortEasy,
    DayEffort.normal => l10n.morningEffortNormal,
    DayEffort.push => l10n.morningEffortPush,
  };

  IconData get icon => switch (this) {
    DayEffort.easy => Icons.self_improvement_rounded,
    DayEffort.normal => Icons.directions_walk_rounded,
    DayEffort.push => Icons.bolt_rounded,
  };
}

/// 11.6 becomes "12°".
String degrees(AppLocalizations l10n, double value) =>
    l10n.weatherDegrees('${value.round()}');
