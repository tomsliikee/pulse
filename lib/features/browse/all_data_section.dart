import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/formatters.dart';
import '../../app/layout.dart';
import '../../data/health_snapshot.dart';
import '../../data/metric_catalog.dart';
import '../../theme/app_theme.dart';
import '../../widgets/page_header.dart';
import '../../widgets/shape_badge.dart';
import '../detail/metric_spec.dart';
import '../../l10n/generated/app_localizations.dart';

/// Every measurement that has data, grouped, with its most recent value.
/// Does not scroll on its own; it is appended to a page.
class AllDataSection extends StatelessWidget {
  const AllDataSection({super.key, required this.snapshot});

  final HealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final missing = [
      for (final metric in Metric.values)
        if (!snapshot.has(metric)) metric,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in MetricGroup.values)
          if ([
                for (final metric in Metric.values)
                  if (metric.group == group && snapshot.has(metric)) metric,
              ]
              case final metrics when metrics.isNotEmpty) ...[
            SectionTitle(
              group.label(l10n),
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
            ),
            Builder(
              builder: (context) => M3ESegmentedColumn(
                color: scheme.surfaceBright,
                haptic: M3EHapticFeedback.light,
                onTap: (i) {
                  // The page grows out of the whole group; the rows have no
                  // rectangle of their own to start from.
                  final origin = globalRectOf(context);
                  if (origin != null) openMetric(context, metrics[i], origin);
                },
                children: [
                  for (final metric in metrics)
                    _row(context, metric, snapshot.latestIndex(metric)!),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        if (missing.isNotEmpty) ...[
          SectionTitle(
            l10n.noData,
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              [for (final metric in missing) metric.title(l10n)].join(', '),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, Metric metric, int index) {
    final scheme = Theme.of(context).colorScheme;
    final formats = Formats.of(context);
    final spec = metric.spec;
    final colors = scheme.tone(spec.tone);
    final neutral = spec.tone == Tone.neutral;
    return M3EListItem(
      leading: ShapeBadge(
        shape: spec.shape,
        icon: spec.icon,
        size: 44,
        color: neutral ? scheme.secondaryContainer : colors.accent,
        iconColor: neutral ? scheme.onSecondaryContainer : scheme.surfaceBright,
      ),
      headline: Text(metric.title(formats.l10n)),
      supportingText: Text(formats.shortDate(snapshot.dateAt(index))),
      trailing: Text(
        metric.formatWithUnit(formats, snapshot.value(metric, index)),
        style: context.emphasizedTextTheme.titleMedium,
      ),
    );
  }
}
