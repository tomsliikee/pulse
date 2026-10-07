import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/container_route.dart';
import '../../app/formatters.dart';
import '../../app/layout.dart';
import '../../data/models.dart';
import '../../data/workout_insights.dart';
import '../../widgets/pressable.dart';
import '../../widgets/shape_badge.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/tile_surface.dart';
import '../../theme/app_shapes.dart';
import 'workout_detail_page.dart';
import 'workout_format.dart';
import 'workout_list_page.dart';
import 'workout_scene.dart';
import 'workout_style.dart';

/// Opens the page about [workout], growing it out of the rectangle [origin]
/// of what was tapped.
void openWorkout(BuildContext context, Workout workout, Rect origin) {
  Navigator.of(context).push(
    ContainerRoute<void>(
      origin: origin,
      originColor: Theme.of(context).colorScheme.surfaceBright,
      builder: (_) => WorkoutDetailPage(workout: workout),
    ),
  );
}

/// The latest workout: a figure doing it, its numbers and how it went
/// against the one before.
class LatestWorkoutCard extends StatelessWidget {
  const LatestWorkoutCard({super.key, required this.workouts});

  /// Every workout the app knows, oldest first, and not empty.
  final List<Workout> workouts;

  static const double sceneHeight = 132;
  static const double height = sceneHeight + 178;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final workout = workouts.last;
    final insights = WorkoutInsights.of(workout, workouts);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final shown = [
      for (final measure in const [
        WorkoutMeasure.distance,
        WorkoutMeasure.pace,
        WorkoutMeasure.speed,
        WorkoutMeasure.energy,
        WorkoutMeasure.avgHeartRate,
      ])
        ?insights.measure(measure),
    ].take(3);

    return Pressable(
      pressedScale: 0.98,
      child: TileSurface(
        color: scheme.surfaceBright,
        radius: AppRadii.extraLargeIncreased,
        child: InkWell(
          onTap: () {
            final origin = globalRectOf(context);
            if (origin != null) openWorkout(context, workout, origin);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WorkoutScene(type: workout.type, height: sceneHeight),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.lastActivity,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              workout.type.label(l10n),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.emphasizedTextTheme.headlineSmall,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      Text(
                        '${formats.shortDate(workout.start)} · '
                        '${formats.duration(workout.minutes)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          for (final comparison in shown)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: _Figure(
                                  label: comparison.measure.label(l10n),
                                  value: comparison.measure.format(
                                    formats,
                                    workout.type,
                                    comparison.value,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        workoutHeadline(formats, insights),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.emphasizedTextTheme.titleSmall?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: context.emphasizedTextTheme.titleMedium,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The workouts before the latest, and the way to all of them.
class RecentWorkoutsCard extends StatelessWidget {
  const RecentWorkoutsCard({
    super.key,
    required this.workouts,
    required this.total,
  });

  /// Newest first.
  final List<Workout> workouts;

  /// How many workouts there are altogether.
  final int total;

  static const double rowHeight = 64;

  static double heightFor(int rows) => 76 + (rows + 1) * rowHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = Formats.of(context).l10n;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              l10n.moreActivities,
              style: context.emphasizedTextTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 12),
          for (final workout in workouts)
            SizedBox(
              height: rowHeight,
              child: WorkoutRow(workout: workout),
            ),
          SizedBox(
            height: rowHeight,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WorkoutListPage(),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.allActivities,
                        style: context.emphasizedTextTheme.titleSmall?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    Text(
                      l10n.activitiesCount(total),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One workout in a list. Tapping it opens the page about it.
class WorkoutRow extends StatelessWidget {
  const WorkoutRow({super.key, required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final distance = workout.distanceKm;
    return InkWell(
      onTap: () {
        final origin = globalRectOf(context);
        if (origin != null) openWorkout(context, workout, origin);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            ShapeBadge(
              shape: workout.type.shape,
              icon: workout.type.icon,
              size: 44,
              color: scheme.secondaryContainer,
              iconColor: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workout.type.label(l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    [
                      formats.shortDate(workout.start),
                      formats.duration(workout.minutes),
                      if (distance != null && distance > 0)
                        WorkoutMeasure.distance.format(
                          formats,
                          workout.type,
                          distance,
                        ),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (workout.kcal case final kcal?) ...[
              const SizedBox(width: 8),
              Text(
                '${formats.integer(kcal)} kcal',
                style: context.emphasizedTextTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
