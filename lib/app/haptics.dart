import 'package:flutter/services.dart';

/// The app's four haptic signals, so their strength is decided in one place.
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
}
