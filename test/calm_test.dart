import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/l10n/generated/app_localizations.dart';
import 'package:pulse/widgets/scene_kit.dart';

import 'support/fixtures.dart';

Finder _drawn() => find.descendant(
  of: find.byType(SceneClock, skipOffstage: false),
  matching: find.byType(CustomPaint, skipOffstage: false),
);

void main() {
  setUpAll(loadAppFont);

  for (final size in const [Size(360, 640), Size(412, 915)]) {
    final label = '${size.width.round()}x${size.height.round()}';

    testWidgets('the calm mode leaves every scene out at $label', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('de'));
      final store = MemoryJsonStore()
        ..documents['settings'] = '{"calm":true,"mascot":true,"simple":false}';
      await pumpApp(tester, size: size, store: store);
      expect(find.byType(SceneClock, skipOffstage: false), findsWidgets);
      expect(_drawn(), findsNothing);

      for (final destination in [
        l10n.groupActivity,
        l10n.groupSleep,
        l10n.navHeart,
      ]) {
        await tester.tap(find.bySemanticsLabel(destination));
        await advance(tester);
        expect(_drawn(), findsNothing, reason: destination);
        expect(tester.takeException(), isNull, reason: destination);
      }
    });

    testWidgets('without it the scenes are drawn at $label', (tester) async {
      await pumpApp(tester, size: size);
      expect(_drawn(), findsWidgets);
    });
  }
}
