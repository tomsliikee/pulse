import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../data/health_controller.dart';
import '../../data/metric_catalog.dart';
import '../../widgets/animated_count.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/board_page.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/tile_board.dart';
import '../detail/metric_spec.dart';
import '../detail/page_tiles.dart';
import 'workout_tiles.dart';
import '../../l10n/generated/app_localizations.dart';

/// The latest workout, the ones before it, steps over the week or month and
/// the measurements of the day.
class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  static const int _maxWorkouts = 5;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    return ListenableBuilder(
      listenable: Listenable.merge([health, scope.settings]),
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final snapshot = health.snapshot;
        final workouts = health.workouts;
        // The latest has a tile of its own; these are the ones before it.
        final earlier = workouts.reversed.skip(1).take(_maxWorkouts).toList();
        return BoardPage(
          pageId: 'activity',
          title: l10n.groupActivity,
          subtitle: l10n.activitySubtitle,
          removable: true,
          tiles: [
            if (workouts.isNotEmpty)
              BoardTile(
                id: 'lastWorkout',
                title: l10n.lastActivity,
                height: LatestWorkoutCard.height,
                entersInPlace: true,
                child: LatestWorkoutCard(workouts: workouts),
              ),
            if (workouts.length > 1)
              BoardTile(
                id: 'recentWorkouts',
                title: l10n.moreActivities,
                height: RecentWorkoutsCard.heightFor(earlier.length),
                entersInPlace: true,
                child: RecentWorkoutsCard(
                  workouts: earlier,
                  total: workouts.length,
                ),
              ),
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
