import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/layout.dart';
import '../../data/health_controller.dart';
import '../../data/health_history.dart';
import '../../data/metric_catalog.dart';
import '../../data/models.dart';
import '../../data/night_insights.dart';
import '../../data/settings_controller.dart';
import '../../data/sleep_insights.dart';
import '../../data/workout_insights.dart' show Trend;
import '../../theme/app_shapes.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_type.dart';
import '../../theme/page_accent.dart';
import '../../widgets/detail_sections.dart';
import '../../widgets/morphing_shape.dart';
import '../../widgets/segment_group.dart';
import '../../widgets/animated_count.dart';
import '../../widgets/number_grid.dart';
import '../../widgets/day_switcher.dart';
import '../../widgets/entrance.dart';
import '../../widgets/floating_tab_bar.dart';
import '../../widgets/wavy_bar.dart';
import '../../widgets/sub_page.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/line_chart.dart';
import '../../widgets/page_header.dart';
import '../../widgets/section_card.dart';
import '../../widgets/stat_tile.dart';
import '../detail/metric_spec.dart';
import 'night_format.dart';
import 'night_list_page.dart';
import 'night_tiles.dart';
import 'sleep_scene.dart';
import 'sleep_schedule_chart.dart';
import 'sleep_stages_chart.dart';
import '../../l10n/generated/app_localizations.dart';

/// How many nights the sleep debt looks back over.
const int _debtNights = 7;

/// Values a wearable takes during sleep, shown beside the night if the
/// snapshot has them.
const List<Metric> _nightMetrics = [
  Metric.restingHeartRate,
  Metric.heartRateVariability,
  Metric.respiratoryRate,
  Metric.oxygenSaturation,
  Metric.skinTemperature,
];

/// Everything the app can say about the night that ended on [date]: its
/// score and what it is made of, its stages, how it stands against the
/// nights before, how regular the nights are, and what to do next. The
/// nights before it are listed at the end.
class SleepDetailPage extends StatefulWidget {
  const SleepDetailPage({super.key, required this.date});

  /// The day the page opens on; the bar at its bottom leads to others.
  final DateTime date;

  @override
  State<SleepDetailPage> createState() => _SleepDetailPageState();
}

class _SleepDetailPageState extends State<SleepDetailPage> {
  late DateTime _date = widget.date;

  DateTime get date => _date;

  void _show(DateTime day) {
    if (day == _date) return;
    setState(() => _date = day);
  }

  /// Nights before this one that are listed at the end of the page.
  static const int _nightsBelow = 3;

  /// Days up to the night that its regularity is drawn over.
  static const int _scheduleDays = 30;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    final l10n = AppLocalizations.of(context);
    return PageAccent.sleep(
      child: ListenableBuilder(
        listenable: Listenable.merge([health, scope.settings]),
        builder: (context, _) => SubPage(
          title: l10n.sleepInDetail,
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
                      allLabel: l10n.allNights,
                      glass: scope.settings.liquidGlass,
                      onSelected: _show,
                      onAll: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const NightListPage(),
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
      for (final day in [
        for (final night in health.nights.reversed) night.date,
      ])
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
    final goalHours = settings.sleepGoalHours;
    final snapshot = health.snapshot;
    final all = health.nights;
    final key = dayKey(date);
    SleepNight? stored;
    for (final night in all) {
      if (dayKey(night.date) == key) stored = night;
    }
    final dateLine = Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
      child: Text(
        l10n.nightTo(formats.longDate(date)),
        style: theme.textTheme.titleMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
    if (stored == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          dateLine,
          SurfaceCard(child: EmptyNote(l10n.noSleepData)),
        ],
      );
    }

    // With the curve of its stages while the snapshot still has it.
    final night = health.withCurve(stored);
    final insights = NightInsights.of(stored, all, goalHours);
    // The days up to this night, one entry a day, for the charts that show
    // the nights around it.
    final byDay = {for (final other in all) dayKey(other.date): other};
    final days = [
      for (var day = key - _scheduleDays + 1; day <= key; day++) byDay[day],
    ];
    final week = days.sublist(days.length - _debtNights);
    final regularity = sleepRegularity(days);
    // The pulse and the day's values only as far as the snapshot reaches.
    final index = snapshot.indexOf(date);
    final heart = index == null
        ? const <HeartSample>[]
        : nightHeart(snapshot, index);
    final metrics = [
      for (final metric in _nightMetrics)
        if (snapshot.has(metric)) metric,
    ];
    final history = health.history;
    final links = sleepLinks(
      nights: all,
      until: date,
      workouts: health.workouts,
      stepsOn: (day) => history?.value(Metric.steps, day),
      stepGoal: settings.stepGoal,
    );
    final before = nightsBefore(all, date, all.length + 1);
    final stageColors = {
      SleepStage.awake: scheme.outlineVariant,
      SleepStage.rem: scheme.tertiary,
      SleepStage.light: scheme.secondary,
      SleepStage.deep: scheme.primary,
    };

    final sections = <Widget>[
      _Summary(night: night, insights: insights),
      _ScoreCard(score: insights.score),
      _Measures(night: night, insights: insights),
      if (night.hasCurve)
        SectionCard(
          title: l10n.sleepStages,
          child: SleepStagesChart(
            night: night,
            colors: stageColors,
            height: 160,
            interactive: true,
          ),
        ),
      if (night.hasStages)
        SectionCard(
          title: l10n.stagesCompared,
          child: _StageComparison(night: night, colors: stageColors),
        )
      else
        SectionCard(
          title: l10n.sleepStages,
          child: EmptyNote(l10n.noStagesRecorded),
        ),
      _Comparison(insights: insights),
      if (regularity != null)
        SectionCard(
          title: l10n.regularity,
          trailing: l10n.nightsCount(regularity.nights),
          child: _Regularity(
            nights: days,
            selectedIndex: days.length - 1,
            regularity: regularity,
          ),
        ),
      SectionCard(
        title: l10n.sleepDebt,
        child: _Debt(nights: week, until: date, goalHours: goalHours),
      ),
      if (heart.length >= 2)
        SectionCard(
          title: l10n.nightPulse,
          trailing: _heartSummary(l10n, heart),
          child: Column(
            children: [
              LineChart(
                values: [for (final sample in heart) sample.bpm.toDouble()],
                color: PageAccent.colorsOf(context).accent,
                height: 140,
              ),
              const SizedBox(height: 8),
              _ClockRow(
                minutes: [heart.first.minuteOfDay, heart.last.minuteOfDay],
              ),
            ],
          ),
        ),
      if (metrics.isNotEmpty)
        TitledSection(
          title: l10n.nightValues,
          note: l10n.nightValuesNote,
          child: SegmentGroup(
            padding: EdgeInsets.zero,
            children: [
              for (final metric in metrics)
                _NightValue(
                  metric: metric,
                  value: index == null
                      ? history?.value(metric, date)
                      : snapshot.value(metric, index),
                  usual: ownRange(snapshot.valuesOf(metric)),
                ),
            ],
          ),
        ),
      if (links.isNotEmpty) _Links(links: links),
      _Tips(insights: insights),
      if (before.isNotEmpty)
        NightsCard(
          title: l10n.nightsBeforeTitle,
          nights: before.reversed.take(_nightsBelow).toList(),
          total: all.length,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        dateLine,
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          // Keyed by the day, so they come in again when it changes.
          Entrance(key: ValueKey((date, i)), order: i, child: sections[i]),
        ],
      ],
    );
  }

  String _heartSummary(AppLocalizations l10n, List<HeartSample> samples) {
    var low = samples.first.bpm;
    var sum = 0;
    for (final sample in samples) {
      if (sample.bpm < low) low = sample.bpm;
      sum += sample.bpm;
    }
    return l10n.heartSummary(low, (sum / samples.length).round());
  }
}

/// The night played back in the one container of the page, the score on a
/// shape that hangs over its edge, and below it, free, how long it was and
/// how it went against the night before.
class _Summary extends StatelessWidget {
  const _Summary({required this.night, required this.insights});

  final SleepNight night;
  final NightInsights insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final type = AppType.of(context);
    final accent = PageAccent.colorsOf(context);
    final score = insights.score.total;
    return SceneSummary(
      scene: SleepScene(
        night: night,
        score: score,
        height: SceneSummary.sceneHeight,
      ),
      mark: MorphingShape(
        shape: AppShapes.of(PageAccent.of(context).family, score),
        color: accent.accent,
        size: SceneSummary.markSize,
        child: AnimatedCount(
          value: score,
          style: type.hero(
            context.emphasizedTextTheme.displaySmall?.copyWith(
              color: accent.onAccent,
              height: 1,
            ),
          ),
        ),
      ),
      label: formats.l10n.scoreTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formats.duration(night.asleepMinutes),
            style: type.hero(context.emphasizedTextTheme.displaySmall),
          ),
          Text(
            formats.l10n.asleepFromTo(
              formatClock(night.bedtimeMinute),
              formatClock(night.wakeMinute),
            ),
            style: type.label(
              theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            nightHeadline(formats, insights),
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

/// What each part of the score gave, a segment for each.
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score});

  final SleepScore score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final type = AppType.of(context);
    final accent = PageAccent.colorsOf(context);
    return TitledSection(
      title: l10n.dayScoreParts,
      note: l10n.scoreNote,
      child: SegmentGroup(
        children: [
          for (final part in ScorePart.values)
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
                  WavyBar(value: earned / part.points, color: accent.accent),
              ],
            ),
        ],
      ),
    );
  }
}

/// Every number of the night.
class _Measures extends StatelessWidget {
  const _Measures({required this.night, required this.insights});

  final SleepNight night;
  final NightInsights insights;

  @override
  Widget build(BuildContext context) {
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    return TitledSection(
      title: l10n.nightNumbers,
      child: NumberGrid(
        cells: [
          NumberCell(
            label: l10n.inBed,
            value: AnimatedNumber(
              value: night.totalMinutes.toDouble(),
              format: (value) => formats.duration(value.round()),
            ),
          ),
          for (final measure in const [
            NightMeasure.efficiency,
            NightMeasure.deep,
            NightMeasure.rem,
            NightMeasure.light,
            NightMeasure.awake,
          ])
            if (insights.measure(measure) case final comparison?)
              NumberCell(
                label: measure.label(l10n),
                value: AnimatedNumber(
                  value: comparison.value,
                  format: (value) => measure.format(formats, value),
                ),
              ),
        ],
      ),
    );
  }
}

/// Each number against the night before and against the week before, a
/// segment for each.
class _Comparison extends StatelessWidget {
  const _Comparison({required this.insights});

  final NightInsights insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final rows = [
      for (final comparison in insights.measures)
        if (comparison.previous != null) comparison,
    ];
    if (rows.isEmpty) {
      return TitledSection(
        title: l10n.compareTitle,
        child: SegmentGroup(
          children: [
            Text(
              l10n.compareNoNight,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    Widget difference(NightComparison comparison, double? other, Trend trend) {
      if (other == null) return const SizedBox.shrink();
      final diff = comparison.value - other;
      final size = comparison.measure.formatDifference(formats, diff);
      return DifferenceText(
        text: trend == Trend.same || diff.abs() < 0.005
            ? '±0'
            : '${diff < 0 ? '−' : '+'}$size',
        good: switch (trend) {
          Trend.better => true,
          Trend.worse => false,
          Trend.same || Trend.neutral => null,
        },
      );
    }

    return ComparisonSegments(
      title: l10n.compareTitle,
      heads: [l10n.compareNightBefore, l10n.compareWeek],
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

class _Links extends StatelessWidget {
  const _Links({required this.links});

  final List<SleepLink> links;

  @override
  Widget build(BuildContext context) {
    final formats = Formats.of(context);
    return NoteSegments(
      title: formats.l10n.linksTitle,
      icon: Icons.link_rounded,
      shape: Shapes.l4LeafClover,
      sentences: [for (final link in links) sleepLinkText(formats, link)],
      note: formats.l10n.linksNote,
    );
  }
}

class _Tips extends StatelessWidget {
  const _Tips({required this.insights});

  final NightInsights insights;

  @override
  Widget build(BuildContext context) {
    final formats = Formats.of(context);
    return NoteSegments(
      title: formats.l10n.sleepTipsTitle,
      icon: Icons.lightbulb_outline_rounded,
      sentences: [for (final tip in insights.tips) nightTip(formats, tip)],
      note: formats.l10n.tipsNote,
    );
  }
}

/// Two clock times at the ends of a chart.
class _ClockRow extends StatelessWidget {
  const _ClockRow({required this.minutes});

  final List<int> minutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final minute in minutes)
          Text(
            formatClock(minute),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// A number with what it is, for a row of several.
class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: context.emphasizedTextTheme.titleMedium?.copyWith(
              color: color,
            ),
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: color.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}

/// Each stage with its duration, its share and the share that is typical.
class _StageComparison extends StatelessWidget {
  const _StageComparison({required this.night, required this.colors});

  final SleepNight night;
  final Map<SleepStage, Color> colors;

  static List<(SleepStage, String)> _stages(AppLocalizations l10n) => [
    (SleepStage.deep, l10n.stageDeep),
    (SleepStage.rem, l10n.stageRem),
    (SleepStage.light, l10n.stageLight),
    (SleepStage.awake, l10n.stageAwake),
  ];

  /// The share at the right end of every bar, so the stages compare.
  static const _scale = 0.75;

  static int _percent(double share) => (share * 100).round();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final quiet = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (stage, label) in _stages(l10n)) ...[
          if (stage != SleepStage.deep) const SizedBox(height: 16),
          ..._rows(context, stage, label, quiet),
        ],
        const SizedBox(height: 16),
        Text(
          l10n.stageGuideNote,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  List<Widget> _rows(
    BuildContext context,
    SleepStage stage,
    String label,
    TextStyle? quiet,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final share = stageShare(night, stage) ?? 0;
    final range = typicalStageShare[stage]!;
    final span = range.$1 == 0
        ? l10n.percentUpTo(_percent(range.$2))
        : l10n.percentRange(_percent(range.$1), _percent(range.$2));
    // The awake lane's pale tone would vanish as a thin line.
    final color = stage == SleepStage.awake
        ? scheme.outline
        : colors[stage] ?? scheme.primary;
    final verdict = switch (verdictOf(share, range)) {
      RangeVerdict.below => l10n.belowGuide(span),
      RangeVerdict.within => l10n.withinGuide(span),
      RangeVerdict.above => l10n.aboveGuide(span),
    };
    return [
      Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
          Text(
            '${formats.duration(night.minutesIn(stage))} · '
            '${l10n.percentValue(_percent(share))}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      M3ELinearWavyProgressIndicator(
        value: (share / _scale).clamp(0, 1).toDouble(),
        color: color,
        backgroundColor: color.withValues(alpha: 0.2),
      ),
      const SizedBox(height: 6),
      Text(verdict, style: quiet),
    ];
  }
}

class _Regularity extends StatelessWidget {
  const _Regularity({
    required this.nights,
    required this.selectedIndex,
    required this.regularity,
  });

  final List<SleepNight?> nights;
  final int selectedIndex;
  final SleepRegularity regularity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final label = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final span = SleepScheduleChart.span(nights);
    const height = 168.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (span != null)
              SizedBox(
                height: height,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatClock(span.$1), style: label),
                    Text(formatClock(span.$2), style: label),
                  ],
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: SleepScheduleChart(
                nights: nights,
                selectedIndex: selectedIndex,
                color: scheme.secondaryContainer,
                selectedColor: scheme.secondary,
                height: height,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Figure(
                label: l10n.avgBedtime,
                value:
                    '${formatClock(regularity.bedtimeMinute)} '
                    '± ${regularity.bedtimeSpread} min',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Figure(
                label: l10n.avgWake,
                value:
                    '${formatClock(regularity.wakeMinute)} '
                    '± ${regularity.wakeSpread} min',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The [nights] of the days up to [until] against the goal, and what they
/// add up to.
class _Debt extends StatelessWidget {
  const _Debt({
    required this.nights,
    required this.until,
    required this.goalHours,
  });

  /// One entry a day, the last for [until]; null where there is no night.
  final List<SleepNight?> nights;
  final DateTime until;
  final double goalHours;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final debt = sleepDebt(nights, goalHours);
    final goal = '${formats.decimal(goalHours)} h';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          debt.minutes == 0
              ? l10n.goalReached
              : l10n.underGoal(formats.duration(debt.minutes)),
          style: context.emphasizedTextTheme.headlineSmall,
        ),
        Text(
          l10n.debtNights(debt.nights, goal),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        BarChart(
          values: [
            for (final night in nights)
              night == null ? null : night.asleepMinutes / 60,
          ],
          labels: [
            for (var back = nights.length - 1; back >= 0; back--)
              formats.weekdayShort[DateTime(
                    until.year,
                    until.month,
                    until.day - back,
                  ).weekday -
                  1],
          ],
          selectedIndex: nights.length - 1,
          color: scheme.secondaryContainer,
          selectedColor: scheme.secondary,
          goal: goalHours,
          height: 150,
        ),
      ],
    );
  }
}

/// One measurement of the day the night ends on, against what is usual for
/// this person. Opens the measurement's own page.
class _NightValue extends StatelessWidget {
  const _NightValue({
    required this.metric,
    required this.value,
    required this.usual,
  });

  final Metric metric;
  final double? value;
  final (double, double)? usual;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final spec = metric.spec;
    final value = this.value;
    final usual = this.usual;
    final String note;
    if (value == null) {
      note = l10n.noValueThisNight;
    } else if (usual == null) {
      note = l10n.tooFewValues;
    } else {
      final span = l10n.rangeFromTo(
        metric.format(formats, usual.$1),
        metric.formatWithUnit(formats, usual.$2),
      );
      note = switch (verdictOf(value, usual)) {
        RangeVerdict.below => l10n.belowUsual(span),
        RangeVerdict.within => l10n.withinUsual(span),
        RangeVerdict.above => l10n.aboveUsual(span),
      };
    }
    return InkWell(
      onTap: () {
        final origin = globalRectOf(context);
        if (origin != null) openMetric(context, metric, origin);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(spec.icon, color: scheme.tone(spec.tone).accent),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(metric.title(l10n), style: theme.textTheme.titleSmall),
                  Text(
                    note,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              metric.formatWithUnit(formats, value),
              style: context.emphasizedTextTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
