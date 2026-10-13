import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/settings_controller.dart';
import 'package:pulse/features/activity/workout_format.dart';
import 'package:pulse/features/activity/workout_tiles.dart';
import 'package:pulse/features/heart/heart_tiles.dart';
import 'package:pulse/features/links/link_card.dart';
import 'package:pulse/features/links/links_tile.dart';
import 'package:pulse/features/morning/morning_tile.dart';
import 'package:pulse/features/sleep/night_tiles.dart';
import 'package:pulse/features/today/day_tiles.dart';
import 'package:pulse/l10n/generated/app_localizations.dart';
import 'package:pulse/widgets/bar_chart.dart';
import 'package:pulse/widgets/chip_carousel.dart';
import 'package:pulse/widgets/free_figure.dart';

import 'support/fixtures.dart';

const _sizes = [Size(360, 640), Size(412, 915)];

final AppLocalizations _de = lookupAppLocalizations(const Locale('de'));

/// A store whose settings hold [mode] and a birth date, so there is a body
/// age to show.
Future<MemoryJsonStore> _store({
  required bool simple,
  Map<String, Object?> more = const {},
}) async {
  final store = MemoryJsonStore();
  await store.write(StoreKeys.settings, {
    'birthDate': '1992-03-07',
    'simple': simple,
    ...more,
  });
  return store;
}

Future<void> _open(WidgetTester tester, String page) async {
  await tester.tap(find.bySemanticsLabel(page));
  await advance(tester);
}

Future<void> _scrollThrough(WidgetTester tester) async {
  final list = find.byType(Scrollable).first;
  for (var i = 0; i < 8; i++) {
    await tester.drag(list, const Offset(0, -500));
    await advance(tester);
  }
}

Finder _in(Type card, Finder what) => find.descendant(
  of: find.byType(card, skipOffstage: false),
  matching: what,
  skipOffstage: false,
);

/// The texts written inside [card].
Iterable<String> _texts(WidgetTester tester, Type card) => tester
    .widgetList<Text>(_in(card, find.byType(Text, skipOffstage: false)))
    .map((text) => text.data ?? '');

void main() {
  setUpAll(loadAppFont);

  group('the setting', () {
    test('a new installation starts simple', () async {
      final settings = SettingsController(MemoryJsonStore());
      await settings.load();
      expect(settings.simple, isTrue);
    });

    test('settings saved before the mode existed keep every number', () async {
      final store = MemoryJsonStore();
      await store.write(StoreKeys.settings, {'stepGoal': 9000});
      final settings = SettingsController(store);
      await settings.load();
      expect(settings.simple, isFalse);
      expect(settings.stepGoal, 9000);
    });

    test('the choice is saved and loaded again', () async {
      final store = MemoryJsonStore();
      final settings = SettingsController(store);
      await settings.load();
      settings.setSimple(false);
      await Future<void>.delayed(Duration.zero);
      expect(store.documents[StoreKeys.settings], contains('"simple":false'));

      final again = SettingsController(store);
      await again.load();
      expect(again.simple, isFalse);
      again.setSimple(true);
      await Future<void>.delayed(Duration.zero);
      final third = SettingsController(store);
      await third.load();
      expect(third.simple, isTrue);
    });
  });

  group('Heute', () {
    testWidgets('the day keeps its three numbers and the body age, and says '
        'how it stands without a number', (tester) async {
      await pumpApp(tester, store: await _store(simple: true));
      final texts = _texts(tester, DayCard).toList();
      expect(texts, contains('Mehr Schritte als gestern um diese Zeit'));
      expect(texts, contains('Schritte'));
      expect(texts, contains('aktive kcal'));
      expect(texts, contains(_de.bodyAge));
      expect(texts.where((text) => text.contains('10.000')), isEmpty);
      expect(texts.where((text) => text.contains('4.432')), isEmpty);
      expect(_in(DayCard, find.byType(HourBars)), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('advanced shows the goals and the hours as before', (
      tester,
    ) async {
      await pumpApp(tester, store: await _store(simple: false));
      final texts = _texts(tester, DayCard).toList();
      expect(texts, contains('4.432 Schritte mehr als gestern um diese Zeit'));
      expect(texts, contains('von 10.000 Schritten'));
      expect(_in(DayCard, find.byType(HourBars)), findsWidgets);
    });

    testWidgets('from nine in the evening the day score is there', (
      tester,
    ) async {
      await pumpApp(
        tester,
        store: await _store(simple: true),
        now: DateTime(2026, 10, 6, 21),
      );
      expect(
        _in(DayCard, find.byKey(const ValueKey('dayScore'))),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the tiles below show one number each', (tester) async {
      await pumpApp(
        tester,
        size: const Size(412, 2600),
        store: await _store(simple: true),
      );
      // Goals: what is, not what it aims at.
      final goals = _texts(tester, GoalsCard).toList();
      expect(goals, contains('7.432'));
      expect(goals, contains('7 h 12 min'));
      expect(goals.where((text) => text.contains(' von ')), isEmpty);

      // Last night: its length, no score and no times.
      final night = _texts(tester, NightRow).toList();
      expect(night, [_de.lastNight, '7 h 12 min']);

      // The latest workout: how far it went.
      final workout = _texts(tester, WorkoutRow).toList();
      expect(workout.last, '5,60 km');
      expect(workout.where((text) => text.contains('kcal')), isEmpty);

      // What goes together: the sentence and two bars without values.
      expect(_in(LinksTile, find.byType(LinkCard)), findsOneWidget);
      final links = _texts(tester, LinksTile).toList();
      expect(links, hasLength(4));
      expect(links.where((text) => text.contains('×')), isEmpty);

      // The days before: the score on its mark, the date below.
      for (final chip in tester.widgetList<CarouselChip>(
        _in(DaysCard, find.byType(CarouselChip, skipOffstage: false)),
      )) {
        expect(chip.subtitle, isNull);
      }
      expect(
        _texts(tester, DaysCard).where((text) => text.contains('Schritte')),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the morning tile is its greeting alone', (tester) async {
      await pumpApp(
        tester,
        store: await _store(simple: true),
        now: DateTime(2026, 10, 6, 7, 30),
      );
      if (find.byType(MorningTile).evaluate().isEmpty) return;
      expect(_texts(tester, MorningTile), hasLength(1));
    });
  });

  group('Aktivität', () {
    testWidgets('the latest workout is one number and a sentence', (
      tester,
    ) async {
      await pumpApp(tester, store: await _store(simple: true));
      await _open(tester, _de.groupActivity);
      final texts = _texts(tester, LatestWorkoutCard).toList();
      expect(texts, contains('5,60 km'));
      expect(_in(LatestWorkoutCard, find.byType(FreeFigure)), findsNothing);
      // No digit in the sentence at the end.
      expect(texts.last, isNot(matches(RegExp(r'\d'))));
      for (final chip in tester.widgetList<CarouselChip>(
        _in(RecentWorkoutsCard, find.byType(CarouselChip)),
      )) {
        expect(chip.subtitle, matches(RegExp(r'^\d+ (min|h)')));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('advanced shows the row of numbers', (tester) async {
      await pumpApp(tester, store: await _store(simple: false));
      await _open(tester, _de.groupActivity);
      expect(_in(LatestWorkoutCard, find.byType(FreeFigure)), findsWidgets);
      expect(find.text(_de.stepsChartTap), findsNothing);
    });

    testWidgets('the chart names a day once a bar is tapped', (tester) async {
      await pumpApp(
        tester,
        size: const Size(412, 1800),
        store: await _store(simple: true),
      );
      await _open(tester, _de.groupActivity);
      expect(find.text(_de.stepsChartTap), findsOneWidget);
      final chart = tester.getRect(find.byType(BarChart));
      await tester.tapAt(Offset(chart.left + 20, chart.center.dy));
      await advance(tester);
      expect(find.text(_de.stepsChartTap), findsNothing);
      expect(find.textContaining('Schritte'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    test('a workout shows how far it went only where that is its point', () {
      final formats = formatsOf();
      Workout workout(WorkoutType type, double? km) => Workout(
        type: type,
        start: DateTime(2026, 10, 5, 18),
        minutes: 45,
        distanceKm: km,
      );
      expect(workoutFigure(formats, workout(WorkoutType.run, null)), '45 min');
      expect(workoutFigure(formats, workout(WorkoutType.run, 0)), '45 min');
      expect(workoutFigure(formats, workout(WorkoutType.run, 5.6)), '5,60 km');
      // The few hundred metres walked in a gym are not what it was about.
      for (final type in [
        WorkoutType.strength,
        WorkoutType.yoga,
        WorkoutType.soccer,
        WorkoutType.ski,
      ]) {
        expect(workoutFigure(formats, workout(type, 0.45)), '45 min');
      }
    });
  });

  group('Schlaf', () {
    testWidgets('the night is its score and its length', (tester) async {
      await pumpApp(tester, store: await _store(simple: true));
      await _open(tester, _de.groupSleep);
      final texts = _texts(tester, LatestNightCard).toList();
      expect(texts, contains(_de.asleepPlain));
      expect(texts.where((text) => text.contains('23:10')), isEmpty);
      expect(_in(LatestNightCard, find.byType(FreeFigure)), findsNothing);
      for (final mark in tester.widgetList<ScoreMark>(
        _in(NightsCard, find.byType(ScoreMark)),
      )) {
        expect(mark.icon, isNotNull);
      }
      expect(_texts(tester, TonightCard), contains(_de.tonightWhyPlain));
      expect(tester.takeException(), isNull);
    });

    testWidgets('advanced shows the times and the row of numbers', (
      tester,
    ) async {
      await pumpApp(tester, store: await _store(simple: false));
      await _open(tester, _de.groupSleep);
      expect(_in(LatestNightCard, find.byType(FreeFigure)), findsWidgets);
      expect(_texts(tester, TonightCard), isNot(contains(_de.tonightWhyPlain)));
    });
  });

  group('Herz', () {
    testWidgets('the day is its latest rate and its range, the zones are '
        'lines alone', (tester) async {
      await pumpApp(
        tester,
        size: const Size(412, 2600),
        store: await _store(simple: true),
      );
      await _open(tester, _de.navHeart);
      final texts = _texts(tester, HeartDayCard).toList();
      expect(texts, contains(_de.heartSoFar));
      expect(texts, contains(_de.metricHeartRate));
      expect(_in(HeartDayCard, find.byType(FreeFigure)), findsNothing);
      for (final chip in tester.widgetList<CarouselChip>(
        _in(HeartDaysCard, find.byType(CarouselChip, skipOffstage: false)),
      )) {
        expect(chip.subtitle, isNull);
      }
      expect(_texts(tester, HeartZones), [
        _de.zoneRest,
        _de.zoneLight,
        _de.zoneCardio,
        _de.zonePeak,
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('advanced shows the times and the minutes', (tester) async {
      await pumpApp(
        tester,
        size: const Size(412, 2600),
        store: await _store(simple: false),
      );
      await _open(tester, _de.navHeart);
      expect(_in(HeartDayCard, find.byType(FreeFigure)), findsWidgets);
      expect(_texts(tester, HeartZones), hasLength(8));
    });
  });

  testWidgets('the profile switches the mode, and the pages follow', (
    tester,
  ) async {
    final app = await pumpApp(tester, store: await _store(simple: true));
    await tester.tap(find.byIcon(Icons.person_rounded).first);
    await advance(tester);
    expect(find.text(_de.simpleOnNote), findsOneWidget);
    expect(find.text(_de.simpleTilesTitle), findsOneWidget);

    await tester.tap(find.text(_de.simpleOff).first);
    await advance(tester);
    expect(find.text(_de.simpleOffNote), findsOneWidget);
    expect(app.store.documents[StoreKeys.settings], contains('"simple":false'));

    Navigator.of(tester.element(find.text(_de.simpleTilesTitle))).pop();
    await advance(tester);
    expect(_texts(tester, DayCard), contains('von 10.000 Schritten'));
    expect(tester.takeException(), isNull);
  });

  for (final language in ['de', 'en', 'pl']) {
    for (final size in _sizes) {
      for (final look in ['light', 'dark', 'glass']) {
        testWidgets('the four pages render simple in $language at '
            '${size.width.round()}x${size.height.round()}, $look', (
          tester,
        ) async {
          final l10n = lookupAppLocalizations(Locale(language));
          await pumpApp(
            tester,
            size: size,
            locale: Locale(language),
            store: await _store(
              simple: true,
              more: {
                'themeMode': look == 'light' ? 'light' : 'dark',
                'liquidGlass': look == 'glass',
              },
            ),
          );
          await _scrollThrough(tester);
          for (final page in [
            l10n.groupActivity,
            l10n.groupSleep,
            l10n.navHeart,
          ]) {
            await _open(tester, page);
            await _scrollThrough(tester);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
