import 'package:flutter/services.dart';
import 'package:m3e_core/m3e_core.dart' show M3EHapticConfig, applyTypedHaptic;

/// The app's haptic signals, so their strength is decided in one place.
///
/// Android only plays them while "touch feedback" is enabled in the system
/// settings; the app does not override that choice.
abstract final class Haptics {
  /// A selection changed: destination, day, range, chart bar, slider step.
  static void selection() => HapticFeedback.selectionClick();

  /// Something was pressed that opens or toggles.
  static void tap() => HapticFeedback.lightImpact();

  /// A tile was picked up.
  static void lift() => HapticFeedback.mediumImpact();

  /// An action went through: saved, deleted, refreshed.
  static void confirm() => HapticFeedback.heavyImpact();

  /// One step of something dragged along a scale, felt by where on the
  /// scale it is: faint at the bottom ([strength] 0), firm at the top (1).
  /// Called for a step taken, never for a finger that rests.
  static void scaled(double strength) => applyTypedHaptic(
    'tickCrossing',
    _faintest + (1 - _faintest) * strength.clamp(0, 1),
  );

  /// The amplitude of the faintest step, of 1.
  static const double _faintest = 0.15;

  /// The same scale for a slider, which ticks by itself: once for each step
  /// its thumb crosses and once at either end.
  static const M3EHapticConfig slider = M3EHapticConfig(
    enableContinuousDrag: false,
    deltaProgressForDragThreshold: 0,
    lowerBookendThreshold: 0,
    upperBookendThreshold: 1,
    progressBasedDragMinScale: _faintest,
    progressBasedDragMaxScale: 1,
    additionalVelocityMaxBump: 0,
    minimumDragInterval: Duration.zero,
  );
}
