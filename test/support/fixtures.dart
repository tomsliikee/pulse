import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app/pulse_app.dart';
import 'package:pulse/data/health_history.dart';
import 'package:pulse/data/health_repository.dart';
import 'package:pulse/data/health_snapshot.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/metric_catalog.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/snapshot_builder.dart';
import 'package:pulse/theme/app_theme.dart';

/// The moment every test treats as "now": Tuesday afternoon.
final DateTime fixtureNow = DateTime(2026, 10, 6, 15, 30);

/// Keeps documents in memory. File access would hang inside a widget test's
/// fake clock.
class MemoryJsonStore implements JsonStore {
  final Map<String, String> documents = {};

  @override
  Future<Object?> read(String name) async {
    final text = documents[name];
    return text == null ? null : jsonDecode(text);
  }

  @override
  Future<void> write(String name, Object? json) async {
    documents[name] = jsonEncode(json);
  }

  @override
  Future<void> delete(String name) async => documents.remove(name);

  @override
  Future<List<String>> names() async => documents.keys.toList();
}

/// A health store in memory with fixed, hand-written readings.
class FixtureRepository implements HealthRepository {
  FixtureRepository({
    this.currentAccess = HealthAccess.granted,
    RawReadings? readings,
  }) : readings = readings ?? fixtureReadings();

  HealthAccess currentAccess;
  RawReadings readings;
  bool failLoads = false;
  bool background = false;

  /// Whether the store lets older data be read, and what it then returns.
  bool historyAccess = false;
  DailyValues olderDays = const {};
  final List<(DateTime, DateTime)> historyRequests = [];
  int historyPermissionRequests = 0;
  int _nextId = 100;

  /// Makes [add] fail the way a refused write does.
  bool failAdds = false;

  /// What each [load] was given as the snapshot to build on.
  final List<HealthSnapshot?> loadedWith = [];

  final List<EntryDraft> added = [];
  final List<HealthEntry> deleted = [];

  @override
  Future<HealthAccess> access() async => currentAccess;

  @override
  Future<HealthAccess> requestAccess() async {
    if (currentAccess == HealthAccess.denied) {
      currentAccess = HealthAccess.granted;
    }
    return currentAccess;
  }

  @override
  Future<void> installStore() async {}

  @override
  Future<HealthSnapshot> load(DateTime now, {HealthSnapshot? previous}) async {
    if (failLoads) throw const FormatException('store unavailable');
    loadedWith.add(previous);
    return buildSnapshot(now: now, raw: readings);
  }

  @override
  Future<void> add(EntryDraft draft) async {
    if (failAdds) throw const HealthStoreException('refused');
    added.add(draft);
    _replaceEntries([
      ...readings.entries,
      HealthEntry(
        id: 'own-${_nextId++}',
        source: 'at.haiden.pulse',
        isOwn: true,
        draft: draft,
      ),
    ]);
  }

  @override
  Future<void> delete(HealthEntry entry) async {
    deleted.add(entry);
    _replaceEntries([
      for (final existing in readings.entries)
        if (existing.id != entry.id) existing,
    ]);
  }

  @override
  Future<bool> backgroundAccessGranted() async => background;

  @override
  Future<bool> requestBackgroundAccess() async => background = true;

  @override
  Future<bool> historyAccessGranted() async => historyAccess;

  @override
  Future<bool> requestHistoryAccess() async {
    historyPermissionRequests++;
    return historyAccess;
  }

  @override
  Future<DailyValues> loadHistory(DateTime from, DateTime to) async {
    historyRequests.add((from, to));
    return {
      for (final MapEntry(key: metric, value: days) in olderDays.entries)
        metric: {
          for (final MapEntry(key: day, :value) in days.entries)
            if (!day.isBefore(from) && !day.isAfter(to)) day: value,
        },
    };
  }

  void _replaceEntries(List<HealthEntry> entries) {
    readings = RawReadings(
      samples: readings.samples,
      dailyTotals: readings.dailyTotals,
      sleepSessions: readings.sleepSessions,
      sleepStages: readings.sleepStages,
      workouts: readings.workouts,
      entries: entries,
      hourlyTotals: readings.hourlyTotals,
    );
  }
}

DateTime _day(int daysAgo, [int hour = 0, int minute = 0]) => DateTime(
  fixtureNow.year,
  fixtureNow.month,
  fixtureNow.day - daysAgo,
  hour,
  minute,
);

/// Thirty days of plausible readings. Values vary with the day so charts are
/// not flat, but nothing is random.
RawReadings fixtureReadings() {
  final samples = <RawSample>[];
  final sessions = <RawSleepSession>[];
  final stages = <RawSleepStage>[];
  final steps = <DateTime, double>{};
  final distance = <DateTime, double>{};
  final active = <DateTime, double>{};
  final total = <DateTime, double>{};
  final intensity = <DateTime, double>{};
  final water = <DateTime, double>{};
  final stepsByHour = <DateTime, double>{
    for (var hour = 7; hour <= 14; hour++) _day(0, hour): 929,
    for (var hour = 8; hour <= 20; hour++) _day(1, hour): 400,
  };

  for (var ago = 29; ago >= 0; ago--) {
    final day = _day(ago);
    final wave = (ago * 37) % 11;
    steps[day] = ago == 0 ? 7432 : 5200.0 + wave * 640;
    distance[day] = steps[day]! * 0.00072;
    active[day] = 310.0 + wave * 22;
    total[day] = 2150.0 + wave * 30;
    intensity[day] = 18.0 + wave * 3;
    water[day] = 1.2 + wave * 0.1;

    samples
      ..add(RawSample(Metric.restingHeartRate, _day(ago, 7), 54.0 + wave % 6))
      ..add(RawSample(Metric.heartRateVariability, _day(ago, 4), 42.0 + wave))
      ..add(RawSample(Metric.oxygenSaturation, _day(ago, 3), 95.0 + wave % 4))
      ..add(RawSample(Metric.respiratoryRate, _day(ago, 3), 13.5 + wave % 3))
      ..add(RawSample(Metric.floors, _day(ago, 12), 4.0 + wave));
    if (ago % 3 == 0) {
      samples.add(RawSample(Metric.weight, _day(ago, 7, 30), 74.0 + wave / 10));
    }
    if (ago < 8) {
      for (var minute = 0; minute < 24 * 60; minute += 10) {
        if (ago == 0 && minute > fixtureNow.hour * 60) break;
        final asleep = minute < 6 * 60 + 30;
        samples.add(
          RawSample(
            Metric.heartRate,
            _day(ago, minute ~/ 60, minute % 60),
            asleep ? 55.0 + minute % 4 : 70.0 + (minute ~/ 10) % 17,
          ),
        );
      }
    }

    // The night that ends this morning started yesterday evening.
    final bedtime = _day(ago + 1, 23, 10 + wave);
    final wake = _day(ago, 6, 40 + wave);
    sessions.add(RawSleepSession(bedtime, wake));
    var cursor = bedtime;
    const pattern = [
      (SleepStage.awake, 6),
      (SleepStage.light, 40),
      (SleepStage.deep, 50),
      (SleepStage.light, 30),
      (SleepStage.rem, 25),
    ];
    var step = 0;
    while (cursor.isBefore(wake)) {
      final (stage, minutes) = pattern[step++ % pattern.length];
      var end = cursor.add(Duration(minutes: minutes));
      if (end.isAfter(wake)) end = wake;
      stages.add(RawSleepStage(stage, cursor, end));
      cursor = end;
    }
  }
  samples
    ..add(RawSample(Metric.systolic, _day(1, 8), 121))
    ..add(RawSample(Metric.diastolic, _day(1, 8), 78))
    ..add(RawSample(Metric.height, _day(20, 8), 181));

  return RawReadings(
    samples: samples,
    dailyTotals: {
      Metric.steps: steps,
      Metric.distance: distance,
      Metric.activeEnergy: active,
      Metric.totalEnergy: total,
      Metric.intensityMinutes: intensity,
      Metric.water: water,
    },
    hourlyTotals: {Metric.steps: stepsByHour},
    sleepSessions: sessions,
    sleepStages: stages,
    workouts: [
      Workout(
        type: WorkoutType.ride,
        start: _day(4, 17, 30),
        minutes: 52,
        kcal: 410,
        distanceKm: 19.4,
      ),
      Workout(
        type: WorkoutType.run,
        start: _day(1, 18),
        minutes: 35,
        kcal: 364,
        distanceKm: 5.6,
      ),
    ],
    entries: [
      HealthEntry(
        id: 'fitbit-water',
        source: 'com.fitbit.FitbitMobile',
        isOwn: false,
        draft: EntryDraft(kind: EntryKind.water, time: _day(0, 9), amount: 300),
      ),
      HealthEntry(
        id: 'own-water',
        source: 'at.haiden.pulse',
        isOwn: true,
        draft: EntryDraft(
          kind: EntryKind.water,
          time: _day(0, 11),
          amount: 500,
        ),
      ),
      HealthEntry(
        id: 'own-meal',
        source: 'at.haiden.pulse',
        isOwn: true,
        draft: EntryDraft(
          kind: EntryKind.meal,
          time: _day(0, 12, 30),
          amount: 640,
          name: 'Mittagessen',
          carbs: 72,
          protein: 31,
          fat: 22,
        ),
      ),
    ],
  );
}

/// Step counts for the two years before the live window, one value per day.
DailyValues fixtureOlderDays() => {
  Metric.steps: {
    for (var ago = 30; ago < 760; ago++) _day(ago): 6000.0 + (ago * 53) % 4000,
  },
  Metric.weight: {
    for (var ago = 30; ago < 760; ago += 7) _day(ago): 75.0 + (ago % 30) / 10,
  },
};

/// The test font is far wider than the real one and would report overflows
/// the app does not have. Call from `setUpAll`.
Future<void> loadAppFont() async {
  final bytes = await File('assets/fonts/GoogleSansFlex.ttf').readAsBytes();
  final loader = FontLoader(AppTheme.fontFamily)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

/// Some indicators move at rest, so the tree never settles; this advances a
/// fixed time that is long enough for every spring.
Future<void> advance(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(seconds: 2));
}

Future<({FixtureRepository repository, MemoryJsonStore store})> pumpApp(
  WidgetTester tester, {
  Size size = const Size(412, 915),
  FixtureRepository? repository,
  MemoryJsonStore? store,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = repository ?? FixtureRepository();
  final memory = store ?? MemoryJsonStore();
  await tester.pumpWidget(
    PulseApp(
      repository: repo,
      store: memory,
      paletteLoader: () async => null,
      clock: () => fixtureNow,
    ),
  );
  await advance(tester);
  return (repository: repo, store: memory);
}

/// Wraps a single widget in the app's theme for tests that need no app.
Widget themed(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: child),
);
