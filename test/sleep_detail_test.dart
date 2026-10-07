import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/snapshot_builder.dart';
import 'package:pulse/features/detail/metric_detail_page.dart';
import 'package:pulse/features/sleep/sleep_detail_page.dart';
import 'package:pulse/features/today/today_page.dart';

import 'support/fixtures.dart';

const _sizes = [Size(360, 640), Size(412, 915)];

Finder _onPage(Finder finder) =>
    find.descendant(of: find.byType(SleepDetailPage), matching: finder);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Schlaf'));
  await advance(tester);
  await tester.tap(find.text('Letzte Nacht'));
  await advance(tester);
}

/// Lays out the whole page, so an overflow anywhere on it fails the test.
Future<void> _scrollThrough(WidgetTester tester) async {
  await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
  await advance(tester);
}

void main() {
  setUpAll(loadAppFont);

  for (final size in _sizes) {
    final label = '${size.width.round()}x${size.height.round()}';

    testWidgets('the sleep tile opens the detailed page at $label', (
      tester,
    ) async {
      await pumpApp(tester, size: size);
      await _open(tester);
      expect(_onPage(find.text('Nacht auf Dienstag, 6. Oktober')), findsOne);
      // Half past seven in bed, six minutes of every 151 awake.
      expect(_onPage(find.text('7 h 30 min')), findsOne);
      expect(_onPage(find.text('7 h 12 min')), findsWidgets);
      for (final title in const [
        'Schlaf-Score',
        'Im Vergleich',
        'So schläfst du besser',
        'Nächte davor',
        'Schlafphasen',
        'Phasen im Vergleich',
        'Regelmäßigkeit',
        'Schlafschuld',
        'Puls in der Nacht',
        'Werte zur Nacht',
      ]) {
        expect(_onPage(find.text(title)), findsWidgets, reason: title);
      }
      // Behind the regularity, and as the number of all nights at the end.
      expect(_onPage(find.text('30 Nächte')), findsNWidgets(2));
      expect(
        _onPage(find.text('7 Nächte bei einem Ziel von 8,0 h je Nacht')),
        findsOne,
      );
      // The fixture has no skin temperature, so it is not listed.
      expect(_onPage(find.text('Herzfrequenzvariabilität')), findsOne);
      expect(_onPage(find.text('Hauttemperatur')), findsNothing);
      await _scrollThrough(tester);
    });

    testWidgets('a night without stages still has its page at $label', (
      tester,
    ) async {
      final nights = fixtureReadings().sleepSessions;
      await pumpApp(
        tester,
        size: size,
        repository: FixtureRepository(
          readings: RawReadings(sleepSessions: nights),
        ),
      );
      await _open(tester);
      expect(
        _onPage(
          find.text('Für diese Nacht wurden keine Schlafphasen aufgezeichnet.'),
        ),
        findsOne,
      );
      expect(_onPage(find.text('Phasen im Vergleich')), findsNothing);
      // The section and the part of the score of the same name.
      expect(_onPage(find.text('Regelmäßigkeit')), findsNWidgets(2));
      expect(_onPage(find.text('Puls in der Nacht')), findsNothing);
      expect(_onPage(find.text('Werte zur Nacht')), findsNothing);
      await _scrollThrough(tester);
    });

    testWidgets('the page renders without any data at $label', (tester) async {
      await pumpApp(
        tester,
        size: size,
        repository: FixtureRepository(readings: const RawReadings()),
      );
      await tester.tap(find.bySemanticsLabel('Schlaf'));
      await advance(tester);
      // Without a night there is nothing to tap; the page is opened as a
      // link from elsewhere would.
      expect(find.text('Keine Schlafdaten für diese Nacht.'), findsOne);
      Navigator.of(tester.element(find.text('Heute Abend'))).push(
        MaterialPageRoute<void>(
          builder: (_) => SleepDetailPage(date: DateTime(2026, 10, 6)),
        ),
      );
      await advance(tester);
      expect(
        _onPage(find.text('Keine Schlafdaten für diese Nacht.')),
        findsOne,
      );
      expect(_onPage(find.text('Schlafschuld')), findsNothing);
      expect(_onPage(find.text('Regelmäßigkeit')), findsNothing);
      await _scrollThrough(tester);
    });
  }

  testWidgets('the sleep tile on Today opens the same page', (tester) async {
    // The tile is not on the page until the user adds it.
    final store = MemoryJsonStore();
    await store.write('settings', {
      'todayTiles': ['sleep'],
      'todayTilesVersion': 2,
    });
    await pumpApp(tester, store: store);
    final tile = find.descendant(
      of: find.byType(TodayPage),
      matching: find.text('Schlaf'),
    );
    await tester.ensureVisible(tile);
    await advance(tester);
    await tester.tap(tile);
    await advance(tester);
    expect(find.byType(SleepDetailPage), findsOne);
    expect(find.byType(MetricDetailPage), findsNothing);
  });

  testWidgets('a bar of the week opens the page of its night', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Schlaf'));
    await advance(tester);
    final monday = find.text('Mo').hitTestable();
    await tester.scrollUntilVisible(
      monday,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await advance(tester);
    await tester.tap(monday);
    await advance(tester);
    expect(_onPage(find.text('Nacht auf Montag, 5. Oktober')), findsOne);
  });

  testWidgets('a back swipe closes the page', (tester) async {
    await pumpApp(tester);
    await _open(tester);
    await backGesture(tester, 'startBackGesture', 0);
    await backGesture(tester, 'updateBackGestureProgress', 0.6);
    expect(find.byType(SleepDetailPage), findsOne);
    await backGesture(tester, 'commitBackGesture');
    await advance(tester);
    expect(find.byType(SleepDetailPage), findsNothing);
    expect(find.text('Schlafphasen'), findsOne);
  });

  testWidgets('a value of the night opens its own page', (tester) async {
    await pumpApp(tester);
    await _open(tester);
    final row = _onPage(find.text('Ruhepuls'));
    await tester.ensureVisible(row);
    await advance(tester);
    await tester.tap(row);
    await advance(tester);
    expect(find.text('Gestern'), findsWidgets);
  });
}
