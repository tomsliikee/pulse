import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../data/heart_day.dart';
import '../../data/metric_catalog.dart';
import '../../data/models.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_type.dart';
import '../../theme/page_accent.dart';
import '../../widgets/animated_count.dart';
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
          final summary = heartSummary(samples);
          final systolic = health.value(Metric.systolic);
          final diastolic = health.value(Metric.diastolic);

          final tiles = [
            BoardTile(
              id: 'hero',
              title: l10n.shortHeartRate,
              height: _Hero.height,
              child: _Hero(
                samples: samples,
                low: summary?.low ?? 0,
                high: summary?.high ?? 0,
              ),
            ),
            BoardTile(
              id: 'day',
              title: l10n.dayCurve,
              height: _DayCurve.height,
              entersInPlace: true,
              child: _DayCurve(samples: samples, day: health.selectedDate),
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
                      height: boardTop + _Hero.sceneHeight,
                      stage: _Hero.sceneHeight + 24,
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

/// The figure with its heart beating at the last measured rate is the one
/// container of the page; the rate itself sits on a heart that hangs over
/// the scene's edge, and beside it, free, how far the day ranged and when
/// the last measurement was.
class _Hero extends StatelessWidget {
  const _Hero({required this.samples, required this.low, required this.high});

  final List<HeartSample> samples;
  final int low;
  final int high;

  static const double sceneHeight = 132;
  static const double _shape = 104;
  static const double _overlap = 48;

  static const double height = sceneHeight + _shape - _overlap + 8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = Formats.of(context).l10n;
    final type = AppType.of(context);
    final accent = PageAccent.colorsOf(context);
    final current = samples.isEmpty ? null : samples.last;
    final bpmStyle = type.hero(
      context.emphasizedTextTheme.headlineMedium?.copyWith(
        color: accent.onAccent,
        height: 1,
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The page draws the scene itself, behind the title.
            if (BoardBackdrop.isShown(context))
              const SizedBox(height: sceneHeight)
            else
              TileSurface(
                color: scheme.surfaceBright,
                radius: AppRadii.extraLargeIncreased,
                child: HeartScene(bpm: current?.bpm, height: sceneHeight),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: _shape + 28, right: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      samples.length < 2 ? 'bpm' : l10n.bpmRange(low, high),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.figure(
                        context.emphasizedTextTheme.titleLarge,
                      ),
                    ),
                    Text(
                      current == null
                          ? l10n.noPulseThatDay
                          : l10n.lastAtTime(formatClock(current.minuteOfDay)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.label(
                        theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
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
          child: SizedBox.square(
            dimension: _shape,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _BeatingHeart(
                  bpm: current?.bpm,
                  color: accent.accent,
                  size: _shape,
                ),
                // A little above the middle, where the heart is widest.
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: current == null
                      ? Text('–', style: bpmStyle)
                      : AnimatedCount(value: current.bpm, style: bpmStyle),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The heart rate over the day, alone on its surface under a free title and
/// reaching its edges. Tapped, it opens the day's pulse in detail.
class _DayCurve extends StatelessWidget {
  const _DayCurve({required this.samples, required this.day});

  final List<HeartSample> samples;
  final DateTime day;

  static const double height = TitledTile.titleHeight + 196;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = Formats.of(context).l10n;
    return TitledTile(
      title: l10n.dayCurve,
      child: TileSurface(
        color: scheme.surfaceBright,
        radius: AppRadii.extraLargeIncreased,
        child: samples.length < 2
            ? EmptyNote(l10n.noHeartCurve)
            : HeartCurve(
                samples: samples,
                day: day,
                onTap: (origin) => openHeartDay(context, origin),
              ),
      ),
    );
  }
}

/// A heart that beats at the measured rate. It is the one thing in the app
/// that moves at rest, because the movement is the measurement. Without a
/// measurement it stands still.
class _BeatingHeart extends StatefulWidget {
  const _BeatingHeart({
    required this.bpm,
    required this.color,
    required this.size,
  });

  final int? bpm;
  final Color color;
  final double size;

  @override
  State<_BeatingHeart> createState() => _BeatingHeartState();
}

class _BeatingHeartState extends State<_BeatingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_BeatingHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bpm != widget.bpm) _sync();
  }

  void _sync() {
    final bpm = widget.bpm;
    if (bpm == null) {
      _beat
        ..stop()
        ..value = 0;
      return;
    }
    _beat
      ..duration = Duration(milliseconds: (60000 / bpm.clamp(30, 220)).round())
      ..repeat();
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Two quick contractions followed by a pause, like a real heartbeat.
    final scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.12), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.07), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.07, end: 1), weight: 18),
      TweenSequenceItem(tween: ConstantTween(1), weight: 50),
    ]).animate(_beat);
    // In a layer of its own, so a beat redraws the heart alone.
    return RepaintBoundary(
      child: ScaleTransition(
        scale: scale,
        child: M3EShape(
          Shapes.heart,
          width: widget.size,
          height: widget.size,
          color: widget.color,
        ),
      ),
    );
  }
}
