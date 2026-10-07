import 'package:m3e_core/m3e_core.dart';

/// Corner radii from the Material 3 Expressive shape scale.
abstract final class AppRadii {
  static const double medium = 12;
  static const double large = 16;
  static const double largeIncreased = 20;
  static const double extraLarge = 28;
  static const double extraLargeIncreased = 32;
  static const double extraExtraLarge = 48;
}

/// Shape sequences for elements that morph when tapped.
abstract final class AppShapes {
  /// The shape a score from 1 to 100 is shown on: the rounder, the better.
  static Shapes ofScore(int? score) => score == null
      ? Shapes.circle
      : scoreCycle[((100 - score) ~/ 20).clamp(0, scoreCycle.length - 1)];

  static const List<Shapes> scoreCycle = [
    Shapes.c9SidedCookie,
    Shapes.l8LeafClover,
    Shapes.softBurst,
    Shapes.puffy,
    Shapes.gem,
  ];
}
