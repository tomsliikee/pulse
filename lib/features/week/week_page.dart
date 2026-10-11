import 'package:intl/intl.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/container_route.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../app/layout.dart';
import '../../data/goals.dart';
import '../../data/health_controller.dart';
import '../../data/health_history.dart';
import '../../data/metric_catalog.dart';
import '../../data/settings_controller.dart';
import '../../data/week_report.dart';
import '../../data/workout_insights.dart' show Trend;
import '../../theme/app_shapes.dart';
import '../../theme/app_type.dart';
import '../../theme/page_accent.dart';
import '../../widgets/animated_count.dart';
import '../../widgets/detail_sections.dart';
import '../../widgets/entrance.dart';
import '../../widgets/floating_surface.dart';
import '../../widgets/morphing_shape.dart';
import '../../widgets/page_header.dart';
import '../../widgets/segment_group.dart';
import '../../widgets/shape_badge.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/sub_page.dart';
import '../activity/workout_tiles.dart';
import '../detail/metric_spec.dart';
import '../goals/goal_format.dart';
import '../links/link_card.dart';
import '../links/link_format.dart';
import '../links/links_page.dart';
import '../sleep/night_tiles.dart';
import '../today/day_format.dart';
import '../today/day_tiles.dart';
import 'week_scene.dart';

/// Opens the weekly report: out of what was tapped at [origin], or from
/// below when a notification leads here. Without [monday] it shows the
/// latest week whose report is ready.
void openWeek(BuildContext context, {Rect? origin, DateTime? monday}) {
  Navigator.of(context).push(
    origin == null
        ? MaterialPageRoute<void>(builder: (_) => WeekPage(monday: monday))
        : ContainerRoute<void>(
            origin: origin,
            originColor: Theme.of(context).colorScheme.surfaceBright,
            builder: (_) => WeekPage(monday: monday),
          ),
  );
}

/// The report of the week that begins on [monday], as the app holds it.
WeekReport weekReportOf(
  HealthController health,
  SettingsController settings,
  DateTime monday,
) => weekReport(
  monday: monday,
  data: goalDataOf(health, settings),
  dayGoals: dayGoalsOf(settings),
  goals: {for (final goal in settings.goals) goal: settings.goalTarget(goal)},
  today: health.today,
  history: health.history,
);

/// A week from Monday to Sunday looked back on: its score over a scene of
/// the seven days, its numbers against the weeks before, the best of it,
/// the goals, the workouts, the sleep, and what goes together.
class WeekPage extends StatefulWidget {
  const WeekPage({super.key, this.monday});

  /// The week the page opens on; the bar at its bottom leads to others.
  final DateTime? monday;

  @override
  State<WeekPage> createState() => _WeekPageState();
}

class _WeekPageState extends State<WeekPage> {
  DateTime? _monday;

  /// Connections the report repeats.
  static const int _linksShown = 3;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    final settings = scope.settings;
    return ListenableBuilder(
      listenable: Listenable.merge([health, settings]),
      builder: (context, _) {
        final l10n = Formats.of(context).l10n;
        final ready = health.status == HealthStatus.ready;
        final monday = _monday ??=
            widget.monday ?? latestReportWeek(health.now);
        final current = weekStart(health.today);
        final first = !ready || health.days.isEmpty
            ? monday
            : weekStart(health.days.first);
        void page(int weeks) {
          Haptics.selection();
          setState(
            () => _monday = DateTime(
              monday.year,
              monday.month,
              monday.day + 7 * weeks,
            ),
          );
        }

        return PageAccent.day(
          child: SubPage(
            title: l10n.weekTitle,
            glass: settings.liquidGlass,
            // The page ends above the floating bar.
            bottomPadding:
                16 +
                FloatingSurface.height +
                24 +
                MediaQuery.paddingOf(context).bottom,
            overlay: !ready
                ? null
                : Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16 + MediaQuery.paddingOf(context).bottom,
                    child: Center(
                      child: _WeekSwitcher(
                        monday: monday,
                        glass: settings.liquidGlass,
                        onOlder: dayKey(monday) > dayKey(first)
                            ? () => page(-1)
                            : null,
                        onNewer: dayKey(monday) < dayKey(current)
                            ? () => page(1)
                            : null,
                      ),
                    ),
                  ),
            child: ready
                ? _content(context, health, settings, monday)
                : const SizedBox(
                    height: 240,
                    child: Center(child: M3ELoadingIndicator()),
                  ),
          ),
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    HealthController health,
    SettingsController settings,
    DateTime monday,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final report = weekReportOf(health, settings, monday);
    final dateLine = Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
      child: Text(
        formats.dayRange(report.monday, report.sunday),
        style: AppType.of(context).aside(
          theme.textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
    if (report.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          dateLine,
          SurfaceCard(child: EmptyNote(l10n.weekEmpty)),
        ],
      );
    }
    final links = linksOf(health, settings).take(_linksShown).toList();
    final sections = <Widget>[
      _Summary(report: report),
      if (report.measures.isNotEmpty) _Comparison(report: report),
      _Best(report: report),
      if (report.goals.isNotEmpty) _Goals(report: report),
      _Workouts(report: report),
      if (report.nights.isNotEmpty) _Sleep(report: report),
      if (links.isNotEmpty)
        TitledSection(
          title: l10n.linksTitle,
          child: SegmentGroup(
            children: [for (final link in links) LinkCard(link: link)],
          ),
        ),
      OpenRow(
        icon: Icons.link_rounded,
        title: l10n.linksAll,
        onTap: (origin) => openLinks(context, origin),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        dateLine,
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          // Keyed by the week, so they come in again when it changes.
          Entrance(key: ValueKey((monday, i)), order: i, child: sections[i]),
        ],
      ],
    );
  }
}

String _weekday(Formats formats, DateTime day) => toBeginningOfSentenceCase(
  DateFormat.EEEE(formats.l10n.localeName).format(day),
);

/// The bar at the foot of the page: the week it shows between a way back
/// and a way on.
class _WeekSwitcher extends StatelessWidget {
  const _WeekSwitcher({
    required this.monday,
    required this.glass,
    required this.onOlder,
    required this.onNewer,
  });

  final DateTime monday;
  final bool glass;
  final VoidCallback? onOlder;
  final VoidCallback? onNewer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    return FloatingSurface(
      glass: glass,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.weekOlder,
            onPressed: onOlder,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              formats.dayRange(
                monday,
                DateTime(monday.year, monday.month, monday.day + 6),
              ),
              style: AppType.of(context).strong(theme.textTheme.labelLarge),
            ),
          ),
          IconButton(
            tooltip: l10n.weekNewer,
            onPressed: onNewer,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

/// The seven days as hills in the one container of the page, the week's
/// score on a shape that hangs over its edge, and below it, free, how the
/// week stands against the one before.
class _Summary extends StatelessWidget {
  const _Summary({required this.report});

  final WeekReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final type = AppType.of(context);
    final accent = PageAccent.colorsOf(context);
    final score = report.score;
    final previous = report.previousScore;
    final style = type.hero(
      context.emphasizedTextTheme.displaySmall?.copyWith(
        color: accent.onAccent,
        height: 1,
      ),
    );
    final steps = report.measure(WeekMeasure.steps);
    return SceneSummary(
      scene: WeekScene(
        scores: report.dayScores,
        best: report.bestDay,
        letters: formats.weekdayShort,
        height: SceneSummary.sceneHeight,
      ),
      mark: MorphingShape(
        shape: AppShapes.of(PageAccent.of(context).family, score),
        color: accent.accent,
        size: SceneSummary.markSize,
        child: score == null
            ? Text('–', style: style)
            : AnimatedCount(value: score, style: style),
      ),
      label: l10n.weekScore,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (steps != null) ...[
            Text(
              l10n.dayStepsOnly(formats.integer(steps.value.round())),
              style: type.hero(context.emphasizedTextTheme.displaySmall),
            ),
            Text(
              l10n.weekSteps,
              style: type.label(
                theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (score != null && previous != null)
            Text(
              score == previous
                  ? l10n.weekSameAsLast
                  : '${l10n.weekScore}: ${l10n.weekAgainstLast((score - previous).abs(), score > previous ? 'more' : 'less')}',
              style: type.strong(
                context.emphasizedTextTheme.titleMedium?.copyWith(
                  color: accent.accent,
                ),
              ),
            ),
          if (report.running)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.weekRunning,
                style: type.aside(
                  theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

extension on WeekMeasure {
  String label(Formats formats) => switch (this) {
    WeekMeasure.steps => formats.l10n.weekSteps,
    WeekMeasure.activeEnergy => formats.l10n.weekEnergy,
    WeekMeasure.asleep => formats.l10n.weekAsleep,
    WeekMeasure.sleepScore => formats.l10n.scoreTitle,
    WeekMeasure.recovery => formats.l10n.recovery,
    WeekMeasure.restingPulse => Metric.restingHeartRate.title(formats.l10n),
  };

  /// A value or the size of a difference.
  String format(Formats formats, double value) => switch (this) {
    WeekMeasure.asleep => formats.duration(value.round()),
    WeekMeasure.restingPulse => Metric.restingHeartRate.formatWithUnit(
      formats,
      value,
    ),
    _ => formats.integer(value.round()),
  };
}

/// Each number of the week with how it differs from the week before and
/// from what the four weeks before it made usual.
class _Comparison extends StatelessWidget {
  const _Comparison({required this.report});

  final WeekReport report;

  static const double _cell = 78;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final type = AppType.of(context);
    final head = type.label(
      theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
    );

    Widget difference(WeekComparison comparison, double? other, Trend trend) {
      if (other == null) return const SizedBox.shrink();
      final diff = comparison.value - other;
      return DifferenceText(
        text: trend == Trend.same
            ? '±0'
            : '${diff < 0 ? '−' : '+'}'
                  '${comparison.measure.format(formats, diff.abs())}',
        good: switch (trend) {
          Trend.better => true,
          Trend.worse => false,
          Trend.same || Trend.neutral => null,
        },
      );
    }

    return TitledSection(
      title: l10n.weekCompareTitle,
      note: l10n.weekScoreNote,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                const Spacer(),
                for (final text in [l10n.weekHeadLast, l10n.weekHeadUsual])
                  SizedBox(
                    width: _cell,
                    child: Text(
                      text,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: head,
                    ),
                  ),
              ],
            ),
          ),
          SegmentGroup(
            from: 1,
            children: [
              for (final comparison in report.measures)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comparison.measure.label(formats),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: head,
                          ),
                          Text(
                            comparison.measure.format(
                              formats,
                              comparison.value,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: type.figure(
                              context.emphasizedTextTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: _cell,
                      child: difference(
                        comparison,
                        comparison.previous,
                        comparison.againstPrevious,
                      ),
                    ),
                    SizedBox(
                      width: _cell,
                      child: difference(
                        comparison,
                        comparison.usual,
                        comparison.againstUsual,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A row that says one thing about the week and opens what it is about.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final void Function(Rect origin)? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = PageAccent.colorsOf(context);
    final onTap = this.onTap;
    return Material(
      type: MaterialType.transparency,
      child: Builder(
        builder: (context) => InkWell(
          onTap: onTap == null
              ? null
              : () {
                  final origin = globalRectOf(context);
                  if (origin != null) onTap(origin);
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                ShapeBadge(
                  shape: Shapes.softBurst,
                  icon: icon,
                  size: 40,
                  color: accent.container,
                  iconColor: accent.onContainer,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.of(context)
                            .strong(theme.textTheme.titleSmall),
                      ),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The best day, the best night and the days that were the highest ever.
class _Best extends StatelessWidget {
  const _Best({required this.report});

  final WeekReport report;

  @override
  Widget build(BuildContext context) {
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final bestDay = report.bestDay;
    final night = report.bestNight;
    DateTime day(int index) => DateTime(
      report.monday.year,
      report.monday.month,
      report.monday.day + index,
    );
    final rows = [
      if (bestDay != null)
        _Row(
          icon: Icons.emoji_events_rounded,
          title: l10n.weekBestDay,
          value:
              '${_weekday(formats, day(bestDay))} · ${l10n.dayScore} '
              '${report.dayScores[bestDay]}',
          onTap: (origin) => openDay(context, day(bestDay), origin),
        ),
      if (night != null)
        _Row(
          icon: Icons.bedtime_rounded,
          title: l10n.weekBestNight,
          value:
              '${_weekday(formats, night.date)} · ${l10n.scoreTitle} '
              '${report.bestNightScore}',
          onTap: (origin) => openNight(context, night, origin),
        ),
      for (final record in report.records)
        _Row(
          icon: Icons.star_rounded,
          title: '${l10n.personalBest} · ${record.measure.metric!.title(l10n)}',
          value:
              '${_weekday(formats, record.day)} · '
              '${record.measure.metric!.formatWithUnit(formats, record.value)}',
          onTap: (origin) => openDay(context, record.day, origin),
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return TitledSection(
      title: l10n.weekBestTitle,
      child: SegmentGroup(padding: EdgeInsets.zero, children: rows),
    );
  }
}

/// Each goal with a dot for every day of the week.
class _Goals extends StatelessWidget {
  const _Goals({required this.report});

  final WeekReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final type = AppType.of(context);
    final accent = PageAccent.colorsOf(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    String status(WeekGoal goal) {
      final row = goal.row;
      if (!row.goal.weekly) {
        return l10n.weekGoalDays(row.reached, row.marks.length);
      }
      return switch (row.marks.firstOrNull) {
        GoalMark.reached => l10n.weekGoalReached,
        GoalMark.missed => l10n.weekGoalMissed,
        _ => l10n.weekGoalOpen,
      };
    }

    Widget dot(GoalMark mark) {
      const size = 12.0;
      final (fill, border) = switch (mark) {
        GoalMark.reached => (accent.accent, accent.accent),
        GoalMark.missed => (Colors.transparent, scheme.outline),
        GoalMark.open => (Colors.transparent, accent.accent),
        GoalMark.none ||
        GoalMark.ahead => (scheme.surfaceContainerHighest, Colors.transparent),
      };
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: border, width: 1.5),
        ),
      );
    }

    return TitledSection(
      title: l10n.goals,
      child: SegmentGroup(
        children: [
          for (final goal in report.goals)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.row.goal.label(l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.strong(theme.textTheme.titleSmall),
                      ),
                      Text(
                        [
                          status(goal),
                          if (goal.streak > 1 && !goal.row.goal.weekly)
                            l10n.streakDays(goal.streak),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [for (final mark in goal.row.marks) dot(mark)],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The workouts of the week under their sum.
class _Workouts extends StatelessWidget {
  const _Workouts({required this.report});

  final WeekReport report;

  @override
  Widget build(BuildContext context) {
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final workouts = report.workouts;
    if (workouts.isEmpty) {
      return TitledSection(
        title: l10n.weekWorkoutsTitle,
        child: SurfaceCard(child: EmptyNote(l10n.weekNoWorkouts)),
      );
    }
    final energy = report.workoutEnergy;
    return TitledSection(
      title: l10n.weekWorkoutsTitle,
      note: [
        l10n.activitiesCount(workouts.length),
        formats.duration(report.workoutMinutes),
        if (energy > 0) '${formats.integer(energy)} kcal',
      ].join(' · '),
      child: SegmentGroup(
        padding: EdgeInsets.zero,
        children: [
          for (final workout in workouts)
            SizedBox(
              height: RecentWorkoutsCard.rowHeight,
              child: WorkoutRow(workout: workout),
            ),
        ],
      ),
    );
  }
}

/// How much sleep the week left owing and how regular its nights were.
class _Sleep extends StatelessWidget {
  const _Sleep({required this.report});

  final WeekReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final type = AppType.of(context);
    final regularity = report.regularity;
    final rows = [
      (l10n.sleepDebt, formats.duration(report.debt.minutes)),
      if (regularity != null) ...[
        (
          l10n.weekBedtime,
          l10n.weekSpread(
            formatClock(regularity.bedtimeMinute),
            regularity.bedtimeSpread,
          ),
        ),
        (
          l10n.weekWake,
          l10n.weekSpread(
            formatClock(regularity.wakeMinute),
            regularity.wakeSpread,
          ),
        ),
      ],
    ];
    return TitledSection(
      title: l10n.weekSleepTitle,
      note: l10n.nightsCount(report.nights.length),
      child: SegmentGroup(
        children: [
          for (final (label, value) in rows)
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  value,
                  style: type.figure(context.emphasizedTextTheme.titleSmall),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
