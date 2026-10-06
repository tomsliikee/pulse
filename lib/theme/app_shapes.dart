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
  static const List<Shapes> scoreCycle = [
    Shapes.c9SidedCookie,
    Shapes.l8LeafClover,
    Shapes.softBurst,
    Shapes.puffy,
    Shapes.gem,
  ];
}
