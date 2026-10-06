import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../../app/formatters.dart';
import '../../app/layout.dart';
import '../../data/health_controller.dart';
import '../../data/health_snapshot.dart';
import '../../data/metric_catalog.dart';
import '../../data/models.dart';
import '../../data/settings_controller.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_count.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/line_chart.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/pressable.dart';
import '../../widgets/progress_ring.dart';
import '../../widgets/shape_badge.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/tile_board.dart';
import '../activity/workout_style.dart';
import '../detail/metric_spec.dart';

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
String todayTileTitle(String id) => switch (Metric.byName(id)) {
  null => 'Letztes Training',
  Metric.heartRate => 'Herzfrequenz',
  Metric.totalEnergy => 'Kalorien',
  Metric.oxygenSaturation => 'Sauerstoff',
  Metric.energyIntake => 'Ernährung',
  Metric.heartRateVariability => 'HRV',
  Metric.skinTemperature => 'Hauttemperatur',
  Metric.systolic => 'Systolisch',
  Metric.diastolic => 'Diastolisch',
  final metric => metric.spec.title,
};

/// What a tile shows for a metric, and a remark when that is not simply
/// today's value.
typedef TileReading = ({double? value, String? note});

/// Totals and averages are today's. A heart rate is the latest sample of
/// today. Measurements taken now and then (weight, blood pressure, the one
/// resting heart rate a day) show the most recent one with its day, because
/// "nothing today" would hide a value that still holds.
TileReading tileReading(HealthSnapshot snapshot, Metric metric) {
  final today = snapshot.dayCount - 1;
  if (metric == Metric.heartRate) {
    final samples = snapshot.heart[today];
    if (samples.isEmpty) return (value: null, note: null);
    return (
      value: samples.last.bpm.toDouble(),
      note: 'Zuletzt um ${formatClock(samples.last.minuteOfDay)}',
    );
  }
  if (metric.rule == DayRule.last || metric == Metric.restingHeartRate) {
    final index = snapshot.latestIndex(metric);
    if (index == null) return (value: null, note: null);
    return (
      value: snapshot.value(metric, index),
      note: index == today
          ? null
          : formatRelativeDay(snapshot.dateAt(index), snapshot.dateAt(today)),
    );
  }
  return (value: snapshot.value(metric, today), note: null);
}

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
      Metric.steps => _StepsHero(health: health, stepGoal: settings.stepGoal),
      Metric.energyIntake => _NutritionCard(
        snapshot: health.snapshot,
        dayIndex: health.todayIndex,
      ),
      _ => _LargeTile(metric: metric, health: health, settings: settings),
    },
  );
}

Widget _valueOf(Metric metric, double? value) {
  if (value != null && metric.digits == 0) {
    return AnimatedCount(value: value.round());
  }
  return Text(metric.format(value), maxLines: 1);
}

/// The goal the user set for [metric], in the metric's unit, if it has one.
double? _goalOf(Metric metric, SettingsController settings) => switch (metric) {
  Metric.steps => settings.stepGoal.toDouble(),
  Metric.water => settings.waterGoalMl / 1000,
  Metric.sleep => settings.sleepGoalHours,
  _ => null,
};

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
    final spec = metric.spec;
    final colors = scheme.tone(spec.tone);
    final snapshot = health.snapshot;
    final today = health.todayIndex;
    final reading = tileReading(snapshot, metric);
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
        'Score ${night.estimatedScore} (Schätzung)',
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
      label: todayTileTitle(metric.name),
      value: _valueOf(metric, value),
      // "Schritte" twice in one tile says nothing.
      unit: metric.unit == spec.title ? null : metric.unit,
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

/// The large form of a tile: the value, a remark, and the last seven days
/// as bars (for a heart rate, today's curve).
class _LargeTile extends StatelessWidget {
  const _LargeTile({
    required this.metric,
    required this.health,
    required this.settings,
  });

  final Metric metric;
  final HealthController health;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final spec = metric.spec;
    final colors = scheme.tone(spec.tone);
    final neutral = spec.tone == Tone.neutral;
    final snapshot = health.snapshot;
    final today = health.todayIndex;
    final reading = tileReading(snapshot, metric);
    final night = snapshot.nights[today];
    final heart = snapshot.heart[today];
    final goal = _goalOf(metric, settings);
    final muted = colors.onContainer.withValues(alpha: 0.72);

    final week = snapshot.valuesOf(metric).sublist(snapshot.dayCount - 7);
    final known = week.whereType<double>().toList();
    final average = known.isEmpty
        ? null
        : known.reduce((a, b) => a + b) / known.length;
    var low = double.infinity;
    var high = 0.0;
    for (final v in known) {
      if (v < low) low = v;
      if (v > high) high = v;
    }

    // Top right: what puts the large number into proportion.
    final String? aside = switch (metric) {
      Metric.heartRate when heart.isNotEmpty => () {
        var min = heart.first.bpm;
        var max = min;
        for (final s in heart) {
          if (s.bpm < min) min = s.bpm;
          if (s.bpm > max) max = s.bpm;
        }
        return '$min bis $max bpm';
      }(),
      Metric.heartRate => null,
      _ when average != null => 'Ø ${metric.formatWithUnit(average)}',
      _ => null,
    };
    final value = reading.value;
    final String? remark = switch (metric) {
      Metric.sleep when night != null =>
        '${formatClock(night.bedtimeMinute)} bis '
            '${formatClock(night.wakeMinute)} · '
            'Score ${night.estimatedScore} (Schätzung)',
      Metric.water when goal != null =>
        '${((value ?? 0) / goal * 100).round()} % von '
            '${metric.formatWithUnit(goal)}',
      _ => reading.note,
    };

    return Pressable(
      pressedScale: 0.97,
      child: Material(
        color: colors.container,
        borderRadius: BorderRadius.circular(AppRadii.extraLargeIncreased),
        clipBehavior: Clip.antiAlias,
        child: Builder(
          builder: (context) => InkWell(
            onTap: () {
              final origin = globalRectOf(context);
              if (origin != null) openMetric(context, metric, origin);
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ShapeBadge(
                        shape: spec.shape,
                        icon: spec.icon,
                        size: 44,
                        color: neutral
                            ? scheme.secondaryContainer
                            : colors.accent,
                        iconColor: neutral
                            ? scheme.onSecondaryContainer
                            : colors.container,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          todayTileTitle(metric.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colors.onContainer,
                          ),
                        ),
                      ),
                      if (aside != null)
                        Text(
                          aside,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: muted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      DefaultTextStyle.merge(
                        style: context.emphasizedTextTheme.headlineLarge
                            ?.copyWith(color: colors.onContainer),
                        child: _valueOf(metric, value),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        metric.unit,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: muted,
                        ),
                      ),
                      if (remark != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            remark,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: metric == Metric.heartRate
                        ? (heart.length < 2
                              ? const SizedBox.shrink()
                              : LineChart(
                                  values: [
                                    for (final s in heart) s.bpm.toDouble(),
                                  ],
                                  color: colors.accent,
                                  height: null,
                                ))
                        : LayoutBuilder(
                            builder: (context, box) => BarChart(
                              values: week,
                              labels: [
                                for (var i = 0; i < 7; i++)
                                  weekdayShort[snapshot
                                          .dateAt(snapshot.dayCount - 7 + i)
                                          .weekday -
                                      1],
                              ],
                              selectedIndex: 6,
                              color: colors.accent.withValues(alpha: 0.24),
                              selectedColor: colors.accent,
                              goal: goal,
                              // A series that barely varies would otherwise
                              // show bars of the same height.
                              baseline:
                                  high > low &&
                                      (high - low) < high * 0.4 &&
                                      low > 0
                                  ? low - (high - low) * 0.6
                                  : 0,
                              height: box.maxHeight,
                            ),
                          ),
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

/// The hero moment: steps as a ring on a cookie shape, with the day's
/// distance and energy underneath where the store has them.
class _StepsHero extends StatelessWidget {
  const _StepsHero({required this.health, required this.stepGoal});

  final HealthController health;
  final int stepGoal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final emphasized = context.emphasizedTextTheme;
    final today = health.todayIndex;
    final steps = health.valueAt(Metric.steps, today);
    final distance = health.valueAt(Metric.distance, today);
    final energy = health.valueAt(Metric.totalEnergy, today);
    final valueStyle = emphasized.headlineLarge?.copyWith(
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                children: [
                  SizedBox.square(
                    dimension: 212,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        M3EShape(
                          Shapes.c12SidedCookie,
                          width: 212,
                          height: 212,
                          color: scheme.primary.withValues(alpha: 0.12),
                        ),
                        SizedBox.square(
                          dimension: 176,
                          child: ProgressRing(
                            value: (steps ?? 0) / stepGoal,
                            color: scheme.primary,
                            trackColor: scheme.primary.withValues(alpha: 0.16),
                            strokeWidth: 14,
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
                      if (distance != null)
                        _HeroStat(
                          value: Metric.distance.format(distance),
                          label: 'Kilometer',
                          shape: Shapes.pentagon,
                        ),
                      if (energy != null)
                        _HeroStat(
                          value: Metric.totalEnergy.format(energy),
                          label: 'Kalorien',
                          shape: Shapes.burst,
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
  });

  final String value;
  final String label;
  final Shapes shape;

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
              M3EShape(
                shape,
                width: 14,
                height: 14,
                color: theme.colorScheme.primary,
              ),
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
