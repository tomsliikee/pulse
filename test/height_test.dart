import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/settings_controller.dart';
import 'package:pulse/features/profile/height_sheet.dart';

import 'support/fixtures.dart';

void main() {
  test('a height is read from what a user types', () {
    expect(parseHeightCm('181'), 181);
    expect(parseHeightCm(' 181 cm'), 181);
    expect(parseHeightCm('181,4'), 181);
    expect(parseHeightCm('1,81'), isNull);
    expect(parseHeightCm('99'), isNull);
    expect(parseHeightCm('251'), isNull);
    expect(parseHeightCm('gross'), isNull);
  });

  test('a height is saved, loaded and taken away again', () async {
    final store = MemoryJsonStore();
    final settings = SettingsController(store)..setHeightCm(181);
    await Future<void>.delayed(Duration.zero);
    final loaded = SettingsController(store);
    await loaded.load();
    expect(loaded.heightCm, 181);

    settings.setHeightCm(300);
    expect(settings.heightCm, 181);
    settings.setHeightCm(null);
    await Future<void>.delayed(Duration.zero);
    final cleared = SettingsController(store);
    await cleared.load();
    expect(cleared.heightCm, isNull);

    store.documents['settings'] = '{"heightCm":20}';
    final refused = SettingsController(store);
    await refused.load();
    expect(refused.heightCm, isNull);
  });

  group('in the app', () {
    setUpAll(loadAppFont);

    for (final (language, title, missing) in const [
      ('de', 'Größe', 'Nicht angegeben'),
      ('en', 'Height', 'Not given'),
      ('pl', 'Wzrost', 'Nie podano'),
    ]) {
      for (final size in const [Size(360, 640), Size(412, 915)]) {
        testWidgets(
          'the profile takes a height in $language at ${size.width.round()}',
          (tester) async {
            final app = await pumpApp(
              tester,
              size: size,
              locale: Locale(language),
            );
            await tester.tap(find.byIcon(Icons.person_rounded).first);
            await advance(tester);
            // Name, birth date, height and place.
            expect(find.text(missing), findsNWidgets(4));

            await tester.tap(find.text(title));
            await advance(tester);
            await tester.enterText(find.byType(TextField), '12');
            await tester.testTextInput.receiveAction(TextInputAction.done);
            await advance(tester);
            expect(find.byType(TextField), findsOneWidget);

            await tester.enterText(find.byType(TextField), '181');
            await tester.testTextInput.receiveAction(TextInputAction.done);
            await advance(tester);
            expect(find.byType(TextField), findsNothing);
            expect(find.text('181 cm'), findsOneWidget);
            expect(app.store.documents['settings'], contains('"heightCm":181'));
          },
        );
      }
    }

    testWidgets('the body age takes the typed height for the body mass', (
      tester,
    ) async {
      final store = MemoryJsonStore()
        ..documents['settings'] =
            '{"birthDate":"1992-03-07","sex":"male","heightCm":175}';
      await pumpApp(tester, store: store);
      await tester.tap(find.text('Körperalter'));
      await advance(tester);
      await tester.drag(
        find.byType(CustomScrollView).last,
        const Offset(0, -4000),
      );
      await advance(tester);
      // The fixture's store measured 181 cm; the profile says 175.
      expect(find.text('175 cm'), findsOneWidget);
    });
  });
}
