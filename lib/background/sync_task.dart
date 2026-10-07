import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../data/health_connect_repository.dart';
import '../data/health_history.dart';
import '../data/health_repository.dart';
import '../data/health_snapshot.dart';
import '../data/json_store.dart';

const String _uniqueName = 'pulse.sync';
const String _taskName = 'sync';

/// Runs in a background isolate without any UI. Reads Health Connect and
/// stores the snapshot, so the app shows current values the moment it opens.
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final repository = HealthConnectRepository();
      if (await repository.access() != HealthAccess.granted) return true;
      if (!await repository.backgroundAccessGranted()) return true;
      await syncOnce(repository, await FileJsonStore.open(), DateTime.now());
      return true;
    } on Exception catch (error) {
      debugPrint('Background sync failed: $error');
      // Reported as done: the next period tries again anyway, and a retry
      // with backoff would only spend battery on the same failure.
      return true;
    }
  });
}

/// Reads the store and saves the result. Builds on the saved snapshot, so
/// only what can have changed since is read again.
Future<void> syncOnce(
  HealthRepository repository,
  JsonStore store,
  DateTime now,
) async {
  final saved = HealthSnapshot.fromJson(await store.read(StoreKeys.snapshot));
  final today = DateTime(now.year, now.month, now.day);
  final snapshot = await repository.load(
    now,
    // The first read of a day is a full one, as in the app.
    previous: saved != null && saved.today == today ? saved : null,
  );
  await store.write(StoreKeys.snapshot, snapshot.toJson());
  // Also kept for the long term, so no day is lost when the app stays
  // closed for longer than the store's window.
  await HistoryArchive(store).mergeIntoStore(dailyValuesOf(snapshot));
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
