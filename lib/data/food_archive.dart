import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'json_store.dart';
import 'models.dart';

/// One time a food was eaten.
typedef Eating = ({DateTime at, bool own});

/// A food the user has logged before: every meal of one name, with the
/// values of the last time.
@immutable
class Food {
  const Food({
    required this.name,
    required this.kcal,
    required this.eaten,
    this.carbs,
    this.protein,
    this.fat,
    this.fiber,
    this.sugar,
    this.hiddenAt,
  });

  /// As written the last time.
  final String name;
  final double kcal;
  final double? carbs;
  final double? protein;
  final double? fat;
  final double? fiber;
  final double? sugar;

  /// Oldest first, never empty.
  final List<Eating> eaten;

  /// When the user took it out of the suggestions. It is back once it is
  /// eaten again.
  final DateTime? hiddenAt;

  String get key => foodKey(name);

  DateTime get last => eaten.last.at;

  bool get hidden => hiddenAt != null && !last.isAfter(hiddenAt!);

  /// Whether this app wrote any of its meals.
  bool get own => eaten.any((eating) => eating.own);

  /// How often it was eaten in the [days] before [now].
  int timesSince(DateTime now, int days) {
    final from = now.subtract(Duration(days: days));
    return eaten.where((eating) => eating.at.isAfter(from)).length;
  }

  /// At least 20 g of protein, or a quarter of its energy from protein.
  bool get proteinRich {
    final grams = protein;
    if (grams == null) return false;
    return grams >= 20 || (kcal > 0 && grams * 4 / kcal >= 0.25);
  }

  FoodEnergy get energy => kcal < 300
      ? FoodEnergy.low
      : kcal <= 600
      ? FoodEnergy.middle
      : FoodEnergy.high;

  /// The time of day it was eaten most often; the earlier one on a tie.
  FoodDaytime get daytime {
    final counts = {for (final daytime in FoodDaytime.values) daytime: 0};
    for (final eating in eaten) {
      final daytime = FoodDaytime.of(eating.at);
      counts[daytime] = counts[daytime]! + 1;
    }
    var most = FoodDaytime.morning;
    for (final daytime in FoodDaytime.values) {
      if (counts[daytime]! > counts[most]!) most = daytime;
    }
    return most;
  }

  /// A meal like the last one of this food, eaten at [time].
  EntryDraft draftAt(DateTime time) => EntryDraft(
    kind: EntryKind.meal,
    time: time,
    amount: kcal,
    name: name,
    carbs: carbs,
    protein: protein,
    fat: fat,
    fiber: fiber,
    sugar: sugar,
  );

  Food _with({List<Eating>? eaten, EntryDraft? values, DateTime? hiddenAt}) =>
      Food(
        name: values?.name?.trim() ?? name,
        kcal: values?.amount ?? kcal,
        carbs: values == null ? carbs : values.carbs,
        protein: values == null ? protein : values.protein,
        fat: values == null ? fat : values.fat,
        fiber: values == null ? fiber : values.fiber,
        sugar: values == null ? sugar : values.sugar,
        eaten: eaten ?? this.eaten,
        hiddenAt: hiddenAt ?? this.hiddenAt,
      );

  Map<String, Object?> toJson() => {
    'name': name,
    'kcal': kcal,
    'carbs': ?carbs,
    'protein': ?protein,
    'fat': ?fat,
    'fiber': ?fiber,
    'sugar': ?sugar,
    'eaten': [
      for (final eating in eaten)
        // Negative for a meal another app wrote.
        eating.own
            ? eating.at.millisecondsSinceEpoch
            : -eating.at.millisecondsSinceEpoch,
    ],
    'hiddenAt': ?hiddenAt?.toIso8601String(),
  };

  static Food? fromJson(Object? json) {
    if (json
        case {
          'name': final String name,
          'kcal': final num kcal,
          'eaten': final List<Object?> eaten,
        }
        when name.trim().isNotEmpty && kcal.isFinite) {
      double? grams(String field) => switch (json[field]) {
        final num value when value.isFinite => value.toDouble(),
        _ => null,
      };
      final times = <Eating>[
        for (final time in eaten)
          if (time is int && time != 0)
            (
              at: DateTime.fromMillisecondsSinceEpoch(time.abs()),
              own: time > 0,
            ),
      ]..sort((a, b) => a.at.compareTo(b.at));
      if (times.isEmpty) return null;
      return Food(
        name: name,
        kcal: kcal.toDouble(),
        carbs: grams('carbs'),
        protein: grams('protein'),
        fat: grams('fat'),
        fiber: grams('fiber'),
        sugar: grams('sugar'),
        eaten: times,
        hiddenAt: switch (json['hiddenAt']) {
          final String text => DateTime.tryParse(text),
          _ => null,
        },
      );
    }
    return null;
  }
}

/// What makes two meals the same food: their name, whatever its case.
String foodKey(String name) => name.trim().toLowerCase();

enum FoodDaytime {
  morning,
  midday,
  evening;

  /// Before 11, from 11 to 16, and after.
  static FoodDaytime of(DateTime time) => time.hour < 11
      ? morning
      : time.hour < 16
      ? midday
      : evening;
}

/// Below 300 kcal, up to 600, and above.
enum FoodEnergy { low, middle, high }

enum FoodSort { recent, frequent, name, kcal }

/// The days the most frequent foods are counted over.
const int foodRecentDays = 90;

/// How many foods the sheet suggests.
const int foodSuggestions = 5;

/// The foods eaten most often in the [foodRecentDays] before [now], the
/// more recent one first where two were eaten as often.
List<Food> topFoods(List<Food> foods, DateTime now) {
  final counts = {
    for (final food in foods)
      if (!food.hidden) food: food.timesSince(now, foodRecentDays),
  };
  final shown = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : b.last.compareTo(a.last);
    });
  return shown.length <= foodSuggestions
      ? shown
      : shown.sublist(0, foodSuggestions);
}

/// The foods that are not hidden and pass every filter given, in [sort]'s
/// order.
List<Food> findFoods(
  List<Food> foods, {
  String query = '',
  FoodSort sort = FoodSort.recent,
  FoodDaytime? daytime,
  FoodEnergy? energy,
  bool proteinRich = false,
  bool ownOnly = false,
}) {
  final wanted = foodKey(query);
  final found = [
    for (final food in foods)
      if (!food.hidden &&
          (wanted.isEmpty || food.key.contains(wanted)) &&
          (daytime == null || food.daytime == daytime) &&
          (energy == null || food.energy == energy) &&
          (!proteinRich || food.proteinRich) &&
          (!ownOnly || food.own))
        food,
  ];
  int byName(Food a, Food b) => a.key.compareTo(b.key);
  found.sort(switch (sort) {
    FoodSort.recent => (a, b) => b.last.compareTo(a.last),
    FoodSort.frequent => (a, b) {
      final byCount = b.eaten.length.compareTo(a.eaten.length);
      return byCount != 0 ? byCount : b.last.compareTo(a.last);
    },
    FoodSort.name => byName,
    FoodSort.kcal => (a, b) {
      final byKcal = a.kcal.compareTo(b.kcal);
      return byKcal != 0 ? byKcal : byName(a, b);
    },
  });
  return found;
}

/// [stored] with the [meals] read merged in, or null when that changes
/// nothing. Meals without a name are no food. With a [window], the read
/// covers that time in full: what was eaten in it and is not among [meals]
/// was deleted or renamed where it came from, and goes.
List<Food>? mergeFoods(
  List<Food> stored,
  Iterable<HealthEntry> meals, {
  (DateTime, DateTime)? window,
}) {
  final byKey = <String, Food>{};
  for (final food in stored) {
    var eaten = food.eaten;
    if (window case (final from, final to)) {
      eaten = [
        for (final eating in eaten)
          if (eating.at.isBefore(from) || eating.at.isAfter(to)) eating,
      ];
    }
    // Kept without a time for now, so a food eaten in the window only
    // does not lose when it was hidden.
    byKey[food.key] = food._with(eaten: eaten);
  }
  for (final meal in meals) {
    final draft = meal.draft;
    final name = draft.name?.trim() ?? '';
    if (draft.kind != EntryKind.meal || name.isEmpty) continue;
    final key = foodKey(name);
    final Eating eating = (at: draft.time, own: meal.isOwn);
    final old = byKey[key];
    if (old == null) {
      byKey[key] = Food(
        name: name,
        kcal: draft.amount,
        carbs: draft.carbs,
        protein: draft.protein,
        fat: draft.fat,
        fiber: draft.fiber,
        sugar: draft.sugar,
        eaten: [eating],
      );
      continue;
    }
    if (old.eaten.any((other) => other.at == eating.at)) continue;
    final latest = old.eaten.isEmpty || !eating.at.isBefore(old.eaten.last.at);
    byKey[key] = old._with(
      eaten: [...old.eaten, eating]..sort((a, b) => a.at.compareTo(b.at)),
      values: latest ? draft : null,
    );
  }
  final merged = [
    for (final food in byKey.values)
      if (food.eaten.isNotEmpty) food,
  ]..sort((a, b) => a.key.compareTo(b.key));
  String text(List<Food> foods) =>
      jsonEncode([for (final food in foods) food.toJson()]);
  final before = [...stored]..sort((a, b) => a.key.compareTo(b.key));
  return text(merged) == text(before) ? null : merged;
}

/// Keeps every named meal the app has seen, as the foods they were: the
/// store's window only reaches back a month, and a food eaten once a
/// season should still be offered.
class FoodArchive {
  const FoodArchive(this._store);

  final JsonStore _store;

  static const int schemaVersion = 1;

  /// By name. Anything that is not a valid food is skipped.
  Future<List<Food>> load() async {
    final json = await _store.read(StoreKeys.foods);
    if (json case {
      'version': schemaVersion,
      'foods': final List<Object?> all,
    }) {
      return [for (final food in all) ?Food.fromJson(food)];
    }
    return const [];
  }

  Future<void> _write(List<Food> foods) => _store.write(StoreKeys.foods, {
    'version': schemaVersion,
    'foods': [for (final food in foods) food.toJson()],
  });

  /// Merges [meals] into what is stored and returns all of it; see
  /// [mergeFoods] for the [window].
  Future<List<Food>> mergeIntoStore(
    Iterable<HealthEntry> meals, {
    (DateTime, DateTime)? window,
  }) async {
    final stored = await load();
    final merged = mergeFoods(stored, meals, window: window);
    if (merged == null) return stored;
    await _write(merged);
    return merged;
  }

  /// Takes the food named [key] out of the suggestions at [now], or with
  /// [hidden] false puts it back. Returns all foods.
  Future<List<Food>> setHidden(
    String key,
    DateTime now, {
    bool hidden = true,
  }) async {
    final foods = [
      for (final food in await load())
        if (food.key != key)
          food
        else
          Food(
            name: food.name,
            kcal: food.kcal,
            carbs: food.carbs,
            protein: food.protein,
            fat: food.fat,
            fiber: food.fiber,
            sugar: food.sugar,
            eaten: food.eaten,
            hiddenAt: hidden ? now : null,
          ),
    ];
    await _write(foods);
    return foods;
  }
}
