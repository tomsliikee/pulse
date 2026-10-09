import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app/app_scope.dart';
import 'package:pulse/data/health_history.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/snapshot_builder.dart';
import 'package:pulse/data/weather.dart';
import 'package:pulse/features/morning/morning_cards.dart';
import 'package:pulse/features/morning/morning_page.dart';
import 'package:pulse/features/morning/morning_scene.dart';
import 'package:pulse/features/morning/morning_tile.dart';
import 'package:pulse/features/profile/profile_page.dart';
import 'package:pulse/l10n/generated/app_localizations.dart';

import 'support/fixtures.dart';

const _sizes = [Size(360, 640), Size(412, 915)];

/// Twenty minutes after the fixture's night ended.
final _morning = DateTime(2026, 10, 6, 7);

/// A store whose saved settings are [settings].
Future<MemoryJsonStore> _storeWith(Map<String, Object?> settings) async {
  final store = MemoryJsonStore();
  await store.write(StoreKeys.settings, settings);
  return store;
}

Future<void> _next(WidgetTester tester, AppLocalizations l10n) async {
  await tester.tap(find.text(l10n.morningNext));
  await advance(tester);
}

void main() {
  setUpAll(loadAppFont);

  for (final language in ['de', 'en', 'pl']) {
    for (final size in _sizes) {
      for (final look in ['light', 'dark', 'glass']) {
        testWidgets('the morning opens by itself and shows every card in '
            '$language at ${size.width.round()}x${size.height.round()}, '
            '$look', (tester) async {
          final l10n = lookupAppLocalizations(Locale(language));
          await pumpApp(
            tester,
            size: size,
            locale: Locale(language),
            now: _morning,
            store: await _storeWith({
              'name': 'Thomas',
              'place': fixturePlace.toJson(),
              'themeMode': look == 'dark' ? 'dark' : 'light',
              'liquidGlass': look == 'glass',
            }),
          );
          final page = find.byType(MorningPage);
          expect(page, findsOneWidget);
          expect(find.text(l10n.morningGreetingName('Thomas')), findsOneWidget);
          expect(find.byType(MorningScene), findsOneWidget);
          expect(tester.takeException(), isNull);

          for (final card in [
            SleepCard,
            RecoveryCard,
            WeatherCard,
            MorningGoalsCard,
            TonightCard,
          ]) {
            await _next(tester, l10n);
            expect(find.byType(card), findsOneWidget, reason: '$card');
            // Down to the end of the card, where a small phone scrolls.
            await tester.drag(
              find.descendant(
                of: find.byType(card),
                matching: find.byType(SingleChildScrollView),
              ),
              const Offset(0, -2000),
            );
            await advance(tester);
            expect(tester.takeException(), isNull, reason: '$card');
          }

          // The last card ends the morning.
          expect(find.text(l10n.morningNext), findsNothing);
          await tester.tap(find.text(l10n.morningDone));
          await advance(tester);
          expect(page, findsNothing);
          expect(find.byType(MorningTile), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('it opens once a day, and the tile brings it back', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('de'));
    final app = await pumpApp(tester, now: _morning);
    expect(find.byType(MorningPage), findsOneWidget);
    // Without a name the greeting stands alone; without a place there is
    // no weather card and a hint where to set one.
    expect(find.text(l10n.morningTitle), findsOneWidget);
    expect(find.text(l10n.weatherNoPlace), findsOneWidget);
    await tester.tap(find.byTooltip(l10n.close));
    await advance(tester);
    expect(find.byType(MorningPage), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(
      await app.store.read(StoreKeys.settings),
      containsPair('morningSeen', dayKey(_morning)),
    );

    // Another start of the same morning.
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, now: _morning, store: app.store);
    expect(find.byType(MorningPage), findsNothing);

    await tester.tap(find.byType(MorningTile));
    await advance(tester);
    expect(find.byType(MorningPage), findsOneWidget);
    for (var card = 0; card < 3; card++) {
      await _next(tester, l10n);
    }
    // Sleep, recovery, then the goals: no weather without a place.
    expect(find.byType(MorningGoalsCard), findsOneWidget);
    expect(find.byType(WeatherCard, skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('it stays shut before the night ended, after three hours and '
      'when switched off', (tester) async {
    for (final now in [
      DateTime(2026, 10, 6, 6, 30),
      DateTime(2026, 10, 6, 9, 50),
      fixtureNow,
    ]) {
      await pumpApp(tester, now: now);
      expect(find.byType(MorningPage), findsNothing, reason: '$now');
      // The way to it is there all day.
      expect(find.byType(MorningTile), findsOneWidget, reason: '$now');
      await tester.pumpWidget(const SizedBox());
    }

    await pumpApp(
      tester,
      now: _morning,
      store: await _storeWith({'morningBrief': false}),
    );
    expect(find.byType(MorningPage), findsNothing);
    expect(find.byType(MorningTile), findsNothing);
  });

  testWidgets('without a night it still opens and says the night is missing', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('de'));
    await pumpApp(
      tester,
      now: DateTime(2026, 10, 6, 5),
      repository: FixtureRepository(readings: const RawReadings()),
    );
    expect(find.byType(MorningPage), findsOneWidget);
    await _next(tester, l10n);
    expect(find.byType(SleepCard), findsOneWidget);
    expect(find.textContaining(l10n.morningNoNight), findsOneWidget);
    // Nothing to judge a recovery by: the goals come next.
    await _next(tester, l10n);
    expect(find.byType(MorningGoalsCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the weather card says when the service cannot be reached, and '
      'the scene follows the sky', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('de'));
    final weather = FixtureWeather(reachable: false);
    final settings = {'place': fixturePlace.toJson()};
    await pumpApp(
      tester,
      now: _morning,
      weather: weather,
      store: await _storeWith(settings),
    );
    expect(weather.asked, 1);
    expect(tester.widget<MorningScene>(find.byType(MorningScene)).sky, isNull);
    for (var card = 0; card < 3; card++) {
      await _next(tester, l10n);
    }
    expect(find.text(l10n.weatherUnavailable), findsOneWidget);

    for (final sky in Sky.values) {
      await tester.pumpWidget(const SizedBox());
      await pumpApp(
        tester,
        now: _morning,
        weather: FixtureWeather(sky: sky),
        store: await _storeWith(settings),
      );
      expect(tester.widget<MorningScene>(find.byType(MorningScene)).sky, sky);
      expect(tester.takeException(), isNull, reason: '$sky');
    }
  });

  testWidgets('the scene moves, and stands still when animations are off', (
    tester,
  ) async {
    await tester.pumpWidget(themed(const MorningScene(sky: Sky.rain)));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(
      themed(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MorningScene(sky: Sky.rain),
        ),
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  for (final language in ['de', 'en', 'pl']) {
    for (final size in _sizes) {
      testWidgets('the profile takes a name and a place in $language at '
          '${size.width.round()}', (tester) async {
        final l10n = lookupAppLocalizations(Locale(language));
        final weather = FixtureWeather();
        await pumpApp(
          tester,
          size: size,
          locale: Locale(language),
          weather: weather,
        );
        await tester.tap(find.bySemanticsLabel(l10n.profile));
        await advance(tester);
        final settings = AppScope.of(tester.element(find.byType(ProfilePage)))
            .settings;

        await tapInView(tester, find.text(l10n.nameLabel));
        await tester.enterText(find.byType(TextField), '  Thomas ');
        await tester.tap(find.text(l10n.save));
        await advance(tester);
        expect(settings.name, 'Thomas');
        expect(find.text('Thomas'), findsOneWidget);

        // Nothing has asked the network so far.
        expect(weather.asked, 0);
        await tapInView(tester, find.text(l10n.placeLabel));
        expect(find.text(l10n.placeNote), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Nirgendwo');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await advance(tester);
        expect(find.text(l10n.placeNoResults), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Wien');
        await tester.tap(find.byTooltip(l10n.placeSearch));
        await advance(tester);
        expect(weather.searches, ['Nirgendwo', 'Wien']);
        await tester.tap(find.text(fixturePlace.region!));
        await advance(tester);
        expect(settings.place, fixturePlace);
        expect(weather.asked, 1);
        expect(tester.takeException(), isNull);

        // The place can be taken away again, and the weather goes with it.
        await tapInView(tester, find.text(l10n.placeLabel));
        await tester.tap(find.text(l10n.placeRemove));
        await advance(tester);
        expect(settings.place, isNull);
        expect(
          AppScope.of(tester.element(find.byType(ProfilePage))).weather.weather,
          isNull,
        );

        await tapInView(tester, find.text(l10n.morningSwitchNote));
        final toggle = find.descendant(
          of: find.ancestor(
            of: find.text(l10n.morningSwitchNote),
            matching: find.byType(Row),
          ),
          matching: find.byType(Switch),
        );
        await tester.tap(toggle);
        await advance(tester);
        expect(settings.morningBrief, isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
