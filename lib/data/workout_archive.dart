import 'health_history.dart';
import 'health_snapshot.dart';
import 'json_store.dart';
import 'metric_catalog.dart';
import 'models.dart';
import 'snapshot_builder.dart';

/// The workouts of [snapshot], each with the heart rate it was done at as
/// far as the snapshot still has the curve of that day.
List<Workout> workoutsWithHeart(HealthSnapshot snapshot) => [
  for (final workout in snapshot.workouts) _withHeart(snapshot, workout),
];

Workout _withHeart(HealthSnapshot snapshot, Workout workout) {
  final index = snapshot.indexOf(workout.start);
  if (index == null) return workout;
  final from = workout.start.hour * 60 + workout.start.minute;
  // A workout that runs past midnight is only looked at up to it.
  final to = from + workout.minutes;
  final beats = [
    for (final sample in snapshot.heart[index])
      if (sample.minuteOfDay >= from && sample.minuteOfDay <= to) sample.bpm,
  ];
  if (beats.isEmpty) return workout;
  return workout.withHeart(
    avgBpm: (beats.reduce((a, b) => a + b) / beats.length).round(),
    maxBpm: beats.reduce((a, b) => a > b ? a : b),
  );
}

/// [stored] with [fresh] merged in, oldest first, or null when that changes
/// nothing. A fresh workout replaces the stored one, but a heart rate once
/// worked out is kept: the curve it came from is gone after a few days.
List<Workout>? mergeWorkouts(List<Workout> stored, Iterable<Workout> fresh) {
  final byKey = {for (final workout in stored) workout.key: workout};
  var changed = false;
  for (final workout in fresh) {
    final old = byKey[workout.key];
    final merged = old == null || workout.avgBpm != null
        ? workout
        : workout.withHeart(avgBpm: old.avgBpm, maxBpm: old.maxBpm);
    if (old != null && _same(old, merged)) continue;
    byKey[workout.key] = merged;
    changed = true;
  }
  if (!changed) return null;
  return byKey.values.toList()..sort((a, b) => a.start.compareTo(b.start));
}

bool _same(Workout a, Workout b) =>
    a.minutes == b.minutes &&
    a.kcal == b.kcal &&
    a.distanceKm == b.distanceKm &&
    a.steps == b.steps &&
    a.avgBpm == b.avgBpm &&
    a.maxBpm == b.maxBpm;

/// A workout the user took out of the app, with what the store counted
/// while it ran. The health store keeps it, so it is remembered here and
/// left out of every later reading, together with those amounts.
class RemovedWorkout {
  const RemovedWorkout({required this.workout, this.totals = const {}});

  final Workout workout;

  /// What the workout added to its days, keyed by the day.
  final DailyValues totals;

  Map<String, Object?> toJson() => {
    'workout': workout.toJson(),
    'totals': {
      for (final MapEntry(key: metric, value: days) in totals.entries)
        metric.name: {
          for (final MapEntry(key: day, :value) in days.entries)
            '${dayKey(day)}': value,
        },
    },
  };

  static RemovedWorkout? fromJson(Object? json) {
    if (json case {
      'workout': final Object? stored,
      'totals': final Map<String, Object?> totals,
    }) {
      final workout = Workout.fromJson(stored);
      if (workout == null) return null;
      final values = <Metric, Map<DateTime, double>>{};
      for (final MapEntry(key: name, value: days) in totals.entries) {
        final metric = Metric.byName(name);
        if (metric == null || days is! Map<String, Object?>) continue;
        for (final MapEntry(key: text, :value) in days.entries) {
          final day = int.tryParse(text);
          if (day == null || value is! num || value <= 0) continue;
          values.putIfAbsent(metric, () => {})[dateOfKey(day)] = value
              .toDouble();
        }
      }
      return RemovedWorkout(workout: workout, totals: values);
    }
    return null;
  }
}

/// What a workout says about itself, for when the store can no longer be
/// asked what it counted during it.
DailyValues ownTotals(Workout workout) {
  final day = DateTime(
    workout.start.year,
    workout.start.month,
    workout.start.day,
  );
  return {
    if (workout.steps case final steps?) Metric.steps: {day: steps.toDouble()},
    if (workout.distanceKm case final km? when km > 0)
      Metric.distance: {day: km},
    // The store adds up all energy of that time, not only the active part.
    if (workout.kcal case final kcal? when kcal > 0)
      Metric.totalEnergy: {day: kcal.toDouble()},
  };
}

double _less(double value, double amount) =>
    value > amount ? value - amount : 0;

/// [values] without what the workouts in [removed] added to their days.
DailyValues withoutRemovedTotals(
  DailyValues values,
  Iterable<RemovedWorkout> removed,
) {
  final result = <Metric, Map<DateTime, double>>{
    for (final MapEntry(key: metric, value: days) in values.entries)
      metric: {...days},
  };
  for (final entry in removed) {
    for (final MapEntry(key: metric, value: days) in entry.totals.entries) {
      final own = result[metric];
      if (own == null) continue;
      for (final MapEntry(key: day, value: amount) in days.entries) {
        final value = own[day];
        if (value != null) own[day] = _less(value, amount);
      }
    }
  }
  return result;
}

/// [snapshot] without the workouts in [removed] and without what they added
/// to their days. The hours of yesterday and today lose it in proportion to
/// the time the workout took of each.
HealthSnapshot withoutWorkouts(
  HealthSnapshot snapshot,
  Iterable<RemovedWorkout> removed,
) {
  final gone = {for (final entry in removed) entry.workout.key: entry};
  if (gone.isEmpty) return snapshot;
  final series = {
    for (final MapEntry(key: metric, value: values) in snapshot.series.entries)
      metric: [...values],
  };
  final hourly = {
    for (final MapEntry(key: metric, value: slots) in snapshot.hourly.entries)
      metric: [...slots],
  };
  const hours = HealthSnapshot.hoursPerDay;
  for (final RemovedWorkout(:workout, :totals) in gone.values) {
    for (final MapEntry(key: metric, value: days) in totals.entries) {
      for (final MapEntry(key: day, value: amount) in days.entries) {
        final index = snapshot.indexOf(day);
        if (index == null) continue;
        final values = series[metric];
        if (values?[index] case final value?) {
          values![index] = _less(value, amount);
        }
        final slots = hourly[metric];
        final daysBack = snapshot.dayCount - 1 - index;
        if (slots == null || daysBack > 1) continue;
        final minutes = minutesByHour([(workout.start, workout.end)]);
        final onDay = {
          for (final MapEntry(key: hour, value: part) in minutes.entries)
            if (dayKey(hour) == dayKey(day)) hour.hour: part,
        };
        final all = onDay.values.fold<double>(0, (sum, part) => sum + part);
        if (all <= 0) continue;
        for (final MapEntry(key: hour, value: part) in onDay.entries) {
          final slot = (1 - daysBack) * hours + hour;
          if (slots[slot] case final value?) {
            slots[slot] = _less(value, amount * part / all);
          }
        }
      }
    }
  }
  return HealthSnapshot(
    today: snapshot.today,
    loadedAt: snapshot.loadedAt,
    dayCount: snapshot.dayCount,
    series: series,
    nights: snapshot.nights,
    heart: snapshot.heart,
    workouts: [
      for (final workout in snapshot.workouts)
        if (!gone.containsKey(workout.key)) workout,
    ],
    entries: snapshot.entries,
    hourly: hourly,
  );
}

/// What the archive holds.
class WorkoutRecords {
  const WorkoutRecords({
    this.workouts = const [],
    this.removed = const [],
    this.missing = const [],
  });

  /// Oldest first.
  final List<Workout> workouts;

  /// Taken out by the user. Never taken in again.
  final List<RemovedWorkout> removed;

  /// No longer in the health store when their days were last read. Kept
  /// aside rather than dropped: a read that fails looks like one without
  /// workouts, and one that comes back gets its heart rate back.
  final List<Workout> missing;
}

/// [stored] with [fresh] merged in, or null when that changes nothing. With
/// a [window], [fresh] is everything the store has from its start to its
/// end, and what the archive has from that time beyond it is set aside: it
/// was deleted where it came from.
WorkoutRecords? reconcileWorkouts(
  WorkoutRecords stored,
  Iterable<Workout> fresh, {
  (DateTime, DateTime)? window,
}) {
  final removed = {for (final entry in stored.removed) entry.workout.key};
  final seen = {for (final workout in fresh) workout.key};
  final back = [
    for (final workout in stored.missing)
      if (seen.contains(workout.key)) workout,
  ];
  var missing = back.isEmpty
      ? stored.missing
      : [
          for (final workout in stored.missing)
            if (!seen.contains(workout.key)) workout,
        ];
  // Merged from the ones that are back, so they keep their heart rate.
  final known = back.isEmpty
      ? stored.workouts
      : ([...stored.workouts, ...back]
          ..sort((a, b) => a.start.compareTo(b.start)));
  var workouts =
      mergeWorkouts(known, [
        for (final workout in fresh)
          if (!removed.contains(workout.key)) workout,
      ]) ??
      known;
  if (window case (final from, final to)) {
    bool gone(Workout workout) =>
        !workout.start.isBefore(from) &&
        !workout.start.isAfter(to) &&
        !seen.contains(workout.key);
    if (workouts.any(gone)) {
      missing = [...missing, ...workouts.where(gone)];
      workouts = [
        for (final workout in workouts)
          if (!gone(workout)) workout,
      ];
    }
  }
  if (identical(workouts, stored.workouts) &&
      identical(missing, stored.missing)) {
    return null;
  }
  return WorkoutRecords(
    workouts: workouts,
    removed: stored.removed,
    missing: missing,
  );
}

/// Keeps every workout the app has seen, because the store's window only
/// reaches back a month and a workout is compared with the ones before it.
class WorkoutArchive {
  const WorkoutArchive(this._store);

  final JsonStore _store;

  static const int schemaVersion = 1;

  /// Oldest first. Anything that is not a valid workout is skipped.
  Future<List<Workout>> load() async => (await _read()).workouts;

  /// The workouts the user took out of the app.
  Future<List<RemovedWorkout>> loadRemoved() async => (await _read()).removed;

  Future<WorkoutRecords> _read() async {
    final json = await _store.read(StoreKeys.workouts);
    if (json case {
      'version': schemaVersion,
      'workouts': final List<Object?> workouts,
    }) {
      // Both added later; documents written before do not have them.
      List<Object?> list(String name) => switch (json[name]) {
        final List<Object?> list => list,
        _ => const [],
      };
      return WorkoutRecords(
        workouts: [for (final workout in workouts) ?Workout.fromJson(workout)]
          ..sort((a, b) => a.start.compareTo(b.start)),
        removed: [
          for (final entry in list('removed')) ?RemovedWorkout.fromJson(entry),
        ],
        missing: [
          for (final workout in list('missing')) ?Workout.fromJson(workout),
        ],
      );
    }
    return const WorkoutRecords();
  }

  Future<void> _write(WorkoutRecords records) =>
      _store.write(StoreKeys.workouts, {
        'version': schemaVersion,
        'workouts': [for (final workout in records.workouts) workout.toJson()],
        if (records.removed.isNotEmpty)
          'removed': [for (final entry in records.removed) entry.toJson()],
        if (records.missing.isNotEmpty)
          'missing': [for (final workout in records.missing) workout.toJson()],
      });

  /// Merges [fresh] into what is stored and returns all of it; see
  /// [reconcileWorkouts] for the [window]. Read again from the store each
  /// time, because the background task writes there too.
  Future<List<Workout>> mergeIntoStore(
    Iterable<Workout> fresh, {
    (DateTime, DateTime)? window,
  }) async {
    final stored = await _read();
    final merged = reconcileWorkouts(stored, fresh, window: window);
    if (merged == null) return stored.workouts;
    await _write(merged);
    return merged.workouts;
  }

  /// Takes [entry]'s workout out for good and returns the ones that stay.
  Future<List<Workout>> remove(RemovedWorkout entry) async {
    final stored = await _read();
    final key = entry.workout.key;
    final workouts = [
      for (final workout in stored.workouts)
        if (workout.key != key) workout,
    ];
    await _write(
      WorkoutRecords(
        workouts: workouts,
        removed: [
          for (final other in stored.removed)
            if (other.workout.key != key) other,
          entry,
        ],
        missing: stored.missing,
      ),
    );
    return workouts;
  }

  /// Undoes [remove] and returns all workouts.
  Future<List<Workout>> restore(RemovedWorkout entry) async {
    final stored = await _read();
    final key = entry.workout.key;
    final workouts =
        mergeWorkouts(stored.workouts, [entry.workout]) ?? stored.workouts;
    await _write(
      WorkoutRecords(
        workouts: workouts,
        removed: [
          for (final other in stored.removed)
            if (other.workout.key != key) other,
        ],
        missing: stored.missing,
      ),
    );
    return workouts;
  }

  /// Takes over the removals of another archive, for the workouts this one
  /// does not hold.
  Future<void> addRemoved(Iterable<RemovedWorkout> removed) async {
    final stored = await _read();
    final known = {
      for (final workout in stored.workouts) workout.key,
      for (final entry in stored.removed) entry.workout.key,
    };
    final added = [
      for (final entry in removed)
        if (known.add(entry.workout.key)) entry,
    ];
    if (added.isEmpty) return;
    await _write(
      WorkoutRecords(
        workouts: stored.workouts,
        removed: [...stored.removed, ...added],
        missing: stored.missing,
      ),
    );
  }
}
