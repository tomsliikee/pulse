import 'package:flutter/services.dart';

/// Lets the user keep a text as a file of their own, and pick one again.
abstract interface class BackupFiles {
  /// Asks where to keep [text] under [name]. False when the user backs out.
  Future<bool> save(String name, String text);

  /// Asks for a file and returns its text, or null when the user backs out.
  Future<String?> open();
}

/// The system's own file dialogs on Android. Needs no permission: the user
/// picks the one file the app may touch.
class SystemBackupFiles implements BackupFiles {
  const SystemBackupFiles();

  static const MethodChannel _channel = MethodChannel('at.haiden.pulse/files');

  @override
  Future<bool> save(String name, String text) async =>
      await _channel.invokeMethod<bool>('save', {'name': name, 'text': text}) ??
      false;

  @override
  Future<String?> open() => _channel.invokeMethod<String>('open');
}
