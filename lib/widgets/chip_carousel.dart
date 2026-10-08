import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../app/layout.dart';
import '../theme/app_shapes.dart';
import '../theme/app_type.dart';
import '../theme/page_accent.dart';
import 'entrance.dart';
import 'page_header.dart';
import 'pressable.dart';
import 'shape_badge.dart';
import 'tile_surface.dart';

/// A few small cards to swipe through under a free title. The last one is
/// usually a [CarouselEndChip], the way to everything.
class ChipCarousel extends StatelessWidget {
  const ChipCarousel({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  static const double _title = 48;
  static const double cardHeight = 164;
  static const double cardWidth = 136;

  static const double height = _title + cardHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _title,
          child: SectionTitle(
            title,
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          ),
        ),
        SizedBox(
          height: cardHeight,
          // Few enough to build at once, so the way to everything is there
          // for a screen reader before anybody swipes.
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            // Not clipped: the cards run out to the edge of the screen.
            clipBehavior: Clip.none,
            child: Row(
              spacing: 10,
              children: [
                for (final (index, child) in children.indexed)
                  SizedBox(
                    width: cardWidth,
                    child: Entrance(order: index + 1, child: child),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One card of a [ChipCarousel]: a small picture, a mark that hangs over
/// the picture's edge, and two lines below.
class CarouselChip extends StatelessWidget {
  const CarouselChip({
    super.key,
    required this.picture,
    required this.mark,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  /// [pictureHeight] high.
  final Widget picture;

  /// [markSize] in both directions.
  final Widget mark;
  final String title;
  final String subtitle;

  /// Given the card's rectangle on the screen, for a page that grows out
  /// of it.
  final ValueChanged<Rect> onTap;

  static const double pictureHeight = 76;
  static const double markSize = 48;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final type = AppType.of(context);
    return Pressable(
      child: TileSurface(
        color: scheme.surfaceBright,
        radius: AppRadii.extraLarge,
        child: Builder(
          builder: (context) => InkWell(
            onTap: () {
              final origin = globalRectOf(context);
              if (origin != null) onTap(origin);
            },
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: pictureHeight, child: picture),
                    const SizedBox(height: markSize / 2 + 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: type.strong(theme.textTheme.titleSmall),
                          ),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: type.label(
                              theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: 12,
                  top: pictureHeight - markSize / 2,
                  child: mark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A score on the shape its page shows scores on, as the mark of a
/// [CarouselChip].
class ScoreMark extends StatelessWidget {
  const ScoreMark({super.key, required this.score});

  final int? score;

  @override
  Widget build(BuildContext context) {
    final accent = PageAccent.colorsOf(context);
    final score = this.score;
    return M3EContainer(
      AppShapes.of(PageAccent.of(context).family, score),
      width: CarouselChip.markSize,
      height: CarouselChip.markSize,
      color: accent.accent,
      child: Text(
        score == null ? '–' : '$score',
        style: AppType.of(context).figure(
          context.emphasizedTextTheme.titleSmall?.copyWith(
            color: accent.onAccent,
          ),
        ),
      ),
    );
  }
}

/// The end of a carousel: the way to the list of everything, in the colour
/// of the page.
class CarouselEndChip extends StatelessWidget {
  const CarouselEndChip({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = AppType.of(context);
    final accent = PageAccent.colorsOf(context);
    return Pressable(
      child: TileSurface(
        color: accent.container,
        radius: AppRadii.extraLarge,
        opaque: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShapeBadge(
                  shape: Shapes.c9SidedCookie,
                  icon: Icons.arrow_forward_rounded,
                  size: 48,
                  color: accent.accent,
                  iconColor: accent.onAccent,
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: type.title(
                    context.emphasizedTextTheme.titleMedium?.copyWith(
                      color: accent.onContainer,
                    ),
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.label(
                    theme.textTheme.bodySmall?.copyWith(
                      color: accent.onContainer.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
