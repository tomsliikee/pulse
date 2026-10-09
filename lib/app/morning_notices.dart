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
}
