import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/background/morning_notice.dart';
import 'package:pulse/data/health_history.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/metric_catalog.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/morning.dart';
import 'package:pulse/data/recovery.dart';

import 'support/fixtures.dart';

final _day = DateTime(2026, 10, 6);

/// A night that ended on [_day] at [wakeMinute], or on [date].
SleepNight _night({int wakeMinute = 6 * 60 + 40, DateTime? date}) => SleepNight(
  date: date ?? _day,
  bedtimeMinute: (wakeMinute - 450) % (24 * 60),
  totalMinutes: 450,
  segments: const [],
);

DateTime _at(int hour, [int minute = 0]) =>
    DateTime(_day.year, _day.month, _day.day, hour, minute);

/// Values of thirty days before the day that swing by [swing] around
/// [mean], and [today] on the day itself.
double? Function(Metric, DateTime) _values(
  Map<Metric, (double mean, double swing, double? today)> metrics, {
  int days = 30,
}) => (metric, day) {
  final entry = metrics[metric];
  if (entry == null) return null;
  final (mean, swing, today) = entry;
  if (day == _day) return today;
  final back = _day.difference(day).inDays;
  if (back < 1 || back > days) return null;
  return mean + (back.isEven ? swing : -swing);
};

Recovery _recovery(double? variability, {int? asleep}) => recoveryOf(
  day: _day,
  valueOf: _values({
    if (variability != null) Metric.heartRateVariability: (50, 5, variability),
  }),
  nights: [
    if (asleep != null)
      SleepNight(
        date: _day,
        bedtimeMinute: 23 * 60,
        totalMinutes: asleep,
        segments: const [],
      ),
  ],
  sleepGoalHours: 8,
);

Workout _workout(int daysAgo) => Workout(
  type: WorkoutType.run,
  start: DateTime(_day.year, _day.month, _day.day - daysAgo, 18),
  minutes: 40,
);

void main() {
  group('the morning', () {
    test('starts where the night ended and lasts three hours', () {
      final window = morningWindow([_night()], _at(7));
      expect(window.fromNight, isTrue);
      expect(window.from, _at(6, 40));
      expect(window.until, _at(9, 40));
      expect(window.holds(_at(6, 39)), isFalse);
      expect(window.holds(_at(6, 40)), isTrue);
      expect(window.holds(_at(9, 39)), isTrue);
      expect(window.holds(_at(9, 40)), isFalse);
    });

    test('follows a late riser', () {
      final window = morningWindow([_night(wakeMinute: 11 * 60)], _at(13));
      expect(window.holds(_at(13)), isTrue);
      expect(window.holds(_at(14)), isFalse);
    });

    test('is four to noon on a day without a night', () {
      final yesterday = _night(date: DateTime(2026, 10, 5));
      for (final nights in [
        <SleepNight>[],
        [yesterday],
      ]) {
        final window = morningWindow(nights, _at(8));
        expect(window.fromNight, isFalse);
        expect(window.holds(_at(3, 59)), isFalse);
        expect(window.holds(_at(4)), isTrue);
        expect(window.holds(_at(11, 59)), isTrue);
        expect(window.holds(_at(12)), isFalse);
      }
    });
  });

  group('readings that stand out', () {
    test('are those a standard deviation and a half from the average', () {
      // The days before swing by 5 around 50, so their deviation is 5.
      List<VitalDeviation> found(double today) => vitalDeviations(
        _values({Metric.heartRateVariability: (50, 5, today)}),
        _day,
      );
      expect(found(50), isEmpty);
      expect(found(57), isEmpty);
      expect(found(43), isEmpty);
      final high = found(57.5).single;
      expect(high.metric, Metric.heartRateVariability);
      expect(high.usual, 50);
      expect(high.above, isTrue);
      expect(found(42.5).single.above, isFalse);
    });

    test('need five days before, and a reading on the day', () {
      expect(
        vitalDeviations(
          _values({Metric.restingHeartRate: (56, 2, 80)}, days: 4),
          _day,
        ),
        isEmpty,
      );
      expect(
        vitalDeviations(
          _values({Metric.restingHeartRate: (56, 2, 80)}, days: 5),
          _day,
        ),
        hasLength(1),
      );
      expect(
        vitalDeviations(
          _values({Metric.restingHeartRate: (56, 2, null)}),
          _day,
        ),
        isEmpty,
      );
    });

    test('readings that never differ do not make a small change stand out', () {
      // A twentieth of the average is the least spread: 3 beats at 60.
      List<VitalDeviation> found(double today) => vitalDeviations(
        _values({Metric.restingHeartRate: (60, 0, today)}),
        _day,
      );
      expect(found(64), isEmpty);
      expect(found(64.5), hasLength(1));
    });

    test('oxygen and skin temperature have a floor of their own', () {
      List<VitalDeviation> found(Metric metric, double mean, double today) =>
          vitalDeviations(_values({metric: (mean, 0, today)}), _day);
      // A point of saturation, three tenths of a degree.
      expect(found(Metric.oxygenSaturation, 97, 96), isEmpty);
      expect(found(Metric.oxygenSaturation, 97, 95.5), hasLength(1));
      expect(found(Metric.skinTemperature, 34, 34.4), isEmpty);
      expect(found(Metric.skinTemperature, 34, 34.5), hasLength(1));
    });

    test('come in the order of the list, each metric once', () {
      final found = vitalDeviations(
        _values({
          Metric.skinTemperature: (34, 0.2, 36),
          Metric.oxygenSaturation: (97, 0.5, 97),
          Metric.respiratoryRate: (14, 1, 19),
        }),
        _day,
      );
      expect(found.map((deviation) => deviation.metric), [
        Metric.respiratoryRate,
        Metric.skinTemperature,
      ]);
    });
  });

  group('what the day is good for', () {
    DayEffort? effort(Recovery recovery, [List<int> trained = const []]) =>
        effortFor(
          day: _day,
          recovery: recovery,
          workouts: [for (final ago in trained.reversed) _workout(ago)],
        );

    test('red is easy, whatever came before', () {
      expect(_recovery(5).zone, RecoveryZone.red);
      expect(effort(_recovery(5)), DayEffort.easy);
    });

    test('yellow is normal, and easy after two days of training in a row', () {
      expect(_recovery(50).zone, RecoveryZone.yellow);
      expect(effort(_recovery(50)), DayEffort.normal);
      expect(effort(_recovery(50), [1]), DayEffort.normal);
      expect(effort(_recovery(50), [1, 3]), DayEffort.normal);
      expect(effort(_recovery(50), [1, 2]), DayEffort.easy);
    });

    test('green is a push, and normal after three days of training', () {
      expect(_recovery(90).zone, RecoveryZone.green);
      expect(effort(_recovery(90)), DayEffort.push);
      expect(effort(_recovery(90), [1, 2]), DayEffort.push);
      expect(effort(_recovery(90), [1, 2, 3]), DayEffort.normal);
    });

    test('a workout of today or of four days ago does not count', () {
      expect(effort(_recovery(90), [0, 1, 2, 4]), DayEffort.push);
    });

    test('without a recovery the night decides, and without both nothing', () {
      expect(_recovery(null, asleep: 300).zone, isNull);
      expect(effort(_recovery(null, asleep: 300)), DayEffort.easy);
      expect(effort(_recovery(null, asleep: 420)), DayEffort.normal);
      expect(effort(_recovery(null)), isNull);
    });
  });

  group('the notification', () {
    MorningNotice? notice({
      Object? settings = const <String, Object?>{},
      Object? state,
      List<SleepNight>? nights,
      DateTime? now,
      String language = 'de',
    }) => morningNoticeFor(
      settings: settings,
      state: state,
      nights: nights ?? [_night()],
      now: now ?? _at(7),
      language: language,
    );

    test('greets with the night, by name where one is set', () {
      expect(notice(), (
        title: 'Guten Morgen',
        body: '7 h 30 min geschlafen · Schlaf-Score 94',
      ));
      expect(
        notice(settings: {'name': 'Thomas'})!.title,
        'Guten Morgen, Thomas',
      );
    });

    test('speaks the saved language, else the system\'s, else English', () {
      expect(notice(language: 'pl')!.title, 'Dzień dobry');
      expect(notice(settings: {'language': 'en'})!.title, 'Good morning');
      expect(notice(language: 'fr')!.title, 'Good morning');
    });

    test('waits for the night and ends with the morning', () {
      expect(notice(nights: []), isNull);
      expect(notice(now: _at(6, 30)), isNull);
      expect(notice(now: _at(9, 39)), isNotNull);
      expect(notice(now: _at(9, 40)), isNull);
    });

    test('is said once a day, and not after the cards were seen', () {
      expect(notice(state: {'notified': dayKey(_day)}), isNull);
      expect(
        notice(state: {'notified': dayKey(DateTime(2026, 10, 5))}),
        isNotNull,
      );
      expect(notice(settings: {'morningSeen': dayKey(_day)}), isNull);
    });

    test('is not said when switched off', () {
      expect(notice(settings: {'morningBrief': false}), isNull);
    });

    test('is left for the platform and the day remembered', () async {
      final store = MemoryJsonStore();
      await leaveMorningNotice(store, [_night()], _at(7), 'de');
      expect(await store.read(StoreKeys.morningNotice), {
        'title': 'Guten Morgen',
        'body': '7 h 30 min geschlafen · Schlaf-Score 94',
      });
      expect(await store.read(StoreKeys.morning), {'notified': dayKey(_day)});

      // The platform took it; the next run of the morning leaves none.
      await store.delete(StoreKeys.morningNotice);
      await leaveMorningNotice(store, [_night()], _at(8), 'de');
      expect(await store.read(StoreKeys.morningNotice), isNull);
    });
  });
}
