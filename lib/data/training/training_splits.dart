import 'training_models.dart';

/// A way to split the week: its templates in the order they come round
/// and how many trainings a week it is made for.
enum TrainingSplit {
  /// Push, pull, legs.
  pushPullLegs(3, _ppl),

  /// The split Arnold Schwarzenegger trained with: chest and back,
  /// shoulders and arms, legs; each twice a week.
  arnold(6, _arnold),

  /// Upper body and lower body in turn.
  upperLower(4, _upperLower),

  /// Two full-body days in turn.
  fullBody(3, _fullBody);

  const TrainingSplit(this.weeklyGoal, this.days);

  final int weeklyGoal;

  /// The key of each template, which names it, with its exercises.
  final List<(String, List<TemplateExercise>)> days;

  /// The marker in the ids of the templates of this split.
  String idOf(String key) => '~$name.$key';

  /// Whether [id] is the template [key] of this split, also as the first
  /// version of the app made the push, pull and legs ones.
  bool owns(String id, String key) =>
      id.endsWith(idOf(key)) ||
      (this == pushPullLegs && RegExp('^t[0-9a-z]+$key\$').hasMatch(id));
}

const _ppl = <(String, List<TemplateExercise>)>[
  (
    'push',
    [
      TemplateExercise(
        exerciseId: 'benchPress',
        sets: 4,
        reps: 6,
        restSeconds: 150,
      ),
      TemplateExercise(
        exerciseId: 'overheadPress',
        sets: 3,
        reps: 8,
        restSeconds: 120,
      ),
      TemplateExercise(
        exerciseId: 'inclineDumbbellPress',
        sets: 3,
        reps: 10,
        restSeconds: 90,
      ),
      TemplateExercise(
        exerciseId: 'lateralRaise',
        sets: 3,
        reps: 12,
        restSeconds: 60,
      ),
      TemplateExercise(
        exerciseId: 'tricepsPushdown',
        sets: 3,
        reps: 12,
        restSeconds: 60,
      ),
    ],
  ),
  (
    'pull',
    [
      TemplateExercise(
        exerciseId: 'deadlift',
        sets: 3,
        reps: 5,
        restSeconds: 180,
      ),
      TemplateExercise(
        exerciseId: 'pullUp',
        sets: 4,
        reps: 8,
        restSeconds: 120,
      ),
      TemplateExercise(
        exerciseId: 'barbellRow',
        sets: 3,
        reps: 8,
        restSeconds: 120,
      ),
      TemplateExercise(
        exerciseId: 'facePull',
        sets: 3,
        reps: 15,
        restSeconds: 60,
      ),
      TemplateExercise(
        exerciseId: 'hammerCurl',
        sets: 3,
        reps: 12,
        restSeconds: 60,
      ),
    ],
  ),
  (
    'legs',
    [
      TemplateExercise(exerciseId: 'squat', sets: 4, reps: 6, restSeconds: 180),
      TemplateExercise(
        exerciseId: 'romanianDeadlift',
        sets: 3,
        reps: 8,
        restSeconds: 120,
      ),
      TemplateExercise(
        exerciseId: 'legPress',
        sets: 3,
        reps: 10,
        restSeconds: 120,
      ),
      TemplateExercise(
        exerciseId: 'lyingLegCurl',
        sets: 3,
        reps: 12,
        restSeconds: 60,
      ),
      TemplateExercise(
        exerciseId: 'standingCalfRaise',
        sets: 4,
        reps: 12,
        restSeconds: 60,
      ),
    ],
  ),
];

const _arnold = <(String, List<TemplateExercise>)>[
  (
    'chestBack',
    [
      TemplateExercise(
        exerciseId: 'benchPress',
        sets: 4,
        reps: 8,
        restSeconds: 150,
      ),
      TemplateExercise(
        exerciseId: 'pullUp',
        sets: 4,
        reps: 8,
        restSeconds: 120,
      ),
      TemplateExercise(
        exerciseId: 'inclineBenchPress',
        sets: 3,
        reps: 10,
        restSeconds: 120,
      ),
      TemplateExercise(
        exerciseId: 'barbellRow',
        sets: 3,
        reps: 10,
        restSeconds: 120,
      ),
      TemplateExercise(
        exerciseId: 'dumbbellFly',
        sets: 3,
        reps: 12,
        restSeconds: 60,
      ),
      TemplateExercise(
        exerciseId: 'pullover',
        sets: 3,
        reps: 12,
        restSeconds: 60,
      ),
    ],
  ),
  (
    'shouldersArms',
    [
      TemplateExercise(
        exerciseId: 'overheadPress',
        sets: 4,
        reps: 8,
        restSeconds: 120,
      ),
      TemplateExercise(
        exerciseId: 'arnoldPress',
        sets: 3,
        reps: 10,
        restSeconds: 90,
      ),
      TemplateExercise(
        exerciseId: 'lateralRaise',
        sets: 3,
        reps: 12,
        restSeconds: 60,
      ),
      TemplateExercise(
        exerciseId: 'barbellCurl',
        sets: 3,
        reps: 10,
        restSeconds: 60,
      ),
      TemplateExercise(
        exerciseId: 'closeGripBenchPress',
        sets: 3,
        reps: 10,
        restSeconds: 90,
      ),
      TemplateExercise(
        exerciseId: 'dumbbellCurl',
        sets: 3,
        reps: 12,
        restSeconds: 60,
      ),
      TemplateExercise(
        exerciseId: 'overheadTricepsExtension',
        sets: 3,
        reps: 12,
        restSeconds: 60,
      ),
    ],
  ),
  (
    'legs',
    [
      TemplateExercise(exerciseId: 'squat', sets: 4, reps: 8, restSeconds: 180),
      TemplateExercise(exerciseId: 'lunge', sets: 3, reps: 10, restSeconds: 90),
      TemplateExercise(
        exerciseId: 'legExtension',
        sets: 3,
        reps: 12,
        restSeconds: 60,
      ),
      TemplateExercise(
        exerciseId: 'lyingLegCurl',
        sets: 3,
        reps: 12,
        restSeconds: 60,
      ),
      TemplateExercise(
        exerciseId: 'standingCalfRaise',
        sets: 4,
        reps: 15,
        restSeconds: 60,
      ),
      TemplateExercise(
        exerciseId: 'crunch',
        sets: 3,
        reps: 20,
        restSeconds: 45,
      ),
    ],
  ),
];

const _upperLower = <(String, List<TemplateExercise>)>[
  (
    'upper',
    [
      TemplateExercise(
        exerciseId: 'benchPress',
        sets: 4,
        reps: 6,
        restSeconds: 150,
      ),
      TemplateExercise(
        exerciseId: 'barbellRow',
        sets: 4,
        reps: 8,
        restSeconds: 120,
      ),
      TemplateExercise(
        exerciseId: 'overheadPress',
        sets: 3,
        reps: 8,
        restSeconds: 120,
      ),
      TemplateExercise(
        exerciseId: 'latPulldown',
        sets: 3,
        reps: 10,
        restSeconds: 90,
      ),
      TemplateExercise(
        exerciseId: 'dumbbellCurl',
        sets: 2,
        reps: 12,
        restSeconds: 60,
      ),
      TemplateExercise(
        exerciseId: 'tricepsPushdown',
        sets: 2,
        reps: 12,
        restSeconds: 60,
      ),
    ],
  ),
  (
    'lower',
    [
      TemplateExercise(exerciseId: 'squat', sets: 4, reps: 6, restSeconds: 180),
      TemplateExercise(
        exerciseId: 'romanianDeadlift',
        sets: 3,
        reps: 8,
        restSeconds: 120,
      ),
      TemplateExercise(
        exerciseId: 'legPress',
        sets: 3,
        reps: 10,
        restSeconds: 120,
      ),
      TemplateExercise(
        exerciseId: 'seatedLegCurl',
        sets: 3,
        reps: 12,
        restSeconds: 60,
      ),
      TemplateExercise(
        exerciseId: 'standingCalfRaise',
        sets: 4,
        reps: 12,
        restSeconds: 60,
      ),
    ],
  ),
];

const _fullBody = <(String, List<TemplateExercise>)>[
  (
    'fullA',
    [
      TemplateExercise(exerciseId: 'squat', sets: 3, reps: 6, restSeconds: 180),
      TemplateExercise(
        exerciseId: 'benchPress',
        sets: 3,
        reps: 6,
        restSeconds: 150,
      ),
      TemplateExercise(
        exerciseId: 'barbellRow',
        sets: 3,
        reps: 8,
        restSeconds: 120,
      ),
      TemplateExercise(
        exerciseId: 'lateralRaise',
        sets: 2,
        reps: 12,
        restSeconds: 60,
      ),
      TemplateExercise(
        exerciseId: 'hangingLegRaise',
        sets: 3,
        reps: 12,
        restSeconds: 45,
      ),
    ],
  ),
  (
    'fullB',
    [
      TemplateExercise(
        exerciseId: 'deadlift',
        sets: 3,
        reps: 5,
        restSeconds: 180,
      ),
      TemplateExercise(
        exerciseId: 'overheadPress',
        sets: 3,
        reps: 8,
        restSeconds: 120,
      ),
      TemplateExercise(
        exerciseId: 'pullUp',
        sets: 3,
        reps: 8,
        restSeconds: 120,
      ),
      TemplateExercise(
        exerciseId: 'bulgarianSplitSquat',
        sets: 2,
        reps: 10,
        restSeconds: 90,
      ),
      TemplateExercise(
        exerciseId: 'hammerCurl',
        sets: 2,
        reps: 12,
        restSeconds: 60,
      ),
    ],
  ),
];
