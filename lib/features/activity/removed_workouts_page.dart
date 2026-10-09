import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../data/health_controller.dart';
import '../../data/workout_archive.dart';
import '../../widgets/entrance.dart';
import '../../widgets/segment_group.dart';
import '../../widgets/sub_page.dart';
import 'workout_tiles.dart';

/// The workouts the user took out of the app, the latest removal first,
/// each with a button that brings it back with its values.
class RemovedWorkoutsPage extends StatelessWidget {
  const RemovedWorkoutsPage({super.key});

  Future<void> _restore(
    BuildContext context,
    HealthController health,
    RemovedWorkout removed,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = Formats.of(context).l10n;
    // Nothing is left to list after the last one.
    if (health.removedWorkouts.length == 1) navigator.maybePop();
    try {
      await health.restoreWorkout(removed);
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.restoreFailed)));
      return;
    }
    Haptics.confirm();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.workoutRestored)));
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    return EntranceGate(
      builder: (context, opening) => ListenableBuilder(
        listenable: Listenable.merge([health, scope.settings]),
        builder: (context, _) {
          final l10n = Formats.of(context).l10n;
          final rows = health.removedWorkouts.reversed.toList();
          return SubPage(
            title: l10n.removedActivities,
            glass: scope.settings.liquidGlass,
            slivers: [
              SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) => Entrance(
                  order: index,
                  animate: index < Entrance.staggered && opening(),
                  child: ListSegment(
                    first: index == 0,
                    last: index == rows.length - 1,
                    child: WorkoutRow(
                      workout: rows[index].workout,
                      onRestore: () => _restore(context, health, rows[index]),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
