import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/layout.dart';
import '../../data/night_insights.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_type.dart';
import '../../widgets/pressable.dart';
import '../../widgets/tile_surface.dart';
import '../today/day_format.dart';
import 'morning_format.dart';
import 'morning_page.dart';

/// Says good morning on the Today page and opens the morning's cards: the
/// way back to them once they have closed.
class MorningTile extends StatelessWidget {
  const MorningTile({super.key});

  static const double height = 88;

  // The board holds this tile as a constant, so it listens for itself.
  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        scope.health,
        scope.settings,
        scope.weather,
      ]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final formats = Formats.of(context);
        final l10n = formats.l10n;
        final type = AppType.of(context);
        final health = scope.health;
        final settings = scope.settings;
        final weather = scope.weather.weather;
        final night = dayInsightsOf(health, settings, health.today).night;
        final line = [
          if (weather != null)
            '${degrees(l10n, weather.temperature)} ${weather.sky.label(l10n)}',
          if (night != null)
            '${formats.duration(night.asleepMinutes)} · ${l10n.scoreShort} '
                '${sleepScore(night, settings.sleepGoalHours, health.nights).total}',
        ].join(' · ');
        return Pressable(
          pressedScale: 0.98,
          child: TileSurface(
            color: scheme.primaryContainer,
            opaque: true,
            radius: AppRadii.extraLarge,
            child: Material(
              type: MaterialType.transparency,
              child: Builder(
                builder: (context) => InkWell(
                  onTap: () {
                    final origin = globalRectOf(context);
                    if (origin != null) openMorning(context, origin: origin);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(
                          weather?.sky.icon ?? Icons.wb_twilight_rounded,
                          size: 32,
                          color: scheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                morningGreeting(l10n, settings.name),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: type.title(
                                  theme.textTheme.titleMedium?.copyWith(
                                    color: scheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              Text(
                                line.isEmpty ? l10n.morningOpen : line,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onPrimaryContainer,
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
