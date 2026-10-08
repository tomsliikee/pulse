import 'package:m3e_core/m3e_core.dart';

/// Corner radii from the Material 3 Expressive shape scale.
abstract final class AppRadii {
  /// The inner corners of segments that belong together.
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double largeIncreased = 20;
  static const double extraLarge = 28;
  static const double extraLargeIncreased = 32;
  static const double extraExtraLarge = 48;
}

/// The shapes a page shows its scores on. Each has five steps, from a plain
/// shape for a low score to its most pronounced one for a high score.
enum ShapeFamily {
  /// Sunny: cookies that grow rays.
  day([
    Shapes.circle,
    Shapes.c6SidedCookie,
    Shapes.c9SidedCookie,
    Shapes.sunny,
    Shapes.verySunny,
  ]),

  /// Soft: leaves and petals.
  sleep([
    Shapes.circle,
    Shapes.c4SidedCookie,
    Shapes.l4LeafClover,
    Shapes.l8LeafClover,
    Shapes.flower,
  ]),

  /// Angular: corners and spikes.
  activity([
    Shapes.square,
    Shapes.pentagon,
    Shapes.gem,
    Shapes.burst,
    Shapes.boom,
  ]),

  heart([
    Shapes.circle,
    Shapes.c7SidedCookie,
    Shapes.softBurst,
    Shapes.softBoom,
    Shapes.heart,
  ]);

  const ShapeFamily(this.steps);

  final List<Shapes> steps;
}

/// Shapes that stand for a value.
abstract final class AppShapes {
  /// The shape of [family] a score from 1 to 100 is shown on: the higher,
  /// the more pronounced. Without a score it is the family's plain shape.
  static Shapes of(ShapeFamily family, int? score) => score == null
      ? family.steps.first
      : family.steps[((score - 1) ~/ 20).clamp(0, family.steps.length - 1)];
}
