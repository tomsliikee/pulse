import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/container_route.dart';
import '../../app/formatters.dart';
import '../../app/layout.dart';
import '../../data/day_insights.dart';
import '../../data/goals.dart';
import '../../data/health_controller.dart';
import '../../data/metric_catalog.dart';
import '../../theme/app_shapes.dart';
import '../../widgets/entrance.dart';
import '../../widgets/animated_count.dart';
import '../../widgets/pressable.dart';
import '../../widgets/shape_badge.dart';
import '../../widgets/progress_ring.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/tile_surface.dart';
import '../age/body_age_page.dart';
import '../../widgets/wavy_bar.dart';
import '../detail/metric_spec.dart';
import '../goals/goal_format.dart';
import '../goals/goals_page.dart';
import 'day_detail_page.dart';
import 'day_format.dart';
import 'day_list_page.dart';
import 'day_scene.dart';

/// Opens the page about [day], growing it out of the rectangle [origin] of
/// what was tapped.
void openDay(BuildContext context, DateTime day, Rect origin) {
  Navigator.of(context).push(
    ContainerRoute<void>(
      origin: origin,
      originColor: Theme.of(context).colorScheme.surfaceBright,
      builder: (_) => DayDetailPage(date: day),
    ),
  );
}

/// The scene of the day [insights] is about: up to now for today, to the
/// evening for a day that is over.
DayScene daySceneOf(
  HealthController health,
  DayInsights insights, {
  required double height,
}) {
  final today = insights.day == health.today;
  final now = health.now;
  final index = health.snapshot.indexOf(insights.day);
  return DayScene(
    untilMinute: today ? now.hour * 60 + now.minute : 22 * 60,
    score: insights.score.total ?? 50,
    hours: index == null ? null : health.snapshot.hoursOf(Metric.steps, index),
    steps: insights.measure(DayMeasure.steps)?.value ?? 0,
    wakeMinute: insights.night?.wakeMinute,
    workouts: insights.workouts,
    height: height,
  );
}

/// Today: its sky and the figure, the score so far, steps and active
/// calories as two rings around the body age, and how the day stands
/// against yesterday at this time. The age opens its own page; a tap
/// anywhere else opens the page about the day.
class DayCard extends StatelessWidget {
  const DayCard({super.key});

  static const double sceneHeight = 120;
  static const double height = sceneHeight + 252;

  static const double _rings = 152;

  // The board holds this tile as a constant, so it listens for itself.
  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.health, scope.settings]),
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final scope = AppScope.of(context);
    final health = scope.health;
    final settings = scope.settings;
    final insights = dayInsightsOf(health, settings, health.today);
    final steps = insights.measure(DayMeasure.steps)?.value;
    final energy = insights.measure(DayMeasure.activeEnergy)?.value;
    final distance = insights.measure(DayMeasure.distance)?.value;
    final score = insights.score.total;
    final muted = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Pressable(
      pressedScale: 0.98,
      child: TileSurface(
        color: scheme.surfaceBright,
        radius: AppRadii.extraLargeIncreased,
        child: Builder(
          builder: (context) => InkWell(
            onTap: () {
              final origin = globalRectOf(context);
              if (origin != null) openDay(context, health.today, origin);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                daySceneOf(health, insights, height: sceneHeight),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SizedBox.square(
                              dimension: _rings,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  _TurningShape(
                                    size: _rings,
                                    color: scheme.primary.withValues(
                                      alpha: 0.10,
                                    ),
                                  ),
                                  SizedBox.square(
                                    dimension: 132,
                                    child: ProgressRing(
                                      value: (steps ?? 0) / settings.stepGoal,
                                      color: scheme.primary,
                                      trackColor: scheme.primary.withValues(
                                        alpha: 0.16,
                                      ),
                                      strokeWidth: 12,
                                    ),
                                  ),
                                  SizedBox.square(
                                    dimension: 102,
                                    child: ProgressRing(
                                      value:
                                          (energy ?? 0) /
                                          settings.activeEnergyGoal,
                                      color: scheme.tertiary,
                                      trackColor: scheme.tertiary.withValues(
                                        alpha: 0.16,
                                      ),
                                      strokeWidth: 10,
                                    ),
                                  ),
                                  _AgeButton(
                                    age: bodyAgeOf(health, settings)?.age,
                                    hasBirthDate: settings.birthDate != null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      if (score == null)
                                        Text(
                                          '–',
                                          style: context
                                              .emphasizedTextTheme
                                              .displaySmall
                                              ?.copyWith(height: 1),
                                        )
                                      else
                                        AnimatedCount(
                                          value: score,
                                          style: context
                                              .emphasizedTextTheme
                                              .displaySmall
                                              ?.copyWith(height: 1),
                                        ),
                                      const Spacer(),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                                  Text(
                                    l10n.dayScoreSoFar,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: muted,
                                  ),
                                  const SizedBox(height: 10),
                                  _Stat(
                                    metric: Metric.steps,
                                    value: steps,
                                    label: l10n.metricSteps,
                                    shape: Shapes.circle,
                                    color: scheme.primary,
                                  ),
                                  _Stat(
                                    metric: Metric.activeEnergy,
                                    value: energy,
                                    label: l10n.shortCalories,
                                    shape: Shapes.burst,
                                    color: scheme.tertiary,
                                  ),
                                  if (distance != null)
                                    _Stat(
                                      metric: Metric.distance,
                                      value: distance,
                                      label: l10n.kilometers,
                                      shape: Shapes.pentagon,
                                      color: scheme.outline,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          dayHeadline(
                            formats,
                            insights,
                            soFar: stepsSoFar(health.snapshot, health.now),
                          ),
                          // Two lines: on a narrow phone the sentence does not fit in one.
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.emphasizedTextTheme.titleSmall
                              ?.copyWith(color: scheme.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One number of the day beside the rings, marked with its ring's colour.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.metric,
    required this.value,
    required this.label,
    required this.shape,
    required this.color,
  });

  final Metric metric;

  /// Null where nothing was measured.
  final double? value;
  final String label;
  final Shapes shape;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formats = Formats.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          M3EShape(shape, width: 10, height: 10, color: color),
          const SizedBox(width: 8),
          if (value case final value?)
            AnimatedNumber(
              value: value,
              format: (current) => metric.format(formats, current),
              style: context.emphasizedTextTheme.titleMedium,
            )
          else
            Text('–', style: context.emphasizedTextTheme.titleMedium),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The body age in the middle of the rings, as a button of its own.
class _AgeButton extends StatelessWidget {
  const _AgeButton({required this.age, required this.hasBirthDate});

  final double? age;
  final bool hasBirthDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final age = this.age;
    void open() {
      final origin = globalRectOf(context);
      if (origin == null) return;
      Navigator.of(context).push(
        ContainerRoute<void>(
          origin: origin,
          originColor: scheme.surfaceBright,
          originRadius: AppRadii.extraExtraLarge,
          builder: (_) => const BodyAgePage(),
        ),
      );
    }

    return Semantics(
      container: true,
      button: true,
      label: age == null
          ? l10n.bodyAgeDetailsA11y
          : l10n.bodyAgeEstimateA11y(formats.decimal(age)),
      onTap: open,
      excludeSemantics: true,
      child: Pressable(
        pressedScale: 0.9,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: open,
          // The whole space inside the inner ring is the button.
          child: SizedBox.square(
            dimension: 80,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  age == null ? '–' : formats.decimal(age),
                  maxLines: 1,
                  style: context.emphasizedTextTheme.headlineSmall,
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    hasBirthDate ? l10n.bodyAge : l10n.setAge,
                    maxLines: 1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The cookie behind the rings. It turns slowly, and stands still when the
/// system asks for no animations.
class _TurningShape extends StatefulWidget {
  const _TurningShape({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  State<_TurningShape> createState() => _TurningShapeState();
}

class _TurningShapeState extends State<_TurningShape>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 90),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _turn.stop();
    } else if (!_turn.isAnimating) {
      _turn.repeat();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Its own layer, so the rings and the numbers are not painted again.
    return RepaintBoundary(
      child: RotationTransition(
        turns: _turn,
        child: M3EShape(
          Shapes.c12SidedCookie,
          width: widget.size,
          height: widget.size,
          color: widget.color,
        ),
      ),
    );
  }
}

/// The goals the user follows, each as a wavy line towards its target.
/// Tapping it opens the page of all goals.
class GoalsCard extends StatelessWidget {
  const GoalsCard({super.key});

  static const double _rowHeight = 38;
  static const double _gap = 14;

  /// The height with [goals] rows; without any it holds a note.
  static double heightFor(int goals) =>
      goals == 0 ? 132 : 84 + goals * _rowHeight + (goals - 1) * _gap;

  // The board holds this tile as a constant, so it listens for itself.
  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.health, scope.settings]),
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final scope = AppScope.of(context);
    final health = scope.health;
    final settings = scope.settings;
    final data = goalDataOf(health, settings);
    final goals = settings.goals;
    return Pressable(
      pressedScale: 0.98,
      child: TileSurface(
        color: scheme.surfaceBright,
        radius: AppRadii.extraLargeIncreased,
        child: Builder(
          builder: (context) => InkWell(
            onTap: () {
              final origin = globalRectOf(context);
              if (origin == null) return;
              Navigator.of(context).push(
                ContainerRoute<void>(
                  origin: origin,
                  originColor: scheme.surfaceBright,
                  builder: (_) => const GoalsPage(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.goals,
                          style: context.emphasizedTextTheme.titleMedium,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (goals.isEmpty)
                    Text(
                      l10n.goalsNone,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  for (final (index, goal) in goals.indexed) ...[
                    if (index > 0) const SizedBox(height: _gap),
                    SizedBox(
                      height: _rowHeight,
                      child: _Goal(
                        progress: goalProgress(
                          goal,
                          settings.goalTarget(goal),
                          health.today,
                          data,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Goal extends StatelessWidget {
  const _Goal({required this.progress});

  final GoalProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final goal = progress.goal;
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                goal.label(l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              goal.formatProgress(formats, progress),
              maxLines: 1,
              style: theme.textTheme.labelLarge?.copyWith(
                color: progress.reached
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        WavyBar(value: progress.share),
      ],
    );
  }
}

/// Up to three hints for today.
class DayTipsCard extends StatelessWidget {
  const DayTipsCard({super.key, required this.tips});

  final List<DayTip> tips;

  /// A hint has room for two lines.
  static const double _tipHeight = 40;
  static const double _gap = 12;

  static double heightFor(int tips) =>
      80 + tips * _tipHeight + (tips - 1) * _gap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formats.l10n.dayTipsTitle,
            style: context.emphasizedTextTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          for (final (index, tip) in tips.indexed) ...[
            if (index > 0) const SizedBox(height: _gap),
            SizedBox(
              height: _tipHeight,
              child: Row(
                children: [
                  ShapeBadge(
                    shape: Shapes.softBurst,
                    icon: Icons.lightbulb_outline_rounded,
                    size: 32,
                    color: scheme.tertiaryContainer,
                    iconColor: scheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      dayTip(formats, tip),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A few days as rows, and the way to all of them.
class DaysCard extends StatelessWidget {
  const DaysCard({super.key, required this.days, required this.total});

  /// Newest first.
  final List<DateTime> days;

  /// How many days there are altogether.
  final int total;

  static const double rowHeight = 64;

  static double heightFor(int rows) => 76 + (rows + 1) * rowHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = Formats.of(context).l10n;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              l10n.moreDays,
              style: context.emphasizedTextTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 12),
          for (final (index, day) in days.indexed)
            SizedBox(
              height: rowHeight,
              child: Entrance(
                order: index + 1,
                child: DayRow(day: day),
              ),
            ),
          SizedBox(
            height: rowHeight,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DayListPage()),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.allDays,
                        style: context.emphasizedTextTheme.titleSmall?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    Text(
                      l10n.daysTotal(total),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One day in a list: its score, date, steps and sleep. Tapping it opens
/// the page about it.
class DayRow extends StatelessWidget {
  const DayRow({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final scope = AppScope.of(context);
    final health = scope.health;
    final goals = dayGoalsOf(scope.settings);
    final score = dayScore(
      day: day,
      valueOf: health.valueOn,
      nights: health.nights,
      goals: goals,
    ).total;
    final steps = health.valueOn(Metric.steps, day);
    final night = nightOn(health.nights, day);
    final stepsText = Metric.steps.format(formats, steps);
    return InkWell(
      onTap: () {
        final origin = globalRectOf(context);
        if (origin != null) openDay(context, day, origin);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            M3EContainer(
              AppShapes.ofScore(score),
              width: 44,
              height: 44,
              color: scheme.secondaryContainer,
              child: Text(
                score == null ? '–' : '$score',
                style: context.emphasizedTextTheme.titleSmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formats.shortDate(day),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    night == null
                        ? l10n.dayStepsOnly(stepsText)
                        : l10n.dayStepsAndSleep(
                            stepsText,
                            formats.duration(night.asleepMinutes),
                          ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if ((steps ?? 0) >= goals.steps) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: scheme.primary,
                semanticLabel: l10n.goalReached,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
