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
    final shown = settings.todayTiles.toSet();
    bool open(String id) =>
        !shown.contains(id) && todayTileAvailable(id, health);

    final groups = [
      for (final group in MetricGroup.values)
        (
          group.label,
          [
            for (final metric in Metric.values)
              if (metric.group == group && open(metric.name)) metric.name,
          ],
        ),
      ('Training', [if (open(workoutTileId)) workoutTileId]),
    ].where((g) => g.$2.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(
          'Hinzufügen',
          padding: EdgeInsets.symmetric(horizontal: 4),
        ),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              'Alles, wozu Health Connect Daten hat, ist schon auf der Seite.',
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
    final metric = Metric.byName(id);
    final workout = health.latestWorkout;
    final tone = metric?.spec.tone ?? Tone.primary;
    final colors = scheme.tone(tone);
    final neutral = tone == Tone.neutral;
    final snapshot = health.snapshot;
    final latest = metric == null ? null : snapshot.latestIndex(metric);
    return M3EListItem(
      leading: ShapeBadge(
        shape: metric?.spec.shape ?? workout?.type.shape ?? Shapes.circle,
        icon: metric?.spec.icon ?? workout?.type.icon ?? Icons.add_rounded,
        size: 44,
        color: neutral ? scheme.secondaryContainer : colors.accent,
        iconColor: neutral ? scheme.onSecondaryContainer : scheme.surfaceBright,
      ),
      headline: Text(metric?.spec.title ?? todayTileTitle(id)),
      supportingText: Text(
        metric == null
            ? workout?.type.label ?? ''
            : latest == null
            ? 'Noch nichts eingetragen'
            : metric.formatWithUnit(snapshot.value(metric, latest)),
      ),
      trailing: Icon(Icons.add_circle_rounded, color: scheme.primary),
    );
  }
}
