import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/container_route.dart';
import '../../app/formatters.dart';
import '../../app/layout.dart';
import '../../data/health_controller.dart';
import '../../data/heart_day.dart';
import '../../data/heart_insights.dart';
import '../../data/models.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_type.dart';
import '../../theme/page_accent.dart';
import '../../widgets/animated_count.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/board_page.dart';
import '../../widgets/chip_carousel.dart';
import '../../widgets/free_figure.dart';
import '../../widgets/page_header.dart';
import '../../widgets/pressable.dart';
import '../../widgets/segment_group.dart';
import '../../widgets/shape_badge.dart';
import '../../widgets/tile_surface.dart';
import '../../widgets/wavy_bar.dart';
import 'heart_detail_page.dart';
import 'heart_format.dart';
import 'heart_scene.dart';

/// Opens the page about the pulse of [date], growing it out of the
/// rectangle [origin] of what was tapped.
void openHeartDay(BuildContext context, DateTime date, Rect origin) {
  Navigator.of(context).push(
    ContainerRoute<void>(
      origin: origin,
      originColor: Theme.of(context).colorScheme.surfaceBright,
      originRadius: AppRadii.extraLargeIncreased,
      builder: (_) => HeartDetailPage(date: date),
    ),
  );
}

/// The pulse of one day at a glance. The figure with its heart beating at
/// the last measured rate is the one container; the rate itself sits on a
/// heart that hangs over the scene's edge, and below it, free, how far the
/// day ranged, its numbers and how it went against the days before. Tapped,
/// it opens the day in detail.
class HeartDayCard extends StatelessWidget {
  const HeartDayCard({super.key, required this.date, required this.samples});

  final DateTime date;
  final List<HeartSample> samples;

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
    final health = AppScope.of(context).health;
    final type = AppType.of(context);
    final accent = PageAccent.colorsOf(context);
    final current = samples.isEmpty ? null : samples.last;
    final summary = heartSummary(samples);
    final bpmStyle = type.hero(
      context.emphasizedTextTheme.headlineMedium?.copyWith(
        color: accent.onAccent,
        height: 1,
      ),
    );
    final quiet = type.label(
      theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
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
              if (origin != null) openHeartDay(context, date, origin);
            },
            child: Stack(
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
                        child: HeartScene(
                          bpm: current?.bpm,
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
                                current == null
                                    ? l10n.noPulseThatDay
                                    : l10n.lastAtTime(
                                        formatClock(current.minuteOfDay),
                                      ),
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
                        child: summary == null
                            ? Align(
                                alignment: Alignment.topLeft,
                                child: Text(l10n.noHeartCurve, style: quiet),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      samples.length < 2
                                          ? bpmText(summary.low)
                                          : l10n.bpmRange(
                                              summary.low,
                                              summary.high,
                                            ),
                                      maxLines: 1,
                                      style: type.hero(
                                        context.emphasizedTextTheme.displaySmall
                                            ?.copyWith(height: 1.05),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    l10n.measuredFromTo(
                                      formatClock(samples.first.minuteOfDay),
                                      formatClock(samples.last.minuteOfDay),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: quiet,
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      for (final (label, value) in [
                                        (
                                          l10n.heartAverage,
                                          bpmText(summary.average),
                                        ),
                                        (
                                          l10n.heartActive,
                                          formats.duration(
                                            activeMinutes(samples),
                                          ),
                                        ),
                                      ])
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              right: 10,
                                            ),
                                            child: FreeFigure(
                                              label: label,
                                              value: Text(value),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    heartHeadline(
                                      formats,
                                      heartInsightsOf(health, date),
                                    ),
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
                  child: SizedBox.square(
                    dimension: _shape,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        BeatingHeart(
                          bpm: current?.bpm,
                          color: accent.accent,
                          size: _shape,
                        ),
                        // A little above the middle, where the heart is
                        // widest.
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: current == null
                              ? Text('–', style: bpmStyle)
                              : AnimatedCount(
                                  value: current.bpm,
                                  style: bpmStyle,
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
      ),
    );
  }
}

/// The days before [date] that have a curve, to swipe through, each a small
/// card with the figure and the day's average on a heart.
class HeartDaysCard extends StatelessWidget {
  const HeartDaysCard({super.key, required this.title, required this.date});

  final String title;
  final DateTime date;

  static const double height = ChipCarousel.height;

  /// The days shown, newest first.
  static List<DateTime> daysBefore(HealthController health, DateTime date) => [
    for (final day in heartDays(health).reversed)
      if (day.isBefore(date)) day,
  ];

  @override
  Widget build(BuildContext context) {
    final formats = Formats.of(context);
    final health = AppScope.of(context).health;
    final accent = PageAccent.colorsOf(context);
    final type = AppType.of(context);
    return ChipCarousel(
      title: title,
      children: [
        for (final day in daysBefore(health, date))
          if (heartSummary(heartSamplesOn(health, day)) case final summary?)
            CarouselChip(
              // A small picture, not a film.
              picture: MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: HeartScene(
                  bpm: summary.average,
                  height: CarouselChip.pictureHeight,
                ),
              ),
              mark: M3EContainer(
                Shapes.heart,
                width: CarouselChip.markSize,
                height: CarouselChip.markSize,
                color: accent.accent,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${summary.average}',
                    style: type.figure(
                      context.emphasizedTextTheme.labelLarge?.copyWith(
                        color: accent.onAccent,
                      ),
                    ),
                  ),
                ),
              ),
              title: formats.shortDate(day),
              subtitle: formats.l10n.bpmRange(summary.low, summary.high),
              onTap: (origin) => openHeartDay(context, day, origin),
            ),
      ],
    );
  }
}

/// What the app has to say about the pulse of [date]: the loud tile of the
/// page.
class HeartNoteCard extends StatelessWidget {
  const HeartNoteCard({super.key, required this.date});

  final DateTime date;

  static const double height = 180;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formats = Formats.of(context);
    final type = AppType.of(context);
    final accent = PageAccent.colorsOf(context);
    final insights = heartInsightsOf(AppScope.of(context).health, date);
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
                shape: Shapes.softBurst,
                icon: Icons.lightbulb_outline_rounded,
                size: 36,
                color: accent.accent,
                iconColor: accent.onAccent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  formats.l10n.heartTipsTitle,
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
          Expanded(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                heartTipText(formats, insights.tips.first),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: type.title(
                  context.emphasizedTextTheme.titleMedium?.copyWith(
                    color: accent.onContainer,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// How long the heart spent in each zone, a wavy line a zone, the one with
/// the most time the loud one.
class HeartZones extends StatelessWidget {
  const HeartZones({super.key, required this.samples, this.detailed = false});

  final List<HeartSample> samples;

  /// Also says the rates each zone covers and its share of the time.
  final bool detailed;

  static const double _row = 68;

  /// As many as [heartZoneFloors] has.
  static const int _zones = 4;

  /// The height of the board tile that shows the zones under a title.
  static const double tileHeight =
      TitledTile.titleHeight + _zones * _row + (_zones - 1) * SegmentGroup.gap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    // In the order of [heartZoneFloors].
    final zones = [
      (label: l10n.zoneRest, color: scheme.secondary),
      (label: l10n.zoneLight, color: scheme.primary),
      (label: l10n.zoneCardio, color: scheme.tertiary),
      (label: l10n.zonePeak, color: scheme.error),
    ];
    final minutes = zoneMinutes(samples);
    var longest = 1;
    var total = 0;
    for (final value in minutes) {
      if (value > longest) longest = value;
      total += value;
    }

    final type = AppType.of(context);
    final quiet = type.label(
      theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
    );
    // The zone most of the day was spent in is the loud one.
    final most = minutes.indexOf(longest);

    Widget row(int i) => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                zones[i].label,
                style: type.strong(theme.textTheme.titleSmall),
              ),
            ),
            Text(
              detailed && total > 0
                  ? '${formats.duration(minutes[i])} · '
                        '${l10n.percentValue((minutes[i] * 100 / total).round())}'
                  : formats.duration(minutes[i]),
              style: type.figure(context.emphasizedTextTheme.labelLarge),
            ),
          ],
        ),
        const SizedBox(height: 8),
        WavyBar(
          // Its share of the time: a line that is full stops waving.
          value: total == 0 ? 0 : minutes[i] / total,
          color: zones[i].color,
          trackColor: scheme.onSurface.withValues(alpha: 0.08),
        ),
        if (detailed) ...[
          const SizedBox(height: 6),
          Text(zoneSpan(l10n, i), style: quiet),
        ],
      ],
    );

    return SegmentGroup(
      padding: detailed
          ? const EdgeInsets.symmetric(horizontal: 20, vertical: 14)
          : const EdgeInsets.symmetric(horizontal: 20),
      loud: most < 0 ? null : most,
      children: [
        for (var i = 0; i < zones.length; i++)
          detailed ? row(i) : SizedBox(height: _row, child: row(i)),
      ],
    );
  }
}

/// The average rate of each of the last days as bars, the one of [date]
/// marked. A bar gives its day to [onSelected].
class HeartWeek extends StatelessWidget {
  const HeartWeek({
    super.key,
    required this.date,
    required this.onSelected,
    this.height = 168,
  });

  final DateTime date;
  final ValueChanged<DateTime> onSelected;
  final double height;

  /// Kept under the lowest bar, so the days differ to the eye.
  static const int _foot = 12;

  @override
  Widget build(BuildContext context) {
    final formats = Formats.of(context);
    final health = AppScope.of(context).health;
    final snapshot = health.snapshot;
    final accent = PageAccent.colorsOf(context);
    final days = [for (var i = health.weekStart; i < snapshot.dayCount; i++) i];
    final values = [
      for (final i in days) heartSummary(snapshot.heart[i])?.average.toDouble(),
    ];
    var lowest = double.infinity;
    for (final value in values) {
      if (value != null && value < lowest) lowest = value;
    }
    final selected = snapshot.indexOf(date);
    return BarChart(
      values: values,
      labels: [
        for (final i in days)
          formats.weekdayShort[snapshot.dateAt(i).weekday - 1],
      ],
      selectedIndex: selected == null || selected < health.weekStart
          ? null
          : selected - health.weekStart,
      onSelected: (i) {
        if (values[i] != null) onSelected(snapshot.dateAt(days[i]));
      },
      color: accent.container,
      selectedColor: accent.accent,
      baseline: lowest.isFinite && lowest > _foot ? lowest - _foot : 0,
      height: height,
    );
  }
}

/// A heart that beats at the measured rate. It is the one thing in the app
/// that moves at rest, because the movement is the measurement. Without a
/// measurement it stands still.
class BeatingHeart extends StatefulWidget {
  const BeatingHeart({
    super.key,
    required this.bpm,
    required this.color,
    required this.size,
  });

  final int? bpm;
  final Color color;
  final double size;

  @override
  State<BeatingHeart> createState() => _BeatingHeartState();
}

class _BeatingHeartState extends State<BeatingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(BeatingHeart oldWidget) {
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
