import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../data/day_insights.dart';
import '../../data/health_controller.dart';
import '../../data/health_history.dart';
import '../../data/metric_catalog.dart';
import '../../data/recovery.dart';
import '../../data/settings_controller.dart';
import '../../data/workout_insights.dart' show Trend;
import '../../widgets/animated_count.dart';
import '../../widgets/number_grid.dart';
import '../../widgets/page_header.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_type.dart';
import '../../theme/page_accent.dart';
import '../../widgets/segment_group.dart';
import '../../widgets/shape_badge.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/day_switcher.dart';
import '../../widgets/entrance.dart';
import '../../widgets/floating_tab_bar.dart';
import '../../widgets/wavy_bar.dart';
import '../../widgets/sub_page.dart';
import '../activity/workout_tiles.dart';
import '../sleep/night_tiles.dart';
import 'day_format.dart';
import 'day_list_page.dart';
import 'day_scores.dart';
import 'day_tiles.dart';
import '../detail/metric_spec.dart';
import '../../l10n/generated/app_localizations.dart';

/// Everything the app can say about the day [date]: its score and what it
/// is made of, its numbers against the days before, the night and the
/// workouts that belong to it, and what to do next. The days before it are
/// listed at the end.
class DayDetailPage extends StatefulWidget {
  const DayDetailPage({super.key, required this.date});

  /// The day the page opens on; the bar at its bottom leads to others.
  final DateTime date;

  @override
  State<DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends State<DayDetailPage> {
  late DateTime _date = widget.date;

  DateTime get date => _date;

  void _show(DateTime day) {
    if (day == _date) return;
    setState(() => _date = day);
  }

  /// Days before this one that are listed at the end of the page.
  static const int _daysBelow = 3;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([health, scope.settings]),
      builder: (context, _) => PageAccent.day(
        child: SubPage(
          title: l10n.dayInDetail,
          glass: scope.settings.liquidGlass,
          // The page ends above the floating bar.
          bottomPadding:
              16 +
              FloatingTabBar.height +
              24 +
              MediaQuery.paddingOf(context).bottom,
          overlay: health.status != HealthStatus.ready
              ? null
              : Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16 + MediaQuery.paddingOf(context).bottom,
                  child: Center(
                    child: DaySwitcher(
                      today: health.today,
                      selected: _date,
                      earlier: _earlier(health),
                      allLabel: l10n.allDays,
                      glass: scope.settings.liquidGlass,
                      onSelected: _show,
                      onAll: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DayListPage(),
                        ),
                      ),
                    ),
                  ),
                ),
          child: health.status == HealthStatus.ready
              ? _content(context, health, scope.settings)
              : const SizedBox(
                  height: 240,
                  child: Center(child: M3ELoadingIndicator()),
                ),
        ),
      ),
    );
  }

  /// The days before yesterday that the menu of the bar offers.
  List<DateTime> _earlier(HealthController health) {
    final before = dayKey(health.today) - 1;
    return [
      for (final day in health.days.reversed)
        if (dayKey(day) < before) day,
    ].take(DaySwitcher.menuDays).toList();
  }

  Widget _content(
    BuildContext context,
    HealthController health,
    SettingsController settings,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final insights = dayInsightsOf(health, settings, date);
    final today = date == health.today;
    final dateLine = Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
      child: Text(
        formats.longDate(date),
        style: AppType.of(context).aside(
          theme.textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
    if (insights.measures.isEmpty && insights.workouts.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          dateLine,
          SurfaceCard(child: EmptyNote(l10n.noDayData)),
        ],
      );
    }

    final key = dayKey(date);
    final all = health.days;
    final before = [
      for (final day in all.reversed)
        if (dayKey(day) < key) day,
    ];
    final night = insights.night;

    final sections = <Widget>[
      _Summary(
        insights: insights,
        today: today,
        soFar: today ? stepsSoFar(health.snapshot, health.now) : null,
      ),
      RecoveryParts(recovery: insights.recovery),
      // The parts come with the score: in the evening, or once the day is over.
      if (showsDayScore(insights.day, health.now))
        _ScoreParts(score: insights.score),
      _Measures(insights: insights),
      // A day that is still running is not set against whole days.
      if (!today) _Comparison(insights: insights),
      if (night != null)
        TitledSection(
          title: l10n.dayNightTitle,
          child: SegmentGroup(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: NightsCard.rowHeight,
                child: NightRow(night: night),
              ),
            ],
          ),
        ),
      if (insights.workouts.isNotEmpty)
        TitledSection(
          title: l10n.dayWorkoutsTitle,
          child: SegmentGroup(
            padding: EdgeInsets.zero,
            children: [
              for (final workout in insights.workouts)
                SizedBox(
                  height: RecentWorkoutsCard.rowHeight,
                  child: WorkoutRow(workout: workout),
                ),
            ],
          ),
        ),
      _Tips(insights: insights, today: today),
      if (before.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: SizedBox(
            height: DaysCard.height,
            child: DaysCard(
              days: before.take(_daysBelow).toList(),
              total: all.length,
            ),
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        dateLine,
        for (var i = 0; i < sections.length; i++) ...[
          // Keyed by the day, so they come in again when it changes.
          Entrance(key: ValueKey((date, i)), order: i, child: sections[i]),
        ],
      ],
    );
  }
}

/// The day played back in the one container of the page, the score on a
/// shape that hangs over its edge, and below it, free, the steps and how
/// the day went.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.insights,
    required this.today,
    required this.soFar,
  });

  final DayInsights insights;
  final bool today;
  final StepsSoFar? soFar;

  static const double _scene = 160;
  static const double _shape = 116;
  static const double _overlap = 54;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final type = AppType.of(context);
    final steps = insights.measure(DayMeasure.steps);
    final health = AppScope.of(context).health;
    final scoreStyle = type.hero(
      context.emphasizedTextTheme.headlineLarge?.copyWith(height: 1),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: daySceneOf(health, insights, height: _scene),
            ),
            const SizedBox(height: _shape - _overlap + DayScores.captionHeight),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.dayStepsOnly(
                      Metric.steps.format(formats, steps?.value),
                    ),
                    style: type.hero(context.emphasizedTextTheme.displaySmall),
                  ),
                  if (insights.streak > 1)
                    Text(
                      l10n.streakDays(insights.streak),
                      style: type.label(
                        theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    dayHeadline(formats, insights, soFar: soFar),
                    style: type.strong(
                      context.emphasizedTextTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          top: _scene - _overlap,
          child: DayScores(
            insights: insights,
            withDay: showsDayScore(insights.day, health.now),
            size: _shape,
            style: scoreStyle,
          ),
        ),
      ],
    );
  }
}

/// What each part of the recovery read and gave, a segment for each.
class RecoveryParts extends StatelessWidget {
  const RecoveryParts({super.key, required this.recovery});

  final Recovery recovery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final type = AppType.of(context);
    final zone = recoveryColors(scheme, recovery.zone);
    final muted = theme.textTheme.labelLarge?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return TitledSection(
      title: l10n.recoveryParts,
      note: l10n.recoveryNote,
      child: SegmentGroup(
        children: [
          for (final part in RecoveryPart.values)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        part.metric?.title(l10n) ?? l10n.groupSleep,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.strong(theme.textTheme.titleSmall),
                      ),
                    ),
                    const SizedBox(width: 8),
                    switch ((recovery.parts[part], part.metric)) {
                      (final reading?, final metric?) => Text(
                        l10n.recoveryUsual(
                          metric.formatWithUnit(formats, reading.value),
                          metric.format(formats, reading.usual),
                        ),
                        style: type.label(muted),
                      ),
                      (final reading?, null) => Text(
                        l10n.recoveryAimed(
                          formats.duration(reading.value.round()),
                          formats.duration(reading.usual.round()),
                        ),
                        style: type.label(muted),
                      ),
                      (null, _) => Text(
                        l10n.scoreNotJudged,
                        style: type.aside(muted),
                      ),
                    },
                  ],
                ),
                // Nothing to draw for a part that was not judged.
                if (recovery.parts[part] case final reading?)
                  WavyBar(value: reading.share, color: zone.fill),
              ],
            ),
        ],
      ),
    );
  }
}

/// What each part of the score gave, a segment for each.
class _ScoreParts extends StatelessWidget {
  const _ScoreParts({required this.score});

  final DayScore score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final type = AppType.of(context);
    return TitledSection(
      title: l10n.dayScoreParts,
      note: l10n.dayScoreNote,
      child: SegmentGroup(
        children: [
          for (final part in DayScorePart.values)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        part.label(l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.strong(theme.textTheme.titleSmall),
                      ),
                    ),
                    switch (score.parts[part]) {
                      final earned? => Text(
                        l10n.scorePoints(earned.round(), part.points),
                        style: type.label(
                          theme.textTheme.labelLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      null => Text(
                        l10n.scoreNotJudged,
                        style: type.aside(
                          theme.textTheme.labelLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    },
                  ],
                ),
                // Nothing to draw for a part that was not judged.
                if (score.parts[part] case final earned?)
                  WavyBar(value: earned / part.points),
              ],
            ),
        ],
      ),
    );
  }
}

/// Every number of the day; a best is marked.
class _Measures extends StatelessWidget {
  const _Measures({required this.insights});

  final DayInsights insights;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    return TitledSection(
      title: l10n.dayNumbers,
      child: NumberGrid(
        cells: [
          for (final comparison in insights.measures)
            if (comparison.measure != DayMeasure.score)
              NumberCell(
                label: comparison.measure.label(l10n),
                value: AnimatedNumber(
                  value: comparison.value,
                  format: (value) =>
                      comparison.measure.formatAlone(formats, value),
                ),
                trailing: !comparison.isBest
                    ? null
                    : Icon(
                        Icons.emoji_events_rounded,
                        size: 18,
                        color: scheme.tertiary,
                        semanticLabel: l10n.dayBest,
                      ),
              ),
        ],
      ),
    );
  }
}

/// Each number against the day before and against the week before, a
/// segment for each.
class _Comparison extends StatelessWidget {
  const _Comparison({required this.insights});

  final DayInsights insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final type = AppType.of(context);
    final rows = [
      for (final comparison in insights.measures)
        if (comparison.previous != null || comparison.average != null)
          comparison,
    ];
    if (rows.isEmpty) {
      return TitledSection(
        title: l10n.compareTitle,
        child: SegmentGroup(
          children: [
            Text(
              l10n.compareNoDay,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    final head = type.label(
      theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
    );

    Widget difference(DayComparison comparison, double? other, Trend trend) {
      if (other == null) return const SizedBox.shrink();
      final diff = comparison.value - other;
      final size = comparison.measure.formatDifference(formats, diff);
      return Text(
        trend == Trend.same ? '±0' : '${diff < 0 ? '−' : '+'}$size',
        textAlign: TextAlign.end,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: type.figure(
          context.emphasizedTextTheme.labelLarge?.copyWith(
            color: switch (trend) {
              Trend.better => scheme.primary,
              Trend.worse => scheme.error,
              Trend.same || Trend.neutral => scheme.onSurfaceVariant,
            },
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(l10n.compareTitle),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              const Expanded(flex: 5, child: SizedBox.shrink()),
              for (final label in [l10n.compareDayBefore, l10n.compareWeek])
                Expanded(
                  flex: 4,
                  child: Text(
                    label,
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          children: [
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
          ],
        ),
      ],
    );
  }
}

class _Tips extends StatelessWidget {
  const _Tips({required this.insights, required this.today});

  final DayInsights insights;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    return TitledSection(
      title: today ? l10n.dayTipsTitle : l10n.dayTipsTitlePast,
      note: l10n.tipsNote,
      child: SegmentGroup(
        from: 1,
        padding: const EdgeInsets.all(16),
        children: [
          for (final tip in insights.tips)
            Row(
              children: [
                ShapeBadge(
                  shape: Shapes.softBurst,
                  icon: Icons.lightbulb_outline_rounded,
                  size: 40,
                  color: scheme.tertiaryContainer,
                  iconColor: scheme.onTertiaryContainer,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    dayTip(formats, tip),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
