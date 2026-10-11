import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/food_archive.dart';
import 'package:pulse/data/health_controller.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/models.dart';

import 'support/fixtures.dart';

var _id = 0;

HealthEntry _meal(
  String? name,
  DateTime time, {
  double kcal = 500,
  double? protein,
  bool own = true,
}) => HealthEntry(
  id: 'meal-${_id++}',
  source: own ? 'at.haiden.pulse' : 'com.other',
  isOwn: own,
  draft: EntryDraft(
    kind: EntryKind.meal,
    time: time,
    amount: kcal,
    name: name,
    protein: protein,
  ),
);

final _now = DateTime(2026, 10, 11, 12);
DateTime _ago(int days, [int hour = 12]) => DateTime(2026, 10, 11 - days, hour);

void main() {
  group('mergeFoods', () {
    test('meals of one name are one food, whatever the case, with the values '
        'of the last time', () {
      final foods = mergeFoods(const [], [
        _meal('Porridge', _ago(3, 8), kcal: 400, protein: 12),
        _meal(' porridge ', _ago(1, 8), kcal: 450, protein: 15),
        _meal('PORRIDGE', _ago(2, 8), kcal: 420),
        _meal('Pasta', _ago(1, 19), kcal: 700),
      ])!;
      expect(foods.map((food) => food.key), ['pasta', 'porridge']);
      final porridge = foods.last;
      expect(porridge.name, 'porridge');
      expect(porridge.kcal, 450);
      expect(porridge.protein, 15);
      expect(porridge.eaten, hasLength(3));
      expect(porridge.last, _ago(1, 8));
    });

    test('meals without a name are no food', () {
      expect(
        mergeFoods(const [], [_meal(null, _ago(1)), _meal('  ', _ago(2))]),
        isNull,
      );
    });

    test('the same meal read again changes nothing', () {
      final meals = [_meal('Pasta', _ago(1)), _meal('Pasta', _ago(4))];
      final foods = mergeFoods(const [], meals)!;
      expect(mergeFoods(foods, meals), isNull);
      expect(mergeFoods(foods, meals, window: (_ago(10), _now)), isNull);
    });

    test('a meal gone from the window read in full goes, an older one '
        'stays', () {
      final foods = mergeFoods(const [], [
        _meal('Pasta', _ago(40)),
        _meal('Pasta', _ago(2)),
        _meal('Salat', _ago(3)),
      ])!;
      final after = mergeFoods(foods, const [], window: (_ago(10), _now))!;
      expect(after.single.key, 'pasta');
      expect(after.single.eaten.single.at, _ago(40));
    });

    test('a food survives being written and read', () {
      final food = mergeFoods(const [], [
        _meal('Pasta', _ago(2), protein: 22.5),
        _meal('Pasta', _ago(1), own: false),
      ])!.single;
      final read = Food.fromJson(food.toJson())!;
      expect(read.toJson(), food.toJson());
      expect(read.eaten.map((eating) => eating.own), [true, false]);
      expect(
        Food.fromJson({'name': 'x', 'kcal': 1, 'eaten': <Object?>[]}),
        isNull,
      );
    });
  });

  group('topFoods', () {
    test('the five eaten most often in the last 90 days, the later one '
        'first on a tie, meals of other apps counted', () {
      final foods = mergeFoods(const [], [
        for (var i = 0; i < 4; i++) _meal('A', _ago(i + 1)),
        for (var i = 0; i < 2; i++) _meal('B', _ago(i + 5), own: false),
        for (var i = 0; i < 2; i++) _meal('C', _ago(i + 1)),
        // Often, but long ago.
        for (var i = 0; i < 9; i++) _meal('Old', _ago(100 + i)),
        _meal('D', _ago(2)),
        _meal('E', _ago(3)),
        _meal('F', _ago(4)),
      ])!;
      expect(topFoods(foods, _now).map((food) => food.name), [
        'A',
        'C',
        'B',
        'D',
        'E',
      ]);
    });
  });

  group('findFoods', () {
    final foods = mergeFoods(const [], [
      _meal('Porridge', _ago(3, 8), kcal: 400, protein: 12),
      _meal('Porridge', _ago(2, 8), kcal: 400, protein: 12),
      _meal('Pasta', _ago(1, 19), kcal: 700, protein: 25),
      _meal('Skyr', _ago(4, 15), kcal: 150, protein: 17, own: false),
      _meal('Apfel', _ago(5, 10), kcal: 80),
    ])!;
    List<String> names(List<Food> found) => [
      for (final food in found) food.name,
    ];

    test('sorts by time, count, name and energy', () {
      expect(names(findFoods(foods)), ['Pasta', 'Porridge', 'Skyr', 'Apfel']);
      expect(
        names(findFoods(foods, sort: FoodSort.frequent)).first,
        'Porridge',
      );
      expect(names(findFoods(foods, sort: FoodSort.name)), [
        'Apfel',
        'Pasta',
        'Porridge',
        'Skyr',
      ]);
      expect(names(findFoods(foods, sort: FoodSort.kcal)), [
        'Apfel',
        'Skyr',
        'Porridge',
        'Pasta',
      ]);
    });

    test('searches the name, whatever the case', () {
      expect(names(findFoods(foods, query: ' PA')), ['Pasta']);
      expect(findFoods(foods, query: 'xyz'), isEmpty);
    });

    test('filters by time of day, protein, energy and source', () {
      expect(names(findFoods(foods, daytime: FoodDaytime.morning)), [
        'Porridge',
        'Apfel',
      ]);
      expect(names(findFoods(foods, daytime: FoodDaytime.midday)), ['Skyr']);
      expect(names(findFoods(foods, daytime: FoodDaytime.evening)), ['Pasta']);
      // 25 g, and 17 g that are 45 % of 150 kcal.
      expect(names(findFoods(foods, proteinRich: true)), ['Pasta', 'Skyr']);
      expect(names(findFoods(foods, energy: FoodEnergy.low)), [
        'Skyr',
        'Apfel',
      ]);
      expect(names(findFoods(foods, energy: FoodEnergy.middle)), ['Porridge']);
      expect(names(findFoods(foods, energy: FoodEnergy.high)), ['Pasta']);
      expect(names(findFoods(foods, ownOnly: true)), [
        'Pasta',
        'Porridge',
        'Apfel',
      ]);
      expect(
        findFoods(foods, energy: FoodEnergy.low, proteinRich: true).single.name,
        'Skyr',
      );
    });
  });

  group('FoodArchive', () {
    test('a hidden food is out of the lists until it is eaten again', () async {
      final store = MemoryJsonStore();
      final archive = FoodArchive(store);
      await archive.mergeIntoStore([_meal('Pasta', _ago(2))]);
      var foods = await archive.setHidden('pasta', _now);
      expect(findFoods(foods), isEmpty);
      expect(topFoods(foods, _now), isEmpty);

      // The same meals read again leave it hidden.
      foods = await archive.mergeIntoStore(
        [_meal('Pasta', _ago(2))],
        window: (_ago(10), _now),
      );
      expect(findFoods(foods), isEmpty);

      foods = await archive.mergeIntoStore([
        _meal('Pasta', _now.add(const Duration(hours: 1))),
      ]);
      expect(findFoods(foods).single.name, 'Pasta');

      foods = await archive.setHidden(
        'pasta',
        _now.add(const Duration(days: 1)),
      );
      foods = await archive.setHidden('pasta', _now, hidden: false);
      expect(findFoods(foods), hasLength(1));
    });

    test('a document of another version is not read', () async {
      final store = MemoryJsonStore();
      await store.write(StoreKeys.foods, {'version': 99, 'foods': []});
      expect(await FoodArchive(store).load(), isEmpty);
    });
  });

  group('HealthController', () {
    HealthController controller(FixtureRepository repository, JsonStore store) {
      final health = HealthController(
        repository: repository,
        store: store,
        clock: () => fixtureNow,
      );
      addTearDown(health.dispose);
      return health;
    }

    test('the named meals of the window are its foods, and older ones are '
        'fetched once', () async {
      final store = MemoryJsonStore();
      final repository = FixtureRepository()
        ..historyAccess = true
        ..olderDays = fixtureOlderDays()
        ..olderMeals = [
          _meal('Gulasch', DateTime(2025, 3, 2, 19), kcal: 650),
          _meal('Mittagessen', DateTime(2026, 6, 1, 12), kcal: 600),
        ];
      final health = controller(repository, store);
      await health.start();

      expect(health.foods.map((food) => food.name), ['Gulasch', 'Mittagessen']);
      final lunch = health.foods.last;
      expect(lunch.eaten, hasLength(2));
      // The values of the later one, which is the window's.
      expect(lunch.kcal, 640);
      final requests = repository.mealRequests.length;
      expect(requests, greaterThan(1));

      final again = controller(repository, store);
      await again.start();
      expect(repository.mealRequests.length, requests);
      expect(again.foods, hasLength(2));
    });

    test('a meal added is a food at once; hiding it is kept', () async {
      final store = MemoryJsonStore();
      final repository = FixtureRepository();
      final health = controller(repository, store);
      await health.start();
      await health.addEntry(
        EntryDraft(
          kind: EntryKind.meal,
          time: fixtureNow,
          amount: 420,
          name: 'Porridge',
        ),
      );
      expect(health.foods.map((food) => food.name), [
        'Mittagessen',
        'Porridge',
      ]);

      await health.hideFood(health.foods.last);
      expect(findFoods(health.foods).single.name, 'Mittagessen');
      final again = controller(repository, store);
      await again.start();
      expect(findFoods(again.foods).single.name, 'Mittagessen');
    });
  });

  test('a food becomes the draft of a meal like the last one', () {
    final food = mergeFoods(const [], [
      _meal('Pasta', _ago(2), kcal: 700, protein: 25),
    ])!.single;
    final draft = food.draftAt(_now);
    expect(draft.kind, EntryKind.meal);
    expect(draft.time, _now);
    expect(draft.name, 'Pasta');
    expect(draft.amount, 700);
    expect(draft.protein, 25);
  });
}
