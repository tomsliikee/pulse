import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/widgets/chip_carousel.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/snapshot_builder.dart';
import 'package:pulse/features/sleep/night_list_page.dart';
import 'package:pulse/features/sleep/night_tiles.dart';
import 'package:pulse/features/sleep/sleep_detail_page.dart';
import 'package:pulse/features/sleep/sleep_scene.dart';
import 'package:pulse/features/sleep/sleep_stages_chart.dart';
import 'package:pulse/l10n/generated/app_localizations.dart';
import 'package:pulse/widgets/day_switcher.dart';
import 'package:pulse/widgets/floating_surface.dart';

import 'support/fixtures.dart';

const _sizes = [Size(360, 640), Size(412, 915)];

Future<void> _openSleep(WidgetTester tester, AppLocalizations l10n) async {
  await tester.tap(find.bySemanticsLabel(l10n.groupSleep));
  await advance(tester);
}

final AppLocalizations _de = lookupAppLocalizations(const Locale('de'));

void main() {
  setUpAll(loadAppFont);

  testWidgets('the sleep page starts with the latest night, then the five '
      'before it, then tonight', (tester) async {
    await pumpApp(tester);
    await _openSleep(tester, _de);

    expect(
      find.descendant(
        of: find.byType(LatestNightCard),
        matching: find.byType(SleepScene),
      ),
      findsOneWidget,
    );
    expect(find.text('Letzte Nacht'), findsOneWidget);
    expect(find.text('Nacht auf Dienstag, 6. Oktober'), findsOneWidget);
    final latest = tester.getRect(find.byType(LatestNightCard));
    final more = tester.getRect(find.byType(NightsCard));
    expect(more.top, greaterThan(latest.bottom));
    expect(
      find.descendant(
        of: find.byType(NightsCard),
        matching: find.byType(CarouselChip, skipOffstage: false),
      ),
      findsNWidgets(5),
    );
    final tonight = find.byType(TonightCard, skipOffstage: false);
    await tester.ensureVisible(tonight);
    await advance(tester);
    expect(
      tester.getRect(tonight).top,
      greaterThan(tester.getRect(find.byType(NightsCard)).bottom - 1),
    );
    // Up at 06:45 on average, eight hours of sleep, and half an hour for a
    // week that stayed under the goal.
    expect(find.text('Um 22:15 ins Bett'), findsOneWidget);
  });

  testWidgets('without a night the page says so and suggests no bedtime', (
    tester,
  ) async {
    await pumpApp(
      tester,
      repository: FixtureRepository(readings: const RawReadings()),
    );
    await _openSleep(tester, _de);
    expect(find.byType(SleepScene), findsNothing);
    expect(find.byType(NightsCard), findsNothing);
    expect(find.text('Keine Schlafdaten für diese Nacht.'), findsOneWidget);
    expect(
      find.text('Nach drei Nächten kann Pulse eine Schlafenszeit vorschlagen.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a night of the list opens its own page, with the three '
      'nights before it at the end', (tester) async {
    await pumpApp(tester);
    await _openSleep(tester, _de);
    // The second row: the night that ended on Sunday.
    await tester.tap(find.text('So, 4.10.'));
    await advance(tester);

    final page = find.byType(SleepDetailPage);
    expect(
      find.descendant(
        of: page,
        matching: find.text('Nacht auf Sonntag, 4. Oktober'),
      ),
      findsOneWidget,
    );
    await tester.drag(
      find.descendant(of: page, matching: find.byType(CustomScrollView)),
      const Offset(0, -9000),
    );
    await advance(tester);
    final below = find.descendant(
      of: page,
      matching: find.byType(CarouselChip, skipOffstage: false),
    );
    expect(below, findsNWidgets(3));
    expect(
      find.descendant(of: page, matching: find.text('Sa, 3.10.')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: page, matching: find.text('Mo, 5.10.')),
      findsNothing,
    );

    // From there on to the night before, and to all of them.
    await tester.tap(
      find.descendant(of: page, matching: find.text('Sa, 3.10.')),
    );
    await advance(tester);
    expect(find.text('Nacht auf Samstag, 3. Oktober'), findsOneWidget);
    await tester.drag(
      find.descendant(
        of: find.byType(SleepDetailPage).last,
        matching: find.byType(CustomScrollView),
      ),
      const Offset(0, -9000),
    );
    await advance(tester);
    // The way to all of them is the last card of the carousel.
    await tapInView(tester, find.text('Alle Nächte').last);
    expect(find.byType(NightListPage), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NightListPage),
        matching: find.text('Oktober 2026'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the score is shown with its four parts', (tester) async {
    await pumpApp(tester);
    await _openSleep(tester, _de);
    await tester.tap(find.text('Letzte Nacht'));
    await advance(tester);
    final page = find.byType(SleepDetailPage);
    Finder onPage(String text) =>
        find.descendant(of: page, matching: find.text(text));
    expect(onPage('Schlaf-Score'), findsOneWidget);
    for (final part in const [
      'Schlafdauer',
      'Tief- und REM-Schlaf',
      'Effizienz',
    ]) {
      expect(onPage(part), findsWidgets, reason: part);
    }
    expect(onPage('36 von 40'), findsOneWidget);
    expect(onPage('20 von 20'), findsOneWidget);
    expect(onPage('15 von 15'), findsOneWidget);
  });

  testWidgets('a night without stages has a score from what there is', (
    tester,
  ) async {
    await pumpApp(
      tester,
      repository: FixtureRepository(
        readings: RawReadings(sleepSessions: fixtureReadings().sleepSessions),
      ),
    );
    await _openSleep(tester, _de);
    await tester.tap(find.text('Letzte Nacht'));
    await advance(tester);
    final page = find.byType(SleepDetailPage);
    expect(
      find.descendant(of: page, matching: find.text('nicht gewertet')),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: page, matching: find.byType(SleepStagesChart)),
      findsNothing,
    );
  });

  testWidgets('a finger on the stages names the block under it', (
    tester,
  ) async {
    await pumpApp(tester);
    await _openSleep(tester, _de);
    await tester.tap(find.text('Letzte Nacht'));
    await advance(tester);
    final chart = find.descendant(
      of: find.byType(SleepDetailPage),
      matching: find.byType(SleepStagesChart),
    );
    await tester.ensureVisible(chart);
    await advance(tester);
    // Away from the top, where the back button floats over the page.
    await tester.drag(
      find.descendant(
        of: find.byType(SleepDetailPage),
        matching: find.byType(CustomScrollView),
      ),
      const Offset(0, 220),
    );
    await advance(tester);
    // Before a touch the line says when the night was.
    expect(
      find.descendant(of: chart, matching: find.text('23:10 bis 06:40')),
      findsOneWidget,
    );
    final lanes = tester.getRect(
      find.descendant(of: chart, matching: find.byType(GestureDetector)),
    );
    // The night begins with six minutes awake.
    await tester.tapAt(lanes.topLeft + const Offset(1, 20));
    await advance(tester);
    expect(
      find.descendant(
        of: chart,
        matching: find.text('Wach · 23:10 bis 23:16 · 6 min'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the bar of a night leads to the night before, and its menu to '
      'older nights and to all of them', (tester) async {
    await pumpApp(tester);
    await _openSleep(tester, _de);
    await tester.tap(find.text('Letzte Nacht'));
    await advance(tester);
    final page = find.byType(SleepDetailPage);
    Finder onPage(String text) => find.descendant(
      of: page,
      matching: find.text(text, skipOffstage: false),
    );
    final bar = find.descendant(of: page, matching: find.byType(DaySwitcher));
    Finder tab(String label) =>
        find.descendant(of: bar, matching: find.bySemanticsLabel(label));
    expect(onPage('Nacht auf Dienstag, 6. Oktober'), findsOneWidget);

    await tester.tap(tab('Gestern'));
    await advance(tester);
    expect(onPage('Nacht auf Montag, 5. Oktober'), findsOneWidget);

    final surfaces = find.byType(FloatingSurface).evaluate().length;
    await tester.tap(tab('Weitere'));
    await advance(tester);
    // Six pills of their own: five days and the way to all.
    expect(find.byType(FloatingSurface).evaluate().length - surfaces, 6);
    await tester.tap(find.widgetWithText(FloatingSurface, 'Fr, 2.10.'));
    await advance(tester);
    expect(onPage('Nacht auf Freitag, 2. Oktober'), findsOneWidget);
    await tester.tap(tab('Fr, 2.10.'));
    await advance(tester);
    await tester.tap(find.widgetWithText(FloatingSurface, 'Alle Nächte'));
    await advance(tester);
    expect(find.byType(NightListPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the night tiles can be removed and brought back', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await _openSleep(tester, _de);
    await tester.tap(find.byTooltip('Kacheln anordnen'));
    await advance(tester);
    await tester.tap(find.byIcon(Icons.remove_rounded).first);
    await advance(tester);
    expect(find.byType(LatestNightCard), findsNothing);
    expect(app.store.documents['settings'], contains('hero'));

    await tester.drag(find.byType(ListView).first, const Offset(0, -9000));
    await advance(tester);
    await tester.tap(find.text('Letzte Nacht'));
    await advance(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, 9000));
    await advance(tester);
    expect(find.byType(LatestNightCard), findsOneWidget);
  });

  testWidgets('with an order saved before, the new tiles follow the latest '
      'night', (tester) async {
    final store = MemoryJsonStore();
    await store.write(StoreKeys.settings, {
      'tileOrder': {
        'sleep': ['week', 'hero', 'stages'],
      },
    });
    await pumpApp(tester, store: store);
    await _openSleep(tester, _de);
    final week = tester.getRect(find.text('Diese Woche'));
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await advance(tester);
    final latest = tester.getRect(
      find.byType(LatestNightCard, skipOffstage: false),
    );
    final more = tester.getRect(find.byType(NightsCard, skipOffstage: false));
    final tonight = tester.getRect(
      find.byType(TonightCard, skipOffstage: false),
    );
    expect(week.top, lessThan(latest.top + 500));
    expect(more.top, greaterThan(latest.bottom - 1));
    expect(tonight.top, greaterThan(more.bottom - 1));
  });

  for (final language in ['de', 'en', 'pl']) {
    for (final size in _sizes) {
      final label = '$language at ${size.width.round()}x${size.height.round()}';

      testWidgets('the sleep pages render in $label', (tester) async {
        final l10n = lookupAppLocalizations(Locale(language));
        // Nights of every kind: good, short, restless, late and one
        // without stages, so every hint and every row has to fit.
        final sessions = <RawSleepSession>[];
        final stages = <RawSleepStage>[];
        for (var ago = 12; ago >= 0; ago--) {
          final late = ago % 4 == 0;
          final start = DateTime(
            fixtureNow.year,
            fixtureNow.month,
            fixtureNow.day - ago - 1,
            late ? 23 : 21,
            late ? 55 : 30 + ago,
          ).add(Duration(hours: late ? 2 : 0));
          final end = start.add(Duration(minutes: ago.isEven ? 330 : 500));
          sessions.add(RawSleepSession(start, end));
          if (ago == 5) continue;
          var cursor = start;
          for (final (stage, minutes) in [
            (SleepStage.awake, ago.isEven ? 50 : 8),
            (SleepStage.light, 120),
            (SleepStage.deep, ago.isEven ? 20 : 90),
            (SleepStage.rem, 60),
            (SleepStage.awake, ago.isEven ? 40 : 4),
            (SleepStage.light, 40),
          ]) {
            final next = cursor.add(Duration(minutes: minutes));
            stages.add(RawSleepStage(stage, cursor, next));
            cursor = next;
          }
        }
        await pumpApp(
          tester,
          size: size,
          locale: Locale(language),
          repository: FixtureRepository(
            readings: RawReadings(sleepSessions: sessions, sleepStages: stages),
          ),
        );
        await _openSleep(tester, l10n);
        await tester.drag(find.byType(ListView).first, const Offset(0, -9000));
        await advance(tester);
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView).first, const Offset(0, 9000));
        await advance(tester);

        final navigator = Navigator.of(
          tester.element(find.byType(LatestNightCard)),
        );
        for (var ago = 0; ago <= 12; ago++) {
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => SleepDetailPage(
                date: DateTime(
                  fixtureNow.year,
                  fixtureNow.month,
                  fixtureNow.day - ago,
                ),
              ),
            ),
          );
          await advance(tester);
          final page = find.byType(SleepDetailPage);
          expect(
            find.descendant(of: page, matching: find.text(l10n.scoreTitle)),
            findsOneWidget,
            reason: '$ago',
          );
          await tester.drag(
            find.descendant(of: page, matching: find.byType(CustomScrollView)),
            const Offset(0, -9000),
          );
          await advance(tester);
          expect(tester.takeException(), isNull, reason: '$ago');
          navigator.pop();
          await advance(tester);
        }

        navigator.push(
          MaterialPageRoute<void>(builder: (_) => const NightListPage()),
        );
        await advance(tester);
        await tester.drag(
          find.descendant(
            of: find.byType(NightListPage),
            matching: find.byType(CustomScrollView),
          ),
          const Offset(0, -9000),
        );
        await advance(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the scene moves for every kind of night, and stands still '
      'when animations are off', (tester) async {
    final good = buildSnapshot(
      now: fixtureNow,
      raw: fixtureReadings(),
    ).nights.last!;
    for (final (night, score) in [
      (good, 94),
      (good.summary, 40),
      (
        SleepNight(
          date: good.date,
          bedtimeMinute: 60,
          totalMinutes: 300,
          segments: const [],
        ),
        20,
      ),
    ]) {
      await tester.pumpWidget(
        themed(
          Scaffold(
            body: SleepScene(night: night, score: score),
          ),
        ),
      );
      // Through a whole night and into the next.
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
          child: Scaffold(body: SleepScene(night: good, score: 94)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
