import '../models.dart';
import 'training_models.dart';

/// The workout of the health store that [session] was recorded as. Any
/// other workout must overlap it by at least half of the shorter of the
/// two; a strength workout matches halfway: any overlap, or on the same day
/// with at most [strengthGap] between them, as when the training in the app
/// was started late or ended early. Strength workouts win over others;
/// among equals the closer one. Workouts in [taken] already belong to
/// another session.
Workout? linkFor(
  TrainingSession session,
  Iterable<Workout> workouts, {
  Set<String> taken = const {},
  DateTime? now,
  Duration strengthGap = const Duration(minutes: 45),
}) {
  final start = session.start;
  final end = session.end ?? now ?? DateTime.now();
  if (!end.isAfter(start)) return null;
  Workout? best;
  var bestScore = 0.0;
  for (final w in workouts) {
    if (taken.contains(w.key)) continue;
    final from = w.start.isAfter(start) ? w.start : start;
    final to = w.end.isBefore(end) ? w.end : end;
    final overlap = to.difference(from).inSeconds;
    final strength = w.type.family == WorkoutFamily.strength;
    final shorter = [
      end.difference(start).inSeconds,
      w.end.difference(w.start).inSeconds,
    ].reduce((a, b) => a < b ? a : b);
    double score;
    if (overlap > 0 && shorter > 0) {
      final share = overlap / shorter;
      if (!strength && share < 0.5) continue;
      score = 1 + share;
    } else {
      final sameDay =
          w.start.year == start.year &&
          w.start.month == start.month &&
          w.start.day == start.day;
      final gap = -overlap;
      if (!strength || !sameDay || gap > strengthGap.inSeconds) continue;
      score = 1 - gap / strengthGap.inSeconds;
    }
    if (strength) score += 2;
    if (score > bestScore) {
      best = w;
      bestScore = score;
    }
  }
  return best;
}

/// [sessions] with every finished session that has no link yet, and was
/// never unlinked by hand, linked to its workout where one is found.
/// Returns null when nothing changes.
List<TrainingSession>? linkAll(
  List<TrainingSession> sessions,
  List<Workout> workouts,
) {
  final taken = {for (final s in sessions) ?s.linkedWorkout};
  var changed = false;
  final out = <TrainingSession>[];
  for (final s in sessions) {
    final w = s.linkedWorkout != null || s.unlinked || !s.finished
        ? null
        : linkFor(s, workouts, taken: taken);
    if (w == null) {
      out.add(s);
      continue;
    }
    taken.add(w.key);
    changed = true;
    out.add(s.copyWith(linkedWorkout: () => w.key));
  }
  return changed ? out : null;
}

/// The workout [session] is linked to, among [workouts].
Workout? linkedWorkoutOf(TrainingSession session, Iterable<Workout> workouts) {
  final key = session.linkedWorkout;
  if (key == null) return null;
  for (final w in workouts) {
    if (w.key == key) return w;
  }
  return null;
}

/// The strength workouts of the health store from [since] on that no
/// session is linked to: trainings a watch saw that have no sets yet.
List<Workout> unmatchedStrength(
  List<TrainingSession> sessions,
  List<Workout> workouts, {
  required DateTime since,
}) {
  final taken = {for (final s in sessions) ?s.linkedWorkout};
  return [
    for (final w in workouts)
      if (!w.start.isBefore(since) &&
          w.type.family == WorkoutFamily.strength &&
          !taken.contains(w.key))
        w,
  ];
}
