import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../data/metric_catalog.dart';
import '../../data/models.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_shapes.dart';
import '../../widgets/animated_count.dart';
import '../../widgets/board_page.dart';
import '../../widgets/line_chart.dart';
import '../../widgets/page_header.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/tile_board.dart';
import '../../widgets/tile_surface.dart';
import '../detail/metric_spec.dart';
import '../detail/page_tiles.dart';

/// Heart rate over the selected day, vitals and time in zones.
class HeartPage extends StatelessWidget {
  const HeartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    final settings = scope.settings;
    return ListenableBuilder(
      listenable: Listenable.merge([health, settings]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final formats = Formats.of(context);
        final l10n = formats.l10n;
        final snapshot = health.snapshot;
        final samples = health.heartSamples;
        final current = samples.isEmpty ? null : samples.last;
        var low = current?.bpm ?? 0;
        var high = low;
        for (final sample in samples) {
          if (sample.bpm < low) low = sample.bpm;
          if (sample.bpm > high) high = sample.bpm;
        }
        final labelStyle = theme.textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        );
        final bpmStyle = context.emphasizedTextTheme.displayMedium?.copyWith(
          color: scheme.onTertiaryContainer,
          height: 1,
        );
        final systolic = health.value(Metric.systolic);
        final diastolic = health.value(Metric.diastolic);

        return BoardPage(
          pageId: 'heart',
          title: l10n.navHeart,
          subtitle: formats.longDate(health.selectedDate),
          removable: true,
          tiles: [
            BoardTile(
              id: 'hero',
              title: l10n.shortHeartRate,
              height: 152,
              child: TileSurface(
                color: scheme.tertiaryContainer,
                radius: AppRadii.extraExtraLarge,
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    _BeatingHeart(bpm: current?.bpm, color: scheme.tertiary),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              if (current == null)
                                Text('–', style: bpmStyle)
                              else
                                AnimatedCount(
                                  value: current.bpm,
                                  style: bpmStyle,
                                ),
                              const SizedBox(width: 6),
                              Text(
                                'bpm',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: scheme.onTertiaryContainer,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            current == null
                                ? l10n.noPulseThatDay
                                : l10n.lastAtTime(
                                    formatClock(current.minuteOfDay),
                                  ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onTertiaryContainer.withValues(
                                alpha: 0.72,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            BoardTile(
              id: 'day',
              title: l10n.dayCurve,
              height: 300,
              child: SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.dayCurve,
                            style: context.emphasizedTextTheme.titleMedium,
                          ),
                        ),
                        if (samples.length >= 2)
                          Text(
                            l10n.bpmRange(low, high),
                            style: context.emphasizedTextTheme.labelLarge
                                ?.copyWith(color: scheme.tertiary),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: samples.length < 2
                          ? EmptyNote(l10n.noHeartCurve)
                          : LineChart(
                              // Draw the line again for every day.
                              key: ValueKey(health.selectedDate),
                              values: [
                                for (final s in samples) s.bpm.toDouble(),
                              ],
                              color: scheme.tertiary,
                              height: null,
                            ),
                    ),
                    const SizedBox(height: 8),
                    if (samples.length >= 2)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final minute in [
                            samples.first.minuteOfDay,
                            samples.last.minuteOfDay,
                          ])
                            Text(formatClock(minute), style: labelStyle),
                        ],
                      ),
                  ],
                ),
              ),
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
                height: 304,
                child: SurfaceCard(child: _Zones(samples: samples)),
              ),
          ],
        );
      },
    );
  }
}

/// A heart that beats at the measured rate. It is the one thing in the app
/// that moves at rest, because the movement is the measurement. Without a
/// measurement it stands still.
class _BeatingHeart extends StatefulWidget {
  const _BeatingHeart({required this.bpm, required this.color});

  final int? bpm;
  final Color color;

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
    return ScaleTransition(
      scale: scale,
      child: M3EShape(
        Shapes.heart,
        width: 104,
        height: 104,
        color: widget.color,
      ),
    );
  }
}

class _Zones extends StatelessWidget {
  const _Zones({required this.samples});

  final List<HeartSample> samples;

  static const _minutesPerSample = 10;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final zones = [
      (label: l10n.zoneRest, from: 0, color: scheme.secondary),
      (label: l10n.zoneLight, from: 70, color: scheme.primary),
      (label: l10n.zoneCardio, from: 115, color: scheme.tertiary),
      (label: l10n.zonePeak, from: 140, color: scheme.error),
    ];
    final minutes = List<int>.filled(zones.length, 0);
    for (final sample in samples) {
      final zone = zones.lastIndexWhere((z) => sample.bpm >= z.from);
      minutes[zone] += _minutesPerSample;
    }
    var longest = 1;
    for (final value in minutes) {
      if (value > longest) longest = value;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.timeInZones, style: context.emphasizedTextTheme.titleMedium),
        const Spacer(),
        for (var i = 0; i < zones.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(zones[i].label, style: theme.textTheme.titleSmall),
              ),
              Text(
                formats.duration(minutes[i]),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ZoneBar(
            fraction: minutes[i] / longest,
            color: zones[i].color,
            trackColor: scheme.surfaceContainerHighest,
          ),
        ],
      ],
    );
  }
}

class _ZoneBar extends StatelessWidget {
  const _ZoneBar({
    required this.fraction,
    required this.color,
    required this.trackColor,
  });

  final double fraction;
  final Color color;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: trackColor,
          shape: const StadiumBorder(),
        ),
        child: SingleMotionBuilder(
          from: 0,
          value: fraction,
          motion: AppMotion.spatial,
          builder: (context, current, _) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: current.clamp(0, 1).toDouble(),
              heightFactor: 1,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: color,
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
