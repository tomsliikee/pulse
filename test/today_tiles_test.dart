import 'package:flutter_test/flutter_test.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/metric_catalog.dart';
import 'package:pulse/data/settings_controller.dart';
import 'package:pulse/data/snapshot_builder.dart';
import 'package:pulse/features/detail/metric_tiles.dart';

import 'support/fixtures.dart';

const _sizes = [Size(360, 640), Size(412, 915)];

DateTime _at(int daysAgo, int hour, [int minute = 0]) => DateTime(
  fixtureNow.year,
  fixtureNow.month,
  fixtureNow.day - daysAgo,
  hour,
  minute,
);

Future<void> _edit(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Kacheln anordnen'));
  await advance(tester);
}

void main() {
  setUpAll(loadAppFont);

  group('tileReading', () {
    test('a total is today\'s, even when it is missing', () {
      final snapshot = buildSnapshot(
        now: fixtureNow,
        raw: RawReadings(samples: [RawSample(Metric.steps, _at(1, 9), 4000)]),
      );

      expect(tileReading(formatsOf(), snapshot, Metric.steps), (
        value: null,
        note: null,
      ));
    });

    test('a measurement taken now and then shows the latest with its day', () {
      final snapshot = buildSnapshot(
        now: fixtureNow,
        raw: RawReadings(
          samples: [
            RawSample(Metric.weight, _at(5, 7), 113),
            RawSample(Metric.restingHeartRate, _at(1, 7), 68),
            RawSample(Metric.height, _at(0, 7), 181),
          ],
        ),
      );

      expect(tileReading(formatsOf(), snapshot, Metric.weight), (
        value: 113.0,
        note: 'Do, 1.10.',
      ));
      expect(tileReading(formatsOf(), snapshot, Metric.restingHeartRate), (
        value: 68.0,
        note: 'gestern',
      ));
      expect(tileReading(formatsOf(), snapshot, Metric.height), (
        value: 181.0,
        note: null,
      ));
    });

    test('the heart rate is the latest sample of today', () {
      final snapshot = buildSnapshot(
        now: fixtureNow,
        raw: RawReadings(
          samples: [
            RawSample(Metric.heartRate, _at(0, 8), 61),
            RawSample(Metric.heartRate, _at(0, 14, 20), 82),
          ],
        ),
      );

      expect(tileReading(formatsOf(), snapshot, Metric.heartRate), (
        value: 82.0,
        note: 'Zuletzt um 14:20',
      ));
    });
  });

  testWidgets('Today shows the heart rate and no figures without data', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Herzfrequenz'), findsOneWidget);
    expect(find.text('Ruhepuls'), findsNothing);
    expect(find.text('Minuten'), findsNothing);
    expect(find.text('Etagen'), findsNothing);
    expect(find.text('Kilometer'), findsOneWidget);
  });

  testWidgets('the corner buttons only exist while editing', (tester) async {
    await pumpApp(tester);
    expect(find.byTooltip('Entfernen').hitTestable(), findsNothing);
    expect(find.byTooltip('Verkleinern').hitTestable(), findsNothing);

    await _edit(tester);

    expect(find.byTooltip('Entfernen').hitTestable(), findsWidgets);
    expect(find.byTooltip('Verkleinern').hitTestable(), findsWidgets);
  });

  testWidgets('the minus removes a tile for good, the plus brings it back', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await _edit(tester);

    // The first minus belongs to the first tile, the steps.
    await tester.tap(find.byTooltip('Entfernen').hitTestable().first);
    await advance(tester);
    expect(find.text('Alter festlegen'), findsNothing);

    // A fresh start with the same store still leaves it out.
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, store: app.store);
    expect(find.text('Alter festlegen'), findsNothing);

    await _edit(tester);
    final offer = find.text('Schritte');
    await tester.scrollUntilVisible(
      offer,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await advance(tester);
    await tester.tap(offer);
    await advance(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, 4000));
    await advance(tester);
    await tester.tap(find.byTooltip('Fertig'));
    await advance(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
    await advance(tester);

    expect(find.text('Alter festlegen'), findsOneWidget);
  });

  testWidgets('only measurements with data are offered', (tester) async {
    await pumpApp(tester);
    await _edit(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
    await advance(tester);

    // The fixture has a resting heart rate and no blood glucose.
    expect(find.text('Hinzufügen', skipOffstage: false), findsOneWidget);
    expect(find.text('Ruhepuls', skipOffstage: false), findsOneWidget);
    expect(find.text('Blutzucker', skipOffstage: false), findsNothing);
  });

  testWidgets('the resize button turns a small tile into a wide one', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    final title = find.text('Herzfrequenz');
    final before = tester.getSize(
      find.ancestor(of: title, matching: find.byType(Material)).first,
    );
    await _edit(tester);

    // Steps are large by default, so the first tile to enlarge is the next.
    await tester.tap(find.byTooltip('Vergrössern').hitTestable().first);
    await advance(tester);

    final after = tester.getSize(
      find.ancestor(of: title, matching: find.byType(Material)).first,
    );
    expect(after.width, greaterThan(before.width * 1.8));
    expect(after.height, greaterThan(before.height));
    expect(find.text('55 bis 86 bpm'), findsOneWidget);
    expect(
      app.store.documents['settings'],
      contains('"largeTiles":["steps","energyIntake","heartRate"]'),
    );
  });

  testWidgets('a tap on a corner button does not lift the tile', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await _edit(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byTooltip('Entfernen').hitTestable().first),
    );
    // Longer than the hold that starts a drag.
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveBy(const Offset(0, 300));
    await gesture.up();
    await advance(tester);

    expect(
      app.store.documents['settings'] ?? '',
      isNot(contains('tileOrder":{"today"')),
    );
  });

  for (final size in _sizes) {
    final label = '${size.width.round()}x${size.height.round()}';
    for (final large in [false, true]) {
      testWidgets('every tile renders ${large ? 'large' : 'small'} at $label', (
        tester,
      ) async {
        final ids = [
          for (final metric in Metric.values) metric.name,
          workoutTileId,
        ];
        final store = MemoryJsonStore();
        await store.write('settings', {
          'todayTiles': ids,
          'largeTiles': large ? ids : <String>[],
        });
        await pumpApp(tester, size: size, store: store);
        await tester.drag(find.byType(ListView).first, const Offset(0, -9000));
        await advance(tester);
        await tester.drag(find.byType(ListView).first, const Offset(0, 9000));
        await advance(tester);
        await _edit(tester);
        await tester.drag(find.byType(ListView).first, const Offset(0, -9000));
        await advance(tester);
      });
    }
  }

  group('the shape behind the rings', () {
    double turns(WidgetTester tester) => tester
        .widget<RotationTransition>(
          find
              .ancestor(
                of: find.byWidgetPredicate(
                  (w) => w is M3EShape && w.width == 212,
                ),
                matching: find.byType(RotationTransition),
              )
              .first,
        )
        .turns
        .value;

    testWidgets('turns slowly', (tester) async {
      await pumpApp(tester);
      final before = turns(tester);
      await tester.pump(const Duration(seconds: 9));
      expect((turns(tester) - before) % 1, moreOrLessEquals(0.1));
    });

    testWidgets('stands still when animations are off', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpApp(tester);
      final before = turns(tester);
      await tester.pump(const Duration(seconds: 9));
      expect(turns(tester), before);
    });
  });
}
