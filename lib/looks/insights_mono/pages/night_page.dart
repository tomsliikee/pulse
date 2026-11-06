import 'package:material_ui/material_ui.dart';

import '../../../app/formatters.dart';
import '../../../data/health_history.dart';
import '../../../data/links.dart';
import '../../../data/metric_catalog.dart';
import '../../../data/models.dart';
import '../../../data/night_insights.dart';
import '../../../data/sleep_insights.dart';
import '../../../data/workout_insights.dart' show Trend;
import '../../../features/detail/metric_spec.dart';
import '../../../features/goals/goal_format.dart';
import '../../../features/links/link_format.dart';
import '../../../features/sleep/night_format.dart';
import '../../../features/sleep/sleep_detail_page.dart'
    show SleepDebtView, SleepRegularityView, StageComparisonView;
import '../data/mono_data.dart';
import '../theme/mono_type.dart';
import '../widgets/mono_blocks.dart';
import '../widgets/mono_card.dart';
import '../widgets/mono_category.dart';
import '../widgets/mono_charts.dart';
import '../widgets/mono_page.dart';
import 'links_page.dart';
import 'list_pages.dart';

const List<Metric> _nightMetrics = [
  Metric.restingHeartRate,
  Metric.heartRateVariability,
  Metric.respiratoryRate,
  Metric.oxygenSaturation,
  Metric.skinTemperature,
];

/// One night in the look: its score and what it is made of, its numbers
/// and stages, how it stands against the nights before, how regular the
/// nights are, the debt, the pulse, the values taken in sleep, what goes
/// with it and what to do next. The arrows lead to the nights around it.
class MonoNightPage extends StatefulWidget {
  const MonoNightPage({super.key, required this.date});

  final DateTime date;

  @override
  State<MonoNightPage> createState() => _MonoNightPageState();
}

class _MonoNightPageState extends State<MonoNightPage> {
  late DateTime _date = widget.date;

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.health, scope.settings]),
      builder: (context, _) => _page(context, MonoCtx.of(context)),
    );
  }

  Widget _page(BuildContext context, MonoCtx c) {
    final l10n = c.l10n;
    final formats = c.formats;
    final t = c.t;
    final health = c.health;
    final settings = c.settings;
    final snapshot = health.snapshot;
    final all = health.nights;
    final key = dayKey(_date);
    final at = all.indexWhere((n) => dayKey(n.date) == key);
    final stored = at == -1 ? null : all[at];
    final earlier = at > 0 ? all[at - 1] : null;
    final later = at != -1 && at < all.length - 1 ? all[at + 1] : null;
    final switcher = Row(
      children: [
        MonoIconButton(
          icon: Icons.chevron_left_rounded,
          label: l10n.earlier,
          onTap: earlier == null
              ? null
              : () => setState(() => _date = earlier.date),
        ),
        Expanded(
          child: Text(
            l10n.nightTo(formats.longDate(_date)),
            textAlign: TextAlign.center,
            style: MonoType.inter(14, 18, FontWeight.w600, t.ink2),
          ),
        ),
        MonoIconButton(
          icon: Icons.chevron_right_rounded,
          label: l10n.later,
          onTap: later == null
              ? null
              : () => setState(() => _date = later.date),
        ),
      ],
    );
    if (stored == null) {
      return MonoSubPage(
        category: MonoCategory.sleep,
        categoryLabel: l10n.sleepInDetail,
        backLabel: l10n.groupSleep,
        statement: l10n.noSleepData,
        children: [MonoSurface(child: switcher)],
      );
    }
    final night = health.withCurve(stored);
    final insights = NightInsights.of(stored, all, settings.sleepGoalHours);
    final byDay = {for (final other in all) dayKey(other.date): other};
    final days = [for (var day = key - 30 + 1; day <= key; day++) byDay[day]];
    final week = days.sublist(days.length - 7);
    final regularity = sleepRegularity(days);
    final index = snapshot.indexOf(_date);
    final heart = index == null
        ? const <HeartSample>[]
        : nightHeart(snapshot, index);
    final metrics = [
      for (final metric in _nightMetrics)
        if (snapshot.has(metric)) metric,
    ];
    final links = [
      for (final link in findLinks(
        data: goalDataOf(health, settings),
        targetOf: settings.goalTarget,
        until: _date,
        kinds: const {LinkKind.dayToNight},
      ))
        if ((link.cause == LinkCause.workout ||
                link.cause == LinkCause.steps) &&
            (link.effect == LinkEffect.asleep ||
                link.effect == LinkEffect.deep))
          link,
    ];
    final before = nightsBefore(all, _date, all.length + 1);
    final stageColors = {
      SleepStage.awake: t.fill,
      SleepStage.rem: t.heart,
      SleepStage.light: t.ink3,
      SleepStage.deep: t.solid,
    };
    final score = insights.score;
    final compared = [
      for (final m in insights.measures)
        if (m.previous != null) m,
    ];

    Widget delta(NightComparison m, double? other, Trend trend) {
      if (other == null) return const SizedBox.shrink();
      final diff = m.value - other;
      return MonoDelta(
        trend == Trend.same || diff.abs() < 0.005
            ? '±0'
            : '${diff < 0 ? '−' : '+'}'
                  '${m.measure.formatDifference(formats, diff)}',
        good: switch (trend) {
          Trend.better => true,
          Trend.worse => false,
          Trend.same || Trend.neutral => null,
        },
      );
    }

    return MonoSubPage(
      category: MonoCategory.sleep,
      categoryLabel: l10n.sleepInDetail,
      kicker: l10n.nightTo(formats.longDate(_date)),
      backLabel: l10n.groupSleep,
      statement: nightHeadline(formats, insights),
      children: [
        MonoSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              switcher,
              const SizedBox(height: 16),
              Row(
                children: [
                  if (!c.simple) ...[
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.solid,
                      ),
                      child: Text(
                        '${score.total}',
                        style: MonoType.number(t).copyWith(color: t.onSolid),
                      ),
                    ),
                    const SizedBox(width: 18),
                  ],
                  Expanded(
                    child: MonoStat(
                      label: l10n.scoreTitle,
                      value: formats.duration(night.asleepMinutes),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.asleepFromTo(
                  formatClock(night.bedtimeMinute),
                  formatClock(night.wakeMinute),
                ),
                style: MonoType.sub(t),
              ),
              if (night.hasCurve) ...[
                const SizedBox(height: 18),
                MonoHypnogram(
                  segments: night.segments,
                  totalMinutes: night.totalMinutes,
                  semantics: l10n.sleepStages,
                  height: 90,
                ),
              ],
            ],
          ),
        ),
        MonoBlock(
          title: l10n.sleepScoreParts,
          child: MonoList(
            gap: 16,
            children: [
              for (final part in ScorePart.values)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MonoPair(
                      label: part.label(l10n),
                      value: switch (score.parts[part]) {
                        final earned? => l10n.scorePoints(
                          earned.round(),
                          part.points,
                        ),
                        null => l10n.scoreNotJudged,
                      },
                    ),
                    if (score.parts[part] case final earned?) ...[
                      const SizedBox(height: 8),
                      MonoTrack(value: earned / part.points),
                    ],
                  ],
                ),
              Text(l10n.scoreNote, style: MonoType.time(t)),
            ],
          ),
        ),
        MonoBlock(
          title: l10n.nightNumbers,
          child: MonoGrid(
            cells: [
              MonoStat(
                label: l10n.inBed,
                value: formats.duration(night.totalMinutes),
                small: true,
              ),
              for (final measure in const [
                NightMeasure.efficiency,
                NightMeasure.deep,
                NightMeasure.rem,
                NightMeasure.light,
                NightMeasure.awake,
              ])
                if (insights.measure(measure) case final comparison?)
                  MonoStat(
                    label: measure.label(l10n),
                    value: measure.format(formats, comparison.value),
                    small: true,
                  ),
            ],
          ),
        ),
        MonoBlock(
          title: l10n.stagesCompared,
          child: MonoSurface(
            child: night.hasStages
                ? StageComparisonView(night: night, colors: stageColors)
                : Text(l10n.noStagesRecorded, style: MonoType.sub(t)),
          ),
        ),
        MonoBlock(
          title: l10n.compareTitle,
          child: compared.isEmpty
              ? MonoSurface(
                  child: Text(l10n.compareNoNight, style: MonoType.sub(t)),
                )
              : MonoList(
                  children: [
                    Row(
                      children: [
                        const Expanded(child: SizedBox.shrink()),
                        for (final head in [
                          l10n.compareNightBefore,
                          l10n.compareWeek,
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
                            child: delta(m, m.average, m.againstAverage),
                          ),
                        ],
                      ),
                  ],
                ),
        ),
        if (regularity != null)
          MonoBlock(
            title: l10n.regularity,
            trailing: Text(
              l10n.nightsCount(regularity.nights),
              style: MonoType.label(t),
            ),
            child: MonoSurface(
              child: SleepRegularityView(
                nights: days,
                selectedIndex: days.length - 1,
                regularity: regularity,
              ),
            ),
          ),
        MonoBlock(
          title: l10n.sleepDebt,
          child: MonoSurface(
            child: SleepDebtView(
              nights: week,
              until: _date,
              goalHours: settings.sleepGoalHours,
            ),
          ),
        ),
        if (heart.length >= 2)
          MonoBlock(
            title: l10n.nightPulse,
            child: MonoSurface(
              child: Column(
                children: [
                  MonoLine(
                    values: [for (final s in heart) s.bpm.toDouble()],
                    color: t.heart,
                    semantics: l10n.nightPulse,
                    height: 130,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final m in [
                        heart.first.minuteOfDay,
                        heart.last.minuteOfDay,
                      ])
                        Text(formatClockOf(m), style: MonoType.time(t)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (metrics.isNotEmpty)
          MonoBlock(
            title: l10n.nightValues,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MonoList(
                  children: [
                    for (final metric in metrics)
                      _UsualRow(
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
                MonoNote(l10n.nightValuesNote),
              ],
            ),
          ),
        if (links.isNotEmpty)
          MonoBlock(
            title: l10n.linksTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MonoSentences(
                  icon: Icons.link_rounded,
                  sentences: [
                    for (final link in links) linkSentence(formats, link),
                  ],
                  note: l10n.linksNote,
                ),
                const SizedBox(height: 12),
                MonoSurface(
                  onTap: () => c.push(const MonoLinksPage()),
                  child: MonoRow(title: l10n.linksAll),
                ),
              ],
            ),
          ),
        if (insights.tips.isNotEmpty)
          MonoBlock(
            title: l10n.sleepTipsTitle,
            child: MonoSentences(
              icon: Icons.lightbulb_outline_rounded,
              sentences: [
                for (final tip in insights.tips) nightTip(formats, tip),
              ],
              note: l10n.tipsNote,
            ),
          ),
        if (before.isNotEmpty)
          MonoBlock(
            title: l10n.nightsBeforeTitle,
            child: MonoList(
              children: [
                for (final n in before.reversed.take(3))
                  MonoRow(
                    title: formats.relativeDay(n.date, c.today),
                    value: formats.duration(n.totalMinutes),
                    onTap: () => setState(() => _date = n.date),
                  ),
                MonoRow(
                  title: l10n.allNights,
                  onTap: () => c.push(const MonoNightListPage()),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A value taken in sleep, beside the range that is usual for the person.
class _UsualRow extends StatelessWidget {
  const _UsualRow({
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
    final off =
        value != null &&
        range != null &&
        (value! < range.$1 || value! > range.$2);
    return Row(
      children: [
        Expanded(
          child: MonoPair(
            label: metric.title(c.l10n),
            value: value == null
                ? c.l10n.noValueThisNight
                : metric.formatWithUnit(formats, value),
            sub: range == null
                ? null
                : '${metric.format(formats, range.$1)} – '
                      '${metric.formatWithUnit(formats, range.$2)}',
            dot: off ? c.t.heart : c.t.ink3,
          ),
        ),
      ],
    );
  }
}
