import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/container_route.dart';
import '../../app/formatters.dart';
import '../../app/layout.dart';
import '../../data/models.dart';
import '../../data/workout_insights.dart';
import '../../widgets/animated_count.dart';
import '../../widgets/pressable.dart';
import '../../widgets/shape_badge.dart';
import '../../widgets/tile_surface.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_type.dart';
import '../../theme/page_accent.dart';
import '../../widgets/board_page.dart';
import '../../widgets/chip_carousel.dart';
import '../../widgets/free_figure.dart';
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

/// Whether the tile of the latest workout gives its scene to the page.
bool workoutHeroBleeds(BuildContext context, List<String> shown) =>
    BoardBackdrop.wanted(
      context,
      pageId: 'activity',
      heroId: 'lastWorkout',
      shown: shown,
      inPlace: const {'lastWorkout', 'recentWorkouts'},
    );

/// The scene of a workout of [type] from edge to edge, as the backdrop of
/// the page.
class WorkoutBackdrop extends StatelessWidget {
  const WorkoutBackdrop({super.key, required this.type, required this.extent});

  final WorkoutType type;
  final double extent;

  @override
  Widget build(BuildContext context) => FadingBackdrop(
    child: WorkoutScene(
      type: type,
      height: extent,
      stage: LatestWorkoutCard.sceneHeight + 24,
    ),
  );
}

/// The latest workout. The figure doing it is the one container; the kind
/// of workout sits on its shape over the scene's edge, and below it its
/// name and numbers stand free.
class LatestWorkoutCard extends StatelessWidget {
  const LatestWorkoutCard({super.key, required this.workouts});

  /// Every workout the app knows, oldest first, and not empty.
  final List<Workout> workouts;

  static const double sceneHeight = 132;
  static const double height = sceneHeight + 232;

  static const double _shape = 104;
  static const double _overlap = 48;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final type = AppType.of(context);
    final accent = PageAccent.colorsOf(context);
    final workout = workouts.last;
    final insights = WorkoutInsights.of(workout, workouts);
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
      child: Material(
        type: MaterialType.transparency,
        child: Builder(
          builder: (context) => InkWell(
            borderRadius: BorderRadius.circular(AppRadii.extraLargeIncreased),
            onTap: () {
              final origin = globalRectOf(context);
              if (origin != null) openWorkout(context, workout, origin);
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (BoardBackdrop.isShown(context))
                      const SizedBox(height: sceneHeight)
                    else
                      TileSurface(
                        color: scheme.surfaceBright,
                        radius: AppRadii.extraLargeIncreased,
                        child: WorkoutScene(
                          type: workout.type,
                          height: sceneHeight,
                        ),
                      ),
                    SizedBox(
                      height: _shape - _overlap,
                      child: Padding(
                        padding: const EdgeInsets.only(left: _shape + 28),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.lastActivity,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: type.label(
                                  theme.textTheme.titleSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
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
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              workout.type.label(l10n),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: type.hero(
                                context.emphasizedTextTheme.displaySmall
                                    ?.copyWith(height: 1.05),
                              ),
                            ),
                            Text(
                              '${formats.shortDate(workout.start)} · '
                              '${formats.duration(workout.minutes)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: type.label(
                                theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                for (final comparison in shown)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 10),
                                      child: FreeFigure(
                                        label: comparison.measure.label(l10n),
                                        value: AnimatedNumber(
                                          value: comparison.value,
                                          format: (value) =>
                                              comparison.measure.format(
                                                formats,
                                                workout.type,
                                                value,
                                              ),
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
                              style: type.strong(
                                context.emphasizedTextTheme.titleSmall
                                    ?.copyWith(color: accent.accent),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: 16,
                  top: sceneHeight - _overlap,
                  child: ShapeBadge(
                    shape: workout.type.shape,
                    icon: workout.type.icon,
                    size: _shape,
                    color: accent.accent,
                    iconColor: accent.onAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The workouts before the latest to swipe through, and the way to all of
/// them at the end.
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

  /// A [WorkoutRow] in a list.
  static const double rowHeight = 64;

  static const double height = ChipCarousel.height;

  @override
  Widget build(BuildContext context) {
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final accent = PageAccent.colorsOf(context);
    return ChipCarousel(
      title: l10n.moreActivities,
      children: [
        for (final workout in workouts)
          CarouselChip(
            // A small picture, not a film.
            picture: MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: WorkoutScene(
                type: workout.type,
                height: CarouselChip.pictureHeight,
              ),
            ),
            mark: ShapeBadge(
              shape: workout.type.shape,
              icon: workout.type.icon,
              size: CarouselChip.markSize,
              color: accent.accent,
              iconColor: accent.onAccent,
            ),
            title: workout.type.label(l10n),
            subtitle:
                '${formats.shortDate(workout.start)} · '
                '${formats.duration(workout.minutes)}',
            onTap: (origin) => openWorkout(context, workout, origin),
          ),
        CarouselEndChip(
          title: l10n.allActivities,
          subtitle: l10n.activitiesCount(total),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const WorkoutListPage()),
          ),
        ),
      ],
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
    final type = AppType.of(context);
    // A workout keeps the colour of activity on whatever page it is listed.
    final activity = scheme.tone(Tone.secondary);
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
              color: activity.container,
              iconColor: activity.onContainer,
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
                style: type.figure(
                  context.emphasizedTextTheme.labelLarge?.copyWith(
                    color: activity.accent,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
