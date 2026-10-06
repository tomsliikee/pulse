import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../data/health_controller.dart';
import '../../data/metric_catalog.dart';
import '../../data/models.dart';
import '../../widgets/animated_count.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/board_page.dart';
import '../../widgets/shape_badge.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/tile_board.dart';
import '../detail/metric_spec.dart';
import '../detail/metric_tiles.dart';
import 'workout_style.dart';

/// Steps over the week or month and the list of workouts.
class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  static const int _maxWorkouts = 5;
  static const double _workoutRowHeight = 64;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    return ListenableBuilder(
      listenable: Listenable.merge([health, scope.settings]),
      builder: (context, _) {
        final snapshot = health.snapshot;
        final workouts = snapshot.workouts.reversed.take(_maxWorkouts).toList();
        return BoardPage(
          pageId: 'activity',
          title: 'Aktivität',
          subtitle: 'Schritte und Trainings',
          tiles: [
            BoardTile(
              id: 'chart',
              height: 420,
              child: _StepsChart(
                health: health,
                stepGoal: scope.settings.stepGoal,
              ),
            ),
            for (final metric in const [
              Metric.distance,
              Metric.floors,
              Metric.intensityMinutes,
            ])
              if (snapshot.has(metric))
                statTile(
                  context,
                  health,
                  metric,
                  span: TileSpan.third,
                  title: switch (metric) {
                    Metric.distance => 'Kilometer',
                    Metric.intensityMinutes => 'Aktive Min.',
                    _ => null,
                  },
                ),
            for (final metric in const [
              Metric.activeEnergy,
              Metric.totalEnergy,
            ])
              if (snapshot.has(metric)) statTile(context, health, metric),
            if (workouts.isNotEmpty)
              BoardTile(
                id: 'workouts',
                height: 76 + workouts.length * _workoutRowHeight,
                child: _Workouts(
                  workouts: workouts,
                  rowHeight: _workoutRowHeight,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StepsChart extends StatefulWidget {
  const _StepsChart({required this.health, required this.stepGoal});

  final HealthController health;
  final int stepGoal;

  @override
  State<_StepsChart> createState() => _StepsChartState();
}

class _StepsChartState extends State<_StepsChart> {
  bool _month = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final health = widget.health;
    final snapshot = health.snapshot;
    final start = _month ? 0 : health.weekStart;
    final range = snapshot.valuesOf(Metric.steps).sublist(start);
    final known = [for (final value in range) ?value];
    final selected = health.selectedIndex - start;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          M3EToggleButtonGroup(
            type: M3EButtonGroupType.connected,
            style: M3EButtonStyle.tonal,
            size: M3EButtonSize.sm,
            haptic: M3EHapticFeedback.light,
            selectedIndex: _month ? 1 : 0,
            onSelectedIndexChanged: (index) {
              if (index != null) setState(() => _month = index == 1);
            },
            actions: const [
              M3EToggleButtonGroupAction(label: Text('Woche')),
              M3EToggleButtonGroupAction(label: Text('Monat')),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Durchschnitt pro Tag',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (known.isEmpty)
                Text('–', style: context.emphasizedTextTheme.displaySmall)
              else
                AnimatedCount(
                  value: (known.reduce((a, b) => a + b) / known.length).round(),
                  style: context.emphasizedTextTheme.displaySmall,
                ),
              const SizedBox(width: 8),
              Text(
                'Schritte',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),
          BarChart(
            // A new key lets the bars grow again for the new range.
            key: ValueKey(_month),
            values: range,
            labels: _month
                ? null
                : [
                    for (var i = start; i < snapshot.dayCount; i++)
                      weekdayShort[snapshot.dateAt(i).weekday - 1],
                  ],
            selectedIndex: selected >= 0 ? selected : null,
            onSelected: (i) => health.selectDay(start + i),
            color: scheme.secondaryContainer,
            selectedColor: scheme.primary,
            goal: widget.stepGoal.toDouble(),
          ),
          const SizedBox(height: 16),
          Text(
            '${formatShortDate(health.selectedDate)}  ·  '
            '${Metric.steps.formatWithUnit(health.value(Metric.steps))}',
            style: context.emphasizedTextTheme.titleSmall?.copyWith(
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Workouts extends StatelessWidget {
  const _Workouts({required this.workouts, required this.rowHeight});

  final List<Workout> workouts;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trainings', style: context.emphasizedTextTheme.titleMedium),
          const SizedBox(height: 12),
          for (final workout in workouts)
            SizedBox(
              height: rowHeight,
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
                          workout.type.label,
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          '${formatShortDate(workout.start)} · '
                          '${formatDuration(workout.minutes)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (workout.kcal case final kcal?)
                    Text(
                      '$kcal kcal',
                      style: context.emphasizedTextTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
