import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../data/body_age.dart';
import '../data/health_connect_repository.dart';
import '../data/health_history.dart';
import '../data/health_repository.dart';
import '../data/health_snapshot.dart';
import '../data/json_store.dart';
import '../data/night_archive.dart';
import '../data/settings_controller.dart';
import '../data/sync_report.dart';
import '../data/workout_archive.dart';

const String _uniqueName = 'pulse.sync';
const String _taskName = 'sync';

/// Runs in a background isolate without any UI. Reads Health Connect and
/// stores the snapshot, so the app shows current values the moment it opens.
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    final store = await FileJsonStore.open();
    Future<void> failed(String why) => store.write(
      StoreKeys.sync,
      SyncReport(at: DateTime.now(), error: why).toJson(),
    );
    try {
      final repository = HealthConnectRepository();
      if (await repository.access() != HealthAccess.granted) {
        await failed('no access');
        return true;
      }
      if (!await repository.backgroundAccessGranted()) {
        await failed('no background access');
        return true;
      }
      await syncOnce(repository, store, DateTime.now());
      return true;
    } on Exception catch (error) {
      debugPrint('Background sync failed: $error');
      await failed('$error');
      // Reported as done: the next period tries again anyway, and a retry
      // with backoff would only spend battery on the same failure.
      return true;
    }
  });
}

/// Reads the store and saves the result. Builds on the saved snapshot, so
/// only what can have changed since is read again. Leaves a [SyncReport].
Future<void> syncOnce(
  HealthRepository repository,
  JsonStore store,
  DateTime now,
) async {
  final watch = Stopwatch()..start();
  final saved = HealthSnapshot.fromJson(await store.read(StoreKeys.snapshot));
  final today = DateTime(now.year, now.month, now.day);
  // The first read of a day is a full one, as in the app.
  final previous = saved != null && saved.today == today ? saved : null;
  final workouts = WorkoutArchive(store);
  final birthDate = savedBirthDate(await store.read(StoreKeys.settings));
  final snapshot = withoutWorkouts(
    await repository.load(
      now,
      previous: previous,
      maxHeartRate: birthDate == null ? null : maxHeartRateOn(birthDate, now),
    ),
    await workouts.loadRemoved(),
  );
  await store.write(StoreKeys.snapshot, snapshot.toJson());
  // Also kept for the long term, so no day is lost when the app stays
  // closed for longer than the store's window.
  await HistoryArchive(store).mergeIntoStore(dailyValuesOf(snapshot));
  await workouts.mergeIntoStore(
    workoutsWithHeart(snapshot),
    window: (snapshot.dateAt(0), snapshot.loadedAt),
  );
  await NightArchive(store).mergeIntoStore(nightSummaries(snapshot));
  await store.write(
    StoreKeys.sync,
    SyncReport(
      at: now.add(watch.elapsed),
      seconds: watch.elapsedMilliseconds / 1000,
      full: previous == null,
    ).toJson(),
  );
}

/// Registers the hourly refresh. Safe to call on every start.
Future<void> scheduleBackgroundSync() async {
  await Workmanager().initialize(backgroundSyncDispatcher);
  await Workmanager().registerPeriodicTask(
    _uniqueName,
    _taskName,
    frequency: const Duration(hours: 1),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    constraints: Constraints(requiresBatteryNotLow: true),
  );
}
