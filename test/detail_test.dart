import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/metric_catalog.dart';
import 'package:pulse/data/snapshot_builder.dart';
import 'package:pulse/features/detail/metric_detail_page.dart';

import 'support/fixtures.dart';

const _tabs = ['Heute', 'Gestern', 'Woche', 'Monat', 'Jahr', 'Gesamt'];

Future<void> _openSteps(WidgetTester tester) async {
  // The hero tile on Today is the steps tile.
  await tester.tap(find.text('7.432'));
  await advance(tester);
  expect(find.text('Schritte'), findsWidgets);
}

Future<void> _tab(WidgetTester tester, String label) async {
  final tab = find.text(label).hitTestable();
  await tester.ensureVisible(tab.first);
  await tester.pump();
  await tester.tap(tab.first);
  await advance(tester);
}

FixtureRepository _withTwoYears() => FixtureRepository()
  ..historyAccess = true
  ..olderDays = fixtureOlderDays();

void main() {
  setUpAll(loadAppFont);

  for (final size in const [Size(360, 640), Size(412, 915)]) {
    final label = '${size.width.round()}x${size.height.round()}';

    testWidgets('every tab renders with two years of data at $label', (
      tester,
    ) async {
      await pumpApp(tester, size: size, repository: _withTwoYears());
      await _openSteps(tester);
      for (final tab in _tabs) {
        await _tab(tester, tab);
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -2000),
        );
        await advance(tester);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 2000));
        await advance(tester);
      }
    });

    testWidgets('every tab renders without any data at $label', (tester) async {
      await pumpApp(
        tester,
        size: size,
        repository: FixtureRepository(readings: const RawReadings()),
      );
      await tester.ensureVisible(find.text('Wasser'));
      await advance(tester);
      await tester.tap(find.text('Wasser'));
      await advance(tester);
      for (final tab in _tabs) {
        await _tab(tester, tab);
      }
      expect(find.text('Keine Daten in diesem Zeitraum.'), findsOneWidget);
    });
  }

  testWidgets('the tabs change the number, its label and the span', (
    tester,
  ) async {
    await pumpApp(tester, repository: _withTwoYears());
    await _openSteps(tester);
    // The Today page stays built beneath this one, so only what can be
    // touched counts.

    expect(find.text('7.432 Schritte').hitTestable(), findsOneWidget);
    expect(find.text('Dienstag, 6. Oktober').hitTestable(), findsOneWidget);

    await _tab(tester, 'Gestern');
    expect(find.text('Montag, 5. Oktober').hitTestable(), findsOneWidget);
    expect(find.text('7.432 Schritte').hitTestable(), findsNothing);

    await _tab(tester, 'Woche');
    expect(find.text('Wochenschnitt pro Tag').hitTestable(), findsOneWidget);
    expect(find.text('5.10. bis 11.10.').hitTestable(), findsOneWidget);
    expect(find.textContaining('als in der Woche davor'), findsOneWidget);

    await _tab(tester, 'Monat');
    expect(find.text('Monatsschnitt pro Tag').hitTestable(), findsOneWidget);
    expect(find.text('Oktober 2026').hitTestable(), findsWidgets);

    await _tab(tester, 'Jahr');
    expect(find.text('Jahresschnitt pro Tag').hitTestable(), findsOneWidget);
    expect(find.text('2026').hitTestable(), findsWidgets);

    await _tab(tester, 'Gesamt');
    expect(find.text('2024 bis 2026').hitTestable(), findsWidgets);
  });

  testWidgets('the arrows page back and stop at the present', (tester) async {
    await pumpApp(tester, repository: _withTwoYears());
    await _openSteps(tester);
    await _tab(tester, 'Monat');

    IconButton later() => tester.widget(
      find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
    );
    expect(later().onPressed, isNull, reason: 'nothing after this month');

    await tester.tap(find.byTooltip('Früher'));
    await advance(tester);
    expect(find.text('September 2026'), findsWidgets);
    expect(later().onPressed, isNotNull);

    await tester.tap(find.byTooltip('Später'));
    await advance(tester);
    expect(find.text('Oktober 2026'), findsWidgets);
  });

  testWidgets('paging back stops at the oldest collected day', (tester) async {
    // No older data: the archive starts with the live window, 7 September.
    await pumpApp(tester);
    await _openSteps(tester);
    await _tab(tester, 'Monat');

    await tester.tap(find.byTooltip('Früher'));
    await advance(tester);
    expect(find.text('September 2026'), findsWidgets);
    final earlier = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_left_rounded),
    );
    expect(earlier.onPressed, isNull);
  });

  testWidgets('tapping a bar shows that day', (tester) async {
    await pumpApp(tester);
    await _openSteps(tester);
    await _tab(tester, 'Woche');

    await tester.tap(find.text('Mo').hitTestable());
    await advance(tester);

    expect(find.text('Montag, 5. Oktober').hitTestable(), findsOneWidget);
    expect(find.text('Wochenschnitt pro Tag'), findsNothing);
  });

  testWidgets('a day without a reading shows the latest one with its day', (
    tester,
  ) async {
    await pumpApp(
      tester,
      size: const Size(412, 915),
      repository: FixtureRepository(
        readings: RawReadings(
          samples: [
            RawSample(
              Metric.weight,
              fixtureNow.subtract(const Duration(days: 3)),
              73.5,
            ),
          ],
        ),
      ),
    );
    await tester.ensureVisible(find.text('Gewicht'));
    await advance(tester);
    await tester.tap(find.text('Gewicht'));
    await advance(tester);

    expect(find.textContaining('Zuletzt gemessen: '), findsOneWidget);
    expect(find.text('73,5 kg'), findsOneWidget);
    expect(find.text('Keine Daten an diesem Tag.'), findsNothing);
  });

  testWidgets('a back swipe shrinks the page, and letting go decides', (
    tester,
  ) async {
    await pumpApp(tester);
    await _openSteps(tester);
    final page = find.byType(MetricDetailPage);
    expect(tester.getRect(page), const Rect.fromLTWH(0, 0, 412, 915));

    await backGesture(tester, 'startBackGesture', 0);
    await backGesture(tester, 'updateBackGestureProgress', 1);
    final pulled = tester.getRect(page);
    expect(pulled.width, moreOrLessEquals(412 * 0.9));
    expect(pulled.height, moreOrLessEquals(915 * 0.9));
    // Pushed away from the left edge, where the finger came from.
    expect(pulled.center.dx, greaterThan(206));
    // The Today page beneath is still there to be seen.
    expect(find.text('7.432'), findsWidgets);

    await backGesture(tester, 'cancelBackGesture');
    await advance(tester);
    expect(tester.getRect(page), const Rect.fromLTWH(0, 0, 412, 915));

    await backGesture(tester, 'startBackGesture', 0);
    await backGesture(tester, 'updateBackGestureProgress', 0.6);
    await backGesture(tester, 'commitBackGesture');
    await advance(tester);
    expect(page, findsNothing);
  });
}
