import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

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
    final played = _recordHaptics(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Ruhepuls')),
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
    final played = _recordHaptics(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Ruhepuls')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(played, contains('HapticFeedbackType.mediumImpact'));

    await gesture.moveTo(tester.getCenter(find.text('Schlaf').first));
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
}
