import 'package:flutter/foundation.dart';

/// A muscle group, as the heat map and the exercises name them.
enum Muscle {
  chest(front: true),
  shoulders(front: true),
  biceps(front: true),
  triceps(front: false),
  forearms(front: true),
  abs(front: true),
  obliques(front: true),
  quads(front: true),
  adductors(front: true),
  traps(front: false),
  upperBack(front: false),
  lats(front: false),
  lowerBack(front: false),
  glutes(front: false),
  hamstrings(front: false),
  calves(front: false);

  const Muscle({required this.front});

  /// Whether the muscle is drawn on the front of the figure.
  final bool front;

  static Muscle? byName(String? name) {
    for (final m in values) {
      if (m.name == name) return m;
    }
    return null;
  }
}

/// What an exercise is done with.
enum Equipment {
  barbell,
  dumbbell,
  machine,
  cable,
  bodyweight,
  kettlebell,
  band,
  other;

  static Equipment byName(String? name) {
    for (final e in values) {
      if (e.name == name) return e;
    }
    return other;
  }
}

/// What kind of set a set is. Only working, drop and failure sets count for
/// records and for the heat map.
enum SetKind {
  warmup,
  working,
  drop,
  failure;

  bool get counts => this != warmup;

  static SetKind byName(String? name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return working;
  }
}

/// An exercise of the library, or one of the user's own.
@immutable
class Exercise {
  const Exercise({
    required this.id,
    required this.names,
    required this.primary,
    this.secondary = const [],
    this.equipment = Equipment.other,
    this.custom = false,
  });

  final String id;

  /// The name per language code; 'en' is always there.
  final Map<String, String> names;
  final List<Muscle> primary;
  final List<Muscle> secondary;
  final Equipment equipment;
  final bool custom;

  /// The name in [language], or the English one.
  String name(String language) => names[language] ?? names['en'] ?? id;

  /// The main muscle, for the subtitle of a row.
  Muscle? get muscle => primary.isEmpty ? null : primary.first;

  Map<String, Object?> toJson() => {
    'id': id,
    'names': names,
    'primary': [for (final m in primary) m.name],
    'secondary': [for (final m in secondary) m.name],
    'equipment': equipment.name,
  };

  static Exercise? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final names = json['names'];
    if (id is! String || names is! Map) return null;
    List<Muscle> muscles(Object? list) => [
      if (list is List)
        for (final n in list) ?Muscle.byName(n is String ? n : null),
    ];
    return Exercise(
      id: id,
      names: {
        for (final e in names.entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      },
      primary: muscles(json['primary']),
      secondary: muscles(json['secondary']),
      equipment: Equipment.byName(json['equipment'] as String?),
      custom: true,
    );
  }
}

/// One set: what was lifted how often.
@immutable
class TrainingSet {
  const TrainingSet({
    this.kg,
    this.reps,
    this.kind = SetKind.working,
    this.rpe,
    this.rir,
    this.done = false,
  });

  final double? kg;
  final int? reps;
  final SetKind kind;

  /// How hard it was, 6 to 10, and how many reps were left in the tank.
  final double? rpe;
  final int? rir;
  final bool done;

  /// The weight moved: kilograms times reps, or nothing without either.
  double get volume => (kg ?? 0) * (reps ?? 0);

  TrainingSet copyWith({
    double? Function()? kg,
    int? Function()? reps,
    SetKind? kind,
    double? Function()? rpe,
    int? Function()? rir,
    bool? done,
  }) => TrainingSet(
    kg: kg == null ? this.kg : kg(),
    reps: reps == null ? this.reps : reps(),
    kind: kind ?? this.kind,
    rpe: rpe == null ? this.rpe : rpe(),
    rir: rir == null ? this.rir : rir(),
    done: done ?? this.done,
  );

  Map<String, Object?> toJson() => {
    'kg': ?kg,
    'reps': ?reps,
    'kind': kind.name,
    'rpe': ?rpe,
    'rir': ?rir,
    'done': done,
  };

  static TrainingSet fromJson(Object? json) {
    if (json is! Map) return const TrainingSet();
    return TrainingSet(
      kg: (json['kg'] as num?)?.toDouble(),
      reps: (json['reps'] as num?)?.toInt(),
      kind: SetKind.byName(json['kind'] as String?),
      rpe: (json['rpe'] as num?)?.toDouble(),
      rir: (json['rir'] as num?)?.toInt(),
      done: json['done'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TrainingSet &&
      other.kg == kg &&
      other.reps == reps &&
      other.kind == kind &&
      other.rpe == rpe &&
      other.rir == rir &&
      other.done == done;

  @override
  int get hashCode => Object.hash(kg, reps, kind, rpe, rir, done);
}

/// An exercise within a session, with its sets.
@immutable
class SessionExercise {
  const SessionExercise({
    required this.exerciseId,
    this.sets = const [],
    this.restSeconds = 120,
    this.targetReps,
  });

  final String exerciseId;
  final List<TrainingSet> sets;
  final int restSeconds;

  /// The reps the template asks for; reaching them in every set suggests
  /// more weight next time.
  final int? targetReps;

  SessionExercise copyWith({List<TrainingSet>? sets, int? restSeconds}) =>
      SessionExercise(
        exerciseId: exerciseId,
        sets: sets ?? this.sets,
        restSeconds: restSeconds ?? this.restSeconds,
        targetReps: targetReps,
      );

  Map<String, Object?> toJson() => {
    'exercise': exerciseId,
    'sets': [for (final s in sets) s.toJson()],
    'rest': restSeconds,
    'targetReps': ?targetReps,
  };

  static SessionExercise? fromJson(Object? json) {
    if (json is! Map || json['exercise'] is! String) return null;
    return SessionExercise(
      exerciseId: json['exercise'] as String,
      sets: [
        if (json['sets'] case final List sets)
          for (final s in sets) TrainingSet.fromJson(s),
      ],
      restSeconds: (json['rest'] as num?)?.toInt() ?? 120,
      targetReps: (json['targetReps'] as num?)?.toInt(),
    );
  }
}

/// A training: started, maybe finished, maybe linked to the workout a watch
/// recorded at the same time.
@immutable
class TrainingSession {
  const TrainingSession({
    required this.id,
    required this.name,
    required this.start,
    this.end,
    this.templateId,
    this.exercises = const [],
    this.linkedWorkout,
    this.unlinked = false,
  });

  final String id;
  final String name;
  final DateTime start;
  final DateTime? end;
  final String? templateId;
  final List<SessionExercise> exercises;

  /// The key of the Health Connect workout this session is linked to.
  final String? linkedWorkout;

  /// Set when the user took a link back: then none is made again.
  final bool unlinked;

  bool get finished => end != null;

  Duration get duration => (end ?? DateTime.now()).difference(start);

  /// The sets that were done and count.
  Iterable<TrainingSet> get countingSets => [
    for (final e in exercises)
      for (final s in e.sets)
        if (s.done && s.kind.counts) s,
  ];

  double get volume => countingSets.fold(0, (sum, s) => sum + s.volume);

  TrainingSession copyWith({
    String? name,
    DateTime? start,
    DateTime? Function()? end,
    List<SessionExercise>? exercises,
    String? Function()? linkedWorkout,
    bool? unlinked,
  }) => TrainingSession(
    id: id,
    name: name ?? this.name,
    start: start ?? this.start,
    end: end == null ? this.end : end(),
    templateId: templateId,
    exercises: exercises ?? this.exercises,
    linkedWorkout: linkedWorkout == null ? this.linkedWorkout : linkedWorkout(),
    unlinked: unlinked ?? this.unlinked,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'start': start.toIso8601String(),
    'end': ?end?.toIso8601String(),
    'template': ?templateId,
    'exercises': [for (final e in exercises) e.toJson()],
    'linked': ?linkedWorkout,
    if (unlinked) 'unlinked': true,
  };

  static TrainingSession? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final start = DateTime.tryParse(json['start'] as String? ?? '');
    if (id is! String || start == null) return null;
    return TrainingSession(
      id: id,
      name: json['name'] as String? ?? '',
      start: start,
      end: DateTime.tryParse(json['end'] as String? ?? ''),
      templateId: json['template'] as String?,
      exercises: [
        if (json['exercises'] case final List list)
          for (final e in list) ?SessionExercise.fromJson(e),
      ],
      linkedWorkout: json['linked'] as String?,
      unlinked: json['unlinked'] == true,
    );
  }
}

/// One exercise of a template: how many sets of how many reps.
@immutable
class TemplateExercise {
  const TemplateExercise({
    required this.exerciseId,
    this.sets = 3,
    this.reps = 8,
    this.restSeconds = 120,
  });

  final String exerciseId;
  final int sets;
  final int reps;
  final int restSeconds;

  Map<String, Object?> toJson() => {
    'exercise': exerciseId,
    'sets': sets,
    'reps': reps,
    'rest': restSeconds,
  };

  static TemplateExercise? fromJson(Object? json) {
    if (json is! Map || json['exercise'] is! String) return null;
    return TemplateExercise(
      exerciseId: json['exercise'] as String,
      sets: (json['sets'] as num?)?.toInt() ?? 3,
      reps: (json['reps'] as num?)?.toInt() ?? 8,
      restSeconds: (json['rest'] as num?)?.toInt() ?? 120,
    );
  }
}

/// A training the user does again and again, such as "Push A".
@immutable
class TrainingTemplate {
  const TrainingTemplate({
    required this.id,
    required this.name,
    this.exercises = const [],
  });

  final String id;
  final String name;
  final List<TemplateExercise> exercises;

  int get setCount => exercises.fold(0, (sum, e) => sum + e.sets);

  /// About how long it takes: a minute a set plus its rest.
  int get minutes =>
      exercises.fold(0, (sum, e) => sum + e.sets * (60 + e.restSeconds) ~/ 60);

  TrainingTemplate copyWith({
    String? name,
    List<TemplateExercise>? exercises,
  }) => TrainingTemplate(
    id: id,
    name: name ?? this.name,
    exercises: exercises ?? this.exercises,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'exercises': [for (final e in exercises) e.toJson()],
  };

  static TrainingTemplate? fromJson(Object? json) {
    if (json is! Map || json['id'] is! String) return null;
    return TrainingTemplate(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      exercises: [
        if (json['exercises'] case final List list)
          for (final e in list) ?TemplateExercise.fromJson(e),
      ],
    );
  }
}

/// Everything the training keeps: own exercises, templates in their
/// rotation, the weekly goal, the sessions and the one that runs.
@immutable
class TrainingData {
  const TrainingData({
    this.customExercises = const [],
    this.templates = const [],
    this.rotation = const [],
    this.weeklyGoal = 3,
    this.split,
    this.sessions = const [],
    this.active,
    this.restEndsAt,
  });

  final List<Exercise> customExercises;
  final List<TrainingTemplate> templates;

  /// Template ids in the order they come round.
  final List<String> rotation;
  final int weeklyGoal;

  /// The name of the split last chosen, of `TrainingSplit`; null when the
  /// plan is made by hand.
  final String? split;

  /// Finished sessions, oldest first.
  final List<TrainingSession> sessions;
  final TrainingSession? active;

  /// When the running rest ends.
  final DateTime? restEndsAt;

  TrainingTemplate? template(String? id) {
    for (final t in templates) {
      if (t.id == id) return t;
    }
    return null;
  }

  TrainingData copyWith({
    List<Exercise>? customExercises,
    List<TrainingTemplate>? templates,
    List<String>? rotation,
    int? weeklyGoal,
    String? Function()? split,
    List<TrainingSession>? sessions,
    TrainingSession? Function()? active,
    DateTime? Function()? restEndsAt,
  }) => TrainingData(
    customExercises: customExercises ?? this.customExercises,
    templates: templates ?? this.templates,
    rotation: rotation ?? this.rotation,
    weeklyGoal: weeklyGoal ?? this.weeklyGoal,
    split: split == null ? this.split : split(),
    sessions: sessions ?? this.sessions,
    active: active == null ? this.active : active(),
    restEndsAt: restEndsAt == null ? this.restEndsAt : restEndsAt(),
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'exercises': [for (final e in customExercises) e.toJson()],
    'templates': [for (final t in templates) t.toJson()],
    'rotation': rotation,
    'weeklyGoal': weeklyGoal,
    'split': ?split,
    'sessions': [for (final s in sessions) s.toJson()],
    'active': ?active?.toJson(),
    'restEndsAt': ?restEndsAt?.toIso8601String(),
  };

  /// What [json] holds; anything damaged in it is left out, and a file that
  /// is not training data at all gives an empty one.
  static TrainingData fromJson(Object? json) {
    if (json is! Map) return const TrainingData();
    final sessions = [
      if (json['sessions'] case final List list)
        for (final s in list) ?TrainingSession.fromJson(s),
    ]..sort((a, b) => a.start.compareTo(b.start));
    return TrainingData(
      customExercises: [
        if (json['exercises'] case final List list)
          for (final e in list) ?Exercise.fromJson(e),
      ],
      templates: [
        if (json['templates'] case final List list)
          for (final t in list) ?TrainingTemplate.fromJson(t),
      ],
      rotation: [
        if (json['rotation'] case final List list)
          for (final id in list)
            if (id is String) id,
      ],
      weeklyGoal: ((json['weeklyGoal'] as num?)?.toInt() ?? 3).clamp(1, 14),
      split: json['split'] as String?,
      sessions: sessions,
      active: TrainingSession.fromJson(json['active']),
      restEndsAt: DateTime.tryParse(json['restEndsAt'] as String? ?? ''),
    );
  }
}
