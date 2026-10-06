import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/health_controller.dart';
import 'package:pulse/data/health_history.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/metric_catalog.dart';
import 'package:pulse/data/period.dart';

import 'support/fixtures.dart';

DailyValues _steps(Map<DateTime, double> days) => {Metric.steps: days};

void main() {
  group('HealthHistory', () {
    test('a new value replaces the old one for the same day', () {
      final history = HealthHistory()
        ..merge(_steps({DateTime(2026, 10, 5): 4000}))
        ..merge(_steps({DateTime(2026, 10, 5): 9000}));

      expect(history.value(Metric.steps, DateTime(2026, 10, 5)), 9000);
    });

    test('a day missing from a later reading keeps its value', () {
      final history = HealthHistory()
        ..merge(
          _steps({DateTime(2026, 10, 4): 4000, DateTime(2026, 10, 5): 5000}),
        )
        ..merge(_steps({DateTime(2026, 10, 5): 5500}));

      expect(history.value(Metric.steps, DateTime(2026, 10, 4)), 4000);
      expect(history.value(Metric.steps, DateTime(2026, 10, 5)), 5500);
    });

    test('reports which years changed, and none when nothing did', () {
      final history = HealthHistory();
      final days = _steps({
        DateTime(2025, 12, 31): 3000,
        DateTime(2026, 1, 1): 3100,
      });

      expect(history.merge(days), {2025, 2026});
      expect(history.merge(days), isEmpty);
    });

    test('implausible values are not stored', () {
      final history = HealthHistory()
        ..merge(_steps({DateTime(2026, 10, 5): -1}));

      expect(history.isEmpty, isTrue);
    });

    test('lists the values of a range in order', () {
      final history = HealthHistory()
        ..merge(
          _steps({
            DateTime(2026, 10, 6): 3,
            DateTime(2026, 10, 2): 1,
            DateTime(2026, 10, 4): 2,
            DateTime(2026, 9, 30): 9,
          }),
        );

      expect(
        history.between(
          Metric.steps,
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 5),
        ),
        [1, 2],
      );
      expect(history.firstDay(Metric.steps), DateTime(2026, 9, 30));
      expect(history.firstDay(Metric.weight), isNull);
    });

    test('day keys are consecutive across a daylight-saving change', () {
      // Clocks go back in Central Europe on 2026-10-25.
      expect(
        dayKey(DateTime(2026, 10, 26)) - dayKey(DateTime(2026, 10, 25)),
        1,
      );
      expect(dateOfKey(dayKey(DateTime(2024, 2, 29))), DateTime(2024, 2, 29));
    });
  });

  group('HistoryArchive', () {
    test('stores one document per year and loads them again', () async {
      final store = MemoryJsonStore();
      final archive = HistoryArchive(store);
      final history = HealthHistory();
      final changed = history.merge(
        _steps({
          DateTime(2025, 12, 31): 3000,
          DateTime(2026, 1, 1): 3100,
          DateTime(2026, 10, 6): 7432,
        }),
      );
      await archive.save(history, changed);

      expect(store.documents.keys, {'history-2025', 'history-2026'});
      final loaded = await archive.load(DateTime(2026, 10, 6));
      expect(loaded.value(Metric.steps, DateTime(2025, 12, 31)), 3000);
      expect(loaded.value(Metric.steps, DateTime(2026, 1, 1)), 3100);
      expect(loaded.value(Metric.steps, DateTime(2026, 10, 6)), 7432);
    });

    test('deletes years older than ten years and keeps the rest', () async {
      final store = MemoryJsonStore();
      final archive = HistoryArchive(store);
      final history = HealthHistory();
      await archive.save(
        history,
        history.merge(
          _steps({DateTime(2016, 6, 1): 1000, DateTime(2017, 6, 1): 2000}),
        ),
      );
      await store.write('settings', {'stepGoal': 9000});

      final loaded = await archive.load(DateTime(2026, 10, 6));

      expect(store.documents.keys, {'history-2017', 'settings'});
      expect(loaded.value(Metric.steps, DateTime(2016, 6, 1)), isNull);
      expect(loaded.value(Metric.steps, DateTime(2017, 6, 1)), 2000);
    });

    test('skips a damaged year and bad values, keeps the others', () async {
      final store = MemoryJsonStore();
      await store.write('history-2025', {'version': 1, 'year': 2025});
      await store.write('history-2026', {
        'version': 1,
        'year': 2026,
        'metrics': {
          'steps': {'0': 5000, '1': -3, '900': 4000, 'x': 1},
          'unknown': {'0': 1},
        },
      });

      final loaded = await HistoryArchive(store).load(DateTime(2026, 10, 6));

      expect(loaded.value(Metric.steps, DateTime(2026, 1, 1)), 5000);
      expect(loaded.value(Metric.steps, DateTime(2026, 1, 2)), isNull);
      expect(loaded.between(Metric.steps, DateTime(2020), DateTime(2030)), [
        5000,
      ]);
    });

    test('the background merge adds to a stored year', () async {
      final store = MemoryJsonStore();
      final archive = HistoryArchive(store);
      await archive.mergeIntoStore(_steps({DateTime(2026, 10, 5): 5000}));
      await archive.mergeIntoStore(_steps({DateTime(2026, 10, 6): 7432}));

      final loaded = await archive.load(DateTime(2026, 10, 6));
      expect(loaded.value(Metric.steps, DateTime(2026, 10, 5)), 5000);
      expect(loaded.value(Metric.steps, DateTime(2026, 10, 6)), 7432);
    });
  });

  group('buildPeriod', () {
    final today = DateTime(2026, 10, 6); // a Tuesday
    HealthHistory history(Map<DateTime, double> days) =>
        HealthHistory()..merge(_steps(days));
    PeriodView view(HealthHistory h, PeriodKind kind, [int offset = 0]) =>
        buildPeriod(
          history: h,
          metric: Metric.steps,
          kind: kind,
          today: today,
          offset: offset,
        );

    test('today and yesterday show the value of the day', () {
      final h = history({
        DateTime(2026, 10, 6): 7432,
        DateTime(2026, 10, 5): 9000,
        DateTime(2026, 10, 4): 5000,
      });

      expect(view(h, PeriodKind.today).headline, 7432);
      expect(view(h, PeriodKind.today).previous, 9000);
      expect(view(h, PeriodKind.yesterday).headline, 9000);
      expect(view(h, PeriodKind.yesterday).previous, 5000);
      expect(view(h, PeriodKind.today).buckets, isEmpty);
    });

    test('a week runs from Monday to Sunday', () {
      final week = view(history({}), PeriodKind.week);

      expect(week.start, DateTime(2026, 10, 5));
      expect(week.end, DateTime(2026, 10, 11));
      expect(week.buckets, hasLength(7));
      expect(
        view(history({}), PeriodKind.week, 1).start,
        DateTime(2026, 9, 28),
      );
    });

    test('the average ignores days without data', () {
      final h = history({
        DateTime(2026, 10, 5): 8000,
        DateTime(2026, 10, 6): 6000,
        // Week before:
        DateTime(2026, 9, 30): 4000,
      });
      final week = view(h, PeriodKind.week);

      expect(week.headline, 7000);
      expect(week.previous, 4000);
      expect(week.buckets.map((b) => b.value), [
        8000,
        6000,
        null,
        null,
        null,
        null,
        null,
      ]);
      expect(view(history({}), PeriodKind.week).headline, isNull);
    });

    test('months have their real number of days', () {
      expect(view(history({}), PeriodKind.month).buckets, hasLength(31));
      // February 2026, eight months back, and the leap February of 2024.
      expect(view(history({}), PeriodKind.month, 8).buckets, hasLength(28));
      final leap = view(history({}), PeriodKind.month, 32);
      expect(leap.start, DateTime(2024, 2));
      expect(leap.buckets, hasLength(29));
    });

    test('a week across the daylight-saving change still has seven days', () {
      final week = buildPeriod(
        history: history({}),
        metric: Metric.steps,
        kind: PeriodKind.week,
        today: DateTime(2026, 10, 27),
      );

      expect(week.start, DateTime(2026, 10, 26));
      expect(week.buckets, hasLength(7));
      expect(
        buildPeriod(
          history: history({}),
          metric: Metric.steps,
          kind: PeriodKind.week,
          today: DateTime(2026, 10, 27),
          offset: 1,
        ).buckets.map((b) => b.start.day),
        [19, 20, 21, 22, 23, 24, 25],
      );
    });

    test('a year shows the daily average of each month', () {
      final h = history({
        DateTime(2026, 1, 10): 4000,
        DateTime(2026, 1, 20): 6000,
        DateTime(2026, 10, 6): 8000,
      });
      final year = view(h, PeriodKind.year);

      expect(year.buckets, hasLength(12));
      expect(year.buckets[0].value, 5000);
      expect(year.buckets[1].value, isNull);
      expect(year.buckets[9].value, 8000);
      // Over the days, not over the months.
      expect(year.headline, 6000);
    });

    test('everything starts with the first year that has data', () {
      final h = history({
        DateTime(2024, 5, 1): 3000,
        DateTime(2026, 10, 6): 9000,
      });
      final all = view(h, PeriodKind.all);

      expect(all.buckets.map((b) => b.start.year), [2024, 2025, 2026]);
      expect(all.buckets.map((b) => b.value), [3000, null, 9000]);
      expect(all.headline, 6000);
      expect(all.previous, isNull);
      expect(all.canGoBack, isFalse);
    });

    test('paging stops at the oldest data and at the present', () {
      final h = history({
        DateTime(2026, 9, 29): 5000,
        DateTime(2026, 10, 6): 7000,
      });

      expect(view(h, PeriodKind.week).canGoBack, isTrue);
      expect(view(h, PeriodKind.week).canGoForward, isFalse);
      expect(view(h, PeriodKind.week, 1).canGoBack, isFalse);
      expect(view(h, PeriodKind.week, 1).canGoForward, isTrue);
      expect(view(history({}), PeriodKind.year).canGoBack, isFalse);
      expect(view(h, PeriodKind.today).canGoBack, isFalse);
    });
  });

  group('history in the controller', () {
    HealthController controller(
      FixtureRepository repository,
      JsonStore store,
    ) => HealthController(
      repository: repository,
      store: store,
      clock: () => fixtureNow,
    );

    test('every refresh archives the days of the live window', () async {
      final store = MemoryJsonStore();
      final health = controller(FixtureRepository(), store);

      await health.start();

      expect(health.history!.value(Metric.steps, DateTime(2026, 10, 6)), 7432);
      expect(health.history!.firstDay(Metric.steps), DateTime(2026, 9, 7));
      expect(store.documents, contains('history-2026'));
    });

    test('archived days survive when the live window has moved on', () async {
      final store = MemoryJsonStore();
      await controller(FixtureRepository(), store).start();

      // Six weeks later the store no longer returns the old days.
      final later = HealthController(
        repository: FixtureRepository(),
        store: store,
        clock: () => DateTime(2026, 11, 20, 9),
      );
      await later.start();

      expect(later.snapshot.indexOf(DateTime(2026, 9, 7)), isNull);
      expect(
        later.history!.value(Metric.steps, DateTime(2026, 9, 7)),
        isNotNull,
      );
      expect(later.history!.value(Metric.steps, DateTime(2026, 10, 6)), 7432);
    });

    test(
      'older data is fetched once, in stretches, until none is left',
      () async {
        final store = MemoryJsonStore();
        final repository = FixtureRepository()
          ..historyAccess = true
          ..olderDays = fixtureOlderDays();
        final health = controller(repository, store);

        await health.start();

        // 730 days of older data in stretches of 90, then two empty ones.
        expect(repository.historyRequests.length, 9 + 2);
        expect(repository.historyRequests.first.$2, DateTime(2026, 9, 6));
        expect(health.history!.firstDay(Metric.steps), DateTime(2024, 9, 7));
        expect(health.backfillReached, isNull);
        expect(
          store.documents.keys,
          containsAll(['history-2024', 'history-2025']),
        );

        await controller(repository, store).start();
        expect(
          repository.historyRequests.length,
          11,
          reason: 'not fetched again',
        );
      },
    );

    test('without the permission it asks once and then leaves it', () async {
      final store = MemoryJsonStore();
      final repository = FixtureRepository();

      await controller(repository, store).start();
      await controller(repository, store).start();

      expect(repository.historyPermissionRequests, 1);
      expect(repository.historyRequests, isEmpty);
    });

    test('an interrupted fetch continues where it stopped', () async {
      final store = MemoryJsonStore();
      final repository = FixtureRepository()
        ..historyAccess = true
        ..olderDays = fixtureOlderDays();
      await store.write(StoreKeys.backfill, {
        'done': false,
        'asked': true,
        'reached': DateTime(2025, 3, 1).toIso8601String(),
      });

      await controller(repository, store).start();

      expect(repository.historyRequests.first.$2, DateTime(2025, 3, 1));
    });
  });
}
