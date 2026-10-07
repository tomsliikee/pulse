import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/day_insights.dart';
import 'package:pulse/data/health_history.dart';
import 'package:pulse/data/health_snapshot.dart';
import 'package:pulse/data/metric_catalog.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/workout_insights.dart' show Trend;

final DateTime _today = DateTime(2026, 10, 6);

DateTime _back(int days) => DateTime(2026, 10, 6 - days);

const DayGoals _goals = DayGoals(
  steps: 10000,
  activeEnergy: 500,
  waterMl: 2000,
  sleepHours: 8,
);

/// Day values written as "days back: value" per metric.
DayValue _values(Map<Metric, Map<int, double>> byMetric) {
  final keyed = {
    for (final MapEntry(key: metric, value: days) in byMetric.entries)
      metric: {
        for (final MapEntry(key: back, :value) in days.entries)
          dayKey(_back(back)): value,
      },
  };
  return (metric, day) => keyed[metric]?[dayKey(day)];
}

/// The same steps on each of the days [from] to [to] back.
Map<int, double> _each(int from, int to, double value) => {
  for (var back = from; back <= to; back++) back: value,
};

SleepNight _night(int back, {int minutes = 480}) => SleepNight(
  date: _back(back),
  bedtimeMinute: 23 * 60,
  totalMinutes: minutes,
  segments: const [],
);

DayInsights _insights(
  DayValue valueOf, {
  List<SleepNight> nights = const [],
  List<Workout> workouts = const [],
  HealthHistory? history,
  DateTime? now,
}) => DayInsights.of(
  day: _today,
  valueOf: valueOf,
  nights: nights,
  workouts: workouts,
  goals: _goals,
  history: history,
  now: now,
);

Set<DayTipKind> _kinds(DayInsights insights) => {
  for (final tip in insights.tips) tip.kind,
};

void main() {
  group('the day score', () {
    DayScore score(DayValue valueOf, {List<SleepNight> nights = const []}) =>
        dayScore(day: _today, valueOf: valueOf, nights: nights, goals: _goals);

    test('is null for a day nothing is known about', () {
      expect(score(_values({})).total, isNull);
    });

    test('counts steps for five eighths of the movement', () {
      final parts = score(
        _values({
          Metric.steps: {0: 10000},
          Metric.activeEnergy: {0: 0},
        }),
      ).parts;
      expect(parts[DayScorePart.movement], closeTo(25, 0.001));
      expect(parts.keys, [DayScorePart.movement]);
    });

    test('gives the whole movement to the one value there is', () {
      final half = score(
        _values({
          Metric.steps: {0: 5000},
        }),
      );
      expect(half.parts[DayScorePart.movement], closeTo(20, 0.001));
      // The parts that could not be judged are left out and the rest scaled.
      expect(half.total, 50);
    });

    test('takes the sleep score of the night that ended that day', () {
      final parts = score(
        _values({}),
        nights: [_night(1, minutes: 480), _night(0, minutes: 240)],
      ).parts;
      // Half the goal asleep, nothing else judged: half the sleep score.
      expect(parts[DayScorePart.sleep], closeTo(17.5, 0.001));
    });

    test('judges the resting pulse against the own month', () {
      DayScore withPulse(double today) => score(
        _values({
          Metric.restingHeartRate: {0: today, ..._each(1, 10, 60)},
        }),
      );
      expect(withPulse(60).parts[DayScorePart.heart], 15);
      expect(withPulse(65).parts[DayScorePart.heart], closeTo(7.5, 0.001));
      expect(withPulse(75).parts[DayScorePart.heart], 0);
    });

    test('leaves the pulse out with too few readings before', () {
      final parts = score(
        _values({
          Metric.restingHeartRate: {0: 60, 1: 60, 2: 60},
        }),
      ).parts;
      expect(parts.containsKey(DayScorePart.heart), isFalse);
    });

    test('counts water only for somebody who entered some', () {
      expect(
        score(
          _values({
            Metric.water: {0: 1.0},
          }),
        ).parts[DayScorePart.water],
        closeTo(5, 0.001),
      );
      expect(
        score(
          _values({
            Metric.steps: {0: 100},
          }),
        ).parts.containsKey(DayScorePart.water),
        isFalse,
      );
    });
  });

  group('steps so far', () {
    HealthSnapshot snapshot(List<double?> hours) => HealthSnapshot(
      today: _today,
      loadedAt: _today,
      dayCount: 2,
      series: const {},
      nights: const [null, null],
      heart: const [[], []],
      workouts: const [],
      entries: const [],
      hourly: {Metric.steps: hours},
    );

    test('compares with yesterday up to the same minute', () {
      final soFar = stepsSoFar(
        snapshot([
          // Yesterday: 100 an hour.
          for (var hour = 0; hour < 24; hour++) 100,
          // Today: 300 in each of the first ten hours.
          for (var hour = 0; hour < 24; hour++) hour < 10 ? 300 : null,
        ]),
        DateTime(2026, 10, 6, 15, 30),
      )!;
      expect(soFar.yesterday, 1550);
      expect(soFar.today, 3000);
      expect(soFar.trend, Trend.better);
    });

    test('is null without hours for one of the two days', () {
      expect(
        stepsSoFar(
          snapshot([
            for (var hour = 0; hour < 24; hour++) null,
            for (var hour = 0; hour < 24; hour++) 100,
          ]),
          DateTime(2026, 10, 6, 15, 30),
        ),
        isNull,
      );
    });
  });

  group('the streak', () {
    test('counts today once the goal is reached', () {
      final valueOf = _values({
        Metric.steps: {0: 10000, 1: 12000, 2: 11000, 3: 9000, 4: 15000},
      });
      expect(stepStreak(valueOf, _today, 10000), 3);
    });

    test('ends yesterday while today is still open', () {
      final valueOf = _values({
        Metric.steps: {0: 4000, 1: 12000, 2: 11000, 3: 9000},
      });
      expect(stepStreak(valueOf, _today, 10000), 2);
    });

    test('is broken by a day without steps', () {
      final valueOf = _values({
        Metric.steps: {0: 10000, 2: 11000},
      });
      expect(stepStreak(valueOf, _today, 10000), 1);
    });
  });

  group('the comparison', () {
    test('sets a day against the day before and the week before', () {
      final insights = _insights(
        _values({
          Metric.steps: {0: 9000, 1: 6000, 2: 8000, 5: 10000},
          Metric.restingHeartRate: {0: 62, 1: 58},
        }),
      );
      final steps = insights.measure(DayMeasure.steps)!;
      expect(steps.previous, 6000);
      // Days without a value are left out, not counted as zero.
      expect(steps.average, 8000);
      expect(steps.againstPrevious, Trend.better);
      // A lower resting pulse is the better one.
      expect(
        insights.measure(DayMeasure.restingHeartRate)!.againstPrevious,
        Trend.worse,
      );
      expect(insights.measure(DayMeasure.water), isNull);
    });

    test('marks the highest day among at least seven', () {
      HealthHistory history(Map<int, double> steps) => HealthHistory()
        ..merge({
          Metric.steps: {
            for (final MapEntry(key: back, :value) in steps.entries)
              _back(back): value,
          },
        });
      final many = {0: 14000.0, ..._each(1, 6, 9000)};
      expect(
        _insights(
          _values({Metric.steps: many}),
          history: history(many),
        ).measure(DayMeasure.steps)!.isBest,
        isTrue,
      );
      final few = {0: 14000.0, ..._each(1, 3, 9000)};
      expect(
        _insights(
          _values({Metric.steps: few}),
          history: history(few),
        ).measure(DayMeasure.steps)!.isBest,
        isFalse,
      );
      final beaten = {0: 14000.0, ..._each(1, 6, 9000), 7: 20000.0};
      expect(
        _insights(
          _values({Metric.steps: beaten}),
          history: history(beaten),
        ).measure(DayMeasure.steps)!.isBest,
        isFalse,
      );
    });

    test('lists the workouts and the night of the day', () {
      final insights = _insights(
        _values({}),
        nights: [_night(1), _night(0)],
        workouts: [
          Workout(type: WorkoutType.run, start: _back(1), minutes: 30),
          Workout(
            type: WorkoutType.walk,
            start: DateTime(2026, 10, 6, 9),
            minutes: 40,
          ),
        ],
      );
      expect(insights.night!.date, _today);
      expect([for (final w in insights.workouts) w.type], [WorkoutType.walk]);
    });
  });

  group('the hints', () {
    final afternoon = DateTime(2026, 10, 6, 15, 30);
    final evening = DateTime(2026, 10, 6, 21);

    test('wait for three days before', () {
      final insights = _insights(
        _values({
          Metric.steps: {0: 9000, 1: 9000},
        }),
        now: afternoon,
      );
      expect(_kinds(insights), {DayTipKind.fewToCompare});
    });

    test('say so when nothing stands out', () {
      final insights = _insights(
        _values({Metric.steps: _each(0, 14, 5000)}),
        now: afternoon,
      );
      expect(_kinds(insights), {DayTipKind.keepGoing});
    });

    test('name the steps missing once the goal is close', () {
      final insights = _insights(
        _values({
          Metric.steps: {0: 8600, ..._each(1, 14, 5000)},
        }),
        now: afternoon,
      );
      expect(insights.tips.single.kind, DayTipKind.goalClose);
      expect(insights.tips.single.value, 1400);
    });

    test('warn of a streak that ends tonight, in the evening only', () {
      final valueOf = _values({
        Metric.steps: {0: 3000, ..._each(1, 14, 11000)},
      });
      expect(
        _kinds(_insights(valueOf, now: evening)),
        contains(DayTipKind.streakAtRisk),
      );
      expect(
        _kinds(_insights(valueOf, now: afternoon)),
        isNot(contains(DayTipKind.streakAtRisk)),
      );
    });

    test('praise a streak once today has reached the goal', () {
      final insights = _insights(
        _values({Metric.steps: _each(0, 14, 11000)}),
        now: afternoon,
      );
      expect(insights.tips.single.kind, DayTipKind.streak);
      expect(insights.tips.single.value, 15);
    });

    test('notice little water only where water is entered at all', () {
      final steps = _each(0, 14, 5000);
      expect(
        _kinds(
          _insights(
            _values({
              Metric.steps: steps,
              Metric.water: {0: 0.2, 1: 2.0},
            }),
            now: afternoon,
          ),
        ),
        contains(DayTipKind.littleWater),
      );
      expect(
        _kinds(_insights(_values({Metric.steps: steps}), now: afternoon)),
        isNot(contains(DayTipKind.littleWater)),
      );
      // In the morning nobody is behind yet.
      expect(
        _kinds(
          _insights(
            _values({
              Metric.steps: steps,
              Metric.water: {1: 2.0},
            }),
            now: DateTime(2026, 10, 6, 9),
          ),
        ),
        isNot(contains(DayTipKind.littleWater)),
      );
    });

    test('point to the bedtime within the hour before it', () {
      // Up at seven after eight hours: to bed at eleven.
      final nights = [for (var back = 6; back >= 0; back--) _night(back)];
      final steps = _values({Metric.steps: _each(0, 14, 5000)});
      final late = _insights(
        steps,
        nights: nights,
        now: DateTime(2026, 10, 6, 22, 30),
      );
      expect(late.tips.first.kind, DayTipKind.bedtimeNear);
      expect(late.tips.first.value, 23 * 60);
      expect(
        _kinds(_insights(steps, nights: nights, now: evening)),
        isNot(contains(DayTipKind.bedtimeNear)),
      );
    });

    test('notice a resting pulse above the own usual', () {
      final insights = _insights(
        _values({
          Metric.steps: _each(0, 14, 5000),
          Metric.restingHeartRate: {0: 66, ..._each(1, 10, 60)},
        }),
      );
      expect(insights.tips.single.kind, DayTipKind.pulseHigh);
      expect(insights.tips.single.value, 6);
    });

    test('notice a week with clearly fewer steps than the one before', () {
      final insights = _insights(
        _values({
          Metric.steps: {0: 4000, ..._each(1, 7, 6000), ..._each(8, 14, 10000)},
        }),
      );
      expect(insights.tips.single.kind, DayTipKind.stepsFalling);
      expect(insights.tips.single.value, 40);
    });

    test('are three at most, and leave out the time of day for a past day', () {
      final valueOf = _values({
        Metric.steps: {0: 8500, ..._each(1, 7, 6000), ..._each(8, 14, 12000)},
        Metric.restingHeartRate: {0: 70, ..._each(1, 10, 60)},
        Metric.water: {0: 0.1},
      });
      expect(_insights(valueOf, now: afternoon).tips, hasLength(3));
      expect(_kinds(_insights(valueOf)), {
        DayTipKind.pulseHigh,
        DayTipKind.stepsFalling,
      });
    });
  });
}
