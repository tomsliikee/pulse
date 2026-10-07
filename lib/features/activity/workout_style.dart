import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../l10n/generated/app_localizations.dart';

/// How a [WorkoutType] is named and drawn.
extension WorkoutStyle on WorkoutType {
  String label(AppLocalizations l10n) => switch (this) {
    WorkoutType.run => l10n.workoutRun,
    WorkoutType.ride => l10n.workoutRide,
    WorkoutType.walk => l10n.workoutWalk,
    WorkoutType.hike => l10n.workoutHike,
    WorkoutType.other => l10n.workoutOther,
    WorkoutType.strength => l10n.workoutStrength,
    WorkoutType.yoga => l10n.workoutYoga,
    WorkoutType.swim => l10n.workoutSwim,
  };

  IconData get icon => switch (this) {
    WorkoutType.run => Icons.directions_run_rounded,
    WorkoutType.ride => Icons.directions_bike_rounded,
    WorkoutType.walk => Icons.directions_walk_rounded,
    WorkoutType.hike => Icons.hiking_rounded,
    WorkoutType.other => Icons.sports_rounded,
    WorkoutType.strength => Icons.fitness_center_rounded,
    WorkoutType.yoga => Icons.self_improvement_rounded,
    WorkoutType.swim => Icons.pool_rounded,
  };

  Shapes get shape => switch (this) {
    WorkoutType.run => Shapes.slanted,
    WorkoutType.ride => Shapes.c6SidedCookie,
    WorkoutType.walk => Shapes.arch,
    WorkoutType.hike => Shapes.triangle,
    WorkoutType.other => Shapes.c4SidedCookie,
    WorkoutType.strength => Shapes.gem,
    WorkoutType.yoga => Shapes.flower,
    WorkoutType.swim => Shapes.puffy,
  };
}
