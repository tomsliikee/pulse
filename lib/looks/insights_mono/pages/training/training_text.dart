import '../../../../app/formatters.dart';
import '../../../../data/training/training_insights.dart';
import '../../../../data/training/training_models.dart';
import '../../../../data/training/training_splits.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// The name of a muscle group.
String muscleLabel(AppLocalizations l10n, Muscle m) => switch (m) {
  Muscle.chest => l10n.muscleChest,
  Muscle.shoulders => l10n.muscleShoulders,
  Muscle.biceps => l10n.muscleBiceps,
  Muscle.triceps => l10n.muscleTriceps,
  Muscle.forearms => l10n.muscleForearms,
  Muscle.abs => l10n.muscleAbs,
  Muscle.obliques => l10n.muscleObliques,
  Muscle.quads => l10n.muscleQuads,
  Muscle.adductors => l10n.muscleAdductors,
  Muscle.traps => l10n.muscleTraps,
  Muscle.upperBack => l10n.muscleUpperBack,
  Muscle.lats => l10n.muscleLats,
  Muscle.lowerBack => l10n.muscleLowerBack,
  Muscle.glutes => l10n.muscleGlutes,
  Muscle.hamstrings => l10n.muscleHamstrings,
  Muscle.calves => l10n.muscleCalves,
};

String equipmentLabel(AppLocalizations l10n, Equipment e) => switch (e) {
  Equipment.barbell => l10n.equipBarbell,
  Equipment.dumbbell => l10n.equipDumbbell,
  Equipment.machine => l10n.equipMachine,
  Equipment.cable => l10n.equipCable,
  Equipment.bodyweight => l10n.equipBodyweight,
  Equipment.kettlebell => l10n.equipKettlebell,
  Equipment.band => l10n.equipBand,
  Equipment.other => l10n.equipOther,
};

/// The short mark of a set kind in the set list: W, D, F, or the number.
String setKindMark(AppLocalizations l10n, SetKind k) => switch (k) {
  SetKind.warmup => l10n.setWarmupMark,
  SetKind.working => '',
  SetKind.drop => l10n.setDropMark,
  SetKind.failure => l10n.setFailureMark,
};

String setKindLabel(AppLocalizations l10n, SetKind k) => switch (k) {
  SetKind.warmup => l10n.setWarmup,
  SetKind.working => l10n.setWorking,
  SetKind.drop => l10n.setDrop,
  SetKind.failure => l10n.setFailure,
};

/// A weight in kilograms with as few digits as it needs: "80", "82.5".
String kgText(Formats formats, double kg) => kg == kg.roundToDouble()
    ? formats.integer(kg.round())
    : formats.decimal(kg, digits: kg * 10 == (kg * 10).roundToDouble() ? 1 : 2);

/// "80 kg × 8", "× 12" without a weight, "80 kg" without reps.
String setText(Formats formats, TrainingSet s) {
  final kg = s.kg;
  final reps = s.reps;
  if (kg != null && kg > 0 && reps != null) {
    return '${kgText(formats, kg)} kg × ${formats.integer(reps)}';
  }
  if (reps != null) return '× ${formats.integer(reps)}';
  if (kg != null) return '${kgText(formats, kg)} kg';
  return '–';
}

/// "1:05:12" or "4:07" for a running time.
String clockText(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

/// What kind of record it is, as a word.
String recordKindLabel(AppLocalizations l10n, RecordKind kind) =>
    switch (kind) {
      RecordKind.oneRepMax => l10n.trainingOneRepMax,
      RecordKind.heaviest => l10n.trainingHeaviest,
      RecordKind.volume => l10n.trainingVolumeBest,
    };

/// The name of a split and what it is.
(String, String) splitText(AppLocalizations l10n, TrainingSplit s) =>
    switch (s) {
      TrainingSplit.pushPullLegs => (
        l10n.splitPushPullLegs,
        l10n.splitPushPullLegsNote,
      ),
      TrainingSplit.arnold => (l10n.splitArnold, l10n.splitArnoldNote),
      TrainingSplit.upperLower => (
        l10n.splitUpperLower,
        l10n.splitUpperLowerNote,
      ),
      TrainingSplit.fullBody => (l10n.splitFullBody, l10n.splitFullBodyNote),
    };

/// The names of the templates of the splits, by key.
Map<String, String> splitTemplateNames(AppLocalizations l10n) => {
  'push': l10n.trainingStarterPush,
  'pull': l10n.trainingStarterPull,
  'legs': l10n.trainingStarterLegs,
  'chestBack': l10n.trainingStarterChestBack,
  'shouldersArms': l10n.trainingStarterShouldersArms,
  'upper': l10n.trainingStarterUpper,
  'lower': l10n.trainingStarterLower,
  'fullA': l10n.trainingStarterFullA,
  'fullB': l10n.trainingStarterFullB,
};
