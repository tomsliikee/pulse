import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'glass_scope.dart';
import 'pressable.dart';

/// The filled, rounded surface every tile sits on. Inside a [GlassScope] it
/// is translucent glass tinted with [color]; everywhere else it is plain
/// Material. While the [Pressable] around it is held, its corners tighten.
class TileSurface extends StatelessWidget {
  const TileSurface({
    super.key,
    required this.color,
    required this.radius,
    required this.child,
    this.padding,
    this.corners,
    this.opaque = false,
  });

  final Color color;
  final double radius;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Corners that differ from one another; [radius] on all four when null.
  final BorderRadius? corners;

  /// Stays a solid colour inside a [GlassScope] too, for a tile whose colour
  /// is its point.
  final bool opaque;

  /// How much of a corner's radius a full press takes away.
  static const double _tighten = 0.35;

  @override
  Widget build(BuildContext context) {
    final padding = this.padding;
    final child = padding == null
        ? this.child
        : Padding(padding: padding, child: this.child);
    final corners =
        (this.corners ?? BorderRadius.circular(radius)) *
        (1 - _tighten * PressState.of(context).clamp(0, 1));
    if (opaque || !GlassScope.isOn(context)) {
      return Material(
        color: color,
        borderRadius: corners,
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }
    return Material(
      color: color.withValues(alpha: GlassScope.tintOpacity),
      shape: RoundedSuperellipseBorder(
        borderRadius: corners,
        side: const BorderSide(color: AppTheme.glassRim),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
