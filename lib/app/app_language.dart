import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/settings_controller.dart';

/// Which language the app is shown in.
///
/// Since Android 13 the system keeps a language per app and offers it in its
/// own settings. There it is the only place the choice lives, so the system's
/// page and the profile always agree. Elsewhere the choice is a setting.
class LanguageController extends ChangeNotifier {
  LanguageController(this._settings) {
    _settings.addListener(_onSettings);
  }

  static const MethodChannel _channel = MethodChannel(
    'at.haiden.pulse/language',
  );

  final SettingsController _settings;
  bool _disposed = false;
  bool _bySystem = false;
  String? _systemChoice;

  /// The chosen language, or null to follow the system.
  String? get choice => _bySystem ? _systemChoice : _settings.language;

  /// The language the app has to force. Null where the system applies the
  /// choice itself, and when there is none.
  String? get forced => _bySystem ? null : _settings.language;

  /// Reads the system's choice. Called at start and whenever the app comes
  /// back to the front, because the system's settings may have changed it.
  Future<void> refresh() async {
    Object? answer;
    try {
      answer = await _channel.invokeMethod<Object?>('get');
    } on MissingPluginException {
      answer = null;
    } on PlatformException catch (error) {
      debugPrint('Reading the app language failed: $error');
      answer = null;
    }
    if (_disposed) return;
    // No answer: this system keeps no language per app.
    final bySystem = answer is Map<Object?, Object?>;
    final language = bySystem ? answer['language'] : null;
    final choice = language is String && appLanguages.contains(language)
        ? language
        : null;
    if (bySystem == _bySystem && choice == _systemChoice) return;
    _bySystem = bySystem;
    _systemChoice = choice;
    notifyListeners();
  }

  Future<void> choose(String? language) async {
    if (language != null && !appLanguages.contains(language)) return;
    if (!_bySystem) {
      _settings.setLanguage(language);
      return;
    }
    try {
      await _channel.invokeMethod<void>('set', language);
    } on PlatformException catch (error) {
      debugPrint('Setting the app language failed: $error');
      return;
    }
    if (_disposed) return;
    _systemChoice = language;
    notifyListeners();
  }

  void _onSettings() {
    if (!_bySystem) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _settings.removeListener(_onSettings);
    super.dispose();
  }
}
