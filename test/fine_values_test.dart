import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/fine_values.dart';
import 'package:pulse/data/health_controller.dart';
import 'package:pulse/data/health_history.dart';
import 'package:pulse/data/health_snapshot.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/metric_catalog.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/snapshot_builder.dart';
import 'package:pulse/data/workout_archive.dart';

import 'support/fixtures.dart';

void main() {
  final now = DateTime(2026, 10, 6, 15, 30);
  DateTime at(int daysAgo, int hour, [int minute = 0]) =>
      DateTime(2026, 10, 6 - daysAgo, hour, minute);

  /// [count] minutes at [bpm] from [start] on.
  List<(DateTime, double)> stretch(DateTime start, int count, double bpm) => [
    for (var i = 0; i < count; i++) (start.add(Duration(minutes: i)), bpm),
  ];

  FineDay day(
    List<(DateTime, double)> beats, {
    List<(DateTime, DateTime, WorkoutType)> workouts = const [],
    double Function(double bpm)? net,
    double? kg,
    Map<int, double>? stepsByHour,
    double? steps,
    double workoutSteps = 0,
    double? perStep,
  }) => fineDay(
    beats,
    on: at(0, 0),
    moderate: 110,
    vigorous: 135,
    workouts: workouts,
    netPerMinute: net,
    kg: kg,
    stepsByHour: stepsByHour,
    steps: steps,
    workoutSteps: workoutSteps,
    perStep: perStep,
  );

  group('formulas', () {
    test('the maximum heart rate is 208 less 0.7 times the age', () {
      expect(fineMaxHeartRate(34), 184);
      expect(fineMaxHeartRate(50), 173);
    });

    test('the energy of a minute follows the heart rate, by sex', () {
      expect(
        keytelPerMinute(140, kg: 80, age: 34, sex: Sex.male),
        closeTo(13.382, 0.001),
      );
      expect(
        keytelPerMinute(140, kg: 80, age: 34, sex: Sex.female),
        closeTo(8.274, 0.001),
      );
    });

    test('the burn at rest comes from the source where that is plausible, '
        'else from weight, height, age and sex', () {
      const profile = FineProfile(age: 34, sex: Sex.male, heightCm: 180);
      // 2300 kcal of base over a whole day.
      expect(
        restingPerMinute(
          total: 3300,
          active: 1000,
          minutes: 1440,
          profile: profile,
          kg: 80,
        ),
        closeTo(2300 / 1440, 1e-9),
      );
      // A total that holds no base is not believed: Mifflin-St Jeor's 1760.
      for (final total in <double?>[1000, null]) {
        expect(
          restingPerMinute(
            total: total,
            active: 1000,
            minutes: 1440,
            profile: profile,
            kg: 80,
          ),
          closeTo(1760 / 1440, 1e-9),
        );
      }
      expect(
        restingBurnPerDay(kg: 80, heightCm: 180, age: 34, sex: Sex.female),
        1594,
      );
      // Nothing to go by.
      expect(
        restingPerMinute(
          total: null,
          active: null,
          minutes: 1440,
          profile: const FineProfile(age: 34, sex: Sex.male),
          kg: 80,
        ),
        isNull,
      );
    });
  });

  group('fineDay', () {
    test('nine minutes in a row do not count, ten do', () {
      expect(day(stretch(at(0, 9), 9, 120)).minutes, 0);
      expect(day(stretch(at(0, 9), 10, 120)).minutes, 10);
    });

    test('readings a few minutes apart are joined by the pulse between '
        'them, readings further apart are not', () {
      // One reading every three minutes for half an hour.
      final sparse = [
        for (var minute = 0; minute <= 27; minute += 3)
          (at(0, 9, minute), 120.0),
      ];
      expect(day(sparse).minutes, 28);
      // On the way from 100 to 130 the pulse passes 110 after two minutes.
      final rising = [
        (at(0, 9), 100.0),
        (at(0, 9, 6), 130.0),
        ...stretch(at(0, 9, 7), 9, 130),
      ];
      expect(day(rising).minutes, 14);
      // Seven minutes without a reading stay empty.
      final apart = [
        ...stretch(at(0, 9), 6, 120),
        ...stretch(at(0, 9, 13), 6, 120),
      ];
      expect(day(apart).minutes, 0);
    });

    test('one minute below does not end a stretch and does not count; two '
        'end it', () {
      final dip = [
        ...stretch(at(0, 9), 5, 120),
        (at(0, 9, 5), 90.0),
        ...stretch(at(0, 9, 6), 5, 120),
      ];
      expect(day(dip).minutes, 10);
      final two = [
        ...stretch(at(0, 9), 5, 120),
        ...stretch(at(0, 9, 5), 2, 90),
        ...stretch(at(0, 9, 7), 5, 120),
      ];
      expect(day(two).minutes, 0);
    });

    test('a vigorous minute counts twice, and an hour ends where it ends', () {
      final result = day([
        ...stretch(at(0, 9, 54), 6, 120),
        ...stretch(at(0, 10), 6, 140),
      ]);
      expect(result.minutesByHour, {at(0, 9): 6, at(0, 10): 12});
    });

    test('short spikes outside a workout count for nothing', () {
      final result = day([
        ...stretch(at(0, 9), 3, 150),
        ...stretch(at(0, 12), 4, 125),
      ], net: (bpm) => 5);
      expect(result.minutes, 0);
      expect(result.kcal, 0);
    });

    test('in a workout every minute gives energy, and those at a moderate '
        'pulse give minutes, however short', () {
      final result = day(
        [
          ...stretch(at(0, 18), 5, 100),
          ...stretch(at(0, 18, 5), 5, 120),
          // After the workout.
          ...stretch(at(0, 18, 30), 5, 120),
        ],
        workouts: [(at(0, 18), at(0, 18, 10), WorkoutType.run)],
        net: (bpm) => bpm / 10,
      );
      expect(result.minutes, 5);
      expect(result.kcal, closeTo(5 * 10 + 5 * 12, 1e-9));
      expect(result.workoutKcal, {0: closeTo(110, 1e-9)});
    });

    test('a minute never costs less than nothing', () {
      final result = day(
        stretch(at(0, 18), 10, 60),
        workouts: [(at(0, 18), at(0, 18, 10), WorkoutType.run)],
        net: (bpm) => -1,
      );
      expect(result.kcal, 0);
      expect(result.workoutKcal, isEmpty);
    });

    test('strength, yoga and unnamed workouts give a fixed rate for each of '
        'their minutes, whatever the pulse and without one', () {
      expect(fixedNetPerMinute(WorkoutType.strength, 80), closeTo(3.5, 1e-9));
      expect(fixedNetPerMinute(WorkoutType.yoga, 80), closeTo(2.1, 1e-9));
      expect(fixedNetPerMinute(WorkoutType.other, 80), closeTo(3.5, 1e-9));
      for (final type in [
        WorkoutType.run,
        WorkoutType.ride,
        WorkoutType.walk,
        WorkoutType.hike,
        WorkoutType.swim,
      ]) {
        expect(fixedNetPerMinute(type, 80), isNull, reason: '$type');
      }

      // An hour in the gym: the pulse is read for ten minutes of it only.
      final gym = day(
        stretch(at(0, 18), 10, 150),
        workouts: [(at(0, 18), at(0, 19), WorkoutType.strength)],
        net: (bpm) => 20,
        kg: 80,
      );
      expect(gym.kcal, closeTo(60 * 3.5, 1e-9));
      expect(gym.workoutKcal, {0: closeTo(210, 1e-9)});
      // The minutes still follow the pulse.
      expect(gym.minutes, 20);

      // A run of the same time follows the pulse, minute by minute.
      final run = day(
        stretch(at(0, 18), 10, 150),
        workouts: [(at(0, 18), at(0, 19), WorkoutType.run)],
        net: (bpm) => 20,
        kg: 80,
      );
      expect(run.kcal, closeTo(10 * 20, 1e-9));
    });

    test('a step costs by weight and height', () {
      expect(kcalPerStep(kg: 80, heightCm: 180), closeTo(0.029808, 1e-9));
      expect(kcalPerStep(kg: 80), closeTo(0.028, 1e-9));
    });

    test('the steps of an hour count beside what is counted already, 100 '
        'for each of its counted minutes left out', () {
      final result = day(
        // A brisk walk of 20 minutes from nine.
        stretch(at(0, 9), 20, 120),
        net: (bpm) => 5,
        stepsByHour: {8: 500, 9: 2600, 10: 0, 18: 1500},
        workouts: [(at(0, 18), at(0, 18, 30), WorkoutType.strength)],
        kg: 80,
        perStep: 0.03,
      );
      expect(result.kcalByHour, {
        at(0, 8): closeTo(500 * 0.03, 1e-9),
        // The walk itself, and the 600 steps beside it.
        at(0, 9): closeTo(20 * 5 + 600 * 0.03, 1e-9),
        // Half an hour in the gym takes all the steps of its hour.
        at(0, 18): closeTo(30 * 3.5, 1e-9),
      });
      expect(result.unplacedKcal, 0);
    });

    test('where only the steps of the day are known, those of its workouts '
        'and 100 for each minute of a stretch are left out', () {
      final result = day(
        stretch(at(0, 9), 20, 120),
        net: (bpm) => 5,
        steps: 9000,
        workoutSteps: 3000,
        perStep: 0.03,
      );
      expect(result.unplacedKcal, closeTo((9000 - 3000 - 2000) * 0.03, 1e-9));
      expect(result.kcal, closeTo(100 + 120, 1e-9));
      // Never less than nothing.
      expect(
        day(
          const [],
          net: (bpm) => 5,
          steps: 500,
          workoutSteps: 900,
          perStep: 1,
        ).kcal,
        0,
      );
    });

    test('steps alone give no energy without a way to it', () {
      expect(day(const [], stepsByHour: {9: 1000}, perStep: 0.03).kcal, isNull);
      expect(day(const [], net: (bpm) => 5, stepsByHour: {9: 1000}).kcal, 0);
    });

    test('without a way to the energy there is none, but the minutes', () {
      final result = day(stretch(at(0, 9), 10, 120));
      expect(result.kcal, isNull);
      expect(result.minutes, 10);
    });

    test('the beats of a minute are averaged', () {
      final result = day([
        for (var i = 0; i < 10; i++) ...[
          (at(0, 9, i), 100.0),
          (at(0, 9, i).add(const Duration(seconds: 30)), 130.0),
        ],
      ]);
      expect(result.minutes, 10);
    });
  });

  group('buildSnapshot', () {
    RawSample beat(DateTime time, double bpm) =>
        RawSample(Metric.heartRate, time, bpm);
    RawSample resting(int daysAgo, double bpm) =>
        RawSample(Metric.restingHeartRate, at(daysAgo, 6), bpm);
    const profile = FineProfile(age: 34, sex: Sex.male, heightCm: 180);
    // Resting 60 and a maximum of 184: moderate from 109.6, vigorous from
    // 134.4.
    RawReadings readings({bool weight = true}) => RawReadings(
      samples: [
        resting(1, 60),
        if (weight) RawSample(Metric.weight, at(1, 7), 80),
        // Yesterday: a workout of 20 minutes at 140, and a spike of 3.
        for (final (time, bpm) in stretch(at(1, 18), 20, 140)) beat(time, bpm),
        for (final (time, bpm) in stretch(at(1, 12), 3, 150)) beat(time, bpm),
        // Today: a brisk walk of 12 minutes at 120.
        for (final (time, bpm) in stretch(at(0, 9), 12, 120)) beat(time, bpm),
        // The day before yesterday has no resting heart rate before it.
        for (final (time, bpm) in stretch(at(2, 9), 12, 120)) beat(time, bpm),
      ],
      dailyTotals: {
        Metric.totalEnergy: {at(1, 0): 3300, at(0, 0): 2000},
        Metric.activeEnergy: {at(1, 0): 1000, at(0, 0): 514},
      },
      workouts: [
        Workout(
          type: WorkoutType.run,
          start: at(1, 18),
          minutes: 20,
          kcal: 400,
        ),
      ],
    );

    test('the fine values stand beside the source\'s own', () {
      final snapshot = buildSnapshot(
        now: now,
        maxHeartRate: 186,
        fine: profile,
        raw: readings(),
      );
      final today = snapshot.dayCount - 1;
      // Yesterday's base is 2300 kcal over the day.
      final perMinute =
          keytelPerMinute(140, kg: 80, age: 34, sex: Sex.male) - 2300 / 1440;

      expect(snapshot.value(Metric.activeEnergy, today - 1), 1000);
      expect(
        snapshot.value(Metric.fineActiveEnergy, today - 1),
        closeTo(20 * perMinute, 1e-6),
      );
      expect(
        snapshot.value(Metric.fineTotalEnergy, today - 1),
        closeTo(2300 + 20 * perMinute, 1e-6),
      );
      // The coarse minutes count the spike as well: 20 and 3, all twice.
      expect(snapshot.value(Metric.intensityMinutes, today - 1), 46);
      expect(snapshot.value(Metric.fineIntensityMinutes, today - 1), 40);
      expect(snapshot.workouts.single.kcal, 400);
      expect(snapshot.workouts.single.fineKcal, (20 * perMinute).round());

      // Today has run for 930 minutes; its base is 1486 kcal so far.
      final walking =
          keytelPerMinute(120, kg: 80, age: 34, sex: Sex.male) - 1486 / 930;
      expect(snapshot.value(Metric.fineIntensityMinutes, today), 12);
      expect(
        snapshot.value(Metric.fineActiveEnergy, today),
        closeTo(12 * walking, 1e-6),
      );
      expect(
        snapshot.hourly[Metric.fineActiveEnergy]![HealthSnapshot.hoursPerDay +
            9],
        closeTo(12 * walking, 1e-6),
      );
      expect(snapshot.hourly[Metric.fineIntensityMinutes]![18], 40);
      // A day that cannot be judged has no fine value.
      expect(snapshot.value(Metric.fineIntensityMinutes, today - 2), isNull);
    });

    test(
      'the steps beside the workout and the walk are part of the energy',
      () {
        final base = readings();
        final plain = buildSnapshot(now: now, fine: profile, raw: base);
        final withSteps = buildSnapshot(
          now: now,
          fine: profile,
          raw: RawReadings(
            samples: base.samples,
            dailyTotals: {
              ...base.dailyTotals,
              Metric.steps: {at(1, 0): 12000, at(0, 0): 4000},
            },
            hourlyTotals: {
              Metric.steps: {
                // Yesterday: 8,000 over the day, and 4,000 in the hour of the
                // run, of which the run's 20 minutes take 2,000.
                at(1, 10): 8000,
                at(1, 18): 4000,
                // Today: the walk of 12 minutes and 1,500 steps, and the rest.
                at(0, 9): 1500,
                at(0, 13): 2500,
              },
            },
            workouts: base.workouts,
          ),
        );
        final today = plain.dayCount - 1;
        final step = kcalPerStep(kg: 80, heightCm: 180);

        expect(
          withSteps.value(Metric.fineActiveEnergy, today - 1),
          closeTo(
            plain.value(Metric.fineActiveEnergy, today - 1)! +
                (8000 + 2000) * step,
            1e-6,
          ),
        );
        expect(
          withSteps.value(Metric.fineActiveEnergy, today),
          closeTo(
            plain.value(Metric.fineActiveEnergy, today)! + (300 + 2500) * step,
            1e-6,
          ),
        );
        expect(
          withSteps.hourly[Metric.fineActiveEnergy]![10],
          closeTo(8000 * step, 1e-6),
        );
        // The parts add up to the whole.
        final yesterday = today - 1;
        final workout = withSteps.value(Metric.fineWorkoutEnergy, yesterday)!;
        expect(workout, closeTo(withSteps.workouts.single.fineKcal!, 0.5));
        // The spike at noon is no stretch.
        expect(withSteps.value(Metric.fineStretchEnergy, yesterday), 0);
        expect(
          withSteps.value(Metric.fineStepEnergy, yesterday),
          closeTo(10000 * step, 1e-6),
        );
        expect(withSteps.value(Metric.fineWorkoutEnergy, today), 0);
        for (final index in [yesterday, today]) {
          expect(
            Metric.fineParts.fold<double>(
              0,
              (sum, part) => sum + withSteps.value(part, index)!,
            ),
            closeTo(withSteps.value(Metric.fineActiveEnergy, index)!, 1e-6),
          );
        }
        // The workout itself is as before.
        expect(
          withSteps.workouts.single.fineKcal,
          plain.workouts.single.fineKcal,
        );
        expect(
          withSteps.value(Metric.fineIntensityMinutes, today - 1),
          plain.value(Metric.fineIntensityMinutes, today - 1),
        );
      },
    );

    test('without the profile there are none, and without a weight or the '
        'sex the minutes alone', () {
      final none = buildSnapshot(now: now, maxHeartRate: 186, raw: readings());
      expect(none.series.keys.where((metric) => metric.isFine), isEmpty);

      for (final snapshot in [
        buildSnapshot(now: now, fine: profile, raw: readings(weight: false)),
        buildSnapshot(
          now: now,
          fine: const FineProfile(age: 34, heightCm: 180),
          raw: readings(),
        ),
      ]) {
        expect(snapshot.has(Metric.fineIntensityMinutes), isTrue);
        expect(snapshot.has(Metric.fineActiveEnergy), isFalse);
        expect(snapshot.has(Metric.fineTotalEnergy), isFalse);
        expect(snapshot.workouts.single.fineKcal, isNull);
      }

      // The weight the profile brings along stands in.
      final brought = buildSnapshot(
        now: now,
        fine: const FineProfile(
          age: 34,
          sex: Sex.male,
          heightCm: 180,
          weightKg: 80,
        ),
        raw: readings(weight: false),
      );
      expect(brought.has(Metric.fineActiveEnergy), isTrue);
    });

    test('the fine values of days that were not read again are kept', () {
      final previous = buildSnapshot(
        now: at(0, 8),
        fine: profile,
        raw: readings(),
      );
      final fresh = buildSnapshot(
        now: now,
        fine: profile,
        raw: RawReadings(
          samples: [
            for (final sample in readings().samples)
              if (sample.metric != Metric.heartRate ||
                  !sample.time.isBefore(at(0, 0)))
                sample,
          ],
          dailyTotals: readings().dailyTotals,
          workouts: readings().workouts,
        ),
      );
      final today = fresh.dayCount - 1;
      expect(fresh.value(Metric.fineIntensityMinutes, today - 1), isNull);
      expect(fresh.workouts.single.fineKcal, isNull);

      final merged = keepHeartBefore(
        at(0, 0),
        fresh: fresh,
        previous: previous,
      );
      expect(merged.value(Metric.fineIntensityMinutes, today - 1), 40);
      expect(
        merged.value(Metric.fineActiveEnergy, today - 1),
        previous.value(Metric.fineActiveEnergy, today - 1),
      );
      expect(merged.value(Metric.fineIntensityMinutes, today), 12);
      expect(
        merged.workouts.single.fineKcal,
        previous.workouts.single.fineKcal,
      );
    });

    test('the fine view shows the fine values in the place of the others, '
        'and nothing where there is none', () {
      final snapshot = buildSnapshot(
        now: now,
        maxHeartRate: 186,
        fine: profile,
        raw: readings(),
      );
      final fine = snapshot.fine;
      final today = snapshot.dayCount - 1;

      expect(
        fine.value(Metric.activeEnergy, today - 1),
        snapshot.value(Metric.fineActiveEnergy, today - 1),
      );
      expect(fine.value(Metric.intensityMinutes, today - 1), 40);
      expect(fine.value(Metric.intensityMinutes, today - 2), isNull);
      expect(
        fine.hourly[Metric.intensityMinutes],
        snapshot.hourly[Metric.fineIntensityMinutes],
      );
      expect(fine.workouts.single.kcal, snapshot.workouts.single.fineKcal);
      expect(fine.value(Metric.restingHeartRate, today - 1), 60);

      // Without fine values the three metrics are gone from the view.
      final none = buildSnapshot(now: now, raw: readings()).fine;
      expect(none.has(Metric.activeEnergy), isFalse);
      expect(none.has(Metric.totalEnergy), isFalse);
      expect(none.workouts.single.kcal, isNull);
    });

    test('a snapshot keeps its fine values through its saved form', () {
      final snapshot = buildSnapshot(now: now, fine: profile, raw: readings());
      final read = HealthSnapshot.fromJson(snapshot.toJson())!;
      final today = snapshot.dayCount - 1;
      expect(
        read.value(Metric.fineActiveEnergy, today - 1),
        snapshot.value(Metric.fineActiveEnergy, today - 1),
      );
      expect(read.workouts.single.fineKcal, snapshot.workouts.single.fineKcal);
    });
  });

  test('the history shows the fine values of the days that have one', () {
    final history = HealthHistory()
      ..merge({
        Metric.activeEnergy: {at(2, 0): 900, at(1, 0): 1000},
        Metric.fineActiveEnergy: {at(1, 0): 640},
        Metric.steps: {at(1, 0): 8000},
      });
    final fine = history.fine;
    expect(fine.value(Metric.activeEnergy, at(1, 0)), 640);
    expect(fine.value(Metric.activeEnergy, at(2, 0)), isNull);
    expect(fine.value(Metric.totalEnergy, at(1, 0)), isNull);
    expect(fine.value(Metric.steps, at(1, 0)), 8000);
    expect(history.value(Metric.activeEnergy, at(1, 0)), 1000);
  });

  test('a fine energy once worked out stays with the archived workout', () {
    final start = at(1, 18);
    Workout workout({int? fineKcal}) => Workout(
      type: WorkoutType.run,
      start: start,
      minutes: 20,
      kcal: 400,
      fineKcal: fineKcal,
    );
    final merged = mergeWorkouts([workout(fineKcal: 230)], [workout()]);
    // Nothing changes: the stored one already says it.
    expect(merged, isNull);
    final added = mergeWorkouts([workout()], [workout(fineKcal: 230)])!;
    expect(added.single.fineKcal, 230);
  });

  test('the fine metrics are never listed', () {
    expect(Metric.listed.where((metric) => metric.isFine), isEmpty);
    expect(Metric.listed.length, Metric.values.length - 6);
    for (final MapEntry(key: metric, value: fine) in Metric.fine.entries) {
      expect(fine.shownAs, metric);
    }
  });

  group('HealthController', () {
    Future<HealthController> started(MemoryJsonStore store) async {
      await store.write(StoreKeys.settings, {
        'birthDate': '1992-03-07',
        'sex': 'male',
        'heightCm': 180,
      });
      final controller = HealthController(
        repository: FixtureRepository(),
        store: store,
        clock: () => fixtureNow,
      );
      await controller.start();
      return controller;
    }

    test(
      'reads with the profile and shows the fine values once asked',
      () async {
        final controller = await started(MemoryJsonStore());
        final raw = controller.snapshot;
        final coarse = controller.value(Metric.activeEnergy);
        final fine = raw.value(Metric.fineActiveEnergy, raw.dayCount - 1);
        expect(raw.has(Metric.fineIntensityMinutes), isTrue);
        expect(fine, isNotNull);
        expect(fine, isNot(coarse));

        var notified = 0;
        controller.addListener(() => notified++);
        controller.fineValues = true;
        expect(notified, 1);
        expect(controller.value(Metric.activeEnergy), fine);
        expect(controller.valueOn(Metric.activeEnergy, controller.today), fine);
        expect(
          controller.history!.value(Metric.activeEnergy, controller.today),
          fine,
        );
        // The same view until the data changes.
        expect(identical(controller.snapshot, controller.snapshot), isTrue);
        expect(identical(controller.workouts, controller.workouts), isTrue);

        controller.fineValues = false;
        expect(controller.value(Metric.activeEnergy), coarse);
        expect(identical(controller.snapshot, raw), isTrue);
      },
    );

    test(
      'a snapshot saved without fine values is read again in full',
      () async {
        final store = MemoryJsonStore();
        await store.write(
          StoreKeys.snapshot,
          buildSnapshot(now: fixtureNow, raw: fixtureReadings()).toJson(),
        );
        await store.write(StoreKeys.settings, {'birthDate': '1992-03-07'});
        final repository = FixtureRepository();
        final controller = HealthController(
          repository: repository,
          store: store,
          clock: () => fixtureNow,
        );
        await controller.start();
        expect(repository.loadedWith, [null]);
        expect(repository.fineProfiles.single!.age, 34);
        // And then built on as usual.
        await controller.refresh();
        expect(repository.loadedWith.last, isNotNull);
      },
    );

    test(
      'a workout is removed as it was read, whatever the page showed',
      () async {
        final store = MemoryJsonStore();
        final controller = await started(store);
        controller.fineValues = true;
        final shown = controller.workouts.last;
        final removed = await controller.removeWorkout(shown);
        expect(removed.workout.kcal, isNot(shown.kcal));
        expect(removed.workout.fineKcal, shown.kcal);
      },
    );
  });
}
