import 'package:material_ui/material_ui.dart';

import '../../../app/app_scope.dart';
import '../../../data/models.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/mono_actions.dart';
import '../pages/training/training_start.dart';
import 'mono_category.dart';

/// Something to log from the search panel: a glass of water, a weight, a
/// meal, a training or a supplement.
class MonoAddAction {
  const MonoAddAction(this.icon, this.label, this.run);

  final IconData icon;
  final String label;

  /// Opens what logs it, from the context of the navigator.
  final void Function(BuildContext) run;
}

/// The five things that can be logged, in the order of the panel.
List<MonoAddAction> monoAddActions(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final health = AppScope.of(context).health;
  return [
    MonoAddAction(
      Icons.water_drop_rounded,
      l10n.metricWater,
      (c) => monoAddGlass(c, health),
    ),
    MonoAddAction(
      Icons.monitor_weight_rounded,
      l10n.metricWeight,
      (c) => monoAddEntry(c, EntryKind.weight),
    ),
    MonoAddAction(
      Icons.restaurant_rounded,
      l10n.entryMeal,
      (c) => monoAddEntry(c, EntryKind.meal),
    ),
    MonoAddAction(
      Icons.fitness_center_rounded,
      l10n.trainingWorkout,
      showTrainingStartSheet,
    ),
    MonoAddAction(
      MonoCategory.supplements.icon,
      l10n.supplement,
      monoAddSupplement,
    ),
  ];
}
