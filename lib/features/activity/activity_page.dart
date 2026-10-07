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
import '../detail/page_tiles.dart';
import 'workout_style.dart';
import '../../l10n/generated/app_localizations.dart';

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
        final l10n = AppLocalizations.of(context);
        final snapshot = health.snapshot;
        final workouts = snapshot.workouts.reversed.take(_maxWorkouts).toList();
        return BoardPage(
          pageId: 'activity',
          title: l10n.groupActivity,
          subtitle: l10n.activitySubtitle,
          removable: true,
          tiles: [
            BoardTile(
              id: 'chart',
              title: l10n.stepsChartTitle,
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
                  settings: scope.settings,
                  page: 'activity',
                  title: switch (metric) {
                    Metric.distance => l10n.kilometers,
                    Metric.intensityMinutes => l10n.shortActiveMinutes,
                    _ => null,
                  },
                ),
            for (final metric in const [
              Metric.activeEnergy,
              Metric.totalEnergy,
            ])
              if (snapshot.has(metric))
                statTile(
                  context,
                  health,
                  metric,
                  settings: scope.settings,
                  page: 'activity',
                ),
            if (workouts.isNotEmpty)
              BoardTile(
                id: 'workouts',
                title: l10n.workouts,
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
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final health = widget.health;
    final snapshot = health.snapshot;
    final start = _month ? 0 : health.weekStart;
    final range = snapshot.valuesOf(Metric.steps).sublist(start);
    final known = [for (final value in range) ?value];
    final selected = health.selectedIndex - start;
    final average = known.isEmpty
        ? null
        : (known.reduce((a, b) => a + b) / known.length).round();

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
            actions: [
              M3EToggleButtonGroupAction(label: Text(l10n.periodWeek)),
              M3EToggleButtonGroupAction(label: Text(l10n.periodMonth)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.averagePerDay,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (average == null)
                Text('–', style: context.emphasizedTextTheme.displaySmall)
              else
                AnimatedCount(
                  value: average,
                  style: context.emphasizedTextTheme.displaySmall,
                ),
              const SizedBox(width: 8),
              Text(
                l10n.unitSteps(average ?? 0),
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
                      formats.weekdayShort[snapshot.dateAt(i).weekday - 1],
                  ],
            selectedIndex: selected >= 0 ? selected : null,
            onSelected: (i) => health.selectDay(start + i),
            color: scheme.secondaryContainer,
            selectedColor: scheme.primary,
            goal: widget.stepGoal.toDouble(),
          ),
          const SizedBox(height: 16),
          Text(
            '${formats.shortDate(health.selectedDate)}  ·  '
            '${Metric.steps.formatWithUnit(formats, health.value(Metric.steps))}',
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
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.workouts, style: context.emphasizedTextTheme.titleMedium),
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
                          workout.type.label(l10n),
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          '${formats.shortDate(workout.start)} · '
                          '${formats.duration(workout.minutes)}',
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
