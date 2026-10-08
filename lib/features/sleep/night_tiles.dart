import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/container_route.dart';
import '../../app/formatters.dart';
import '../../app/layout.dart';
import '../../data/models.dart';
import '../../data/night_insights.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_type.dart';
import '../../theme/page_accent.dart';
import '../../widgets/board_page.dart';
import '../../widgets/chip_carousel.dart';
import '../../widgets/free_figure.dart';
import '../../widgets/morphing_shape.dart';
import '../../widgets/shape_badge.dart';
import '../../widgets/animated_count.dart';
import '../../widgets/pressable.dart';
import '../../widgets/tile_surface.dart';
import 'night_format.dart';
import 'night_list_page.dart';
import 'sleep_detail_page.dart';
import 'sleep_scene.dart';

/// Opens the page about [night], growing it out of the rectangle [origin] of
/// what was tapped.
void openNight(BuildContext context, SleepNight night, Rect origin) {
  Navigator.of(context).push(
    ContainerRoute<void>(
      origin: origin,
      originColor: Theme.of(context).colorScheme.surfaceBright,
      builder: (_) => SleepDetailPage(date: night.date),
    ),
  );
}

/// Whether the tile of the latest night gives its sky to the page.
bool nightHeroBleeds(BuildContext context, List<String> shown) =>
    BoardBackdrop.wanted(
      context,
      pageId: 'sleep',
      heroId: 'hero',
      shown: shown,
      inPlace: const {'recentNights', 'tonight'},
    );

/// The sky of [night] from edge to edge, as the backdrop of the page.
class NightBackdrop extends StatelessWidget {
  const NightBackdrop({super.key, required this.night, required this.extent});

  final SleepNight night;
  final double extent;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return FadingBackdrop(
      child: SleepScene(
        night: scope.health.withCurve(night),
        score: sleepScore(
          night,
          scope.settings.sleepGoalHours,
          scope.health.nights,
        ).total,
        height: extent,
        stage: LatestNightCard.sceneHeight + 24,
      ),
    );
  }
}

/// The latest night. Its sky and the figure asleep are the one container;
/// the score sits on a shape that hangs over the sky's edge, and below it
/// the length of the night and its numbers stand free.
class LatestNightCard extends StatelessWidget {
  const LatestNightCard({super.key, required this.night});

  final SleepNight night;

  static const double sceneHeight = 132;
  static const double height = sceneHeight + 232;

  static const double _shape = 104;
  static const double _overlap = 48;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final scope = AppScope.of(context);
    final type = AppType.of(context);
    final accent = PageAccent.colorsOf(context);
    final insights = NightInsights.of(
      night,
      scope.health.nights,
      scope.settings.sleepGoalHours,
    );
    final score = insights.score.total;
    final shown = [
      for (final measure in const [
        NightMeasure.deep,
        NightMeasure.rem,
        NightMeasure.efficiency,
      ])
        ?insights.measure(measure),
    ];
    final scoreStyle = type.hero(
      context.emphasizedTextTheme.headlineLarge?.copyWith(
        color: accent.onAccent,
        height: 1,
      ),
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
              if (origin != null) openNight(context, night, origin);
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (BoardBackdrop.isShown(context))
                      const SizedBox(height: sceneHeight)
                    else
                      TileSurface(
                        color: scheme.surfaceBright,
                        radius: AppRadii.extraLargeIncreased,
                        child: SleepScene(
                          night: scope.health.withCurve(night),
                          score: score,
                          height: sceneHeight,
                        ),
                      ),
                    SizedBox(
                      height: _shape - _overlap,
                      child: Padding(
                        padding: const EdgeInsets.only(left: _shape + 28),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.lastNight,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: type.label(
                                  theme.textTheme.titleSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
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
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedNumber(
                              value: night.asleepMinutes.toDouble(),
                              format: (value) =>
                                  formats.duration(value.round()),
                              style: type.hero(
                                context.emphasizedTextTheme.displaySmall
                                    ?.copyWith(height: 1.05),
                              ),
                            ),
                            Text(
                              l10n.asleepFromTo(
                                formatClock(night.bedtimeMinute),
                                formatClock(night.wakeMinute),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: type.label(
                                theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                for (final comparison in shown)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 10),
                                      child: FreeFigure(
                                        label: comparison.measure.label(l10n),
                                        value: AnimatedNumber(
                                          value: comparison.value,
                                          format: (value) => comparison.measure
                                              .format(formats, value),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              nightHeadline(formats, insights),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: type.strong(
                                context.emphasizedTextTheme.titleSmall
                                    ?.copyWith(color: accent.accent),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: 16,
                  top: sceneHeight - _overlap,
                  child: MorphingShape(
                    shape: AppShapes.of(PageAccent.of(context).family, score),
                    color: accent.accent,
                    size: _shape,
                    child: AnimatedCount(value: score, style: scoreStyle),
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

/// A few nights to swipe through, each a small card with its sky, and the
/// way to all of them at the end.
class NightsCard extends StatelessWidget {
  const NightsCard({
    super.key,
    required this.title,
    required this.nights,
    required this.total,
  });

  final String title;

  /// Newest first.
  final List<SleepNight> nights;

  /// How many nights there are altogether.
  final int total;

  /// A [NightRow] in a list.
  static const double rowHeight = 64;

  static const double height = ChipCarousel.height;

  @override
  Widget build(BuildContext context) {
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final scope = AppScope.of(context);
    return ChipCarousel(
      title: title,
      children: [
        for (final night in nights)
          Builder(
            builder: (context) {
              final score = sleepScore(
                night,
                scope.settings.sleepGoalHours,
                scope.health.nights,
              ).total;
              return CarouselChip(
                // A small picture, not a film.
                picture: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: true),
                  child: SleepScene(
                    night: night,
                    score: score,
                    height: CarouselChip.pictureHeight,
                  ),
                ),
                mark: ScoreMark(score: score),
                title: formats.shortDate(night.date),
                subtitle: formats.duration(night.asleepMinutes),
                onTap: (origin) => openNight(context, night, origin),
              );
            },
          ),
        CarouselEndChip(
          title: l10n.allNights,
          subtitle: l10n.nightsTotal(total),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const NightListPage()),
          ),
        ),
      ],
    );
  }
}

/// One night in a list: its score, date, length and times. Tapping it opens
/// the page about it.
class NightRow extends StatelessWidget {
  const NightRow({super.key, required this.night, this.title});

  final SleepNight night;

  /// Shown instead of the night's date, where the row stands alone.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final scope = AppScope.of(context);
    final score = sleepScore(
      night,
      scope.settings.sleepGoalHours,
      scope.health.nights,
    ).total;
    final type = AppType.of(context);
    // A night keeps the colour of sleep on whatever page it is listed.
    final sleep = scheme.tone(Tone.tertiary);
    return InkWell(
      onTap: () {
        final origin = globalRectOf(context);
        if (origin != null) openNight(context, night, origin);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            M3EContainer(
              AppShapes.of(ShapeFamily.sleep, score),
              width: 44,
              height: 44,
              color: sleep.container,
              child: Text(
                '$score',
                style: type.figure(
                  context.emphasizedTextTheme.titleSmall?.copyWith(
                    color: sleep.onContainer,
                  ),
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
                    title ?? formats.shortDate(night.date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    formats.l10n.rangeFromTo(
                      formatClock(night.bedtimeMinute),
                      formatClock(night.wakeMinute),
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
            const SizedBox(width: 8),
            Text(
              formats.duration(night.asleepMinutes),
              style: type.figure(
                context.emphasizedTextTheme.labelLarge?.copyWith(
                  color: sleep.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// When to go to bed tonight, and why then: the loud tile of the page.
class TonightCard extends StatelessWidget {
  const TonightCard({super.key});

  static const double height = 180;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final scope = AppScope.of(context);
    final type = AppType.of(context);
    final accent = PageAccent.colorsOf(context);
    final goal = scope.settings.sleepGoalHours;
    final plan = tonight(scope.health.nights, goal, scope.health.today);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: accent.onContainer.withValues(alpha: 0.76),
    );
    return TileSurface(
      color: accent.container,
      radius: AppRadii.extraLargeIncreased,
      opaque: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShapeBadge(
                shape: Shapes.l4LeafClover,
                icon: Icons.bedtime_rounded,
                size: 36,
                color: accent.accent,
                iconColor: accent.onAccent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.tonightTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.label(
                    theme.textTheme.titleSmall?.copyWith(
                      color: accent.onContainer,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (plan == null)
            Text(l10n.tonightNeedsNights, style: muted)
          else ...[
            Text(
              l10n.tonightBedtime(formatClock(plan.bedtimeMinute)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.title(
                context.emphasizedTextTheme.headlineSmall?.copyWith(
                  color: accent.onContainer,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [
                l10n.tonightWhy(
                  formats.duration((goal * 60).round()),
                  formatClock(plan.wakeMinute),
                ),
                if (plan.catchUpMinutes > 0)
                  l10n.tonightCatchUp(plan.catchUpMinutes),
              ].join(' '),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: muted,
            ),
          ],
        ],
      ),
    );
  }
}
