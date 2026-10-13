import '../../app/formatters.dart';
import '../../data/supplements.dart';
import '../../l10n/generated/app_localizations.dart';

/// The name of the preset called [id] in the app's language.
String? presetName(AppLocalizations l10n, String? id) => switch (id) {
  'creatine' => l10n.supplementCreatineName,
  'protein' => l10n.supplementProteinName,
  'omega3' => l10n.supplementOmega3Name,
  'vitaminD' => l10n.supplementVitaminDName,
  'magnesium' => l10n.supplementMagnesiumName,
  'multivitamin' => l10n.supplementMultivitaminName,
  'vitaminC' => l10n.supplementVitaminCName,
  'vitaminB12' => l10n.supplementVitaminB12Name,
  'vitaminK2' => l10n.supplementVitaminK2Name,
  'zinc' => l10n.supplementZincName,
  'iron' => l10n.supplementIronName,
  'calcium' => l10n.supplementCalciumName,
  'folicAcid' => l10n.supplementFolicAcidName,
  'biotin' => l10n.supplementBiotinName,
  'ashwagandha' => l10n.supplementAshwagandhaName,
  'rhodiola' => l10n.supplementRhodiolaName,
  'ginseng' => l10n.supplementGinsengName,
  'melatonin' => l10n.supplementMelatoninName,
  'theanine' => l10n.supplementTheanineName,
  'glycine' => l10n.supplementGlycineName,
  'caffeine' => l10n.supplementCaffeineName,
  'preWorkout' => l10n.supplementPreWorkoutName,
  'bcaa' => l10n.supplementBcaaName,
  'eaa' => l10n.supplementEaaName,
  'glutamine' => l10n.supplementGlutamineName,
  'betaAlanine' => l10n.supplementBetaAlanineName,
  'citrulline' => l10n.supplementCitrullineName,
  'carnitine' => l10n.supplementCarnitineName,
  'taurine' => l10n.supplementTaurineName,
  'collagen' => l10n.supplementCollagenName,
  'electrolytes' => l10n.supplementElectrolytesName,
  'probiotics' => l10n.supplementProbioticsName,
  'psyllium' => l10n.supplementPsylliumName,
  'curcumin' => l10n.supplementCurcuminName,
  'coenzymeQ10' => l10n.supplementCoenzymeQ10Name,
  'coffee' => l10n.supplementCoffeeName,
  'espresso' => l10n.supplementEspressoName,
  'energyDrink' => l10n.supplementEnergyDrinkName,
  _ => null,
};

extension SupplementText on Supplement {
  /// Its own name, or the preset's in the app's language.
  String title(AppLocalizations l10n) =>
      name ?? presetName(l10n, preset) ?? key;
}

extension SupplementUnitText on SupplementUnit {
  /// The unit as it stands after [count]: "Kapsel", "Kapseln", "mg".
  String label(AppLocalizations l10n, [num count = 2]) => switch (this) {
    SupplementUnit.capsule => l10n.unitCapsule(count),
    SupplementUnit.tablet => l10n.unitTablet(count),
    SupplementUnit.scoop => l10n.unitScoop(count),
    SupplementUnit.drop => l10n.unitDrop(count),
    SupplementUnit.piece => l10n.unitPiece(count),
    SupplementUnit.gram => l10n.unitGram,
    SupplementUnit.milligram => l10n.unitMilligram,
    SupplementUnit.millilitre => l10n.unitMillilitre,
    SupplementUnit.iu => l10n.unitIu,
  };
}

extension SupplementTimeText on SupplementTime {
  String label(AppLocalizations l10n) => switch (this) {
    SupplementTime.any => l10n.supplementTimeAny,
    SupplementTime.morning => l10n.supplementTimeMorning,
    SupplementTime.noon => l10n.supplementTimeNoon,
    SupplementTime.evening => l10n.supplementTimeEvening,
  };
}

/// 2 becomes "2", 0.5 becomes "0,5".
String amountText(Formats formats, double amount) =>
    amount == amount.roundToDouble()
    ? formats.integer(amount.round())
    : formats.decimal(
        amount,
        digits: amount * 10 == (amount * 10).round() ? 1 : 2,
      );

/// "2 Kapseln", "5 g", or null where no amount is set. An amount without a
/// unit is the bare number.
String? doseText(Formats formats, double? amount, SupplementUnit? unit) {
  if (amount == null) return null;
  final number = amountText(formats, amount);
  return unit == null ? number : '$number ${unit.label(formats.l10n, amount)}';
}

/// "14:05".
String clockOf(DateTime time) => formatClock(time.hour * 60 + time.minute);
