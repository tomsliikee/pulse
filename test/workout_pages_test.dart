import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/snapshot_builder.dart';
import 'package:pulse/features/activity/workout_detail_page.dart';
import 'package:pulse/features/activity/workout_list_page.dart';
import 'package:pulse/features/activity/workout_scene.dart';
import 'package:pulse/features/activity/workout_tiles.dart';
import 'package:pulse/l10n/generated/app_localizations.dart';
import 'package:pulse/widgets/tile_board.dart';

import 'support/fixtures.dart';

const _sizes = [Size(360, 640), Size(412, 915)];

/// One workout of every kind, newest first by the order of the enum.
FixtureRepository _everyKind() => FixtureRepository(
  readings: RawReadings(
    workouts: [
      for (final type in WorkoutType.values)
        for (var n = 0; n < 2; n++)
          Workout(
            type: type,
            start: DateTime(2026, 10, 5 - type.index, 9 + n * 8),
            minutes: 40 + n,
            kcal: 300,
            distanceKm: type == WorkoutType.strength ? null : 6.0 + n,
          ),
    ],
  ),
);

Future<void> _openActivity(WidgetTester tester, AppLocalizations l10n) async {
  await tester.tap(find.bySemanticsLabel(l10n.groupActivity));
  await advance(tester);
}

void main() {
  setUpAll(loadAppFont);

  testWidgets('the activity page starts with the latest workout, then the '
      'five before it and the way to all', (tester) async {
    await pumpApp(tester);
    await _openActivity(tester, lookupAppLocalizations(const Locale('de')));

    expect(find.byType(WorkoutScene), findsOneWidget);
    expect(find.text('Letzte Aktivität'), findsOneWidget);
    expect(find.text('18 s schneller als letztes Mal'), findsOneWidget);
    final latest = tester.getRect(find.byType(LatestWorkoutCard));
    final recent = tester.getRect(find.byType(RecentWorkoutsCard));
    expect(recent.top, greaterThan(latest.bottom));
    expect(
      find.descendant(
        of: find.byType(RecentWorkoutsCard),
        matching: find.byType(WorkoutRow),
      ),
      findsNWidgets(5),
    );
    expect(find.text('6 Aktivitäten'), findsOneWidget);
  });

  testWidgets('without a workout there are no workout tiles', (tester) async {
    await pumpApp(
      tester,
      repository: FixtureRepository(readings: const RawReadings()),
    );
    await _openActivity(tester, lookupAppLocalizations(const Locale('de')));
    expect(find.byType(WorkoutScene), findsNothing);
    expect(find.byType(RecentWorkoutsCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a workout opens its page, and back closes it', (
    tester,
  ) async {
    await pumpApp(tester);
    await _openActivity(tester, lookupAppLocalizations(const Locale('de')));
    await tester.tap(find.text('Letzte Aktivität'));
    await advance(tester);

    final page = find.byType(WorkoutDetailPage);
    expect(page, findsOneWidget);
    Finder onPage(String text) =>
        find.descendant(of: page, matching: find.text(text));
    expect(onPage('Laufen'), findsOneWidget);
    expect(onPage('6:15 min/km'), findsOneWidget);
    expect(onPage('Bestwert'), findsNWidgets(2));
    expect(onPage('Im Vergleich'), findsOneWidget);
    expect(onPage('−18 s'), findsOneWidget);
    await tester.drag(
      find.descendant(of: page, matching: find.byType(CustomScrollView)),
      const Offset(0, -3000),
    );
    await advance(tester);
    expect(onPage('So wirst du besser'), findsOneWidget);
    expect(onPage('Du bist auf Kurs. Bleib bei deinem Rhythmus.'), findsOne);

    await tester.tap(find.byType(BackButton));
    await advance(tester);
    expect(page, findsNothing);

    // A row of the list below opens the page of that workout.
    await tester.tap(find.text('Radfahren'));
    await advance(tester);
    expect(
      find.descendant(
        of: find.byType(WorkoutDetailPage),
        matching: find.textContaining('Erste Aktivität dieser Art'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the list of all workouts filters by kind', (tester) async {
    await pumpApp(tester);
    await _openActivity(tester, lookupAppLocalizations(const Locale('de')));
    await tester.ensureVisible(find.text('Alle Aktivitäten'));
    await advance(tester);
    await tester.tap(find.text('Alle Aktivitäten'));
    await advance(tester);

    final page = find.byType(WorkoutListPage);
    Finder rows() => find.descendant(
      of: page,
      matching: find.byType(WorkoutRow, skipOffstage: false),
    );
    expect(rows(), findsNWidgets(6));
    expect(
      find.descendant(of: page, matching: find.text('Oktober 2026')),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(ChoiceChip),
        matching: find.text('Spaziergang'),
      ),
    );
    await advance(tester);
    expect(rows(), findsOneWidget);
  });

  testWidgets('the workout tiles can be removed and brought back', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await _openActivity(tester, lookupAppLocalizations(const Locale('de')));
    await tester.tap(find.byTooltip('Kacheln anordnen'));
    await advance(tester);
    // The first minus belongs to the first tile, the latest workout.
    await tester.tap(find.byIcon(Icons.remove_rounded).first);
    await advance(tester);
    expect(find.byType(LatestWorkoutCard), findsNothing);
    expect(app.store.documents['settings'], contains('lastWorkout'));

    await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
    await advance(tester);
    await tester.tap(find.text('Letzte Aktivität'));
    await advance(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, 4000));
    await advance(tester);
    expect(find.byType(LatestWorkoutCard), findsOneWidget);
  });

  testWidgets('with an order saved before, the workout tiles still come '
      'first', (tester) async {
    final store = MemoryJsonStore();
    await store.write(StoreKeys.settings, {
      'tileOrder': {
        'activity': ['totalEnergy', 'chart', 'workouts'],
      },
    });
    await pumpApp(tester, store: store);
    await _openActivity(tester, lookupAppLocalizations(const Locale('de')));
    final latest = tester.getRect(find.byType(LatestWorkoutCard));
    final recent = tester.getRect(find.byType(RecentWorkoutsCard));
    expect(latest.top, lessThan(recent.top));
    // The tiles of the saved order follow them.
    final chart = tester.getRect(
      find.text('Durchschnitt pro Tag', skipOffstage: false),
    );
    expect(chart.top, greaterThan(recent.bottom));
  });

  test('a new tile that enters in place goes next to the one before it', () {
    BoardTile tile(String id, {bool inPlace = false}) => BoardTile(
      id: id,
      height: 10,
      entersInPlace: inPlace,
      child: const SizedBox.shrink(),
    );
    final first = [tile('new', inPlace: true), tile('a'), tile('b'), tile('c')];
    expect(resolveTileOrder(first, const ['b', 'a']), ['new', 'b', 'a', 'c']);
    // Once the user has placed it, it stays where it was put.
    expect(resolveTileOrder(first, const ['b', 'new', 'a']), [
      'b',
      'new',
      'a',
      'c',
    ]);

    final after = [
      tile('a'),
      tile('new', inPlace: true),
      tile('newer', inPlace: true),
      tile('b'),
    ];
    expect(resolveTileOrder(after, const []), ['a', 'new', 'newer', 'b']);
    expect(resolveTileOrder(after, const ['b', 'a']), [
      'b',
      'a',
      'new',
      'newer',
    ]);
    // Without the tile before it, it goes to the top.
    expect(resolveTileOrder(after.sublist(1), const ['b']), [
      'new',
      'newer',
      'b',
    ]);
  });

  for (final language in ['de', 'en', 'pl']) {
    for (final size in _sizes) {
      final label = '$language at ${size.width.round()}x${size.height.round()}';

      testWidgets('every kind of workout renders its page in $label', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(Locale(language));
        await pumpApp(
          tester,
          size: size,
          locale: Locale(language),
          repository: _everyKind(),
        );
        await _openActivity(tester, l10n);
        await tester.drag(find.byType(ListView).first, const Offset(0, -6000));
        await advance(tester);
        await tester.tap(find.text(l10n.allActivities));
        await advance(tester);
        expect(tester.takeException(), isNull);

        await tester.drag(
          find.descendant(
            of: find.byType(WorkoutListPage),
            matching: find.byType(CustomScrollView),
          ),
          const Offset(0, -6000),
        );
        await advance(tester);
        expect(tester.takeException(), isNull);

        final navigator = Navigator.of(
          tester.element(find.byType(WorkoutListPage)),
        );
        // The later of the two has one of its kind to be compared with.
        for (final workout in _everyKind().readings.workouts.where(
          (workout) => workout.start.hour > 12,
        )) {
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => WorkoutDetailPage(workout: workout),
            ),
          );
          await advance(tester);
          final page = find.byType(WorkoutDetailPage);
          expect(
            find.descendant(of: page, matching: find.text(l10n.compareLast)),
            findsOneWidget,
            reason: workout.type.name,
          );
          await tester.drag(
            find.descendant(of: page, matching: find.byType(CustomScrollView)),
            const Offset(0, -6000),
          );
          await advance(tester);
          expect(tester.takeException(), isNull, reason: workout.type.name);
          navigator.pop();
          await advance(tester);
        }
      });
    }
  }

  testWidgets('the scene moves, and stands still when animations are off', (
    tester,
  ) async {
    for (final type in WorkoutType.values) {
      await tester.pumpWidget(themed(Scaffold(body: WorkoutScene(type: type))));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isTrue, reason: type.name);
      expect(tester.takeException(), isNull, reason: type.name);
    }
    await tester.pumpWidget(
      themed(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: WorkoutScene(type: WorkoutType.run)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
