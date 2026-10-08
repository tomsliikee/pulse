import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../data/health_controller.dart';
import '../../data/models.dart';
import '../../data/workout_archive.dart';
import '../../data/workout_insights.dart';
import '../../theme/app_type.dart';
import '../../theme/page_accent.dart';
import '../../widgets/detail_sections.dart';
import '../../widgets/page_header.dart';
import '../../widgets/segment_group.dart';
import '../../widgets/shape_badge.dart';
import '../../widgets/animated_count.dart';
import '../../widgets/number_grid.dart';
import '../../widgets/entrance.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/section_card.dart';
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

  /// Takes the workout out of the app and leaves the page. The health store
  /// keeps it, so there is an undo that brings it back.
  Future<void> _remove(BuildContext context, HealthController health) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = Formats.of(context).l10n;
    final RemovedWorkout removed;
    try {
      removed = await health.removeWorkout(workout);
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.deleteFailed)));
      return;
    }
    Haptics.confirm();
    navigator.maybePop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.workoutRemoved),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () async {
              try {
                await health.restoreWorkout(removed);
              } on Exception {
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.restoreFailed)),
                );
              }
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    return PageAccent.activity(
      child: ListenableBuilder(
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
            action: IconButton(
              onPressed: () => _remove(context, health),
              tooltip: l10n.removeWorkout,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
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
      ),
    );
  }
}

/// The figure doing the workout in the one container of the page, the kind
/// of workout on its shape over the edge, and below it, free, how long it
/// was and how it went.
class _Summary extends StatelessWidget {
  const _Summary({required this.insights});

  final WorkoutInsights insights;

  @override
  Widget build(BuildContext context) {
    final formats = Formats.of(context);
    final type = AppType.of(context);
    final accent = PageAccent.colorsOf(context);
    final workout = insights.workout;
    return SceneSummary(
      scene: WorkoutScene(type: workout.type, height: SceneSummary.sceneHeight),
      mark: ShapeBadge(
        shape: workout.type.shape,
        icon: workout.type.icon,
        size: SceneSummary.markSize,
        color: accent.accent,
        iconColor: accent.onAccent,
      ),
      label: formats.l10n.workoutAtTime(
        formats.longDate(workout.start),
        formatClock(workout.start.hour * 60 + workout.start.minute),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formats.duration(workout.minutes),
            style: type.hero(context.emphasizedTextTheme.displaySmall),
          ),
          const SizedBox(height: 4),
          Text(
            workoutHeadline(formats, insights),
            style: type.strong(
              context.emphasizedTextTheme.titleMedium?.copyWith(
                color: accent.accent,
              ),
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
    return TitledSection(
      title: l10n.workoutNumbers,
      child: NumberGrid(
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
      ),
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
      return TitledSection(
        title: l10n.compareTitle,
        child: SegmentGroup(children: [Text(l10n.compareFirst, style: muted)]),
      );
    }
    final averaged = insights.earlier.length < WorkoutInsights.averageOver
        ? insights.earlier.length
        : WorkoutInsights.averageOver;

    Widget difference(
      MeasureComparison comparison,
      double? other,
      Trend trend,
    ) {
      if (other == null) return const SizedBox.shrink();
      final diff = comparison.value - other;
      return DifferenceText(
        text: trend == Trend.same
            ? '±0'
            : '${diff < 0 ? '−' : '+'}'
                  '${comparison.measure.formatDifference(formats, insights.workout.type, diff)}',
        good: switch (trend) {
          Trend.better => true,
          Trend.worse => false,
          Trend.same || Trend.neutral => null,
        },
      );
    }

    return ComparisonSegments(
      title: l10n.compareTitle,
      heads: [l10n.compareLast, l10n.compareAverage(averaged)],
      rows: [
        for (final comparison in rows)
          (
            label: comparison.measure.label(l10n),
            cells: [
              difference(
                comparison,
                comparison.previous,
                comparison.againstPrevious,
              ),
              difference(
                comparison,
                comparison.average,
                comparison.againstAverage,
              ),
            ],
          ),
      ],
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
            color: PageAccent.colorsOf(context).container,
            selectedColor: PageAccent.colorsOf(context).accent,
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
    final type = AppType.of(context);
    return TitledSection(
      title: l10n.frequencyTitle,
      child: SegmentGroup(
        children: [
          Text(
            l10n.frequencyRecent(formats.decimal(insights.perWeekRecent)),
            style: type.strong(theme.textTheme.titleMedium),
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
    final l10n = Formats.of(context).l10n;
    return NoteSegments(
      title: l10n.tipsTitle,
      icon: Icons.lightbulb_outline_rounded,
      sentences: [for (final tip in insights.tips) workoutTip(l10n, tip)],
      note: l10n.tipsNote,
    );
  }
}
