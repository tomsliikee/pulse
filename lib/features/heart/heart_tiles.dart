import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../../app/app_scope.dart';
import '../../app/container_route.dart';
import '../../app/formatters.dart';
import '../../data/heart_day.dart';
import '../../data/models.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_type.dart';
import '../../widgets/page_header.dart';
import '../../widgets/segment_group.dart';
import 'heart_detail_page.dart';

/// Opens the page about the pulse of the day the Herz page shows, growing it
/// out of the rectangle [origin] of what was tapped.
void openHeartDay(BuildContext context, Rect origin) {
  Navigator.of(context).push(
    ContainerRoute<void>(
      origin: origin,
      originColor: Theme.of(context).colorScheme.surfaceBright,
      originRadius: AppRadii.extraLargeIncreased,
      builder: (_) =>
          HeartDetailPage(date: AppScope.of(context).health.selectedDate),
    ),
  );
}

/// How long the heart spent in each zone, one row a zone, the one with the
/// most time the loud one.
class HeartZones extends StatelessWidget {
  const HeartZones({super.key, required this.samples});

  final List<HeartSample> samples;

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
    for (final value in minutes) {
      if (value > longest) longest = value;
    }

    final type = AppType.of(context);
    // The zone most of the day was spent in is the loud one.
    final most = minutes.indexOf(longest);
    return SegmentGroup(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      loud: most < 0 ? null : most,
      children: [
        for (var i = 0; i < zones.length; i++)
          SizedBox(
            height: _row,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                      formats.duration(minutes[i]),
                      style: type.figure(
                        context.emphasizedTextTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _ZoneBar(
                  fraction: minutes[i] / longest,
                  color: zones[i].color,
                  trackColor: scheme.onSurface.withValues(alpha: 0.08),
                ),
              ],
            ),
          ),
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
