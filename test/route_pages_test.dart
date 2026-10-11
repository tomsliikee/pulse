import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app/app_scope.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/routes.dart';
import 'package:pulse/features/activity/route_view.dart';
import 'package:pulse/features/activity/workout_detail_page.dart';
import 'package:pulse/features/activity/workout_tiles.dart';
import 'package:pulse/features/profile/profile_page.dart';
import 'package:pulse/l10n/generated/app_localizations.dart';

import 'support/fixtures.dart';

const double _metre = 1 / 111195;

/// A hilly round of [km] kilometres that begins with [workout].
WorkoutRoute _routeOf(Workout workout, {double km = 5.6, bool hills = true}) {
  const count = 2400;
  final radius = km * 1000 / (2 * math.pi);
  return routeOf(workout.start.add(const Duration(seconds: 5)), [
    for (var i = 0; i < count; i++)
      RoutePoint(
        latitude: 48.2 + math.sin(2 * math.pi * i / count) * radius * _metre,
        longitude:
            16.37 +
            math.cos(2 * math.pi * i / count) * radius * _metre * 1.5 +
            math.sin(6 * math.pi * i / count) * 0.0008,
        // Faster in the second half.
        seconds: i < count / 2 ? i * 1.0 : count / 2 + (i - count / 2) * 0.7,
        altitude: hills ? 180 + 40 * math.sin(4 * math.pi * i / count) : null,
      ),
  ])!;
}

FixtureRepository _withRoutes({bool hills = true}) {
  final workouts = fixtureReadings().workouts;
  return FixtureRepository()
    ..routes = [
      _routeOf(workouts.last, hills: hills),
      _routeOf(workouts[4], km: 19.4),
    ];
}

Future<void> _openWorkout(WidgetTester tester, Workout workout) async {
  Navigator.of(tester.element(find.byType(Scaffold).first)).push(
    MaterialPageRoute<void>(
      builder: (_) => WorkoutDetailPage(workout: workout),
    ),
  );
  await advance(tester);
}

void main() {
  setUpAll(loadAppFont);
  final de = lookupAppLocalizations(const Locale('de'));
  final last = fixtureReadings().workouts.last;

  testWidgets('a workout with a route shows its line, its kilometres and '
      'its climb', (tester) async {
    await pumpApp(tester, repository: _withRoutes());
    await _openWorkout(tester, last);
    final page = find.byType(WorkoutDetailPage);

    expect(
      find.descendant(of: page, matching: find.byType(RouteSection)),
      findsOneWidget,
    );
    final splits = tester.widget<SplitsSection>(find.byType(SplitsSection));
    expect(splits.route.splits, hasLength(5));
    // The second half is the faster one.
    expect(splits.route.fastestSplit, greaterThanOrEqualTo(3));
    expect(find.textContaining('min/km'), findsWidgets);
    expect(find.byType(ElevationSection), findsOneWidget);
    expect(find.textContaining(de.routeAscent), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a ride is told in speed, a long one in stretches', (
    tester,
  ) async {
    await pumpApp(tester, repository: _withRoutes());
    await _openWorkout(tester, fixtureReadings().workouts[4]);
    expect(find.byType(SplitsSection), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SplitsSection),
        matching: find.textContaining('km/h'),
      ),
      findsNWidgets(19),
    );
    final (step, rows) = SplitsSection.rows(List.filled(42, 5.0));
    expect(step, 5);
    expect(rows, List.filled(8, 5.0));
    expect(SplitsSection.rows(List.filled(160, 3.0)).$1, 10);
  });

  testWidgets('a route without altitude has no climb, a workout without a '
      'route none of it', (tester) async {
    await pumpApp(tester, repository: _withRoutes(hills: false));
    await _openWorkout(tester, last);
    expect(find.byType(RouteSection), findsOneWidget);
    expect(find.byType(ElevationSection), findsNothing);
    Navigator.of(tester.element(find.byType(WorkoutDetailPage))).pop();
    await advance(tester);

    await _openWorkout(tester, fixtureReadings().workouts.first);
    expect(find.byType(RouteSection), findsNothing);
    expect(find.byType(SplitsSection), findsNothing);
  });

  testWidgets('the switches take the kilometres, the climb and the small '
      'lines away, each on its own', (tester) async {
    final store = MemoryJsonStore();
    await store.write(StoreKeys.settings, {
      'routeSplits': false,
      'routeClimb': false,
      'routeOnTiles': false,
    });
    await pumpApp(tester, repository: _withRoutes(), store: store);
    final settings = AppScope.of(tester.element(find.byType(Scaffold).first))
        .settings;
    await _openWorkout(tester, last);

    expect(find.byType(RouteSection), findsOneWidget);
    expect(find.byType(SplitsSection), findsNothing);
    expect(find.byType(ElevationSection), findsNothing);

    settings.setRouteSplits(true);
    await advance(tester);
    expect(find.byType(SplitsSection), findsOneWidget);
    expect(find.byType(ElevationSection), findsNothing);
    settings.setRouteClimb(true);
    await advance(tester);
    expect(find.byType(ElevationSection), findsOneWidget);
  });

  testWidgets('rows and the latest workout show the small line, unless '
      'switched off', (tester) async {
    await pumpApp(tester, repository: _withRoutes());
    await tester.tap(find.bySemanticsLabel(de.groupActivity));
    await advance(tester);
    final settings = AppScope.of(tester.element(find.byType(LatestWorkoutCard)))
        .settings;
    expect(
      find.descendant(
        of: find.byType(LatestWorkoutCard),
        matching: find.byType(RouteThumb),
      ),
      findsOneWidget,
    );

    await tapInView(tester, find.text(de.allActivities));
    expect(find.byType(RouteThumb), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    settings.setRouteOnTiles(false);
    await advance(tester);
    expect(find.byType(RouteThumb), findsNothing);
  });

  testWidgets('the profile asks for the routes while the store holds them '
      'back', (tester) async {
    final repository = _withRoutes()..routeAccess = false;
    await pumpApp(tester, repository: repository);
    await tester.tap(find.bySemanticsLabel(de.profile));
    await advance(tester);
    expect(find.byType(ProfilePage), findsOneWidget);

    await tapInView(tester, find.text(de.routeAllow));
    await advance(tester);
    expect(repository.routeConsentRequests, hasLength(1));
    expect(find.text(de.routeAllow), findsNothing);
    expect(find.text(de.routeSplitsSwitch), findsOneWidget);
    expect(find.text(de.routeClimbSwitch), findsOneWidget);
    expect(find.text(de.routeTilesSwitch), findsOneWidget);
  });

  testWidgets('a workout asks for the routes itself while the store holds '
      'them back, and shows its line once they are allowed', (tester) async {
    final repository = _withRoutes()..routeAccess = false;
    await pumpApp(tester, repository: repository);
    await _openWorkout(tester, last);
    expect(find.byType(RouteSection), findsNothing);

    await tapInView(tester, find.text(de.routeAllow));
    await advance(tester);
    expect(repository.routeConsentRequests, hasLength(1));
    expect(find.byType(RouteConsentSection), findsNothing);
    expect(find.byType(RouteSection), findsOneWidget);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    for (final size in const [Size(360, 640), Size(412, 915)]) {
      testWidgets('a workout with a route renders in ${locale.languageCode} '
          'at ${size.width.round()}x${size.height.round()}', (tester) async {
        final l10n = lookupAppLocalizations(locale);
        await pumpApp(
          tester,
          size: size,
          locale: locale,
          repository: _withRoutes(),
        );
        for (final workout in [last, fixtureReadings().workouts[4]]) {
          await _openWorkout(tester, workout);
          expect(tester.takeException(), isNull);
          await tester.drag(
            find.descendant(
              of: find.byType(WorkoutDetailPage),
              matching: find.byType(Scrollable).first,
            ),
            const Offset(0, -1500),
          );
          await advance(tester);
          expect(tester.takeException(), isNull);
          expect(find.text(l10n.routeElevation), findsOneWidget);
          Navigator.of(tester.element(find.byType(WorkoutDetailPage))).pop();
          await advance(tester);
        }

        await tester.tap(find.bySemanticsLabel(l10n.profile));
        await advance(tester);
        await tester.scrollUntilVisible(
          find.text(l10n.routeTilesSwitch),
          300,
          scrollable: find.descendant(
            of: find.byType(ProfilePage),
            matching: find.byType(Scrollable).first,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
