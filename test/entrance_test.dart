import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/widgets/animated_count.dart';
import 'package:pulse/widgets/entrance.dart';

import 'support/fixtures.dart';

double _opacity(WidgetTester tester, String text) => tester
    .widget<Opacity>(
      find.ancestor(of: find.text(text), matching: find.byType(Opacity)).first,
    )
    .opacity;

void main() {
  setUpAll(loadAppFont);

  testWidgets('a number counts up and ends on the exact value', (tester) async {
    await tester.pumpWidget(
      themed(
        AnimatedNumber(
          value: 5.4,
          format: (value) => '${value.toStringAsFixed(1)} km',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('5.4 km'), findsNothing);
    await advance(tester);
    expect(find.text('5.4 km'), findsOneWidget);
  });

  testWidgets('something that is not new on the page does not come in', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(
        const Column(
          children: [
            Entrance(order: 2, child: Text('new')),
            Entrance(order: 2, animate: false, child: Text('old')),
          ],
        ),
      ),
    );
    expect(_opacity(tester, 'new'), 0);
    expect(_opacity(tester, 'old'), 1);
    await advance(tester);
    expect(_opacity(tester, 'new'), 1);
  });

  testWidgets('staggered children start one after the other', (tester) async {
    await tester.pumpWidget(
      themed(Column(children: staggered(const [Text('a'), Text('b')]))),
    );
    await tester.pump(const Duration(milliseconds: 30));
    expect(_opacity(tester, 'a'), greaterThan(0));
    expect(_opacity(tester, 'b'), 0);
    await tester.pump(const Duration(milliseconds: 100));
    await advance(tester);
    expect(_opacity(tester, 'b'), 1);
  });

  testWidgets('the gate is open for the first frame of a page only', (
    tester,
  ) async {
    late bool Function() opening;
    final seen = <bool>[];
    await tester.pumpWidget(
      EntranceGate(
        builder: (context, isOpening) {
          opening = isOpening;
          seen.add(isOpening());
          return const SizedBox();
        },
      ),
    );
    expect(seen, [true]);
    // A row that the list builds later asks again, and is told no.
    await tester.pump();
    expect(opening(), isFalse);
  });
}
