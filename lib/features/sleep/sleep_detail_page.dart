import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/layout.dart';
import '../../data/health_controller.dart';
import '../../data/health_snapshot.dart';
import '../../data/metric_catalog.dart';
import '../../data/models.dart';
import '../../data/sleep_insights.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/sub_page.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/line_chart.dart';
import '../../widgets/page_header.dart';
import '../../widgets/section_card.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/tile_surface.dart';
import '../detail/metric_spec.dart';
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

/// Everything the app can say about the selected night: its stages against
/// typical shares, how regular the nights are and how far they stay behind
/// the goal.
class SleepDetailPage extends StatelessWidget {
  const SleepDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([health, scope.settings]),
      builder: (context, _) => SubPage(
        title: l10n.sleepInDetail,
        glass: scope.settings.liquidGlass,
        child: health.status == HealthStatus.ready
            ? _content(context, health, scope.settings.sleepGoalHours)
            : const SizedBox(
                height: 240,
                child: Center(child: M3ELoadingIndicator()),
              ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    HealthController health,
    double goalHours,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final snapshot = health.snapshot;
    final index = health.selectedIndex;
    final night = health.night;
    final regularity = sleepRegularity(snapshot.nights);
    final heart = nightHeart(snapshot, index);
    final debtFrom = index - _debtNights + 1 < 0 ? 0 : index - _debtNights + 1;
    final metrics = [
      for (final metric in _nightMetrics)
        if (snapshot.has(metric)) metric,
    ];
    final stageColors = {
      SleepStage.awake: scheme.outlineVariant,
      SleepStage.rem: scheme.tertiary,
      SleepStage.light: scheme.secondary,
      SleepStage.deep: scheme.primary,
    };

    final sections = <Widget>[
      if (night == null)
        SurfaceCard(child: EmptyNote(l10n.noSleepData))
      else ...[
        _Overview(night: night),
        if (night.hasStages) ...[
          SectionCard(
            title: l10n.sleepStages,
            child: Column(
              children: [
                SleepStagesChart(
                  night: night,
                  colors: stageColors,
                  height: 160,
                ),
                const SizedBox(height: 8),
                _ClockRow(minutes: [night.bedtimeMinute, night.wakeMinute]),
              ],
            ),
          ),
          SectionCard(
            title: l10n.stagesCompared,
            child: _StageComparison(night: night, colors: stageColors),
          ),
        ] else
          SectionCard(
            title: l10n.sleepStages,
            child: EmptyNote(l10n.noStagesRecorded),
          ),
      ],
      if (regularity != null)
        SectionCard(
          title: l10n.regularity,
          trailing: l10n.nightsCount(regularity.nights),
          child: _Regularity(
            nights: snapshot.nights,
            selectedIndex: index,
            regularity: regularity,
          ),
        ),
      if (snapshot.nights.sublist(debtFrom, index + 1).any((n) => n != null))
        SectionCard(
          title: l10n.sleepDebt,
          child: _Debt(
            snapshot: snapshot,
            from: debtFrom,
            to: index,
            goalHours: goalHours,
          ),
        ),
      if (heart.length >= 2)
        SectionCard(
          title: l10n.nightPulse,
          trailing: _heartSummary(l10n, heart),
          child: Column(
            children: [
              LineChart(
                // Draw the line again for every night.
                key: ValueKey(health.selectedDate),
                values: [for (final sample in heart) sample.bpm.toDouble()],
                color: scheme.tertiary,
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
        SectionCard(
          title: l10n.nightValues,
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final metric in metrics)
                _NightValue(
                  metric: metric,
                  value: snapshot.value(metric, index),
                  usual: ownRange(snapshot.valuesOf(metric)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  l10n.nightValuesNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Text(
            l10n.nightTo(formats.longDate(health.selectedDate)),
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          sections[i],
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
  const _Figure({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = this.color ?? theme.colorScheme.onSurface;
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

class _Overview extends StatelessWidget {
  const _Overview({required this.night});

  final SleepNight night;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final onContainer = scheme.onSecondaryContainer;
    return TileSurface(
      color: scheme.secondaryContainer,
      radius: AppRadii.extraLargeIncreased,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formats.duration(night.asleepMinutes),
              maxLines: 1,
              style: context.emphasizedTextTheme.displaySmall?.copyWith(
                color: onContainer,
              ),
            ),
          ),
          Text(
            l10n.asleepFromTo(
              formatClock(night.bedtimeMinute),
              formatClock(night.wakeMinute),
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: onContainer.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Figure(
                  label: l10n.inBed,
                  value: formats.duration(night.totalMinutes),
                  color: onContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Figure(
                  label: l10n.efficiency,
                  value: l10n.percentValue(
                    (sleepEfficiency(night) * 100).round(),
                  ),
                  color: onContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Figure(
                  label: l10n.scoreEstimated,
                  value: '${night.estimatedScore}',
                  color: onContainer,
                ),
              ),
            ],
          ),
        ],
      ),
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

/// The nights from [from] to [to] against the goal, and what they add up to.
class _Debt extends StatelessWidget {
  const _Debt({
    required this.snapshot,
    required this.from,
    required this.to,
    required this.goalHours,
  });

  final HealthSnapshot snapshot;
  final int from;
  final int to;
  final double goalHours;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final nights = snapshot.nights.sublist(from, to + 1);
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
            for (var i = from; i <= to; i++)
              formats.weekdayShort[snapshot.dateAt(i).weekday - 1],
          ],
          selectedIndex: to - from,
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
