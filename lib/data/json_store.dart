import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Small named JSON documents kept on the device.
abstract interface class JsonStore {
  /// The decoded document, or null if it is missing or unreadable.
  Future<Object?> read(String name);

  Future<void> write(String name, Object? json);

  Future<void> delete(String name);

  /// The names of all stored documents.
  Future<List<String>> names();
}

/// The names of the documents the app keeps.
abstract final class StoreKeys {
  static const String snapshot = 'snapshot';
  static const String settings = 'settings';
  static const String backfill = 'backfill';
  static const String workouts = 'workouts';
  static const String workoutBackfill = 'workoutBackfill';
  static const String nightBackfill = 'nightBackfill';
}

class FileJsonStore implements JsonStore {
  const FileJsonStore(this.directory);

  final Directory directory;

  /// The app's private support directory. Nothing in it leaves the device.
  static Future<FileJsonStore> open() async =>
      FileJsonStore(await getApplicationSupportDirectory());

  File _file(String name) => File('${directory.path}/$name.json');

  @override
  Future<Object?> read(String name) async {
    try {
      final file = _file(name);
      if (!await file.exists()) return null;
      return jsonDecode(await file.readAsString());
    } on FileSystemException {
      return null;
    } on FormatException {
      // A half-written or damaged file is treated as absent.
      return null;
    }
  }

  @override
  Future<void> write(String name, Object? json) async {
    await directory.create(recursive: true);
    // Written next to the target and renamed over it: the rename is atomic,
    // so an interrupted write never leaves a broken document behind. The app
    // and the background task may both write the snapshot.
    final temp = File('${directory.path}/$name.json.$pid.tmp');
    await temp.writeAsString(jsonEncode(json), flush: true);
    await temp.rename(_file(name).path);
  }

  @override
  Future<void> delete(String name) async {
    try {
      await _file(name).delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  @override
  Future<List<String>> names() async {
    if (!await directory.exists()) return const [];
    const suffix = '.json';
    return [
      await for (final entity in directory.list())
        if (entity is File && entity.path.endsWith(suffix))
          entity.uri.pathSegments.last.replaceFirst(RegExp(r'\.json$'), ''),
    ];
  }
}
