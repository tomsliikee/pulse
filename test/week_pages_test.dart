import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/health_history.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/links.dart';
import 'package:pulse/data/snapshot_builder.dart';
import 'package:pulse/features/links/link_card.dart';
import 'package:pulse/features/links/links_page.dart';
import 'package:pulse/features/links/links_tile.dart';
import 'package:pulse/features/today/day_detail_page.dart';
import 'package:pulse/features/week/week_page.dart';
import 'package:pulse/features/week/week_scene.dart';
import 'package:pulse/features/week/week_tile.dart';
import 'package:pulse/l10n/generated/app_localizations.dart';

import 'support/fixtures.dart';

const _sizes = [Size(360, 640), Size(412, 915)];

/// Monday noon: the report of the week before is ready, the morning over.
final _monday = DateTime(2026, 10, 5, 12);

/// A store whose saved settings are [settings]. The morning's cards were
/// seen, so they do not open over the page.
Future<MemoryJsonStore> _storeWith(
  DateTime now, [
  Map<String, Object?> settings = const {},
]) async {
  final store = MemoryJsonStore();
  await store.write(StoreKeys.settings, {
    'morningSeen': dayKey(now),
    ...settings,
  });
  return store;
}

/// Scrolls the open sub page to its end and back to the top.
Future<void> _scrollThrough(WidgetTester tester, Type page) async {
  final scroll = find
      .descendant(of: find.byType(page), matching: find.byType(Scrollable))
      .first;
  for (var i = 0; i < 6; i++) {
    await tester.drag(scroll, const Offset(0, -500));
    await advance(tester);
    expect(tester.takeException(), isNull);
  }
  await tester.drag(scroll, const Offset(0, 4000));
  await advance(tester);
}

void main() {
  setUpAll(loadAppFont);

  for (final language in ['de', 'en', 'pl']) {
    for (final size in _sizes) {
      for (final look in ['light', 'dark', 'glass']) {
        testWidgets('the tile opens the report, and the report the '
            'connections, in $language at '
            '${size.width.round()}x${size.height.round()}, $look', (
          tester,
        ) async {
          final l10n = lookupAppLocalizations(Locale(language));
          await pumpApp(
            tester,
            size: size,
            locale: Locale(language),
            now: _monday,
            store: await _storeWith(_monday, {
              'themeMode': look == 'dark' ? 'dark' : 'light',
              'liquidGlass': look == 'glass',
            }),
          );
          expect(find.text(l10n.weekTileReady), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tapInView(tester, find.byType(WeekTile));
          expect(find.byType(WeekPage), findsOneWidget);
          expect(find.byType(WeekScene), findsOneWidget);
          expect(find.text(l10n.weekScore), findsOneWidget);
          expect(find.text(l10n.weekCompareTitle), findsOneWidget);
          expect(tester.takeException(), isNull);
          await _scrollThrough(tester, WeekPage);

          // The strongest connections stand in the report, the rest behind
          // the row below them.
          expect(
            find.descendant(
              of: find.byType(WeekPage),
              matching: find.byType(LinkCard, skipOffstage: false),
            ),
            findsAtLeast(1),
          );
          await tapInView(tester, find.text(l10n.linksAll));
          expect(find.byType(LinksPage), findsOneWidget);
          expect(find.byType(LinkCard), findsAtLeast(1));
          expect(tester.takeException(), isNull);
          await _scrollThrough(tester, LinksPage);
          expect(
            find.text(l10n.linksPageNote, skipOffstage: false),
            findsOneWidget,
          );
        });
      }
    }
  }

  testWidgets('a connection shows its sentence, both sides and their days', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      themed(
        const SingleChildScrollView(
          child: LinkCard(
            link: Link(
              kind: LinkKind.dayToNight,
              cause: LinkCause.intensity,
              split: LinkSplit.goal,
              effect: LinkEffect.bedtime,
              withMean: 23 * 60 + 5,
              withoutMean: 24 * 60 + 20,
              countWith: 14,
              countWithout: 61,
              strength: 1.2,
            ),
          ),
        ),
      ),
    );
    await advance(tester);
    expect(
      find.text(
        'Nach Tagen über deinem Ziel für aktive Minuten gehst du im Schnitt '
        '1 h 15 min früher ins Bett.',
      ),
      findsOneWidget,
    );
    expect(find.text('Solche Tage · 14×'), findsOneWidget);
    expect(find.text('Andere Tage · 61×'), findsOneWidget);
    expect(find.text('23:05'), findsOneWidget);
    expect(find.text('00:20'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the report pages back through the weeks and not past today', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('de'));
    await pumpApp(tester, now: _monday, store: await _storeWith(_monday));
    await tapInView(tester, find.byType(WeekTile));
    final formats = formatsOf();
    String range(DateTime monday) => formats.dayRange(
      monday,
      DateTime(monday.year, monday.month, monday.day + 6),
    );
    final shown = DateTime(2026, 9, 28);
    expect(find.text(range(shown)), findsNWidgets(2));

    await tester.tap(find.byTooltip(l10n.weekOlder));
    await advance(tester);
    expect(find.text(range(DateTime(2026, 9, 21))), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    // Forward again, and on to the week that is running.
    await tester.tap(find.byTooltip(l10n.weekNewer));
    await advance(tester);
    await tester.tap(find.byTooltip(l10n.weekNewer));
    await advance(tester);
    expect(find.text(range(DateTime(2026, 10, 5))), findsNWidgets(2));
    expect(find.text(l10n.weekRunning), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byIcon(Icons.chevron_right_rounded).last,
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the best day opens its page', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('de'));
    await pumpApp(tester, now: _monday, store: await _storeWith(_monday));
    await tapInView(tester, find.byType(WeekTile));
    await tapInView(tester, find.text(l10n.weekBestDay));
    expect(find.byType(DayDetailPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a week without data says so', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('de'));
    await pumpApp(
      tester,
      now: _monday,
      repository: FixtureRepository(readings: const RawReadings()),
      store: await _storeWith(_monday),
    );
    await tapInView(tester, find.byType(WeekTile));
    expect(find.text(l10n.weekEmpty), findsOneWidget);
    expect(find.byType(WeekScene), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without enough nights the connections say how many there are', (
    tester,
  ) async {
    final l10n = lookupAppLocalizations(const Locale('de'));
    await pumpApp(
      tester,
      now: _monday,
      repository: FixtureRepository(readings: const RawReadings()),
      store: await _storeWith(_monday),
    );
    expect(find.text(l10n.linksTileEmpty, skipOffstage: false), findsOneWidget);
    await tapInView(tester, find.byType(LinksTile, skipOffstage: false));
    expect(find.byType(LinksPage), findsOneWidget);
    expect(find.text(l10n.linksEmptyFew(0)), findsOneWidget);
    expect(find.byType(LinkCard), findsNothing);
    // The report is reachable from here all week.
    await tester.tap(find.text(l10n.weekLatest));
    await advance(tester);
    expect(find.byType(WeekPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the tile comes on Sunday evening and goes when Monday ends, '
      'with the page open', (tester) async {
    var now = DateTime(2026, 10, 4, 18, 59);
    final store = await _storeWith(now, {
      'morningSeen': dayKey(DateTime(2026, 10, 5)),
    });
    await pumpApp(tester, clock: () => now, store: store);
    expect(find.byType(WeekTile), findsNothing);
    // The connections are there on every day.
    expect(find.byType(LinksTile, skipOffstage: false), findsOneWidget);

    now = DateTime(2026, 10, 4, 19);
    await tester.pump(const Duration(minutes: 1));
    await advance(tester);
    expect(find.byType(WeekTile), findsOneWidget);

    now = DateTime(2026, 10, 5, 23, 59);
    await tester.pump(const Duration(hours: 28, minutes: 59));
    await advance(tester);
    expect(find.byType(WeekTile), findsOneWidget);

    now = DateTime(2026, 10, 6);
    await tester.pump(const Duration(minutes: 1));
    await advance(tester);
    expect(find.byType(WeekTile), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switched off there is no tile', (tester) async {
    await pumpApp(
      tester,
      now: _monday,
      store: await _storeWith(_monday, {'weekReport': false}),
    );
    expect(find.byType(WeekTile), findsNothing);
  });

  testWidgets('settings saved before the tiles existed get both once', (
    tester,
  ) async {
    final app = await pumpApp(
      tester,
      now: _monday,
      store: await _storeWith(_monday, {
        'todayTiles': ['hero', 'morning', 'tips', 'goals', 'steps'],
        'todayTilesVersion': 3,
      }),
    );
    expect(find.byType(WeekTile), findsOneWidget);
    expect(find.byType(LinksTile, skipOffstage: false), findsOneWidget);
    // Removed, it stays away.
    final later = MemoryJsonStore();
    await later.write(StoreKeys.settings, {
      'morningSeen': dayKey(_monday),
      'todayTiles': ['hero', 'steps'],
      'todayTilesVersion': 4,
    });
    expect(app.store, isNotNull);
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, now: _monday, store: later);
    expect(find.byType(WeekTile), findsNothing);
    expect(find.byType(LinksTile, skipOffstage: false), findsNothing);
  });
}
