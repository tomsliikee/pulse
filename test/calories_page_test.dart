import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/calories/calories_detail_page.dart';
import 'package:pulse/features/detail/metric_detail_page.dart';
import 'package:pulse/l10n/generated/app_localizations.dart';

import 'support/fixtures.dart';

void main() {
  setUpAll(loadAppFont);

  for (final language in const ['de', 'en', 'pl']) {
    for (final size in const [Size(360, 640), Size(412, 915)]) {
      final label = '$language at ${size.width.round()}x${size.height.round()}';

      testWidgets('the calories tile opens the page of the day in $label', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(Locale(language));
        await pumpApp(tester, size: size, locale: Locale(language));
        await tester.ensureVisible(find.text(l10n.shortCalories).first);
        await advance(tester);
        await tester.tap(find.text(l10n.shortCalories).first);
        await advance(tester);
        expect(find.byType(CaloriesDetailPage), findsOneWidget);
        expect(find.text(l10n.caloriesInDetail), findsOneWidget);
        expect(find.text(l10n.caloriesBalance), findsOneWidget);

        // Yesterday, and the spans of the burn behind "Weitere".
        await tapBarTab(tester, 1);
        expect(find.text(l10n.caloriesBalance), findsOneWidget);
        await tapBarTab(tester, 2);
        await tester.tap(find.text(l10n.caloriesHistory).last);
        await advance(tester);
        expect(find.byType(MetricDetailPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
