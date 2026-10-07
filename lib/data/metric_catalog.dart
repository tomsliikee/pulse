/// The sections measurements are grouped into.
enum MetricGroup { activity, vitals, body, sleep, nutrition }

/// How the readings of one day become that day's value.
enum DayRule { sum, average, last }

/// Every measurement the app knows. This is the single list: what is loaded,
/// what is listed and how a value is formatted all derive from it.
///
/// [min] and [max] bound what is accepted from outside; a reading beyond them
/// is treated as a faulty record and dropped.
enum Metric {
  steps(MetricGroup.activity, '', DayRule.sum, max: 200000),
  distance(MetricGroup.activity, 'km', DayRule.sum, digits: 1, max: 500),
  floors(MetricGroup.activity, '', DayRule.sum, max: 2000),
  activeEnergy(MetricGroup.activity, 'kcal', DayRule.sum, max: 20000),
  totalEnergy(MetricGroup.activity, 'kcal', DayRule.sum, max: 30000),
  intensityMinutes(MetricGroup.activity, 'min', DayRule.sum, max: 1440),
  speed(MetricGroup.activity, 'km/h', DayRule.average, digits: 1, max: 150),

  heartRate(MetricGroup.vitals, 'bpm', DayRule.average, min: 20, max: 250),
  restingHeartRate(MetricGroup.vitals, 'bpm', DayRule.last, min: 20, max: 200),
  heartRateVariability(MetricGroup.vitals, 'ms', DayRule.average, max: 400),
  oxygenSaturation(MetricGroup.vitals, '%', DayRule.average, min: 50, max: 100),
  respiratoryRate(
    MetricGroup.vitals,
    '/min',
    DayRule.average,
    digits: 1,
    min: 2,
    max: 80,
  ),
  systolic(MetricGroup.vitals, 'mmHg', DayRule.last, min: 40, max: 300),
  diastolic(MetricGroup.vitals, 'mmHg', DayRule.last, min: 20, max: 200),
  bloodGlucose(MetricGroup.vitals, 'mg/dl', DayRule.average, min: 10, max: 900),
  bodyTemperature(
    MetricGroup.vitals,
    '°C',
    DayRule.last,
    digits: 1,
    min: 30,
    max: 45,
  ),
  skinTemperature(
    MetricGroup.vitals,
    '°C',
    DayRule.average,
    digits: 1,
    min: -10,
    max: 10,
  ),

  weight(MetricGroup.body, 'kg', DayRule.last, digits: 1, min: 2, max: 500),
  height(MetricGroup.body, 'cm', DayRule.last, min: 30, max: 280),
  bodyMassIndex(
    MetricGroup.body,
    '',
    DayRule.last,
    digits: 1,
    min: 5,
    max: 100,
  ),
  bodyFat(MetricGroup.body, '%', DayRule.last, digits: 1, min: 1, max: 80),
  leanMass(MetricGroup.body, 'kg', DayRule.last, digits: 1, min: 1, max: 300),
  bodyWater(MetricGroup.body, 'kg', DayRule.last, digits: 1, min: 1, max: 300),
  basalEnergy(MetricGroup.body, 'kcal', DayRule.last, min: 200, max: 10000),

  sleep(MetricGroup.sleep, 'h', DayRule.sum, digits: 1, max: 24),

  water(MetricGroup.nutrition, 'l', DayRule.sum, digits: 1, max: 30),
  energyIntake(MetricGroup.nutrition, 'kcal', DayRule.sum, max: 30000),
  carbs(MetricGroup.nutrition, 'g', DayRule.sum, max: 5000),
  protein(MetricGroup.nutrition, 'g', DayRule.sum, max: 5000),
  fat(MetricGroup.nutrition, 'g', DayRule.sum, max: 5000),
  fiber(MetricGroup.nutrition, 'g', DayRule.sum, max: 1000),
  sugar(MetricGroup.nutrition, 'g', DayRule.sum, max: 5000);

  const Metric(
    this.group,
    this.unit,
    this.rule, {
    this.digits = 0,
    this.min = 0,
    required this.max,
  });

  final MetricGroup group;

  /// Empty for what is counted or has none. The word after a count is the
  /// interface's to choose, because it depends on the language.
  final String unit;
  final DayRule rule;
  final int digits;
  final double min;
  final double max;

  bool accepts(double value) => value.isFinite && value >= min && value <= max;

  /// Combines one day's readings, oldest first, into the day's value.
  double? combine(List<double> readings) {
    if (readings.isEmpty) return null;
    return switch (rule) {
      DayRule.sum => readings.fold<double>(0, (sum, v) => sum + v),
      DayRule.average =>
        readings.fold<double>(0, (sum, v) => sum + v) / readings.length,
      DayRule.last => readings.last,
    };
  }

  static Metric? byName(String name) {
    for (final metric in values) {
      if (metric.name == name) return metric;
    }
    return null;
  }
}
