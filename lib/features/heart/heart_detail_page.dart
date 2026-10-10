import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../data/heart_day.dart';
import '../../data/metric_catalog.dart';
import '../../data/models.dart';
import '../../theme/app_type.dart';
import '../../theme/page_accent.dart';
import '../../widgets/entrance.dart';
import '../../widgets/page_header.dart';
import '../../widgets/section_card.dart';
import '../../widgets/segment_group.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/sub_page.dart';
import '../detail/metric_spec.dart';
import 'heart_curve.dart';
import 'heart_tiles.dart';

/// The pulse of one day in detail: how far it ranged, its curve to hold and
/// read, the time in each zone, and the day hour by hour.
class HeartDetailPage extends StatelessWidget {
  const HeartDetailPage({super.key, required this.date});

  final DateTime date;

  static const double _curveHeight = 240;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    return PageAccent.heart(
      child: ListenableBuilder(
        listenable: Listenable.merge([health, scope.settings]),
        builder: (context, _) {
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          final formats = Formats.of(context);
          final l10n = formats.l10n;
          final type = AppType.of(context);
          final snapshot = health.snapshot;
          // The curve only as far as the snapshot reaches.
          final index = snapshot.indexOf(date);
          final samples = index == null
              ? const <HeartSample>[]
              : snapshot.heart[index];
          final summary = heartSummary(samples);
          final hours = heartHours(samples);

          Widget figure(String label, int bpm) => Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: type.strong(theme.textTheme.titleSmall),
                ),
              ),
              Text(
                Metric.heartRate.formatWithUnit(formats, bpm.toDouble()),
                style: type.figure(context.emphasizedTextTheme.titleMedium),
              ),
            ],
          );

          final sections = <Widget>[
            if (summary == null || samples.length < 2)
              SurfaceCard(child: EmptyNote(l10n.noHeartCurve))
            else ...[
              SegmentGroup(
                children: [
                  figure(l10n.lowest, summary.low),
                  figure(l10n.heartAverage, summary.average),
                  figure(l10n.highest, summary.high),
                ],
              ),
              SectionCard(
                title: l10n.dayCurve,
                padding: EdgeInsets.zero,
                child: SizedBox(
                  height: _curveHeight,
                  child: HeartCurve(samples: samples, day: date),
                ),
              ),
              TitledSection(
                title: l10n.timeInZones,
                child: HeartZones(samples: samples),
              ),
              TitledSection(
                title: l10n.hourByHour,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, hour) in hours.indexed)
                      ListSegment(
                        first: i == 0,
                        last: i == hours.length - 1,
                        child: _HourRow(hour: hour),
                      ),
                  ],
                ),
              ),
            ],
          ];

          return SubPage(
            title: l10n.heartInDetail,
            glass: scope.settings.liquidGlass,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                  child: Text(
                    formats.longDate(date),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (var i = 0; i < sections.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  Entrance(order: i, child: sections[i]),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One hour of the day: when it was, how far the pulse ranged in it and,
/// at the end, its average.
class _HourRow extends StatelessWidget {
  const _HourRow({required this.hour});

  final HeartHour hour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.rangeFromTo(
                    formatClockHour(hour.hour),
                    formatClockHour(hour.hour + 1),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  hour.low == hour.high
                      ? Metric.heartRate.formatWithUnit(
                          formats,
                          hour.low.toDouble(),
                        )
                      : l10n.bpmRange(hour.low, hour.high),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            l10n.averageValue(
              Metric.heartRate.formatWithUnit(formats, hour.average.toDouble()),
            ),
            style: AppType.of(context)
                .figure(context.emphasizedTextTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}
