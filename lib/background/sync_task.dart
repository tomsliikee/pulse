import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../data/health_connect_repository.dart';
import '../data/health_history.dart';
import '../data/health_repository.dart';
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
      final snapshot = await repository.load(DateTime.now());
      final store = await FileJsonStore.open();
      await store.write(StoreKeys.snapshot, snapshot.toJson());
      // Also kept for the long term, so no day is lost when the app stays
      // closed for longer than the store's window.
      await HistoryArchive(store).mergeIntoStore(dailyValuesOf(snapshot));
      return true;
    } on Exception catch (error) {
      debugPrint('Background sync failed: $error');
      // Reported as done: the next period tries again anyway, and a retry
      // with backoff would only spend battery on the same failure.
      return true;
    }
  });
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
