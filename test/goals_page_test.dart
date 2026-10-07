import 'package:flutter_test/flutter_test.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/snapshot_builder.dart';
import 'package:pulse/features/goals/goals_page.dart';
import 'package:pulse/features/today/day_tiles.dart';
import 'package:pulse/l10n/generated/app_localizations.dart';
import 'package:pulse/widgets/floating_tab_bar.dart';

import 'support/fixtures.dart';

const _sizes = [Size(360, 640), Size(412, 915)];

FixtureRepository _withTwoYears() => FixtureRepository()
  ..historyAccess = true
  ..olderDays = fixtureOlderDays();

Future<void> _openGoals(WidgetTester tester) async {
  await tapInView(tester, find.byType(GoalsCard));
  expect(find.byType(GoalsPage), findsOneWidget);
}

Finder _onPage(Finder finder) =>
    find.descendant(of: find.byType(GoalsPage), matching: finder);

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(FloatingTabBar),
      matching: find.bySemanticsLabel(label),
    ),
  );
  await advance(tester);
}

Future<void> _scrollThrough(WidgetTester tester) async {
  final scrollable = _onPage(find.byType(CustomScrollView));
  for (var i = 0; i < 10; i++) {
    await tester.drag(scrollable, const Offset(0, -500));
    await advance(tester);
  }
  await tester.drag(scrollable, const Offset(0, 9000));
  await advance(tester);
}

void main() {
  setUpAll(loadAppFont);

  testWidgets('the goals tile opens the page, which starts on today', (
    tester,
  ) async {
    await pumpApp(tester);
    await _openGoals(tester);
    expect(_onPage(find.text('Dienstag, 6. Oktober')), findsOneWidget);
    expect(_onPage(find.text('7.432 von 10.000')), findsOneWidget);
    expect(_onPage(find.text('1,2 l von 2,4 l')), findsOneWidget);
    // Nothing is reached yet at half past three.
    expect(_onPage(find.bySemanticsLabel('erreicht')), findsNothing);
  });

  testWidgets('a week shows each day, how many were reached and pages back', (
    tester,
  ) async {
    await pumpApp(tester, repository: _withTwoYears());
    await _openGoals(tester);
    await _tab(tester, 'Woche');
    expect(_onPage(find.text('5.10. bis 11.10.')), findsOneWidget);
    // Monday is over, Tuesday is running: one day counts for each goal.
    expect(_onPage(find.text('0 von 1 erreicht')), findsWidgets);
    expect(_onPage(find.bySemanticsLabel('läuft noch')), findsWidgets);

    await tester.tap(find.byTooltip('Früher'));
    await advance(tester);
    expect(_onPage(find.text('28.9. bis 4.10.')), findsOneWidget);
    // Two days of that week were above ten thousand steps.
    expect(_onPage(find.text('2 von 7 erreicht')), findsOneWidget);
    await tester.tap(find.byTooltip('Später'));
    await advance(tester);
    expect(_onPage(find.text('5.10. bis 11.10.')), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('a switch adds a goal to the page and the tile, and is saved', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await _openGoals(tester);
    expect(_onPage(find.text('Etagen')), findsOneWidget);

    final toggle = find.descendant(
      of: _onPage(find.bySemanticsLabel('Etagen')),
      matching: find.byType(Switch),
    );
    await tapInView(tester, toggle);
    expect(app.store.documents['settings'], contains('"floors"'));
    // Its card above and its row among the settings.
    expect(_onPage(find.text('Etagen', skipOffstage: false)), findsNWidgets(2));

    await tapInView(
      tester,
      find.descendant(
        of: _onPage(find.bySemanticsLabel('Wasser')),
        matching: find.byType(Switch),
      ),
    );
    await tester.tap(find.byType(BackButton));
    await advance(tester);
    final card = find.byType(GoalsCard);
    expect(
      find.descendant(of: card, matching: find.text('Etagen')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Wasser')),
      findsNothing,
    );
  });

  testWidgets('the slider of a goal sets its target', (tester) async {
    final app = await pumpApp(tester);
    await _openGoals(tester);
    await tapInView(
      tester,
      find.descendant(
        of: _onPage(find.bySemanticsLabel('Aktive Minuten')),
        matching: find.byType(Switch),
      ),
    );
    expect(_onPage(find.text('30 min')), findsOneWidget);
    final slider = find
        .descendant(
          of: find.ancestor(
            of: _onPage(find.text('30 min')),
            matching: find.byType(Column),
          ),
          matching: find.byType(M3ESlider),
        )
        .first;
    await bringIntoView(tester, slider);
    await tester.tapAt(tester.getRect(slider).centerRight - const Offset(4, 0));
    await advance(tester);
    expect(_onPage(find.text('120 min')), findsOneWidget);
    expect(app.store.documents['settings'], contains('"intensityMinutes":120'));
  });

  testWidgets('with every goal switched off the tile and the page say so', (
    tester,
  ) async {
    final store = MemoryJsonStore();
    await store.write(StoreKeys.settings, {'goals': <String>[]});
    await pumpApp(tester, store: store);
    await bringIntoView(tester, find.byType(GoalsCard));
    expect(find.text('Noch keine Ziele gewählt.'), findsOneWidget);
    await _openGoals(tester);
    expect(_onPage(find.text('Noch keine Ziele gewählt.')), findsOneWidget);
  });

  for (final language in ['de', 'en', 'pl']) {
    for (final size in _sizes) {
      for (final glass in [false, true]) {
        final label =
            '$language at ${size.width.round()}x${size.height.round()}'
            '${glass ? ' as glass' : ''}';

        testWidgets('every span of the goals renders in $label', (
          tester,
        ) async {
          final l10n = lookupAppLocalizations(Locale(language));
          final store = MemoryJsonStore();
          await store.write(StoreKeys.settings, {
            'liquidGlass': glass,
            // Every goal of the catalog.
            'goals': [
              'steps',
              'activeEnergy',
              'intensityMinutes',
              'distance',
              'floors',
              'sleepDuration',
              'sleepScore',
              'water',
              'workouts',
              'trainingMinutes',
              'energyIntake',
              'protein',
            ],
          });
          await pumpApp(
            tester,
            size: size,
            locale: Locale(language),
            repository: _withTwoYears(),
            store: store,
          );
          await _openGoals(tester);
          for (final tab in [
            l10n.navToday,
            l10n.periodWeek,
            l10n.periodMonth,
            l10n.periodYear,
          ]) {
            await _tab(tester, tab);
            await _scrollThrough(tester);
            await tester.tap(find.byTooltip(l10n.earlier));
            await advance(tester);
            expect(tester.takeException(), isNull);
          }
        });
      }
    }
  }

  testWidgets('an empty store renders every span', (tester) async {
    await pumpApp(
      tester,
      repository: FixtureRepository(readings: const RawReadings()),
    );
    await _openGoals(tester);
    for (final tab in ['Woche', 'Monat', 'Jahr']) {
      await _tab(tester, tab);
      await _scrollThrough(tester);
    }
    expect(tester.takeException(), isNull);
  });
}
