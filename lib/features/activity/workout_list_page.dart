import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../data/models.dart';
import '../../widgets/segment_group.dart';
import '../../widgets/entrance.dart';
import '../../widgets/page_header.dart';
import '../../widgets/sub_page.dart';
import 'removed_workouts_page.dart';
import 'workout_style.dart';
import 'workout_tiles.dart';

/// Every workout the app knows, newest first and month by month, with a
/// filter for the kind.
class WorkoutListPage extends StatefulWidget {
  const WorkoutListPage({super.key});

  @override
  State<WorkoutListPage> createState() => _WorkoutListPageState();
}

class _WorkoutListPageState extends State<WorkoutListPage> {
  WorkoutType? _only;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    // The rows the list starts with come in; the ones scrolled to do not.
    return EntranceGate(
      builder: (context, opening) => ListenableBuilder(
        listenable: Listenable.merge([health, scope.settings]),
        builder: (context, _) {
          final formats = Formats.of(context);
          final l10n = formats.l10n;
          final all = health.workouts;
          final removed = health.removedWorkouts.length;
          final kinds = [
            for (final type in WorkoutType.values)
              if (all.any((workout) => workout.type == type)) type,
          ];
          final only = kinds.contains(_only) ? _only : null;

          // A month's heading, then its workouts.
          final rows = <Object>[];
          DateTime? month;
          for (final workout in all.reversed) {
            if (only != null && workout.type != only) continue;
            final start = DateTime(workout.start.year, workout.start.month);
            if (start != month) rows.add(month = start);
            rows.add(workout);
          }

          Widget chip(WorkoutType? type) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(type?.label(l10n) ?? l10n.filterAll),
              selected: only == type,
              onSelected: (_) {
                Haptics.selection();
                setState(() => _only = type);
              },
            ),
          );

          return SubPage(
            title: l10n.allActivities,
            glass: scope.settings.liquidGlass,
            // The way back for what the bin took out of the app. At the top:
            // the list below can be hundreds of rows long.
            action: removed == 0
                ? null
                : IconButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RemovedWorkoutsPage(),
                      ),
                    ),
                    tooltip: l10n.removedActivities,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    icon: Badge.count(
                      count: removed,
                      child: const Icon(Icons.restore_from_trash_rounded),
                    ),
                  ),
            slivers: [
              if (kinds.length > 1)
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [chip(null), ...kinds.map(chip)]),
                  ),
                ),
              SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) => Entrance(
                  order: index,
                  animate: index < Entrance.staggered && opening(),
                  child: switch (rows[index]) {
                    final DateTime month => SectionTitle(
                      formats.month(month),
                      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                    ),
                    // The workouts of a month are one group of segments.
                    final Workout workout => ListSegment(
                      first: rows[index - 1] is DateTime,
                      last:
                          index == rows.length - 1 ||
                          rows[index + 1] is DateTime,
                      child: WorkoutRow(workout: workout),
                    ),
                    _ => const SizedBox.shrink(),
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
