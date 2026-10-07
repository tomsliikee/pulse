import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/background/sync_task.dart';
import 'package:pulse/data/health_history.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/metric_catalog.dart';
import 'package:pulse/data/snapshot_builder.dart';

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
      },
    );

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
  });
}
