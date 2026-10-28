import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The system's consent to the morning's notification.
abstract final class MorningNotices {
  static const MethodChannel _channel = MethodChannel(
    'at.haiden.pulse/morning',
  );

  /// Asks for it where the system wants to be asked (Android 13 and later)
  /// and says whether notifications may be shown. False where there is no
  /// such thing, as on the desktop and in tests.
  static Future<bool> allow() async {
    try {
      return await _channel.invokeMethod<bool>('allow') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      debugPrint('Asking for notifications failed: $error');
      return false;
    }
  }

  /// Whether notifications may be shown, without asking for it.
  static Future<bool> allowed() async {
    try {
      return await _channel.invokeMethod<bool>('allowed') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      debugPrint('Asking whether notifications are allowed failed: $error');
      return false;
    }
  }

  /// Whether Android lets the app highlight live messages. True where the
  /// platform knows no such thing, as there is nothing to ask for.
  static Future<bool> promotable() async {
    try {
      return await _channel.invokeMethod<bool>('promotable') ?? true;
    } on MissingPluginException {
      return true;
    } on PlatformException catch (error) {
      debugPrint('Asking whether live messages are allowed failed: $error');
      return true;
    }
  }

  /// Opens the system's setting for live messages.
  static Future<void> openPromotionSettings() async {
    try {
      await _channel.invokeMethod<void>('promotionSettings');
    } on MissingPluginException {
      // No such thing on the desktop and in tests.
    } on PlatformException catch (error) {
      debugPrint('Opening the setting for live messages failed: $error');
    }
  }

  /// What the notification the app was opened from was about ("week"), or
  /// null when it was opened another way. Told once.
  static Future<String?> opened() async {
    try {
      return await _channel.invokeMethod<String>('opened');
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      debugPrint('Asking what was opened failed: $error');
      return null;
    }
  }

  /// Has the platform set its alarms anew by what the app left for them.
  static Future<void> schedule() async {
    try {
      await _channel.invokeMethod<void>('schedule');
    } on MissingPluginException {
      // No such thing on the desktop and in tests.
    } on PlatformException catch (error) {
      debugPrint('Setting the morning alarm failed: $error');
    }
  }
}
