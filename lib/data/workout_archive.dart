import 'health_snapshot.dart';
import 'json_store.dart';
import 'models.dart';

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

/// Keeps every workout the app has seen, because the store's window only
/// reaches back a month and a workout is compared with the ones before it.
class WorkoutArchive {
  const WorkoutArchive(this._store);

  final JsonStore _store;

  static const int schemaVersion = 1;

  /// Oldest first. Anything that is not a valid workout is skipped.
  Future<List<Workout>> load() async {
    final json = await _store.read(StoreKeys.workouts);
    if (json case {
      'version': schemaVersion,
      'workouts': final List<Object?> workouts,
    }) {
      return [for (final workout in workouts) ?Workout.fromJson(workout)]
        ..sort((a, b) => a.start.compareTo(b.start));
    }
    return [];
  }

  /// Merges [fresh] into what is stored and returns all of it. Read again
  /// from the store each time, because the background task writes there too.
  Future<List<Workout>> mergeIntoStore(Iterable<Workout> fresh) async {
    final stored = await load();
    final merged = mergeWorkouts(stored, fresh);
    if (merged == null) return stored;
    await _store.write(StoreKeys.workouts, {
      'version': schemaVersion,
      'workouts': [for (final workout in merged) workout.toJson()],
    });
    return merged;
  }
}
