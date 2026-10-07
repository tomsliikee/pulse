import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/widgets/number_grid.dart';

import 'support/fixtures.dart';

void main() {
  setUpAll(loadAppFont);

  Future<void> pumpGrid(WidgetTester tester, int count, double width) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      themed(
        SingleChildScrollView(
          child: NumberGrid(
            cells: [
              for (var i = 0; i < count; i++)
                NumberCell(label: 'label $i', value: Text('value $i')),
            ],
          ),
        ),
      ),
    );
  }

  double widthOf(WidgetTester tester, int index) => tester
      .getSize(
        find
            .ancestor(
              of: find.text('value $index'),
              matching: find.byType(SizedBox),
            )
            .first,
      )
      .width;

  for (final width in [360.0, 412.0]) {
    testWidgets('an odd count gives the last card the whole row at '
        '${width.round()}', (tester) async {
      await pumpGrid(tester, 3, width);
      expect(widthOf(tester, 0), (width - 12) / 2);
      expect(widthOf(tester, 2), width);
      // Nothing stands beside a gap: the last card starts at the left edge.
      expect(tester.getTopLeft(find.text('label 2')).dx, lessThan(40));
    });

    testWidgets('an even count keeps two to a row at ${width.round()}', (
      tester,
    ) async {
      await pumpGrid(tester, 4, width);
      expect(widthOf(tester, 2), (width - 12) / 2);
      expect(widthOf(tester, 3), (width - 12) / 2);
      expect(
        tester.getTopLeft(find.text('label 3')).dy,
        tester.getTopLeft(find.text('label 2')).dy,
      );
    });
  }
}
