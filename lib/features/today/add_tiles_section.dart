import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/health_controller.dart';
import '../../data/metric_catalog.dart';
import '../../data/settings_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/page_header.dart';
import '../../widgets/shape_badge.dart';
import '../activity/workout_style.dart';
import '../detail/metric_spec.dart';
import 'today_tiles.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../app/formatters.dart';

/// Everything that could be a tile on the Today page and is not one yet,
/// each with a plus. Shown while the page is being edited.
class AddTilesSection extends StatelessWidget {
  const AddTilesSection({
    super.key,
    required this.health,
    required this.settings,
  });

  final HealthController health;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final shown = settings.todayTiles.toSet();
    bool open(String id) =>
        !shown.contains(id) && todayTileAvailable(id, health);

    final groups = [
      (
        l10n.navToday,
        [
          for (final id in const [
            dayTileId,
            tipsTileId,
            nightTileId,
            goalsTileId,
            daysTileId,
          ])
            if (open(id)) id,
        ],
      ),
      for (final group in MetricGroup.values)
        (
          group.label(l10n),
          [
            for (final metric in Metric.values)
              if (metric.group == group && open(metric.name)) metric.name,
          ],
        ),
      (l10n.groupWorkout, [if (open(workoutTileId)) workoutTileId]),
    ].where((g) => g.$2.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          l10n.add,
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              l10n.addTilesAllShown,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final (label, ids) in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          M3ESegmentedColumn(
            color: scheme.surfaceBright,
            haptic: M3EHapticFeedback.light,
            onTap: (i) => settings.addTodayTile(ids[i]),
            children: [for (final id in ids) _row(context, id)],
          ),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, String id) {
    final scheme = Theme.of(context).colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final metric = Metric.byName(id);
    // Only the workout tile is about a workout.
    final workout = id == workoutTileId ? health.latestWorkout : null;
    final dayIcon = switch (id) {
      dayTileId => Icons.wb_sunny_rounded,
      tipsTileId => Icons.lightbulb_outline_rounded,
      nightTileId => Icons.bedtime_rounded,
      goalsTileId => Icons.flag_rounded,
      daysTileId => Icons.calendar_month_rounded,
      _ => null,
    };
    final tone = metric?.spec.tone ?? Tone.primary;
    final colors = scheme.tone(tone);
    final neutral = tone == Tone.neutral;
    final snapshot = health.snapshot;
    final latest = metric == null ? null : snapshot.latestIndex(metric);
    return M3EListItem(
      leading: ShapeBadge(
        shape: metric?.spec.shape ?? workout?.type.shape ?? Shapes.circle,
        icon:
            metric?.spec.icon ??
            workout?.type.icon ??
            dayIcon ??
            Icons.add_rounded,
        size: 44,
        color: neutral ? scheme.secondaryContainer : colors.accent,
        iconColor: neutral ? scheme.onSecondaryContainer : scheme.surfaceBright,
      ),
      headline: Text(metric?.title(l10n) ?? todayTileTitle(l10n, id)),
      supportingText: dayIcon != null
          ? null
          : Text(
              metric == null
                  ? workout?.type.label(l10n) ?? ''
                  : latest == null
                  ? l10n.nothingEntered
                  : metric.formatWithUnit(
                      formats,
                      snapshot.value(metric, latest),
                    ),
            ),
      trailing: Icon(Icons.add_circle_rounded, color: scheme.primary),
    );
  }
}
