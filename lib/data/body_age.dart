import 'health_history.dart';
import 'health_snapshot.dart';
import 'metric_catalog.dart';
import 'models.dart';
import 'sleep_insights.dart';

/// The body age is the app's own estimate: the real age plus or minus some
/// years for each habit and measurement of the snapshot's days. The anchor
/// values follow common guidance (150 active minutes a week, seven to nine
/// hours of sleep, the blood pressure grades); the years given for them are
/// constants of this app and are not validated against anything. It is
/// labelled as an estimate wherever it is shown.
enum AgeFactorKind {
  steps,
  intensity,
  sleepDuration,
  sleepRegularity,
  restingHeartRate,
  heartRateVariability,
  bodyFat,
  bodyMassIndex,
  bloodPressure,
  strength,
}

/// A daily measurement counts once it has this many days in the window; a
/// few days say little about a habit.
const int minFactorDays = 7;

/// Below this many factors the sum says too little to be called an age.
const int minAgeFactors = 3;

/// Points of (value, years), ordered by value. Between two points the years
/// are interpolated; beyond the ends they stay at the end's years.
typedef AgeCurve = List<(double, double)>;

const AgeCurve stepsCurve = [(3000, 2), (7000, 0), (12000, -2)];
const AgeCurve intensityCurve = [(0, 2), (150, 0), (300, -2)];
const AgeCurve sleepDurationCurve = [
  (5.5, 2),
  (7, 0),
  (7.5, -1),
  (8.5, -1),
  (9, 0),
  (10, 2),
];
const AgeCurve sleepRegularityCurve = [(30, -1), (60, 0), (120, 1.5)];
const AgeCurve _restingHeartRateCurve = [(50, -2), (62, 0), (80, 2.5)];

/// A woman's resting heart rate is a few beats higher at the same fitness.
const double _femaleHeartRateShift = 3;
const AgeCurve heartRateVariabilityCurve = [(0.7, 1.5), (1, 0), (1.4, -1.5)];
const AgeCurve bodyMassIndexCurve = [
  (18.5, 0.5),
  (22, -0.5),
  (25, 0),
  (30, 1.5),
  (35, 2.5),
];
const AgeCurve _maleBodyFatCurve = [(12, -0.5), (20, 0), (25, 1.5), (30, 2.5)];
const AgeCurve _femaleBodyFatCurve = [
  (20, -0.5),
  (28, 0),
  (33, 1.5),
  (38, 2.5),
];
const AgeCurve systolicCurve = [(120, -1), (130, 0), (140, 1.5), (160, 2.5)];
const AgeCurve diastolicCurve = [(80, -1), (85, 0), (90, 1.5), (100, 2.5)];
const AgeCurve strengthCurve = [(0, 0.5), (1, 0), (2, -1)];

AgeCurve restingHeartRateCurve(Sex? sex) => sex == Sex.female
    ? [
        for (final (bpm, years) in _restingHeartRateCurve)
          (bpm + _femaleHeartRateShift, years),
      ]
    : _restingHeartRateCurve;

AgeCurve bodyFatCurve(Sex sex) =>
    sex == Sex.female ? _femaleBodyFatCurve : _maleBodyFatCurve;

/// The heart rate variability (RMSSD, ms) taken as usual at [age]; it falls
/// with the years, so the measured value is compared with this.
double expectedHeartRateVariability(double age) {
  final expected = 65 - 0.6 * (age - 20);
  return expected < 20 ? 20 : expected;
}

/// The value on [curve] at which a factor neither adds nor takes years.
double neutralOf(AgeCurve curve) =>
    curve.firstWhere((point) => point.$2 == 0).$1;

double yearsOn(AgeCurve curve, double value) {
  if (value <= curve.first.$1) return curve.first.$2;
  for (var i = 1; i < curve.length; i++) {
    final (x1, y1) = curve[i];
    if (value <= x1) {
      final (x0, y0) = curve[i - 1];
      return y0 + (y1 - y0) * (value - x0) / (x1 - x0);
    }
  }
  return curve.last.$2;
}

/// One habit or measurement and what it does to the age.
class AgeFactor {
  const AgeFactor({
    required this.kind,
    this.value,
    this.second,
    this.days = 0,
    this.years,
    this.position,
  });

  final AgeFactorKind kind;

  /// The mean or the latest measurement, in the unit the factor is judged
  /// in: steps a day, minutes a week, hours, minutes of spread, beats,
  /// milliseconds, percent, kg/m², mmHg, sessions a week.
  final double? value;

  /// The diastolic value of a blood pressure, the expected value of a heart
  /// rate variability.
  final double? second;

  /// Days, nights or sessions the value rests on.
  final int days;

  /// Null while there is too little data; then the factor leaves the age
  /// alone.
  final double? years;

  /// Where [years] lies between the worst (0) and the best (1) the factor
  /// can give.
  final double? position;
}

class BodyAge {
  const BodyAge({
    required this.chronological,
    required this.age,
    required this.factors,
  });

  /// The real age in years.
  final double chronological;

  /// Null while fewer than [minAgeFactors] factors have data.
  final double? age;
  final List<AgeFactor> factors;

  /// Negative when the body age is below the real one.
  double? get difference => age == null ? null : age! - chronological;
}

/// The latest measurement of [metric]: from the snapshot's days, else from
/// the archive. A height is often entered once and never again.
({double value, DateTime day})? latestKnown(
  HealthSnapshot snapshot,
  HealthHistory? history,
  Metric metric,
) {
  final index = snapshot.latestIndex(metric);
  if (index != null) {
    return (value: snapshot.value(metric, index)!, day: snapshot.dateAt(index));
  }
  final first = history?.firstDay(metric);
  if (history == null || first == null) return null;
  for (
    var day = snapshot.dateAt(0);
    !day.isBefore(first);
    day = DateTime(day.year, day.month, day.day - 1)
  ) {
    final value = history.value(metric, day);
    if (value != null) return (value: value, day: day);
  }
  return null;
}

/// The maximum heart rate taken for someone born on [birthDate]: 220 less
/// the age, the common rule of thumb.
int maxHeartRateOn(DateTime birthDate, DateTime today) =>
    (220 - ageOn(birthDate, today)).round();

double ageOn(DateTime birthDate, DateTime today) {
  var years = today.year - birthDate.year;
  var last = DateTime(today.year, birthDate.month, birthDate.day);
  if (last.isAfter(today)) {
    years--;
    last = DateTime(today.year - 1, birthDate.month, birthDate.day);
  }
  final next = DateTime(last.year + 1, birthDate.month, birthDate.day);
  final sinceBirthday = DateTime.utc(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime.utc(last.year, last.month, last.day)).inDays;
  final yearLength = DateTime.utc(
    next.year,
    next.month,
    next.day,
  ).difference(DateTime.utc(last.year, last.month, last.day)).inDays;
  return years + sinceBirthday / yearLength;
}

BodyAge estimateBodyAge({
  required DateTime birthDate,
  required Sex? sex,
  required HealthSnapshot snapshot,
  double? weight,
  double? height,
  double? bodyFat,
  double? systolic,
  double? diastolic,
}) {
  final chronological = ageOn(birthDate, snapshot.today);

  AgeFactor daily(
    AgeFactorKind kind,
    Metric metric,
    AgeCurve curve, {
    double scale = 1,
    double? expected,
  }) {
    final values = snapshot.valuesOf(metric).whereType<double>().toList();
    if (values.isEmpty) return AgeFactor(kind: kind);
    final mean = values.reduce((a, b) => a + b) / values.length * scale;
    return _factor(
      kind,
      curve,
      value: mean,
      judged: expected == null ? mean : mean / expected,
      second: expected,
      days: values.length,
      enough: values.length >= minFactorDays,
    );
  }

  final regularity = sleepRegularity(snapshot.nights);
  final strengthSessions = snapshot.workouts
      .where((w) => w.type == WorkoutType.strength)
      .length;

  final factors = [
    daily(AgeFactorKind.steps, Metric.steps, stepsCurve),
    daily(
      AgeFactorKind.intensity,
      Metric.intensityMinutes,
      intensityCurve,
      scale: 7,
    ),
    daily(AgeFactorKind.sleepDuration, Metric.sleep, sleepDurationCurve),
    regularity == null
        ? const AgeFactor(kind: AgeFactorKind.sleepRegularity)
        : _factor(
            AgeFactorKind.sleepRegularity,
            sleepRegularityCurve,
            value: regularity.bedtimeSpread.toDouble(),
            days: regularity.nights,
            enough: regularity.nights >= minFactorDays,
          ),
    daily(
      AgeFactorKind.restingHeartRate,
      Metric.restingHeartRate,
      restingHeartRateCurve(sex),
    ),
    daily(
      AgeFactorKind.heartRateVariability,
      Metric.heartRateVariability,
      heartRateVariabilityCurve,
      expected: expectedHeartRateVariability(chronological),
    ),
    if (bodyFat != null && sex != null)
      _factor(AgeFactorKind.bodyFat, bodyFatCurve(sex), value: bodyFat, days: 1)
    else if (weight != null && height != null && height > 0)
      _factor(
        AgeFactorKind.bodyMassIndex,
        bodyMassIndexCurve,
        value: weight / ((height / 100) * (height / 100)),
        days: 1,
      )
    else
      const AgeFactor(kind: AgeFactorKind.bodyMassIndex),
    if (systolic != null && diastolic != null)
      _bloodPressure(systolic, diastolic)
    else
      const AgeFactor(kind: AgeFactorKind.bloodPressure),
    // Without any workout in the store nobody can tell "does not train"
    // from "does not record it".
    if (snapshot.workouts.isEmpty)
      const AgeFactor(kind: AgeFactorKind.strength)
    else
      _factor(
        AgeFactorKind.strength,
        strengthCurve,
        value: strengthSessions / snapshot.dayCount * 7,
        days: strengthSessions,
      ),
  ];

  final counted = [for (final f in factors) ?f.years];
  return BodyAge(
    chronological: chronological,
    age: counted.length < minAgeFactors
        ? null
        : chronological + counted.reduce((a, b) => a + b),
    factors: factors,
  );
}

AgeFactor _factor(
  AgeFactorKind kind,
  AgeCurve curve, {
  required double value,
  double? judged,
  double? second,
  required int days,
  bool enough = true,
}) {
  if (!enough) {
    return AgeFactor(kind: kind, value: value, second: second, days: days);
  }
  final years = yearsOn(curve, judged ?? value);
  return AgeFactor(
    kind: kind,
    value: value,
    second: second,
    days: days,
    years: years,
    position: _position(curve, years),
  );
}

/// The higher of the two readings decides, as in the blood pressure grades.
AgeFactor _bloodPressure(double systolic, double diastolic) {
  final bySystolic = yearsOn(systolicCurve, systolic);
  final byDiastolic = yearsOn(diastolicCurve, diastolic);
  final years = bySystolic > byDiastolic ? bySystolic : byDiastolic;
  return AgeFactor(
    kind: AgeFactorKind.bloodPressure,
    value: systolic,
    second: diastolic,
    days: 1,
    years: years,
    position: _position(systolicCurve, years),
  );
}

double _position(AgeCurve curve, double years) {
  var best = curve.first.$2;
  var worst = curve.first.$2;
  for (final (_, y) in curve) {
    if (y < best) best = y;
    if (y > worst) worst = y;
  }
  return ((worst - years) / (worst - best)).clamp(0.0, 1.0);
}
