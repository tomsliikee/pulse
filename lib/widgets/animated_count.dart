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
    this.format,
  });

  final int value;
  final TextStyle? style;

  /// How a number is written; the language's whole number when null.
  final String Function(int value)? format;

  @override
  Widget build(BuildContext context) {
    final format = this.format ?? Formats.of(context).integer;
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

/// Like [AnimatedCount] for a number that is not whole or not written as
/// one: kilometres, or minutes shown as hours and minutes. [format] writes
/// every value on the way.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.format,
    this.style,
  });

  final double value;
  final String Function(double value) format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return SingleMotionBuilder(
      from: 0,
      value: value,
      motion: AppMotion.effectsSlow,
      builder: (context, current, _) =>
          Text(format(current), style: style, maxLines: 1, softWrap: false),
    );
  }
}
