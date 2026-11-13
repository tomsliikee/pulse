import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/training/exercise_library.dart';
import 'package:pulse/data/training/session_link.dart';
import 'package:pulse/data/training/training_controller.dart';
import 'package:pulse/data/training/training_splits.dart';
import 'package:pulse/data/training/training_insights.dart';
import 'package:pulse/data/training/training_models.dart';

import 'support/fixtures.dart';

TrainingSession _session(
  String id,
  DateTime start, {
  List<SessionExercise> exercises = const [],
  String? template,
  int minutes = 60,
  String? linked,
  bool unlinked = false,
}) => TrainingSession(
  id: id,
  name: id,
  start: start,
  end: start.add(Duration(minutes: minutes)),
  templateId: template,
  exercises: exercises,
  linkedWorkout: linked,
  unlinked: unlinked,
);

SessionExercise _ex(String id, List<(double, int)> sets, {int? target}) =>
    SessionExercise(
      exerciseId: id,
      targetReps: target,
      sets: [
        for (final (kg, reps) in sets)
          TrainingSet(kg: kg, reps: reps, done: true),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('epley', () {
    test('estimates from 1 to 10 reps only', () {
      expect(epley(100, 1), 100);
      expect(epley(80, 8), closeTo(101.33, 0.01));
      expect(epley(80, 11), isNull);
      expect(epley(80, 0), isNull);
      expect(epley(null, 5), isNull);
    });
  });

  group('records', () {
    test('a first time is no record, a better one is', () {
      final a = _session(
        'a',
        DateTime(2026, 11, 2),
        exercises: [
          _ex('benchPress', [(80, 8), (80, 8)]),
        ],
      );
      final b = _session(
        'b',
        DateTime(2026, 11, 5),
        exercises: [
          _ex('benchPress', [(82.5, 8), (80, 8)]),
        ],
      );
      expect(recordsOf([a]), isEmpty);
      final records = recordsOf([a, b]);
      expect(records.map((r) => r.kind).toSet(), {
        RecordKind.oneRepMax,
        RecordKind.heaviest,
        RecordKind.volume,
      });
      final orm = records.firstWhere((r) => r.kind == RecordKind.oneRepMax);
      expect(orm.gain, closeTo(2.5 * (1 + 8 / 30), 0.01));
      expect(orm.session.id, 'b');
    });

    test('warm-up and undone sets do not count', () {
      final s = _session(
        'a',
        DateTime(2026, 11, 2),
        exercises: [
          const SessionExercise(
            exerciseId: 'squat',
            sets: [
              TrainingSet(kg: 140, reps: 3, kind: SetKind.warmup, done: true),
              TrainingSet(kg: 150, reps: 3),
              TrainingSet(kg: 100, reps: 5, done: true),
            ],
          ),
        ],
      );
      final best = bestOf('squat', [s]);
      expect(best.heaviest, 100);
      expect(best.volume, 500);
    });
  });

  test('sets per muscle: main muscle whole, helper half, in the window', () {
    final inside = _session(
      'a',
      DateTime(2026, 11, 10),
      exercises: [
        _ex('benchPress', [(80, 8), (80, 8), (80, 8)]),
      ],
    );
    final outside = _session(
      'b',
      DateTime(2026, 11, 1),
      exercises: [
        _ex('benchPress', [(80, 8)]),
      ],
    );
    final map = setsPerMuscle(
      [inside, outside],
      from: DateTime(2026, 11, 6),
      to: DateTime(2026, 11, 13),
    );
    expect(map[Muscle.chest], 3);
    expect(map[Muscle.triceps], 1.5);
    expect(map[Muscle.quads], isNull);
  });

  test('the rotation goes on after the last template done', () {
    const push = TrainingTemplate(id: 'p', name: 'Push');
    const pull = TrainingTemplate(id: 'q', name: 'Pull');
    const legs = TrainingTemplate(id: 'l', name: 'Legs');
    var data = const TrainingData(
      templates: [push, pull, legs],
      rotation: ['p', 'q', 'l'],
    );
    expect(nextTemplate(data)?.id, 'p');
    data = data.copyWith(
      sessions: [
        _session('a', DateTime(2026, 11, 2), template: 'p'),
        _session('b', DateTime(2026, 11, 4), template: 'l'),
        _session('c', DateTime(2026, 11, 5)),
      ],
    );
    expect(nextTemplate(data)?.id, 'p');
    data = data.copyWith(
      sessions: [
        ...data.sessions,
        _session('d', DateTime(2026, 11, 6), template: 'p'),
      ],
    );
    expect(nextTemplate(data)?.id, 'q');
  });

  group('prefill', () {
    test('adds 2.5 kg when every working set reached its reps', () {
      final last = _session(
        'a',
        DateTime(2026, 11, 2),
        exercises: [
          _ex('benchPress', [(80, 8), (80, 8)], target: 8),
        ],
      );
      final next = prefill('benchPress', [last], targetReps: 8);
      expect(next.map((s) => s.kg), [82.5, 82.5]);
      expect(suggestsMore('benchPress', [last], targetReps: 8), isTrue);
    });

    test('keeps the weight when a set fell short', () {
      final last = _session(
        'a',
        DateTime(2026, 11, 2),
        exercises: [
          _ex('benchPress', [(80, 8), (80, 6)], target: 8),
        ],
      );
      expect(prefill('benchPress', [last], targetReps: 8).map((s) => s.kg), [
        80,
        80,
      ]);
    });

    test('without a history gives empty sets', () {
      final sets = prefill('squat', const [], targetReps: 5, fallbackSets: 4);
      expect(sets, hasLength(4));
      expect(sets.first.kg, isNull);
      expect(sets.first.reps, 5);
    });
  });

  group('linking', () {
    final strength = Workout(
      type: WorkoutType.strength,
      start: DateTime(2026, 11, 12, 18, 2),
      minutes: 63,
    );
    final walk = Workout(
      type: WorkoutType.walk,
      start: DateTime(2026, 11, 12, 18, 0),
      minutes: 60,
    );

    test('prefers strength and matches it halfway', () {
      final s = _session('a', DateTime(2026, 11, 12, 18), minutes: 60);
      expect(linkFor(s, [walk, strength])?.key, strength.key);
      // A little overlap is enough for strength, not for a walk.
      final late = _session('b', DateTime(2026, 11, 12, 18, 50), minutes: 60);
      expect(linkFor(late, [strength])?.key, strength.key);
      expect(linkFor(late, [walk]), isNull);
      // No overlap, but half an hour after, the same day.
      final after = _session('c', DateTime(2026, 11, 12, 19, 35), minutes: 40);
      expect(linkFor(after, [strength])?.key, strength.key);
      // Two hours after, or the next day, is another training.
      final evening = _session('d', DateTime(2026, 11, 12, 21, 5), minutes: 40);
      expect(linkFor(evening, [strength]), isNull);
      final next = _session('e', DateTime(2026, 11, 13, 18), minutes: 60);
      expect(linkFor(next, [strength]), isNull);
    });

    test('links all but those unlinked by hand or already taken', () {
      final a = _session('a', DateTime(2026, 11, 12, 18));
      final b = _session('b', DateTime(2026, 11, 12, 18), unlinked: true);
      final linked = linkAll([a, b], [strength])!;
      expect(linked[0].linkedWorkout, strength.key);
      expect(linked[1].linkedWorkout, isNull);
      expect(linkAll(linked, [strength]), isNull);
    });

    test('a workout without a session shows as unmatched', () {
      expect(
        unmatchedStrength(const [], [
          strength,
          walk,
        ], since: DateTime(2026, 11, 12)),
        [strength],
      );
    });
  });

  test('the week counts sessions and unlinked workouts, not walks', () {
    final day = DateTime(2026, 11, 12);
    final run = Workout(
      type: WorkoutType.run,
      start: DateTime(2026, 11, 10, 7),
      minutes: 40,
    );
    final walk = Workout(
      type: WorkoutType.walk,
      start: DateTime(2026, 11, 10, 9),
      minutes: 40,
    );
    final linked = Workout(
      type: WorkoutType.strength,
      start: DateTime(2026, 11, 11, 18),
      minutes: 60,
    );
    final s = _session('a', DateTime(2026, 11, 11, 18), linked: linked.key);
    final old = _session('b', DateTime(2026, 11, 8, 18));
    expect(
      trainingDaysOfWeek(day, [s, old], [run, walk, linked]),
      hasLength(2),
    );
  });

  test('the library has unique ids and three names each', () {
    final ids = {for (final e in exerciseLibrary) e.id};
    expect(ids.length, exerciseLibrary.length);
    expect(exerciseLibrary.length, greaterThanOrEqualTo(80));
    for (final e in exerciseLibrary) {
      expect(e.names.keys.toSet(), {'en', 'de', 'pl'}, reason: e.id);
      expect(e.primary, isNotEmpty, reason: e.id);
    }
  });

  group('controller', () {
    test(
      'a training is logged afterwards with last weights, not run',
      () async {
        final store = MemoryJsonStore();
        final c = TrainingController(
          store,
          clock: () => DateTime(2026, 11, 13, 9),
        );
        await c.load();
        await c.applySplit(TrainingSplit.pushPullLegs, {'push': 'Push'});
        final push = c.data.template(c.data.rotation.first)!;
        // Last week: bench 80 kg for all sets.
        final ran = await c.logAfter(
          Workout(
            type: WorkoutType.strength,
            start: DateTime(2026, 11, 5, 18),
            minutes: 60,
          ),
          template: push,
          name: '',
        );
        await c.updateSet(
          0,
          0,
          ran.exercises.first.sets.first.copyWith(kg: () => 80),
          session: ran.id,
        );
        final watch = Workout(
          type: WorkoutType.strength,
          start: DateTime(2026, 11, 12, 18),
          minutes: 55,
        );
        final logged = await c.logAfter(watch, template: push, name: '');
        expect(c.active, isNull);
        expect(logged.linkedWorkout, watch.key);
        expect(logged.end, watch.end);
        final bench = logged.exercises.first;
        expect(bench.sets.every((s) => s.done), isTrue);
        expect(bench.sets.first.kg, 80);
        // A set of the finished one can be taken back and another added.
        await c.toggleSet(0, 0, session: logged.id);
        await c.addSet(0, session: logged.id);
        final now = c.data.sessions.firstWhere((s) => s.id == logged.id);
        expect(now.exercises.first.sets.first.done, isFalse);
        expect(now.exercises.first.sets.last.done, isTrue);
        expect(c.restLeft, isNull);
        await c.moveExercise(0, 1, session: logged.id);
        expect(
          c.data.sessions
              .firstWhere((s) => s.id == logged.id)
              .exercises[1]
              .exerciseId,
          bench.exerciseId,
        );
      },
    );

    test('a template is copied next to it in the rotation', () async {
      final c = TrainingController(MemoryJsonStore());
      await c.load();
      await c.applySplit(TrainingSplit.pushPullLegs, const {});
      final push = c.data.rotation.first;
      final copy = await c.duplicateTemplate(push, 'Push B');
      expect(c.data.rotation[1], copy!.id);
      expect(copy.exercises, c.data.template(push)!.exercises);
    });

    test('the usual template is the one of the weekday, else the next', () {
      const a = TrainingTemplate(id: 'a', name: 'A');
      const b = TrainingTemplate(id: 'b', name: 'B');
      TrainingSession on(DateTime d, String t) => TrainingSession(
        id: '$d',
        name: t,
        start: d,
        end: d.add(const Duration(hours: 1)),
        templateId: t,
      );
      final data = TrainingData(
        templates: const [a, b],
        rotation: const ['a', 'b'],
        sessions: [
          on(DateTime(2026, 11, 2, 18), 'b'), // Monday
          on(DateTime(2026, 11, 4, 18), 'a'),
          on(DateTime(2026, 11, 9, 18), 'b'), // Monday
          on(DateTime(2026, 11, 11, 18), 'a'),
        ],
      );
      expect(usualTemplate(data, DateTime(2026, 11, 16, 18))?.id, 'b');
      expect(usualTemplate(data, DateTime(2026, 11, 17, 18))?.id, 'b');
    });

    test('a split becomes the rotation once, own templates stay', () async {
      final store = MemoryJsonStore();
      final c = TrainingController(store);
      await c.load();
      final own = await c.saveTemplate(c.newTemplate('Mine'));
      await c.applySplit(TrainingSplit.arnold, {'chestBack': 'Chest & back'});
      expect(c.data.split, 'arnold');
      expect(c.data.weeklyGoal, 6);
      expect(c.data.rotation, hasLength(3));
      expect(c.data.rotation, isNot(contains(own.id)));
      expect(c.data.template(c.data.rotation.first)?.name, 'Chest & back');
      for (final (_, exercises) in TrainingSplit.values.expand((s) => s.days)) {
        for (final e in exercises) {
          expect(exerciseById(e.exerciseId), isNotNull, reason: e.exerciseId);
        }
      }
      // Chosen again, it makes nothing twice.
      await c.applySplit(TrainingSplit.arnold, const {});
      expect(c.data.templates, hasLength(4));
      // Back to push, pull and legs, then Arnold again: the same templates.
      final arnold = [...c.data.rotation];
      await c.applySplit(TrainingSplit.pushPullLegs, const {});
      expect(c.data.templates, hasLength(7));
      await c.applySplit(TrainingSplit.arnold, const {});
      expect(c.data.rotation, arnold);
      await c.flush();
      final again = TrainingController(store);
      await again.load();
      expect(again.data.split, 'arnold');
    });

    test('a session survives a reload and is kept on finish', () async {
      final store = MemoryJsonStore();
      var now = DateTime(2026, 11, 12, 18);
      final c = TrainingController(store, clock: () => now);
      await c.load();
      await c.addStarterTemplates({'push': 'Push A'});
      final template = c.data.templates.firstWhere((t) => t.name == 'Push A');
      await c.start(template: template, name: '');
      expect(c.active?.exercises, hasLength(template.exercises.length));
      await c.toggleSet(0, 0);
      expect(c.restLeft, isNotNull);

      final again = TrainingController(store, clock: () => now);
      await again.load();
      expect(again.active?.exercises.first.sets.first.done, isTrue);

      now = now.add(const Duration(minutes: 60));
      final strength = Workout(
        type: WorkoutType.strength,
        start: DateTime(2026, 11, 12, 18, 2),
        minutes: 55,
      );
      final done = await again.finish([strength]);
      expect(done?.linkedWorkout, strength.key);
      expect(done?.exercises, hasLength(1));
      expect(done?.exercises.first.sets, hasLength(1));
      expect(again.active, isNull);
      again.dispose();
      c.dispose();
    });

    test('a session without a done set is dropped', () async {
      final c = TrainingController(
        MemoryJsonStore(),
        clock: () => DateTime(2026, 11, 12),
      );
      await c.start(name: 'Empty');
      await c.addExerciseToSession('squat');
      expect(await c.finish(const []), isNull);
      expect(c.data.sessions, isEmpty);
      c.dispose();
    });

    test('a damaged file gives empty data', () async {
      final store = MemoryJsonStore();
      await store.write(StoreKeys.training, ['not', 'a', 'map']);
      final c = TrainingController(store);
      await c.load();
      expect(c.data.sessions, isEmpty);
      await store.write(StoreKeys.training, {
        'sessions': [
          {'id': 'x'},
          {'id': 'y', 'start': '2026-11-12T18:00:00.000'},
        ],
      });
      await c.load();
      expect(c.data.sessions.map((s) => s.id), ['y']);
      c.dispose();
    });

    test('unlinking stays unlinked', () async {
      final store = MemoryJsonStore();
      final c = TrainingController(
        store,
        clock: () => DateTime(2026, 11, 12, 19),
      );
      final strength = Workout(
        type: WorkoutType.strength,
        start: DateTime(2026, 11, 12, 18),
        minutes: 60,
      );
      await c.start(name: 'A', start: DateTime(2026, 11, 12, 18));
      await c.addExerciseToSession('squat');
      await c.updateSet(0, 0, const TrainingSet(kg: 100, reps: 5, done: true));
      final s = await c.finish([strength]);
      expect(s?.linkedWorkout, strength.key);
      await c.setLink(s!.id, null);
      await c.link([strength]);
      expect(c.data.sessions.single.linkedWorkout, isNull);
      c.dispose();
    });
  });
}
