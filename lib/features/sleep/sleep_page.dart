import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/container_route.dart';
import '../../app/formatters.dart';
import '../../app/layout.dart';
import '../../data/models.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_count.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/board_page.dart';
import '../../widgets/morphing_shape.dart';
import '../../widgets/page_header.dart';
import '../../widgets/pressable.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/tile_board.dart';
import '../../widgets/tile_surface.dart';
import 'sleep_detail_page.dart';
import 'sleep_stages_chart.dart';

/// Last night's sleep and the week around it.
class SleepPage extends StatefulWidget {
  const SleepPage({super.key});

  @override
  State<SleepPage> createState() => _SleepPageState();
}

class _SleepPageState extends State<SleepPage> {
  int _shape = 0;

  void _nextShape() =>
      setState(() => _shape = (_shape + 1) % AppShapes.scoreCycle.length);

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    return ListenableBuilder(
      listenable: Listenable.merge([health, scope.settings]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final formats = Formats.of(context);
        final l10n = formats.l10n;
        final snapshot = health.snapshot;
        final night = health.night;
        final selected = health.selectedIndex - health.weekStart;
        final stageColors = {
          SleepStage.awake: scheme.outlineVariant,
          SleepStage.rem: scheme.tertiary,
          SleepStage.light: scheme.secondary,
          SleepStage.deep: scheme.primary,
        };

        BoardTile stage(
          SleepStage stage,
          String label,
          IconData icon,
          Shapes shape,
          Tone tone,
        ) => BoardTile(
          id: stage.name,
          title: label,
          span: TileSpan.half,
          height: 132,
          child: StatTile(
            label: label,
            value: formats.duration(night?.minutesIn(stage) ?? 0),
            icon: icon,
            shape: shape,
            tone: tone,
          ),
        );

        return BoardPage(
          pageId: 'sleep',
          title: l10n.groupSleep,
          subtitle: l10n.nightTo(formats.longDate(health.selectedDate)),
          removable: true,
          tiles: [
            BoardTile(
              id: 'hero',
              title: l10n.sleepDuration,
              height: 172,
              child: _SleepHero(
                night: night,
                goalHours: scope.settings.sleepGoalHours,
                shape: AppShapes.scoreCycle[_shape],
                onShapeTap: _nextShape,
              ),
            ),
            if (night != null) ...[
              BoardTile(
                id: 'stages',
                title: l10n.sleepStages,
                height: 284,
                child: SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.sleepStages,
                        style: context.emphasizedTextTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: night.hasStages
                            ? SleepStagesChart(
                                night: night,
                                colors: stageColors,
                              )
                            : EmptyNote(l10n.noStagesRecorded),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final minute in [
                            night.bedtimeMinute,
                            night.wakeMinute,
                          ])
                            Text(
                              formatClock(minute),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (night.hasStages) ...[
                stage(
                  SleepStage.deep,
                  l10n.stageDeep,
                  Icons.waves_rounded,
                  Shapes.puffy,
                  Tone.primary,
                ),
                stage(
                  SleepStage.light,
                  l10n.stageLight,
                  Icons.cloud_rounded,
                  Shapes.bun,
                  Tone.secondary,
                ),
                stage(
                  SleepStage.rem,
                  l10n.stageRem,
                  Icons.auto_awesome_rounded,
                  Shapes.softBoom,
                  Tone.tertiary,
                ),
                stage(
                  SleepStage.awake,
                  l10n.stageAwake,
                  Icons.visibility_rounded,
                  Shapes.oval,
                  Tone.neutral,
                ),
              ],
            ],
            BoardTile(
              id: 'week',
              title: l10n.thisWeek,
              height: 268,
              child: SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.thisWeek,
                      style: context.emphasizedTextTheme.titleMedium,
                    ),
                    const Spacer(),
                    BarChart(
                      values: [
                        for (
                          var i = health.weekStart;
                          i < snapshot.dayCount;
                          i++
                        )
                          switch (snapshot.nights[i]) {
                            final night? => night.asleepMinutes / 60,
                            null => null,
                          },
                      ],
                      labels: [
                        for (
                          var i = health.weekStart;
                          i < snapshot.dayCount;
                          i++
                        )
                          formats.weekdayShort[snapshot.dateAt(i).weekday - 1],
                      ],
                      selectedIndex: selected >= 0 ? selected : null,
                      onSelected: (i) => health.selectDay(health.weekStart + i),
                      color: scheme.secondaryContainer,
                      selectedColor: scheme.secondary,
                      goal: scope.settings.sleepGoalHours,
                      height: 168,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The estimated score in a shape that morphs on tap, next to duration and
/// goal. A tap anywhere else on the tile opens the detailed page.
class _SleepHero extends StatelessWidget {
  const _SleepHero({
    required this.night,
    required this.goalHours,
    required this.shape,
    required this.onShapeTap,
  });

  final SleepNight? night;
  final double goalHours;
  final Shapes shape;
  final VoidCallback onShapeTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TileSurface(
      color: scheme.secondaryContainer,
      radius: AppRadii.extraExtraLarge,
      child: InkWell(
        onTap: () {
          final origin = globalRectOf(context);
          if (origin == null) return;
          Navigator.of(context).push(
            ContainerRoute<void>(
              origin: origin,
              originColor: scheme.secondaryContainer,
              originRadius: AppRadii.extraExtraLarge,
              builder: (_) => const SleepDetailPage(),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _content(context),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final emphasized = context.emphasizedTextTheme;
    final night = this.night;
    final onContainer = scheme.onSecondaryContainer;
    final progress = night == null
        ? 0.0
        : (night.asleepMinutes / (goalHours * 60)).clamp(0, 1).toDouble();
    final scoreStyle = emphasized.displaySmall?.copyWith(
      color: scheme.onSecondary,
      height: 1,
    );
    return Row(
      children: [
        Semantics(
          container: true,
          button: true,
          label: night == null
              ? l10n.noSleepScore
              : l10n.estimatedSleepScore(night.estimatedScore),
          onTap: onShapeTap,
          excludeSemantics: true,
          child: Pressable(
            pressedScale: 0.9,
            child: GestureDetector(
              onTap: onShapeTap,
              child: MorphingShape(
                shape: shape,
                color: scheme.secondary,
                size: 124,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (night == null)
                      Text('–', style: scoreStyle)
                    else
                      AnimatedCount(
                        value: night.estimatedScore,
                        style: scoreStyle,
                      ),
                    Text(
                      l10n.estimate,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: night == null
              ? Text(
                  l10n.noSleepData,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: onContainer,
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formats.duration(night.asleepMinutes),
                        maxLines: 1,
                        style: emphasized.headlineMedium?.copyWith(
                          color: onContainer,
                        ),
                      ),
                    ),
                    Text(
                      l10n.rangeFromTo(
                        formatClock(night.bedtimeMinute),
                        formatClock(night.wakeMinute),
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: onContainer.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 14),
                    M3ELinearWavyProgressIndicator(
                      value: progress,
                      color: scheme.secondary,
                      backgroundColor: scheme.secondary.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.percentOfGoal(
                        (progress * 100).round(),
                        '${formats.decimal(goalHours)} h',
                      ),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: onContainer.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
        ),
        Icon(
          Icons.chevron_right_rounded,
          color: onContainer.withValues(alpha: 0.72),
          semanticLabel: l10n.sleepInDetail,
        ),
      ],
    );
  }
}
