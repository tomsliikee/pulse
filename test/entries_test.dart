import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/features/detail/metric_detail_page.dart';
import 'package:pulse/features/entry/entry_sheet.dart';

import 'support/fixtures.dart';

Future<void> _openMenuItem(WidgetTester tester, String label) async {
  await tester.tap(find.byIcon(Icons.add_rounded));
  await advance(tester);
  // The menu floats above the page, which may show the same word on a tile.
  await tester.tap(find.text(label).hitTestable().last);
  await advance(tester);
}

void main() {
  setUpAll(loadAppFont);

  test('amounts accept a comma or a point', () {
    expect(parseAmount('72,5'), 72.5);
    expect(parseAmount(' 72.5 '), 72.5);
    expect(parseAmount('viel'), isNull);
  });

  testWidgets('a quick amount records water', (tester) async {
    final app = await pumpApp(tester);
    await _openMenuItem(tester, 'Wasser');
    expect(find.text('Wasser eintragen'), findsOneWidget);

    await tester.tap(find.text('300 ml').hitTestable());
    await tester.pump();
    await tester.tap(find.text('Speichern').hitTestable());
    await advance(tester);

    expect(app.repository.added.single.kind, EntryKind.water);
    expect(app.repository.added.single.amount, 300);
    expect(find.text('Wasser eintragen'), findsNothing);
  });

  testWidgets('an implausible weight is refused with a reason', (tester) async {
    final app = await pumpApp(tester);
    await _openMenuItem(tester, 'Gewicht');

    await tester.enterText(find.byType(TextField), '9000');
    await tester.tap(find.text('Speichern').hitTestable());
    await advance(tester);

    expect(find.textContaining('Bitte eine Zahl zwischen'), findsOneWidget);
    expect(app.repository.added, isEmpty);

    await tester.enterText(find.byType(TextField), '73,4');
    await tester.tap(find.text('Speichern').hitTestable());
    await advance(tester);

    expect(app.repository.added.single.amount, 73.4);
  });

  testWidgets('a meal keeps its name and nutrients', (tester) async {
    final app = await pumpApp(tester);
    await _openMenuItem(tester, 'Mahlzeit');

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Porridge');
    await tester.enterText(fields.at(1), '420');
    await tester.enterText(fields.at(2), '58');
    await tester.enterText(fields.at(3), 'x');
    final save = find.text('Speichern').hitTestable();
    await tester.ensureVisible(find.text('Speichern').last);
    await tester.pump();
    await tester.tap(save);
    await advance(tester);
    expect(find.textContaining('Nährwerte müssen Zahlen'), findsOneWidget);
    expect(app.repository.added, isEmpty);

    await tester.enterText(fields.at(3), '14,5');
    await tester.ensureVisible(find.text('Speichern').last);
    await tester.pump();
    await tester.tap(find.text('Speichern').hitTestable());
    await advance(tester);

    final meal = app.repository.added.single;
    expect(meal.name, 'Porridge');
    expect(meal.amount, 420);
    expect(meal.carbs, 58);
    expect(meal.protein, 14.5);
    expect(meal.fat, isNull);
  });

  testWidgets('own entries can be edited and deleted, foreign ones cannot', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await tester.scrollUntilVisible(
      find.text('Wasser'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await advance(tester);
    await tester.tap(find.text('Wasser'));
    await advance(tester);

    expect(find.text('Einträge'), findsOneWidget);
    expect(find.text('300 ml'), findsOneWidget);
    expect(find.textContaining('com.fitbit.FitbitMobile'), findsOneWidget);
    // Two entries, but only the app's own one offers the actions.
    expect(find.byTooltip('Bearbeiten'), findsOneWidget);
    expect(find.byTooltip('Löschen'), findsOneWidget);

    await tester.tap(find.byTooltip('Bearbeiten'));
    await advance(tester);
    expect(find.text('Wasser bearbeiten'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '750');
    await tester.tap(find.text('Speichern').hitTestable());
    await advance(tester);
    expect(app.repository.deleted.single.id, 'own-water');
    expect(app.repository.added.single.amount, 750);
    expect(find.text('750 ml'), findsOneWidget);

    await tester.tap(find.byTooltip('Löschen'));
    await advance(tester);
    expect(find.text('750 ml'), findsNothing);
    expect(find.text('300 ml'), findsOneWidget);
    expect(find.text('Eintrag gelöscht'), findsOneWidget);
  });

  testWidgets('a back swipe shrinks the sheet towards the bottom and closes '
      'only the sheet', (tester) async {
    final app = await pumpApp(tester);
    await tester.scrollUntilVisible(
      find.text('Wasser'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await advance(tester);
    await tester.tap(find.text('Wasser'));
    await advance(tester);
    await tester.tap(find.byTooltip('Bearbeiten'));
    await advance(tester);

    final sheet = find.byType(EntrySheet);
    final page = find.byType(MetricDetailPage);
    final atRest = tester.getRect(sheet);

    await backGesture(tester, 'startBackGesture', 0);
    await backGesture(tester, 'updateBackGestureProgress', 1);
    final pulled = tester.getRect(sheet);
    expect(pulled.width, moreOrLessEquals(atRest.width * 0.9));
    expect(pulled.top, greaterThan(atRest.top));
    // The page beneath the sheet does not answer the same swipe.
    expect(tester.getRect(page), const Rect.fromLTWH(0, 0, 412, 915));

    await backGesture(tester, 'cancelBackGesture');
    await advance(tester);
    expect(tester.getRect(sheet), atRest);

    await backGesture(tester, 'startBackGesture', 0);
    await backGesture(tester, 'updateBackGestureProgress', 0.5);
    await backGesture(tester, 'commitBackGesture');
    await advance(tester);
    expect(sheet, findsNothing);
    expect(page, findsOneWidget);
    expect(app.repository.added, isEmpty);
    expect(app.repository.deleted, isEmpty);
  });
}
