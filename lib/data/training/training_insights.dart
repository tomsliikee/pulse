import '../models.dart';
import 'exercise_library.dart';
import 'training_models.dart';

/// The one-rep maximum a set suggests, by Epley: kilograms times one plus a
/// thirtieth of the reps. Only for sets of 1 to 10 reps; beyond that the
/// estimate drifts too far.
double? epley(double? kg, int? reps) {
  if (kg == null || reps == null || kg <= 0 || reps < 1 || reps > 10) {
    return null;
  }
  if (reps == 1) return kg;
  return kg * (1 + reps / 30);
}

/// The best of an exercise: estimated maximum, heaviest weight, most volume
/// in one session.
class ExerciseBest {
  const ExerciseBest({this.oneRepMax, this.heaviest, this.volume});

  final double? oneRepMax;
  final double? heaviest;
  final double? volume;
}

/// What [exerciseId] reached in [sessions], counting only done sets that
/// count.
ExerciseBest bestOf(String exerciseId, Iterable<TrainingSession> sessions) {
  double? orm, heavy, volume;
  for (final session in sessions) {
    var sessionVolume = 0.0;
    var found = false;
    for (final e in session.exercises) {
      if (e.exerciseId != exerciseId) continue;
      for (final s in e.sets) {
        if (!s.done || !s.kind.counts) continue;
        found = true;
        sessionVolume += s.volume;
        final est = epley(s.kg, s.reps);
        if (est != null && (orm == null || est > orm)) orm = est;
        if (s.kg != null && (heavy == null || s.kg! > heavy)) heavy = s.kg;
      }
    }
    if (found && (volume == null || sessionVolume > volume)) {
      volume = sessionVolume;
    }
  }
  return ExerciseBest(oneRepMax: orm, heaviest: heavy, volume: volume);
}

/// What kind of record a set or session broke.
enum RecordKind { oneRepMax, heaviest, volume }

/// A record: [exerciseId] beat its best of before in [session].
class TrainingRecord {
  const TrainingRecord({
    required this.exerciseId,
    required this.kind,
    required this.value,
    required this.previous,
    required this.session,
  });

  final String exerciseId;
  final RecordKind kind;
  final double value;

  /// The best before, or null for the first time.
  final double? previous;
  final TrainingSession session;

  double? get gain => previous == null ? null : value - previous!;
}

List<TrainingSession>? _recordsFor;
List<TrainingRecord> _records = const [];

/// The records of [sessions], newest first: every session in which an
/// exercise beat what it had reached before. A first time is no record.
/// The last answer is kept while the same list is asked about again, as
/// pages that rebuild often do.
List<TrainingRecord> recordsOf(List<TrainingSession> sessions) {
  if (identical(sessions, _recordsFor)) return _records;
  _records = _recordsOf(sessions);
  _recordsFor = sessions;
  return _records;
}

List<TrainingRecord> _recordsOf(List<TrainingSession> sessions) {
  final sorted = [...sessions]..sort((a, b) => a.start.compareTo(b.start));
  final records = <TrainingRecord>[];
  final best = <String, ExerciseBest>{};
  for (final session in sorted) {
    final ids = {for (final e in session.exercises) e.exerciseId};
    for (final id in ids) {
      final now = bestOf(id, [session]);
      final before = best[id];
      if (before != null) {
        void check(RecordKind kind, double? value, double? old) {
          if (value != null && old != null && value > old + 0.01) {
            records.add(
              TrainingRecord(
                exerciseId: id,
                kind: kind,
                value: value,
                previous: old,
                session: session,
              ),
            );
          }
        }

        check(RecordKind.oneRepMax, now.oneRepMax, before.oneRepMax);
        check(RecordKind.heaviest, now.heaviest, before.heaviest);
        check(RecordKind.volume, now.volume, before.volume);
      }
      best[id] = ExerciseBest(
        oneRepMax: _max(before?.oneRepMax, now.oneRepMax),
        heaviest: _max(before?.heaviest, now.heaviest),
        volume: _max(before?.volume, now.volume),
      );
    }
  }
  return records.reversed.toList();
}

double? _max(double? a, double? b) =>
    a == null ? b : (b == null ? a : (a > b ? a : b));

/// The sets each muscle got from [sessions] between [from] and [to]: a full
/// set for a main muscle, half a set for a helping one.
Map<Muscle, double> setsPerMuscle(
  Iterable<TrainingSession> sessions, {
  required DateTime from,
  required DateTime to,
  List<Exercise> custom = const [],
}) {
  final out = <Muscle, double>{};
  for (final session in sessions) {
    if (session.start.isBefore(from) || !session.start.isBefore(to)) continue;
    for (final e in session.exercises) {
      final exercise = exerciseById(e.exerciseId, custom);
      if (exercise == null) continue;
      final n = e.sets.where((s) => s.done && s.kind.counts).length;
      if (n == 0) continue;
      for (final m in exercise.primary) {
        out[m] = (out[m] ?? 0) + n;
      }
      for (final m in exercise.secondary) {
        out[m] = (out[m] ?? 0) + n / 2;
      }
    }
  }
  return out;
}

/// The template that comes next in the rotation: the one after the template
/// of the last finished session that had one, or the first.
TrainingTemplate? nextTemplate(TrainingData data) {
  final rotation = [
    for (final id in data.rotation)
      if (data.template(id) != null) id,
  ];
  if (rotation.isEmpty) {
    return data.templates.isEmpty ? null : data.templates.first;
  }
  for (final session in data.sessions.reversed) {
    final at = rotation.indexOf(session.templateId ?? '');
    if (at >= 0) return data.template(rotation[(at + 1) % rotation.length]);
  }
  return data.template(rotation.first);
}

/// Monday 00:00 of the week of [day].
DateTime weekStart(DateTime day) =>
    DateTime(day.year, day.month, day.day - (day.weekday - 1));

/// The trainings of the week of [day]: sessions plus the workouts of the
/// health store that no session is linked to. Walks are left out; a watch
/// records every longer walk by itself.
List<DateTime> trainingDaysOfWeek(
  DateTime day,
  List<TrainingSession> sessions,
  List<Workout> workouts,
) {
  final from = weekStart(day);
  final to = DateTime(from.year, from.month, from.day + 7);
  bool inWeek(DateTime t) => !t.isBefore(from) && t.isBefore(to);
  final linked = {for (final s in sessions) ?s.linkedWorkout};
  return [
    for (final s in sessions)
      if (inWeek(s.start)) s.start,
    for (final w in workouts)
      if (inWeek(w.start) &&
          !linked.contains(w.key) &&
          w.type.family != WorkoutFamily.walk)
        w.start,
  ]..sort();
}

/// What to put in the sets of [exerciseId] this time: the sets of last
/// time, and 2.5 kg more on the working sets if every one of them reached
/// [targetReps] (or the reps it had, without a target). Without [more], as
/// for a training logged afterwards, the weights stay as they were.
List<TrainingSet> prefill(
  String exerciseId,
  List<TrainingSession> sessions, {
  int? targetReps,
  int fallbackSets = 3,
  bool more = true,
}) {
  for (final session in sessions.reversed) {
    for (final e in session.exercises) {
      if (e.exerciseId != exerciseId) continue;
      final done = e.sets.where((s) => s.done).toList();
      if (done.isEmpty) continue;
      final working = done.where((s) => s.kind == SetKind.working).toList();
      final target = targetReps ?? e.targetReps;
      final allMet =
          more &&
          working.isNotEmpty &&
          working.every(
            (s) =>
                s.reps != null &&
                s.kg != null &&
                (target == null || s.reps! >= target),
          ) &&
          working.length ==
              e.sets.where((s) => s.kind == SetKind.working).length;
      return [
        for (final s in done)
          TrainingSet(
            kg: s.kind == SetKind.working && allMet && s.kg != null
                ? s.kg! + 2.5
                : s.kg,
            reps: target ?? s.reps,
            kind: s.kind,
          ),
      ];
    }
  }
  return [for (var i = 0; i < fallbackSets; i++) TrainingSet(reps: targetReps)];
}

/// The template usually trained at the time of [start]: the one most often
/// trained on its weekday, when that happened at least twice, or else the
/// one next in the rotation.
TrainingTemplate? usualTemplate(TrainingData data, DateTime start) {
  final counts = <String, int>{};
  for (final s in data.sessions) {
    final id = s.templateId;
    if (id == null || s.start.weekday != start.weekday) continue;
    if (data.template(id) == null) continue;
    counts[id] = (counts[id] ?? 0) + 1;
  }
  final best = counts.entries.fold<MapEntry<String, int>?>(
    null,
    (a, b) => a == null || b.value > a.value ? b : a,
  );
  if (best != null && best.value >= 2) return data.template(best.key);
  return nextTemplate(data);
}

/// Whether [prefill] would put more weight on [exerciseId] than last time.
bool suggestsMore(
  String exerciseId,
  List<TrainingSession> sessions, {
  int? targetReps,
}) {
  final next = prefill(exerciseId, sessions, targetReps: targetReps);
  for (final session in sessions.reversed) {
    for (final e in session.exercises) {
      if (e.exerciseId != exerciseId) continue;
      final last = e.sets.where((s) => s.done).toList();
      if (last.isEmpty) continue;
      for (var i = 0; i < last.length && i < next.length; i++) {
        if ((next[i].kg ?? 0) > (last[i].kg ?? 0)) return true;
      }
      return false;
    }
  }
  return false;
}

/// The last done set of [exerciseId], with the session it was in.
(TrainingSet, TrainingSession)? lastSetOf(
  String exerciseId,
  List<TrainingSession> sessions,
) {
  for (final session in sessions.reversed) {
    for (final e in session.exercises) {
      if (e.exerciseId != exerciseId) continue;
      TrainingSet? top;
      for (final s in e.sets) {
        if (!s.done || !s.kind.counts) continue;
        if (top == null || (s.kg ?? 0) > (top.kg ?? 0)) top = s;
      }
      if (top != null) return (top, session);
    }
  }
  return null;
}

/// The estimated maximum of [exerciseId] per session, oldest first, for its
/// chart.
List<(DateTime, double)> oneRepMaxHistory(
  String exerciseId,
  List<TrainingSession> sessions,
) => [
  for (final session in sessions)
    if (bestOf(exerciseId, [session]).oneRepMax case final double v)
      (session.start, v),
];
