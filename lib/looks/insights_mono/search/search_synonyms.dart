import 'search_index.dart';

/// Words that mean the same to someone searching, across German, English
/// and Polish. Each line is one meaning; a search for one word finds what
/// is named by any other.
const List<List<String>> _groups = [
  ['puls', 'herzfrequenz', 'heart rate', 'pulse', 'tetno', 'bpm', 'hf'],
  ['ruhepuls', 'resting heart rate', 'tetno spoczynkowe', 'rhr'],
  ['hrv', 'herzratenvariabilitat', 'heart rate variability', 'zmiennosc'],
  ['schlaf', 'sleep', 'sen', 'nacht', 'night', 'noc', 'asleep'],
  ['schritte', 'steps', 'kroki', 'gehen', 'walk'],
  ['gewicht', 'weight', 'waga', 'kg', 'korpergewicht'],
  ['wasser', 'water', 'woda', 'trinken', 'drink'],
  ['kalorien', 'calories', 'kalorie', 'kcal', 'energie', 'energy', 'energia'],
  [
    'essen',
    'meal',
    'mahlzeit',
    'food',
    'posilek',
    'jedzenie',
    'nutrition',
    'ernahrung',
  ],
  ['eiweiss', 'protein', 'bialko'],
  ['kohlenhydrate', 'carbs', 'weglowodany', 'carbohydrates'],
  ['fett', 'fat', 'tluszcz'],
  ['blutdruck', 'blood pressure', 'cisnienie', 'systolic', 'diastolic'],
  ['sauerstoff', 'spo2', 'oxygen', 'tlen', 'blood oxygen'],
  ['atmung', 'atemfrequenz', 'respiratory', 'breathing', 'oddech'],
  ['erholung', 'recovery', 'regeneracja', 'readiness'],
  ['training', 'workout', 'trening', 'sport', 'gym', 'fitness'],
  [
    'split',
    'arnold',
    'trainingsplan',
    'plan',
    'ppl',
    'push pull',
    'ganzkorper',
    'full body',
    'upper lower',
  ],
  ['kraft', 'strength', 'sila', 'krafttraining', 'lifting', 'gewichte'],
  ['laufen', 'run', 'running', 'bieg', 'joggen', 'lauf'],
  ['rad', 'fahrrad', 'ride', 'cycling', 'bike', 'rower'],
  ['bank', 'bench', 'lawka', 'bankdrucken', 'bench press', 'wyciskanie'],
  ['kniebeuge', 'squat', 'przysiad'],
  ['kreuzheben', 'deadlift', 'martwy ciag'],
  ['klimmzug', 'pull-up', 'pull up', 'chin-up', 'podciaganie'],
  ['schulter', 'shoulder', 'bark', 'barki'],
  ['brust', 'chest', 'klatka'],
  ['rucken', 'back', 'plecy'],
  ['beine', 'legs', 'nogi', 'leg'],
  ['bizeps', 'biceps', 'biceps'],
  ['trizeps', 'triceps', 'triceps'],
  ['bauch', 'abs', 'core', 'brzuch'],
  ['po', 'glutes', 'gesass', 'posladki'],
  ['wade', 'calves', 'calf', 'lydki'],
  [
    'nahrungserganzung',
    'supplement',
    'suplement',
    'vitamin',
    'witamina',
    'pille',
    'pill',
  ],
  ['tag', 'day', 'dzien', 'tagesscore', 'day score', 'score', 'wynik'],
  ['einstellung', 'settings', 'setting', 'ustawienia', 'profil', 'profile'],
  ['korperalter', 'body age', 'wiek', 'alter', 'age', 'longevity'],
  ['vo2', 'vo2 max', 'fitness level', 'ausdauer'],
  ['temperatur', 'temperature', 'temperatura', 'fieber'],
  ['zucker', 'sugar', 'cukier', 'glucose', 'blutzucker', 'glukoza'],
];

/// The other words of every meaning that [query] (already normalised) is
/// a beginning of, or holds. Nothing for less than three letters: "b" would
/// mean everything.
List<String> synonymsOf(String query) {
  if (query.length < 3) return const [];
  final out = <String>{};
  for (final group in _normalized) {
    final hit = group.any(
      (w) => w.startsWith(query) || (w.length >= 3 && query.contains(w)),
    );
    if (hit) out.addAll(group.where((w) => w.length >= 3));
  }
  out.remove(query);
  return out.toList();
}

final List<List<String>> _normalized = [
  for (final g in _groups) [for (final w in g) normalizeSearch(w)],
];
