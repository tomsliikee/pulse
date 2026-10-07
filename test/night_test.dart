import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/background/sync_task.dart';
import 'package:pulse/data/health_controller.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/night_archive.dart';
import 'package:pulse/data/night_insights.dart';
import 'package:pulse/data/snapshot_builder.dart';
import 'package:pulse/data/workout_insights.dart' show Trend;
import 'package:pulse/features/sleep/night_format.dart';

import 'support/fixtures.dart';

final DateTime _first = DateTime(2026, 9, 1);
DateTime _day(int n) => DateTime(_first.year, _first.month, _first.day + n);

/// A night that ends on [date]: in bed at [bedtime], [minutes] long, with
/// the stages in the shares of a textbook night unless given.
SleepNight _night(
  DateTime date, {
  int bedtime = 23 * 60,
  int minutes = 480,
  int? deep,
  int? rem,
  int awake = 20,
  bool stages = true,
}) {
  final asleep = minutes - awake;
  deep ??= (asleep * 0.18).round();
  rem ??= (asleep * 0.22).round();
  return SleepNight(
    date: date,
    bedtimeMinute: bedtime % (24 * 60),
    totalMinutes: minutes,
    segments: const [],
    stageMinutes: !stages
        ? null
        : {
            SleepStage.deep: deep,
            SleepStage.rem: rem,
            SleepStage.light: asleep - deep - rem,
            SleepStage.awake: awake,
          },
  );
}

HealthController _controller(FixtureRepository repository, JsonStore store) =>
    HealthController(
      repository: repository,
      store: store,
      clock: () => fixtureNow,
    );

void main() {
  group('SleepNight', () {
    test('its summary keeps the minutes of each stage without the curve', () {
      final night = buildSnapshot(
        now: fixtureNow,
        raw: fixtureReadings(),
      ).nights.last!;
      final summary = night.summary;
      expect(night.hasCurve, isTrue);
      expect(summary.hasCurve, isFalse);
      expect(summary.hasStages, isTrue);
      for (final stage in SleepStage.values) {
        expect(summary.minutesIn(stage), night.minutesIn(stage));
      }
      expect(summary.asleepMinutes, night.asleepMinutes);

      final restored = SleepNight.fromJson(summary.toJson())!;
      expect(
        restored.minutesIn(SleepStage.deep),
        night.minutesIn(SleepStage.deep),
      );
      expect(restored.hasCurve, isFalse);
    });

    test('a night without stages has none after the archive either', () {
      final night = _night(_day(0), stages: false);
      final restored = SleepNight.fromJson(night.summary.toJson())!;
      expect(restored.hasStages, isFalse);
      expect(restored.asleepMinutes, 480);
    });
  });

  group('night archive', () {
    test('merging adds, replaces and reports no change', () {
      final stored = [_night(_day(1))];
      final merged = mergeNights(stored, [
        _night(_day(0)),
        _night(_day(1), minutes: 420),
      ])!;
      expect(merged.map((night) => night.totalMinutes), [480, 420]);
      expect(mergeNights(merged, [_night(_day(0))]), isNull);
    });

    test(
      'a refresh archives the nights of the window, a year a document',
      () async {
        final store = MemoryJsonStore();
        final health = _controller(FixtureRepository(), store);
        await health.start();

        expect(health.nights, hasLength(30));
        expect(health.latestNight!.date, DateTime(2026, 10, 6));
        expect(health.latestNight!.hasCurve, isFalse);
        expect(health.withCurve(health.latestNight!).hasCurve, isTrue);
        expect(store.documents.keys, contains('nights-2026'));
        expect(await NightArchive(store).load(), hasLength(30));
      },
    );

    test('a night stays after it has left the store\'s window', () async {
      final store = MemoryJsonStore();
      await _controller(FixtureRepository(), store).start();
      final later = HealthController(
        repository: FixtureRepository(readings: const RawReadings()),
        store: store,
        clock: () => DateTime(2026, 12, 20, 9),
      );
      await later.start();
      expect(later.snapshot.nights.whereType<SleepNight>(), isEmpty);
      expect(later.nights, hasLength(30));
      // Outside the window there is no curve to give back.
      expect(later.withCurve(later.latestNight!).hasCurve, isFalse);
    });

    test('older nights are fetched once, across empty stretches', () async {
      final store = MemoryJsonStore();
      final repository = FixtureRepository()
        ..historyAccess = true
        ..olderDays = fixtureOlderDays()
        ..olderNights = [
          _night(DateTime(2024, 10, 3)),
          _night(DateTime(2025, 12, 31)),
          _night(DateTime(2026, 6, 1)),
        ];
      final health = _controller(repository, store);
      await health.start();

      expect(health.nights, hasLength(33));
      expect(health.nights.first.date, DateTime(2024, 10, 3));
      expect(repository.nightRequests.length, 9);
      expect(repository.historyPermissionRequests, 0);
      expect(
        store.documents.keys,
        containsAll(['nights-2024', 'nights-2025', 'nights-2026']),
      );

      await _controller(repository, store).start();
      expect(repository.nightRequests.length, 9, reason: 'not fetched again');
    });

    test('an interrupted fetch continues where it stopped', () async {
      final store = MemoryJsonStore();
      final repository = FixtureRepository()
        ..historyAccess = true
        ..olderDays = fixtureOlderDays();
      await store.write(StoreKeys.nightBackfill, {
        'done': false,
        'reached': DateTime(2025, 3, 1).toIso8601String(),
      });
      await _controller(repository, store).start();
      expect(repository.nightRequests.first.$2, DateTime(2025, 3, 1));
    });

    test('without the permission nothing is fetched', () async {
      final store = MemoryJsonStore();
      final repository = FixtureRepository()
        ..olderNights = [_night(DateTime(2026, 6, 1))];
      await store.write(StoreKeys.backfill, {'done': true, 'asked': true});
      await _controller(repository, store).start();
      expect(repository.nightRequests, isEmpty);
      expect(repository.historyPermissionRequests, 0);
    });

    test('the background task archives nights too', () async {
      final store = MemoryJsonStore();
      await syncOnce(FixtureRepository(), store, fixtureNow);
      expect(await NightArchive(store).load(), hasLength(30));
    });
  });

  group('nightsBefore', () {
    final all = [for (var n = 0; n < 20; n += 2) _night(_day(n))];

    test('gives the nights of the days before, without the day itself', () {
      expect(nightsBefore(all, _day(10), 7).map((night) => night.date.day), [
        5,
        7,
        9,
      ]);
      expect(nightsBefore(all, _day(0), 7), isEmpty);
      expect(nightsBefore(all, _day(40), 7), isEmpty);
    });
  });

  group('sleepScore', () {
    final week = [for (var n = 0; n < 7; n++) _night(_day(n))];

    test('a textbook night after a regular week scores the hundred', () {
      final night = _night(_day(7));
      final score = sleepScore(night, 7.5, [...week, night]);
      expect(score.parts.keys, ScorePart.values);
      expect(score.total, 100);
      for (final part in ScorePart.values) {
        expect(
          score.parts[part],
          closeTo(part.points, 0.01),
          reason: part.name,
        );
      }
    });

    test('half the goal earns half the points for duration', () {
      final night = _night(_day(7), minutes: 260, awake: 20);
      final score = sleepScore(night, 8, [...week, night]);
      expect(score.parts[ScorePart.duration], closeTo(20, 0.01));
    });

    test('little deep and REM sleep costs points for the stages', () {
      final night = _night(_day(7), deep: 0, rem: 46);
      final score = sleepScore(night, 7.5, [...week, night]);
      // No deep sleep, half the typical share of REM.
      expect(score.parts[ScorePart.stages], closeTo(25 / 4, 0.2));
    });

    test('lying awake costs points for efficiency', () {
      final night = _night(_day(7), minutes: 500, awake: 100);
      final score = sleepScore(night, 6, [...week, night]);
      // Eighty percent asleep is halfway between none and all.
      expect(score.parts[ScorePart.efficiency], closeTo(10, 0.01));
    });

    test('a bedtime far from the usual one costs points for regularity', () {
      final night = _night(_day(7), bedtime: 23 * 60 + 90, minutes: 390);
      final score = sleepScore(night, 6, [...week, night]);
      expect(score.parts[ScorePart.regularity], 0);
      // Through midnight the distance is still measured in minutes.
      final after = _night(_day(7), bedtime: 10, minutes: 410);
      expect(
        sleepScore(after, 6, [...week, after]).parts[ScorePart.regularity],
        closeTo(15 * 20 / 75, 0.01),
      );
    });

    test('what cannot be judged is left out and the rest scaled up', () {
      final night = _night(_day(0), stages: false);
      final score = sleepScore(night, 8, [night]);
      expect(score.parts.keys, [ScorePart.duration]);
      expect(score.total, 100);
    });
  });

  group('NightInsights', () {
    final week = [for (var n = 0; n < 7; n++) _night(_day(n))];

    test('compares with the night before and the week before', () {
      final night = _night(_day(7), minutes: 520, awake: 40);
      final insights = NightInsights.of(night, [...week, night], 8);
      final asleep = insights.measure(NightMeasure.asleep)!;
      expect(asleep.value, 480);
      expect(asleep.previous, 460);
      expect(asleep.average, 460);
      expect(asleep.againstPrevious, Trend.better);
      expect(
        insights.measure(NightMeasure.awake)!.againstPrevious,
        Trend.worse,
      );
      // Neither earlier nor later is the better bedtime.
      expect(
        insights.measure(NightMeasure.bedtime)!.againstPrevious,
        Trend.neutral,
      );
      expect(insights.week, hasLength(7));
    });

    test('a few minutes more or less are the same', () {
      final night = _night(_day(7), minutes: 484);
      final insights = NightInsights.of(night, [...week, night], 8);
      expect(
        insights.measure(NightMeasure.asleep)!.againstPrevious,
        Trend.same,
      );
    });

    test('without stages only what the night has is compared', () {
      final night = _night(_day(7), stages: false);
      final insights = NightInsights.of(night, [...week, night], 8);
      expect(insights.measure(NightMeasure.deep), isNull);
      expect(insights.measure(NightMeasure.efficiency), isNull);
      expect(insights.measure(NightMeasure.asleep), isNotNull);
    });

    List<NightTipKind> tips(SleepNight night, List<SleepNight> before) => [
      for (final tip in NightInsights.of(night, [...before, night], 7.5).tips)
        tip.kind,
    ];

    test('with fewer than three nights before there is only the note', () {
      expect(tips(_night(_day(2)), week.sublist(0, 2)), [
        NightTipKind.fewToCompare,
      ]);
    });

    test('a week in rhythm is told to keep going', () {
      expect(tips(_night(_day(7)), week), [NightTipKind.keepGoing]);
    });

    test('a week short of the goal is named with what is missing', () {
      final short = [for (var n = 0; n < 7; n++) _night(_day(n), minutes: 420)];
      final insights = NightInsights.of(_night(_day(7), minutes: 420), [
        ...short,
        _night(_day(7), minutes: 420),
      ], 7.5);
      expect(insights.tips.single.kind, NightTipKind.debt);
      // Seven nights of fifty minutes each.
      expect(insights.tips.single.minutes, 350);
    });

    test('a late night and long time awake are both named', () {
      final night = _night(_day(7), bedtime: 24 * 60 + 40, awake: 70);
      final found = tips(night, week);
      expect(found, contains(NightTipKind.lateToBed));
      expect(found, contains(NightTipKind.longAwake));
    });

    test('bedtimes all over the evening are named', () {
      final scattered = [
        for (var n = 0; n < 7; n++)
          _night(_day(n), bedtime: 21 * 60 + (n.isEven ? 0 : 200)),
      ];
      expect(
        tips(_night(_day(7), bedtime: 22 * 60), scattered),
        contains(NightTipKind.irregular),
      );
    });

    test('less deep sleep than is usual for the user is named', () {
      expect(tips(_night(_day(7), deep: 30), week), [NightTipKind.littleDeep]);
    });
  });

  group('sleepLinks', () {
    // Twelve nights, every other one after a workout and forty minutes
    // longer.
    final nights = [
      for (var n = 1; n <= 12; n++)
        _night(
          _day(n),
          minutes: n.isEven ? 500 : 460,
          deep: n.isEven ? 100 : 80,
        ),
    ];
    final workouts = [
      for (var n = 1; n <= 12; n += 2)
        Workout(
          type: WorkoutType.run,
          start: _day(n).add(const Duration(hours: 18)),
          minutes: 30,
        ),
    ];

    test('nights after a workout are set against the others', () {
      final links = sleepLinks(
        nights: nights,
        until: _day(12),
        workouts: workouts,
        stepsOn: (_) => null,
        stepGoal: 10000,
      );
      expect(links, hasLength(2));
      expect(links.every((link) => link.kind == SleepLinkKind.workout), isTrue);
      final asleep = links.firstWhere((l) => l.measure == NightMeasure.asleep);
      expect(asleep.minutes, 40);
      expect(asleep.nightsWith, 6);
      expect(asleep.nightsWithout, 6);
      expect(
        links.firstWhere((l) => l.measure == NightMeasure.deep).minutes,
        20,
      );
    });

    test('with too few nights on one side nothing is said', () {
      expect(
        sleepLinks(
          nights: nights,
          until: _day(12),
          workouts: workouts.sublist(0, 4),
          stepsOn: (_) => null,
          stepGoal: 10000,
        ),
        isEmpty,
      );
    });

    test('days above the step goal are set against those below', () {
      final links = sleepLinks(
        nights: nights,
        until: _day(12),
        workouts: const [],
        // The day before an even night had many steps.
        stepsOn: (day) => day.difference(_first).inDays.isOdd ? 12000 : 4000,
        stepGoal: 10000,
      );
      expect(links.map((link) => link.kind).toSet(), {SleepLinkKind.steps});
      expect(links.first.minutes, 40);
    });

    test('a small difference is not worth a sentence', () {
      final even = [for (var n = 1; n <= 12; n++) _night(_day(n))];
      expect(
        sleepLinks(
          nights: even,
          until: _day(12),
          workouts: workouts,
          stepsOn: (_) => null,
          stepGoal: 10000,
        ),
        isEmpty,
      );
    });
  });

  group('tonight', () {
    test('needs three nights', () {
      expect(tonight([_night(_day(0)), _night(_day(1))], 8, _day(1)), isNull);
    });

    test('counts back from the usual time of getting up', () {
      // In bed at 23:00 for eight hours and twenty minutes: up at 07:20.
      final nights = [
        for (var n = 0; n < 7; n++) _night(_day(n), minutes: 500),
      ];
      final plan = tonight(nights, 8, _day(6))!;
      expect(plan.wakeMinute, 7 * 60 + 20);
      expect(plan.catchUpMinutes, 0);
      expect(plan.bedtimeMinute, 23 * 60 + 20);
    });

    test('goes to bed earlier while the week is in debt, but not by much', () {
      final nights = [
        for (var n = 0; n < 7; n++) _night(_day(n), minutes: 380),
      ];
      final plan = tonight(nights, 8, _day(6))!;
      expect(plan.wakeMinute, 5 * 60 + 20);
      expect(plan.catchUpMinutes, 30);
      expect(plan.bedtimeMinute, 20 * 60 + 50);
    });

    test('a bedtime after midnight comes out as a time of the day', () {
      final nights = [
        for (var n = 0; n < 7; n++)
          _night(_day(n), bedtime: 26 * 60, minutes: 500),
      ];
      final plan = tonight(nights, 8, _day(6))!;
      expect(plan.bedtimeMinute, 2 * 60 + 20);
    });
  });

  group('night texts', () {
    final week = [for (var n = 0; n < 7; n++) _night(_day(n))];

    test('the headline says how long against the night before', () {
      String headline(int minutes, [String language = 'de']) {
        final night = _night(_day(7), minutes: minutes);
        return nightHeadline(
          formatsOf(language),
          NightInsights.of(night, [...week, night], 8),
        );
      }

      expect(headline(520), '40 min länger als die Nacht davor');
      expect(headline(420), '1 h 0 min kürzer als die Nacht davor');
      expect(headline(480, 'en'), 'As long as the night before');
      expect(
        nightHeadline(
          formatsOf('pl'),
          NightInsights.of(_night(_day(0)), [_night(_day(0))], 8),
        ),
        'Brak wcześniejszej nocy do porównania',
      );
    });

    test('measures are written as times, shares and durations', () {
      final formats = formatsOf();
      expect(NightMeasure.bedtime.format(formats, 24 * 60 + 10), '00:10');
      expect(NightMeasure.efficiency.format(formats, 0.957), '96 %');
      expect(NightMeasure.deep.format(formats, 95), '1 h 35 min');
      expect(NightMeasure.score.format(formats, 91), '91');
    });

    test('a link reads as a sentence in each language', () {
      const link = SleepLink(
        kind: SleepLinkKind.workout,
        measure: NightMeasure.asleep,
        minutes: -25,
        nightsWith: 6,
        nightsWithout: 9,
      );
      expect(
        sleepLinkText(formatsOf(), link),
        'Nach Tagen mit Training schläfst du im Schnitt 25 min kürzer.',
      );
      expect(
        sleepLinkText(formatsOf('en'), link),
        'After days with a workout you sleep 25 min less on average.',
      );
      expect(
        sleepLinkText(formatsOf('pl'), link),
        'Po dniach z treningiem śpisz średnio o 25 min krócej.',
      );
    });
  });
}
