import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../app/haptics.dart';
import '../theme/app_motion.dart';

/// How far the [Pressable] around a widget is pressed in, from 0 to 1 and a
/// little beyond while its spring settles. Surfaces tighten their corners
/// with it and numbers grow a grade bolder.
class PressState extends InheritedWidget {
  const PressState({super.key, required this.pressed, required super.child});

  final double pressed;

  /// Zero where nothing around [context] can be pressed.
  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PressState>()?.pressed ?? 0;

  @override
  bool updateShouldNotify(PressState oldWidget) => oldWidget.pressed != pressed;
}

/// Squeezes its child while a pointer is down and springs back on release.
/// What is inside can follow the press through [PressState].
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
        value: _pressed ? 1 : 0,
        motion: AppMotion.spatialFast,
        builder: (context, pressed, child) => Transform.scale(
          scale: 1 - (1 - widget.pressedScale) * pressed,
          child: PressState(pressed: pressed, child: child!),
        ),
        child: widget.child,
      ),
    );
  }
}
