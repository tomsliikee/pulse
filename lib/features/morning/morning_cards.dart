import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/formatters.dart';
import '../../data/day_insights.dart';
import '../../data/goals.dart';
import '../../data/metric_catalog.dart';
import '../../data/morning.dart';
import '../../data/night_insights.dart';
import '../../data/recovery.dart';
import '../../data/weather.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_type.dart';
import '../../theme/page_accent.dart';
import '../../widgets/animated_count.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/morphing_shape.dart';
import '../../widgets/number_grid.dart';
import '../../widgets/page_header.dart';
import '../../widgets/segment_group.dart';
import '../../widgets/shape_badge.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/wavy_bar.dart';
import '../detail/metric_spec.dart';
import '../goals/goal_format.dart';
import '../sleep/night_format.dart';
import '../today/day_detail_page.dart';
import 'morning_format.dart';
import 'morning_scene.dart';

/// The size of the shape a card's main number stands on.
const double _markSize = 116;

/// One card of the morning: scrolls by itself where a small phone has not
/// the room, under a free title.
class MorningCard extends StatelessWidget {
  const MorningCard({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title case final title?)
          SectionTitle(title, padding: const EdgeInsets.fromLTRB(4, 8, 4, 16)),
        ...children,
      ],
    ),
  );
}

/// A sentence with an icon on a shape, as one surface.
class _Sentence extends StatelessWidget {
  const _Sentence({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final accent = PageAccent.colorsOf(context);
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// A quiet line under what a card shows.
class _Aside extends StatelessWidget {
  const _Aside(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
      child: Text(
        text,
        style: AppType.of(context).aside(
          theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// A shape with the card's main number, and what it means beside it.
class _Lead extends StatelessWidget {
  const _Lead({
    required this.shape,
    required this.color,
    required this.mark,
    required this.headline,
    required this.caption,
  });

  final Shapes shape;
  final Color color;
  final Widget mark;
  final String headline;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = AppType.of(context);
    return Row(
      children: [
        MorphingShape(shape: shape, color: color, size: _markSize, child: mark),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text(
                headline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: type.title(context.emphasizedTextTheme.headlineSmall),
              ),
              Text(
                caption,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: type.label(
                  theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The greeting over the morning's scene, with what the day is good for.
class GreetingCard extends StatelessWidget {
  const GreetingCard({
    super.key,
    required this.name,
    required this.today,
    required this.effort,
    required this.weather,
    required this.hasPlace,
  });

  final String? name;
  final DateTime today;
  final DayEffort? effort;
  final Weather? weather;
  final bool hasPlace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final type = AppType.of(context);
    return MorningCard(
      children: [
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: MorningScene(sky: weather?.sky, height: 200),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 4),
          child: Text(
            morningGreeting(l10n, name),
            style: type.title(context.emphasizedTextTheme.displaySmall),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
          child: Text(
            formats.longDate(today),
            style: type.label(
              theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        if (effort case final effort?) ...[
          _Sentence(icon: effort.icon, text: effort.sentence(l10n)),
          const SizedBox(height: 8),
        ],
        if (weather case final weather?)
          _Sentence(
            icon: weather.sky.icon,
            text:
                '${degrees(l10n, weather.temperature)} · '
                '${weather.sky.label(l10n)} · '
                '${degrees(l10n, weather.high)} / '
                '${degrees(l10n, weather.low)}',
          )
        else if (!hasPlace)
          _Aside(l10n.weatherNoPlace),
      ],
    );
  }
}

/// Last night: its score, how long and when, and the stages.
class SleepCard extends StatelessWidget {
  const SleepCard({super.key, required this.insights});

  /// Null while the night has not arrived from the watch.
  final NightInsights? insights;

  @override
  Widget build(BuildContext context) {
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final insights = this.insights;
    return PageAccent.sleep(
      child: Builder(
        builder: (context) {
          if (insights == null) {
            return MorningCard(
              title: l10n.lastNight,
              children: [
                _Sentence(
                  icon: Icons.bedtime_outlined,
                  text: '${l10n.morningNoNight}. ${l10n.morningNoNightBody}',
                ),
              ],
            );
          }
          final night = insights.night;
          final accent = PageAccent.colorsOf(context);
          final score = insights.score.total;
          return MorningCard(
            title: l10n.lastNight,
            children: [
              _Lead(
                shape: AppShapes.of(ShapeFamily.sleep, score),
                color: accent.accent,
                mark: AnimatedCount(
                  value: score,
                  style: AppType.of(context).hero(
                    context.emphasizedTextTheme.headlineMedium?.copyWith(
                      color: accent.onAccent,
                      height: 1,
                    ),
                  ),
                ),
                headline: formats.duration(night.asleepMinutes),
                caption: l10n.asleepFromTo(
                  formatClock(night.bedtimeMinute),
                  formatClock(night.wakeMinute),
                ),
              ),
              const SizedBox(height: 20),
              if (night.hasStages) ...[
                NumberGrid(
                  cells: [
                    for (final measure in const [
                      NightMeasure.deep,
                      NightMeasure.rem,
                      NightMeasure.light,
                      NightMeasure.awake,
                    ])
                      NumberCell(
                        label: measure.label(l10n),
                        value: Text(
                          formats.duration(night.minutesIn(measure.stage!)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              _Sentence(
                icon: Icons.nights_stay_rounded,
                text: nightHeadline(formats, insights),
              ),
              _Aside(l10n.scoreNote),
            ],
          );
        },
      ),
    );
  }
}

/// How rested the day starts, and the readings of the night that stand out.
class RecoveryCard extends StatelessWidget {
  const RecoveryCard({
    super.key,
    required this.recovery,
    required this.deviations,
  });

  final Recovery recovery;
  final List<VitalDeviation> deviations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final type = AppType.of(context);
    final total = recovery.total;
    final zone = recoveryColors(scheme, recovery.zone);
    final style = type.hero(
      context.emphasizedTextTheme.headlineMedium?.copyWith(
        color: zone.onFill,
        height: 1,
      ),
    );
    return MorningCard(
      title: l10n.recovery,
      children: [
        if (total != null)
          _Lead(
            shape: AppShapes.of(ShapeFamily.day, total),
            color: zone.fill,
            mark: AnimatedCount(
              value: total,
              style: style,
              format: (value) => '$value%',
            ),
            headline: l10n.recovery,
            caption: switch (recovery.zone!) {
              RecoveryZone.green => l10n.recoveryGreen,
              RecoveryZone.yellow => l10n.recoveryYellow,
              RecoveryZone.red => l10n.recoveryRed,
            },
          ),
        TitledSection(
          title: l10n.morningVitals,
          note: l10n.morningVitalsNote,
          child: deviations.isEmpty
              ? _Sentence(
                  icon: Icons.check_rounded,
                  text: l10n.morningVitalsFine,
                )
              : SegmentGroup(
                  children: [
                    for (final deviation in deviations)
                      Row(
                        children: [
                          Icon(
                            deviation.above
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  deviation.above
                                      ? l10n.morningVitalAbove(
                                          deviation.metric.title(l10n),
                                        )
                                      : l10n.morningVitalBelow(
                                          deviation.metric.title(l10n),
                                        ),
                                  style: type.strong(
                                    theme.textTheme.titleSmall,
                                  ),
                                ),
                                Text(
                                  l10n.recoveryUsual(
                                    deviation.metric.formatWithUnit(
                                      formats,
                                      deviation.value,
                                    ),
                                    deviation.metric.format(
                                      formats,
                                      deviation.usual,
                                    ),
                                  ),
                                  style: type.label(
                                    theme.textTheme.labelLarge?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
        ),
        if (recovery.parts.isNotEmpty) RecoveryParts(recovery: recovery),
      ],
    );
  }
}

/// The weather of the day: now, the span, the rain and every other hour.
class WeatherCard extends StatelessWidget {
  const WeatherCard({super.key, required this.weather, required this.now});

  /// Null when the service could not be reached.
  final Weather? weather;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = Formats.of(context).l10n;
    final type = AppType.of(context);
    final weather = this.weather;
    if (weather == null) {
      return MorningCard(
        title: l10n.weather,
        children: [
          _Sentence(
            icon: Icons.cloud_off_rounded,
            text: l10n.weatherUnavailable,
          ),
        ],
      );
    }
    final accent = PageAccent.colorsOf(context);
    // Every other hour: twelve bars fit a narrow phone with their labels.
    final hours = [
      for (final hour in weather.hours)
        if (hour.hour.isEven) hour,
    ];
    final coldest = hours.isEmpty
        ? weather.low
        : hours.map((hour) => hour.temperature).reduce((a, b) => a < b ? a : b);
    return MorningCard(
      title: l10n.weather,
      children: [
        _Lead(
          shape: Shapes.sunny,
          color: accent.container,
          mark: Icon(weather.sky.icon, size: 48, color: accent.onContainer),
          headline: degrees(l10n, weather.temperature),
          caption: '${weather.sky.label(l10n)} · ${weather.place.name}',
        ),
        const SizedBox(height: 20),
        NumberGrid(
          cells: [
            NumberCell(
              label: l10n.weatherRainChance,
              value: Text(l10n.weatherPercent('${weather.rainChance}')),
            ),
            NumberCell(
              label: l10n.highest,
              value: Text(degrees(l10n, weather.high)),
            ),
            NumberCell(
              label: l10n.lowest,
              value: Text(degrees(l10n, weather.low)),
            ),
          ],
        ),
        if (hours.length > 1) ...[
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                BarChart(
                  values: [for (final hour in hours) hour.temperature],
                  labels: [for (final hour in hours) '${hour.hour}'],
                  selectedIndex: hours.indexWhere(
                    (hour) => hour.hour == now.hour - now.hour % 2,
                  ),
                  color: accent.container,
                  selectedColor: accent.accent,
                  // Bars of a cold day still stand on something.
                  baseline: coldest - 3,
                  goal: coldest - 2,
                  height: 132,
                ),
                // The chance of rain of the same hours, as a quiet line.
                Row(
                  children: [
                    for (final hour in hours)
                      Expanded(
                        child: Text(
                          hour.rainChance >= 10 ? '${hour.rainChance}' : '',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.tertiary,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  '${l10n.weatherRainChance} (%)',
                  style: type.label(
                    theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        _Aside(l10n.weatherSource),
      ],
    );
  }
}

/// The goals as they stand this morning, and what yesterday came to.
class MorningGoalsCard extends StatelessWidget {
  const MorningGoalsCard({
    super.key,
    required this.goals,
    required this.targetOf,
    required this.data,
    required this.today,
    required this.yesterday,
  });

  final List<Goal> goals;
  final double Function(Goal goal) targetOf;
  final GoalData data;
  final DateTime today;
  final DayInsights yesterday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final type = AppType.of(context);
    final muted = type.label(
      theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
    );
    final score = yesterday.score.total;
    final steps = yesterday.measure(DayMeasure.steps)?.value;
    final energy = yesterday.measure(DayMeasure.activeEnergy)?.value;
    final cells = [
      if (score != null)
        NumberCell(label: l10n.dayScore, value: Text('$score')),
      if (steps != null)
        NumberCell(
          label: Metric.steps.title(l10n),
          value: Text(Metric.steps.format(formats, steps)),
        ),
      if (energy != null)
        NumberCell(
          label: Metric.activeEnergy.title(l10n),
          value: Text(Metric.activeEnergy.formatWithUnit(formats, energy)),
        ),
      if (yesterday.workouts.isNotEmpty)
        NumberCell(
          label: l10n.groupWorkout,
          value: Text(formats.integer(yesterday.workouts.length)),
        ),
    ];
    return MorningCard(
      title: l10n.goals,
      children: [
        if (goals.isEmpty)
          _Sentence(icon: Icons.flag_outlined, text: l10n.goalsNone)
        else
          SegmentGroup(
            children: [
              for (final goal in goals)
                Builder(
                  builder: (context) {
                    final progress = goalProgress(
                      goal,
                      targetOf(goal),
                      today,
                      data,
                    );
                    // Yesterday's: today's has hardly begun.
                    final streak = goalStreak(
                      goal,
                      targetOf(goal),
                      today,
                      data,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                goal.label(l10n),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: type.strong(theme.textTheme.titleSmall),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              streak > 1
                                  ? (goal.weekly
                                        ? l10n.goalStreakWeeks(streak)
                                        : l10n.goalStreakDays(streak))
                                  : goal.formatProgress(formats, progress),
                              style: muted,
                            ),
                          ],
                        ),
                        WavyBar(value: progress.share),
                      ],
                    );
                  },
                ),
            ],
          ),
        if (cells.isNotEmpty)
          TitledSection(
            title: l10n.periodYesterday,
            child: NumberGrid(cells: cells),
          ),
      ],
    );
  }
}

/// When to go to bed tonight.
class TonightCard extends StatelessWidget {
  const TonightCard({super.key, required this.plan, required this.goalHours});

  final Tonight plan;
  final double goalHours;

  @override
  Widget build(BuildContext context) {
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    return PageAccent.sleep(
      child: Builder(
        builder: (context) {
          final accent = PageAccent.colorsOf(context);
          return MorningCard(
            title: l10n.tonightTitle,
            children: [
              _Lead(
                shape: Shapes.l4LeafClover,
                color: accent.container,
                mark: Icon(
                  Icons.bedtime_rounded,
                  size: 48,
                  color: accent.onContainer,
                ),
                headline: l10n.tonightBedtime(formatClock(plan.bedtimeMinute)),
                caption: l10n.tonightWhy(
                  formats.duration((goalHours * 60).round()),
                  formatClock(plan.wakeMinute),
                ),
              ),
              if (plan.catchUpMinutes > 0) ...[
                const SizedBox(height: 20),
                _Sentence(
                  icon: Icons.hourglass_bottom_rounded,
                  text: l10n.tonightCatchUp(plan.catchUpMinutes),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
