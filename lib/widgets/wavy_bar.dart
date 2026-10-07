import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../theme/app_motion.dart';

/// A share of something as the wavy line of Material 3 Expressive. It grows
/// from nothing when it appears and follows the value on a spring.
class WavyBar extends StatelessWidget {
  const WavyBar({super.key, required this.value, this.color});

  /// From 0 to 1.
  final double value;

  /// The theme's primary when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleMotionBuilder(
      from: 0,
      value: value.clamp(0, 1).toDouble(),
      // An effects spring: a bar that overshoots would show more than is.
      motion: AppMotion.effectsSlow,
      builder: (context, current, _) => M3ELinearWavyProgressIndicator(
        value: current.clamp(0, 1).toDouble(),
        color: color ?? scheme.primary,
        backgroundColor: scheme.surfaceContainerHighest,
      ),
    );
  }
}
