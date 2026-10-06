import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';

import 'app/pulse_app.dart';
import 'background/sync_task.dart';
import 'data/health_connect_repository.dart';
import 'data/health_repository.dart';
import 'data/json_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await FileJsonStore.open();
  runApp(
    PulseApp(
      store: store,
      // Health Connect only exists on Android.
      repository: Platform.isAndroid
          ? HealthConnectRepository()
          : const UnsupportedHealthRepository(),
    ),
  );
  if (Platform.isAndroid) unawaited(scheduleBackgroundSync());
}
