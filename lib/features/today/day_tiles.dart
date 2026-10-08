import 'package:flutter/foundation.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../../app/app_scope.dart';
import '../../app/container_route.dart';
import '../../app/formatters.dart';
import '../../app/layout.dart';
import '../../data/day_insights.dart';
import '../../data/goals.dart';
import '../../data/health_controller.dart';
import '../../data/metric_catalog.dart';
import '../../data/settings_controller.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_type.dart';
import '../../theme/page_accent.dart';
import '../../widgets/board_page.dart';
import '../../widgets/chip_carousel.dart';
import '../../widgets/segment_group.dart';
import '../../widgets/animated_count.dart';
import '../../widgets/pressable.dart';
import '../../widgets/shape_badge.dart';
import '../../widgets/page_header.dart';
import '../../widgets/progress_ring.dart';
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
import 'day_scores.dart';

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
  int? untilMinute,
  double? stage,
  bool figure = true,
}) {
  final today = insights.day == health.today;
  final now = health.now;
  final index = health.snapshot.indexOf(insights.day);
  return DayScene(
    untilMinute: untilMinute ?? (today ? now.hour * 60 + now.minute : 22 * 60),
    score: insights.score.total ?? 50,
    hours: index == null ? null : health.snapshot.hoursOf(Metric.steps, index),
    steps: insights.measure(DayMeasure.steps)?.value ?? 0,
    height: height,
    stage: stage,
    figure: figure,
  );
}

/// Whether the tile of the day gives its scene to the page, which draws it
/// from edge to edge behind the title.
bool dayHeroBleeds(BuildContext context, List<String> shown) =>
    BoardBackdrop.wanted(
      context,
      pageId: 'today',
      heroId: dayTileId,
      shown: shown,
      inPlace: const {dayTileId, tipsTileId, nightTileId, goalsTileId},
    );

/// The scene of today from edge to edge, as the backdrop of the page. It is
/// [extent] high and fades into the page where it ends.
class DayBackdrop extends StatelessWidget {
  const DayBackdrop({super.key, required this.extent});

  final double extent;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    final insights = dayInsightsOf(health, scope.settings, health.today);
    return FadingBackdrop(
      child: daySceneOf(
        health,
        insights,
        height: extent,
        stage: DayCard.sceneHeight + 24,
      ),
    );
  }
}

/// Today. Its sky and the figure are the one container of the page; the
/// score so far sits on a shape that hangs over the scene's edge, and below
/// it steps and active calories stand free, as two rings around the body
/// age and as numbers. The age opens its own page; a tap anywhere else
/// opens the page about the day.
class DayCard extends StatelessWidget {
  const DayCard({super.key});

  static const double sceneHeight = 132;
  static const double height = sceneHeight + 304 + DayScores.captionHeight;

  static const double _rings = 168;

  /// The shape of the score, and how far it hangs over the scene.
  static const double _shape = 104;
  static const double _overlap = 48;

  // The board holds this tile as a constant, so it listens for itself.
  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return _OnReturn(
      builder: (context, round) => ListenableBuilder(
        listenable: Listenable.merge([scope.health, scope.settings]),
        builder: (context, _) => _build(context, round),
      ),
    );
  }

  /// [round] counts how often the page came back into view: the rings and
  /// the bars fill again with every one.
  Widget _build(BuildContext context, int round) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final scope = AppScope.of(context);
    final health = scope.health;
    final settings = scope.settings;
    final type = AppType.of(context);
    final insights = dayInsightsOf(health, settings, health.today);
    final steps = insights.measure(DayMeasure.steps)?.value;
    final energy = insights.measure(DayMeasure.activeEnergy)?.value;
    // The page draws the scene itself, behind the title.
    final bleeds = BoardBackdrop.isShown(context);
    // The hours of today that have begun; null without hourly values.
    List<double?>? hoursUntilNow(Metric metric) => health.snapshot
        .hoursOf(metric, health.todayIndex)
        ?.sublist(0, health.now.hour + 1);
    final scoreStyle = type.hero(
      context.emphasizedTextTheme.headlineMedium?.copyWith(height: 1),
    );

    return Pressable(
      pressedScale: 0.98,
      child: Material(
        type: MaterialType.transparency,
        child: Builder(
          builder: (context) => InkWell(
            borderRadius: BorderRadius.circular(AppRadii.extraLargeIncreased),
            onTap: () {
              final origin = globalRectOf(context);
              if (origin != null) openDay(context, health.today, origin);
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (bleeds)
                      const SizedBox(height: sceneHeight)
                    else
                      TileSurface(
                        color: scheme.surfaceBright,
                        radius: AppRadii.extraLargeIncreased,
                        child: daySceneOf(
                          health,
                          insights,
                          height: sceneHeight,
                        ),
                      ),
                    // Room for the shapes that hang over the scene's edge,
                    // and for what is written below them.
                    SizedBox(
                      height: _shape - _overlap + DayScores.captionHeight,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          SizedBox.square(
                            dimension: _rings,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                ProgressRing(
                                  key: ValueKey(('steps', round)),
                                  value: (steps ?? 0) / settings.stepGoal,
                                  color: scheme.primary,
                                  trackColor: scheme.primary.withValues(
                                    alpha: 0.16,
                                  ),
                                  strokeWidth: 15,
                                ),
                                SizedBox.square(
                                  dimension: 124,
                                  child: ProgressRing(
                                    key: ValueKey(('energy', round)),
                                    value:
                                        (energy ?? 0) /
                                        settings.activeEnergyGoal,
                                    color: scheme.tertiary,
                                    trackColor: scheme.tertiary.withValues(
                                      alpha: 0.16,
                                    ),
                                    strokeWidth: 13,
                                  ),
                                ),
                                _AgeButton(
                                  age: bodyAgeOf(health, settings)?.age,
                                  hasBirthDate: settings.birthDate != null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 12,
                              children: [
                                _Stat(
                                  metric: Metric.steps,
                                  value: steps,
                                  hours: hoursUntilNow(Metric.steps),
                                  round: round,
                                  label: l10n.stepsOfGoal(
                                    formats.integer(settings.stepGoal),
                                  ),
                                  shape: Shapes.circle,
                                  color: scheme.primary,
                                ),
                                _Stat(
                                  metric: Metric.activeEnergy,
                                  value: energy,
                                  hours: hoursUntilNow(Metric.activeEnergy),
                                  round: round,
                                  label: l10n.ofGoal(
                                    formats.integer(settings.activeEnergyGoal),
                                    Metric.activeEnergy.unit,
                                  ),
                                  shape: Shapes.burst,
                                  color: scheme.tertiary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                      child: Text(
                        dayHeadline(
                          formats,
                          insights,
                          soFar: stepsSoFar(health.snapshot, health.now),
                        ),
                        // Two lines: on a narrow phone the sentence does not fit in one.
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: type.strong(
                          context.emphasizedTextTheme.titleSmall?.copyWith(
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: sceneHeight - _overlap,
                  child: DayScores(
                    insights: insights,
                    withDay: showsDayScore(health.today, health.now),
                    size: _shape,
                    style: scoreStyle,
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

/// One number of the day beside the rings: the number, what it is aiming
/// at, and below, hour by hour, when it came together. How far it has come
/// is its ring's to say.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.metric,
    required this.value,
    required this.hours,
    required this.round,
    required this.label,
    required this.shape,
    required this.color,
  });

  final Metric metric;

  /// Null where nothing was measured.
  final double? value;

  /// The hours of today so far; null without hourly values.
  final List<double?>? hours;

  /// A new round lets the bars grow again.
  final int round;

  /// What the number is aiming at, in words.
  final String label;
  final Shapes shape;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formats = Formats.of(context);
    final type = AppType.of(context);
    final figure = type.hero(
      context.emphasizedTextTheme.headlineMedium?.copyWith(height: 1.05),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            M3EShape(shape, width: 10, height: 10, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: value == null
                    ? Text('–', style: figure)
                    : AnimatedNumber(
                        value: value!,
                        format: (current) => metric.format(formats, current),
                        style: figure,
                      ),
              ),
            ),
          ],
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            maxLines: 1,
            style: type.label(
              theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        if (hours case final hours?) ...[
          const SizedBox(height: 6),
          HourBars(key: ValueKey(round), hours: hours, color: color),
        ],
      ],
    );
  }
}

/// The hours of a day as small bars, from midnight on the left to midnight
/// on the right: the last one given is the hour that is running. An hour
/// with nothing in it is a dot; the hours still to come are left empty.
/// The bars grow out of the line one after the other when they appear.
class HourBars extends StatelessWidget {
  const HourBars({super.key, required this.hours, required this.color});

  final List<double?> hours;
  final Color color;

  static const double height = 24;

  @override
  Widget build(BuildContext context) {
    return SingleMotionBuilder(
      from: MediaQuery.disableAnimationsOf(context) ? 1 : 0,
      value: 1,
      motion: AppMotion.effectsSlow,
      builder: (context, grown, _) => CustomPaint(
        size: const Size(double.infinity, height),
        painter: HourBarsPainter(
          hours: hours,
          color: color,
          grown: grown.clamp(0, 1).toDouble(),
        ),
      ),
    );
  }
}

/// Paints [HourBars].
@visibleForTesting
class HourBarsPainter extends CustomPainter {
  const HourBarsPainter({
    required this.hours,
    required this.color,
    required this.grown,
  });

  final List<double?> hours;
  final Color color;

  /// How far the bars have grown, from 0 to 1.
  final double grown;

  static const int _slots = 24;

  @override
  void paint(Canvas canvas, Size size) {
    var most = 0.0;
    for (final value in hours) {
      if (value != null && value > most) most = value;
    }
    final slot = size.width / _slots;
    final width = (slot * 0.62).clamp(2.0, 8.0);
    final dot = width / 2;
    for (var i = 0; i < hours.length && i < _slots; i++) {
      final value = hours[i] ?? 0;
      // Later hours start later, and all have arrived at the end.
      final own = ((grown * 1.5) - i / _slots * 0.5).clamp(0.0, 1.0);
      final share = most <= 0 ? 0.0 : value / most;
      final tall = width + (size.height - width) * share * own;
      final x = slot * i + (slot - width) / 2;
      final paint = Paint()
        ..color = color.withValues(
          alpha: value <= 0 ? 0.28 : (i == hours.length - 1 ? 1 : 0.62),
        );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          value <= 0
              ? Rect.fromLTWH(x, size.height - width, width, width)
              : Rect.fromLTWH(x, size.height - tall, width, tall),
          Radius.circular(dot),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(HourBarsPainter oldDelegate) =>
      oldDelegate.grown != grown ||
      oldDelegate.color != color ||
      !listEquals(oldDelegate.hours, hours);
}

/// Builds [builder] with a number that goes up by one every time the page
/// above this one is closed.
class _OnReturn extends StatefulWidget {
  const _OnReturn({required this.builder});

  final Widget Function(BuildContext context, int round) builder;

  @override
  State<_OnReturn> createState() => _OnReturnState();
}

class _OnReturnState extends State<_OnReturn> with RouteAware {
  int _round = 0;
  ModalRoute<void>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route) return;
    if (_route != null) appRouteObserver.unsubscribe(this);
    _route = route;
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  @override
  void didPopNext() => setState(() => _round++);

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _round);
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
    final figure = AppType.of(
      context,
    ).hero(context.emphasizedTextTheme.headlineSmall?.copyWith(height: 1.05));
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
            dimension: 76,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // As heavy as the two numbers beside the rings.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: age == null
                      ? Text('–', style: figure)
                      : AnimatedNumber(
                          value: age,
                          format: formats.decimal,
                          style: figure,
                        ),
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
    return _OnReturn(
      builder: (context, round) => ListenableBuilder(
        listenable: Listenable.merge([scope.health, scope.settings]),
        builder: (context, _) => _build(context, round),
      ),
    );
  }

  /// [round] counts how often the page came back into view: the rings and
  /// the bars fill again with every one.
  Widget _build(BuildContext context, int round) {
    final theme = Theme.of(context);
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final scope = AppScope.of(context);
    final health = scope.health;
    final settings = scope.settings;
    final data = goalDataOf(health, settings);
    final goals = settings.goals;
    final accent = PageAccent.colorsOf(context);
    return Pressable(
      pressedScale: 0.98,
      // The loud tile of the page.
      child: TileSurface(
        color: accent.container,
        radius: AppRadii.extraLargeIncreased,
        opaque: true,
        child: Builder(
          builder: (context) => InkWell(
            onTap: () {
              final origin = globalRectOf(context);
              if (origin == null) return;
              Navigator.of(context).push(
                ContainerRoute<void>(
                  origin: origin,
                  originColor: accent.container,
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
                          style: AppType.of(context).title(
                            context.emphasizedTextTheme.titleLarge?.copyWith(
                              color: accent.onContainer,
                            ),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: accent.onContainer,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (goals.isEmpty)
                    Text(
                      l10n.goalsNone,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: accent.onContainer,
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
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final type = AppType.of(context);
    final accent = PageAccent.colorsOf(context);
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
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: accent.onContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              goal.formatProgress(formats, progress),
              maxLines: 1,
              style: (progress.reached ? type.strong : type.label)(
                theme.textTheme.labelLarge?.copyWith(
                  color: accent.onContainer.withValues(
                    alpha: progress.reached ? 1 : 0.72,
                  ),
                ),
              ),
            ),
          ],
        ),
        WavyBar(
          value: progress.share,
          color: accent.accent,
          trackColor: accent.onContainer.withValues(alpha: 0.16),
        ),
      ],
    );
  }
}

/// Up to three hints for today, each a segment of its own.
class DayTipsCard extends StatelessWidget {
  const DayTipsCard({super.key, required this.tips});

  final List<DayTip> tips;

  /// A hint has room for two lines.
  static const double _tipHeight = 72;
  static const double _title = 48;

  static double heightFor(int tips) =>
      _title + tips * _tipHeight + (tips - 1) * SegmentGroup.gap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _title,
          child: SectionTitle(
            formats.l10n.dayTipsTitle,
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          ),
        ),
        SegmentGroup(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            for (final tip in tips)
              SizedBox(
                height: _tipHeight,
                child: Row(
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// A few days to swipe through, each a small card with its sky, and the way
/// to all of them at the end.
class DaysCard extends StatelessWidget {
  const DaysCard({super.key, required this.days, required this.total});

  /// Newest first.
  final List<DateTime> days;

  /// How many days there are altogether.
  final int total;

  static const double height = ChipCarousel.height;

  @override
  Widget build(BuildContext context) {
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final scope = AppScope.of(context);
    final health = scope.health;
    return ChipCarousel(
      title: l10n.moreDays,
      children: [
        for (final day in days)
          Builder(
            builder: (context) {
              final insights = dayInsightsOf(health, scope.settings, day);
              return CarouselChip(
                // A small picture, not a film: the sky of the day's
                // afternoon, standing still.
                picture: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: true),
                  child: daySceneOf(
                    health,
                    insights,
                    height: CarouselChip.pictureHeight,
                    untilMinute: 15 * 60,
                    figure: false,
                  ),
                ),
                mark: ScoreMark(score: insights.score.total),
                title: formats.shortDate(day),
                subtitle: l10n.dayStepsOnly(
                  Metric.steps.format(
                    formats,
                    insights.measure(DayMeasure.steps)?.value,
                  ),
                ),
                onTap: (origin) => openDay(context, day, origin),
              );
            },
          ),
        CarouselEndChip(
          title: l10n.allDays,
          subtitle: l10n.daysTotal(total),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const DayListPage())),
        ),
      ],
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
              AppShapes.of(ShapeFamily.day, score),
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
