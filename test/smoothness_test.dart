import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/features/today/day_scene.dart';
import 'package:pulse/theme/app_type.dart';
import 'package:pulse/widgets/board_page.dart';

import 'support/fixtures.dart';

void main() {
  setUpAll(loadAppFont);

  group('type on its way keeps to a grid, so its fonts are met again', () {
    const type = AppType(flex: true);
    const style = TextStyle(fontSize: 20, fontWeight: FontWeight.w800);

    test('a number that counts up grows heavier in steps and ends on its '
        'weight', () {
      final weights = {
        for (var i = 0; i <= 1000; i++)
          AppType.weightOf(type.moving(style, settled: i / 1000)!),
      };
      expect(weights.every((weight) => weight % 20 == 0), isTrue);
      expect(weights.length, lessThan(25));
      expect(AppType.weightOf(type.moving(style)!), 800);
      // A hair before the end it already has its weight.
      expect(AppType.weightOf(type.moving(style, settled: 0.999)!), 800);
    });

    test('a tab label on its way to selected takes few forms', () {
      final forms = {
        for (var i = 0; i <= 1000; i++)
          '${type.tab(style, i / 1000)!.fontVariations}',
      };
      expect(forms.length, lessThan(25));
    });
  });

  group('a scene draws only while it can be seen', () {
    testWidgets('scrolled out of the screen it stands, and goes on when it '
        'is back', (tester) async {
      await tester.pumpWidget(
        themed(
          ListView(
            children: const [
              DayScene(untilMinute: 15 * 60, score: 90),
              SizedBox(height: 3000),
            ],
          ),
        ),
      );
      expect(await moves(tester), isTrue);
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(await moves(tester), isFalse);
      await tester.drag(find.byType(ListView), const Offset(0, 1000));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(await moves(tester), isTrue);
    });

    testWidgets('where tickers are off it stands', (tester) async {
      await tester.pumpWidget(
        themed(
          const TickerMode(
            enabled: false,
            child: DayScene(untilMinute: 15 * 60, score: 90),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(await moves(tester), isFalse);
    });
  });

  testWidgets('the page beneath a page that grew out of a tile rests, and '
      'moves again when that page has closed', (tester) async {
    await pumpApp(tester);
    bool todayMoves() => TickerMode.valuesOf(
      tester.element(find.byType(BoardPage, skipOffstage: false).first),
    ).enabled;
    expect(todayMoves(), isTrue);
    await tapInView(tester, stepsTile());
    expect(todayMoves(), isFalse);
    await tester.binding.handlePopRoute();
    await tester.pump();
    // While the page closes, the one beneath shows and moves.
    await tester.pump(const Duration(milliseconds: 100));
    expect(todayMoves(), isTrue);
    await advance(tester);
    expect(todayMoves(), isTrue);
  });
}
