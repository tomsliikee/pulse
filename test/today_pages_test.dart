import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/snapshot_builder.dart';
import 'package:pulse/features/activity/workout_detail_page.dart';
import 'package:pulse/features/activity/workout_tiles.dart';
import 'package:pulse/features/sleep/night_tiles.dart';
import 'package:pulse/features/sleep/sleep_detail_page.dart';
import 'package:pulse/features/today/day_detail_page.dart';
import 'package:pulse/features/today/day_list_page.dart';
import 'package:pulse/features/today/day_scene.dart';
import 'package:pulse/features/today/day_tiles.dart';
import 'package:pulse/features/today/today_page.dart';
import 'package:pulse/l10n/generated/app_localizations.dart';
import 'package:pulse/widgets/day_switcher.dart';
import 'package:pulse/widgets/floating_surface.dart';
import 'package:pulse/widgets/metric_card.dart';

import 'support/fixtures.dart';

const _sizes = [Size(360, 640), Size(412, 915)];

Finder _onToday(Finder finder) =>
    find.descendant(of: find.byType(TodayPage), matching: finder);

FixtureRepository _withTwoYears() => FixtureRepository()
  ..historyAccess = true
  ..olderDays = fixtureOlderDays();

Future<void> _scrollThrough(WidgetTester tester, Finder scrollable) async {
  for (var i = 0; i < 12; i++) {
    await tester.drag(scrollable, const Offset(0, -500));
    await advance(tester);
  }
}

void main() {
  setUpAll(loadAppFont);

  testWidgets('Today starts with the day: its scene, the score so far, the '
      'rings and how it stands against yesterday', (tester) async {
    await pumpApp(tester);

    final card = find.byType(DayCard);
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.byType(DayScene)),
      findsOneWidget,
    );
    expect(find.text('Tageswert bisher'), findsOneWidget);
    // 7.432 by half past three against 3.000 by then the day before.
    expect(
      find.text('4.432 Schritte mehr als gestern um diese Zeit'),
      findsOneWidget,
    );
    // The hints, last night and the goals follow in that order.
    final tips = tester.getRect(find.byType(DayTipsCard));
    final night = tester.getRect(
      _onToday(find.byType(NightRow, skipOffstage: false)),
    );
    final goals = tester.getRect(find.byType(GoalsCard, skipOffstage: false));
    expect(tips.top, greaterThan(tester.getRect(card).bottom - 1));
    expect(night.top, greaterThan(tips.bottom - 1));
    expect(goals.top, greaterThan(night.bottom - 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('with the pills open the bar stays live: a tap on Gestern '
      'switches the day and takes them away', (tester) async {
    await pumpApp(tester, repository: _withTwoYears());
    await tester.tap(find.text('Tageswert bisher'));
    await advance(tester);
    final page = find.byType(DayDetailPage);
    final bar = find.descendant(of: page, matching: find.byType(DaySwitcher));
    Finder tab(String label) =>
        find.descendant(of: bar, matching: find.bySemanticsLabel(label));
    Finder pill(String text) => find.widgetWithText(FloatingSurface, text);

    await tester.tap(tab('Weitere'));
    await advance(tester);
    expect(pill('Alle Tage'), findsOneWidget);

    await tester.tap(tab('Gestern'));
    await advance(tester);
    expect(pill('Alle Tage'), findsNothing);
    expect(
      find.descendant(of: page, matching: find.text('Montag, 5. Oktober')),
      findsOneWidget,
    );

    // A tap beside the pills closes them and leaves the day alone.
    await tester.tap(tab('Weitere'));
    await advance(tester);
    await tester.tapAt(const Offset(40, 300));
    await advance(tester);
    expect(pill('Alle Tage'), findsNothing);
    expect(
      find.descendant(of: page, matching: find.text('Montag, 5. Oktober')),
      findsOneWidget,
    );

    // So does the tab itself, and back before it leaves the page.
    await tester.tap(tab('Weitere'));
    await advance(tester);
    await tester.tap(tab('Weitere'));
    await advance(tester);
    expect(pill('Alle Tage'), findsNothing);
    await tester.tap(tab('Weitere'));
    await advance(tester);
    await tester.binding.handlePopRoute();
    await advance(tester);
    expect(pill('Alle Tage'), findsNothing);
    expect(page, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the tiles wake up when the page is opened, and not again when '
      'it is edited', (tester) async {
    await pumpApp(tester);
    double opacity() => tester
        .widget<Opacity>(
          find
              .ancestor(
                of: find.byType(DayCard),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;
    expect(opacity(), 1);

    await tester.tap(find.byTooltip('Kacheln anordnen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(opacity(), 1);
    await advance(tester);

    // Coming back to the page from another one starts it afresh.
    await tester.tap(find.bySemanticsLabel('Herz'));
    await advance(tester);
    await tester.tap(find.bySemanticsLabel('Heute'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(opacity(), lessThan(1));
    await advance(tester);
    expect(opacity(), 1);
  });

  testWidgets('without hours for yesterday the day is set against nothing', (
    tester,
  ) async {
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
    expect(find.textContaining('gestern um diese Zeit'), findsNothing);
    // The day before is whole, so it is not what a running day is set
    // against either: the sentence falls back to the days as they are.
    expect(find.byType(DayCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the rows of last night and the latest workout open their '
      'pages', (tester) async {
    await pumpApp(tester);

    await tapInView(tester, _onToday(find.text('Letzte Nacht')));
    expect(find.byType(SleepDetailPage), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await advance(tester);

    await tapInView(tester, _onToday(find.byType(WorkoutRow)));
    expect(find.byType(WorkoutDetailPage), findsOneWidget);
  });

  testWidgets('the goals tile shows the four goals that are on at first', (
    tester,
  ) async {
    await pumpApp(tester);
    final card = find.byType(GoalsCard);
    await bringIntoView(tester, card);
    Finder onCard(String text) =>
        find.descendant(of: card, matching: find.text(text));
    expect(onCard('7.432 von 10.000'), findsOneWidget);
    expect(onCard('310 kcal von 500 kcal'), findsOneWidget);
    expect(onCard('7 h 12 min von 8 h 0 min'), findsOneWidget);
    expect(onCard('1,2 l von 2,4 l'), findsOneWidget);
  });

  testWidgets('the bar of a day leads to yesterday, and its menu to the days '
      'before and to all of them', (tester) async {
    await pumpApp(tester, repository: _withTwoYears());
    await tester.tap(find.text('Tageswert bisher'));
    await advance(tester);
    final page = find.byType(DayDetailPage);
    Finder onPage(String text) => find.descendant(
      of: page,
      matching: find.text(text, skipOffstage: false),
    );
    final bar = find.descendant(of: page, matching: find.byType(DaySwitcher));
    Finder tab(String label) =>
        find.descendant(of: bar, matching: find.bySemanticsLabel(label));
    expect(onPage('Dienstag, 6. Oktober'), findsOneWidget);

    await tester.tap(tab('Gestern'));
    await advance(tester);
    expect(onPage('Montag, 5. Oktober'), findsOneWidget);
    expect(onPage('Tageswert bisher'), findsNothing);

    final surfaces = find.byType(FloatingSurface).evaluate().length;
    await tester.tap(tab('Weitere'));
    await advance(tester);
    // The five days before yesterday, then the way to all.
    // Six pills of their own: five days and the way to all.
    expect(find.byType(FloatingSurface).evaluate().length - surfaces, 6);
    expect(find.widgetWithText(FloatingSurface, 'So, 4.10.'), findsOneWidget);
    expect(find.widgetWithText(FloatingSurface, 'Mi, 30.9.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FloatingSurface, 'Sa, 3.10.'));
    await advance(tester);
    expect(onPage('Samstag, 3. Oktober'), findsOneWidget);
    // The third tab now carries the day, and opens the menu again.
    expect(tab('Weitere'), findsNothing);
    await tester.tap(tab('Sa, 3.10.'));
    await advance(tester);
    await tester.tap(find.widgetWithText(FloatingSurface, 'Alle Tage'));
    await advance(tester);
    expect(find.byType(DayListPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the glass on the water tile enters 250 ml, and the message '
      'takes it back', (tester) async {
    final app = await pumpApp(tester);
    final glass = find.byTooltip('Ein Glas Wasser eintragen');
    await tapInView(tester, glass);

    final added = app.repository.added.single;
    expect(added.kind, EntryKind.water);
    expect(added.amount, 250);
    expect(added.time, fixtureNow);
    expect(find.text('250 ml Wasser eingetragen'), findsOneWidget);
    // The tile was not opened by the tap on its button.
    expect(find.text('Einträge'), findsNothing);

    await tester.tap(find.text('Rückgängig'));
    await advance(tester);
    expect(app.repository.deleted.single.draft.amount, 250);
  });

  testWidgets('a refused glass says so', (tester) async {
    final app = await pumpApp(tester);
    app.repository.failAdds = true;
    await tapInView(tester, find.byTooltip('Ein Glas Wasser eintragen'));
    expect(find.text('Der Eintrag konnte nicht gespeichert werden.'), findsOne);
  });

  testWidgets('the days before are listed, and one of them opens its own '
      'page with the three before it', (tester) async {
    await pumpApp(tester, repository: _withTwoYears());

    final days = find.byType(DaysCard, skipOffstage: false);
    await bringIntoView(tester, days);
    final rows = find.descendant(
      of: days,
      matching: find.byType(DayRow, skipOffstage: false),
    );
    expect(rows, findsNWidgets(5));
    expect(find.text('Mo, 5.10.', skipOffstage: false), findsOneWidget);

    await tapInView(tester, find.text('Mo, 5.10.'));
    final page = find.byType(DayDetailPage);
    expect(page, findsOneWidget);
    Finder onPage(Finder finder) => find.descendant(of: page, matching: finder);
    expect(onPage(find.text('Montag, 5. Oktober')), findsOneWidget);
    // A day that is over has its score, not a score so far, and is set
    // against whole days.
    expect(onPage(find.text('Tageswert')), findsWidgets);
    expect(onPage(find.text('Tageswert bisher')), findsNothing);
    expect(onPage(find.text('Tag davor', skipOffstage: false)), findsOneWidget);
    expect(
      onPage(find.text('nicht gewertet', skipOffstage: false)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: onPage(find.byType(DaysCard, skipOffstage: false)),
        matching: find.byType(DayRow, skipOffstage: false),
      ),
      findsNWidgets(3),
    );
    await _scrollThrough(tester, onPage(find.byType(CustomScrollView)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('today\'s page leaves out the comparison with whole days', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Tageswert bisher'));
    await advance(tester);
    final page = find.byType(DayDetailPage);
    expect(page, findsOneWidget);
    expect(
      find.descendant(
        of: page,
        matching: find.text('Tag davor', skipOffstage: false),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: page,
        matching: find.text('Die Nacht davor', skipOffstage: false),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the rows a list starts with come in; the ones scrolled to are '
      'simply there', (tester) async {
    await pumpApp(tester, repository: _withTwoYears());
    await bringIntoView(tester, find.text('Alle Tage', skipOffstage: false));
    await tester.tap(find.text('Alle Tage'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    final page = find.byType(DayListPage);
    double opacityOf(Finder row) => tester
        .widget<Opacity>(
          find.ancestor(of: row, matching: find.byType(Opacity)).first,
        )
        .opacity;
    final rows = find.descendant(of: page, matching: find.byType(DayRow));
    // The third row is still waiting for its turn.
    expect(opacityOf(rows.at(2)), lessThan(1));
    await advance(tester);
    expect(opacityOf(rows.at(2)), 1);

    await tester.drag(
      find.descendant(of: page, matching: find.byType(CustomScrollView)),
      const Offset(0, -3000),
    );
    await tester.pump();
    expect(opacityOf(rows.first), 1);
    await advance(tester);
  });

  testWidgets('all days are listed month by month, newest first', (
    tester,
  ) async {
    await pumpApp(tester, repository: _withTwoYears());
    await tapInView(tester, find.text('Alle Tage', skipOffstage: false));

    final page = find.byType(DayListPage);
    expect(page, findsOneWidget);
    expect(
      find.descendant(of: page, matching: find.text('Oktober 2026')),
      findsOneWidget,
    );
    final first = find
        .descendant(of: page, matching: find.byType(DayRow))
        .first;
    expect(
      find.descendant(of: first, matching: find.text('Di, 6.10.')),
      findsOneWidget,
    );
    await _scrollThrough(
      tester,
      find.descendant(of: page, matching: find.byType(CustomScrollView)),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the tiles about the day can be removed and brought back', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await tester.tap(find.byTooltip('Kacheln anordnen'));
    await advance(tester);
    await tester.tap(find.byTooltip('Entfernen').hitTestable().first);
    await advance(tester);
    expect(find.byType(DayCard), findsNothing);
    expect(app.store.documents['settings'], isNot(contains('"hero"')));

    final offer = find.text('Der Tag');
    await tester.scrollUntilVisible(
      offer,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await advance(tester);
    await tester.tap(offer);
    await advance(tester);
    expect(find.byType(DayCard, skipOffstage: false), findsOneWidget);
    expect(app.store.documents['settings'], contains('"hero"'));
  });

  testWidgets('a page arranged before the rework gets the day on top and '
      'keeps its own tiles in their order', (tester) async {
    final store = MemoryJsonStore();
    await store.write(StoreKeys.settings, {
      'todayTiles': ['water', 'steps', 'heartRate'],
      'tileOrder': {
        'today': ['heartRate', 'water', 'steps'],
      },
    });
    await pumpApp(tester, store: store);

    Rect of(Finder finder) => tester.getRect(finder);
    final day = of(find.byType(DayCard));
    final tips = of(find.byType(DayTipsCard, skipOffstage: false));
    final goals = of(find.byType(GoalsCard, skipOffstage: false));
    final heart = of(find.text('Herzfrequenz', skipOffstage: false));
    final water = of(
      find.descendant(
        of: find.byType(MetricCard, skipOffstage: false),
        matching: find.text('Wasser', skipOffstage: false),
      ),
    );
    final days = of(find.byType(DaysCard, skipOffstage: false));
    expect(tips.top, greaterThan(day.bottom - 1));
    expect(goals.top, greaterThan(tips.bottom - 1));
    expect(heart.top, greaterThan(goals.bottom - 1));
    expect(water.top, greaterThan(heart.top - 1));
    // The days before come last.
    expect(days.top, greaterThan(water.bottom - 1));
  });

  testWidgets('an empty store shows the day without numbers and offers no '
      'days before', (tester) async {
    for (final size in _sizes) {
      await pumpApp(
        tester,
        size: size,
        repository: FixtureRepository(readings: const RawReadings()),
      );
      expect(find.byType(DayCard), findsOneWidget);
      expect(find.byType(DaysCard, skipOffstage: false), findsNothing);
      expect(
        find.text('Nach drei Tagen kann Pulse vergleichen und Hinweise geben.'),
        findsOneWidget,
      );
      await _scrollThrough(tester, find.byType(ListView).first);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  for (final language in ['de', 'en', 'pl']) {
    for (final size in _sizes) {
      for (final glass in [false, true]) {
        final label =
            '$language at ${size.width.round()}x${size.height.round()}'
            '${glass ? ' as glass' : ''}';

        testWidgets('Today, a day and the list render in $label', (
          tester,
        ) async {
          final l10n = lookupAppLocalizations(Locale(language));
          final store = MemoryJsonStore();
          await store.write(StoreKeys.settings, {
            'birthDate': '1992-03-07',
            'liquidGlass': glass,
          });
          await pumpApp(
            tester,
            size: size,
            locale: Locale(language),
            repository: _withTwoYears(),
            store: store,
          );
          await _scrollThrough(tester, find.byType(ListView).first);
          await tester.drag(find.byType(ListView).first, const Offset(0, 9000));
          await advance(tester);

          await tester.tap(find.text(l10n.dayScoreSoFar));
          await advance(tester);
          final page = find.byType(DayDetailPage);
          expect(page, findsOneWidget);
          await _scrollThrough(
            tester,
            find.descendant(of: page, matching: find.byType(CustomScrollView)),
          );
          await tester.tap(
            find.descendant(of: page, matching: find.text(l10n.allDays)),
          );
          await advance(tester);
          expect(find.byType(DayListPage), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('the scene runs through every kind of day, and stands at the '
      'moment the day has reached when animations are off', (tester) async {
    final hours = [for (var hour = 0; hour < 24; hour++) hour * 90.0];
    for (final scene in [
      // Today in the afternoon, with hours and a run.
      DayScene(
        untilMinute: 15 * 60 + 30,
        score: 90,
        hours: hours,
        wakeMinute: 6 * 60 + 40,
        workouts: [
          Workout(
            type: WorkoutType.run,
            start: DateTime(2026, 10, 6, 12),
            minutes: 40,
          ),
        ],
      ),
      // A day that is over, known only by its total.
      const DayScene(untilMinute: 22 * 60, score: 30, steps: 9000),
      // Early in the morning, before anything has happened.
      const DayScene(untilMinute: 5, score: 50),
    ]) {
      await tester.pumpWidget(themed(Scaffold(body: scene)));
      // Through a whole loop and into the next.
      for (var i = 0; i < 14; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(tester.hasRunningAnimations, isTrue);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(
      themed(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: DayScene(untilMinute: 12 * 60, score: 70, hours: hours),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });
}
