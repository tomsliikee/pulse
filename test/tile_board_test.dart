import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/widgets/entrance.dart';
import 'package:pulse/widgets/tile_board.dart';

import 'support/fixtures.dart';

BoardTile _tile(String id, TileSpan span, [double height = 100]) => BoardTile(
  id: id,
  span: span,
  height: height,
  child: ColoredBox(
    color: const Color(0xFF888888),
    child: Center(child: Text(id)),
  ),
);

void main() {
  group('resolveTileOrder', () {
    final tiles = [
      _tile('a', TileSpan.full),
      _tile('b', TileSpan.half),
      _tile('c', TileSpan.half),
    ];

    test('uses the declared order when nothing is saved', () {
      expect(resolveTileOrder(tiles, const []), ['a', 'b', 'c']);
    });

    test('follows the saved order', () {
      expect(resolveTileOrder(tiles, const ['c', 'a', 'b']), ['c', 'a', 'b']);
    });

    test('drops unknown ids and appends tiles the order does not know', () {
      expect(resolveTileOrder(tiles, const ['gone', 'c', 'c']), [
        'c',
        'a',
        'b',
      ]);
    });
  });

  group('packTiles', () {
    test('fills rows by span and starts a new row when one is full', () {
      final packed = packTiles(
        [
          _tile('full', TileSpan.full, 200),
          _tile('h1', TileSpan.half, 100),
          _tile('h2', TileSpan.half, 140),
          _tile('t1', TileSpan.third),
          _tile('t2', TileSpan.third),
          _tile('t3', TileSpan.third),
          _tile('t4', TileSpan.third),
        ],
        312,
        gap: 12,
      );

      expect(packed.rects['full'], const Rect.fromLTWH(0, 0, 312, 200));
      expect(packed.rects['h1'], const Rect.fromLTWH(0, 212, 150, 100));
      expect(packed.rects['h2'], const Rect.fromLTWH(162, 212, 150, 140));
      // The row is as tall as its tallest tile.
      expect(packed.rects['t1']!.top, 212 + 140 + 12);
      expect(packed.rects['t3']!.right, 312);
      expect(packed.rects['t4']!.left, 0);
      expect(packed.height, packed.rects['t4']!.bottom);
    });

    test('an empty board has no height', () {
      expect(packTiles(const [], 300).height, 0);
    });
  });

  group('TileBoard', () {
    final tiles = [
      _tile('a', TileSpan.half),
      _tile('b', TileSpan.half),
      _tile('c', TileSpan.half),
      _tile('d', TileSpan.half),
    ];

    Future<List<List<String>>> pumpBoard(
      WidgetTester tester, {
      required bool editing,
      bool settle = true,
    }) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final reorders = <List<String>>[];
      await tester.pumpWidget(
        themed(
          SingleChildScrollView(
            child: TileBoard(
              tiles: tiles,
              order: const [],
              editing: editing,
              onReorder: reorders.add,
            ),
          ),
        ),
      );
      await tester.pump();
      // Past the tiles coming in.
      if (settle) {
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(seconds: 2));
      }
      return reorders;
    }

    testWidgets('the tiles come in one after the other', (tester) async {
      await pumpBoard(tester, editing: false, settle: false);
      double opacity(String id) => tester
          .widget<Opacity>(
            find
                .ancestor(of: find.text(id), matching: find.byType(Opacity))
                .first,
          )
          .opacity;
      await tester.pump(const Duration(milliseconds: 60));
      // The first is on its way while the last still waits.
      expect(opacity('a'), greaterThan(0));
      expect(opacity('d'), 0);
      final rising = tester.getCenter(find.text('a')).dy;
      // The last one's wait runs out, then its spring.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 2));
      expect(opacity('a'), 1);
      expect(opacity('d'), 1);
      expect(tester.getCenter(find.text('a')).dy, lessThan(rising));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('with animations off a tile is simply there', (tester) async {
      await tester.pumpWidget(
        themed(
          const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Entrance(order: 3, child: Text('a')),
          ),
        ),
      );
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
      // The wait of its place still runs out.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('dragging a tile onto another moves it there', (tester) async {
      final reorders = await pumpBoard(tester, editing: true);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('a')),
      );
      // Past the short hold that tells a drag from a scroll.
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.moveTo(tester.getCenter(find.text('d')));
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(seconds: 2));

      expect(reorders, [
        ['b', 'c', 'd', 'a'],
      ]);
      // Stop the wiggle before the test ends.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a lifted tile stays under the finger', (tester) async {
      await pumpBoard(tester, editing: true);
      Offset center(String id) => tester.getCenter(find.text(id));
      final home = center('a');

      final gesture = await tester.startGesture(home);
      await tester.pump(const Duration(milliseconds: 300));

      // Small moves that stay inside the tile's own slot.
      for (final step in const [
        Offset(20, 10),
        Offset(15, 25),
        Offset(-5, 30),
      ]) {
        await gesture.moveBy(step);
        await tester.pump();
      }
      expect(center('a').dx, closeTo(home.dx + 30, 0.5));
      expect(center('a').dy, closeTo(home.dy + 65, 0.5));

      // Across another slot: the others reorder, the tile keeps following.
      final target = center('d');
      await gesture.moveTo(target);
      await tester.pump();
      expect(center('a').dx, closeTo(target.dx, 0.5));
      expect(center('a').dy, closeTo(target.dy, 0.5));
      await tester.pump(const Duration(milliseconds: 400));
      expect(center('a').dx, closeTo(target.dx, 0.5));

      // Released, it settles exactly in its new slot, the last one.
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      final slots = packTiles([
        for (final id in const ['b', 'c', 'd', 'a'])
          tiles.firstWhere((t) => t.id == id),
      ], tester.getSize(find.byType(TileBoard)).width).rects;
      final board = tester.getTopLeft(find.byType(TileBoard));
      expect(center('a').dx, closeTo(board.dx + slots['a']!.center.dx, 0.5));
      expect(center('a').dy, closeTo(board.dy + slots['a']!.center.dy, 0.5));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('grazing the edge of another tile does not swap them', (
      tester,
    ) async {
      final reorders = await pumpBoard(tester, editing: true);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('a')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      // Just past the left edge of the neighbouring slot.
      await gesture.moveTo(
        tester.getTopLeft(find.text('b').first) +
            Offset(-tester.getSize(find.byType(TileBoard)).width / 4 + 30, 0),
      );
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(seconds: 2));

      expect(reorders.single, ['a', 'b', 'c', 'd']);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('tiles cannot be dragged outside the edit mode', (
      tester,
    ) async {
      final reorders = await pumpBoard(tester, editing: false);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('a')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.moveTo(tester.getCenter(find.text('d')));
      await gesture.up();
      await tester.pump(const Duration(seconds: 2));

      expect(reorders, isEmpty);
    });

    testWidgets('nothing wiggles when the system reduces motion', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      await pumpBoard(tester, editing: true);
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('edit mode in the app', () {
    setUpAll(loadAppFont);

    testWidgets('the pencil starts it and a moved tile is saved', (
      tester,
    ) async {
      final app = await pumpApp(tester);
      await tester.tap(find.bySemanticsLabel('Schlaf'));
      await advance(tester);

      await tester.tap(find.byTooltip('Kacheln anordnen'));
      await advance(tester);
      expect(find.byTooltip('Fertig'), findsOneWidget);

      // While editing, a tap must not open anything.
      // The stage tile, not the figure of the same name in the top tile.
      final deep = find.text('Tiefschlaf').last;
      await tester.ensureVisible(deep);
      await advance(tester);
      final gesture = await tester.startGesture(tester.getCenter(deep));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.moveTo(tester.getCenter(find.text('Leichter Schlaf').last));
      await tester.pump();
      await gesture.up();
      await advance(tester);

      final saved = app.store.documents['settings']!;
      expect(
        saved.indexOf('"light"'),
        lessThan(saved.indexOf('"deep"')),
        reason: 'deep sleep was dropped behind light sleep',
      );

      // Back to the top, where the header with the check mark is.
      await tester.drag(find.byType(ListView).first, const Offset(0, 4000));
      await advance(tester);
      await tester.tap(find.byTooltip('Fertig'));
      await advance(tester);
      expect(find.byTooltip('Kacheln anordnen'), findsOneWidget);
    });
  });
}
