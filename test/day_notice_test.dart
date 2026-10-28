import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/background/day_notice.dart';
import 'package:pulse/data/day_insights.dart' show DayValue;
import 'package:pulse/data/health_history.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/metric_catalog.dart';
import 'package:pulse/data/settings_controller.dart';

import 'support/fixtures.dart' show MemoryJsonStore;

void main() {
  final now = DateTime(2026, 10, 4, 21);
  double? steps(Metric metric, DateTime day) =>
      metric == Metric.steps && dayKey(day) == dayKey(now) ? 5000 : null;

  DayAlarm? alarm(Object? settings, {DayValue? valueOf}) => dayAlarmFor(
    settings: settings,
    valueOf: valueOf ?? steps,
    nights: const [],
    now: now,
    language: 'en',
  );

  group('the alarm for nine in the evening', () {
    test('it is off until the user turns it on', () {
      expect(alarm(null), isNull);
      expect(alarm(const {'dayNotice': false}), isNull);
      expect(alarm(const {'dayNotice': true}), isNotNull);
    });

    test('it tells the score in the chosen language', () {
      final german = alarm(const {'dayNotice': true, 'language': 'de'})!;
      expect(german.title, 'Dein Tag');
      expect(german.body, startsWith('Tageswert '));
      expect(german.short, isNotNull);
      expect(german.day, dayKey(now));
      final english = alarm(const {'dayNotice': true})!;
      expect(english.body, startsWith('Day score '));
    });

    test('it says only that the day is ready when nothing is known', () {
      final empty = alarm(const {'dayNotice': true}, valueOf: (_, _) => null)!;
      expect(empty.body, empty.plain);
      expect(empty.short, isNull);
    });

    test('it is left for the platform and taken away again', () async {
      final store = MemoryJsonStore();
      Future<bool> leave(Object? settings) => leaveDayAlarm(
        store,
        settings: settings,
        valueOf: steps,
        nights: const [],
        now: now,
        language: 'en',
      );
      expect(await leave(const {'dayNotice': true}), isTrue);
      expect(await store.read(StoreKeys.dayAlarm), isNotNull);
      // Nothing new, nothing written.
      expect(await leave(const {'dayNotice': true}), isFalse);
      expect(await leave(const {'dayNotice': false}), isTrue);
      expect(await store.read(StoreKeys.dayAlarm), isNull);
      expect(await leave(const {'dayNotice': false}), isFalse);
    });
  });

  group('the live message switches', () {
    test('they are off, saved and read again', () async {
      final store = MemoryJsonStore();
      final settings = SettingsController(store);
      await settings.load();
      expect(settings.dayNotice, isFalse);
      expect(settings.liveMorning, isFalse);
      settings
        ..setDayNotice(true)
        ..setLiveSupplements(true);
      await Future<void>.delayed(Duration.zero);
      final loaded = SettingsController(store);
      await loaded.load();
      expect(loaded.dayNotice, isTrue);
      expect(loaded.liveSupplements, isTrue);
      expect(loaded.liveWeek, isFalse);
      expect(loaded.liveDay, isFalse);
    });
  });
}
