/// How the steps of a day are counted where more than one source wrote
/// them, such as a watch and the phone that carries its app.
enum StepCounting {
  /// The health store's own total: the source it ranks first, and every
  /// other in the minutes that one left out.
  store,

  /// The day of every source that counted, added up and divided by how
  /// many they are.
  dayMean,

  /// Hour by hour the mean of the sources that counted in it, so an hour
  /// only one of them saw counts in full.
  hourMean,

  /// The watch or the app alone; the phone on a day they wrote nothing.
  wearable;

  /// The way saved as [name]; the store's where there is none.
  static StepCounting named(Object? name) =>
      values.firstWhere((way) => way.name == name, orElse: () => store);
}

/// The way of counting in the saved settings [json].
StepCounting savedStepCounting(Object? json) => StepCounting.named(
  json is Map<String, Object?> ? json['stepCounting'] : null,
);

/// One record of steps as a source wrote it.
class StepRecord {
  const StepRecord(this.source, this.from, this.to, this.count);

  /// The package that wrote it.
  final String source;
  final DateTime from;
  final DateTime to;
  final double count;
}

/// Whether [source] is the phone counting by itself, not an app or a watch.
bool isPhoneCounter(String source) => source.contains('healthconnect');

/// The steps of [records] by the hour they were taken in, counted the
/// [counting] way. A record across the turn of an hour is shared out by
/// time. Not for [StepCounting.store]: that total is the store's to give.
Map<DateTime, double> stepsByHour(
  Iterable<StepRecord> records,
  StepCounting counting,
) {
  if (counting == StepCounting.store) {
    throw ArgumentError.value(counting, 'counting', 'is the store\'s own');
  }
  // Day, then source, then hour.
  final days = <DateTime, Map<String, Map<DateTime, double>>>{};
  for (final record in records) {
    if (record.count <= 0) continue;
    for (final (hour, share) in _hoursOf(record)) {
      final day = DateTime(hour.year, hour.month, hour.day);
      final hours = days
          .putIfAbsent(day, () => {})
          .putIfAbsent(record.source, () => {});
      hours[hour] = (hours[hour] ?? 0) + record.count * share;
    }
  }

  final result = <DateTime, double>{};
  for (final sources in days.values) {
    switch (counting) {
      case StepCounting.dayMean:
        for (final hours in sources.values) {
          for (final MapEntry(key: hour, value: steps) in hours.entries) {
            result[hour] = (result[hour] ?? 0) + steps / sources.length;
          }
        }
      case StepCounting.hourMean:
        final counted = <DateTime, int>{};
        for (final hours in sources.values) {
          for (final MapEntry(key: hour, value: steps) in hours.entries) {
            result[hour] = (result[hour] ?? 0) + steps;
            counted[hour] = (counted[hour] ?? 0) + 1;
          }
        }
        for (final MapEntry(key: hour, value: count) in counted.entries) {
          result[hour] = result[hour]! / count;
        }
      case StepCounting.wearable:
        result.addAll(sources[_leading(sources)]!);
      case StepCounting.store:
        break;
    }
  }
  return result;
}

/// The steps taken from [start] to [end], counted the [counting] way. Of a
/// record that reaches beyond, the part by time inside counts.
double stepsDuring(
  Iterable<StepRecord> records,
  DateTime start,
  DateTime end,
  StepCounting counting,
) {
  final inside = <StepRecord>[];
  for (final record in records) {
    final from = record.from.isBefore(start) ? start : record.from;
    final to = record.to.isAfter(end) ? end : record.to;
    final whole = record.to.difference(record.from).inMicroseconds;
    if (whole <= 0) {
      if (record.from.isBefore(start) || record.from.isAfter(end)) continue;
      inside.add(record);
      continue;
    }
    final part = to.difference(from).inMicroseconds;
    if (part <= 0) continue;
    inside.add(
      StepRecord(record.source, from, to, record.count * part / whole),
    );
  }
  return stepsByHour(
    inside,
    counting,
  ).values.fold(0, (sum, steps) => sum + steps);
}

/// The source a day is taken from when only one counts: the watch or app
/// with the most steps, and the phone where there is none.
String _leading(Map<String, Map<DateTime, double>> sources) {
  double total(String source) =>
      sources[source]!.values.fold(0, (sum, steps) => sum + steps);
  final worn = [
    for (final source in sources.keys)
      if (!isPhoneCounter(source)) source,
  ];
  final among = worn.isEmpty ? sources.keys.toList() : worn;
  return among.reduce((a, b) => total(b) > total(a) ? b : a);
}

/// The hours [record] lies in, each with its share of the record's time.
Iterable<(DateTime, double)> _hoursOf(StepRecord record) sync* {
  final from = record.from;
  final whole = record.to.difference(from).inMicroseconds;
  var hour = DateTime(from.year, from.month, from.day, from.hour);
  if (whole <= 0) {
    yield (hour, 1);
    return;
  }
  var at = from;
  while (at.isBefore(record.to)) {
    final next = DateTime(hour.year, hour.month, hour.day, hour.hour + 1);
    final until = next.isBefore(record.to) ? next : record.to;
    yield (hour, until.difference(at).inMicroseconds / whole);
    at = until;
    hour = next;
  }
}
