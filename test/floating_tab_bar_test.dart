import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/widgets/floating_tab_bar.dart';

import 'support/fixtures.dart';

const _labels = ['Heute', 'Gestern', 'Woche', 'Monat', 'Jahr', 'Gesamt'];

Widget _bar({required ValueChanged<int> onSelected, int selected = 0}) =>
    themed(
      Center(
        child: FloatingTabBar(
          labels: _labels,
          selectedIndex: selected,
          onSelected: onSelected,
        ),
      ),
    );

void main() {
  setUpAll(loadAppFont);

  testWidgets('a tap selects another tab, a tap on the selected one does not', (
    tester,
  ) async {
    final picked = <int>[];
    await tester.pumpWidget(_bar(onSelected: picked.add));
    await advance(tester);

    await tester.tap(find.text('Monat'));
    await tester.tap(find.text('Heute'));
    expect(picked, [3]);
  });

  testWidgets('every tab is a button and the selected one says so', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_bar(onSelected: (_) {}, selected: 2));
    await advance(tester);

    for (final label in _labels) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        matchesSemantics(
          label: label,
          isButton: true,
          hasSelectedState: true,
          isSelected: label == 'Woche',
          hasTapAction: true,
        ),
      );
    }
    handle.dispose();
  });

  for (final width in const [320.0, 360.0, 412.0]) {
    testWidgets('all six tabs fit a screen ${width.round()} wide', (
      tester,
    ) async {
      tester.view
        ..physicalSize = Size(width, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        themed(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: FloatingTabBar(
                labels: _labels,
                selectedIndex: 5,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await advance(tester);

      final bar = tester.getRect(find.byType(FloatingTabBar));
      expect(bar.left, greaterThanOrEqualTo(16));
      expect(bar.right, lessThanOrEqualTo(width - 16));
      for (final label in _labels) {
        expect(find.text(label).hitTestable(), findsOne);
      }
    });
  }

  testWidgets('the selected tab is wider than at rest, the others give way '
      'and the bar keeps its width', (tester) async {
    const labels = ['Tag', 'Tag', 'Tag'];
    Widget bar(int selected) => themed(
      Center(
        child: FloatingTabBar(
          labels: labels,
          selectedIndex: selected,
          onSelected: (_) {},
        ),
      ),
    );
    double widthOf(int index) =>
        tester.getSize(find.bySemanticsLabel('Tag').at(index)).width;

    await tester.pumpWidget(bar(0));
    await advance(tester);
    final whole = tester.getSize(find.byType(FloatingTabBar)).width;
    expect(widthOf(0), greaterThan(widthOf(1) + 8));
    expect(widthOf(1), closeTo(widthOf(2), 0.01));

    await tester.pumpWidget(bar(2));
    await advance(tester);
    expect(widthOf(2), greaterThan(widthOf(1) + 8));
    expect(widthOf(0), closeTo(widthOf(1), 0.01));
    expect(tester.getSize(find.byType(FloatingTabBar)).width, whole);
  });
}
