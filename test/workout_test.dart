import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/background/sync_task.dart';
import 'package:pulse/data/health_controller.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/snapshot_builder.dart';
import 'package:pulse/data/workout_archive.dart';
import 'package:pulse/data/workout_insights.dart';
import 'package:pulse/features/activity/workout_format.dart';

import 'support/fixtures.dart';

Workout _run(
  DateTime start, {
  int minutes = 30,
  double? km = 5,
  int? kcal,
  int? avgBpm,
}) => Workout(
  type: WorkoutType.run,
  start: start,
  minutes: minutes,
  distanceKm: km,
  kcal: kcal,
  avgBpm: avgBpm,
);

HealthController _controller(FixtureRepository repository, JsonStore store) =>
    HealthController(
      repository: repository,
      store: store,
      clock: () => fixtureNow,
    );

void main() {
  group('Workout', () {
    test('survives JSON with and without the newer fields', () {
      final workout = Workout(
        type: WorkoutType.walk,
        start: DateTime(2026, 10, 1, 8),
        minutes: 40,
        kcal: 150,
        distanceKm: 3.2,
        steps: 4300,
        avgBpm: 101,
        maxBpm: 122,
      );
      final restored = Workout.fromJson(workout.toJson())!;
      expect(restored.key, workout.key);
      expect(restored.steps, 4300);
      expect(restored.avgBpm, 101);
      expect(restored.maxBpm, 122);

      // As a release before the fields existed wrote it.
      final old = Workout.fromJson({
        'type': 'run',
        'start': '2026-10-01T08:00:00.000',
        'minutes': 30,
        'kcal': null,
        'km': 5,
      })!;
      expect(old.steps, isNull);
      expect(old.avgBpm, isNull);
    });
  });

  group('mergeWorkouts', () {
    final day = DateTime(2026, 10, 1, 8);

    test('adds new ones in order and reports no change for known ones', () {
      final stored = [_run(day)];
      final merged = mergeWorkouts(stored, [
        _run(day.subtract(const Duration(days: 3))),
        _run(day),
      ])!;
      expect(merged.map((w) => w.start.day), [28, 1]);
      expect(mergeWorkouts(merged, [_run(day)]), isNull);
    });

    test('a later reading replaces the stored one but keeps its pulse', () {
      final stored = [_run(day, kcal: 300, avgBpm: 150)];
      final merged = mergeWorkouts(stored, [_run(day, kcal: 320)])!;
      expect(merged.single.kcal, 320);
      expect(merged.single.avgBpm, 150);
    });
  });

  group('workout archive', () {
    test(
      'a refresh archives the window with the pulse of each workout',
      () async {
        final store = MemoryJsonStore();
        final health = _controller(FixtureRepository(), store);
        await health.start();

        expect(health.workouts.length, 6);
        expect(
          health.workouts.first.start.isBefore(health.workouts.last.start),
          isTrue,
        );
        // The run of yesterday lies inside the days that have a heart curve.
        expect(health.latestWorkout!.type, WorkoutType.run);
        expect(health.latestWorkout!.avgBpm, isNotNull);
        expect(
          health.latestWorkout!.maxBpm,
          greaterThanOrEqualTo(health.latestWorkout!.avgBpm!),
        );
        expect(await WorkoutArchive(store).load(), hasLength(6));
      },
    );

    test('a workout stays after it has left the store\'s window', () async {
      final store = MemoryJsonStore();
      await _controller(FixtureRepository(), store).start();

      final later = HealthController(
        repository: FixtureRepository(readings: const RawReadings()),
        store: store,
        clock: () => DateTime(2026, 12, 20, 9),
      );
      await later.start();
      expect(later.snapshot.workouts, isEmpty);
      expect(later.workouts, hasLength(6));
    });

    test('older workouts are fetched once, across empty stretches', () async {
      final store = MemoryJsonStore();
      final repository = FixtureRepository()
        ..historyAccess = true
        ..olderDays = fixtureOlderDays()
        ..olderWorkouts = [
          _run(DateTime(2024, 10, 3, 7)),
          // More than half a year without any, then one more.
          _run(DateTime(2026, 6, 1, 7)),
        ];
      final health = _controller(repository, store);
      await health.start();

      expect(health.workouts.length, 8);
      expect(health.workouts.first.start, DateTime(2024, 10, 3, 7));
      // Back to the oldest day of the history, 730 days in stretches of 90.
      expect(repository.workoutRequests.length, 9);
      expect(repository.workoutRequests.first.$2, DateTime(2026, 9, 6));
      expect(repository.historyPermissionRequests, 0);

      await _controller(repository, store).start();
      expect(repository.workoutRequests.length, 9, reason: 'not fetched again');
    });

    test(
      'without the permission nothing is fetched and nothing is asked',
      () async {
        final store = MemoryJsonStore();
        final repository = FixtureRepository()
          ..olderWorkouts = [_run(DateTime(2026, 6, 1, 7))];
        await store.write(StoreKeys.backfill, {'done': true, 'asked': true});
        await _controller(repository, store).start();

        expect(repository.workoutRequests, isEmpty);
        expect(repository.historyPermissionRequests, 0);
        expect(await store.read(StoreKeys.workoutBackfill), isNull);
      },
    );

    test('an interrupted fetch continues where it stopped', () async {
      final store = MemoryJsonStore();
      final repository = FixtureRepository()
        ..historyAccess = true
        ..olderDays = fixtureOlderDays();
      await store.write(StoreKeys.workoutBackfill, {
        'done': false,
        'reached': DateTime(2025, 3, 1).toIso8601String(),
      });
      await _controller(repository, store).start();

      expect(repository.workoutRequests.first.$2, DateTime(2025, 3, 1));
    });

    test('the background task archives workouts too', () async {
      final store = MemoryJsonStore();
      await syncOnce(FixtureRepository(), store, fixtureNow);
      expect(await WorkoutArchive(store).load(), hasLength(6));
    });
  });

  group('WorkoutInsights', () {
    final base = DateTime(2026, 9, 1, 18);
    DateTime week(int n) => base.add(Duration(days: 7 * n));

    test('a few metres give no pace and no speed', () {
      final drifted = _run(week(0), minutes: 22, km: 0.003);
      expect(measureOf(drifted, WorkoutMeasure.pace), isNull);
      expect(measureOf(drifted, WorkoutMeasure.distance), 0.003);
      final ride = Workout(
        type: WorkoutType.ride,
        start: week(0),
        minutes: 22,
        distanceKm: 0.05,
      );
      expect(measureOf(ride, WorkoutMeasure.speed), isNull);

      // Such a workout is nothing to be faster than.
      final next = _run(week(1), minutes: 30, km: 5);
      final pace = WorkoutInsights.of(next, [
        drifted,
        next,
      ]).measure(WorkoutMeasure.pace)!;
      expect(pace.previous, isNull);
    });

    test('compares with the workout before and the average before', () {
      final all = [
        _run(week(0), minutes: 32, km: 5),
        _run(week(1), minutes: 31, km: 5),
        _run(week(2), minutes: 30, km: 5.5),
        Workout(type: WorkoutType.walk, start: week(2), minutes: 60),
      ];
      final insights = WorkoutInsights.of(all[2], all);

      expect(insights.earlier, hasLength(2));
      final pace = insights.measure(WorkoutMeasure.pace)!;
      expect(pace.value, closeTo(30 / 5.5, 0.001));
      expect(pace.previous, closeTo(6.2, 0.001));
      expect(pace.average, closeTo(6.3, 0.001));
      expect(pace.againstPrevious, Trend.better);
      expect(pace.isBest, isTrue);
      expect(insights.measure(WorkoutMeasure.distance)!.isBest, isTrue);
      // How long it took says nothing next to how far and how fast.
      expect(
        insights.measure(WorkoutMeasure.duration)!.againstPrevious,
        Trend.neutral,
      );
      expect(insights.headline!.measure, WorkoutMeasure.pace);
      expect(insights.trend, hasLength(3));
    });

    test('a ride is measured in speed, a workout without distance in time', () {
      final ride = Workout(
        type: WorkoutType.ride,
        start: week(1),
        minutes: 60,
        distanceKm: 24,
      );
      final rides = WorkoutInsights.of(ride, [ride]);
      expect(rides.measure(WorkoutMeasure.speed)!.value, 24);
      expect(rides.measure(WorkoutMeasure.pace), isNull);
      expect(rides.headline, isNull);

      Workout yoga(int n, int minutes) =>
          Workout(type: WorkoutType.yoga, start: week(n), minutes: minutes);
      final sessions = [yoga(0, 30), yoga(1, 40)];
      final longer = WorkoutInsights.of(sessions[1], sessions);
      expect(longer.headline!.measure, WorkoutMeasure.duration);
      expect(longer.headline!.againstPrevious, Trend.better);
    });

    test('within one percent it is the same', () {
      final all = [_run(week(0), km: 5), _run(week(1), km: 5.03)];
      expect(
        WorkoutInsights.of(
          all[1],
          all,
        ).measure(WorkoutMeasure.distance)!.againstPrevious,
        Trend.same,
      );
    });

    test('counts how often, and knows when it cannot look back', () {
      final all = [
        for (var n = 0; n < 9; n++) _run(week(n)),
        _run(week(8).add(const Duration(days: 2))),
      ];
      final insights = WorkoutInsights.of(all.last, all);
      expect(insights.perWeekRecent, 5 / 4);
      expect(insights.perWeekBefore, 1);

      final few = [_run(week(0)), _run(week(1))];
      expect(WorkoutInsights.of(few[1], few).perWeekBefore, isNull);
    });

    List<WorkoutTipKind> tips(Workout workout, List<Workout> all) => [
      for (final tip in WorkoutInsights.of(workout, all).tips) tip.kind,
    ];

    test('with fewer than three there is only the note about comparing', () {
      final all = [_run(week(0)), _run(week(1))];
      expect(tips(all[1], all), [WorkoutTipKind.fewToCompare]);
    });

    test('a steady series is told to keep going', () {
      final all = [for (var n = 0; n < 4; n++) _run(week(n))];
      expect(tips(all.last, all), [WorkoutTipKind.keepGoing]);
    });

    test('a long break and a big jump are both named', () {
      final all = [
        _run(week(0)),
        _run(week(1)),
        _run(week(2)),
        _run(week(6), km: 8, minutes: 48),
      ];
      final insights = WorkoutInsights.of(all.last, all);
      expect(insights.tips.map((tip) => tip.kind), [
        WorkoutTipKind.longBreak,
        WorkoutTipKind.bigJump,
      ]);
      expect(insights.tips.first.value, 28);
      expect(insights.tips.last.value, 60);
    });

    test('doing it less often than before is named', () {
      final all = [
        for (var n = 0; n < 4; n++) ...[
          _run(week(n)),
          _run(week(n).add(const Duration(days: 3))),
        ],
        _run(week(6)),
        _run(week(8)),
      ];
      expect(tips(all.last, all), contains(WorkoutTipKind.lessOften));
    });

    test('the same pace at a higher pulse is named', () {
      final all = [
        for (var n = 0; n < 3; n++) _run(week(n), avgBpm: 150),
        _run(week(3), avgBpm: 160),
      ];
      expect(tips(all.last, all), [WorkoutTipKind.higherPulse]);
    });

    test('strength less than twice a week is named', () {
      final all = [
        for (var n = 0; n < 4; n++)
          Workout(type: WorkoutType.strength, start: week(n), minutes: 40),
      ];
      expect(tips(all.last, all), [WorkoutTipKind.strengthTwice]);
    });
  });

  group('workout texts', () {
    final formats = formatsOf();

    test('measures are written with their units', () {
      String text(WorkoutMeasure measure, double value, [WorkoutType? type]) =>
          measure.format(formats, type ?? WorkoutType.run, value);
      expect(text(WorkoutMeasure.pace, 5.7), '5:42 min/km');
      expect(text(WorkoutMeasure.pace, 20, WorkoutType.swim), '2:00 min/100 m');
      expect(text(WorkoutMeasure.speed, 21.44), '21,4 km/h');
      expect(text(WorkoutMeasure.distance, 5.6), '5,60 km');
      expect(text(WorkoutMeasure.distance, 19.4), '19,4 km');
      expect(text(WorkoutMeasure.duration, 95), '1 h 35 min');
      expect(text(WorkoutMeasure.energy, 1364), '1.364 kcal');
      expect(
        WorkoutMeasure.pace.formatDifference(formats, WorkoutType.run, -0.3),
        '18 s',
      );
      expect(
        WorkoutMeasure.pace.formatDifference(formats, WorkoutType.run, 1.25),
        '1:15 min',
      );
    });

    test('the headline says how it went against last time', () {
      final day = DateTime(2026, 9, 1, 18);
      String headline(Workout before, Workout now, [String language = 'de']) =>
          workoutHeadline(
            formatsOf(language),
            WorkoutInsights.of(now, [before, now]),
          );
      final later = day.add(const Duration(days: 7));
      expect(
        headline(_run(day, minutes: 32), _run(later, minutes: 30)),
        '24 s schneller als letztes Mal',
      );
      expect(
        headline(_run(day, minutes: 30), _run(later, minutes: 32)),
        '24 s langsamer als letztes Mal',
      );
      expect(headline(_run(day), _run(later), 'en'), 'Same as last time');
      expect(
        workoutHeadline(
          formatsOf('pl'),
          WorkoutInsights.of(_run(day), [_run(day)]),
        ),
        'Pierwsza aktywność tego rodzaju',
      );
    });
  });
}
