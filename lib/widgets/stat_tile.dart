import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../app/layout.dart';
import '../theme/app_shapes.dart';
import '../theme/app_theme.dart';
import 'pressable.dart';
import 'shape_badge.dart';
import 'tile_surface.dart';

/// A compact tile: shaped icon, a value and what it measures.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.shape,
    this.tone = Tone.neutral,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Shapes shape;
  final Tone tone;

  /// Receives the tile's rectangle on screen, like [MetricCard.onTap].
  final void Function(Rect origin)? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = scheme.tone(tone);
    final neutral = tone == Tone.neutral;
    final onTap = this.onTap;
    return Pressable(
      child: TileSurface(
        color: colors.container,
        radius: AppRadii.largeIncreased + 4,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  final origin = globalRectOf(context);
                  if (origin != null) onTap(origin);
                },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShapeBadge(
                  shape: shape,
                  icon: icon,
                  size: 36,
                  color: neutral ? scheme.secondaryContainer : colors.accent,
                  iconColor: neutral
                      ? scheme.onSecondaryContainer
                      : colors.container,
                ),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: context.emphasizedTextTheme.titleLarge?.copyWith(
                      color: colors.onContainer,
                    ),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onContainer.withValues(alpha: 0.72),
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

/// A plain surface tile that groups a chart with its caption.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return TileSurface(
      color: Theme.of(context).colorScheme.surfaceBright,
      radius: AppRadii.extraLargeIncreased,
      padding: padding ?? const EdgeInsets.all(20),
      child: child,
    );
  }
}
