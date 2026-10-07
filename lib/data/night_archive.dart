import 'health_history.dart';
import 'health_snapshot.dart';
import 'json_store.dart';
import 'models.dart';

/// The nights of [snapshot] as the archive keeps them.
List<SleepNight> nightSummaries(HealthSnapshot snapshot) => [
  for (final night in snapshot.nights) ?night?.summary,
];

/// [stored] with [fresh] merged in, oldest first, or null when that changes
/// nothing. There is one night a day; a fresh one replaces the stored one.
List<SleepNight>? mergeNights(
  List<SleepNight> stored,
  Iterable<SleepNight> fresh,
) {
  final byDay = {for (final night in stored) dayKey(night.date): night};
  var changed = false;
  for (final night in fresh) {
    final key = dayKey(night.date);
    final old = byDay[key];
    if (old != null && _same(old, night)) continue;
    byDay[key] = night;
    changed = true;
  }
  if (!changed) return null;
  return byDay.values.toList()..sort((a, b) => a.date.compareTo(b.date));
}

bool _same(SleepNight a, SleepNight b) =>
    a.bedtimeMinute == b.bedtimeMinute &&
    a.totalMinutes == b.totalMinutes &&
    a.hasStages == b.hasStages &&
    SleepStage.values.every(
      (stage) => a.minutesIn(stage) == b.minutesIn(stage),
    );

/// Keeps every night the app has seen, one document per calendar year like
/// [HistoryArchive]: the store's window only reaches back a month, and a
/// night is compared with the ones before it. The curve of the stages is not
/// kept, only how long each stage lasted.
class NightArchive {
  const NightArchive(this._store);

  final JsonStore _store;

  static const int schemaVersion = 1;
  static const String _prefix = 'nights-';

  static String _name(int year) => '$_prefix$year';

  /// Every kept night, oldest first.
  Future<List<SleepNight>> load() async {
    final nights = <SleepNight>[];
    for (final name in await _store.names()) {
      if (!name.startsWith(_prefix)) continue;
      nights.addAll(_nightsOf(await _store.read(name)));
    }
    return nights..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Merges [fresh] into the stored years they belong to, without loading
  /// the others. Read again from the store each time, because the background
  /// task writes there too.
  Future<void> mergeIntoStore(Iterable<SleepNight> fresh) async {
    final byYear = <int, List<SleepNight>>{};
    for (final night in fresh) {
      byYear.putIfAbsent(night.date.year, () => []).add(night.summary);
    }
    for (final MapEntry(key: year, value: nights) in byYear.entries) {
      final stored = _nightsOf(await _store.read(_name(year)));
      final merged = mergeNights(stored, nights);
      if (merged == null) continue;
      await _store.write(_name(year), {
        'version': schemaVersion,
        'nights': [for (final night in merged) night.toJson()],
      });
    }
  }

  /// Anything that is not a valid night is skipped.
  static List<SleepNight> _nightsOf(Object? json) {
    if (json case {
      'version': schemaVersion,
      'nights': final List<Object?> nights,
    }) {
      return [for (final night in nights) ?SleepNight.fromJson(night)];
    }
    return [];
  }
}
