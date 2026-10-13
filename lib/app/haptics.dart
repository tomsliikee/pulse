import 'package:flutter/services.dart';
import 'package:m3e_core/m3e_core.dart'
    show M3EHapticConfig, M3EHapticFeedback, applyTypedHaptic;

/// The app's haptic signals, so their strength is decided in one place.
///
/// Android only plays them while "touch feedback" is enabled in the system
/// settings; the app does not override that choice.
abstract final class Haptics {
  /// Whether the app gives any signal at all; the user's choice in the
  /// profile, kept here by the app as the settings change.
  static bool enabled = true;

  /// A selection changed: destination, day, range, chart bar, slider step.
  static void selection() {
    if (enabled) HapticFeedback.selectionClick();
  }

  /// Something was pressed that opens or toggles.
  static void tap() {
    if (enabled) HapticFeedback.lightImpact();
  }

  /// A tile was picked up.
  static void lift() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  /// An action went through: saved, deleted, refreshed.
  static void confirm() {
    if (enabled) HapticFeedback.heavyImpact();
  }

  /// What a widget of the component library plays by itself when pressed.
  static M3EHapticFeedback get widget =>
      enabled ? M3EHapticFeedback.light : M3EHapticFeedback.none;

  /// One step of something dragged along a scale, felt by where on the
  /// scale it is: faint at the bottom ([strength] 0), firm at the top (1).
  /// Called for a step taken, never for a finger that rests.
  static void scaled(double strength) {
    if (!enabled) return;
    applyTypedHaptic(
      'tickCrossing',
      _faintest + (1 - _faintest) * strength.clamp(0, 1),
    );
  }

  /// The amplitude of the faintest step, of 1.
  static const double _faintest = 0.15;

  /// The same scale for a slider, which ticks by itself: once for each step
  /// its thumb crosses and once at either end.
  static M3EHapticConfig get slider => enabled ? _slider : _silent;

  /// Nothing at the ends either; the steps go with [widget].
  static const M3EHapticConfig _silent = M3EHapticConfig(
    enableContinuousDrag: false,
    vibrateOnLowerBookend: false,
    vibrateOnUpperBookend: false,
  );

  static const M3EHapticConfig _slider = M3EHapticConfig(
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
