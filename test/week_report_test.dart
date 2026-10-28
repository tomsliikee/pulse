import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/background/week_notice.dart';
import 'package:pulse/data/day_insights.dart';
import 'package:pulse/data/goals.dart';
import 'package:pulse/data/health_history.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/metric_catalog.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/week_report.dart';
import 'package:pulse/data/workout_insights.dart' show Trend;

import 'support/fixtures.dart';

const _goals = DayGoals(
  steps: 10000,
  activeEnergy: 500,
  waterMl: 2400,
  sleepHours: 8,
);

/// Monday 2026-09-28; the week before began on the 21st.
final _monday = DateTime(2026, 9, 28);

DateTime _day(int fromMonday) =>
    DateTime(_monday.year, _monday.month, _monday.day + fromMonday);

SleepNight _night(DateTime date, int asleep) => SleepNight(
  date: date,
  bedtimeMinute: 23 * 60,
  totalMinutes: asleep,
  segments: const [],
);

WeekReport _report({
  required Map<int, double> steps,
  List<SleepNight> nights = const [],
  List<Workout> workouts = const [],
  DateTime? monday,
  DateTime? today,
  HealthHistory? history,
  Map<Goal, double> goals = const {Goal.steps: 10000},
}) => weekReport(
  monday: monday ?? _monday,
  data: GoalData(
    valueOf: (metric, day) =>
        metric == Metric.steps ? steps[dayKey(day)] : null,
    nights: nights,
    workouts: workouts,
    sleepGoalHours: 8,
  ),
  dayGoals: _goals,
  goals: goals,
  today: today ?? _day(9),
  history: history,
);

void main() {
  test('the score is the mean of the days that have one, against the week '
      'before', () {
    final report = _report(
      steps: {
        // The week before: half the goal every day.
        for (var i = -7; i < 0; i++) dayKey(_day(i)): 5000,
        // This week: the goal on four days, nothing known on three.
        for (var i = 0; i < 4; i++) dayKey(_day(i)): 10000,
      },
    );
    expect(report.dayScores, [100, 100, 100, 100, null, null, null]);
    expect(report.score, 100);
    expect(report.previousScore, 50);
    expect(report.running, isFalse);
    expect(report.isEmpty, isFalse);
    expect(report.bestDay, 0);

    final steps = report.measure(WeekMeasure.steps)!;
    expect(steps.value, 10000);
    expect(steps.previous, 5000);
    expect(steps.usual, 5000);
    expect(steps.againstPrevious, Trend.better);
    expect(report.measure(WeekMeasure.asleep), isNull);
  });

  test('a week that is still running counts up to today', () {
    final report = _report(
      steps: {for (var i = 0; i < 7; i++) dayKey(_day(i)): 8000},
      today: _day(2),
    );
    expect(report.running, isTrue);
    expect(report.dayScores.sublist(3), [null, null, null, null]);
    expect(report.measure(WeekMeasure.steps)!.value, 8000);
    // Sunday itself is still running too.
    expect(
      _report(steps: {dayKey(_monday): 1}, today: _day(6)).running,
      isTrue,
    );
  });

  test('a week nothing is known about is empty', () {
    final report = _report(steps: const {});
    expect(report.isEmpty, isTrue);
    expect(report.score, isNull);
    expect(report.bestDay, isNull);
    expect(report.records, isEmpty);
  });

  test('the best night, the debt and the nights of the week', () {
    final nights = [
      _night(_day(-1), 300),
      _night(_day(0), 420),
      _night(_day(2), 500),
      _night(_day(6), 450),
      _night(_day(7), 600),
    ];
    final report = _report(steps: const {}, nights: nights);
    expect(report.nights.map((night) => night.date), [
      _day(0),
      _day(2),
      _day(6),
    ]);
    expect(report.bestNight!.date, _day(2));
    // 60 + 0 (twenty over pay nothing back beyond the debt) + 30.
    expect(report.debt.minutes, 70);
    expect(report.debt.nights, 3);
    expect(report.measure(WeekMeasure.asleep)!.value, closeTo(456.7, 0.1));
    expect(report.measure(WeekMeasure.asleep)!.previous, 300);
  });

  test('a day higher than every day before is a record, others are not', () {
    final history = HealthHistory()
      ..merge({
        Metric.steps: {
          for (var back = 1; back <= 20; back++) _day(-back): 9000,
        },
      });
    final steps = {
      for (var i = 0; i < 7; i++) dayKey(_day(i)): i == 3 ? 15000.0 : 7000.0,
    };
    final report = _report(steps: steps, history: history);
    expect(report.records, hasLength(1));
    expect(report.records.single.measure, DayMeasure.steps);
    expect(report.records.single.day, _day(3));
    expect(report.records.single.value, 15000);

    final lower = _report(
      steps: {for (var i = 0; i < 7; i++) dayKey(_day(i)): 7000},
      history: history,
    );
    expect(lower.records, isEmpty);
    // Without the history nobody knows the days before.
    expect(_report(steps: steps).records, isEmpty);
  });

  test('goals are marked day by day and week by week', () {
    final workouts = [
      for (final i in [0, 2, 4])
        Workout(
          type: WorkoutType.run,
          start: _day(i).add(const Duration(hours: 18)),
          minutes: 30,
          kcal: 300,
        ),
      Workout(type: WorkoutType.run, start: _day(8), minutes: 30),
    ];
    final report = _report(
      steps: {
        for (var i = 0; i < 7; i++) dayKey(_day(i)): i < 5 ? 11000 : 4000,
      },
      workouts: workouts,
      goals: const {Goal.steps: 10000, Goal.workouts: 3},
    );
    final steps = report.goals.first;
    expect(steps.row.marks, hasLength(7));
    expect(steps.row.reached, 5);
    final weekly = report.goals.last;
    expect(weekly.row.marks, [GoalMark.reached]);
    expect(report.workouts, hasLength(3));
    expect(report.workoutMinutes, 90);
    expect(report.workoutEnergy, 900);
  });

  test('a week over the turn of the year and one with a clock change are '
      'seven days', () {
    final newYear = DateTime(2025, 12, 29);
    final report = _report(
      steps: {
        for (var i = 0; i < 7; i++) dayKey(DateTime(2025, 12, 29 + i)): 10000,
      },
      monday: newYear,
    );
    expect(report.sunday, DateTime(2026, 1, 4));
    expect(report.dayScores.whereType<int>(), hasLength(7));

    // Summer time ends on Sunday 2026-10-25.
    final change = DateTime(2026, 10, 19);
    final autumn = _report(
      steps: {
        for (var i = 0; i < 7; i++) dayKey(DateTime(2026, 10, 19 + i)): 10000,
      },
      monday: change,
      today: DateTime(2026, 11, 1),
    );
    expect(autumn.sunday, DateTime(2026, 10, 25));
    expect(autumn.dayScores.whereType<int>(), hasLength(7));
  });

  group('when the report is ready', () {
    final sunday = DateTime(2026, 10, 4);

    test('the latest week is this one from Sunday evening', () {
      expect(latestReportWeek(DateTime(2026, 10, 4, 18, 59)), _day(-7));
      expect(latestReportWeek(DateTime(2026, 10, 4, 19)), _monday);
      expect(latestReportWeek(DateTime(2026, 10, 5, 8)), _monday);
      expect(latestReportWeek(DateTime(2026, 10, 10, 23)), _monday);
    });

    test('the tile stands from Sunday evening until Monday ends', () {
      expect(weekTileShown(DateTime(2026, 10, 4, 18, 59)), isFalse);
      expect(weekTileShown(DateTime(2026, 10, 4, 19)), isTrue);
      expect(weekTileShown(DateTime(2026, 10, 5, 23, 59)), isTrue);
      expect(weekTileShown(DateTime(2026, 10, 6)), isFalse);

      expect(
        weekTileEdge(DateTime(2026, 10, 1, 12)),
        sunday.add(const Duration(hours: 19)),
      );
      expect(
        weekTileEdge(DateTime(2026, 10, 4, 10)),
        DateTime(2026, 10, 4, 19),
      );
      expect(weekTileEdge(DateTime(2026, 10, 4, 20)), DateTime(2026, 10, 6));
      expect(weekTileEdge(DateTime(2026, 10, 5, 9)), DateTime(2026, 10, 6));
      expect(
        weekTileEdge(DateTime(2026, 10, 6, 0, 1)),
        DateTime(2026, 10, 11, 19),
      );
    });
  });

  group('the alarm for Sunday evening', () {
    final now = DateTime(2026, 10, 4, 12);
    double? steps(Metric metric, DateTime day) {
      if (metric != Metric.steps) return null;
      final key = dayKey(day);
      if (key >= dayKey(_monday) && key <= dayKey(now)) return 8000;
      if (key >= dayKey(_day(-7)) && key < dayKey(_monday)) return 6000;
      return null;
    }

    test('it tells the score and how it stands against the week before', () {
      final alarm = weekAlarmFor(
        settings: const {'language': 'de'},
        valueOf: steps,
        nights: const [],
        now: now,
        language: 'en',
      )!;
      expect(alarm.title, 'Dein Wochenbericht');
      expect(alarm.body, 'Wochenwert 80, 20 mehr als in der Woche davor.');
      expect(alarm.plain, 'Der Rückblick auf deine Woche ist da.');
      expect(alarm.day, dayKey(now));
    });

    test('it follows the goals, the system language and the switch', () {
      final alarm = weekAlarmFor(
        settings: const {'stepGoal': 16000},
        valueOf: steps,
        nights: const [],
        now: now,
        language: 'en',
      )!;
      expect(alarm.body, 'Week score 50, 12 more than the week before.');
      expect(
        weekAlarmFor(
          settings: const {'weekReport': false},
          valueOf: steps,
          nights: const [],
          now: now,
          language: 'de',
        ),
        isNull,
      );
      expect(
        weekAlarmFor(
          settings: null,
          valueOf: (_, _) => null,
          nights: const [],
          now: now,
          language: 'pl',
        )!.body,
        'Podsumowanie Twojego tygodnia jest gotowe.',
      );
    });

    test('it is left for the platform and taken away again', () async {
      final store = MemoryJsonStore();
      Future<bool> leave(Object? settings) => leaveWeekAlarm(
        store,
        settings: settings,
        valueOf: steps,
        nights: const [],
        now: now,
        language: 'de',
      );
      expect(await leave(null), isTrue);
      expect(await store.read(StoreKeys.weekAlarm), {
        'title': 'Dein Wochenbericht',
        'body': 'Wochenwert 80, 20 mehr als in der Woche davor.',
        'plain': 'Der Rückblick auf deine Woche ist da.',
        'day': dayKey(now),
        'short': '80',
      });
      // Nothing new, nothing written.
      expect(await leave(null), isFalse);
      expect(await leave(const {'weekReport': false}), isTrue);
      expect(await store.read(StoreKeys.weekAlarm), isNull);
      expect(await leave(const {'weekReport': false}), isFalse);
    });
  });
}
