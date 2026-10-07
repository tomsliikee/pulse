import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../data/models.dart';
import '../../theme/app_shapes.dart';
import '../../widgets/page_header.dart';
import '../../widgets/sub_page.dart';
import '../../widgets/tile_surface.dart';
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
    return ListenableBuilder(
      listenable: Listenable.merge([health, scope.settings]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final formats = Formats.of(context);
        final l10n = formats.l10n;
        final all = health.workouts;
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
              itemBuilder: (context, index) => switch (rows[index]) {
                final DateTime month => SectionTitle(
                  formats.month(month),
                  padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                ),
                final Workout workout => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TileSurface(
                    color: scheme.surfaceBright,
                    radius: AppRadii.extraLarge,
                    child: SizedBox(
                      height: 72,
                      child: WorkoutRow(workout: workout),
                    ),
                  ),
                ),
                _ => const SizedBox.shrink(),
              },
            ),
          ],
        );
      },
    );
  }
}
