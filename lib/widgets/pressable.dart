import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../app/haptics.dart';
import '../theme/app_motion.dart';

/// Squeezes its child while a pointer is down and springs back on release.
///
/// It only observes pointers, so the child keeps its own tap handling.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.pressedScale = 0.95});

  final Widget child;
  final double pressedScale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed == value) return;
    // Felt on touch down, together with the squeeze.
    if (value) Haptics.tap();
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: SingleMotionBuilder(
        value: _pressed ? widget.pressedScale : 1,
        motion: AppMotion.spatialFast,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: widget.child,
      ),
    );
  }
}
