import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/layout.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/page_accent.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/board_page.dart';
import '../../widgets/page_header.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/tile_board.dart';
import 'night_tiles.dart';
import 'sleep_stages_chart.dart';

/// Last night's sleep and the week around it.
class SleepPage extends StatefulWidget {
  const SleepPage({super.key});

  @override
  State<SleepPage> createState() => _SleepPageState();
}

class _SleepPageState extends State<SleepPage> {
  static const int _moreNights = 5;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    return PageAccent.sleep(
      child: ListenableBuilder(
        listenable: Listenable.merge([health, scope.settings]),
        builder: (context, _) => _build(context),
      ),
    );
  }

  Widget _build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = PageAccent.colorsOf(context);
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final snapshot = health.snapshot;
    // The page is about the latest night, whatever day is selected
    // elsewhere.
    final latest = health.latestNight;
    final night = latest == null ? null : health.withCurve(latest);
    final nights = health.nights;
    final earlier = nights.reversed.skip(1).take(_moreNights).toList();
    final shownIndex = latest == null ? null : snapshot.indexOf(latest.date);
    final selected = shownIndex == null ? -1 : shownIndex - health.weekStart;
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
        number: (night?.minutesIn(stage) ?? 0).toDouble(),
        format: (value) => formats.duration(value.round()),
        icon: icon,
        shape: shape,
        tone: tone,
      ),
    );

    final shown = ['hero', if (nights.length > 1) 'recentNights', 'tonight'];
    return BoardPage(
      pageId: 'sleep',
      // A night sky is dark under any theme.
      backdropInk: const Color(0xFFEFF1FF),
      backdrop: latest == null || !nightHeroBleeds(context, shown)
          ? null
          : (context, boardTop) => NightBackdrop(
              night: latest,
              extent: boardTop + LatestNightCard.sceneHeight,
            ),
      title: l10n.groupSleep,
      subtitle: l10n.nightTo(formats.longDate(latest?.date ?? health.today)),
      removable: true,
      tiles: [
        if (night == null)
          BoardTile(
            id: 'hero',
            title: l10n.lastNight,
            height: 132,
            child: SurfaceCard(child: EmptyNote(l10n.noSleepData)),
          )
        else
          BoardTile(
            id: 'hero',
            title: l10n.lastNight,
            height: LatestNightCard.height,
            child: LatestNightCard(night: latest!),
          ),
        if (nights.length > 1)
          BoardTile(
            id: 'recentNights',
            title: l10n.moreNights,
            height: NightsCard.height,
            entersInPlace: true,
            child: NightsCard(
              title: l10n.moreNights,
              nights: earlier,
              total: nights.length,
            ),
          ),
        BoardTile(
          id: 'tonight',
          title: l10n.tonightTitle,
          height: TonightCard.height,
          entersInPlace: true,
          child: const TonightCard(),
        ),
        if (night != null) ...[
          BoardTile(
            id: 'stages',
            title: l10n.sleepStages,
            height: 292,
            child: TitledTile(
              title: l10n.sleepStages,
              child: SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: night.hasCurve
                          ? SleepStagesChart(night: night, colors: stageColors)
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
          height: 276,
          child: TitledTile(
            title: l10n.thisWeek,
            child: SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  BarChart(
                    values: [
                      for (var i = health.weekStart; i < snapshot.dayCount; i++)
                        switch (snapshot.nights[i]) {
                          final night? => night.asleepMinutes / 60,
                          null => null,
                        },
                    ],
                    labels: [
                      for (var i = health.weekStart; i < snapshot.dayCount; i++)
                        formats.weekdayShort[snapshot.dateAt(i).weekday - 1],
                    ],
                    selectedIndex: selected >= 0 ? selected : null,
                    // A bar opens the page of its night.
                    onSelected: (i) {
                      final tapped = snapshot.nights[health.weekStart + i];
                      final origin = globalRectOf(context);
                      if (tapped != null && origin != null) {
                        openNight(context, tapped, origin);
                      }
                    },
                    color: accent.container,
                    selectedColor: accent.accent,
                    goal: scope.settings.sleepGoalHours,
                    height: 168,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The estimated score in a shape that morphs on tap, next to duration and
/// goal. A tap anywhere else on the tile opens the detailed page.
