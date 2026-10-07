import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/settings_controller.dart';
import 'package:pulse/widgets/floating_tab_bar.dart';
import 'package:pulse/widgets/glass_bar.dart';
import 'package:pulse/widgets/glass_rim.dart';
import 'package:pulse/widgets/glass_scope.dart';

import 'support/fixtures.dart';

const _sizes = [Size(360, 640), Size(412, 915)];

Future<MemoryJsonStore> _glassStore() async {
  final store = MemoryJsonStore();
  await store.write(StoreKeys.settings, {'liquidGlass': true});
  return store;
}

void main() {
  setUpAll(loadAppFont);

  test('the glass setting is off at first and survives a restart', () async {
    final store = MemoryJsonStore();
    final settings = SettingsController(store);
    await settings.load();
    expect(settings.liquidGlass, isFalse);
    settings.setLiquidGlass(true);
    await pumpEventQueue();

    final loaded = SettingsController(store);
    await loaded.load();
    expect(loaded.liquidGlass, isTrue);
  });

  testWidgets('without the setting nothing is drawn as glass', (tester) async {
    await pumpApp(tester);
    expect(find.byType(LiquidGlass), findsNothing);
  });

  testWidgets('the switch on the profile turns tiles and bar into glass', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Profil'));
    await advance(tester);
    // The list builds its lower rows only once they come near.
    await tester.scrollUntilVisible(
      find.text('Liquid Glass'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final row = find.ancestor(
      of: find.text('Liquid Glass'),
      matching: find.byType(Row),
    );
    final glassSwitch = find.descendant(
      of: row.first,
      matching: find.byType(Switch),
    );
    await tester.ensureVisible(glassSwitch);
    await advance(tester);
    await tester.tap(glassSwitch);
    await advance(tester);
    expect(app.store.documents['settings'], contains('"liquidGlass":true'));

    await tester.pageBack();
    await advance(tester);
    // The bar, its pill and the add button.
    expect(find.byType(LiquidGlass), findsNWidgets(3));
    expect(find.byType(GlassScope), findsOneWidget);
    expect(find.text('7.432'), findsOneWidget);
  });

  for (final glass in [false, true]) {
    final look = glass ? 'glass' : 'solid';

    testWidgets('dragging the $look pill along the bar changes the page', (
      tester,
    ) async {
      await pumpApp(tester, store: glass ? await _glassStore() : null);
      final from = tester.getCenter(find.bySemanticsLabel('Heute'));
      final to = tester.getCenter(find.bySemanticsLabel('Schlaf'));
      final gesture = await tester.startGesture(from);
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(to);
      await tester.pump(const Duration(milliseconds: 300));
      // The page only changes when the pill is let go. The glass pill stays
      // one piece of glass while it is a lens, next to the bar and the add
      // button.
      expect(find.text('Schlafphasen'), findsNothing);
      expect(find.byType(LiquidGlass).evaluate().length, glass ? 3 : 0);
      await gesture.up();
      await advance(tester);
      expect(find.text('Schlafphasen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a $look pill dropped where it was keeps the page', (
      tester,
    ) async {
      await pumpApp(tester, store: glass ? await _glassStore() : null);
      final from = tester.getCenter(find.bySemanticsLabel('Heute'));
      final gesture = await tester.startGesture(from);
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(from);
      await gesture.up();
      await advance(tester);
      expect(find.text('7.432'), findsOneWidget);
    });
  }

  testWidgets('the glass pill of the navigation bar lies on the selected '
      'destination', (tester) async {
    await pumpApp(tester, store: await _glassStore());
    // The bar is the first piece of glass in it, the pill the second.
    Rect pill() => tester.getRect(
      find
          .descendant(
            of: find.byType(GlassBar),
            matching: find.byType(LiquidGlass),
          )
          .at(1),
    );
    Offset centre(String label) =>
        tester.getCenter(find.bySemanticsLabel(label));

    expect(pill().contains(centre('Heute')), isTrue);
    expect(pill().contains(centre('Schlaf')), isFalse);
    await tester.tap(find.bySemanticsLabel('Schlaf'));
    await advance(tester);
    expect(pill().contains(centre('Schlaf')), isTrue);
    expect(pill().contains(centre('Heute')), isFalse);
  });

  testWidgets('the glass pill of the period tabs lies on the selected tab', (
    tester,
  ) async {
    await pumpApp(tester, store: await _glassStore());
    await tester.tap(find.text('7.432'));
    await advance(tester);
    final bar = find.byType(GlassBar).last;
    Rect pill() => tester.getRect(
      find.descendant(of: bar, matching: find.byType(LiquidGlass)).at(1),
    );
    Offset centre(String label) => tester.getCenter(
      find.descendant(of: bar, matching: find.bySemanticsLabel(label)),
    );

    expect(pill().contains(centre('Heute')), isTrue);
    await tester.tap(
      find.descendant(of: bar, matching: find.bySemanticsLabel('Woche')),
    );
    await advance(tester);
    expect(pill().contains(centre('Woche')), isTrue);
    expect(pill().contains(centre('Heute')), isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final glass in [false, true]) {
    final look = glass ? 'glass' : 'solid';

    testWidgets('dragging the $look pill of the period tabs changes the tab', (
      tester,
    ) async {
      await pumpApp(tester, store: glass ? await _glassStore() : null);
      await tester.tap(find.text('7.432'));
      await advance(tester);
      final bar = find.byType(FloatingTabBar);
      Finder tab(String label) =>
          find.descendant(of: bar, matching: find.bySemanticsLabel(label));
      bool selected(String label) =>
          tester.getSemantics(tab(label)).flagsCollection.isSelected ==
          Tristate.isTrue;

      final gesture = await tester.startGesture(tester.getCenter(tab('Heute')));
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(tester.getCenter(tab('Monat')));
      await tester.pump(const Duration(milliseconds: 300));
      // The tab only changes when the pill is let go.
      expect(selected('Heute'), isTrue);
      await gesture.up();
      await advance(tester);
      expect(selected('Monat'), isTrue);
      expect(selected('Heute'), isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an entry of the glass add button has its rim only once it is '
      'in its place', (tester) async {
    await pumpApp(tester, store: await _glassStore());
    final rim = find.descendant(
      of: find.ancestor(
        of: find.text('Wasser'),
        matching: find.byType(LiquidGlass),
      ),
      matching: find.byType(GlassRim),
    );

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 48));
    expect(tester.widget<GlassRim>(rim).strength, 0);
    await advance(tester);
    expect(tester.widget<GlassRim>(rim).strength, 1);
  });

  testWidgets('the glass add button lets its entries out and takes them back', (
    tester,
  ) async {
    await pumpApp(tester, store: await _glassStore());
    expect(find.text('Mahlzeit'), findsNothing);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await advance(tester);
    for (final entry in const ['Wasser', 'Gewicht', 'Mahlzeit']) {
      expect(find.text(entry).hitTestable(), findsOneWidget);
    }
    // Entries stay on screen, right-aligned with the button.
    final button = tester.getRect(find.bySemanticsLabel('Schliessen'));
    final meal = tester.getRect(
      find.ancestor(
        of: find.text('Mahlzeit'),
        matching: find.byType(LiquidGlass),
      ),
    );
    expect(meal.right, moreOrLessEquals(button.right, epsilon: 0.5));
    expect(meal.bottom, lessThan(button.top));
    expect(meal.left, greaterThan(0));

    // A tap beside the menu closes it.
    await tester.tapAt(const Offset(40, 300));
    await advance(tester);
    expect(find.text('Mahlzeit'), findsNothing);
    expect(find.bySemanticsLabel('Eintrag hinzufügen'), findsOneWidget);
  });

  testWidgets('the entries of the glass add button only pull together while '
      'they move', (tester) async {
    await pumpApp(tester, store: await _glassStore());
    // The entry nearest to the button is the first to be there.
    final group = find.ancestor(
      of: find.text('Wasser'),
      matching: find.byType(LiquidGlassBlendGroup),
    );
    double blend() => group.evaluate().isEmpty
        ? 0
        : tester.widget<LiquidGlassBlendGroup>(group).blend;

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    var strongest = 0.0;
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (blend() > strongest) strongest = blend();
    }
    expect(strongest, greaterThan(20));

    // At rest it has to be zero itself, not merely close to it.
    await advance(tester);
    expect(blend(), 0);
  });

  testWidgets('an entry of the glass add button opens its sheet', (
    tester,
  ) async {
    await pumpApp(tester, store: await _glassStore());
    await tester.tap(find.byIcon(Icons.add_rounded));
    await advance(tester);
    await tester.tap(find.text('Wasser').hitTestable());
    await advance(tester);
    expect(find.text('Wasser eintragen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in _sizes) {
    final label = '${size.width.round()}x${size.height.round()}';

    testWidgets('every page renders as glass at $label', (tester) async {
      await pumpApp(tester, size: size, store: await _glassStore());
      for (final destination in const [
        'Heute',
        'Aktivität',
        'Schlaf',
        'Herz',
      ]) {
        await tester.tap(find.bySemanticsLabel(destination));
        await advance(tester);
        expect(find.byType(GlassScope), findsOneWidget);
        await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
        await advance(tester);
      }
    });

    testWidgets('tiles can be picked up while they are glass at $label', (
      tester,
    ) async {
      await pumpApp(tester, size: size, store: await _glassStore());
      await tester.tap(find.byTooltip('Kacheln anordnen'));
      await advance(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Herzfrequenz')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.moveBy(const Offset(40, 120));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await advance(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
