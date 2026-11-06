import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/formatters.dart';
import '../../../app/haptics.dart';
import '../../../data/goals.dart';
import '../../../data/health_controller.dart';
import '../../../data/health_history.dart';
import '../../../data/metric_catalog.dart';
import '../../../data/week_report.dart';
import '../../../data/workout_insights.dart' show Trend;
import '../../../features/detail/metric_spec.dart';
import '../../../features/goals/goal_format.dart';
import '../../../features/links/link_card.dart';
import '../../../features/links/link_format.dart';
import '../../../features/week/week_page.dart' show weekReportOf;
import '../data/mono_data.dart';
import '../theme/mono_type.dart';
import '../widgets/mono_blocks.dart';
import '../widgets/mono_card.dart';
import '../widgets/mono_category.dart';
import '../widgets/mono_charts.dart';
import '../widgets/mono_page.dart';
import 'day_page.dart';
import 'links_page.dart';
import 'list_pages.dart';
import 'night_page.dart';

/// A week from Monday to Sunday looked back on, in the look: its score and
/// its days, its numbers against the weeks before, the best of it, the
/// goals, the workouts, the sleep, and what goes together.
class MonoWeekPage extends StatefulWidget {
  const MonoWeekPage({super.key, this.monday});

  final DateTime? monday;

  @override
  State<MonoWeekPage> createState() => _MonoWeekPageState();
}

class _MonoWeekPageState extends State<MonoWeekPage> {
  DateTime? _monday;

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
    final ready = health.status == HealthStatus.ready;
    final monday = _monday ??= widget.monday ?? latestReportWeek(health.now);
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

    final switcher = Row(
      children: [
        MonoIconButton(
          icon: Icons.chevron_left_rounded,
          label: l10n.weekOlder,
          onTap: dayKey(monday) > dayKey(first) ? () => page(-1) : null,
        ),
        Expanded(
          child: Text(
            formats.dayRange(
              monday,
              DateTime(monday.year, monday.month, monday.day + 6),
            ),
            textAlign: TextAlign.center,
            style: MonoType.inter(14, 18, FontWeight.w600, t.ink2),
          ),
        ),
        MonoIconButton(
          icon: Icons.chevron_right_rounded,
          label: l10n.weekNewer,
          onTap: dayKey(monday) < dayKey(current) ? () => page(1) : null,
        ),
      ],
    );
    if (!ready) {
      return MonoSubPage(
        category: MonoCategory.recovery,
        icon: Icons.view_week_rounded,
        categoryLabel: l10n.weekTitle,
        backLabel: l10n.monoInsights,
        children: [MonoSurface(child: switcher)],
      );
    }
    final report = weekReportOf(health, c.settings, monday);
    if (report.isEmpty) {
      return MonoSubPage(
        category: MonoCategory.recovery,
        icon: Icons.view_week_rounded,
        categoryLabel: l10n.weekTitle,
        backLabel: l10n.monoInsights,
        statement: l10n.weekEmpty,
        children: [MonoSurface(child: switcher)],
      );
    }
    String weekday(DateTime day) =>
        toBeginningOfSentenceCase(DateFormat.EEEE(l10n.localeName).format(day));
    DateTime day(int index) => DateTime(
      report.monday.year,
      report.monday.month,
      report.monday.day + index,
    );
    final score = report.score;
    final previous = report.previousScore;
    final steps = report.measure(WeekMeasure.steps);
    final links = linksOf(health, c.settings).take(3).toList();
    final statement = score != null && previous != null
        ? (score == previous
              ? l10n.weekSameAsLast
              : '${l10n.weekScore}: ${l10n.weekAgainstLast((score - previous).abs(), score > previous ? 'more' : 'less')}')
        : l10n.weekTitle;

    Widget delta(WeekComparison m, double? other, Trend trend) {
      if (other == null) return const SizedBox.shrink();
      final diff = m.value - other;
      return MonoDelta(
        trend == Trend.same
            ? '±0'
            : '${diff < 0 ? '−' : '+'}${_format(m.measure, formats, diff.abs())}',
        good: switch (trend) {
          Trend.better => true,
          Trend.worse => false,
          Trend.same || Trend.neutral => null,
        },
      );
    }

    Widget dot(GoalMark mark) {
      final (fill, border) = switch (mark) {
        GoalMark.reached => (t.solid, t.solid),
        GoalMark.missed => (Colors.transparent, t.ink3),
        GoalMark.open => (Colors.transparent, t.solid),
        GoalMark.none || GoalMark.ahead => (t.fill, Colors.transparent),
      };
      return Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: border, width: 1.5),
        ),
      );
    }

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

    final bestDay = report.bestDay;
    final bestNight = report.bestNight;
    final regularity = report.regularity;
    final energy = report.workoutEnergy;

    return MonoSubPage(
      category: MonoCategory.recovery,
      icon: Icons.view_week_rounded,
      categoryLabel: l10n.weekTitle,
      kicker: formats.dayRange(report.monday, report.sunday),
      backLabel: l10n.monoInsights,
      statement: statement,
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
                        color: t.recovery,
                      ),
                      child: Text(
                        score == null ? '–' : '$score',
                        style: MonoType.number(
                          t,
                          size: 28,
                        ).copyWith(color: t.bg),
                      ),
                    ),
                    const SizedBox(width: 18),
                  ],
                  Expanded(
                    child: MonoStat(
                      label: l10n.weekSteps,
                      value: steps == null
                          ? '–'
                          : formats.integer(steps.value.round()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              MonoBars(
                values: [for (final s in report.dayScores) s?.toDouble()],
                highlight: bestDay,
                semantics: l10n.weekScore,
                height: 70,
                radius: 6,
                gap: 8,
              ),
              MonoAxis(formats.weekdayShort),
              if (report.running) ...[
                const SizedBox(height: 10),
                Text(l10n.weekRunning, style: MonoType.time(t)),
              ],
            ],
          ),
        ),
        if (report.measures.isNotEmpty)
          MonoBlock(
            title: l10n.weekCompareTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MonoList(
                  children: [
                    Row(
                      children: [
                        const Spacer(),
                        for (final head in [
                          l10n.weekHeadLast,
                          l10n.weekHeadUsual,
                        ])
                          SizedBox(
                            width: 80,
                            child: Text(
                              head,
                              textAlign: TextAlign.end,
                              style: MonoType.label(t),
                            ),
                          ),
                      ],
                    ),
                    for (final m in report.measures)
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _label(m.measure, formats),
                                  style: MonoType.label(t),
                                ),
                                Text(
                                  _format(m.measure, formats, m.value),
                                  style: MonoType.inter(
                                    16,
                                    22,
                                    FontWeight.w600,
                                    t.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: delta(m, m.previous, m.againstPrevious),
                          ),
                          SizedBox(
                            width: 80,
                            child: delta(m, m.usual, m.againstUsual),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                MonoNote(l10n.weekScoreNote),
              ],
            ),
          ),
        if (bestDay != null || bestNight != null || report.records.isNotEmpty)
          MonoBlock(
            title: l10n.weekBestTitle,
            child: MonoList(
              children: [
                if (bestDay != null)
                  MonoRow(
                    title: l10n.weekBestDay,
                    subtitle:
                        '${weekday(day(bestDay))} · ${l10n.dayScore} '
                        '${report.dayScores[bestDay]}',
                    leading: const MonoScoreMark(
                      '',
                      icon: Icons.emoji_events_rounded,
                    ),
                    onTap: () => c.push(MonoDayPage(date: day(bestDay))),
                  ),
                if (bestNight != null)
                  MonoRow(
                    title: l10n.weekBestNight,
                    subtitle:
                        '${weekday(bestNight.date)} · ${l10n.scoreTitle} '
                        '${report.bestNightScore}',
                    leading: const MonoScoreMark(
                      '',
                      icon: Icons.bedtime_rounded,
                    ),
                    onTap: () => c.push(MonoNightPage(date: bestNight.date)),
                  ),
                for (final record in report.records)
                  MonoRow(
                    title:
                        '${l10n.personalBest} · '
                        '${record.measure.metric!.title(l10n)}',
                    subtitle:
                        '${weekday(record.day)} · '
                        '${record.measure.metric!.formatWithUnit(formats, record.value)}',
                    leading: const MonoScoreMark('', icon: Icons.star_rounded),
                    onTap: () => c.push(MonoDayPage(date: record.day)),
                  ),
              ],
            ),
          ),
        if (report.goals.isNotEmpty)
          MonoBlock(
            title: l10n.goals,
            child: MonoList(
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
                              style: MonoType.body(t),
                            ),
                            Text(
                              [
                                status(goal),
                                if (goal.streak > 1 && !goal.row.goal.weekly)
                                  l10n.streakDays(goal.streak),
                              ].join(' · '),
                              style: MonoType.label(t),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 4,
                        children: [
                          for (final mark in goal.row.marks) dot(mark),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        MonoBlock(
          title: l10n.weekWorkoutsTitle,
          child: report.workouts.isEmpty
              ? MonoSurface(
                  child: Text(l10n.weekNoWorkouts, style: MonoType.sub(t)),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MonoList(
                      children: [
                        for (final workout in report.workouts)
                          monoWorkoutRow(c, workout),
                      ],
                    ),
                    const SizedBox(height: 10),
                    MonoNote(
                      [
                        l10n.activitiesCount(report.workouts.length),
                        formats.duration(report.workoutMinutes),
                        if (energy > 0) '${formats.integer(energy)} kcal',
                      ].join(' · '),
                    ),
                  ],
                ),
        ),
        if (report.nights.isNotEmpty)
          MonoBlock(
            title: l10n.weekSleepTitle,
            trailing: Text(
              l10n.nightsCount(report.nights.length),
              style: MonoType.label(t),
            ),
            child: MonoList(
              children: [
                MonoPair(
                  label: l10n.sleepDebt,
                  value: formats.duration(report.debt.minutes),
                ),
                if (regularity != null) ...[
                  MonoPair(
                    label: l10n.weekBedtime,
                    value: l10n.weekSpread(
                      formatClock(regularity.bedtimeMinute),
                      regularity.bedtimeSpread,
                    ),
                  ),
                  MonoPair(
                    label: l10n.weekWake,
                    value: l10n.weekSpread(
                      formatClock(regularity.wakeMinute),
                      regularity.wakeSpread,
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (links.isNotEmpty)
          MonoBlock(
            title: l10n.linksTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final link in links)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: MonoSurface(child: LinkCard(link: link)),
                  ),
              ],
            ),
          ),
        MonoSurface(
          onTap: () => c.push(const MonoLinksPage()),
          child: MonoRow(
            title: l10n.linksAll,
            leading: Icon(Icons.link_rounded, color: t.ink),
          ),
        ),
      ],
    );
  }

  static String _label(WeekMeasure m, Formats formats) => switch (m) {
    WeekMeasure.steps => formats.l10n.weekSteps,
    WeekMeasure.activeEnergy => formats.l10n.weekEnergy,
    WeekMeasure.asleep => formats.l10n.weekAsleep,
    WeekMeasure.sleepScore => formats.l10n.scoreTitle,
    WeekMeasure.recovery => formats.l10n.recovery,
    WeekMeasure.restingPulse => Metric.restingHeartRate.title(formats.l10n),
  };

  static String _format(WeekMeasure m, Formats formats, double value) =>
      switch (m) {
        WeekMeasure.asleep => formats.duration(value.round()),
        WeekMeasure.restingPulse => Metric.restingHeartRate.formatWithUnit(
          formats,
          value,
        ),
        _ => formats.integer(value.round()),
      };
}
