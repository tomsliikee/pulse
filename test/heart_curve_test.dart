import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/features/heart/heart_curve.dart';
import 'package:pulse/features/heart/heart_detail_page.dart';
import 'package:pulse/l10n/generated/app_localizations.dart';
import 'package:pulse/widgets/floating_surface.dart';
import 'package:pulse/widgets/line_chart.dart';
import 'package:pulse/widgets/segment_group.dart';

import 'support/fixtures.dart';

const _sizes = [Size(360, 640), Size(412, 915)];

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

Future<void> _openHeart(WidgetTester tester, [String label = 'Herz']) async {
  await tester.tap(find.bySemanticsLabel(label));
  await advance(tester);
}

/// The pill above the curve, if it is shown.
final Finder _pill = find.ancestor(
  of: find.textContaining(' bpm · '),
  matching: find.byType(FloatingSurface),
);

void main() {
  setUpAll(loadAppFont);

  // The fixture's day runs from 00:00 to 15:00 in steps of ten minutes.
  testWidgets('the curve reaches the edges of its tile and names the full '
      'hours where they are', (tester) async {
    await pumpApp(tester);
    await _openHeart(tester);

    final curve = tester.getRect(find.byType(HeartCurve));
    final line = tester.getRect(
      find.descendant(
        of: find.byType(HeartCurve),
        matching: find.byType(LineChart),
      ),
    );
    expect(line.left, moreOrLessEquals(curve.left));
    expect(line.right, moreOrLessEquals(curve.right));
    expect(curve.width, moreOrLessEquals(412 - 32));

    expect(find.text('00:00'), findsNothing);
    expect(find.text('15:00'), findsNothing);
    for (final (label, minute) in [('06:00', 360), ('12:00', 720)]) {
      expect(
        tester.getCenter(find.text(label)).dx,
        moreOrLessEquals(curve.left + curve.width * minute / 900),
      );
      expect(tester.getRect(find.text(label)).bottom, lessThan(curve.bottom));
    }
  });

  testWidgets('held, it says the rate and the time under the finger in a '
      'pill above the tile, which goes when the finger lifts', (tester) async {
    await pumpApp(tester);
    await _openHeart(tester);
    final played = _recordHaptics(tester);
    final curve = tester.getRect(find.byType(HeartCurve));

    final gesture = await tester.startGesture(curve.center);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_pill, findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    await advance(tester);

    // Half of 00:00 to 15:00.
    expect(find.text('81 bpm · 07:30'), findsOneWidget);
    expect(played, ['HapticFeedbackType.mediumImpact']);
    final pill = tester.getRect(_pill);
    expect(pill.bottom, lessThan(curve.top));
    expect(pill.center.dx, moreOrLessEquals(curve.center.dx));

    // Within the same ten minutes nothing changes.
    await gesture.moveBy(const Offset(1, 0));
    await advance(tester);
    expect(played, hasLength(1));

    await gesture.moveTo(Offset(curve.left + curve.width * 2 / 3, curve.top));
    await advance(tester);
    expect(find.text('79 bpm · 10:00'), findsOneWidget);
    expect(played.last, 'HapticFeedbackType.selectionClick');
    expect(played, hasLength(2));

    // At the edge the pill stays on the screen.
    await gesture.moveTo(curve.centerRight + const Offset(40, 0));
    await advance(tester);
    expect(find.text('75 bpm · 15:00'), findsOneWidget);
    expect(tester.getRect(_pill).right, moreOrLessEquals(412 - 16));
    await gesture.moveTo(curve.centerLeft - const Offset(40, 0));
    await advance(tester);
    expect(find.text('55 bpm · 00:00'), findsOneWidget);
    expect(tester.getRect(_pill).left, moreOrLessEquals(16));

    await gesture.up();
    await advance(tester);
    expect(_pill, findsNothing);
    expect(find.byType(HeartDetailPage), findsNothing);
  });

  testWidgets('a swipe that starts on the curve still scrolls the page', (
    tester,
  ) async {
    await pumpApp(tester);
    await _openHeart(tester);
    final before = tester.getRect(find.byType(HeartCurve));

    await tester.dragFrom(before.center, const Offset(0, -120));
    await advance(tester);
    expect(tester.getRect(find.byType(HeartCurve)).top, lessThan(before.top));
    expect(_pill, findsNothing);
  });

  testWidgets('where nothing is to move the pill is simply there', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpApp(tester);
    await _openHeart(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HeartCurve)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('81 bpm · 07:30'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(_pill, findsNothing);
  });

  testWidgets('in edit mode a tap on the curve opens nothing', (tester) async {
    await pumpApp(tester);
    await _openHeart(tester);
    await tester.tap(find.byTooltip('Kacheln anordnen'));
    await advance(tester);

    await tester.tap(find.byType(HeartCurve), warnIfMissed: false);
    await advance(tester);
    expect(find.byType(HeartDetailPage), findsNothing);
  });

  testWidgets('tapped, it opens the day in detail: range, curve, zones and '
      'hour by hour', (tester) async {
    await pumpApp(tester);
    await _openHeart(tester);
    await tester.tap(find.byType(HeartCurve));
    await advance(tester);

    final page = find.byType(HeartDetailPage);
    expect(page, findsOneWidget);
    Finder onPage(Finder finder) => find.descendant(of: page, matching: finder);
    expect(onPage(find.text('Dienstag, 6. Oktober')), findsOneWidget);
    expect(onPage(find.text('Tiefstwert')), findsOneWidget);
    expect(onPage(find.text('55 bpm')), findsOneWidget);
    expect(onPage(find.text('86 bpm')), findsWidgets);
    expect(onPage(find.byType(HeartCurve)), findsOneWidget);

    // The curve of the page is held like the one of the tile.
    final curve = tester.getRect(onPage(find.byType(HeartCurve)));
    final gesture = await tester.startGesture(curve.center);
    await tester.pump(const Duration(milliseconds: 400));
    await advance(tester);
    expect(find.text('81 bpm · 07:30'), findsOneWidget);
    await gesture.up();
    await advance(tester);

    final hours = onPage(find.text('Stunde für Stunde', skipOffstage: false));
    await tester.ensureVisible(hours);
    await advance(tester);
    expect(onPage(find.text('00:00 bis 01:00')), findsOneWidget);
    expect(onPage(find.text('55 bis 57 bpm')), findsWidgets);
    // 00:00 to 15:00 has a sample in sixteen hours.
    expect(
      onPage(find.byType(ListSegment, skipOffstage: false)),
      findsNWidgets(16),
    );

    await tester.ensureVisible(find.byType(BackButton));
    await tester.tap(find.byType(BackButton));
    await advance(tester);
    expect(page, findsNothing);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    for (final size in _sizes) {
      testWidgets('the curve and its page render in ${locale.languageCode} '
          'at ${size.width.round()}x${size.height.round()}', (tester) async {
        final l10n = lookupAppLocalizations(locale);
        await pumpApp(tester, size: size, locale: locale);
        await _openHeart(tester, l10n.navHeart);

        final curve = find.byType(HeartCurve);
        final gesture = await tester.startGesture(tester.getCenter(curve));
        await tester.pump(const Duration(milliseconds: 400));
        await advance(tester);
        expect(_pill, findsOneWidget);
        await gesture.up();
        await advance(tester);

        await tester.tap(curve);
        await advance(tester);
        expect(find.text(l10n.heartInDetail), findsWidgets);
        await tester.ensureVisible(
          find.text(l10n.hourByHour, skipOffstage: false),
        );
        await advance(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('a day without a curve says so on the tile and has nothing to '
      'hold', (tester) async {
    // The day after the fixture's last measurement.
    await pumpApp(tester, now: DateTime(2026, 10, 7, 0, 5));
    await _openHeart(tester);
    expect(find.byType(HeartCurve), findsNothing);
    expect(find.textContaining('kein Pulsverlauf'), findsOneWidget);
  });
}
