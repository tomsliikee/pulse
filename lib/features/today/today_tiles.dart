import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../../app/container_route.dart';
import '../../app/formatters.dart';
import '../../app/layout.dart';
import '../../data/night_insights.dart';
import '../../data/health_controller.dart';
import '../../data/health_snapshot.dart';
import '../../data/metric_catalog.dart';
import '../../data/models.dart';
import '../../data/settings_controller.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/line_chart.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/pressable.dart';
import '../../widgets/progress_ring.dart';
import '../../widgets/shape_badge.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/tile_board.dart';
import '../../widgets/tile_surface.dart';
import '../activity/workout_style.dart';
import '../activity/workout_tiles.dart';
import '../age/body_age_page.dart';
import '../detail/large_metric_tile.dart';
import '../detail/metric_spec.dart';
import '../detail/metric_tiles.dart';
import '../../l10n/generated/app_localizations.dart';

/// Whether the tile [id] has something to show: data in the store, or a
/// measurement the user can record here.
bool todayTileAvailable(String id, HealthController health) {
  if (id == workoutTileId) return health.latestWorkout != null;
  final metric = Metric.byName(id);
  if (metric == null) return false;
  return metric.entryKind != null || health.snapshot.has(metric);
}

/// The name on a tile. Shorter than the catalog's where that would not fit
/// a half-width tile.
String todayTileTitle(AppLocalizations l10n, String id) =>
    switch (Metric.byName(id)) {
      null => l10n.lastWorkout,
      Metric.heartRate => l10n.shortHeartRate,
      Metric.totalEnergy => l10n.shortCalories,
      Metric.oxygenSaturation => l10n.shortOxygen,
      Metric.energyIntake => l10n.groupNutrition,
      Metric.heartRateVariability => l10n.shortHrv,
      Metric.skinTemperature => l10n.shortSkinTemperature,
      Metric.systolic => l10n.shortSystolic,
      Metric.diastolic => l10n.shortDiastolic,
      final metric => metric.title(l10n),
    };

/// The tile [id] of the Today page in the size the user chose, or null when
/// there is nothing to show for it.
BoardTile? buildTodayTile(
  BuildContext context, {
  required String id,
  required HealthController health,
  required SettingsController settings,
}) {
  if (!todayTileAvailable(id, health)) return null;
  void remove() => settings.removeTodayTile(id);

  final metric = Metric.byName(id);
  if (metric == null) {
    return BoardTile(
      id: id,
      height: 132,
      onRemove: remove,
      child: _WorkoutCard(workout: health.latestWorkout!),
    );
  }

  final large = settings.isLargeTile(id);
  void resize() => settings.toggleTileSize(id);
  if (!large) {
    return BoardTile(
      id: id,
      span: TileSpan.half,
      height: 176,
      onRemove: remove,
      onResize: resize,
      child: _SmallTile(metric: metric, health: health, settings: settings),
    );
  }
  return BoardTile(
    id: id,
    height: switch (metric) {
      Metric.steps => 316,
      Metric.energyIntake => 196,
      _ => 272,
    },
    large: true,
    onRemove: remove,
    onResize: resize,
    child: switch (metric) {
      Metric.steps => _StepsHero(health: health, settings: settings),
      Metric.energyIntake => _NutritionCard(
        snapshot: health.snapshot,
        dayIndex: health.todayIndex,
      ),
      _ => LargeMetricTile(
        metric: metric,
        title: todayTileTitle(AppLocalizations.of(context), id),
        health: health,
        settings: settings,
      ),
    },
  );
}

class _SmallTile extends StatelessWidget {
  const _SmallTile({
    required this.metric,
    required this.health,
    required this.settings,
  });

  final Metric metric;
  final HealthController health;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final spec = metric.spec;
    final colors = scheme.tone(spec.tone);
    final snapshot = health.snapshot;
    final today = health.todayIndex;
    final reading = tileReading(formats, snapshot, metric);
    final value = reading.value;
    final note = reading.note;
    final night = snapshot.nights[today];
    final heart = snapshot.heart[today];

    final Widget? footer = switch (metric) {
      Metric.heartRate when heart.length >= 2 => LineChart(
        values: [for (final s in heart) s.bpm.toDouble()],
        color: colors.accent,
        height: 32,
        strokeWidth: 3,
      ),
      Metric.sleep when night != null => _Caption(
        l10n.scoreEstimate(
          sleepScore(night, settings.sleepGoalHours, health.nights).total,
        ),
        color: colors.onContainer,
      ),
      Metric.water => M3ELinearWavyProgressIndicator(
        value: ((value ?? 0) * 1000 / settings.waterGoalMl)
            .clamp(0, 1)
            .toDouble(),
        color: scheme.primary,
        backgroundColor: scheme.secondaryContainer,
      ),
      Metric.heartRate => null,
      _ when note != null => _Caption(note, color: colors.onContainer),
      _ => null,
    };

    return MetricCard(
      label: todayTileTitle(l10n, metric.name),
      value: metricValueOf(metric, value),
      // "Schritte" twice in one tile says nothing.
      unit: metric.isCount ? null : metric.unit,
      icon: spec.icon,
      shape: spec.shape,
      tone: spec.tone,
      footer: footer,
      trailing: metric != Metric.steps
          ? null
          : SizedBox.square(
              dimension: 36,
              child: ProgressRing(
                value: (value ?? 0) / settings.stepGoal,
                color: colors.accent,
                trackColor: colors.accent.withValues(alpha: 0.16),
                strokeWidth: 6,
              ),
            ),
      onTap: (origin) => openMetric(context, metric, origin),
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

/// The hero moment: steps and active calories as two rings on a cookie
/// shape around the body age, with the day's numbers underneath. The age
/// opens its own page; a tap anywhere else opens the steps.
class _StepsHero extends StatelessWidget {
  const _StepsHero({required this.health, required this.settings});

  final HealthController health;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final today = health.todayIndex;
    final steps = health.valueAt(Metric.steps, today);
    final distance = health.valueAt(Metric.distance, today);
    final energy = health.valueAt(Metric.activeEnergy, today);

    return Pressable(
      pressedScale: 0.97,
      child: TileSurface(
        color: scheme.primaryContainer,
        radius: AppRadii.extraExtraLarge,
        child: Builder(
          builder: (context) => InkWell(
            onTap: () {
              final origin = globalRectOf(context);
              if (origin != null) openMetric(context, Metric.steps, origin);
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                children: [
                  SizedBox.square(
                    dimension: 212,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _TurningShape(
                          color: scheme.primary.withValues(alpha: 0.12),
                        ),
                        SizedBox.square(
                          dimension: 176,
                          child: ProgressRing(
                            value: (steps ?? 0) / settings.stepGoal,
                            color: scheme.primary,
                            trackColor: scheme.primary.withValues(alpha: 0.16),
                            strokeWidth: 14,
                          ),
                        ),
                        SizedBox.square(
                          dimension: 140,
                          child: ProgressRing(
                            value: (energy ?? 0) / settings.activeEnergyGoal,
                            color: scheme.tertiary,
                            trackColor: scheme.tertiary.withValues(alpha: 0.16),
                            strokeWidth: 12,
                          ),
                        ),
                        _AgeButton(
                          age: bodyAgeOf(health, settings)?.age,
                          hasBirthDate: settings.birthDate != null,
                          onTap: () {
                            final origin = globalRectOf(context);
                            if (origin == null) return;
                            Navigator.of(context).push(
                              ContainerRoute<void>(
                                origin: origin,
                                originColor: scheme.primaryContainer,
                                originRadius: AppRadii.extraExtraLarge,
                                builder: (_) => const BodyAgePage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      _HeroStat(
                        value: Metric.steps.format(formats, steps),
                        label: l10n.metricSteps,
                        shape: Shapes.circle,
                        color: scheme.primary,
                      ),
                      _HeroStat(
                        value: Metric.activeEnergy.format(formats, energy),
                        label: l10n.shortCalories,
                        shape: Shapes.burst,
                        color: scheme.tertiary,
                      ),
                      if (distance != null)
                        _HeroStat(
                          value: Metric.distance.format(formats, distance),
                          label: l10n.kilometers,
                          shape: Shapes.pentagon,
                          color: scheme.onPrimaryContainer.withValues(
                            alpha: 0.72,
                          ),
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

/// The body age in the middle of the rings, as a button of its own.
class _AgeButton extends StatelessWidget {
  const _AgeButton({
    required this.age,
    required this.hasBirthDate,
    required this.onTap,
  });

  final double? age;
  final bool hasBirthDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onContainer = theme.colorScheme.onPrimaryContainer;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final age = this.age;
    return Semantics(
      container: true,
      button: true,
      label: age == null
          ? l10n.bodyAgeDetailsA11y
          : l10n.bodyAgeEstimateA11y(formats.decimal(age)),
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        pressedScale: 0.9,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          // The whole space inside the inner ring is the button.
          child: SizedBox.square(
            dimension: 112,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  age == null ? '–' : formats.decimal(age),
                  maxLines: 1,
                  style: context.emphasizedTextTheme.headlineLarge?.copyWith(
                    color: onContainer,
                  ),
                ),
                Text(
                  hasBirthDate ? l10n.bodyAge : l10n.setAge,
                  maxLines: 1,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: onContainer.withValues(alpha: 0.72),
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

  /// The colour of the ring the number belongs to.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onContainer = theme.colorScheme.onPrimaryContainer;
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                M3EShape(shape, width: 14, height: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  value,
                  maxLines: 1,
                  style: context.emphasizedTextTheme.titleLarge?.copyWith(
                    color: onContainer,
                  ),
                ),
              ],
            ),
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
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final kcal = snapshot.value(Metric.energyIntake, dayIndex);
    final parts = [
      (Metric.carbs, l10n.metricCarbs, scheme.primary),
      (Metric.protein, l10n.metricProtein, scheme.secondary),
      (Metric.fat, l10n.metricFat, scheme.tertiary),
    ];
    var total = 0.0;
    for (final (metric, _, _) in parts) {
      total += snapshot.value(metric, dayIndex) ?? 0;
    }

    return Pressable(
      pressedScale: 0.97,
      child: TileSurface(
        color: scheme.surfaceBright,
        radius: AppRadii.extraLargeIncreased,
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
                          l10n.groupNutrition,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        kcal == null
                            ? l10n.nothingEntered
                            : Metric.energyIntake.formatWithUnit(formats, kcal),
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
                              formats,
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
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final distance = workout.distanceKm;
    final kcal = workout.kcal;
    return Pressable(
      child: GestureDetector(
        onTap: () {
          final origin = globalRectOf(context);
          if (origin != null) openWorkout(context, workout, origin);
        },
        child: _card(context, theme, scheme, formats, l10n, distance, kcal),
      ),
    );
  }

  Widget _card(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    Formats formats,
    AppLocalizations l10n,
    double? distance,
    int? kcal,
  ) {
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.lastWorkout, style: theme.textTheme.titleSmall),
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
                      workout.type.label(l10n),
                      style: context.emphasizedTextTheme.titleMedium,
                    ),
                    Text(
                      [
                        formats.shortDate(workout.start),
                        formats.duration(workout.minutes),
                        if (distance != null) '${formats.decimal(distance)} km',
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

/// The cookie behind the rings of the steps tile. It turns slowly, and stands
/// still when the system asks for no animations.
class _TurningShape extends StatefulWidget {
  const _TurningShape({required this.color});

  final Color color;

  @override
  State<_TurningShape> createState() => _TurningShapeState();
}

class _TurningShapeState extends State<_TurningShape>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 90),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _turn.stop();
    } else if (!_turn.isAnimating) {
      _turn.repeat();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Its own layer, so the rings and the numbers are not painted again.
    return RepaintBoundary(
      child: RotationTransition(
        turns: _turn,
        child: M3EShape(
          Shapes.c12SidedCookie,
          width: 212,
          height: 212,
          color: widget.color,
        ),
      ),
    );
  }
}
