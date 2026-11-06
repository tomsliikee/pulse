import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/pulse_look.dart';

/// [child] on an expressive shape, or in the Insights looks, which have no
/// such shapes, on a plain circle.
class LookShape extends StatelessWidget {
  const LookShape(
    this.shape, {
    super.key,
    required this.width,
    required this.height,
    required this.color,
    required this.child,
  });

  final Shapes shape;
  final double width;
  final double height;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (PulseLook.monoOf(context)) {
      return Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: child,
      );
    }
    return M3EContainer(
      shape,
      width: width,
      height: height,
      color: color,
      child: child,
    );
  }
}
