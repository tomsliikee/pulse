import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/body_age.dart';
import 'package:pulse/data/health_history.dart';
import 'package:pulse/data/health_snapshot.dart';
import 'package:pulse/data/metric_catalog.dart';
import 'package:pulse/data/models.dart';

final _today = DateTime(2026, 10, 6);
final _birthDate = DateTime(1992, 10, 6);

HealthSnapshot _snapshot({
  Map<Metric, List<double?>> series = const {},
  List<SleepNight?>? nights,
  List<Workout> workouts = const [],
  int dayCount = 30,
}) => HealthSnapshot(
  today: _today,
  loadedAt: _today,
  dayCount: dayCount,
  series: series,
  nights: nights ?? List.filled(dayCount, null),
  heart: List.filled(dayCount, const []),
  workouts: workouts,
  entries: const [],
);

/// [days] days with [value], the rest of the window without data.
List<double?> _days(double value, [int days = 30]) => [
  for (var i = 0; i < 30; i++) i < days ? value : null,
];

SleepNight _night(int bedtimeMinute) => SleepNight(
  date: _today,
  bedtimeMinute: bedtimeMinute,
  totalMinutes: 480,
  segments: const [],
);

AgeFactor _factor(BodyAge age, AgeFactorKind kind) =>
    age.factors.singleWhere((f) => f.kind == kind);

BodyAge _estimate(
  HealthSnapshot snapshot, {
  Sex? sex,
  double? weight,
  double? height,
  double? bodyFat,
  double? systolic,
  double? diastolic,
}) => estimateBodyAge(
  birthDate: _birthDate,
  sex: sex,
  snapshot: snapshot,
  weight: weight,
  height: height,
  bodyFat: bodyFat,
  systolic: systolic,
  diastolic: diastolic,
);

void main() {
  group('yearsOn', () {
    test('holds the end values beyond the ends', () {
      expect(yearsOn(stepsCurve, 500), 2);
      expect(yearsOn(stepsCurve, 3000), 2);
      expect(yearsOn(stepsCurve, 12000), -2);
      expect(yearsOn(stepsCurve, 30000), -2);
    });

    test('interpolates between two points', () {
      expect(yearsOn(stepsCurve, 7000), 0);
      expect(yearsOn(stepsCurve, 5000), 1);
      expect(yearsOn(stepsCurve, 9500), -1);
    });

    test('too little and too much sleep both add years', () {
      expect(yearsOn(sleepDurationCurve, 5), 2);
      expect(yearsOn(sleepDurationCurve, 8), -1);
      expect(yearsOn(sleepDurationCurve, 9), 0);
      expect(yearsOn(sleepDurationCurve, 9.5), 1);
    });
  });

  group('ageOn', () {
    test('is whole on the birthday and counts the days after it', () {
      expect(ageOn(DateTime(1992, 10, 6), _today), 34);
      expect(ageOn(DateTime(1992, 10, 7), _today), closeTo(33.997, 0.001));
      expect(ageOn(DateTime(1992, 4, 6), _today), closeTo(34.5, 0.01));
    });
  });

  group('estimateBodyAge', () {
    test('adds the years of every factor to the real age', () {
      final age = _estimate(
        _snapshot(
          series: {
            Metric.steps: _days(12000),
            Metric.intensityMinutes: _days(150 / 7),
            Metric.sleep: _days(8),
            Metric.restingHeartRate: _days(80),
          },
        ),
      );
      expect(_factor(age, AgeFactorKind.steps).years, -2);
      expect(_factor(age, AgeFactorKind.steps).position, 1);
      expect(_factor(age, AgeFactorKind.intensity).value, closeTo(150, 1e-9));
      expect(_factor(age, AgeFactorKind.intensity).years, closeTo(0, 1e-9));
      expect(_factor(age, AgeFactorKind.sleepDuration).years, -1);
      expect(_factor(age, AgeFactorKind.restingHeartRate).years, 2.5);
      expect(_factor(age, AgeFactorKind.restingHeartRate).position, 0);
      expect(age.chronological, 34);
      expect(age.age, closeTo(33.5, 1e-9));
      expect(age.difference, closeTo(-0.5, 1e-9));
    });

    test('a mean counts only the days with data', () {
      final age = _estimate(_snapshot(series: {Metric.steps: _days(7000, 10)}));
      final steps = _factor(age, AgeFactorKind.steps);
      expect(steps.value, 7000);
      expect(steps.days, 10);
      expect(steps.years, 0);
    });

    test('a factor with fewer than seven days leaves the age alone', () {
      final age = _estimate(
        _snapshot(
          series: {
            Metric.steps: _days(2000, 6),
            Metric.sleep: _days(8),
            Metric.restingHeartRate: _days(62),
            Metric.intensityMinutes: _days(150 / 7),
          },
        ),
      );
      final steps = _factor(age, AgeFactorKind.steps);
      expect(steps.value, 2000);
      expect(steps.years, isNull);
      expect(age.age, closeTo(33, 1e-9));
    });

    test('fewer than three factors give no age', () {
      final age = _estimate(
        _snapshot(series: {Metric.steps: _days(9000), Metric.sleep: _days(8)}),
      );
      expect(age.age, isNull);
      expect(age.difference, isNull);
      expect(age.factors, hasLength(9));
    });

    test('a woman has a higher neutral resting heart rate', () {
      final snapshot = _snapshot(series: {Metric.restingHeartRate: _days(65)});
      expect(
        _factor(
          _estimate(snapshot, sex: Sex.female),
          AgeFactorKind.restingHeartRate,
        ).years,
        0,
      );
      expect(
        _factor(
          _estimate(snapshot, sex: Sex.male),
          AgeFactorKind.restingHeartRate,
        ).years,
        greaterThan(0),
      );
    });

    test('heart rate variability is judged against the age', () {
      // At 34 the expected value is 65 - 0.6 * 14 = 56.6 ms.
      final age = _estimate(
        _snapshot(series: {Metric.heartRateVariability: _days(56.6)}),
      );
      final hrv = _factor(age, AgeFactorKind.heartRateVariability);
      expect(hrv.second, closeTo(56.6, 1e-9));
      expect(hrv.years, closeTo(0, 1e-9));
      expect(expectedHeartRateVariability(120), 20);
    });

    test('body fat is used with a sex, else the body mass index', () {
      final snapshot = _snapshot();
      final byFat = _estimate(
        snapshot,
        sex: Sex.male,
        weight: 81,
        height: 180,
        bodyFat: 20,
      );
      expect(_factor(byFat, AgeFactorKind.bodyFat).years, 0);
      expect(
        byFat.factors.where((f) => f.kind == AgeFactorKind.bodyMassIndex),
        isEmpty,
      );

      final byIndex = _estimate(snapshot, weight: 81, height: 180, bodyFat: 20);
      final index = _factor(byIndex, AgeFactorKind.bodyMassIndex);
      expect(index.value, closeTo(25, 1e-9));
      expect(index.years, closeTo(0, 1e-9));

      final missing = _estimate(snapshot, weight: 81);
      expect(_factor(missing, AgeFactorKind.bodyMassIndex).value, isNull);
    });

    test('the worse blood pressure reading decides', () {
      final age = _estimate(_snapshot(), systolic: 118, diastolic: 90);
      final pressure = _factor(age, AgeFactorKind.bloodPressure);
      expect(pressure.years, 1.5);
      expect(pressure.second, 90);
      expect(
        _factor(
          _estimate(_snapshot(), systolic: 115, diastolic: 75),
          AgeFactorKind.bloodPressure,
        ).years,
        -1,
      );
    });

    test('regular bedtimes take years, also across midnight', () {
      final age = _estimate(
        _snapshot(
          nights: [
            for (var i = 0; i < 30; i++) _night(i.isEven ? 23 * 60 + 50 : 10),
          ],
        ),
      );
      final regularity = _factor(age, AgeFactorKind.sleepRegularity);
      expect(regularity.value, 10);
      expect(regularity.days, 30);
      expect(regularity.years, -1);
    });

    test('strength training counts only when workouts are recorded', () {
      expect(
        _factor(_estimate(_snapshot()), AgeFactorKind.strength).value,
        isNull,
      );

      Workout workout(WorkoutType type, int day) =>
          Workout(type: type, start: DateTime(2026, 9, day), minutes: 40);
      final runner = _estimate(
        _snapshot(workouts: [workout(WorkoutType.run, 10)]),
      );
      expect(_factor(runner, AgeFactorKind.strength).years, 0.5);

      final lifter = _estimate(
        _snapshot(
          workouts: [
            for (var day = 8; day < 30; day += 2)
              workout(WorkoutType.strength, day),
          ],
        ),
      );
      // Eleven sessions in thirty days are more than two a week.
      expect(_factor(lifter, AgeFactorKind.strength).years, -1);
    });
  });

  group('latestKnown', () {
    test('takes the snapshot first and the archive for older values', () {
      final history = HealthHistory()
        ..merge({
          Metric.height: {DateTime(2024, 3, 1): 181},
          Metric.weight: {DateTime(2024, 3, 1): 70},
        });
      final snapshot = _snapshot(
        series: {
          Metric.weight: [for (var i = 0; i < 30; i++) i == 20 ? 74.5 : null],
        },
      );
      expect(latestKnown(snapshot, history, Metric.weight), (
        value: 74.5,
        day: DateTime(2026, 9, 27),
      ));
      expect(latestKnown(snapshot, history, Metric.height), (
        value: 181.0,
        day: DateTime(2024, 3, 1),
      ));
      expect(latestKnown(snapshot, history, Metric.bodyFat), isNull);
      expect(latestKnown(snapshot, null, Metric.height), isNull);
    });
  });
}
