import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../app/layout.dart';
import '../../data/health_controller.dart';
import '../../data/health_snapshot.dart';
import '../../data/metric_catalog.dart';
import '../../data/models.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_shapes.dart';
import '../../widgets/animated_count.dart';
import '../../widgets/board_page.dart';
import '../../widgets/line_chart.dart';
import '../../widgets/pressable.dart';
import '../../widgets/progress_ring.dart';
import '../../widgets/shape_badge.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/tile_board.dart';
import '../../widgets/page_header.dart';
import '../activity/workout_style.dart';
import '../browse/all_data_section.dart';
import '../detail/metric_spec.dart';
import '../detail/metric_tiles.dart';
import '../profile/profile_page.dart';

/// The summary of the selected day.
class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    final settings = scope.settings;
    return ListenableBuilder(
      listenable: Listenable.merge([health, settings]),
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final snapshot = health.snapshot;
        // This page always shows today, whatever day is selected elsewhere.
        final today = health.todayIndex;
        final night = snapshot.nights[today];
        final workout = health.latestWorkout;
        final heart = snapshot.heart[today];
        final water = snapshot.value(Metric.water, today);

        return BoardPage(
          pageId: 'today',
          title: 'Heute',
          subtitle: formatLongDate(snapshot.dateAt(today)),
          trailing: const _ProfileButton(),
          editMenu: SurfaceCard(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Alle Daten anzeigen',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Switch(
                  value: settings.showAllData,
                  onChanged: (value) {
                    Haptics.selection();
                    settings.setShowAllData(value);
                  },
                ),
              ],
            ),
          ),
          footer: !settings.showAllData
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    const SectionTitle(
                      'Alle Daten',
                      padding: EdgeInsets.symmetric(horizontal: 4),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
                      child: Text(
                        'Letzte 30 Tage aus Health Connect',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    AllDataSection(snapshot: snapshot),
                  ],
                ),
          tiles: [
            BoardTile(
              id: 'steps',
              height: 404,
              child: _StepsHero(health: health, stepGoal: settings.stepGoal),
            ),
            if (snapshot.has(Metric.restingHeartRate))
              metricTile(
                context,
                health,
                Metric.restingHeartRate,
                dayIndex: today,
                footer: heart.length < 2
                    ? null
                    : LineChart(
                        values: [for (final s in heart) s.bpm.toDouble()],
                        color: scheme.tertiary,
                        height: 32,
                        strokeWidth: 3,
                      ),
              ),
            if (snapshot.has(Metric.sleep))
              metricTile(
                context,
                health,
                Metric.sleep,
                dayIndex: today,
                footer: night == null
                    ? null
                    : _Caption(
                        'Score ${night.estimatedScore} (Schätzung)',
                        color: scheme.onSecondaryContainer,
                      ),
              ),
            if (snapshot.has(Metric.activeEnergy))
              metricTile(
                context,
                health,
                Metric.activeEnergy,
                title: 'Kalorien',
                dayIndex: today,
              ),
            metricTile(
              context,
              health,
              Metric.water,
              dayIndex: today,
              footer: M3ELinearWavyProgressIndicator(
                value: ((water ?? 0) * 1000 / settings.waterGoalMl)
                    .clamp(0, 1)
                    .toDouble(),
                color: scheme.primary,
                backgroundColor: scheme.secondaryContainer,
              ),
            ),
            if (snapshot.has(Metric.weight))
              metricTile(context, health, Metric.weight, dayIndex: today),
            if (snapshot.has(Metric.oxygenSaturation))
              metricTile(
                context,
                health,
                Metric.oxygenSaturation,
                title: 'Sauerstoff',
                dayIndex: today,
              ),
            BoardTile(
              id: 'nutrition',
              height: 196,
              child: _NutritionCard(snapshot: snapshot, dayIndex: today),
            ),
            if (workout != null)
              BoardTile(
                id: 'workout',
                height: 132,
                child: _WorkoutCard(workout: workout),
              ),
          ],
        );
      },
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    void open() =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const ProfilePage()));
    return Semantics(
      container: true,
      button: true,
      label: 'Profil',
      onTap: open,
      excludeSemantics: true,
      child: Pressable(
        pressedScale: 0.88,
        child: GestureDetector(
          onTap: open,
          child: M3EContainer(
            Shapes.c7SidedCookie,
            width: 56,
            height: 56,
            color: scheme.tertiary,
            child: Icon(Icons.person_rounded, color: scheme.onTertiary),
          ),
        ),
      ),
    );
  }
}

/// The hero moment: steps and active minutes as rings on a cookie shape.
class _StepsHero extends StatelessWidget {
  const _StepsHero({required this.health, required this.stepGoal});

  final HealthController health;
  final int stepGoal;

  /// What the WHO recommends per day, and what fills the inner ring.
  static const _intensityGoalMinutes = 30;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final emphasized = context.emphasizedTextTheme;
    final today = health.todayIndex;
    final steps = health.valueAt(Metric.steps, today);
    final minutes = health.valueAt(Metric.intensityMinutes, today);
    final valueStyle = emphasized.displaySmall?.copyWith(
      color: scheme.onPrimaryContainer,
    );

    return Pressable(
      pressedScale: 0.97,
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.extraExtraLarge),
        clipBehavior: Clip.antiAlias,
        child: Builder(
          builder: (context) => InkWell(
            onTap: () {
              final origin = globalRectOf(context);
              if (origin != null) openMetric(context, Metric.steps, origin);
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                children: [
                  SizedBox.square(
                    dimension: 268,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        M3EShape(
                          Shapes.c12SidedCookie,
                          width: 268,
                          height: 268,
                          color: scheme.primary.withValues(alpha: 0.12),
                        ),
                        SizedBox.square(
                          dimension: 228,
                          child: ProgressRing(
                            value: (steps ?? 0) / stepGoal,
                            color: scheme.primary,
                            trackColor: scheme.primary.withValues(alpha: 0.16),
                          ),
                        ),
                        if (minutes != null)
                          SizedBox.square(
                            dimension: 184,
                            child: ProgressRing(
                              value: minutes / _intensityGoalMinutes,
                              color: scheme.tertiary,
                              trackColor: scheme.tertiary.withValues(
                                alpha: 0.16,
                              ),
                            ),
                          ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (steps == null)
                              Text('–', style: valueStyle)
                            else
                              AnimatedCount(
                                value: steps.round(),
                                style: valueStyle,
                              ),
                            Text(
                              'von ${formatInt(stepGoal)}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: scheme.onPrimaryContainer.withValues(
                                  alpha: 0.72,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      _HeroStat(
                        value: Metric.intensityMinutes.format(minutes),
                        label: 'Minuten',
                        shape: Shapes.sunny,
                        color: scheme.tertiary,
                      ),
                      _HeroStat(
                        value: Metric.distance.format(
                          health.valueAt(Metric.distance, today),
                        ),
                        label: 'Kilometer',
                        shape: Shapes.pentagon,
                        color: scheme.primary,
                      ),
                      _HeroStat(
                        value: Metric.floors.format(
                          health.valueAt(Metric.floors, today),
                        ),
                        label: 'Etagen',
                        shape: Shapes.arch,
                        color: scheme.secondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.value,
    required this.label,
    required this.shape,
    required this.color,
  });

  final String value;
  final String label;
  final Shapes shape;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onContainer = theme.colorScheme.onPrimaryContainer;
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              M3EShape(shape, width: 14, height: 14, color: color),
              const SizedBox(width: 6),
              Text(
                value,
                style: context.emphasizedTextTheme.titleLarge?.copyWith(
                  color: onContainer,
                ),
              ),
            ],
          ),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: onContainer.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

/// Eaten calories and the three macronutrients of the selected day.
class _NutritionCard extends StatelessWidget {
  const _NutritionCard({required this.snapshot, required this.dayIndex});

  final HealthSnapshot snapshot;
  final int dayIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kcal = snapshot.value(Metric.energyIntake, dayIndex);
    final parts = [
      (Metric.carbs, 'Kohlenhydrate', scheme.primary),
      (Metric.protein, 'Eiweiss', scheme.secondary),
      (Metric.fat, 'Fett', scheme.tertiary),
    ];
    var total = 0.0;
    for (final (metric, _, _) in parts) {
      total += snapshot.value(metric, dayIndex) ?? 0;
    }

    return Pressable(
      pressedScale: 0.97,
      child: Material(
        color: scheme.surfaceBright,
        borderRadius: BorderRadius.circular(AppRadii.extraLargeIncreased),
        clipBehavior: Clip.antiAlias,
        child: Builder(
          builder: (context) => InkWell(
            onTap: () {
              final origin = globalRectOf(context);
              if (origin != null) {
                openMetric(context, Metric.energyIntake, origin);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ShapeBadge(
                        shape: Metric.energyIntake.spec.shape,
                        icon: Metric.energyIntake.spec.icon,
                        size: 44,
                        color: scheme.tertiary,
                        iconColor: scheme.onTertiary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Ernährung',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        kcal == null
                            ? 'Noch nichts eingetragen'
                            : Metric.energyIntake.formatWithUnit(kcal),
                        style: kcal == null
                            ? theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              )
                            : context.emphasizedTextTheme.titleLarge,
                      ),
                    ],
                  ),
                  const Spacer(),
                  for (final (metric, label, color) in parts) ...[
                    Row(
                      children: [
                        SizedBox(
                          width: 112,
                          child: Text(label, style: theme.textTheme.labelLarge),
                        ),
                        Expanded(
                          child: _Bar(
                            fraction: total == 0
                                ? 0
                                : (snapshot.value(metric, dayIndex) ?? 0) /
                                      total,
                            color: color,
                            trackColor: scheme.surfaceContainerHighest,
                          ),
                        ),
                        SizedBox(
                          width: 56,
                          child: Text(
                            metric.formatWithUnit(
                              snapshot.value(metric, dayIndex),
                            ),
                            textAlign: TextAlign.end,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (metric != Metric.fat) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.color,
    required this.trackColor,
  });

  final double fraction;
  final Color color;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 10,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: trackColor,
          shape: const StadiumBorder(),
        ),
        child: SingleMotionBuilder(
          value: fraction,
          motion: AppMotion.spatial,
          builder: (context, current, _) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: current.clamp(0, 1).toDouble(),
              heightFactor: 1,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: color,
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final distance = workout.distanceKm;
    final kcal = workout.kcal;
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Letztes Training', style: theme.textTheme.titleSmall),
          const Spacer(),
          Row(
            children: [
              ShapeBadge(
                shape: workout.type.shape,
                icon: workout.type.icon,
                size: 56,
                color: scheme.primary,
                iconColor: scheme.onPrimary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout.type.label,
                      style: context.emphasizedTextTheme.titleMedium,
                    ),
                    Text(
                      [
                        formatShortDate(workout.start),
                        formatDuration(workout.minutes),
                        if (distance != null) '${formatDecimal(distance)} km',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (kcal != null) ...[
                const SizedBox(width: 8),
                Text(
                  '$kcal kcal',
                  style: context.emphasizedTextTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
