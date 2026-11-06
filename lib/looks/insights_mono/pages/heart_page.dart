import 'package:material_ui/material_ui.dart';

import '../../../app/formatters.dart';
import '../../../data/health_history.dart';
import '../../../data/heart_day.dart';
import '../../../data/heart_insights.dart';
import '../../../data/metric_catalog.dart';
import '../../../data/sleep_insights.dart';
import '../../../data/workout_insights.dart' show Trend;
import '../../../features/detail/metric_spec.dart';
import '../../../features/heart/heart_curve.dart';
import '../../../features/heart/heart_detail_page.dart' show HeartHourRow;
import '../../../features/heart/heart_format.dart';
import '../../../features/heart/heart_tiles.dart';
import '../../../theme/page_accent.dart';
import '../data/mono_data.dart';
import '../theme/mono_type.dart';
import '../widgets/mono_blocks.dart';
import '../widgets/mono_card.dart';
import '../widgets/mono_category.dart';
import '../widgets/mono_page.dart';
import 'metric_page.dart';

const List<Metric> _heartMetrics = [
  Metric.restingHeartRate,
  Metric.heartRateVariability,
  Metric.oxygenSaturation,
  Metric.respiratoryRate,
];

/// The pulse of one day in the look: how far it ranged, its curve to tap
/// and to hold, the time in each zone and part of the day, how it stands
/// against the days before, the values of the heart, and the day hour by
/// hour.
class MonoHeartPage extends StatefulWidget {
  const MonoHeartPage({super.key, required this.date});

  final DateTime date;

  @override
  State<MonoHeartPage> createState() => _MonoHeartPageState();
}

class _MonoHeartPageState extends State<MonoHeartPage> {
  late DateTime _date = widget.date;

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    // The shared charts below take the red of the heart from the accent.
    return PageAccent.heart(
      child: ListenableBuilder(
        listenable: Listenable.merge([scope.health, scope.settings]),
        builder: (context, _) => _page(MonoCtx.of(context)),
      ),
    );
  }

  Widget _page(MonoCtx c) {
    final l10n = c.l10n;
    final formats = c.formats;
    final t = c.t;
    final health = c.health;
    final snapshot = health.snapshot;
    final days = heartDays(health);
    final key = dayKey(_date);
    final at = days.indexWhere((d) => dayKey(d) == key);
    final earlier = at > 0 ? days[at - 1] : null;
    final later = at != -1 && at < days.length - 1 ? days[at + 1] : null;
    final switcher = Row(
      children: [
        MonoIconButton(
          icon: Icons.chevron_left_rounded,
          label: l10n.earlier,
          onTap: earlier == null ? null : () => setState(() => _date = earlier),
        ),
        Expanded(
          child: Text(
            formats.longDate(_date),
            textAlign: TextAlign.center,
            style: MonoType.inter(14, 18, FontWeight.w600, t.ink2),
          ),
        ),
        MonoIconButton(
          icon: Icons.chevron_right_rounded,
          label: l10n.later,
          onTap: later == null ? null : () => setState(() => _date = later),
        ),
      ],
    );
    final samples = heartSamplesOn(health, _date);
    final summary = heartSummary(samples);
    final history = MonoSurface(
      onTap: () => c.push(const MonoMetricPage(metric: Metric.heartRate)),
      child: MonoRow(title: l10n.trendRows),
    );
    if (summary == null || samples.length < 2) {
      return MonoSubPage(
        category: MonoCategory.heart,
        categoryLabel: l10n.heartInDetail,
        backLabel: l10n.navHeart,
        statement: l10n.noHeartCurve,
        children: [
          MonoSurface(child: switcher),
          history,
        ],
      );
    }
    final insights = heartInsightsOf(health, _date);
    final hours = heartHours(samples);
    final index = snapshot.indexOf(_date);
    final resting = health.valueOn(Metric.restingHeartRate, _date);
    final variability = health.valueOn(Metric.heartRateVariability, _date);
    final metrics = [
      for (final metric in _heartMetrics)
        if (snapshot.has(metric)) metric,
    ];
    final compared = [
      for (final m in insights.comparisons)
        if (m.previous != null || m.mean != null) m,
    ];

    Widget delta(HeartComparison m, double? other, Trend trend) {
      if (other == null) return const SizedBox.shrink();
      final diff = m.value - other;
      return MonoDelta(
        diff.abs() < 0.5
            ? '±0'
            : '${diff < 0 ? '−' : '+'}${m.measure.formatDifference(formats, diff)}',
        good: switch (trend) {
          Trend.better => true,
          Trend.worse => false,
          Trend.same || Trend.neutral => null,
        },
      );
    }

    Widget cell(String label, String value, [String? foot]) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MonoStat(label: label, value: value, small: true),
        if (foot != null) Text(foot, style: MonoType.time(t)),
      ],
    );

    return MonoSubPage(
      category: MonoCategory.heart,
      categoryLabel: l10n.heartInDetail,
      kicker: formats.longDate(_date),
      backLabel: l10n.navHeart,
      statement: heartHeadline(formats, insights),
      children: [
        MonoSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              switcher,
              const SizedBox(height: 16),
              MonoStat(
                label: l10n.heartDayAverage,
                value: '${summary.average}',
                unit: 'bpm',
                color: t.heart,
              ),
              const SizedBox(height: 6),
              Text(
                '${l10n.bpmRange(summary.low, summary.high)} · '
                '${l10n.measuredFromTo(formatClock(samples.first.minuteOfDay), formatClock(samples.last.minuteOfDay))}',
                style: MonoType.sub(t),
              ),
            ],
          ),
        ),
        MonoBlock(
          title: l10n.dayCurve,
          child: Padding(
            padding: const EdgeInsets.only(top: HeartCurve.pillRoom),
            child: MonoSurface(
              padding: EdgeInsets.zero,
              child: SizedBox(
                height: 264,
                child: HeartCurve(samples: samples, day: _date),
              ),
            ),
          ),
        ),
        MonoBlock(
          title: l10n.dayNumbers,
          child: MonoGrid(
            cells: [
              cell(l10n.heartAverage, bpmText(summary.average)),
              cell(
                l10n.lowest,
                bpmText(summary.low),
                l10n.atTime(formatClock(summary.lowMinute)),
              ),
              if (resting != null)
                cell(l10n.metricRestingHeartRate, bpmText(resting.round())),
              cell(
                l10n.highest,
                bpmText(summary.high),
                l10n.atTime(formatClock(summary.highMinute)),
              ),
              cell(l10n.heartActive, formats.duration(activeMinutes(samples))),
              if (variability != null)
                cell(
                  l10n.shortHrv,
                  Metric.heartRateVariability.formatWithUnit(
                    formats,
                    variability,
                  ),
                ),
            ],
          ),
        ),
        MonoBlock(
          title: l10n.timeInZones,
          child: HeartZones(samples: samples, detailed: true),
        ),
        MonoBlock(
          title: l10n.partsOfDay,
          child: MonoList(
            children: [
              for (final part in heartParts(samples))
                MonoPair(
                  label: part.part.label(l10n),
                  sub: part.low == part.high
                      ? bpmText(part.low)
                      : l10n.bpmRange(part.low, part.high),
                  value: l10n.averageValue(bpmText(part.average)),
                ),
            ],
          ),
        ),
        MonoBlock(
          title: l10n.compareTitle,
          child: compared.isEmpty
              ? MonoSurface(
                  child: Text(l10n.compareNoDay, style: MonoType.sub(t)),
                )
              : MonoList(
                  children: [
                    Row(
                      children: [
                        const Expanded(child: SizedBox.shrink()),
                        for (final head in [
                          l10n.compareDayBefore,
                          l10n.compareDaysBefore,
                        ])
                          SizedBox(
                            width: 84,
                            child: Text(
                              head,
                              textAlign: TextAlign.end,
                              style: MonoType.label(t),
                            ),
                          ),
                      ],
                    ),
                    for (final m in compared)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.measure.label(l10n),
                              style: MonoType.body(t),
                            ),
                          ),
                          SizedBox(
                            width: 84,
                            child: delta(m, m.previous, m.againstPrevious),
                          ),
                          SizedBox(
                            width: 84,
                            child: delta(m, m.mean, m.againstMean),
                          ),
                        ],
                      ),
                  ],
                ),
        ),
        MonoBlock(
          title: l10n.heartLastDays,
          child: MonoSurface(
            child: HeartWeek(
              date: _date,
              onSelected: (day) => setState(() => _date = day),
              height: 150,
            ),
          ),
        ),
        if (metrics.isNotEmpty)
          MonoBlock(
            title: l10n.heartValues,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MonoList(
                  children: [
                    for (final metric in metrics)
                      _Usual(
                        c: c,
                        metric: metric,
                        value: index == null
                            ? health.history?.value(metric, _date)
                            : snapshot.value(metric, index),
                        usual: ownRange(snapshot.valuesOf(metric)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                MonoNote(l10n.heartValuesNote),
              ],
            ),
          ),
        if (insights.tips.isNotEmpty)
          MonoBlock(
            title: l10n.heartTipsTitle,
            child: MonoSentences(
              icon: Icons.lightbulb_outline_rounded,
              sentences: [
                for (final tip in insights.tips) heartTipText(formats, tip),
              ],
              note: l10n.tipsNote,
            ),
          ),
        MonoBlock(
          title: l10n.hourByHour,
          child: MonoSurface(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                for (final hour in hours)
                  HeartHourRow(
                    hour: hour,
                    low: summary.low,
                    high: summary.high,
                  ),
              ],
            ),
          ),
        ),
        history,
      ],
    );
  }
}

class _Usual extends StatelessWidget {
  const _Usual({
    required this.c,
    required this.metric,
    required this.value,
    required this.usual,
  });

  final MonoCtx c;
  final Metric metric;
  final double? value;
  final (double, double)? usual;

  @override
  Widget build(BuildContext context) {
    final formats = c.formats;
    final range = usual;
    final v = value;
    final off = v != null && range != null && (v < range.$1 || v > range.$2);
    return MonoPair(
      label: metric.title(c.l10n),
      value: v == null
          ? c.l10n.noValueThisDay
          : metric.formatWithUnit(formats, v),
      sub: range == null
          ? null
          : '${metric.format(formats, range.$1)} – '
                '${metric.formatWithUnit(formats, range.$2)}',
      dot: off ? c.t.heart : c.t.ink3,
    );
  }
}
