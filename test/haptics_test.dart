import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app/haptics.dart';
import 'package:pulse/data/settings_controller.dart';

import 'support/fixtures.dart';

/// Records the haptic types the app asks the platform for.
List<String> _recordHaptics(WidgetTester tester) {
  final played = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        played.add(call.arguments as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return played;
}

void main() {
  setUpAll(loadAppFont);

  testWidgets('changing the destination clicks, staying does not', (
    tester,
  ) async {
    await pumpApp(tester);
    final played = _recordHaptics(tester);

    await tester.tap(find.bySemanticsLabel('Schlaf'));
    await advance(tester);
    expect(played, ['HapticFeedbackType.selectionClick']);

    await tester.tap(find.bySemanticsLabel('Schlaf'));
    await advance(tester);
    expect(played, hasLength(1));
  });

  testWidgets('pressing a tile gives a light tap', (tester) async {
    await pumpApp(tester);
    await bringIntoView(tester, find.text('Herzfrequenz'));
    final played = _recordHaptics(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Herzfrequenz')),
    );
    await tester.pump();
    expect(played, ['HapticFeedbackType.lightImpact']);
    await gesture.cancel();
    await advance(tester);
  });

  testWidgets('picking up a tile and passing another one are felt', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Kacheln anordnen'));
    await advance(tester);
    await bringIntoView(tester, find.text('Herzfrequenz'));
    final played = _recordHaptics(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Herzfrequenz')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(played, contains('HapticFeedbackType.mediumImpact'));

    await gesture.moveTo(tester.getCenter(tileTitled('Wasser')));
    await tester.pump();
    expect(played.last, 'HapticFeedbackType.selectionClick');
    await gesture.up();
    await advance(tester);
  });

  testWidgets('saving an entry confirms with a strong signal', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await advance(tester);
    await tester.tap(find.text('Wasser').hitTestable().last);
    await advance(tester);
    final played = _recordHaptics(tester);

    await tester.tap(find.text('500 ml').hitTestable());
    await tester.pump();
    await tester.tap(find.text('Speichern').hitTestable());
    await advance(tester);

    expect(played.last, 'HapticFeedbackType.heavyImpact');
  });

  test(
    'the haptics are on until switched off, and the choice is kept',
    () async {
      final store = MemoryJsonStore();
      final settings = SettingsController(store);
      expect(settings.haptics, isTrue);
      settings.setHaptics(false);
      await Future<void>.delayed(Duration.zero);
      final loaded = SettingsController(store);
      await loaded.load();
      expect(loaded.haptics, isFalse);
    },
  );

  testWidgets('switched off in the settings, nothing is played', (
    tester,
  ) async {
    addTearDown(() => Haptics.enabled = true);
    final store = MemoryJsonStore()
      ..documents['settings'] = '{"simple":false,"haptics":false}';
    await pumpApp(tester, store: store);
    final played = _recordHaptics(tester);

    await tester.tap(find.bySemanticsLabel('Schlaf'));
    await advance(tester);
    final gesture = await tester.startGesture(const Offset(200, 400));
    await tester.pump();
    await gesture.cancel();
    await advance(tester);
    Haptics.selection();
    Haptics.tap();
    Haptics.lift();
    Haptics.confirm();
    Haptics.scaled(0.5);
    expect(played, isEmpty);
    expect(Haptics.widget.value, 0);
  });

  for (final (language, label) in const [
    ('de', 'Haptik'),
    ('en', 'Haptics'),
    ('pl', 'Haptyka'),
  ]) {
    for (final size in const [Size(360, 640), Size(412, 915)]) {
      testWidgets('the profile switches the haptics off and on in $language at '
          '${size.width.round()}', (tester) async {
        addTearDown(() => Haptics.enabled = true);
        final app = await pumpApp(tester, size: size, locale: Locale(language));
        await tester.tap(find.byIcon(Icons.person_rounded).first);
        await advance(tester);
        await bringIntoView(tester, find.text(label));
        final toggle = find.descendant(
          of: find.ancestor(of: find.text(label), matching: find.byType(Row)),
          matching: find.byType(Switch),
        );
        final played = _recordHaptics(tester);

        // Silent on the way off, felt on the way back on.
        await tester.tap(toggle);
        await advance(tester);
        expect(Haptics.enabled, isFalse);
        expect(played, isEmpty);
        expect(app.store.documents['settings'], contains('"haptics":false'));

        await tester.tap(toggle);
        await advance(tester);
        expect(Haptics.enabled, isTrue);
        expect(played, ['HapticFeedbackType.selectionClick']);
        expect(app.store.documents['settings'], contains('"haptics":true'));
      });
    }
  }
}
