import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/container_route.dart';
import '../../app/formatters.dart';
import '../../app/layout.dart';
import '../../data/models.dart';
import '../../data/night_insights.dart';
import '../../theme/app_shapes.dart';
import '../../widgets/pressable.dart';
import '../../widgets/stat_tile.dart';
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

/// The latest night: its sky and the figure asleep, its numbers and how it
/// went against the night before.
class LatestNightCard extends StatelessWidget {
  const LatestNightCard({super.key, required this.night});

  final SleepNight night;

  static const double sceneHeight = 132;
  static const double height = sceneHeight + 178;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final scope = AppScope.of(context);
    final insights = NightInsights.of(
      night,
      scope.health.nights,
      scope.settings.sleepGoalHours,
    );
    final shown = [
      for (final measure in const [
        NightMeasure.score,
        NightMeasure.deep,
        NightMeasure.rem,
        NightMeasure.efficiency,
      ])
        ?insights.measure(measure),
    ].take(3);

    return Pressable(
      pressedScale: 0.98,
      child: TileSurface(
        color: scheme.surfaceBright,
        radius: AppRadii.extraLargeIncreased,
        child: InkWell(
          onTap: () {
            final origin = globalRectOf(context);
            if (origin != null) openNight(context, night, origin);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SleepScene(
                night: scope.health.withCurve(night),
                score: insights.score.total,
                height: sceneHeight,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.lastNight,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formats.duration(night.asleepMinutes),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.emphasizedTextTheme.headlineSmall,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      Text(
                        l10n.asleepFromTo(
                          formatClock(night.bedtimeMinute),
                          formatClock(night.wakeMinute),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          for (final comparison in shown)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: _Figure(
                                  label: comparison.measure.label(l10n),
                                  value: comparison.measure.format(
                                    formats,
                                    comparison.value,
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
                        style: context.emphasizedTextTheme.titleSmall?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: context.emphasizedTextTheme.titleMedium,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// A few nights as rows, and the way to all of them.
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
            child: Text(title, style: context.emphasizedTextTheme.titleMedium),
          ),
          const SizedBox(height: 12),
          for (final night in nights)
            SizedBox(
              height: rowHeight,
              child: NightRow(night: night),
            ),
          SizedBox(
            height: rowHeight,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const NightListPage()),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.allNights,
                        style: context.emphasizedTextTheme.titleSmall?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    Text(
                      l10n.nightsTotal(total),
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

/// One night in a list: its score, date, length and times. Tapping it opens
/// the page about it.
class NightRow extends StatelessWidget {
  const NightRow({super.key, required this.night});

  final SleepNight night;

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
    return InkWell(
      onTap: () {
        final origin = globalRectOf(context);
        if (origin != null) openNight(context, night, origin);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$score',
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
                    formats.shortDate(night.date),
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
              style: context.emphasizedTextTheme.labelLarge?.copyWith(
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// When to go to bed tonight, and why then.
class TonightCard extends StatelessWidget {
  const TonightCard({super.key});

  static const double height = 180;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final scope = AppScope.of(context);
    final goal = scope.settings.sleepGoalHours;
    final plan = tonight(scope.health.nights, goal, scope.health.today);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSecondaryContainer.withValues(alpha: 0.76),
    );
    return TileSurface(
      color: scheme.secondaryContainer,
      radius: AppRadii.extraLargeIncreased,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bedtime_rounded,
                size: 18,
                color: scheme.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.tonightTitle,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSecondaryContainer,
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
              style: context.emphasizedTextTheme.headlineSmall?.copyWith(
                color: scheme.onSecondaryContainer,
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
