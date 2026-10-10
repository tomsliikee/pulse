import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/features/heart/heart_curve.dart';
import 'package:pulse/features/heart/heart_detail_page.dart';
import 'package:pulse/features/heart/heart_tiles.dart';
import 'package:pulse/l10n/generated/app_localizations.dart';
import 'package:pulse/widgets/floating_surface.dart';
import 'package:pulse/widgets/line_chart.dart';
import 'package:pulse/widgets/segment_group.dart';

import 'support/fixtures.dart';

const _sizes = [Size(360, 640), Size(412, 915)];

/// Records how strong each scaled tick was that the app asked for.
List<double> _recordTicks(WidgetTester tester) {
  const channel = MethodChannel('m3e_haptics/haptics');
  final played = <double>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
    call,
  ) async {
    played.add((call.arguments as Map)['amplitude'] as double);
    return null;
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
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
      'pill on the edge of the tile, which goes when the finger lifts', (
    tester,
  ) async {
    await pumpApp(tester);
    await _openHeart(tester);
    final played = _recordTicks(tester);
    final curve = tester.getRect(find.byType(HeartCurve));

    final gesture = await tester.startGesture(curve.center);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_pill, findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    await advance(tester);

    // Half of 00:00 to 15:00.
    expect(find.text('81 bpm · 07:30'), findsOneWidget);
    // 81 of 55 to 86: high up, so a firm tick.
    expect(played.single, moreOrLessEquals(0.15 + 0.85 * 26 / 31));
    final pill = tester.getRect(_pill);
    // Half over the tile's top edge, and clear of the title above it.
    expect(pill.center.dy, moreOrLessEquals(curve.top));
    expect(
      pill.top,
      greaterThan(tester.getRect(find.text('Tagesverlauf')).bottom),
    );
    expect(pill.center.dx, moreOrLessEquals(curve.center.dx));

    // Within the same ten minutes nothing changes, and a finger that
    // rests is not felt.
    await gesture.moveBy(const Offset(1, 0));
    await advance(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(played, hasLength(1));

    await gesture.moveTo(Offset(curve.left + curve.width * 2 / 3, curve.top));
    await advance(tester);
    expect(find.text('79 bpm · 10:00'), findsOneWidget);
    expect(played, hasLength(2));
    expect(played.last, lessThan(played.first));

    // At the edge the pill stays on the screen.
    await gesture.moveTo(curve.centerRight + const Offset(40, 0));
    await advance(tester);
    expect(find.text('75 bpm · 15:00'), findsOneWidget);
    expect(tester.getRect(_pill).right, moreOrLessEquals(412 - 16));
    await gesture.moveTo(curve.centerLeft - const Offset(40, 0));
    await advance(tester);
    expect(find.text('55 bpm · 00:00'), findsOneWidget);
    expect(tester.getRect(_pill).left, moreOrLessEquals(16));
    // The lowest rate of the day is the faintest tick.
    expect(played.last, moreOrLessEquals(0.15));

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

  testWidgets('in edit mode a tap on the curve shows nothing', (tester) async {
    await pumpApp(tester);
    await _openHeart(tester);
    await tester.tap(find.byTooltip('Kacheln anordnen'));
    await advance(tester);

    await tester.tap(find.byType(HeartCurve), warnIfMissed: false);
    await advance(tester);
    expect(_pill, findsNothing);
  });

  testWidgets('tapped, the bar stays where it was put, moves with the next '
      'tap and with the page, and goes when its place is tapped again', (
    tester,
  ) async {
    await pumpApp(tester);
    await _openHeart(tester);
    final played = _recordTicks(tester);
    final curve = tester.getRect(find.byType(HeartCurve));

    await tester.tapAt(curve.center);
    await advance(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('81 bpm · 07:30'), findsOneWidget);
    expect(find.byType(HeartDetailPage), findsNothing);
    expect(played, hasLength(1));

    await tester.tapAt(
      Offset(curve.left + curve.width * 2 / 3, curve.top + 40),
    );
    await advance(tester);
    expect(find.text('79 bpm · 10:00'), findsOneWidget);
    expect(played, hasLength(2));

    // Scrolled, the pill stays above the tile.
    final before = tester.getRect(_pill);
    await tester.dragFrom(curve.center, const Offset(0, -90));
    await advance(tester);
    final moved = tester.getRect(find.byType(HeartCurve)).top - curve.top;
    expect(moved, lessThan(-40));
    expect(tester.getRect(_pill).top, moreOrLessEquals(before.top + moved));
    expect(tester.getRect(_pill).left, moreOrLessEquals(before.left));

    final now = tester.getRect(find.byType(HeartCurve));
    await tester.tapAt(Offset(now.left + now.width * 2 / 3, now.top + 40));
    await advance(tester);
    expect(_pill, findsNothing);
    // Taking it away is not felt.
    expect(played, hasLength(2));
  });

  testWidgets('holding takes over a bar that was put down, and leaves none', (
    tester,
  ) async {
    await pumpApp(tester);
    await _openHeart(tester);
    final curve = tester.getRect(find.byType(HeartCurve));
    await tester.tapAt(curve.center);
    await advance(tester);
    expect(_pill, findsOneWidget);

    final gesture = await tester.startGesture(
      curve.centerLeft + const Offset(1, 0),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await advance(tester);
    expect(find.text('55 bpm · 00:00'), findsOneWidget);
    await gesture.up();
    await advance(tester);
    expect(_pill, findsNothing);
  });

  testWidgets('the hero opens the day in detail, and a bar left on the '
      'curve does not follow there', (tester) async {
    await pumpApp(tester);
    await _openHeart(tester);
    await tester.tapAt(tester.getCenter(find.byType(HeartCurve)));
    await advance(tester);
    expect(_pill, findsOneWidget);

    await bringIntoView(tester, find.byType(HeartDayCard));
    await tester.tap(find.byType(HeartDayCard));
    await advance(tester);
    final page = find.byType(HeartDetailPage);
    expect(page, findsOneWidget);
    expect(_pill, findsNothing);

    Finder onPage(Finder finder) => find.descendant(of: page, matching: finder);
    expect(onPage(find.text('Dienstag, 6. Oktober')), findsOneWidget);
    expect(onPage(find.text('Ø Puls des Tages')), findsOneWidget);
    expect(onPage(find.text('55 bis 86 bpm')), findsWidgets);
    expect(onPage(find.text('Gemessen von 00:00 bis 15:00')), findsOneWidget);
    expect(onPage(find.byType(HeartCurve)), findsOneWidget);
    for (final title in [
      'Der Tag in Zahlen',
      'Zeit in Zonen',
      'Tagesabschnitte',
      'Im Vergleich',
      'Die letzten Tage',
      'Werte des Tages',
      'Hinweise für dein Herz',
      'Stunde für Stunde',
    ]) {
      expect(onPage(find.text(title, skipOffstage: false)), findsOneWidget);
    }
    // The lowest of the day with when it was.
    expect(onPage(find.text('um 00:00')), findsOneWidget);
    // Until 15:00 there is a night, a morning and an afternoon.
    expect(onPage(find.text('Vormittag', skipOffstage: false)), findsOneWidget);
    expect(onPage(find.text('Abend', skipOffstage: false)), findsNothing);
    // Zones say what they cover.
    expect(
      onPage(find.text('70 bis 114 bpm', skipOffstage: false)),
      findsOneWidget,
    );

    // The curve of the page is tapped and held like the one of the tile.
    await bringIntoView(tester, onPage(find.byType(HeartCurve)));
    final curve = tester.getRect(onPage(find.byType(HeartCurve)));
    await tester.tapAt(curve.center);
    await advance(tester);
    expect(find.text('81 bpm · 07:30'), findsOneWidget);
    await tester.tapAt(curve.center);
    await advance(tester);
    expect(_pill, findsNothing);

    final hours = onPage(find.text('Stunde für Stunde', skipOffstage: false));
    await tester.ensureVisible(hours);
    await advance(tester);
    expect(onPage(find.text('00:00 bis 01:00')), findsOneWidget);
    // 00:00 to 15:00 has a sample in sixteen hours.
    expect(
      onPage(find.byType(ListSegment, skipOffstage: false)),
      findsNWidgets(16),
    );

    await tester.tap(find.byType(BackButton));
    await advance(tester);
    expect(page, findsNothing);
  });

  testWidgets('the bar at the bottom of the page and the bars of the last '
      'days lead to other days', (tester) async {
    await pumpApp(tester);
    await _openHeart(tester);
    await tester.tap(find.byType(HeartDayCard));
    await advance(tester);
    final page = find.byType(HeartDetailPage);
    Finder onPage(Finder finder) => find.descendant(of: page, matching: finder);

    await tester.tap(onPage(find.text('Gestern')));
    await advance(tester);
    expect(onPage(find.text('Montag, 5. Oktober')), findsOneWidget);
    expect(onPage(find.text('Gemessen von 00:00 bis 23:50')), findsOneWidget);
    expect(onPage(find.text('Abend', skipOffstage: false)), findsOneWidget);
    // There is no list of every day to go to.
    await tester.tap(onPage(find.text('Weitere')));
    await advance(tester);
    expect(find.text('Alle Tage'), findsNothing);
    // The card of the Herz page below has the same date; the pill is on top.
    final third = find.text(formatsOf().shortDate(DateTime(2026, 10, 3))).last;
    await tester.tap(third);
    await advance(tester);
    expect(onPage(find.text('Samstag, 3. Oktober')), findsOneWidget);

    // The last bar is today.
    final week = onPage(find.byType(HeartWeek, skipOffstage: false));
    await bringIntoView(tester, week);
    final bars = tester.getRect(week);
    await tester.tapAt(bars.centerRight - const Offset(12, 0));
    await advance(tester);
    expect(
      onPage(find.text('Dienstag, 6. Oktober', skipOffstage: false)),
      findsOneWidget,
    );
  });

  testWidgets('the days before are cards to swipe, and a card or a bar of '
      'the week opens its day', (tester) async {
    await pumpApp(tester);
    await _openHeart(tester);
    expect(find.text('Die Tage davor'), findsOneWidget);
    await bringIntoView(tester, find.byType(HeartDaysCard));
    await tester.tap(find.text(formatsOf().shortDate(DateTime(2026, 10, 5))));
    await advance(tester);
    final page = find.byType(HeartDetailPage);
    expect(
      find.descendant(of: page, matching: find.text('Montag, 5. Oktober')),
      findsOneWidget,
    );
    await tester.tap(find.byType(BackButton));
    await advance(tester);

    final week = find.byType(HeartWeek, skipOffstage: false);
    await bringIntoView(tester, week);
    await tester.tapAt(tester.getRect(week).centerLeft + const Offset(12, 0));
    await advance(tester);
    expect(
      find.descendant(of: page, matching: find.text('Mittwoch, 30. September')),
      findsOneWidget,
    );
  });

  for (final locale in AppLocalizations.supportedLocales) {
    for (final size in _sizes) {
      testWidgets('the Herz page and the day page render in '
          '${locale.languageCode} at ${size.width.round()}x'
          '${size.height.round()}', (tester) async {
        final l10n = lookupAppLocalizations(locale);
        await pumpApp(tester, size: size, locale: locale);
        await _openHeart(tester, l10n.navHeart);

        final curve = find.byType(HeartCurve);
        await bringIntoView(tester, curve);
        final gesture = await tester.startGesture(tester.getCenter(curve));
        await tester.pump(const Duration(milliseconds: 400));
        await advance(tester);
        expect(_pill, findsOneWidget);
        await gesture.up();
        await advance(tester);
        for (final tile in [
          find.byType(HeartNoteCard, skipOffstage: false),
          find.byType(HeartZones, skipOffstage: false),
          find.byType(HeartWeek, skipOffstage: false),
        ]) {
          await bringIntoView(tester, tile);
          expect(tester.takeException(), isNull);
        }

        await bringIntoView(tester, find.byType(HeartDayCard));
        await tester.tap(find.byType(HeartDayCard));
        await advance(tester);
        expect(find.text(l10n.heartInDetail), findsWidgets);
        for (final title in [
          l10n.partsOfDay,
          l10n.compareTitle,
          l10n.heartTipsTitle,
          l10n.hourByHour,
        ]) {
          await tester.ensureVisible(
            find.descendant(
              of: find.byType(HeartDetailPage),
              matching: find.text(title, skipOffstage: false),
            ),
          );
          await advance(tester);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets('a day without a curve says so on the tile and has nothing to '
      'hold', (tester) async {
    // The day after the fixture's last measurement.
    await pumpApp(tester, now: DateTime(2026, 10, 7, 0, 5));
    await _openHeart(tester);
    expect(find.byType(HeartCurve), findsNothing);
    expect(find.textContaining('kein Pulsverlauf'), findsWidgets);
    // Its page says the same and still leads to the days that have one.
    await tester.tap(find.byType(HeartDayCard));
    await advance(tester);
    final page = find.byType(HeartDetailPage);
    expect(
      find.descendant(of: page, matching: find.textContaining('kein Puls')),
      findsOneWidget,
    );
    await tester.tap(find.descendant(of: page, matching: find.text('Gestern')));
    await advance(tester);
    expect(
      find.descendant(of: page, matching: find.byType(HeartCurve)),
      findsOneWidget,
    );
  });
}
