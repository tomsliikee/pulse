import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/backup.dart';
import 'package:pulse/data/health_controller.dart';
import 'package:pulse/data/json_store.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/routes.dart';

import 'support/fixtures.dart';

/// A metre of latitude, in degrees.
const double _metre = 1 / 111195;

/// [count] points going north from Vienna, [metres] apart and [seconds]
/// after one another, with [altitude] by the index.
List<RoutePoint> _north(
  int count, {
  double metres = 10,
  double seconds = 4,
  double? Function(int index)? altitude,
}) => [
  for (var i = 0; i < count; i++)
    RoutePoint(
      latitude: 48.2 + i * metres * _metre,
      longitude: 16.37,
      seconds: i * seconds,
      altitude: altitude?.call(i),
    ),
];

/// A round of [count] points with a [radius] in metres.
List<RoutePoint> _round(int count, {double radius = 500}) => [
  for (var i = 0; i < count; i++)
    RoutePoint(
      latitude: 48.2 + math.sin(2 * math.pi * i / count) * radius * _metre,
      longitude:
          16.37 +
          math.cos(2 * math.pi * i / count) *
              radius *
              _metre /
              math.cos(48.2 * math.pi / 180),
      seconds: i * 2,
    ),
];

HealthController _controller(FixtureRepository repository, JsonStore store) {
  final health = HealthController(
    repository: repository,
    store: store,
    clock: () => fixtureNow,
  );
  addTearDown(health.dispose);
  return health;
}

void main() {
  group('the numbers of a line', () {
    test('metres between two places', () {
      final points = _north(2, metres: 1000);
      expect(metresBetween(points[0], points[1]), closeTo(1000, 1));
    });

    test('each full kilometre has its minutes, the rest has none', () {
      // 2.5 km at 10 m every 4 s: 400 s a kilometre.
      final splits = routeSplits(_north(251));
      expect(splits, hasLength(2));
      expect(splits[0], closeTo(400 / 60, 0.01));
      expect(splits[1], closeTo(400 / 60, 0.01));
      expect(routeSplits(_north(50)), isEmpty);
      expect(routeSplits(const []), isEmpty);
    });

    test('a kilometre reached between two points is timed between them', () {
      // One step of 1500 m in 600 s: the first kilometre after 400 s.
      final splits = routeSplits(_north(2, metres: 1500, seconds: 600));
      expect(splits.single, closeTo(400 / 60, 0.01));
    });

    test('a climb counts, the wavering of a watch does not', () {
      // Up 100 m evenly, then down 40 m.
      final climb = routeClimb(
        _north(141, altitude: (i) => i <= 100 ? 200.0 + i : 300.0 - (i - 100)),
      )!;
      expect(climb.ascent, closeTo(100, 4));
      expect(climb.descent, closeTo(40, 4));

      final flat = routeClimb(
        _north(200, altitude: (i) => 200 + (i.isEven ? 1.0 : -1.0)),
      )!;
      expect(flat.ascent, 0);
      expect(flat.descent, 0);
      expect(routeClimb(_north(50)), isNull);
    });
  });

  group('simplifyRoute', () {
    test('a straight line keeps its ends only', () {
      final line = simplifyRoute(_north(500), atMost: 100);
      expect(line, hasLength(2));
      expect(line.first.seconds, 0);
      expect(line.last.seconds, 499 * 4);
    });

    test('a round keeps its shape in few enough points', () {
      final full = _round(3000);
      final round = simplifyRoute(full);
      expect(round.length, lessThanOrEqualTo(routePointsAtMost));
      expect(round.length, greaterThan(20));
      // Every point kept is one of the line, in order.
      expect(round.first.seconds, full.first.seconds);
      expect(round.last.seconds, full.last.seconds);
      for (var i = 1; i < round.length; i++) {
        expect(round[i].seconds, greaterThan(round[i - 1].seconds));
      }
      // And none lies off the circle.
      for (final point in round) {
        final north = (point.latitude - 48.2) / _metre;
        final east =
            (point.longitude - 16.37) / _metre * math.cos(48.2 * math.pi / 180);
        expect(math.sqrt(north * north + east * east), closeTo(500, 1));
      }
    });

    test('a short line is left as it is', () {
      final points = _round(50);
      expect(identical(simplifyRoute(points), points), isTrue);
    });
  });

  group('routeOf', () {
    final start = DateTime(2026, 10, 3, 7, 25);

    test('reads the full line and keeps the coarse one', () {
      final route = routeOf(start, _round(3000))!;
      expect(route.km, closeTo(math.pi, 0.01));
      expect(route.splits, hasLength(3));
      expect(route.points.length, lessThanOrEqualTo(routePointsAtMost));
      expect(route.hasAltitude, isFalse);
      expect(route.ascent, isNull);
    });

    test('a line that never leaves its place is no route', () {
      expect(routeOf(start, _north(100, metres: 0)), isNull);
      expect(routeOf(start, _north(1)), isNull);
    });

    test('survives being written and read', () {
      final route = routeOf(
        start,
        _north(300, altitude: (i) => 180 + i * 0.5),
      )!;
      final read = WorkoutRoute.fromJson(route.toJson())!;
      expect(read.toJson(), route.toJson());
      expect(read.start, start);
      expect(read.ascent, route.ascent);
      expect(read.points.first.altitude, 180);
      expect(WorkoutRoute.fromJson({'start': 'x'}), isNull);
    });

    test('the fastest kilometre is named where there are two', () {
      // The second kilometre in half the time.
      final points = [
        ..._north(101),
        for (final point in _north(105).skip(1))
          RoutePoint(
            latitude: point.latitude + 1000 * _metre,
            longitude: point.longitude,
            seconds: 400 + point.seconds / 2,
          ),
      ];
      final route = routeOf(start, points)!;
      expect(route.splits, hasLength(2));
      expect(route.fastestSplit, 1);
      expect(routeOf(start, _north(150))!.fastestSplit, isNull);
    });

    test('the pace along the line runs from 0 to 1', () {
      final points = [
        ..._north(50),
        for (final point in _north(50).skip(1))
          RoutePoint(
            latitude: point.latitude + 490 * _metre,
            longitude: point.longitude,
            seconds: 196 + point.seconds / 3,
          ),
      ];
      final route = WorkoutRoute(
        start: start,
        points: points,
        km: 1,
        splits: const [],
      );
      final pace = routePace(route);
      expect(pace, hasLength(points.length - 1));
      expect(pace.first, closeTo(0, 1e-6));
      expect(pace.last, closeTo(1, 1e-6));
      expect(pace.every((share) => share >= 0 && share <= 1), isTrue);
    });
  });

  test('a route belongs to the workout it began in', () {
    final workout = Workout(
      type: WorkoutType.walk,
      start: DateTime(2026, 10, 3, 7, 25),
      minutes: 51,
    );
    WorkoutRoute at(DateTime start) =>
        WorkoutRoute(start: start, points: _north(2), km: 1, splits: const []);
    final own = at(DateTime(2026, 10, 3, 7, 25, 20));
    expect(
      routeFor(workout, [
        at(DateTime(2026, 10, 3, 6, 12)),
        own,
        at(DateTime(2026, 10, 3, 9)),
      ]),
      same(own),
    );
    expect(routeFor(workout, [at(DateTime(2026, 10, 4, 7, 25))]), isNull);
  });

  group('RouteArchive', () {
    test('keeps routes by the year of their workout, and that a workout '
        'has none', () async {
      final store = MemoryJsonStore();
      final archive = RouteArchive(store);
      final route = routeOf(DateTime(2025, 12, 31, 23, 50), _north(300))!;
      await archive.add({
        'walk@2025-12-31T23:50:00.000': route,
        'run@2026-01-01T08:00:00.000': null,
      });
      expect(
        (await store.names()).where((name) => name.startsWith('routes-')),
        unorderedEquals(['routes-2025', 'routes-2026']),
      );
      final all = await archive.load();
      expect(all, hasLength(2));
      expect(all['walk@2025-12-31T23:50:00.000']!.km, closeTo(route.km, 0.001));
      expect(all.containsKey('run@2026-01-01T08:00:00.000'), isTrue);
      expect(all['run@2026-01-01T08:00:00.000'], isNull);
    });
  });

  group('HealthController', () {
    WorkoutRoute routeOfWorkout(Workout workout) =>
        routeOf(workout.start.add(const Duration(seconds: 10)), _round(600))!;

    test('the routes of the window are read once and kept', () async {
      final store = MemoryJsonStore();
      final workouts = fixtureReadings().workouts;
      final repository = FixtureRepository()
        ..routes = [routeOfWorkout(workouts.last), routeOfWorkout(workouts[3])];
      final health = _controller(repository, store);
      await health.start();

      expect(health.routesNeedConsent, isFalse);
      expect(health.routeOf(health.workouts.last)!.km, closeTo(3.14, 0.01));
      expect(health.routeOf(health.workouts[3]), isNotNull);
      expect(health.routeOf(health.workouts.first), isNull);
      expect(repository.routeRequests, hasLength(1));

      // Every workout is known now, with a route or without.
      await health.refresh();
      expect(repository.routeRequests, hasLength(1));
      final again = _controller(repository, store);
      await again.start();
      expect(repository.routeRequests, hasLength(1));
      expect(again.routeOf(again.workouts.last), isNotNull);
    });

    test('without the consent nothing is kept, not even that a workout has '
        'no route; with it the routes come', () async {
      final store = MemoryJsonStore();
      final workouts = fixtureReadings().workouts;
      final repository = FixtureRepository()
        ..routeAccess = false
        ..routes = [routeOfWorkout(workouts.last)];
      final health = _controller(repository, store);
      await health.start();

      expect(health.routesNeedConsent, isTrue);
      expect(health.routeOf(health.workouts.last), isNull);
      expect(await RouteArchive(store).load(), isEmpty);
      // Not asked for again and again while the answer is known.
      await health.refresh();
      expect(repository.routeRequests, hasLength(1));

      repository.grantsRoutes = false;
      await health.requestRoutes();
      expect(repository.routeConsentRequests, ['session-1']);
      expect(health.routesNeedConsent, isTrue);

      repository.grantsRoutes = true;
      await health.requestRoutes();
      expect(health.routesNeedConsent, isFalse);
      expect(health.routeOf(health.workouts.last), isNotNull);
      expect(await RouteArchive(store).load(), hasLength(6));
    });

    test('the routes of older workouts are fetched once', () async {
      final store = MemoryJsonStore();
      final old = Workout(
        type: WorkoutType.hike,
        start: DateTime(2026, 6, 1, 7),
        minutes: 120,
      );
      final repository = FixtureRepository()
        ..historyAccess = true
        ..olderDays = fixtureOlderDays()
        ..olderWorkouts = [old]
        ..routes = [routeOfWorkout(old)];
      final health = _controller(repository, store);
      await health.start();

      expect(health.routeOf(health.workouts.first), isNotNull);
      final requests = repository.routeRequests.length;
      expect(requests, greaterThan(1));
      await _controller(repository, store).start();
      expect(repository.routeRequests.length, requests);
    });
  });

  test(
    'a backup carries the routes, and brings the ones the app has not',
    () async {
      final from = MemoryJsonStore();
      final route = routeOf(DateTime(2026, 10, 3, 7, 25), _round(600))!;
      await RouteArchive(from).add({
        'walk@2026-10-03T07:25:00.000': route,
        'run@2026-10-04T07:25:00.000': route,
      });
      final text = await exportBackup(from, fixtureNow);

      final to = MemoryJsonStore();
      // Known to be without a route here, and one the app has itself.
      final own = routeOf(DateTime(2026, 10, 4, 7, 25), _north(300))!;
      await RouteArchive(to).add({
        'walk@2026-10-03T07:25:00.000': null,
        'run@2026-10-04T07:25:00.000': own,
      });
      await importBackup(to, text, fixtureNow);
      final all = await RouteArchive(to).load();
      expect(all['walk@2026-10-03T07:25:00.000']!.km, closeTo(route.km, 0.001));
      expect(all['run@2026-10-04T07:25:00.000']!.km, closeTo(own.km, 0.001));
    },
  );
}
