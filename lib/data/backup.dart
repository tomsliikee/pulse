import 'dart:convert';

import 'health_history.dart';
import 'json_store.dart';
import 'night_archive.dart';
import 'routes.dart';
import 'supplements.dart';
import 'workout_archive.dart';

/// What reading a backup added to the app's own data.
typedef BackupResult = ({int days, int nights, int workouts, bool settings});

const String _app = 'pulse';
const int _version = 1;
const String _historyPrefix = 'history-';
const String _nightsPrefix = 'nights-';

bool _kept(String name) =>
    name.startsWith(_historyPrefix) ||
    name.startsWith(_nightsPrefix) ||
    name.startsWith(RouteArchive.prefix) ||
    name == StoreKeys.workouts ||
    name == StoreKeys.supplements ||
    name == StoreKeys.settings;

/// The name a backup made at [now] is offered under.
String backupFileName(DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'pulse-backup-${now.year}-${two(now.month)}-${two(now.day)}.json';
}

/// Everything that cannot be read again from the health store, as one JSON
/// text: the years of the history, the nights, the workouts with their
/// routes, the supplements and the settings, each as the app keeps it.
Future<String> exportBackup(JsonStore store, DateTime now) async {
  final names = [
    for (final name in await store.names())
      if (_kept(name)) name,
  ]..sort();
  return jsonEncode({
    'app': _app,
    'version': _version,
    'exported': now.toIso8601String(),
    'documents': {for (final name in names) name: ?await store.read(name)},
  });
}

/// Adds what [text] holds to [store]. What the app already has stays as it
/// is: the backup only fills in days, nights and workouts that are missing,
/// and brings its settings only where there are none yet. Throws a
/// [FormatException] for anything that is not a backup of this app.
Future<BackupResult> importBackup(
  JsonStore store,
  String text,
  DateTime now,
) async {
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    throw const FormatException('Not a JSON document.');
  }
  if (json case {
    'app': _app,
    'version': _version,
    'documents': final Map<String, Object?> documents,
  }) {
    final file = _Documents(documents);

    final own = await HistoryArchive(store).load(now);
    final days = (await HistoryArchive(file).load(now)).notIn(own);
    await HistoryArchive(store).mergeIntoStore(days);

    final ownNights = {
      for (final night in await NightArchive(store).load()) dayKey(night.date),
    };
    final nights = [
      for (final night in await NightArchive(file).load())
        if (!ownNights.contains(dayKey(night.date))) night,
    ];
    await NightArchive(store).mergeIntoStore(nights);

    final ownWorkouts = {
      for (final workout in await WorkoutArchive(store).load()) workout.key,
    };
    final workouts = [
      for (final workout in await WorkoutArchive(file).load())
        if (!ownWorkouts.contains(workout.key)) workout,
    ];
    await WorkoutArchive(store).mergeIntoStore(workouts);
    // After the workouts, so one the app holds is not removed by a backup.
    await WorkoutArchive(store)
        .addRemoved(await WorkoutArchive(file).loadRemoved());

    // The routes the app has none for; a workout it knows to be without
    // one may still have one in the backup.
    final ownRoutes = await RouteArchive(store).load();
    await RouteArchive(store).add({
      for (final MapEntry(:key, value: route) in (await RouteArchive(
        file,
      ).load()).entries)
        if (route != null && ownRoutes[key] == null) key: route,
    });

    // Supplements and what was taken of them exist nowhere else.
    final ownSupplements = SupplementData.fromJson(
      await store.read(StoreKeys.supplements),
    );
    final supplements = ownSupplements.mergedWith(
      SupplementData.fromJson(documents[StoreKeys.supplements]),
    );
    if (supplements.intakes.length != ownSupplements.intakes.length ||
        supplements.supplements.length != ownSupplements.supplements.length) {
      await store.write(StoreKeys.supplements, supplements.toJson());
    }

    final settings = documents[StoreKeys.settings];
    final restore =
        settings is Map<String, Object?> &&
        await store.read(StoreKeys.settings) == null;
    if (restore) await store.write(StoreKeys.settings, settings);

    return (
      days: {
        for (final values in days.values)
          for (final day in values.keys) dayKey(day),
      }.length,
      nights: nights.length,
      workouts: workouts.length,
      settings: restore,
    );
  }
  throw const FormatException('Not a backup of this app.');
}

/// The documents of a backup, read the way the archives read the store.
class _Documents implements JsonStore {
  const _Documents(this._documents);

  final Map<String, Object?> _documents;

  @override
  Future<Object?> read(String name) async => _documents[name];

  @override
  Future<List<String>> names() async => _documents.keys.toList();

  // The archives delete years past their limit; a backup is left alone.
  @override
  Future<void> delete(String name) async {}

  @override
  Future<void> write(String name, Object? json) async {}
}
