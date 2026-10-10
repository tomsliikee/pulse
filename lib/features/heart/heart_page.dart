import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/layout.dart';
import '../../data/metric_catalog.dart';
import '../../data/models.dart';
import '../../theme/app_shapes.dart';
import '../../theme/page_accent.dart';
import '../../widgets/board_page.dart';
import '../../widgets/page_header.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/tile_board.dart';
import '../../widgets/tile_surface.dart';
import '../detail/metric_spec.dart';
import '../detail/page_tiles.dart';
import 'heart_curve.dart';
import 'heart_scene.dart';
import 'heart_tiles.dart';

/// Heart rate over the selected day, vitals and time in zones.
class HeartPage extends StatelessWidget {
  const HeartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    final settings = scope.settings;
    return PageAccent.heart(
      child: ListenableBuilder(
        listenable: Listenable.merge([health, settings]),
        builder: (context, _) {
          final formats = Formats.of(context);
          final l10n = formats.l10n;
          final snapshot = health.snapshot;
          final samples = health.heartSamples;
          final current = samples.isEmpty ? null : samples.last;
          final date = health.selectedDate;
          final earlier = HeartDaysCard.daysBefore(health, date).isNotEmpty;
          final systolic = health.value(Metric.systolic);
          final diastolic = health.value(Metric.diastolic);

          final tiles = [
            BoardTile(
              id: 'hero',
              title: l10n.shortHeartRate,
              height: HeartDayCard.height,
              child: HeartDayCard(date: date, samples: samples),
            ),
            BoardTile(
              id: 'day',
              title: l10n.dayCurve,
              height: _DayCurve.height,
              entersInPlace: true,
              child: _DayCurve(samples: samples, day: date),
            ),
            if (earlier)
              BoardTile(
                id: 'recentDays',
                title: l10n.moreDays,
                height: HeartDaysCard.height,
                entersInPlace: true,
                child: HeartDaysCard(title: l10n.moreDays, date: date),
              ),
            if (samples.isNotEmpty)
              BoardTile(
                id: 'heartNote',
                title: l10n.heartTipsTitle,
                height: HeartNoteCard.height,
                entersInPlace: true,
                child: HeartNoteCard(date: date),
              ),
            if (snapshot.has(Metric.restingHeartRate))
              statTile(
                context,
                health,
                Metric.restingHeartRate,
                settings: settings,
                page: 'heart',
              ),
            if (snapshot.has(Metric.heartRateVariability))
              statTile(
                context,
                health,
                Metric.heartRateVariability,
                settings: settings,
                page: 'heart',
              ),
            if (snapshot.has(Metric.systolic))
              BoardTile(
                id: 'bloodPressure',
                title: l10n.bloodPressure,
                span: TileSpan.half,
                height: 132,
                child: StatTile(
                  label: l10n.bloodPressure,
                  value: systolic == null || diastolic == null
                      ? '–'
                      : '${systolic.round()}/${diastolic.round()}',
                  icon: Icons.speed_rounded,
                  shape: Shapes.gem,
                  onTap: (origin) =>
                      openMetric(context, Metric.systolic, origin),
                ),
              ),
            if (snapshot.has(Metric.oxygenSaturation))
              statTile(
                context,
                health,
                Metric.oxygenSaturation,
                settings: settings,
                page: 'heart',
              ),
            if (snapshot.has(Metric.respiratoryRate))
              statTile(
                context,
                health,
                Metric.respiratoryRate,
                settings: settings,
                page: 'heart',
              ),
            if (snapshot.has(Metric.skinTemperature))
              statTile(
                context,
                health,
                Metric.skinTemperature,
                title: l10n.shortSkinTemperature,
                settings: settings,
                page: 'heart',
              ),
            if (samples.isNotEmpty)
              BoardTile(
                id: 'zones',
                title: l10n.heartRateZones,
                height: HeartZones.tileHeight,
                child: TitledTile(
                  title: l10n.timeInZones,
                  child: HeartZones(samples: samples),
                ),
              ),
            BoardTile(
              id: 'week',
              title: l10n.thisWeek,
              height: 276,
              child: TitledTile(
                title: l10n.thisWeek,
                child: SurfaceCard(
                  child: Column(
                    children: [
                      const Spacer(),
                      // A bar opens the page of its day.
                      Builder(
                        builder: (context) => HeartWeek(
                          date: date,
                          onSelected: (day) {
                            final origin = globalRectOf(context);
                            if (origin != null) {
                              openHeartDay(context, day, origin);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ];
          final bleeds = BoardBackdrop.wanted(
            context,
            pageId: 'heart',
            heroId: 'hero',
            shown: [for (final tile in tiles) tile.id],
            inPlace: {
              for (final tile in tiles)
                if (tile.entersInPlace) tile.id,
            },
          );
          return BoardPage(
            pageId: 'heart',
            backdrop: !bleeds
                ? null
                : (context, boardTop) => FadingBackdrop(
                    child: HeartScene(
                      bpm: current?.bpm,
                      height: boardTop + HeartDayCard.sceneHeight,
                      stage: HeartDayCard.sceneHeight + 24,
                    ),
                  ),
            title: l10n.navHeart,
            subtitle: formats.longDate(health.selectedDate),
            removable: true,
            tiles: tiles,
          );
        },
      ),
    );
  }
}

/// The heart rate over the day, alone on its surface under a free title and
/// reaching its edges, to tap and to hold.
class _DayCurve extends StatelessWidget {
  const _DayCurve({required this.samples, required this.day});

  final List<HeartSample> samples;
  final DateTime day;

  static const double height =
      TitledTile.titleHeight + HeartCurve.pillRoom + 220;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = Formats.of(context).l10n;
    return TitledTile(
      title: l10n.dayCurve,
      // The pill sits on the surface's top edge, under the title.
      child: Padding(
        padding: const EdgeInsets.only(top: HeartCurve.pillRoom),
        child: TileSurface(
          color: scheme.surfaceBright,
          radius: AppRadii.extraLargeIncreased,
          child: samples.length < 2
              ? EmptyNote(l10n.noHeartCurve)
              : HeartCurve(samples: samples, day: day),
        ),
      ),
    );
  }
}
