import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/goals.dart';
import 'package:pulse/data/health_history.dart';
import 'package:pulse/data/metric_catalog.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/settings_controller.dart';

import 'support/fixtures.dart';

/// A Tuesday.
final DateTime _today = DateTime(2026, 10, 6);

DateTime _back(int days) => DateTime(2026, 10, 6 - days);

GoalData _data({
  Map<Metric, Map<int, double>> values = const {},
  List<SleepNight> nights = const [],
  List<Workout> workouts = const [],
}) {
  final keyed = {
    for (final MapEntry(key: metric, value: days) in values.entries)
      metric: {
        for (final MapEntry(key: back, :value) in days.entries)
          dayKey(_back(back)): value,
      },
  };
  return GoalData(
    valueOf: (metric, day) => keyed[metric]?[dayKey(day)],
    nights: nights,
    workouts: workouts,
    sleepGoalHours: 8,
  );
}

Workout _workout(int back, int minutes) => Workout(
  type: WorkoutType.run,
  start: _back(back).add(const Duration(hours: 18)),
  minutes: minutes,
);

void main() {
  group('a goal is reached', () {
    test('by getting to the target', () {
      final data = _data(
        values: {
          Metric.steps: {0: 10000, 1: 9999},
        },
      );
      expect(goalProgress(Goal.steps, 10000, _today, data).reached, isTrue);
      expect(goalProgress(Goal.steps, 10000, _back(1), data).reached, isFalse);
      expect(goalProgress(Goal.steps, 10000, _back(2), data).value, isNull);
      expect(goalProgress(Goal.steps, 10000, _back(1), data).share, 0.9999);
    });

    test('by staying under a limit, but only with something entered', () {
      final data = _data(
        values: {
          Metric.energyIntake: {0: 2000, 1: 2600, 2: 0},
        },
      );
      GoalProgress on(int back) =>
          goalProgress(Goal.energyIntake, 2200, _back(back), data);
      expect(on(0).reached, isTrue);
      expect(on(1).reached, isFalse);
      expect(on(2).reached, isFalse);
      expect(on(3).reached, isFalse);
    });

    test('by the night that ended on the day', () {
      final data = _data(
        nights: [
          SleepNight(
            date: _today,
            bedtimeMinute: 23 * 60,
            totalMinutes: 450,
            segments: const [],
          ),
        ],
      );
      expect(goalValue(Goal.sleepDuration, _today, data), 7.5);
      expect(goalValue(Goal.sleepDuration, _back(1), data), isNull);
      // Seven and a half of eight hours, nothing else judged.
      expect(goalValue(Goal.sleepScore, _today, data), 94);
    });

    test('by the workouts of the week from Monday', () {
      // Monday and Tuesday of this week, Sunday of the last.
      final data = _data(
        workouts: [_workout(2, 60), _workout(1, 30), _workout(0, 45)],
      );
      expect(goalValue(Goal.workouts, _today, data), 2);
      expect(goalValue(Goal.trainingMinutes, _today, data), 75);
      expect(goalValue(Goal.workouts, _back(2), data), 1);
      // A week without a workout is a zero, not a gap.
      expect(goalValue(Goal.workouts, _back(14), data), 0);
    });
  });

  group('a row of days', () {
    test('marks reached, missed, empty, open and coming days', () {
      // Monday to Sunday of the week of the sixth.
      final row = goalRow(
        Goal.steps,
        10000,
        DateTime(2026, 9, 28),
        DateTime(2026, 10, 11),
        _today,
        _data(
          values: {
            Metric.steps: {0: 4000, 1: 12000, 2: 3000, 4: 10000},
          },
        ),
      );
      expect(row.marks.sublist(4, 10), [
        GoalMark.reached,
        GoalMark.none,
        GoalMark.missed,
        GoalMark.reached,
        GoalMark.open,
        GoalMark.ahead,
      ]);
      expect(row.reached, 2);
      // Days without a value and the running day do not count.
      expect(row.counted, 3);
      expect(row.rate, closeTo(2 / 3, 0.001));
    });

    test('counts today once it has reached the goal', () {
      final row = goalRow(
        Goal.steps,
        10000,
        _today,
        _today,
        _today,
        _data(
          values: {
            Metric.steps: {0: 10000},
          },
        ),
      );
      expect(row.marks, [GoalMark.reached]);
    });

    test('leaves a limit open until the day is over', () {
      final row = goalRow(
        Goal.energyIntake,
        2200,
        _back(1),
        _today,
        _today,
        _data(
          values: {
            Metric.energyIntake: {0: 900, 1: 2000},
          },
        ),
      );
      expect(row.marks, [GoalMark.reached, GoalMark.open]);
    });

    test('has one mark a week for a weekly goal', () {
      final row = goalRow(
        Goal.workouts,
        2,
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 30),
        _today,
        _data(workouts: [_workout(29, 40), _workout(28, 40), _workout(20, 40)]),
      );
      // The Mondays of September: 7, 14, 21, 28.
      expect(row.marks, [
        GoalMark.reached,
        GoalMark.missed,
        GoalMark.missed,
        GoalMark.missed,
      ]);
    });

    test('has no rate while nothing counts', () {
      final row = goalRow(Goal.steps, 10000, _today, _today, _today, _data());
      expect(row.rate, isNull);
    });
  });

  test('a year gives the share reached per month', () {
    final rates = goalYear(
      Goal.steps,
      10000,
      2026,
      _today,
      _data(
        values: {
          Metric.steps: {
            // The first five days of October, today left out.
            1: 12000, 2: 12000, 3: 5000, 4: 5000, 5: 12000,
            // The last of September.
            6: 12000,
          },
        },
      ),
    );
    expect(rates[9], closeTo(0.6, 0.001));
    expect(rates[8], 1);
    expect(rates[0], isNull);
    expect(rates[11], isNull);
  });

  group('the streak', () {
    test('runs up to yesterday while today is open', () {
      final data = _data(
        values: {
          Metric.steps: {0: 100, 1: 11000, 2: 11000, 3: 2000, 4: 11000},
        },
      );
      expect(goalStreak(Goal.steps, 10000, _today, data), 2);
    });

    test('counts weeks for a weekly goal', () {
      final data = _data(
        workouts: [_workout(15, 30), _workout(8, 30), _workout(1, 30)],
      );
      // Two weeks before, last week, and this week already.
      expect(goalStreak(Goal.workouts, 1, _today, data), 3);
    });
  });

  group('goals in the settings', () {
    test('start with four and keep the old targets', () {
      final settings = SettingsController(MemoryJsonStore());
      expect(settings.goals, defaultGoals);
      expect(settings.goalTarget(Goal.steps), 10000);
      expect(settings.goalTarget(Goal.water), 2.4);
      expect(settings.goalTarget(Goal.floors), Goal.floors.defaultTarget);
    });

    test('are switched, set and saved', () async {
      final store = MemoryJsonStore();
      SettingsController(store)
        ..setGoalOn(Goal.water, false)
        ..setGoalOn(Goal.intensityMinutes, true)
        ..setGoalTarget(Goal.intensityMinutes, 45)
        ..setGoalTarget(Goal.steps, 12000)
        // Beyond the range it stops at the end.
        ..setGoalTarget(Goal.floors, 900);
      await pumpEventQueue();

      final settings = SettingsController(store);
      await settings.load();
      // In the order of the catalog, not of switching.
      expect(settings.goals, [
        Goal.steps,
        Goal.activeEnergy,
        Goal.intensityMinutes,
        Goal.sleepDuration,
      ]);
      expect(settings.goalTarget(Goal.intensityMinutes), 45);
      expect(settings.goalTarget(Goal.floors), 40);
      // The steps goal is the one the rings read.
      expect(settings.stepGoal, 12000);
    });

    test('ignore names and targets that cannot be', () async {
      final store = MemoryJsonStore();
      await store.write('settings', {
        'goals': ['floors', 'unicorns', 7],
        'goalTargets': {'floors': 9000, 'protein': 120, 'unicorns': 3},
      });
      final settings = SettingsController(store);
      await settings.load();
      expect(settings.goals, [Goal.floors]);
      expect(settings.goalTarget(Goal.floors), Goal.floors.defaultTarget);
      expect(settings.goalTarget(Goal.protein), 120);
    });
  });
}
