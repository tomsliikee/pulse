import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'glass_scope.dart';

/// The filled, rounded surface every tile sits on. Inside a [GlassScope] it
/// is translucent glass tinted with [color]; everywhere else it is plain Material.
class TileSurface extends StatelessWidget {
  const TileSurface({
    super.key,
    required this.color,
    required this.radius,
    required this.child,
    this.padding,
  });

  final Color color;
  final double radius;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final padding = this.padding;
    final child = padding == null
        ? this.child
        : Padding(padding: padding, child: this.child);
    if (!GlassScope.isOn(context)) {
      return Material(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }
    return Material(
      color: color.withValues(alpha: GlassScope.tintOpacity),
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(radius),
        side: const BorderSide(color: AppTheme.glassRim),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
