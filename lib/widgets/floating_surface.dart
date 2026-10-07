import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:material_ui/material_ui.dart';

import 'glass_rim.dart';
import 'glass_scope.dart';

/// A pill that floats over a page: a round button, or a short label. As wide
/// as its [child], which is painted on it and stays sharp.
class FloatingSurface extends StatelessWidget {
  const FloatingSurface({
    super.key,
    this.glass = false,
    this.color,
    this.glassTint,
    required this.child,
  });

  /// Draws the pill as liquid glass that bends the page scrolling under it.
  final bool glass;

  /// The fill without glass; the colour of the navigation bar when null.
  final Color? color;

  /// The colour of the glass; the light veil of a bar when null.
  final Color? glassTint;

  final Widget child;

  static const double height = 48;
  static const double _radius = height / 2;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!glass) {
      return SizedBox(
        height: height,
        child: Material(
          color: color ?? scheme.surfaceContainerHighest,
          shape: const StadiumBorder(),
          elevation: 3,
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      );
    }
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          const Positioned.fill(child: GlassShadow(radius: _radius)),
          Positioned.fill(
            child: LiquidGlass.withOwnLayer(
              settings: GlassScope.barSettings.copyWith(
                glassColor: glassTint ?? GlassScope.barTint(scheme),
              ),
              shape: const LiquidRoundedRectangle(borderRadius: _radius),
              child: const GlassRim(radius: _radius),
            ),
          ),
          Material(
            type: MaterialType.transparency,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ],
      ),
    );
  }
}
