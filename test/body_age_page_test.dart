import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/snapshot_builder.dart';
import 'package:pulse/features/age/body_age_page.dart';
import 'package:pulse/features/detail/metric_detail_page.dart';

import 'support/fixtures.dart';

const _sizes = [Size(360, 640), Size(412, 915)];

MemoryJsonStore _storeWithBirthDate() =>
    MemoryJsonStore()
      ..documents['settings'] = '{"birthDate":"1992-03-07","sex":"male"}';

Finder _onPage(Finder finder) =>
    find.descendant(of: find.byType(BodyAgePage), matching: finder);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel(RegExp('Körperalter')));
  await advance(tester);
}

/// Lays out the whole page, so an overflow anywhere on it fails the test.
Future<void> _scrollThrough(WidgetTester tester) async {
  await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
  await advance(tester);
}

void main() {
  setUpAll(loadAppFont);

  for (final size in _sizes) {
    final label = '${size.width.round()}x${size.height.round()}';

    testWidgets('the age in the rings opens its page at $label', (
      tester,
    ) async {
      await pumpApp(tester, size: size, store: _storeWithBirthDate());
      expect(find.text('Körperalter'), findsOne);
      expect(find.text('Alter festlegen'), findsNothing);
      await _open(tester);
      expect(find.byType(MetricDetailPage), findsNothing);
      for (final title in const [
        'Schritte',
        'Intensitätsminuten',
        'Schlafdauer',
        'Schlafrhythmus',
        'Ruhepuls',
        'Herzfrequenzvariabilität',
        'Body-Mass-Index',
        'Blutdruck',
        'Krafttraining',
        'Deine Angaben',
        'So wird gerechnet',
      ]) {
        expect(
          _onPage(find.text(title, skipOffstage: false)),
          findsOne,
          reason: title,
        );
      }
      expect(
        _onPage(find.text('Schätzung aus den letzten 30 Tagen')),
        findsOne,
      );
      await _scrollThrough(tester);
      expect(_onPage(find.text('7.3.1992')), findsOne);
      expect(_onPage(find.text('181 cm')), findsOne);
    });

    testWidgets('without a date of birth the page asks for it at $label', (
      tester,
    ) async {
      final app = await pumpApp(tester, size: size);
      expect(find.text('Alter festlegen'), findsOne);
      await _open(tester);
      expect(_onPage(find.text('Geburtsdatum fehlt')), findsOne);

      await tester.tap(find.text('Geburtsdatum eintragen'));
      await advance(tester);
      await tester.enterText(find.byType(TextField), '31.2.1992');
      await tester.tap(find.text('Speichern'));
      await advance(tester);
      expect(find.text('Bitte ein Datum wie 7.3.1992 eingeben.'), findsOne);

      await tester.enterText(find.byType(TextField), '7.3.1992');
      await tester.tap(find.text('Speichern'));
      await advance(tester);
      expect(
        app.store.documents['settings'],
        contains('"birthDate":"1992-03-07"'),
      );
      expect(_onPage(find.text('Geburtsdatum fehlt')), findsNothing);
      expect(
        _onPage(find.text('Schätzung aus den letzten 30 Tagen')),
        findsOne,
      );
      await _scrollThrough(tester);
    });
  }

  testWidgets('a tap beside the age still opens the steps', (tester) async {
    await pumpApp(tester, store: _storeWithBirthDate());
    await tester.tap(find.text('7.432'));
    await advance(tester);
    expect(find.byType(MetricDetailPage), findsOne);
    expect(find.byType(BodyAgePage), findsNothing);
  });

  testWidgets('too few factors give a dash instead of an age', (tester) async {
    final all = fixtureReadings();
    await pumpApp(
      tester,
      store: _storeWithBirthDate(),
      repository: FixtureRepository(
        readings: RawReadings(dailyTotals: all.dailyTotals),
      ),
    );
    await _open(tester);
    expect(_onPage(find.text('Noch zu wenig Daten')), findsOne);
    expect(_onPage(find.text('Keine Messung.')), findsOne);
    await _scrollThrough(tester);
  });
}
