import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../json_store.dart';
import '../models.dart';
import 'session_link.dart';
import 'training_insights.dart';
import 'training_models.dart';
import 'training_splits.dart';

/// Holds the trainings: the templates, the finished sessions and the one
/// that runs, with its rest. Everything is saved on every change, so a
/// session survives the app being closed in the middle of it. Nothing goes
/// to the health store: a session is only linked to the workout a watch
/// recorded at the same time.
class TrainingController extends ChangeNotifier {
  TrainingController(
    this._store, {
    this.clock = DateTime.now,
    TrainingNotices? notices,
  }) : _notices = notices ?? const TrainingNotices();

  final JsonStore _store;
  final DateTime Function() clock;
  final TrainingNotices _notices;
  TrainingData _data = const TrainingData();
  bool _disposed = false;
  Timer? _restTimer;

  /// Called when a rest is over, for the haptic signal.
  VoidCallback? onRestOver;

  TrainingData get data => _data;
  TrainingSession? get active => _data.active;
  DateTime? get restEndsAt => _data.restEndsAt;
  DateTime get now => clock();

  /// How long the running rest was set for; after a restart of the app
  /// only what was left then.
  Duration? get restLength => _restLength;
  Duration? _restLength;

  /// What is left of the rest, or null when none runs.
  Duration? get restLeft {
    final end = _data.restEndsAt;
    if (end == null) return null;
    final left = end.difference(clock());
    return left.isNegative ? null : left;
  }

  Future<void> load() async {
    final data = TrainingData.fromJson(await _store.read(StoreKeys.training));
    if (_disposed) return;
    _data = data;
    _armRest();
    notifyListeners();
  }

  Timer? _writeSoon;

  /// Takes [data] and saves it, at once or, for [soon], a moment later so a
  /// number typed digit by digit is written once.
  Future<void> _set(TrainingData data, {bool soon = false}) async {
    _data = data;
    if (!_disposed) notifyListeners();
    if (soon) {
      _writeSoon?.cancel();
      _writeSoon = Timer(const Duration(milliseconds: 600), () {
        _writeSoon = null;
        unawaited(_store.write(StoreKeys.training, _data.toJson()));
      });
      return;
    }
    _writeSoon?.cancel();
    _writeSoon = null;
    await _store.write(StoreKeys.training, data.toJson());
  }

  /// Writes what waits to be written; for the app going to the background.
  Future<void> flush() async {
    if (_writeSoon == null) return;
    _writeSoon!.cancel();
    _writeSoon = null;
    await _store.write(StoreKeys.training, _data.toJson());
  }

  String _id() => clock().microsecondsSinceEpoch.toRadixString(36);

  // Templates.

  Future<TrainingTemplate> saveTemplate(TrainingTemplate template) async {
    final list = [..._data.templates];
    final at = list.indexWhere((t) => t.id == template.id);
    if (at >= 0) {
      list[at] = template;
      await _set(_data.copyWith(templates: list));
    } else {
      await _set(
        _data.copyWith(
          templates: [...list, template],
          rotation: [..._data.rotation, template.id],
        ),
      );
    }
    return template;
  }

  /// A copy of the template [id] named [name], next to it in the rotation
  /// when the original is in it, so a second day of the kind needs no
  /// starting over.
  Future<TrainingTemplate?> duplicateTemplate(String id, String name) async {
    final original = _data.template(id);
    if (original == null) return null;
    final copy = TrainingTemplate(
      id: 't${_id()}',
      name: name,
      exercises: original.exercises,
    );
    final at = _data.rotation.indexOf(id);
    await _set(
      _data.copyWith(
        templates: [..._data.templates, copy],
        rotation: at < 0
            ? _data.rotation
            : ([..._data.rotation]..insert(at + 1, copy.id)),
      ),
    );
    return copy;
  }

  TrainingTemplate newTemplate(String name) =>
      TrainingTemplate(id: 't${_id()}', name: name);

  Future<void> removeTemplate(String id) => _set(
    _data.copyWith(
      templates: [
        for (final t in _data.templates)
          if (t.id != id) t,
      ],
      rotation: [
        for (final r in _data.rotation)
          if (r != id) r,
      ],
    ),
  );

  Future<void> setRotation(List<String> ids) =>
      _set(_data.copyWith(rotation: ids));

  Future<void> setWeeklyGoal(int goal) =>
      _set(_data.copyWith(weeklyGoal: goal.clamp(1, 14)));

  /// Puts in the push, pull and legs templates the app brings along.
  Future<void> addStarterTemplates(Map<String, String> names) =>
      applySplit(TrainingSplit.pushPullLegs, names);

  /// Makes [split] the plan: its templates, made where they are missing,
  /// become the rotation and its trainings a week the goal. Templates of
  /// before stay, out of the rotation. [names] names the templates by key.
  Future<void> applySplit(
    TrainingSplit split,
    Map<String, String> names,
  ) async {
    final templates = [..._data.templates];
    final rotation = <String>[];
    for (final (key, exercises) in split.days) {
      var template = templates.where((t) => split.owns(t.id, key)).firstOrNull;
      if (template == null) {
        template = TrainingTemplate(
          id: 't${_id()}${split.idOf(key)}',
          name: names[key] ?? key,
          exercises: exercises,
        );
        templates.add(template);
      }
      rotation.add(template.id);
    }
    await _set(
      _data.copyWith(
        templates: templates,
        rotation: rotation,
        weeklyGoal: split.weeklyGoal,
        split: () => split.name,
      ),
    );
  }

  // Own exercises.

  Future<Exercise> addExercise({
    required String name,
    required List<Muscle> primary,
    Equipment equipment = Equipment.other,
  }) async {
    final exercise = Exercise(
      id: 'x${_id()}',
      names: {'en': name, 'de': name, 'pl': name},
      primary: primary,
      equipment: equipment,
      custom: true,
    );
    await _set(
      _data.copyWith(customExercises: [..._data.customExercises, exercise]),
    );
    return exercise;
  }

  // The running session.

  /// Starts [template], or an empty session without one. [start] is for a
  /// training that is logged afterwards, [linked] for the workout it was.
  Future<TrainingSession> start({
    TrainingTemplate? template,
    required String name,
    DateTime? start,
    String? linked,
  }) async {
    final session = TrainingSession(
      id: 's${_id()}',
      name: template?.name ?? name,
      start: start ?? clock(),
      templateId: template?.id,
      linkedWorkout: linked,
      exercises: [
        for (final e in template?.exercises ?? const <TemplateExercise>[])
          SessionExercise(
            exerciseId: e.exerciseId,
            restSeconds: e.restSeconds,
            targetReps: e.reps,
            sets: _sized(
              prefill(e.exerciseId, _data.sessions, targetReps: e.reps),
              e.sets,
              e.reps,
            ),
          ),
      ],
    );
    await _set(_data.copyWith(active: () => session, restEndsAt: () => null));
    return session;
  }

  List<TrainingSet> _sized(List<TrainingSet> sets, int count, int reps) {
    final working = sets.where((s) => s.kind == SetKind.working).toList();
    final warmups = sets.where((s) => s.kind == SetKind.warmup).toList();
    final base = working.isEmpty ? TrainingSet(reps: reps) : working.last;
    return [
      ...warmups,
      for (var i = 0; i < count; i++)
        i < working.length ? working[i] : base.copyWith(done: false),
    ];
  }

  /// Changes the running session, or with [session] the finished one of
  /// that id: the editing below serves both.
  Future<void> _edit(
    TrainingSession Function(TrainingSession) change, {
    bool soon = false,
    String? session,
  }) async {
    if (session != null) {
      final list = [..._data.sessions];
      final at = list.indexWhere((s) => s.id == session);
      if (at < 0) return;
      list[at] = change(list[at]);
      await _set(_data.copyWith(sessions: list), soon: soon);
      return;
    }
    final active = _data.active;
    if (active == null) return;
    await _set(_data.copyWith(active: () => change(active)), soon: soon);
  }

  Future<void> addExerciseToSession(String exerciseId, {String? session}) =>
      _edit(
        (s) => s.copyWith(
          exercises: [
            ...s.exercises,
            SessionExercise(
              exerciseId: exerciseId,
              sets: [
                for (final set in prefill(exerciseId, _data.sessions))
                  // Logged afterwards, the sets were done.
                  set.copyWith(done: session != null),
              ],
            ),
          ],
        ),
        session: session,
      );

  Future<void> removeExerciseFromSession(int index, {String? session}) => _edit(
    (s) => s.copyWith(exercises: [...s.exercises]..removeAt(index)),
    session: session,
  );

  Future<void> moveExercise(int from, int to, {String? session}) => _edit((s) {
    final list = [...s.exercises];
    final e = list.removeAt(from);
    list.insert(to.clamp(0, list.length), e);
    return s.copyWith(exercises: list);
  }, session: session);

  Future<void> _editExercise(
    int index,
    SessionExercise Function(SessionExercise) change, {
    bool soon = false,
    String? session,
  }) => _edit(
    (s) {
      final list = [...s.exercises];
      list[index] = change(list[index]);
      return s.copyWith(exercises: list);
    },
    soon: soon,
    session: session,
  );

  Future<void> addSet(int exercise, {String? session}) =>
      _editExercise(exercise, session: session, (e) {
        final last = e.sets.isEmpty ? null : e.sets.last;
        return e.copyWith(
          sets: [
            ...e.sets,
            TrainingSet(
              kg: last?.kg,
              reps: last?.reps ?? e.targetReps,
              kind: last?.kind == SetKind.warmup
                  ? SetKind.working
                  : (last?.kind ?? SetKind.working),
              done: session != null,
            ),
          ],
        );
      });

  Future<void> removeSet(int exercise, int set, {String? session}) =>
      _editExercise(
        exercise,
        (e) => e.copyWith(sets: [...e.sets]..removeAt(set)),
        session: session,
      );

  /// Puts [value] in place of a set. While a number is [typing], it is
  /// saved a moment after the last key.
  Future<void> updateSet(
    int exercise,
    int set,
    TrainingSet value, {
    bool typing = false,
    String? session,
  }) => _editExercise(
    exercise,
    (e) {
      final sets = [...e.sets];
      sets[set] = value;
      return e.copyWith(sets: sets);
    },
    soon: typing,
    session: session,
  );

  /// Marks a set done or not; done in the running training, it starts the
  /// rest of its exercise.
  Future<void> toggleSet(int exercise, int set, {String? session}) async {
    final target = session == null
        ? _data.active
        : _data.sessions.where((s) => s.id == session).firstOrNull;
    if (target == null) return;
    final e = target.exercises[exercise];
    final s = e.sets[set];
    await updateSet(exercise, set, s.copyWith(done: !s.done), session: session);
    if (!s.done && session == null) {
      await startRest(Duration(seconds: e.restSeconds));
    }
  }

  Future<void> setRest(int exercise, int seconds, {String? session}) =>
      _editExercise(
        exercise,
        (e) => e.copyWith(restSeconds: seconds),
        session: session,
      );

  /// Puts in, as done, the training [workout] of the watch was: the sets of
  /// [template] with the weights of last time, at the time of the workout
  /// and linked to it. Nothing runs; the sets are there to be corrected.
  Future<TrainingSession> logAfter(
    Workout workout, {
    TrainingTemplate? template,
    required String name,
  }) async {
    final session = TrainingSession(
      id: 's${_id()}',
      name: template?.name ?? name,
      start: workout.start,
      end: workout.end,
      templateId: template?.id,
      linkedWorkout: workout.key,
      exercises: [
        for (final e in template?.exercises ?? const <TemplateExercise>[])
          SessionExercise(
            exerciseId: e.exerciseId,
            restSeconds: e.restSeconds,
            targetReps: e.reps,
            sets: [
              for (final s in _sized(
                prefill(
                  e.exerciseId,
                  [
                    for (final s in _data.sessions)
                      if (s.start.isBefore(workout.start)) s,
                  ],
                  targetReps: e.reps,
                  more: false,
                ),
                e.sets,
                e.reps,
              ))
                s.copyWith(done: true),
            ],
          ),
      ],
    );
    final sessions = [..._data.sessions, session]
      ..sort((a, b) => a.start.compareTo(b.start));
    await _set(_data.copyWith(sessions: sessions));
    return session;
  }

  Future<void> startRest(Duration length) async {
    if (length <= Duration.zero) return stopRest();
    final end = clock().add(length);
    _restLength = length;
    await _set(_data.copyWith(restEndsAt: () => end));
    _armRest();
    unawaited(_notices.rest(end, _data.active?.name ?? ''));
  }

  Future<void> addRest(Duration more) async {
    final end = _data.restEndsAt;
    if (end == null) return startRest(more);
    final next = end.add(more);
    if (!next.isAfter(clock())) return stopRest();
    _restLength = (_restLength ?? end.difference(clock())) + more;
    await _set(_data.copyWith(restEndsAt: () => next));
    _armRest();
    unawaited(_notices.rest(next, _data.active?.name ?? ''));
  }

  Future<void> stopRest() async {
    _restTimer?.cancel();
    if (_data.restEndsAt == null) return;
    await _set(_data.copyWith(restEndsAt: () => null));
    unawaited(_notices.clear());
  }

  void _armRest() {
    _restTimer?.cancel();
    final left = restLeft;
    if (left == null) return;
    _restTimer = Timer(left, () {
      if (_disposed) return;
      onRestOver?.call();
      _data = _data.copyWith(restEndsAt: () => null);
      notifyListeners();
      unawaited(_store.write(StoreKeys.training, _data.toJson()));
    });
  }

  /// Ends the running session and keeps it, linked to its workout where the
  /// health store has one. A session without a done set is dropped.
  Future<TrainingSession?> finish(List<Workout> workouts) async {
    final session = _data.active;
    if (session == null) return null;
    _restTimer?.cancel();
    unawaited(_notices.clear());
    if (session.countingSets.isEmpty &&
        session.exercises.every((e) => e.sets.every((s) => !s.done))) {
      await _set(_data.copyWith(active: () => null, restEndsAt: () => null));
      return null;
    }
    var done = session.copyWith(
      end: () => session.linkedWorkout == null
          ? clock()
          : (linkedWorkoutOf(session, workouts)?.end ?? clock()),
      exercises: [
        for (final e in session.exercises)
          e.copyWith(
            sets: [
              for (final s in e.sets)
                if (s.done) s,
            ],
          ),
      ],
    );
    done = done.copyWith(
      exercises: [
        for (final e in done.exercises)
          if (e.sets.isNotEmpty) e,
      ],
    );
    final sessions = [..._data.sessions, done];
    await _set(
      _data.copyWith(
        sessions: linkAll(sessions, workouts) ?? sessions,
        active: () => null,
        restEndsAt: () => null,
      ),
    );
    return _data.sessions.lastWhere((s) => s.id == done.id);
  }

  Future<void> discard() async {
    _restTimer?.cancel();
    unawaited(_notices.clear());
    await _set(_data.copyWith(active: () => null, restEndsAt: () => null));
  }

  Future<void> deleteSession(String id) => _set(
    _data.copyWith(
      sessions: [
        for (final s in _data.sessions)
          if (s.id != id) s,
      ],
    ),
  );

  /// Takes the link of [id] back for good, or links it to [workout].
  Future<void> setLink(String id, String? workout) => _set(
    _data.copyWith(
      sessions: [
        for (final s in _data.sessions)
          if (s.id == id)
            s.copyWith(linkedWorkout: () => workout, unlinked: workout == null)
          else
            s,
      ],
    ),
  );

  /// Links what is not linked yet; called whenever new workouts are read.
  Future<void> link(List<Workout> workouts) async {
    final linked = linkAll(_data.sessions, workouts);
    if (linked != null) await _set(_data.copyWith(sessions: linked));
  }

  @override
  void dispose() {
    _disposed = true;
    _restTimer?.cancel();
    unawaited(flush());
    super.dispose();
  }
}

/// The ongoing notification of a rest, with its countdown, so the end shows
/// while the phone is in the pocket. Silent where there is no platform.
class TrainingNotices {
  const TrainingNotices();

  static const MethodChannel _channel = MethodChannel(
    'at.haiden.pulse/training',
  );

  Future<void> rest(DateTime end, String title) async {
    try {
      await _channel.invokeMethod<void>('rest', {
        'end': end.millisecondsSinceEpoch,
        'title': title,
      });
    } on MissingPluginException {
      // No platform, as on the desktop and in tests.
    } on PlatformException catch (error) {
      debugPrint('Showing the rest failed: $error');
    }
  }

  Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clear');
    } on MissingPluginException {
      // As above.
    } on PlatformException catch (error) {
      debugPrint('Clearing the rest failed: $error');
    }
  }
}
