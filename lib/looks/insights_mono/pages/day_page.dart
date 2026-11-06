import 'package:material_ui/material_ui.dart';

import '../../../data/day_insights.dart';
import '../../../data/health_history.dart';
import '../../../data/metric_catalog.dart';
import '../../../data/recovery.dart';
import '../../../data/workout_insights.dart' show Trend;
import '../../../features/detail/metric_spec.dart';
import '../../../features/today/day_format.dart';
import '../../../features/today/day_scores.dart';
import '../data/mono_data.dart';
import '../theme/mono_type.dart';
import '../widgets/mono_blocks.dart';
import '../widgets/mono_card.dart';
import '../widgets/mono_category.dart';
import '../widgets/mono_charts.dart';
import '../widgets/mono_page.dart';
import 'list_pages.dart';
import 'night_page.dart';

/// One day in the look: its scores, the steps and how the day went, what
/// the recovery and the day score are made of, every number, how it stands
/// against the day and the week before, its night and workouts, and what to
/// do next. The arrows lead to the days around it.
class MonoDayPage extends StatefulWidget {
  const MonoDayPage({super.key, required this.date});

  final DateTime date;

  @override
  State<MonoDayPage> createState() => _MonoDayPageState();
}

class _MonoDayPageState extends State<MonoDayPage> {
  late DateTime _date = widget.date;

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.health, scope.settings]),
      builder: (context, _) => _page(MonoCtx.of(context)),
    );
  }

  Widget _page(MonoCtx c) {
    final l10n = c.l10n;
    final formats = c.formats;
    final t = c.t;
    final health = c.health;
    final insights = dayInsightsOf(health, c.settings, _date);
    final today = _date == health.today;
    final all = health.days;
    final key = dayKey(_date);
    final at = all.indexWhere((d) => dayKey(d) == key);
    final earlier = at > 0 ? all[at - 1] : null;
    final later = at != -1 && at < all.length - 1 ? all[at + 1] : null;
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
    if (insights.measures.isEmpty && insights.workouts.isEmpty) {
      return MonoSubPage(
        category: MonoCategory.recovery,
        categoryLabel: l10n.dayInDetail,
        backLabel: l10n.monoInsights,
        statement: l10n.noDayData,
        children: [MonoSurface(child: switcher)],
      );
    }
    final soFar = today ? stepsSoFar(health.snapshot, health.now) : null;
    final steps = insights.measure(DayMeasure.steps);
    final withScore = showsDayScore(insights.day, health.now);
    final recovery = insights.recovery;
    final score = insights.score;
    final night = insights.night;
    final before = [
      for (final day in all.reversed)
        if (dayKey(day) < key) day,
    ];
    final compared = [
      for (final m in insights.measures)
        if (m.previous != null || m.average != null) m,
    ];

    Widget delta(DayComparison m, double? other, Trend trend) {
      if (other == null) return const SizedBox.shrink();
      final diff = m.value - other;
      return MonoDelta(
        trend == Trend.same
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

    Widget mark(String label, int? value, {bool solid = false}) => Column(
      children: [
        Container(
          width: 76,
          height: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: solid ? t.recovery : t.solid,
          ),
          child: Text(
            value == null ? '–' : '$value',
            style: MonoType.number(t, size: 28).copyWith(color: t.bg),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: MonoType.label(t)),
      ],
    );

    return MonoSubPage(
      category: MonoCategory.recovery,
      categoryLabel: l10n.dayInDetail,
      kicker: formats.longDate(_date),
      backLabel: l10n.monoInsights,
      statement: dayHeadline(formats, insights, soFar: soFar),
      children: [
        MonoSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              switcher,
              const SizedBox(height: 18),
              if (!c.simple)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    mark(l10n.recovery, recovery.total, solid: true),
                    if (withScore) mark(l10n.dayScoreParts, score.total),
                  ],
                ),
              const SizedBox(height: 18),
              MonoStat(
                label: Metric.steps.title(l10n),
                value: Metric.steps.format(formats, steps?.value),
                unit: Metric.steps.unitFor(l10n, steps?.value),
              ),
              if (insights.streak > 1)
                Text(l10n.streakDays(insights.streak), style: MonoType.sub(t)),
            ],
          ),
        ),
        MonoBlock(
          title: l10n.recoveryParts,
          child: MonoList(
            gap: 16,
            children: [
              for (final part in RecoveryPart.values)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MonoPair(
                      label: part.metric?.title(l10n) ?? l10n.groupSleep,
                      value: switch ((recovery.parts[part], part.metric)) {
                        (final reading?, final metric?) => l10n.recoveryUsual(
                          metric.formatWithUnit(formats, reading.value),
                          metric.format(formats, reading.usual),
                        ),
                        (final reading?, null) => l10n.recoveryAimed(
                          formats.duration(reading.value.round()),
                          formats.duration(reading.usual.round()),
                        ),
                        (null, _) => l10n.scoreNotJudged,
                      },
                    ),
                    if (recovery.parts[part] case final reading?) ...[
                      const SizedBox(height: 8),
                      MonoTrack(value: reading.share, color: t.recovery),
                    ],
                  ],
                ),
              Text(l10n.recoveryNote, style: MonoType.time(t)),
            ],
          ),
        ),
        if (withScore)
          MonoBlock(
            title: l10n.dayScoreParts,
            child: MonoList(
              gap: 16,
              children: [
                for (final part in DayScorePart.values)
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
                Text(l10n.dayScoreNote, style: MonoType.time(t)),
              ],
            ),
          ),
        MonoBlock(
          title: l10n.dayNumbers,
          child: MonoGrid(
            cells: [
              for (final m in insights.measures)
                if (m.measure != DayMeasure.score)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MonoStat(
                        label: m.measure.label(l10n),
                        value: m.measure.formatAlone(formats, m.value),
                        small: true,
                      ),
                      if (m.isBest)
                        Row(
                          children: [
                            Icon(
                              Icons.emoji_events_rounded,
                              size: 14,
                              color: t.recovery,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.dayBest,
                              style: MonoType.inter(
                                12,
                                16,
                                FontWeight.w600,
                                t.recovery,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
            ],
          ),
        ),
        // A day that is still running is not set against whole days.
        if (!today)
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
        if (night != null)
          MonoBlock(
            title: l10n.dayNightTitle,
            child: MonoSurface(
              onTap: () => c.push(MonoNightPage(date: night.date)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MonoRow(
                    title: formats.duration(night.totalMinutes),
                    subtitle:
                        '${formatClockOf(night.bedtimeMinute)} – '
                        '${formatClockOf(night.bedtimeMinute + night.totalMinutes)}',
                  ),
                  if (night.hasCurve) ...[
                    const SizedBox(height: 12),
                    MonoHypnogram(
                      segments: night.segments,
                      totalMinutes: night.totalMinutes,
                      semantics: l10n.dayNightTitle,
                      height: 48,
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (insights.workouts.isNotEmpty)
          MonoBlock(
            title: l10n.dayWorkoutsTitle,
            child: MonoList(
              children: [
                for (final workout in insights.workouts)
                  monoWorkoutRow(c, workout),
              ],
            ),
          ),
        if (insights.tips.isNotEmpty)
          MonoBlock(
            title: today ? l10n.dayTipsTitle : l10n.dayTipsTitlePast,
            child: MonoSentences(
              icon: Icons.lightbulb_outline_rounded,
              sentences: [
                for (final tip in insights.tips) dayTip(formats, tip),
              ],
              note: l10n.tipsNote,
            ),
          ),
        if (before.isNotEmpty)
          MonoBlock(
            title: l10n.monoDays,
            child: MonoList(
              children: [
                for (final day in before.take(3))
                  MonoRow(
                    title: formats.relativeDay(day, c.today),
                    onTap: () => setState(() => _date = day),
                  ),
                MonoRow(
                  title: l10n.allDays,
                  onTap: () => c.push(const MonoDayListPage()),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
