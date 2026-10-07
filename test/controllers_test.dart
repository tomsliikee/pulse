import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/health_controller.dart';
import 'package:pulse/data/health_repository.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/metric_catalog.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/settings_controller.dart';

import 'support/fixtures.dart';

HealthController _controller(FixtureRepository repository, JsonStore store) =>
    HealthController(
      repository: repository,
      store: store,
      clock: () => fixtureNow,
    );

void main() {
  group('HealthController', () {
    test('loads, selects today and saves the snapshot', () async {
      final store = MemoryJsonStore();
      final controller = _controller(FixtureRepository(), store);
      expect(controller.status, HealthStatus.loading);

      await controller.start();

      expect(controller.status, HealthStatus.ready);
      expect(controller.isTodaySelected, isTrue);
      expect(controller.value(Metric.steps), 7432);
      expect(store.documents, contains(StoreKeys.snapshot));
    });

    test('asks for access and becomes ready once it is granted', () async {
      final repository = FixtureRepository(currentAccess: HealthAccess.denied);
      final controller = _controller(repository, MemoryJsonStore());

      await controller.start();
      expect(controller.status, HealthStatus.needsAccess);

      await controller.requestAccess();
      expect(controller.status, HealthStatus.ready);
    });

    test('reports a missing store and an unsupported platform', () async {
      final missing = _controller(
        FixtureRepository(currentAccess: HealthAccess.unavailable),
        MemoryJsonStore(),
      );
      await missing.start();
      expect(missing.status, HealthStatus.unavailable);

      final unsupported = HealthController(
        repository: const UnsupportedHealthRepository(),
        store: MemoryJsonStore(),
      );
      await unsupported.start();
      expect(unsupported.status, HealthStatus.unsupported);
    });

    test('shows the saved snapshot when a fresh read fails', () async {
      final store = MemoryJsonStore();
      await _controller(FixtureRepository(), store).start();

      final failing = FixtureRepository()..failLoads = true;
      final controller = _controller(failing, store);
      await controller.start();

      expect(controller.status, HealthStatus.ready);
      expect(controller.value(Metric.steps), 7432);
    });

    test('fails when nothing was saved and reading fails', () async {
      final controller = _controller(
        FixtureRepository()..failLoads = true,
        MemoryJsonStore(),
      );

      await controller.start();

      expect(controller.status, HealthStatus.failed);
    });

    test('keeps the selected day across a refresh', () async {
      final controller = _controller(FixtureRepository(), MemoryJsonStore());
      await controller.start();
      controller.selectDay(controller.todayIndex - 2);
      final date = controller.selectedDate;

      await controller.refresh();

      expect(controller.selectedDate, date);
    });

    test('adds, edits and deletes own entries', () async {
      final repository = FixtureRepository();
      final controller = _controller(repository, MemoryJsonStore());
      await controller.start();
      final today = controller.todayIndex;

      await controller.addEntry(
        EntryDraft(kind: EntryKind.weight, time: fixtureNow, amount: 73.4),
      );
      final weight = controller.snapshot.entriesOn(today, EntryKind.weight);
      expect(weight.single.draft.amount, 73.4);

      await controller.replaceEntry(
        weight.single,
        EntryDraft(kind: EntryKind.weight, time: fixtureNow, amount: 73.1),
      );
      expect(
        controller.snapshot
            .entriesOn(today, EntryKind.weight)
            .single
            .draft
            .amount,
        73.1,
      );

      await controller.deleteEntry(
        controller.snapshot.entriesOn(today, EntryKind.weight).single,
      );
      expect(controller.snapshot.entriesOn(today, EntryKind.weight), isEmpty);
    });

    test('an edit that cannot be written keeps the old entry', () async {
      final repository = FixtureRepository();
      final controller = _controller(repository, MemoryJsonStore());
      await controller.start();
      final own = controller.snapshot.entries.firstWhere((e) => e.isOwn);

      repository.failAdds = true;
      await expectLater(
        controller.replaceEntry(own, own.draft),
        throwsA(isA<HealthStoreException>()),
      );
      expect(repository.deleted, isEmpty);
    });

    test('coming back within two minutes does not read again', () async {
      var now = fixtureNow;
      final repository = FixtureRepository();
      final controller = HealthController(
        repository: repository,
        store: MemoryJsonStore(),
        clock: () => now,
      );
      await controller.start();
      expect(repository.loadedWith, hasLength(1));

      now = fixtureNow.add(const Duration(seconds: 90));
      await controller.refreshIfStale();
      expect(repository.loadedWith, hasLength(1));

      now = fixtureNow.add(const Duration(minutes: 3));
      await controller.refreshIfStale();
      expect(repository.loadedWith, hasLength(2));
    });

    test(
      'builds on the snapshot of the same day unless asked for all',
      () async {
        var now = fixtureNow;
        final repository = FixtureRepository();
        final controller = HealthController(
          repository: repository,
          store: MemoryJsonStore(),
          clock: () => now,
        );
        await controller.start();
        await controller.refresh();
        await controller.refresh(full: true);
        now = fixtureNow.add(const Duration(days: 1));
        await controller.refresh();

        expect(repository.loadedWith.map((s) => s != null), [
          false,
          true,
          false,
          // A new day starts with a full read.
          false,
        ]);
      },
    );

    test('refuses to change entries of other apps', () async {
      final repository = FixtureRepository();
      final controller = _controller(repository, MemoryJsonStore());
      await controller.start();
      final foreign = controller.snapshot.entries.firstWhere((e) => !e.isOwn);

      await expectLater(controller.deleteEntry(foreign), throwsArgumentError);
      await expectLater(
        controller.replaceEntry(foreign, foreign.draft),
        throwsArgumentError,
      );
      expect(repository.deleted, isEmpty);
    });
  });

  group('SettingsController', () {
    test('saves changes and loads them again', () async {
      final store = MemoryJsonStore();
      SettingsController(store)
        ..setStepGoal(12000)
        ..setThemeMode(ThemeMode.dark)
        ..setDynamicColor(false)
        ..setTileOrder('today', ['water', 'steps']);
      await Future<void>.delayed(Duration.zero);

      final loaded = SettingsController(store);
      await loaded.load();

      expect(loaded.stepGoal, 12000);
      expect(loaded.themeMode, ThemeMode.dark);
      expect(loaded.dynamicColor, isFalse);
      expect(loaded.tileOrder('today'), ['water', 'steps']);
      expect(loaded.tileOrder('sleep'), isEmpty);
    });

    test('ignores values that make no sense', () async {
      final store = MemoryJsonStore();
      await store.write(StoreKeys.settings, {
        'stepGoal': -4,
        'sleepGoalHours': 'eight',
        'themeMode': 'neon',
        'tileOrder': {
          'today': ['steps', 7, null],
        },
      });
      final settings = SettingsController(store);

      await settings.load();

      expect(settings.stepGoal, 10000);
      expect(settings.sleepGoalHours, 8);
      expect(settings.themeMode, ThemeMode.system);
      expect(settings.tileOrder('today'), ['steps']);
    });
  });

  group('Today tiles in the settings', () {
    test('start with the default set and sizes', () {
      final settings = SettingsController(MemoryJsonStore());

      expect(settings.todayTiles, defaultTodayTiles);
      expect(settings.todayTiles, contains('heartRate'));
      expect(settings.todayTiles, isNot(contains('restingHeartRate')));
      expect(settings.isLargeTile('steps'), isTrue);
      expect(settings.isLargeTile('water'), isFalse);
    });

    test('adding, removing and resizing are saved', () async {
      final store = MemoryJsonStore();
      SettingsController(store)
        ..removeTodayTile('steps')
        ..addTodayTile('distance')
        ..addTodayTile('distance')
        ..toggleTileSize('water')
        ..toggleTileSize('energyIntake');
      await Future<void>.delayed(Duration.zero);

      final loaded = SettingsController(store);
      await loaded.load();

      expect(loaded.todayTiles, isNot(contains('steps')));
      expect(loaded.todayTiles.where((id) => id == 'distance'), hasLength(1));
      expect(loaded.isLargeTile('water'), isTrue);
      expect(loaded.isLargeTile('energyIntake'), isFalse);
    });

    test('unknown and repeated ids are dropped on load', () async {
      final store = MemoryJsonStore();
      await store.write(StoreKeys.settings, {
        'todayTiles': ['water', 'unicorns', 7, 'water', 'workout'],
        'largeTiles': ['water', 'unicorns'],
      });
      final settings = SettingsController(store);

      await settings.load();

      expect(settings.todayTiles, ['water', 'workout']);
      expect(settings.isLargeTile('water'), isTrue);
      expect(settings.isLargeTile('unicorns'), isFalse);
    });
  });

  group('FileJsonStore', () {
    late Directory directory;

    setUp(() => directory = Directory.systemTemp.createTempSync('pulse_test'));
    tearDown(() => directory.deleteSync(recursive: true));

    test('writes and reads a document', () async {
      final store = FileJsonStore(directory);

      await store.write('settings', {'stepGoal': 9000});

      expect(await store.read('settings'), {'stepGoal': 9000});
      expect(await store.read('missing'), isNull);
      expect(directory.listSync().map((f) => f.path.split('/').last), [
        'settings.json',
      ]);
    });

    test('treats a damaged file as absent', () async {
      File('${directory.path}/snapshot.json').writeAsStringSync('{"vers');

      expect(await FileJsonStore(directory).read('snapshot'), isNull);
    });
  });
}
