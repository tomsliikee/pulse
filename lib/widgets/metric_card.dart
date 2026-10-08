import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../app/layout.dart';
import '../theme/app_shapes.dart';
import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import 'pressable.dart';
import 'shape_badge.dart';
import 'tile_surface.dart';

/// A tile showing one measurement: a shaped icon, a label, a large value and
/// an optional footer such as a small chart.
///
/// [onTap] receives the tile's rectangle on screen so the caller can grow the
/// next page out of it.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.shape,
    this.unit,
    this.tone = Tone.neutral,
    this.footer,
    this.trailing,
    this.onTap,
    this.height = 176,
  });

  final String label;
  final Widget value;
  final String? unit;
  final IconData icon;
  final Shapes shape;
  final Tone tone;
  final Widget? footer;

  /// Sits at the end of the title row, e.g. a small progress ring.
  final Widget? trailing;
  final void Function(Rect origin)? onTap;
  final double height;

  void _handleTap(BuildContext context) {
    final origin = globalRectOf(context);
    if (origin != null) onTap?.call(origin);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = scheme.tone(tone);
    final neutral = tone == Tone.neutral;
    final unit = this.unit;
    final footer = this.footer;

    return Pressable(
      child: TileSurface(
        color: colors.container,
        radius: AppRadii.extraLarge,
        child: InkWell(
          onTap: onTap == null ? null : () => _handleTap(context),
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ShapeBadge(
                        shape: shape,
                        icon: icon,
                        size: 44,
                        color: neutral
                            ? scheme.secondaryContainer
                            : colors.accent,
                        iconColor: neutral
                            ? scheme.onSecondaryContainer
                            : colors.container,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colors.onContainer,
                          ),
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: DefaultTextStyle.merge(
                          style: AppType.of(context).figure(
                            context.emphasizedTextTheme.headlineLarge?.copyWith(
                              color: colors.onContainer,
                            ),
                          ),
                          child: value,
                        ),
                      ),
                      if (unit != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          unit,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colors.onContainer.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (footer != null) ...[const SizedBox(height: 10), footer],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
