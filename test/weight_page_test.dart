import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/snapshot_builder.dart';
import 'package:pulse/data/metric_catalog.dart';
import 'package:pulse/features/detail/metric_detail_page.dart';
import 'package:pulse/widgets/bar_chart.dart';
import 'package:pulse/widgets/floating_surface.dart';
import 'package:pulse/widgets/pick_curve.dart';

import 'support/fixtures.dart';

/// Weights of the week of the fixture's Tuesday and the days before it.
FixtureRepository _weights() => FixtureRepository(
  readings: RawReadings(
    samples: [
      for (final (ago, kg) in const [
        (0, 112.0),
        (1, 112.2),
        (2, 112.4),
        (5, 112.8),
        (8, 113.0),
        (20, 114.5),
      ])
        RawSample(
          Metric.weight,
          DateTime(fixtureNow.year, fixtureNow.month, fixtureNow.day - ago, 7),
          kg,
        ),
    ],
  ),
);

Future<void> _open(WidgetTester tester, String title) async {
  await tester.ensureVisible(find.text(title));
  await advance(tester);
  await tester.tap(find.text(title));
  await advance(tester);
}

final Finder _pill = find.descendant(
  of: find.byType(FloatingSurface),
  matching: find.textContaining(' kg · '),
);

void main() {
  setUpAll(loadAppFont);

  for (final (language, title, tabs, lost) in const [
    ('de', 'Gewicht', ['Monat', 'Jahr', 'Gesamt'], 'abgenommen'),
    ('en', 'Weight', ['Month', 'Year', 'All'], 'Lost'),
    ('pl', 'Waga', ['Miesiąc', 'Rok', 'Całość'], 'Spadek'),
  ]) {
    for (final size in const [Size(360, 640), Size(412, 915)]) {
      testWidgets(
        'the weight opens on its week with line, bars and rows in $language '
        'at ${size.width.round()}',
        (tester) async {
          final store = MemoryJsonStore()
            ..documents['settings'] = '{"targetWeightKg":100,"simple":false}';
          await pumpApp(
            tester,
            size: size,
            locale: Locale(language),
            repository: _weights(),
            store: store,
          );
          await _open(tester, title);
          final page = find.byType(MetricDetailPage);
          Finder onPage(Finder finder) =>
              find.descendant(of: page, matching: finder);

          expect(onPage(find.byType(PickCurve)), findsOneWidget);
          expect(onPage(find.byType(BarChart)), findsOneWidget);
          expect(onPage(find.textContaining(lost)), findsOneWidget);
          expect(
            tester.getRect(onPage(find.byType(PickCurve))).bottom,
            lessThan(tester.getRect(onPage(find.byType(BarChart))).top),
          );
          for (final tab in tabs) {
            await pickPeriod(tester, tab);
            expect(onPage(find.byType(PickCurve)), findsOneWidget, reason: tab);
            expect(onPage(find.byType(BarChart)), findsOneWidget, reason: tab);
            expect(tester.takeException(), isNull, reason: tab);
          }
        },
      );
    }
  }

  testWidgets('today and yesterday have no line', (tester) async {
    await pumpApp(tester, repository: _weights());
    await _open(tester, 'Gewicht');
    for (final (index, tab) in const ['Heute', 'Gestern'].indexed) {
      await tapBarTab(tester, index);
      expect(find.byType(PickCurve), findsNothing, reason: tab);
    }
  });

  testWidgets('the week lists its days and the month its weeks', (
    tester,
  ) async {
    await pumpApp(tester, repository: _weights());
    await _open(tester, 'Gewicht');
    expect(find.text('Verlauf'), findsOneWidget);
    expect(find.text('Dienstag, 6. Oktober'), findsOneWidget);
    expect(find.text('Montag, 5. Oktober'), findsOneWidget);
    expect(find.text('0,2 kg über den Zeitraum abgenommen'), findsOneWidget);

    await pickPeriod(tester, 'Monat');
    expect(find.text('Diese Woche'), findsOneWidget);
    expect(find.text('1.10. bis 4.10.'), findsOneWidget);
    // Monday and Tuesday of this week, Thursday and Sunday of the one before.
    expect(find.text('112,1 kg'), findsWidgets);
    expect(find.text('112,6 kg'), findsOneWidget);
  });

  testWidgets(
    'a tap on the line says the weight and the day, held it follows',
    (tester) async {
      await pumpApp(tester, repository: _weights());
      await _open(tester, 'Gewicht');
      final curve = tester.getRect(find.byType(PickCurve));
      // Monday is the first seventh of the week.
      await tester.tapAt(
        Offset(curve.left + curve.width / 14, curve.center.dy),
      );
      await advance(tester);
      expect(find.text('112,2 kg · Mo, 5.10.'), findsOneWidget);
      expect(_pill, findsOneWidget);

      // The same place again takes it away.
      await tester.tapAt(
        Offset(curve.left + curve.width / 14, curve.center.dy),
      );
      await advance(tester);
      expect(_pill, findsNothing);

      final finger = await tester.startGesture(
        Offset(curve.left + curve.width / 14, curve.center.dy),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await advance(tester);
      expect(find.text('112,2 kg · Mo, 5.10.'), findsOneWidget);
      await finger.moveTo(Offset(curve.right - 4, curve.center.dy));
      await advance(tester);
      expect(find.text('112,0 kg · Di, 6.10.'), findsOneWidget);
      await finger.up();
      await advance(tester);
      expect(_pill, findsNothing);
    },
  );

  testWidgets(
    'the target weight is typed in the profile and named on the line',
    (tester) async {
      final app = await pumpApp(tester, repository: _weights());
      await tester.tap(find.byIcon(Icons.person_rounded).first);
      await advance(tester);
      await tapInView(tester, find.text('Wunschgewicht'));
      await advance(tester);
      await tester.enterText(find.byType(TextField), '5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await advance(tester);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), '99,5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await advance(tester);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('99,5 kg'), findsOneWidget);
      expect(
        app.store.documents['settings'],
        contains('"targetWeightKg":99.5'),
      );
    },
  );

  testWidgets('another measurement keeps its page', (tester) async {
    await pumpApp(tester);
    await tapInView(tester, stepsTile());
    expect(find.byType(MetricDetailPage), findsOneWidget);
    await pickPeriod(tester, 'Woche');
    expect(find.byType(PickCurve), findsNothing);
    expect(find.text('Verlauf'), findsNothing);
  });
}
