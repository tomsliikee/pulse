import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/metric_catalog.dart';

import 'support/fixtures.dart';

const _sizes = [Size(360, 640), Size(412, 915)];

Future<void> _open(WidgetTester tester, String destination) async {
  await tester.tap(find.bySemanticsLabel(destination));
  await advance(tester);
}

Future<void> _edit(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Kacheln anordnen'));
  await advance(tester);
}

void main() {
  setUpAll(loadAppFont);

  testWidgets('a tile removed from Herz stays away and can be brought back', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await _open(tester, 'Herz');
    expect(find.text('Ruhepuls'), findsOneWidget);
    await _edit(tester);

    // The first four belong to the hero, the curve of the day, the days
    // before and the note; then comes the resting heart rate.
    final minus = find.byTooltip('Entfernen', skipOffstage: false).at(4);
    await bringIntoView(tester, minus);
    await tester.tap(minus);
    await advance(tester);
    expect(
      app.store.documents['settings'],
      contains('"hiddenTiles":{"heart":["restingHeartRate"]}'),
    );

    // A fresh start with the same store still leaves it out.
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, store: app.store);
    await _open(tester, 'Herz');
    expect(find.text('Ruhepuls'), findsNothing);

    await _edit(tester);
    final offer = find.text('Ruhepuls');
    await tester.scrollUntilVisible(
      offer,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await advance(tester);
    await tester.tap(offer);
    await advance(tester);

    expect(
      app.store.documents['settings'],
      contains('"hiddenTiles":{"heart":[]}'),
    );
  });

  testWidgets('a compact tile on Herz grows into the wide form', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await _open(tester, 'Herz');
    await _edit(tester);
    final resize = find.byTooltip('Vergrössern');
    await tester.scrollUntilVisible(
      resize.first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await advance(tester);
    await tester.tap(resize.hitTestable().first);
    await advance(tester);

    expect(
      app.store.documents['settings'],
      contains('"heart/restingHeartRate"'),
    );
    expect(find.byTooltip('Verkleinern'), findsOneWidget);
  });

  for (final size in _sizes) {
    final label = '${size.width.round()}x${size.height.round()}';
    for (final (destination, page) in const [
      ('Aktivität', 'activity'),
      ('Herz', 'heart'),
    ]) {
      testWidgets('every tile of $destination renders large at $label', (
        tester,
      ) async {
        final store = MemoryJsonStore();
        await store.write('settings', {
          'largeTiles': [
            for (final metric in Metric.values) '$page/${metric.name}',
          ],
        });
        await pumpApp(tester, size: size, store: store);
        await _open(tester, destination);
        await tester.drag(find.byType(ListView).first, const Offset(0, -9000));
        await advance(tester);
        await tester.drag(find.byType(ListView).first, const Offset(0, 9000));
        await advance(tester);
        await _edit(tester);
        await tester.drag(find.byType(ListView).first, const Offset(0, -9000));
        await advance(tester);
        expect(find.byTooltip('Verkleinern'), findsWidgets);
      });
    }

    testWidgets('Schlaf renders with every tile removed at $label', (
      tester,
    ) async {
      final store = MemoryJsonStore();
      await store.write('settings', {
        'hiddenTiles': {
          'sleep': ['hero', 'stages', 'week', 'deep', 'light', 'rem', 'awake'],
        },
      });
      await pumpApp(tester, size: size, store: store);
      await _open(tester, 'Schlaf');
      expect(find.text('Schlafphasen'), findsNothing);
      await _edit(tester);
      await tester.drag(find.byType(ListView).first, const Offset(0, -9000));
      await advance(tester);
      expect(find.text('Schlafphasen', skipOffstage: false), findsOneWidget);
    });
  }
}
