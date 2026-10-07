import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../data/models.dart';
import '../../data/workout_insights.dart';
import '../../widgets/animated_count.dart';
import '../../widgets/number_grid.dart';
import '../../widgets/entrance.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/section_card.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/sub_page.dart';
import 'workout_format.dart';
import 'workout_scene.dart';
import 'workout_style.dart';

/// Everything the app can say about one workout: its numbers, how they stand
/// against earlier workouts of the kind, how often the user does it and what
/// to do next.
class WorkoutDetailPage extends StatelessWidget {
  const WorkoutDetailPage({super.key, required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    return ListenableBuilder(
      listenable: Listenable.merge([health, scope.settings]),
      builder: (context, _) {
        final formats = Formats.of(context);
        final l10n = formats.l10n;
        // The archive may hold a later reading of this workout, with the
        // heart rate added.
        final current = health.workouts.firstWhere(
          (other) => other.key == workout.key,
          orElse: () => workout,
        );
        final insights = WorkoutInsights.of(current, health.workouts);
        return SubPage(
          title: current.type.label(l10n),
          glass: scope.settings.liquidGlass,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              // Each section comes in a little after the one above it.
              for (final (index, section) in [
                _Summary(insights: insights),
                _Measures(insights: insights),
                _Comparison(insights: insights),
                if (insights.trend.length > 1) _Progress(insights: insights),
                _Frequency(insights: insights),
                _Tips(insights: insights),
              ].indexed)
                Entrance(order: index, child: section),
            ],
          ),
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.insights});

  final WorkoutInsights insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final workout = insights.workout;
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkoutScene(type: workout.type, height: 140),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formats.l10n.workoutAtTime(
                    formats.longDate(workout.start),
                    formatClock(workout.start.hour * 60 + workout.start.minute),
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  workoutHeadline(formats, insights),
                  style: context.emphasizedTextTheme.titleMedium?.copyWith(
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

/// Every number of the workout, two to a row.
class _Measures extends StatelessWidget {
  const _Measures({required this.insights});

  final WorkoutInsights insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    return NumberGrid(
      cellHeight: 104,
      cells: [
        for (final comparison in insights.measures)
          NumberCell(
            label: comparison.measure.label(l10n),
            value: AnimatedNumber(
              value: comparison.value,
              format: (value) => comparison.measure.format(
                formats,
                insights.workout.type,
                value,
              ),
            ),
            footer: !comparison.isBest
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.emoji_events_rounded,
                        size: 14,
                        color: scheme.tertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.personalBest,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.tertiary,
                        ),
                      ),
                    ],
                  ),
          ),
      ],
    );
  }
}

/// Each number against the workout before and against the usual one.
class _Comparison extends StatelessWidget {
  const _Comparison({required this.insights});

  final WorkoutInsights insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final rows = [
      for (final comparison in insights.measures)
        if (comparison.previous != null) comparison,
    ];
    if (rows.isEmpty) {
      return SectionCard(
        title: l10n.compareTitle,
        child: Text(l10n.compareFirst, style: muted),
      );
    }
    final averaged = insights.earlier.length < WorkoutInsights.averageOver
        ? insights.earlier.length
        : WorkoutInsights.averageOver;
    final head = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    Widget difference(
      MeasureComparison comparison,
      double? other,
      Trend trend,
    ) {
      if (other == null) return const SizedBox.shrink();
      final diff = comparison.value - other;
      final text = trend == Trend.same
          ? '±0'
          : '${diff < 0 ? '−' : '+'}'
                '${comparison.measure.formatDifference(formats, insights.workout.type, diff)}';
      return Text(
        text,
        textAlign: TextAlign.end,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.emphasizedTextTheme.labelLarge?.copyWith(
          color: switch (trend) {
            Trend.better => scheme.primary,
            Trend.worse => scheme.error,
            Trend.same || Trend.neutral => scheme.onSurfaceVariant,
          },
        ),
      );
    }

    return SectionCard(
      title: l10n.compareTitle,
      child: Column(
        spacing: 12,
        children: [
          Row(
            children: [
              const Expanded(flex: 5, child: SizedBox.shrink()),
              Expanded(
                flex: 4,
                child: Text(
                  l10n.compareLast,
                  textAlign: TextAlign.end,
                  style: head,
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  l10n.compareAverage(averaged),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: head,
                ),
              ),
            ],
          ),
          ...staggered([
            for (final comparison in rows)
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      comparison.measure.label(l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: difference(
                      comparison,
                      comparison.previous,
                      comparison.againstPrevious,
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: difference(
                      comparison,
                      comparison.average,
                      comparison.againstAverage,
                    ),
                  ),
                ],
              ),
          ], from: 1),
        ],
      ),
    );
  }
}

/// The last workouts of the kind as bars, this one marked.
class _Progress extends StatefulWidget {
  const _Progress({required this.insights});

  final WorkoutInsights insights;

  @override
  State<_Progress> createState() => _ProgressState();
}

class _ProgressState extends State<_Progress> {
  int _shown = 0;

  /// What a bar can stand for. Speed is in km/h for every kind, so that a
  /// taller bar is always the better one.
  static double? _value(Workout workout, WorkoutMeasure measure) {
    if (measure != WorkoutMeasure.speed) return measureOf(workout, measure);
    final km = workout.distanceKm;
    return km == null || km <= 0 || workout.minutes == 0
        ? null
        : km / workout.minutes * 60;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final trend = widget.insights.trend;
    final offered = [
      for (final measure in const [
        WorkoutMeasure.distance,
        WorkoutMeasure.speed,
        WorkoutMeasure.duration,
      ])
        if (_value(trend.last, measure) != null) measure,
    ];
    final measure = offered[_shown < offered.length ? _shown : 0];
    final value = _value(trend.last, measure)!;
    return SectionCard(
      title: l10n.trendTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (offered.length > 1) ...[
            M3EToggleButtonGroup(
              type: M3EButtonGroupType.connected,
              style: M3EButtonStyle.tonal,
              size: M3EButtonSize.sm,
              haptic: M3EHapticFeedback.light,
              selectedIndex: offered.indexOf(measure),
              onSelectedIndexChanged: (index) {
                if (index != null) setState(() => _shown = index);
              },
              actions: [
                for (final offer in offered)
                  M3EToggleButtonGroupAction(label: Text(offer.label(l10n))),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Text(
            l10n.trendLast(trend.length),
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          Text(
            measure.format(formats, trend.last.type, value),
            style: context.emphasizedTextTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          BarChart(
            // A new key lets the bars grow again for the new measure.
            key: ValueKey(measure),
            values: [for (final workout in trend) _value(workout, measure)],
            selectedIndex: trend.length - 1,
            color: scheme.secondaryContainer,
            selectedColor: scheme.primary,
            height: 140,
          ),
        ],
      ),
    );
  }
}

class _Frequency extends StatelessWidget {
  const _Frequency({required this.insights});

  final WorkoutInsights insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final before = insights.perWeekBefore;
    return SectionCard(
      title: l10n.frequencyTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(
            l10n.frequencyRecent(formats.decimal(insights.perWeekRecent)),
            style: theme.textTheme.bodyLarge,
          ),
          if (before != null)
            Text(
              l10n.frequencyBefore(formats.decimal(before)),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _Tips extends StatelessWidget {
  const _Tips({required this.insights});

  final WorkoutInsights insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = Formats.of(context).l10n;
    return SectionCard(
      title: l10n.tipsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          for (final tip in insights.tips)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 20,
                  color: scheme.tertiary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    workoutTip(l10n, tip),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          Text(
            l10n.tipsNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
