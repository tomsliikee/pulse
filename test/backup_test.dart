import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app/backup_files.dart';
import 'package:pulse/background/sync_task.dart';
import 'package:pulse/data/backup.dart';
import 'package:pulse/data/health_history.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/metric_catalog.dart';
import 'package:pulse/data/night_archive.dart';
import 'package:pulse/data/workout_archive.dart';

import 'support/fixtures.dart';

class _Files implements BackupFiles {
  String? saved;
  String? name;
  String? toOpen;

  @override
  Future<bool> save(String name, String text) async {
    this.name = name;
    saved = text;
    return true;
  }

  @override
  Future<String?> open() async => toOpen;
}

/// A store as the app leaves it after a day of use.
Future<MemoryJsonStore> _usedStore() async {
  final store = MemoryJsonStore();
  await syncOnce(FixtureRepository(), store, fixtureNow);
  await store.write(StoreKeys.settings, {'stepGoal': 9000});
  return store;
}

void main() {
  setUpAll(loadAppFont);

  group('backup', () {
    test('holds the archives and the settings, and nothing else', () async {
      final store = await _usedStore();

      final json = jsonDecode(await exportBackup(store, fixtureNow)) as Map;

      expect(json['app'], 'pulse');
      final names = (json['documents'] as Map).keys.toSet();
      expect(names, contains('history-${fixtureNow.year}'));
      expect(names, contains('nights-${fixtureNow.year}'));
      expect(names, contains(StoreKeys.workouts));
      expect(names, contains(StoreKeys.settings));
      expect(names, isNot(contains(StoreKeys.snapshot)));
      expect(names, isNot(contains(StoreKeys.sync)));
      expect(
        backupFileName(DateTime(2026, 3, 7)),
        'pulse-backup-2026-03-07.json',
      );
    });

    test('read into an empty store brings everything back', () async {
      final used = await _usedStore();
      final text = await exportBackup(used, fixtureNow);
      final empty = MemoryJsonStore();

      final result = await importBackup(empty, text, fixtureNow);

      expect(result.days, greaterThan(0));
      expect(result.nights, (await NightArchive(used).load()).length);
      expect(result.workouts, (await WorkoutArchive(used).load()).length);
      expect(result.settings, isTrue);
      for (final name in await used.names()) {
        // What a read makes anew is not kept.
        if (const {
          StoreKeys.snapshot,
          StoreKeys.sync,
          StoreKeys.morningAlarm,
        }.contains(name)) {
          continue;
        }
        expect(await empty.read(name), await used.read(name), reason: name);
      }
    });

    test('read into the store it came from changes nothing', () async {
      final store = await _usedStore();
      final before = Map.of(store.documents);

      final result = await importBackup(
        store,
        await exportBackup(store, fixtureNow),
        fixtureNow,
      );

      expect(result, (days: 0, nights: 0, workouts: 0, settings: false));
      expect(store.documents, before);
    });

    test('fills gaps and leaves what is there', () async {
      final day = DateTime(fixtureNow.year, 1, 10);
      final other = DateTime(fixtureNow.year, 1, 11);
      final old = MemoryJsonStore();
      await HistoryArchive(old).mergeIntoStore({
        Metric.steps: {day: 1000, other: 2000},
      });
      final text = await exportBackup(old, fixtureNow);
      final store = MemoryJsonStore();
      await HistoryArchive(store).mergeIntoStore({
        Metric.steps: {day: 5555},
      });
      await store.write(StoreKeys.settings, {'stepGoal': 7000});

      final result = await importBackup(store, text, fixtureNow);

      expect(result.days, 1);
      expect(result.settings, isFalse);
      final history = await HistoryArchive(store).load(fixtureNow);
      expect(history.value(Metric.steps, day), 5555);
      expect(history.value(Metric.steps, other), 2000);
      expect(await store.read(StoreKeys.settings), {'stepGoal': 7000});
    });

    test('refuses what is not a backup', () async {
      final store = MemoryJsonStore();
      for (final text in [
        'not json',
        '[]',
        '{"app": "other", "version": 1, "documents": {}}',
        '{"app": "pulse", "version": 2, "documents": {}}',
      ]) {
        await expectLater(
          importBackup(store, text, fixtureNow),
          throwsFormatException,
          reason: text,
        );
      }
      expect(store.documents, isEmpty);
    });
  });

  for (final (code, save, open, nothing) in [
    (
      'de',
      'Sicherung speichern',
      'Sicherung einlesen',
      'nichts, was hier fehlt',
    ),
    ('en', 'Save a backup', 'Read a backup', 'nothing that is missing'),
    ('pl', 'Zapisz kopię', 'Wczytaj kopię', 'niczego, czego tu brakuje'),
  ]) {
    testWidgets('The profile saves and reads a backup ($code)', (tester) async {
      final files = _Files();
      await pumpApp(tester, locale: Locale(code), files: files);
      await tester.tap(find.bySemanticsLabel(_profile[code]!));
      await advance(tester);

      await tester.drag(
        find.byType(CustomScrollView).last,
        const Offset(0, -4000),
      );
      await advance(tester);
      await tester.tap(find.text(save));
      await advance(tester);
      expect(files.name, backupFileName(fixtureNow));
      expect(jsonDecode(files.saved!), containsPair('app', 'pulse'));

      files.toOpen = files.saved;
      await tester.tap(find.text(open));
      await advance(tester);
      expect(find.textContaining(nothing), findsOneWidget);

      files.toOpen = '{}';
      await tester.tap(find.text(open));
      await advance(tester);
      expect(find.textContaining('Pulse'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}

const _profile = {'de': 'Profil', 'en': 'Profile', 'pl': 'Profil'};
