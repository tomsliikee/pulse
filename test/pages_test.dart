import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/health_repository.dart';
import 'package:pulse/data/snapshot_builder.dart';

import 'support/fixtures.dart';

const _sizes = [Size(360, 640), Size(412, 915)];

/// Builds the lazily laid out rest of the page, so an overflow anywhere on it
/// fails the test.
Future<void> _scrollThrough(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
  await advance(tester);
}

void main() {
  setUpAll(loadAppFont);

  for (final size in _sizes) {
    final label = '${size.width.round()}x${size.height.round()}';

    testWidgets('Today renders at $label', (tester) async {
      await pumpApp(tester, size: size);
      expect(find.text('Heute'), findsWidgets);
      expect(find.text('7.432'), findsOneWidget);
      await _scrollThrough(tester);
      expect(find.text('Ernährung'), findsOneWidget);
      expect(find.text('640 kcal'), findsOneWidget);
    });

    for (final (destination, marker) in const [
      ('Aktivität', 'Schritte und Trainings'),
      ('Schlaf', 'Schlafphasen'),
      ('Herz', 'Tagesverlauf'),
    ]) {
      testWidgets('$destination renders at $label', (tester) async {
        await pumpApp(tester, size: size);
        await tester.tap(find.bySemanticsLabel(destination));
        await advance(tester);
        expect(find.text(marker), findsOneWidget);
        await _scrollThrough(tester);
      });
    }

    testWidgets('Profile renders at $label', (tester) async {
      await pumpApp(tester, size: size);
      await tester.tap(find.bySemanticsLabel('Profil'));
      await advance(tester);
      expect(find.text('Ziele'), findsOneWidget);
      await _scrollThrough(tester);
      expect(find.text('Zuletzt aktualisiert'), findsOneWidget);
    });

    testWidgets('every page renders without any data at $label', (
      tester,
    ) async {
      await pumpApp(
        tester,
        size: size,
        repository: FixtureRepository(readings: const RawReadings()),
      );
      expect(find.text('Heute'), findsWidgets);
      await _scrollThrough(tester);
      for (final destination in const ['Aktivität', 'Schlaf', 'Herz']) {
        await tester.tap(find.bySemanticsLabel(destination));
        await advance(tester);
        await _scrollThrough(tester);
      }
    });

    testWidgets('all data appended to Today renders at $label', (tester) async {
      final store = MemoryJsonStore();
      await store.write('settings', {'showAllData': true});
      await pumpApp(tester, size: size, store: store);
      await _scrollThrough(tester);
      expect(find.text('Letzte 30 Tage aus Health Connect'), findsOneWidget);
      expect(find.text('Vitalwerte'), findsOneWidget);
      expect(find.text('Keine Daten'), findsOneWidget);
    });

    testWidgets('a tile opens its detail page at $label', (tester) async {
      await pumpApp(tester, size: size);
      await tester.ensureVisible(find.text('Ruhepuls'));
      await advance(tester);
      await tester.tap(find.text('Ruhepuls'));
      await advance(tester);
      // Opens on today; the other spans are one tab away.
      expect(find.text('Gestern'), findsWidgets);
      await tester.tap(find.text('Woche').hitTestable());
      await advance(tester);
      expect(find.text('Wochenschnitt pro Tag'), findsOneWidget);
      expect(find.text('Höchstwert'), findsOneWidget);
    });
  }

  testWidgets('Today stays on today when another day is selected elsewhere', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('7.432'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Schlaf'));
    await advance(tester);
    await tester.scrollUntilVisible(
      find.text('Diese Woche'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await advance(tester);
    // The week chart selects Monday.
    await tester.tap(find.text('Mo').hitTestable());
    await advance(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, 4000));
    await advance(tester);
    expect(find.text('Nacht auf Montag, 5. Oktober'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Heute'));
    await advance(tester);
    expect(find.text('Dienstag, 6. Oktober'), findsOneWidget);
    expect(find.text('7.432'), findsOneWidget);
  });

  testWidgets('the dark setting switches the theme and is saved', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Profil'));
    await advance(tester);
    // The button group lays out a second, hidden copy of each label.
    final dark = find.text('Dunkel').hitTestable();
    await tester.ensureVisible(dark);
    await advance(tester);
    await tester.tap(dark);
    await advance(tester);
    expect(Theme.of(tester.element(dark)).brightness, Brightness.dark);
    expect(app.store.documents['settings'], contains('"themeMode":"dark"'));
  });

  testWidgets('the edit mode offers to append all data to Today', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    final toggle = find.text('Alle Daten anzeigen').hitTestable();
    // Hidden until the pencil is used.
    expect(toggle, findsNothing);

    await tester.tap(find.byTooltip('Kacheln anordnen'));
    await advance(tester);
    expect(toggle, findsOneWidget);
    await tester.tap(find.byType(Switch).hitTestable());
    await advance(tester);
    expect(app.store.documents['settings'], contains('"showAllData":true'));

    await tester.tap(find.byTooltip('Fertig'));
    await advance(tester);
    expect(toggle, findsNothing);
    await _scrollThrough(tester);
    expect(find.text('Letzte 30 Tage aus Health Connect'), findsOneWidget);
    expect(find.text('Kalorien gesamt'), findsOneWidget);

    // A fresh start of the app with the same store still shows the list.
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, store: app.store);
    await _scrollThrough(tester);
    expect(find.text('Kalorien gesamt'), findsOneWidget);
  });

  testWidgets('there is no separate page for all data', (tester) async {
    await pumpApp(tester);
    expect(find.bySemanticsLabel('Alle Daten'), findsNothing);
    expect(find.text('Letzte 30 Tage aus Health Connect'), findsNothing);
  });

  testWidgets('without permission the app asks for access', (tester) async {
    final repository = FixtureRepository(currentAccess: HealthAccess.denied);
    await pumpApp(tester, repository: repository);
    expect(find.text('Deine Gesundheitsdaten'), findsOneWidget);
    expect(find.text('Heute'), findsNothing);

    await tester.tap(find.text('Zugriff erlauben').hitTestable());
    await advance(tester);

    expect(find.text('7.432'), findsOneWidget);
  });

  testWidgets('a platform without a health store says so', (tester) async {
    await pumpApp(
      tester,
      repository: FixtureRepository(currentAccess: HealthAccess.unsupported),
    );
    expect(find.text('Nur auf Android'), findsOneWidget);
  });

  testWidgets('a missing Health Connect offers to install it', (tester) async {
    await pumpApp(
      tester,
      repository: FixtureRepository(currentAccess: HealthAccess.unavailable),
    );
    expect(find.text('Health Connect fehlt'), findsOneWidget);
    expect(find.text('Health Connect öffnen'), findsWidgets);
  });
}
