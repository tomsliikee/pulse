import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/layout.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_type.dart';
import '../../theme/page_accent.dart';
import '../../widgets/pressable.dart';
import '../../widgets/shape_badge.dart';
import '../../widgets/tile_surface.dart';
import 'link_card.dart';
import 'link_format.dart';
import 'links_page.dart';

/// The strongest connection in the user's numbers on the Today page, and
/// the way to all of them.
class LinksTile extends StatelessWidget {
  const LinksTile({super.key});

  static const double height = 96;

  /// The height in simple mode, where the strongest link shows its two
  /// bars; without a link the tile is the row it always was.
  static double heightFor({required bool simple, required bool hasLink}) =>
      simple && hasLink ? 236 : height;

  // The board holds this tile as a constant, so it listens for itself.
  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        scope.health,
        scope.settings,
        scope.supplements,
      ]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final formats = Formats.of(context);
        final l10n = formats.l10n;
        final accent = PageAccent.colorsOf(context);
        final type = AppType.of(context);
        // The rework fills the mark in the strong tone.
        final mark = type.expressive ? accent.accent : accent.container;
        final onMark = type.expressive ? accent.onAccent : accent.onContainer;
        final links = linksOf(
          scope.health,
          scope.settings,
          scope.supplements.data,
        );
        if (scope.settings.simple && links.isNotEmpty) {
          return Pressable(
            pressedScale: 0.98,
            child: TileSurface(
              color: scheme.surfaceBright,
              radius: AppRadii.extraLarge,
              child: Material(
                type: MaterialType.transparency,
                child: Builder(
                  builder: (context) => InkWell(
                    onTap: () {
                      final origin = globalRectOf(context);
                      if (origin != null) openLinks(context, origin);
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              ShapeBadge(
                                shape: Shapes.l4LeafClover,
                                icon: Icons.link_rounded,
                                size: 36,
                                color: mark,
                                iconColor: onMark,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  type.caps(l10n.linksTitle),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: type.capsLabel(
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
                          const Spacer(),
                          LinkCard(link: links.first, plain: true),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return Pressable(
          pressedScale: 0.98,
          child: TileSurface(
            color: scheme.surfaceBright,
            radius: AppRadii.extraLarge,
            child: Material(
              type: MaterialType.transparency,
              child: Builder(
                builder: (context) => InkWell(
                  onTap: () {
                    final origin = globalRectOf(context);
                    if (origin != null) openLinks(context, origin);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        ShapeBadge(
                          shape: Shapes.l4LeafClover,
                          icon: Icons.link_rounded,
                          size: 40,
                          color: mark,
                          iconColor: onMark,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.linksTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: type.strong(
                                  type.expressive
                                      ? theme.textTheme.titleMedium
                                      : theme.textTheme.titleSmall,
                                ),
                              ),
                              Text(
                                links.isEmpty
                                    ? l10n.linksTileEmpty
                                    : linkSentence(formats, links.first),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
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
              ),
            ),
          ),
        );
      },
    );
  }
}
