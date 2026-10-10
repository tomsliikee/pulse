import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/formatters.dart';
import '../../app/layout.dart';
import '../../data/metric_catalog.dart';
import '../../data/sleep_insights.dart';
import '../../theme/app_theme.dart';
import 'metric_spec.dart';

/// One measurement of a day against what is usual for this person. Opens
/// the measurement's own page.
class UsualValueRow extends StatelessWidget {
  const UsualValueRow({
    super.key,
    required this.metric,
    required this.value,
    required this.usual,
    required this.missing,
  });

  final Metric metric;
  final double? value;
  final (double, double)? usual;

  /// Said where the day has no [value].
  final String missing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final spec = metric.spec;
    final value = this.value;
    final usual = this.usual;
    final String note;
    if (value == null) {
      note = missing;
    } else if (usual == null) {
      note = l10n.tooFewValues;
    } else {
      final span = l10n.rangeFromTo(
        metric.format(formats, usual.$1),
        metric.formatWithUnit(formats, usual.$2),
      );
      note = switch (verdictOf(value, usual)) {
        RangeVerdict.below => l10n.belowUsual(span),
        RangeVerdict.within => l10n.withinUsual(span),
        RangeVerdict.above => l10n.aboveUsual(span),
      };
    }
    return InkWell(
      onTap: () {
        final origin = globalRectOf(context);
        if (origin != null) openMetric(context, metric, origin);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(spec.icon, color: scheme.tone(spec.tone).accent),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(metric.title(l10n), style: theme.textTheme.titleSmall),
                  Text(
                    note,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              metric.formatWithUnit(formats, value),
              style: context.emphasizedTextTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
