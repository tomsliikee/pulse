import 'dart:collection';

import 'health_snapshot.dart';
import 'json_store.dart';
import 'metric_catalog.dart';

/// Values of one day per metric, keyed by the calendar day.
typedef DailyValues = Map<Metric, Map<DateTime, double>>;

const int _millisPerDay = 86400000;

/// Numbers calendar days so they can be ordered and subtracted. Computed in
/// UTC from the date's components, so daylight saving cannot shift a day.
int dayKey(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
    _millisPerDay;

DateTime dateOfKey(int key) {
  final utc = DateTime.fromMillisecondsSinceEpoch(
    key * _millisPerDay,
    isUtc: true,
  );
  return DateTime(utc.year, utc.month, utc.day);
}

/// The day values of [snapshot] in the form the history takes.
DailyValues dailyValuesOf(HealthSnapshot snapshot) => {
  for (final MapEntry(key: metric, value: values) in snapshot.series.entries)
    metric: {
      for (var i = 0; i < values.length; i++) snapshot.dateAt(i): ?values[i],
    },
};

/// One value per day and metric, for as long as the app has been collecting.
/// Kept in memory; [HistoryArchive] loads and saves it.
class HealthHistory {
  final Map<Metric, SplayTreeMap<int, double>> _values = {};

  bool get isEmpty => _values.values.every((days) => days.isEmpty);

  double? value(Metric metric, DateTime day) => _values[metric]?[dayKey(day)];

  /// The values from [from] to [to], both inclusive, oldest first.
  List<double> between(Metric metric, DateTime from, DateTime to) {
    final days = _values[metric];
    if (days == null) return const [];
    final first = dayKey(from);
    final last = dayKey(to);
    final result = <double>[];
    for (
      var key = days.firstKeyAfter(first - 1);
      key != null && key <= last;
      key = days.firstKeyAfter(key)
    ) {
      result.add(days[key]!);
    }
    return result;
  }

  /// The oldest day that has a value for [metric].
  DateTime? firstDay(Metric metric) {
    final days = _values[metric];
    return days == null || days.isEmpty ? null : dateOfKey(days.firstKey()!);
  }

  /// The oldest day that has a value for any metric.
  DateTime? get firstDayOfAll {
    int? first;
    for (final days in _values.values) {
      final key = days.firstKey();
      if (key != null && (first == null || key < first)) first = key;
    }
    return first == null ? null : dateOfKey(first);
  }

  /// Takes [values] over. A new value replaces an older one for the same
  /// day; a day that is missing from [values] keeps what is stored, so a gap
  /// in a later reading never erases history. Returns the years that changed.
  Set<int> merge(DailyValues values) {
    final changed = <int>{};
    for (final MapEntry(key: metric, value: days) in values.entries) {
      for (final MapEntry(key: day, :value) in days.entries) {
        if (!metric.accepts(value)) continue;
        final stored = _values.putIfAbsent(metric, SplayTreeMap.new);
        final key = dayKey(day);
        if (stored[key] == value) continue;
        stored[key] = value;
        changed.add(day.year);
      }
    }
    return changed;
  }

  Map<String, Object?> yearToJson(int year) {
    final first = dayKey(DateTime(year));
    final last = dayKey(DateTime(year, 12, 31));
    final metrics = <String, Object?>{};
    for (final MapEntry(key: metric, value: days) in _values.entries) {
      final inYear = <String, double>{};
      for (
        var key = days.firstKeyAfter(first - 1);
        key != null && key <= last;
        key = days.firstKeyAfter(key)
      ) {
        // Stored as the day's offset within the year.
        inYear['${key - first}'] = days[key]!;
      }
      if (inYear.isNotEmpty) metrics[metric.name] = inYear;
    }
    return {
      'version': HistoryArchive.schemaVersion,
      'year': year,
      'metrics': metrics,
    };
  }

  /// Adds a stored year. Anything that is not a valid year document, and any
  /// single value that is out of range, is skipped.
  void addYearJson(int year, Object? json) {
    if (json
        case {
          'version': HistoryArchive.schemaVersion,
          'year': final int storedYear,
          'metrics': final Map<String, Object?> metrics,
        }
        when storedYear == year) {
      final first = dayKey(DateTime(year));
      final length = dayKey(DateTime(year + 1)) - first;
      for (final MapEntry(key: name, value: days) in metrics.entries) {
        final metric = Metric.byName(name);
        if (metric == null || days is! Map<String, Object?>) continue;
        for (final MapEntry(key: offsetText, :value) in days.entries) {
          final offset = int.tryParse(offsetText);
          if (offset == null || offset < 0 || offset >= length) continue;
          if (value is! num || !metric.accepts(value.toDouble())) continue;
          _values.putIfAbsent(metric, SplayTreeMap.new)[first + offset] = value
              .toDouble();
        }
      }
    }
  }
}

/// Stores the history as one document per calendar year, so a refresh only
/// rewrites the current year and damage is limited to one year.
class HistoryArchive {
  const HistoryArchive(this._store);

  final JsonStore _store;

  static const int schemaVersion = 1;

  /// Years kept, counting the current one.
  static const int retentionYears = 10;

  static const String _prefix = 'history-';

  static String _name(int year) => '$_prefix$year';

  /// Loads every kept year and deletes years older than [retentionYears].
  /// This is the only place the app deletes its own data.
  Future<HealthHistory> load(DateTime now) async {
    final history = HealthHistory();
    final oldest = now.year - retentionYears + 1;
    for (final name in await _store.names()) {
      if (!name.startsWith(_prefix)) continue;
      final year = int.tryParse(name.substring(_prefix.length));
      if (year == null) continue;
      if (year < oldest) {
        await _store.delete(name);
      } else {
        history.addYearJson(year, await _store.read(name));
      }
    }
    return history;
  }

  Future<void> save(HealthHistory history, Set<int> years) async {
    for (final year in years) {
      await _store.write(_name(year), history.yearToJson(year));
    }
  }

  /// Merges [values] into the stored years without loading the others. Used
  /// by the background task, which holds no history in memory.
  Future<void> mergeIntoStore(DailyValues values) async {
    final years = {
      for (final days in values.values)
        for (final day in days.keys) day.year,
    };
    final history = HealthHistory();
    for (final year in years) {
      history.addYearJson(year, await _store.read(_name(year)));
    }
    await save(history, history.merge(values));
  }
}
