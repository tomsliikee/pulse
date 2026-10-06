import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import 'morphing_shape.dart';

/// An icon sitting in an expressive shape.
class ShapeBadge extends StatelessWidget {
  const ShapeBadge({
    super.key,
    required this.shape,
    required this.icon,
    required this.color,
    required this.iconColor,
    this.size = 48,
  });

  final Shapes shape;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return MorphingShape(
      shape: shape,
      color: color,
      size: size,
      child: Icon(icon, color: iconColor, size: size * 0.5),
    );
  }
}
