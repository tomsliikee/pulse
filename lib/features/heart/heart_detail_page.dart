import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../data/health_controller.dart';
import '../../data/health_history.dart';
import '../../data/heart_day.dart';
import '../../data/heart_insights.dart';
import '../../data/metric_catalog.dart';
import '../../data/models.dart';
import '../../data/sleep_insights.dart';
import '../../data/workout_insights.dart' show Trend;
import '../../theme/app_theme.dart';
import '../../theme/app_type.dart';
import '../../theme/page_accent.dart';
import '../../widgets/animated_count.dart';
import '../../widgets/day_switcher.dart';
import '../../widgets/detail_sections.dart';
import '../../widgets/entrance.dart';
import '../../widgets/floating_tab_bar.dart';
import '../../widgets/number_grid.dart';
import '../../widgets/page_header.dart';
import '../../widgets/section_card.dart';
import '../../widgets/segment_group.dart';
import '../../widgets/shape_badge.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/sub_page.dart';
import '../detail/metric_spec.dart';
import '../detail/usual_value_row.dart';
import 'heart_curve.dart';
import 'heart_format.dart';
import 'heart_scene.dart';
import 'heart_tiles.dart';

/// Values of the day that belong to the heart, shown beside its pulse if
/// the snapshot has them.
const List<Metric> _heartMetrics = [
  Metric.restingHeartRate,
  Metric.heartRateVariability,
  Metric.oxygenSaturation,
  Metric.respiratoryRate,
];

/// Everything the app can say about the pulse of the day [date]: how far it
/// ranged, its curve to tap and to hold, the time in each zone and part of
/// the day, how it stands against the days before, and what to make of it.
/// The day hour by hour is at the end.
class HeartDetailPage extends StatefulWidget {
  const HeartDetailPage({super.key, required this.date});

  /// The day the page opens on; the bar at its bottom leads to others.
  final DateTime date;

  @override
  State<HeartDetailPage> createState() => _HeartDetailPageState();
}

class _HeartDetailPageState extends State<HeartDetailPage> {
  late DateTime _date = widget.date;

  static const double _curveHeight = 264;

  void _show(DateTime day) {
    if (day == _date) return;
    setState(() => _date = day);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    return PageAccent.heart(
      child: ListenableBuilder(
        listenable: Listenable.merge([health, scope.settings]),
        builder: (context, _) => SubPage(
          title: Formats.of(context).l10n.heartInDetail,
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
                    // Only the days with a curve, so no list of all days.
                    child: DaySwitcher(
                      today: health.today,
                      selected: _date,
                      earlier: _earlier(health),
                      glass: scope.settings.liquidGlass,
                      onSelected: _show,
                    ),
                  ),
                ),
          child: health.status == HealthStatus.ready
              ? _content(context, health)
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
      for (final day in heartDays(health).reversed)
        if (dayKey(day) < before) day,
    ].take(DaySwitcher.menuDays).toList();
  }

  Widget _content(BuildContext context, HealthController health) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final date = _date;
    final snapshot = health.snapshot;
    final index = snapshot.indexOf(date);
    final samples = heartSamplesOn(health, date);
    final summary = heartSummary(samples);
    final dateLine = Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
      child: Text(
        formats.longDate(date),
        style: theme.textTheme.titleMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
    if (summary == null || samples.length < 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          dateLine,
          SurfaceCard(child: EmptyNote(l10n.noHeartCurve)),
        ],
      );
    }

    final insights = heartInsightsOf(health, date);
    final hours = heartHours(samples);
    final history = health.history;
    final metrics = [
      for (final metric in _heartMetrics)
        if (snapshot.has(metric)) metric,
    ];

    final sections = <Widget>[
      _Summary(samples: samples, insights: insights),
      _Numbers(
        samples: samples,
        resting: health.valueOn(Metric.restingHeartRate, date),
        variability: health.valueOn(Metric.heartRateVariability, date),
      ),
      TitledSection(
        title: l10n.dayCurve,
        // The pill sits on the surface's top edge, under the title.
        child: Padding(
          padding: const EdgeInsets.only(top: HeartCurve.pillRoom),
          child: SurfaceCard(
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: _curveHeight,
              child: HeartCurve(samples: samples, day: date),
            ),
          ),
        ),
      ),
      TitledSection(
        title: l10n.timeInZones,
        child: HeartZones(samples: samples, detailed: true),
      ),
      _Parts(parts: heartParts(samples)),
      _Comparison(insights: insights),
      SectionCard(
        title: l10n.heartLastDays,
        child: HeartWeek(date: date, onSelected: _show, height: 150),
      ),
      if (metrics.isNotEmpty)
        TitledSection(
          title: l10n.heartValues,
          note: l10n.heartValuesNote,
          child: SegmentGroup(
            padding: EdgeInsets.zero,
            children: [
              for (final metric in metrics)
                UsualValueRow(
                  metric: metric,
                  value: index == null
                      ? history?.value(metric, date)
                      : snapshot.value(metric, index),
                  usual: ownRange(snapshot.valuesOf(metric)),
                  missing: l10n.noValueThisDay,
                ),
            ],
          ),
        ),
      NoteSegments(
        title: l10n.heartTipsTitle,
        icon: Icons.lightbulb_outline_rounded,
        sentences: [
          for (final tip in insights.tips) heartTipText(formats, tip),
        ],
        note: l10n.tipsNote,
      ),
      TitledSection(
        title: l10n.hourByHour,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, hour) in hours.indexed)
              ListSegment(
                first: i == 0,
                last: i == hours.length - 1,
                child: _HourRow(
                  hour: hour,
                  low: summary.low,
                  high: summary.high,
                ),
              ),
          ],
        ),
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
}

/// The figure with its heart in the one container of the page, the day's
/// average on a heart that hangs over its edge, and below it, free, how far
/// the pulse ranged and how the day went against the days before.
class _Summary extends StatelessWidget {
  const _Summary({required this.samples, required this.insights});

  final List<HeartSample> samples;
  final HeartDayInsights insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final type = AppType.of(context);
    final accent = PageAccent.colorsOf(context);
    final summary = heartSummary(samples)!;
    return SceneSummary(
      scene: HeartScene(bpm: summary.average, height: SceneSummary.sceneHeight),
      mark: SizedBox.square(
        dimension: SceneSummary.markSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            BeatingHeart(
              bpm: summary.average,
              color: accent.accent,
              size: SceneSummary.markSize,
            ),
            // A little above the middle, where the heart is widest.
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AnimatedCount(
                value: summary.average,
                style: type.hero(
                  context.emphasizedTextTheme.headlineLarge?.copyWith(
                    color: accent.onAccent,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      label: l10n.heartDayAverage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.bpmRange(summary.low, summary.high),
              maxLines: 1,
              style: type.hero(context.emphasizedTextTheme.displaySmall),
            ),
          ),
          Text(
            l10n.measuredFromTo(
              formatClock(samples.first.minuteOfDay),
              formatClock(samples.last.minuteOfDay),
            ),
            style: type.label(
              theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            heartHeadline(formats, insights),
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

/// Every number of the day's pulse.
class _Numbers extends StatelessWidget {
  const _Numbers({
    required this.samples,
    required this.resting,
    required this.variability,
  });

  final List<HeartSample> samples;
  final double? resting;
  final double? variability;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final summary = heartSummary(samples)!;
    final resting = this.resting;
    final variability = this.variability;

    Widget rate(int bpm) => AnimatedNumber(
      value: bpm.toDouble(),
      format: (value) => bpmText(value.round()),
    );
    Widget at(int minute) => Text(
      l10n.atTime(formatClock(minute)),
      style: AppType.of(context).label(
        theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    return TitledSection(
      title: l10n.dayNumbers,
      child: NumberGrid(
        cells: [
          NumberCell(label: l10n.heartAverage, value: rate(summary.average)),
          NumberCell(
            label: l10n.lowest,
            value: rate(summary.low),
            footer: at(summary.lowMinute),
          ),
          if (resting != null)
            NumberCell(
              label: l10n.metricRestingHeartRate,
              value: rate(resting.round()),
            ),
          NumberCell(
            label: l10n.highest,
            value: rate(summary.high),
            footer: at(summary.highMinute),
          ),
          NumberCell(
            label: l10n.heartActive,
            value: AnimatedNumber(
              value: activeMinutes(samples).toDouble(),
              format: (value) => formats.duration(value.round()),
            ),
          ),
          if (variability != null)
            NumberCell(
              label: l10n.shortHrv,
              value: Text(
                Metric.heartRateVariability.formatWithUnit(
                  formats,
                  variability,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The quarters of the day, each on a shape of its own with its average
/// and how far the pulse ranged in it.
class _Parts extends StatelessWidget {
  const _Parts({required this.parts});

  final List<HeartPart> parts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = Formats.of(context).l10n;
    final type = AppType.of(context);
    return TitledSection(
      title: l10n.partsOfDay,
      child: SegmentGroup(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          for (final part in parts)
            Row(
              children: [
                ShapeBadge(
                  shape: part.part.shape,
                  icon: part.part.icon,
                  size: 44,
                  color: scheme.tone(part.part.tone).container,
                  iconColor: scheme.tone(part.part.tone).onContainer,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        part.part.label(l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.strong(theme.textTheme.titleSmall),
                      ),
                      Text(
                        part.low == part.high
                            ? bpmText(part.low)
                            : l10n.bpmRange(part.low, part.high),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.averageValue(bpmText(part.average)),
                  style: type.figure(context.emphasizedTextTheme.titleMedium),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Each number against the day before and against the mean of the days
/// before, a segment for each.
class _Comparison extends StatelessWidget {
  const _Comparison({required this.insights});

  final HeartDayInsights insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final rows = [
      for (final comparison in insights.comparisons)
        if (comparison.previous != null || comparison.mean != null) comparison,
    ];
    if (rows.isEmpty) {
      return TitledSection(
        title: l10n.compareTitle,
        child: SegmentGroup(
          children: [
            Text(
              l10n.compareNoDay,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    Widget difference(HeartComparison comparison, double? other, Trend trend) {
      if (other == null) return const SizedBox.shrink();
      final diff = comparison.value - other;
      final size = comparison.measure.formatDifference(formats, diff);
      return DifferenceText(
        text: diff.abs() < 0.5 ? '±0' : '${diff < 0 ? '−' : '+'}$size',
        good: switch (trend) {
          Trend.better => true,
          Trend.worse => false,
          Trend.same || Trend.neutral => null,
        },
      );
    }

    return ComparisonSegments(
      title: l10n.compareTitle,
      heads: [l10n.compareDayBefore, l10n.compareDaysBefore],
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
              difference(comparison, comparison.mean, comparison.againstMean),
            ],
          ),
      ],
    );
  }
}

/// One hour of the day: when it was, how far the pulse ranged in it, where
/// that lies within the day's range, and, at the end, its average.
class _HourRow extends StatelessWidget {
  const _HourRow({required this.hour, required this.low, required this.high});

  final HeartHour hour;

  /// The lowest and the highest rate of the whole day.
  final int low;
  final int high;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = Formats.of(context).l10n;
    final span = high - low == 0 ? 1 : high - low;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.rangeFromTo(
                    formatClockHour(hour.hour),
                    formatClockHour(hour.hour + 1),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  hour.low == hour.high
                      ? bpmText(hour.low)
                      : l10n.bpmRange(hour.low, hour.high),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                CustomPaint(
                  size: const Size(double.infinity, 6),
                  painter: _SpanPainter(
                    from: (hour.low - low) / span,
                    to: (hour.high - low) / span,
                    color: PageAccent.colorsOf(context).accent,
                    track: scheme.onSurface.withValues(alpha: 0.08),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            l10n.averageValue(bpmText(hour.average)),
            style: AppType.of(context)
                .figure(context.emphasizedTextTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}

/// A stretch of a round track, from [from] to [to] of its length.
class _SpanPainter extends CustomPainter {
  const _SpanPainter({
    required this.from,
    required this.to,
    required this.color,
    required this.track,
  });

  final double from;
  final double to;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = track,
    );
    // Never thinner than a dot.
    final width = ((to - from) * size.width).clamp(size.height, size.width);
    final left = (from * size.width).clamp(0.0, size.width - width);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, width, size.height),
        radius,
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SpanPainter oldDelegate) =>
      oldDelegate.from != from ||
      oldDelegate.to != to ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}
