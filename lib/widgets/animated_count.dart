import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../app/formatters.dart';
import '../theme/app_motion.dart';

/// Counts up to [value] when it appears and whenever the value changes.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.format = formatInt,
  });

  final int value;
  final TextStyle? style;
  final String Function(int value) format;

  @override
  Widget build(BuildContext context) {
    return SingleMotionBuilder(
      from: 0,
      value: value.toDouble(),
      // An effects spring: a number that overshoots would show a wrong value.
      motion: AppMotion.effectsSlow,
      builder: (context, current, _) => Text(
        format(current.round()),
        style: style,
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}
