import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/background/sync_task.dart';
import 'package:pulse/data/health_history.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/metric_catalog.dart';
import 'package:pulse/data/snapshot_builder.dart';
import 'package:pulse/data/sync_report.dart';

import 'support/fixtures.dart';

void main() {
  group('syncOnce', () {
    test(
      'reads in full when nothing is saved, and stores the result',
      () async {
        final repository = FixtureRepository();
        final store = MemoryJsonStore();

        await syncOnce(repository, store, fixtureNow);

        expect(repository.loadedWith, [null]);
        expect(store.documents, contains(StoreKeys.snapshot));
        final history = await HistoryArchive(store).load(fixtureNow);
        expect(history.value(Metric.steps, fixtureNow), 7432);
        final report = SyncReport.fromJson(await store.read(StoreKeys.sync))!;
        expect(report.full, isTrue);
        expect(report.error, isNull);
        expect(report.at.isBefore(fixtureNow), isFalse);
        // And what the platform sets its alarm for the morning by.
        expect(
          await store.read(StoreKeys.morningAlarm),
          containsPair('minute', inInclusiveRange(4 * 60, 12 * 60 - 1)),
        );
      },
    );

    test('reads with the maximum heart rate of the saved profile', () async {
      final repository = FixtureRepository();
      final store = MemoryJsonStore();

      await syncOnce(repository, store, fixtureNow);
      await store.write(StoreKeys.settings, {'birthDate': '1992-03-07'});
      await syncOnce(repository, store, fixtureNow);

      expect(repository.maxHeartRates, [null, 185]);
    });

    test('builds on a snapshot saved earlier the same day', () async {
      final repository = FixtureRepository();
      final store = MemoryJsonStore();
      final morning = DateTime(2026, 10, 6, 8);
      await store.write(
        StoreKeys.snapshot,
        buildSnapshot(now: morning, raw: repository.readings).toJson(),
      );

      await syncOnce(repository, store, fixtureNow);

      expect(repository.loadedWith.single?.loadedAt, morning);
      final report = SyncReport.fromJson(await store.read(StoreKeys.sync))!;
      expect(report.full, isFalse);
    });

    test('reads in full on the first run of a day', () async {
      final repository = FixtureRepository();
      final store = MemoryJsonStore();
      await store.write(
        StoreKeys.snapshot,
        buildSnapshot(
          now: DateTime(2026, 10, 5, 23),
          raw: repository.readings,
        ).toJson(),
      );

      await syncOnce(repository, store, fixtureNow);

      expect(repository.loadedWith, [null]);
    });

    test('a report survives its own JSON, with and without an error', () {
      final failed = SyncReport(at: fixtureNow, error: 'no access');
      final read = SyncReport.fromJson(failed.toJson())!;
      expect(read.at, fixtureNow);
      expect(read.error, 'no access');
      expect(read.seconds, isNull);
      expect(SyncReport.fromJson({'at': 'never'}), isNull);
      expect(SyncReport.fromJson(null), isNull);
    });
  });
}
