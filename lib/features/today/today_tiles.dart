import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../app/layout.dart';
import '../../data/night_insights.dart';
import '../../data/health_controller.dart';
import '../../data/health_snapshot.dart';
import '../../data/metric_catalog.dart';
import '../../data/goals.dart';
import '../../data/models.dart';
import '../../data/morning.dart';
import '../../data/settings_controller.dart';
import '../../data/supplements.dart';
import '../../data/week_report.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_type.dart';
import '../../theme/pulse_look.dart';
import '../../widgets/line_chart.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/pressable.dart';
import '../../widgets/progress_ring.dart';
import '../../widgets/shape_badge.dart';
import '../../widgets/tile_board.dart';
import '../../widgets/tile_surface.dart';
import '../../widgets/wavy_bar.dart';
import '../activity/workout_tiles.dart';
import '../sleep/night_tiles.dart';
import '../supplements/caffeine_tile.dart';
import '../supplements/supplement_card.dart';
import '../detail/large_metric_tile.dart';
import '../detail/metric_spec.dart';
import '../detail/metric_tiles.dart';
import '../links/link_format.dart';
import '../links/links_tile.dart';
import '../morning/morning_tile.dart';
import '../week/week_tile.dart';
import 'day_format.dart';
import 'day_tiles.dart';
import '../../l10n/generated/app_localizations.dart';

/// The height of a tile that is one row of a list.
const double _rowTileHeight = 72;

/// Days before today that the tile of earlier days lists.
const int _moreDays = 5;

/// Whether the tile [id] has something to show: data in the store, or a
/// measurement the user can record here.
bool todayTileAvailable(
  String id,
  HealthController health,
  SettingsController settings, [
  SupplementData supplements = const SupplementData(),
]) {
  switch (id) {
    case supplementsTileId:
      return true;
    case caffeineTileId:
      // Only for someone who logs caffeine at all.
      return supplements.intakes.any((intake) => intake.caffeineMg != null);
    case dayTileId || tipsTileId || goalsTileId:
      return true;
    case morningTileId:
      // The way back to the cards, for as long as it is morning unless the
      // user keeps it.
      return settings.morningBrief &&
          (settings.morningTileAllDay ||
              morningWindow(health.nights, health.now).holds(health.now));
    case weekTileId:
      return settings.weekReport && weekTileShown(health.now);
    case linksTileId:
      return true;
    case nightTileId:
      return health.latestNight != null;
    case workoutTileId:
      return health.latestWorkout != null;
    case daysTileId:
      return health.days.length > 1;
  }
  final metric = Metric.byName(id);
  if (metric == null) return false;
  return metric.entryKind != null || health.snapshot.has(metric);
}

/// The name on a tile. Shorter than the catalog's where that would not fit
/// a half-width tile.
String todayTileTitle(AppLocalizations l10n, String id) =>
    switch (Metric.byName(id)) {
      null => switch (id) {
        dayTileId => l10n.dayTileTitle,
        morningTileId => l10n.morningTitle,
        weekTileId => l10n.weekTitle,
        linksTileId => l10n.linksTitle,
        supplementsTileId => l10n.supplements,
        caffeineTileId => l10n.metricCaffeine,
        tipsTileId => l10n.dayTipsTitle,
        nightTileId => l10n.lastNight,
        goalsTileId => l10n.goals,
        daysTileId => l10n.moreDays,
        _ => l10n.lastWorkout,
      },
      Metric.heartRate => l10n.shortHeartRate,
      Metric.totalEnergy => l10n.shortCalories,
      Metric.oxygenSaturation => l10n.shortOxygen,
      Metric.energyIntake => l10n.groupNutrition,
      Metric.heartRateVariability => l10n.shortHrv,
      Metric.skinTemperature => l10n.shortSkinTemperature,
      Metric.systolic => l10n.shortSystolic,
      Metric.diastolic => l10n.shortDiastolic,
      final metric => metric.title(l10n),
    };

/// The tile [id] of the Today page in the size the user chose, or null when
/// there is nothing to show for it.
BoardTile? buildTodayTile(
  BuildContext context, {
  required String id,
  required HealthController health,
  required SettingsController settings,
  SupplementData supplements = const SupplementData(),
}) {
  if (!todayTileAvailable(id, health, settings, supplements)) return null;
  void remove() => settings.removeTodayTile(id);

  final metric = Metric.byName(id);
  if (metric == null) {
    final scheme = Theme.of(context).colorScheme;
    // One row of a list, as a tile of its own.
    Widget row(Widget child) => TileSurface(
      color: scheme.surfaceBright,
      radius: AppRadii.extraLarge,
      child: child,
    );
    switch (id) {
      case morningTileId:
        return BoardTile(
          id: id,
          height: MorningTile.heightFor(simple: settings.simple),
          entersInPlace: true,
          onRemove: remove,
          child: const MorningTile(),
        );
      case weekTileId:
        return BoardTile(
          id: id,
          height: WeekTile.height,
          entersInPlace: true,
          onRemove: remove,
          child: const WeekTile(),
        );
      case linksTileId:
        return BoardTile(
          id: id,
          height: LinksTile.heightFor(
            simple: settings.simple,
            hasLink:
                settings.simple &&
                linksOf(health, settings, supplements).isNotEmpty,
          ),
          entersInPlace: true,
          onRemove: remove,
          child: const LinksTile(),
        );
      case supplementsTileId:
        final large = settings.isLargeTile(id);
        return BoardTile(
          id: id,
          height: SupplementsCard.heightFor(
            supplements.mine.length,
            simple: settings.simple,
            large: large,
          ),
          large: large,
          onRemove: remove,
          onResize: () => settings.toggleTileSize(id),
          child: SupplementsCard(simple: settings.simple, large: large),
        );
      case caffeineTileId:
        return BoardTile(
          id: id,
          height: CaffeineTile.height,
          onRemove: remove,
          child: const CaffeineTile(),
        );
      case dayTileId:
        return BoardTile(
          id: id,
          height: DayCard.heightFor(simple: settings.simple),
          entersInPlace: true,
          onRemove: remove,
          child: const DayCard(),
        );
      case tipsTileId:
        final tips = dayInsightsOf(health, settings, health.today).tips;
        return BoardTile(
          id: id,
          height: DayTipsCard.heightFor(tips.length),
          entersInPlace: true,
          onRemove: remove,
          child: DayTipsCard(tips: tips),
        );
      case nightTileId:
        return BoardTile(
          id: id,
          height: _rowTileHeight,
          entersInPlace: true,
          onRemove: remove,
          child: row(
            NightRow(
              night: health.latestNight!,
              title: AppLocalizations.of(context).lastNight,
              simple: settings.simple,
            ),
          ),
        );
      case goalsTileId:
        return BoardTile(
          id: id,
          height: GoalsCard.heightFor(settings.goals.length),
          entersInPlace: true,
          onRemove: remove,
          child: const GoalsCard(),
        );
      case daysTileId:
        final days = health.days;
        final earlier = days.reversed.skip(1).take(_moreDays).toList();
        return BoardTile(
          id: id,
          height: DaysCard.heightFor(simple: settings.simple),
          onRemove: remove,
          child: DaysCard(
            days: earlier,
            total: days.length,
            simple: settings.simple,
          ),
        );
    }
    return BoardTile(
      id: id,
      height: _rowTileHeight,
      onRemove: remove,
      child: row(
        WorkoutRow(workout: health.latestWorkout!, simple: settings.simple),
      ),
    );
  }

  final large = settings.isLargeTile(id);
  void resize() => settings.toggleTileSize(id);
  if (!large) {
    return BoardTile(
      id: id,
      span: TileSpan.half,
      height: 176,
      onRemove: remove,
      onResize: resize,
      child: _SmallTile(metric: metric, health: health, settings: settings),
    );
  }
  return BoardTile(
    id: id,
    height: metric == Metric.energyIntake ? 196 : 272,
    large: true,
    onRemove: remove,
    onResize: resize,
    child: switch (metric) {
      Metric.energyIntake => _NutritionCard(
        snapshot: health.snapshot,
        dayIndex: health.todayIndex,
      ),
      _ => LargeMetricTile(
        metric: metric,
        title: todayTileTitle(AppLocalizations.of(context), id),
        health: health,
        settings: settings,
      ),
    },
  );
}

class _SmallTile extends StatelessWidget {
  const _SmallTile({
    required this.metric,
    required this.health,
    required this.settings,
  });

  final Metric metric;
  final HealthController health;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final spec = metric.spec;
    final colors = scheme.tone(spec.tone);
    final snapshot = health.snapshot;
    final today = health.todayIndex;
    final reading = tileReading(formats, snapshot, metric);
    final value = reading.value;
    final note = reading.note;
    final night = snapshot.nights[today];
    final heart = snapshot.heart[today];
    // In the expressive rework a measurement with a daily goal shows how
    // far it has come as a wavy bar, in place of its note.
    final goal = PulseLook.expressiveOf(context)
        ? dailyGoalOf(metric, settings)
        : null;

    final Widget? footer = switch (metric) {
      _ when goal != null => WavyBar(
        value: (value ?? 0) / settings.goalTarget(goal),
        color: metric == Metric.water ? scheme.primary : colors.accent,
        trackColor: colors.accent.withValues(alpha: 0.16),
      ),
      Metric.heartRate when heart.length >= 2 => LineChart(
        values: [for (final s in heart) s.bpm.toDouble()],
        color: colors.accent,
        height: 32,
        strokeWidth: 3,
      ),
      Metric.sleep when night != null => _Caption(
        l10n.scoreEstimate(
          sleepScore(night, settings.sleepGoalHours, health.nights).total,
        ),
        color: colors.onContainer,
      ),
      Metric.water => RepaintBoundary(
        child: M3ELinearWavyProgressIndicator(
          value: ((value ?? 0) * 1000 / settings.waterGoalMl)
              .clamp(0, 1)
              .toDouble(),
          color: scheme.primary,
          backgroundColor: scheme.secondaryContainer,
        ),
      ),
      Metric.heartRate => null,
      _ when note != null => _Caption(note, color: colors.onContainer),
      _ => null,
    };

    return MetricCard(
      label: todayTileTitle(l10n, metric.name),
      value: metricValueOf(metric, value),
      // "Schritte" twice in one tile says nothing.
      unit: metric.isCount ? null : metric.unit,
      icon: spec.icon,
      shape: spec.shape,
      tone: spec.tone,
      footer: footer,
      trailing: switch (metric) {
        Metric.steps => SizedBox.square(
          dimension: 36,
          child: ProgressRing(
            value: (value ?? 0) / settings.stepGoal,
            color: colors.accent,
            trackColor: colors.accent.withValues(alpha: 0.16),
            strokeWidth: 6,
          ),
        ),
        Metric.water => _GlassButton(health: health),
        _ => null,
      },
      onTap: (origin) => openMetric(context, metric, origin),
    );
  }
}

/// The goal of a day [metric] is the measurement of, where the user follows
/// one.
Goal? dailyGoalOf(Metric metric, SettingsController settings) {
  for (final goal in settings.goals) {
    if (!goal.weekly && goal.metric == metric) return goal;
  }
  return null;
}

class _Caption extends StatelessWidget {
  const _Caption(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
    );
  }
}

/// Eaten calories and the three macronutrients of the selected day.
class _NutritionCard extends StatelessWidget {
  const _NutritionCard({required this.snapshot, required this.dayIndex});

  final HealthSnapshot snapshot;
  final int dayIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final kcal = snapshot.value(Metric.energyIntake, dayIndex);
    final parts = [
      (Metric.carbs, l10n.metricCarbs, scheme.primary),
      (Metric.protein, l10n.metricProtein, scheme.secondary),
      (Metric.fat, l10n.metricFat, scheme.tertiary),
    ];
    var total = 0.0;
    for (final (metric, _, _) in parts) {
      total += snapshot.value(metric, dayIndex) ?? 0;
    }
    final expressive = PulseLook.expressiveOf(context);

    return Pressable(
      pressedScale: 0.97,
      child: TileSurface(
        color: scheme.surfaceBright,
        radius: AppRadii.extraLargeIncreased,
        blob: expressive ? 2 : null,
        child: Builder(
          builder: (context) => InkWell(
            onTap: () {
              final origin = globalRectOf(context);
              if (origin != null) {
                openMetric(context, Metric.energyIntake, origin);
              }
            },
            child: expressive
                ? _NutritionRingBody(
                    kcal: kcal,
                    parts: [
                      for (final (metric, label, color) in parts)
                        (
                          label: label,
                          color: color,
                          grams: snapshot.value(metric, dayIndex),
                          text: metric.formatWithUnit(
                            formats,
                            snapshot.value(metric, dayIndex),
                          ),
                        ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ShapeBadge(
                              shape: Metric.energyIntake.spec.shape,
                              icon: Metric.energyIntake.spec.icon,
                              size: 44,
                              color: scheme.tertiary,
                              iconColor: scheme.onTertiary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l10n.groupNutrition,
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                            Text(
                              kcal == null
                                  ? l10n.nothingEntered
                                  : Metric.energyIntake.formatWithUnit(
                                      formats,
                                      kcal,
                                    ),
                              style: kcal == null
                                  ? theme.textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    )
                                  : context.emphasizedTextTheme.titleLarge,
                            ),
                          ],
                        ),
                        const Spacer(),
                        for (final (metric, label, color) in parts) ...[
                          Row(
                            children: [
                              SizedBox(
                                width: 112,
                                child: Text(
                                  label,
                                  style: theme.textTheme.labelLarge,
                                ),
                              ),
                              Expanded(
                                child: _Bar(
                                  fraction: total == 0
                                      ? 0
                                      : (snapshot.value(metric, dayIndex) ??
                                                0) /
                                            total,
                                  color: color,
                                  trackColor: scheme.surfaceContainerHighest,
                                ),
                              ),
                              SizedBox(
                                width: 56,
                                child: Text(
                                  metric.formatWithUnit(
                                    formats,
                                    snapshot.value(metric, dayIndex),
                                  ),
                                  textAlign: TextAlign.end,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (metric != Metric.fat) const SizedBox(height: 10),
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

typedef _Part = ({String label, Color color, double? grams, String text});

/// The nutrition tile of the expressive rework: the three nutrients as one
/// ring around the cutlery, the calories large beside it and a line for
/// each nutrient below them.
class _NutritionRingBody extends StatelessWidget {
  const _NutritionRingBody({required this.kcal, required this.parts});

  final double? kcal;
  final List<_Part> parts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final type = AppType.of(context);
    final kcal = this.kcal;
    final quiet = theme.textTheme.labelLarge?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 20, 16),
      child: Row(
        children: [
          SizedBox.square(
            // Smaller on a narrow phone, so the nutrients keep their names.
            dimension: MediaQuery.sizeOf(context).width < 400 ? 112 : 136,
            child: SingleMotionBuilder(
              from: 0,
              value: 1,
              motion: AppMotion.effectsSlow,
              builder: (context, grown, child) => CustomPaint(
                painter: _NutritionRing(
                  shares: [for (final part in parts) part.grams ?? 0],
                  colors: [for (final part in parts) part.color],
                  track: scheme.surfaceContainerHighest,
                  grown: grown.clamp(0, 1).toDouble(),
                ),
                child: child,
              ),
              child: Center(
                child: ShapeBadge(
                  shape: Metric.energyIntake.spec.shape,
                  icon: Metric.energyIntake.spec.icon,
                  size: 56,
                  color: scheme.tertiary,
                  iconColor: scheme.onTertiary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  type.caps(l10n.groupNutrition),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.capsLabel(
                    theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: kcal == null
                      ? Text(l10n.nothingEntered, style: quiet)
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              Metric.energyIntake.format(formats, kcal),
                              style: type.hero(
                                context.emphasizedTextTheme.headlineLarge,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(Metric.energyIntake.unit, style: quiet),
                          ],
                        ),
                ),
                const SizedBox(height: 8),
                for (final part in parts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: part.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            part.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                        Text(
                          part.text,
                          style: type.figure(theme.textTheme.labelLarge),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The nutrients as arcs of one ring, each as long as its share of the
/// grams, with a gap between them; a quiet track where nothing was eaten.
class _NutritionRing extends CustomPainter {
  const _NutritionRing({
    required this.shares,
    required this.colors,
    required this.track,
    required this.grown,
  });

  final List<double> shares;
  final List<Color> colors;
  final Color track;

  /// How far the arcs have grown in, from 0 to 1.
  final double grown;

  static const double _width = 14;

  /// The gap between two arcs, in radians.
  static const double _gap = 0.32;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_width / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _width
      ..strokeCap = StrokeCap.round;
    final total = shares.fold(0.0, (sum, share) => sum + share);
    if (total <= 0) {
      canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = track);
      return;
    }
    final shown = [
      for (final (i, share) in shares.indexed)
        if (share > 0) (share / total, colors[i]),
    ];
    final room = 2 * math.pi - (shown.length > 1 ? _gap * shown.length : 0);
    var start = -math.pi / 2;
    for (final (share, color) in shown) {
      final sweep = room * share * grown;
      if (sweep > 0) {
        canvas.drawArc(rect, start, sweep, false, paint..color = color);
      }
      start += room * share + (shown.length > 1 ? _gap : 0);
    }
  }

  @override
  bool shouldRepaint(_NutritionRing oldDelegate) =>
      oldDelegate.grown != grown ||
      oldDelegate.track != track ||
      !listEquals(oldDelegate.shares, shares) ||
      !listEquals(oldDelegate.colors, colors);
}

class _Bar extends StatelessWidget {
  const _Bar({
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
      height: 10,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: trackColor,
          shape: const StadiumBorder(),
        ),
        child: SingleMotionBuilder(
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

/// Enters one glass of water without opening the sheet. What it wrote can
/// be taken back from the message that follows.
class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.health});

  final HealthController health;

  /// Millilitres in a glass.
  static const double _glass = 250;

  Future<void> _add(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final draft = EntryDraft(
      kind: EntryKind.water,
      time: health.now,
      amount: _glass,
    );
    Haptics.tap();
    try {
      await health.addEntry(draft);
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.entrySaveFailed)));
      return;
    }
    Haptics.confirm();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            l10n.glassAdded('${formats.integer(_glass.round())} ml'),
          ),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () async {
              // The entry as the store handed it back, to delete that one.
              HealthEntry? written;
              for (final entry in health.snapshot.entries) {
                if (entry.isOwn &&
                    entry.draft.kind == EntryKind.water &&
                    entry.draft.time == draft.time) {
                  written = entry;
                }
              }
              if (written == null) return;
              try {
                await health.deleteEntry(written);
              } on Exception {
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.deleteFailed)),
                );
              }
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 40,
      child: IconButton.filledTonal(
        onPressed: () => _add(context),
        tooltip: AppLocalizations.of(context).addGlass,
        padding: EdgeInsets.zero,
        color: scheme.onSecondaryContainer,
        icon: const Icon(Icons.local_drink_rounded, size: 20),
      ),
    );
  }
}
