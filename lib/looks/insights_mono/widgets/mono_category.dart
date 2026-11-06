import 'package:material_ui/material_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../theme/mono_tokens.dart';

/// The categories of the look. Only recovery and the heart carry a colour;
/// all the others are written in ink.
enum MonoCategory {
  recovery(Icons.bolt_rounded),
  activity(Icons.directions_run_rounded),
  workouts(Icons.fitness_center_rounded),
  heart(Icons.favorite_rounded),
  vitals(Icons.monitor_heart_rounded),
  sleep(Icons.bedtime_rounded),
  body(Icons.accessibility_new_rounded),
  nutrition(Icons.restaurant_rounded),
  supplements(Icons.medication_rounded);

  const MonoCategory(this.icon);

  final IconData icon;

  Color color(MonoTokens t) => switch (this) {
    MonoCategory.recovery => t.recovery,
    MonoCategory.heart => t.heart,
    _ => t.ink,
  };

  String label(AppLocalizations l10n) => switch (this) {
    MonoCategory.recovery => l10n.recovery,
    MonoCategory.activity => l10n.groupActivity,
    MonoCategory.workouts => l10n.workouts,
    MonoCategory.heart => l10n.navHeart,
    MonoCategory.vitals => l10n.groupVitals,
    MonoCategory.sleep => l10n.groupSleep,
    MonoCategory.body => l10n.groupBody,
    MonoCategory.nutrition => l10n.groupNutrition,
    MonoCategory.supplements => l10n.supplements,
  };
}
