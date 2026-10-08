import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/widgets/number_grid.dart';
import 'package:pulse/widgets/tile_surface.dart';

import 'support/fixtures.dart';

void main() {
  setUpAll(loadAppFont);

  Future<void> pumpGrid(
    WidgetTester tester,
    int count,
    double width, {
    List<String>? labels,
  }) async {
    tester.view.physicalSize = Size(width, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      themed(
        SingleChildScrollView(
          child: NumberGrid(
            cells: [
              for (var i = 0; i < count; i++)
                NumberCell(
                  label: labels?[i] ?? 'label $i',
                  value: Text('value $i'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The surfaces of the grid, row by row: the rectangles that share a top.
  List<List<Rect>> rowsOf(WidgetTester tester) {
    final rects =
        [
          for (final element in find.byType(TileSurface).evaluate())
            tester.getRect(find.byWidget(element.widget)),
        ]..sort(
          (a, b) => a.top != b.top
              ? a.top.compareTo(b.top)
              : a.left.compareTo(b.left),
        );
    final rows = <List<Rect>>[];
    for (final rect in rects) {
      if (rows.isEmpty || rows.last.first.top != rect.top) rows.add([]);
      rows.last.add(rect);
    }
    return rows;
  }

  for (final width in [360.0, 412.0]) {
    for (var count = 2; count <= 7; count++) {
      testWidgets('$count numbers fill every row at ${width.round()}', (
        tester,
      ) async {
        await pumpGrid(tester, count, width);
        for (var i = 0; i < count; i++) {
          expect(find.text('value $i'), findsOneWidget);
          expect(find.text('label $i'), findsOneWidget);
        }
        final rows = rowsOf(tester);
        // An odd count starts with one pill over the whole width.
        final pairs = count.isOdd ? rows.skip(1) : rows;
        if (count.isOdd) {
          expect(rows.first, hasLength(1));
          expect(rows.first.single.width, width);
        }
        expect(pairs, hasLength(count ~/ 2));
        for (final (index, row) in pairs.indexed) {
          // Two to a row, from edge to edge: no surface beside a gap.
          expect(row, hasLength(2));
          expect(row.first.left, 0);
          expect(row.last.right, width);
          expect(row.last.left - row.first.right, NumberGrid.gap);
          // A circle and a wide surface, on sides that swap row by row.
          final round = index.isEven ? row.first : row.last;
          expect(round.size, const Size.square(NumberGrid.circle));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the circle takes the shorter name of a pair', (tester) async {
    await pumpGrid(
      tester,
      2,
      412,
      labels: ['a very long name of a number', 'short'],
    );
    final circle = rowsOf(tester).single.first;
    expect(circle.contains(tester.getCenter(find.text('short'))), isTrue);
    expect(circle.contains(tester.getCenter(find.text('value 1'))), isTrue);
  });
}
