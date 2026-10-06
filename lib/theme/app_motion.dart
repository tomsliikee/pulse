import 'package:motor/motor.dart';

/// The Material 3 Expressive spring tokens used by this app.
///
/// Spatial springs move, scale and morph things and may overshoot. Effects
/// springs drive colour, opacity and numbers and never overshoot.
abstract final class AppMotion {
  static const Motion spatialFast =
      MaterialSpringMotion.expressiveSpatialFast();
  static const Motion spatial = MaterialSpringMotion.expressiveSpatialDefault();
  static const Motion spatialSlow =
      MaterialSpringMotion.expressiveSpatialSlow();
  static const Motion effects = MaterialSpringMotion.expressiveEffectsDefault();
  static const Motion effectsSlow =
      MaterialSpringMotion.expressiveEffectsSlow();
}
