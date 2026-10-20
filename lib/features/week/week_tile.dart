import 'package:material_ui/material_ui.dart';
import 'package:m3e_core/m3e_core.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/layout.dart';
import '../../data/week_report.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_type.dart';
import '../../widgets/pressable.dart';
import '../../widgets/shape_badge.dart';
import '../../widgets/tile_surface.dart';
import 'week_page.dart';

/// Says on the Today page that the week's report is ready and opens it:
/// there from Sunday evening until Monday ends.
class WeekTile extends StatelessWidget {
  const WeekTile({super.key});

  static const double height = 88;

  // The board holds this tile as a constant, so it listens for itself.
  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.health, scope.settings]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final formats = Formats.of(context);
        final l10n = formats.l10n;
        final type = AppType.of(context);
        final health = scope.health;
        final report = weekReportOf(
          health,
          scope.settings,
          latestReportWeek(health.now),
        );
        final score = report.score;
        final previous = report.previousScore;
        final line = [
          formats.dayRange(report.monday, report.sunday),
          if (score != null) '${l10n.weekScore} $score',
          if (score != null && previous != null && score != previous)
            '${score > previous ? '+' : '−'}${(score - previous).abs()}',
        ].join(' · ');
        return Pressable(
          pressedScale: 0.98,
          child: TileSurface(
            color: scheme.tertiaryContainer,
            opaque: true,
            radius: AppRadii.extraLarge,
            blob: type.expressive ? 1 : null,
            child: Material(
              type: MaterialType.transparency,
              child: Builder(
                builder: (context) => InkWell(
                  onTap: () {
                    final origin = globalRectOf(context);
                    if (origin != null) openWeek(context, origin: origin);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        if (type.expressive)
                          ShapeBadge(
                            shape: Shapes.c7SidedCookie,
                            icon: Icons.calendar_month_rounded,
                            size: 48,
                            color: scheme.tertiary,
                            iconColor: scheme.onTertiary,
                          )
                        else
                          Icon(
                            Icons.calendar_view_week_rounded,
                            size: 32,
                            color: scheme.onTertiaryContainer,
                          ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.weekTileReady,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: type.title(
                                  theme.textTheme.titleMedium?.copyWith(
                                    color: scheme.onTertiaryContainer,
                                  ),
                                ),
                              ),
                              Text(
                                line,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onTertiaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onTertiaryContainer,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
