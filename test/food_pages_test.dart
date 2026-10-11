import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/food_archive.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/snapshot_builder.dart';
import 'package:pulse/features/entry/entry_sheet.dart';
import 'package:pulse/features/entry/food_sheet.dart';
import 'package:pulse/features/entry/foods_page.dart';
import 'package:pulse/l10n/generated/app_localizations.dart';

import 'support/fixtures.dart';

/// Foods from before the window, which a read of the window leaves alone.
Future<MemoryJsonStore> _storeWithFoods() async {
  final store = MemoryJsonStore();
  var id = 0;
  HealthEntry meal(
    String name,
    int daysAgo,
    int hour,
    double kcal, {
    double? protein,
    bool own = true,
  }) => HealthEntry(
    id: 'old-${id++}',
    source: own ? 'at.haiden.pulse' : 'com.other',
    isOwn: own,
    draft: EntryDraft(
      kind: EntryKind.meal,
      time: fixtureNow.subtract(Duration(days: daysAgo, hours: 12 - hour)),
      amount: kcal,
      name: name,
      protein: protein,
    ),
  );
  await FoodArchive(store).mergeIntoStore([
    meal('Porridge mit Beeren und Nüssen', 40, 8, 420, protein: 14),
    meal('Porridge mit Beeren und Nüssen', 41, 8, 420, protein: 14),
    meal('Pasta', 42, 19, 700, protein: 25),
    meal('Skyr', 43, 15, 150, protein: 17, own: false),
    meal('Apfel', 44, 10, 80),
    meal('Gulasch', 45, 19, 650, protein: 40),
    meal('Käsebrot', 46, 8, 310, protein: 12),
  ]);
  return store;
}

Future<void> _openMeal(WidgetTester tester, AppLocalizations l10n) async {
  await tester.tap(find.byIcon(Icons.add_rounded));
  await advance(tester);
  await tester.tap(find.text(l10n.entryMeal).hitTestable().last);
  await advance(tester);
}

void main() {
  setUpAll(loadAppFont);
  final de = lookupAppLocalizations(const Locale('de'));

  testWidgets('a new meal starts at the foods; one of them fills the form, '
      'and saving writes a meal like it for now', (tester) async {
    final app = await pumpApp(tester);
    await _openMeal(tester, de);

    expect(find.byType(FoodSheet), findsOneWidget);
    // One food only: nothing more to show.
    expect(find.text(de.foodsMore), findsNothing);
    await tester.tap(find.text('Mittagessen').hitTestable());
    await advance(tester);

    expect(find.byType(FoodSheet), findsNothing);
    expect(find.byType(EntrySheet), findsOneWidget);
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((field) => field.controller!.text)
        .toList();
    expect(fields.take(5), ['Mittagessen', '640', '72', '31', '22']);

    await tester.ensureVisible(find.text(de.save).last);
    await tester.pump();
    await tester.tap(find.text(de.save).hitTestable());
    await advance(tester);
    final meal = app.repository.added.single;
    expect(meal.kind, EntryKind.meal);
    expect(meal.name, 'Mittagessen');
    expect(meal.amount, 640);
    expect(meal.protein, 31);
    expect(meal.time.isAfter(fixtureNow), isTrue);
  });

  testWidgets('without a named meal the form comes at once', (tester) async {
    final readings = fixtureReadings();
    await pumpApp(
      tester,
      repository: FixtureRepository(
        readings: RawReadings(
          samples: readings.samples,
          dailyTotals: readings.dailyTotals,
          sleepSessions: readings.sleepSessions,
          sleepStages: readings.sleepStages,
          workouts: readings.workouts,
        ),
      ),
    );
    await _openMeal(tester, de);
    expect(find.byType(FoodSheet), findsNothing);
    expect(find.byType(EntrySheet), findsOneWidget);
  });

  testWidgets('leaving the food sheet opens nothing', (tester) async {
    final app = await pumpApp(tester);
    await _openMeal(tester, de);
    Navigator.of(tester.element(find.byType(FoodSheet))).pop();
    await advance(tester);
    expect(find.byType(EntrySheet), findsNothing);
    expect(app.repository.added, isEmpty);
  });

  testWidgets('the sheet shows five and leads to all of them, which can be '
      'searched, sorted, filtered and taken', (tester) async {
    await pumpApp(tester, store: await _storeWithFoods());
    await _openMeal(tester, de);

    expect(find.byType(FoodRow), findsNWidgets(5));
    await tester.tap(find.text(de.foodsMore).hitTestable());
    await advance(tester);
    expect(find.byType(FoodsPage), findsOneWidget);
    expect(find.byType(FoodRow), findsNWidgets(7));

    List<String> names() => [
      for (final row in tester.widgetList<FoodRow>(find.byType(FoodRow)))
        row.food.name,
    ];
    expect(names().first, 'Mittagessen');

    await tester.tap(find.text(de.foodSortName));
    await advance(tester);
    expect(names().first, 'Apfel');

    await tester.tap(find.text(de.foodProteinRich));
    await advance(tester);
    expect(names(), ['Gulasch', 'Mittagessen', 'Pasta', 'Skyr']);
    await tester.tap(find.text(de.foodProteinRich));
    await advance(tester);

    await tester.enterText(find.byType(TextField), 'porr');
    await advance(tester);
    expect(names(), ['Porridge mit Beeren und Nüssen']);
    await tester.enterText(find.byType(TextField), 'nichts davon');
    await advance(tester);
    expect(find.text(de.foodsNone), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'gul');
    await advance(tester);

    await tester.tap(find.text('Gulasch'));
    await advance(tester);
    expect(find.byType(FoodsPage), findsNothing);
    expect(find.byType(EntrySheet), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Gulasch',
    );
  });

  testWidgets('a swipe takes a food out of the lists, and undo brings it '
      'back', (tester) async {
    final store = await _storeWithFoods();
    await pumpApp(tester, store: store);
    await _openMeal(tester, de);
    await tester.tap(find.text(de.foodsMore).hitTestable());
    await advance(tester);

    await tester.drag(find.text('Pasta'), const Offset(-500, 0));
    await advance(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Pasta'), findsNothing);
    expect(find.text(de.foodHidden('Pasta')), findsOneWidget);
    expect(findFoods(await FoodArchive(store).load()), hasLength(6));

    await tester.tap(find.text(de.undo));
    await advance(tester);
    expect(find.text('Pasta'), findsOneWidget);
    expect(findFoods(await FoodArchive(store).load()), hasLength(7));
  });

  for (final locale in AppLocalizations.supportedLocales) {
    for (final size in const [Size(360, 640), Size(412, 915)]) {
      testWidgets('the foods render in ${locale.languageCode} at '
          '${size.width.round()}x${size.height.round()}', (tester) async {
        final l10n = lookupAppLocalizations(locale);
        await pumpApp(
          tester,
          size: size,
          locale: locale,
          store: await _storeWithFoods(),
        );
        await _openMeal(tester, l10n);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(l10n.foodsMore).hitTestable());
        await advance(tester);
        expect(tester.takeException(), isNull);
        expect(find.text(l10n.foodsTitle), findsWidgets);
      });
    }
  }
}
