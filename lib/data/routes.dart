import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'json_store.dart';
import 'models.dart';

/// One place of a route.
@immutable
class RoutePoint {
  const RoutePoint({
    required this.latitude,
    required this.longitude,
    required this.seconds,
    this.altitude,
  });

  /// In degrees.
  final double latitude;
  final double longitude;

  /// Since the first point of the route.
  final double seconds;

  /// Above sea level, in metres, where the source wrote it.
  final double? altitude;
}

/// The way of a workout over the ground: its line, made coarse enough to
/// keep, and what was read from the full line before that.
@immutable
class WorkoutRoute {
  const WorkoutRoute({
    required this.start,
    required this.points,
    required this.km,
    required this.splits,
    this.ascent,
    this.descent,
  });

  /// When the first point was recorded.
  final DateTime start;

  /// At most [routePointsAtMost], at least two.
  final List<RoutePoint> points;

  /// The length of the full line.
  final double km;

  /// The minutes each full kilometre took, in order.
  final List<double> splits;

  /// Metres climbed and descended, where the source wrote the altitude.
  final int? ascent;
  final int? descent;

  bool get hasAltitude => points.any((point) => point.altitude != null);

  /// Index into [splits] of the fastest kilometre; null without two.
  int? get fastestSplit {
    if (splits.length < 2) return null;
    var best = 0;
    for (var i = 1; i < splits.length; i++) {
      if (splits[i] < splits[best]) best = i;
    }
    return best;
  }

  Map<String, Object?> toJson() => {
    'start': start.toIso8601String(),
    'km': _round(km, 3),
    'splits': [for (final split in splits) _round(split, 3)],
    'ascent': ?ascent,
    'descent': ?descent,
    'points': [
      for (final point in points)
        [
          _round(point.latitude, 6),
          _round(point.longitude, 6),
          point.seconds.round(),
          if (point.altitude case final altitude?) _round(altitude, 1),
        ],
    ],
  };

  static WorkoutRoute? fromJson(Object? json) {
    if (json case {
      'start': final String start,
      'km': final num km,
      'splits': final List<Object?> splits,
      'points': final List<Object?> points,
    }) {
      final parsedStart = DateTime.tryParse(start);
      final parsed = <RoutePoint>[
        for (final point in points)
          if (point case [
            final num latitude,
            final num longitude,
            final num seconds,
            ...final rest,
          ])
            RoutePoint(
              latitude: latitude.toDouble(),
              longitude: longitude.toDouble(),
              seconds: seconds.toDouble(),
              altitude: switch (rest) {
                [final num altitude] => altitude.toDouble(),
                _ => null,
              },
            ),
      ];
      if (parsedStart == null || parsed.length < 2) return null;
      return WorkoutRoute(
        start: parsedStart,
        points: parsed,
        km: km.toDouble(),
        splits: [
          for (final split in splits)
            if (split is num) split.toDouble(),
        ],
        ascent: switch (json['ascent']) {
          final int value => value,
          _ => null,
        },
        descent: switch (json['descent']) {
          final int value => value,
          _ => null,
        },
      );
    }
    return null;
  }
}

double _round(double value, int digits) {
  final factor = math.pow(10, digits);
  return (value * factor).round() / factor;
}

/// The most points a kept route has: enough for a line across a phone.
const int routePointsAtMost = 200;

/// A change in altitude below this, in metres, is taken for noise.
const double _climbStep = 3;

const double _earthRadius = 6371000;

/// The metres between two places close to one another.
double metresBetween(RoutePoint a, RoutePoint b) {
  const rad = math.pi / 180;
  final x =
      (b.longitude - a.longitude) *
      rad *
      math.cos((a.latitude + b.latitude) / 2 * rad);
  final y = (b.latitude - a.latitude) * rad;
  return math.sqrt(x * x + y * y) * _earthRadius;
}

/// The minutes each full kilometre of [points] took. The time a kilometre
/// was reached lies between the two points around it.
List<double> routeSplits(List<RoutePoint> points) {
  final splits = <double>[];
  var metres = 0.0;
  var next = 1000.0;
  var last = points.isEmpty ? 0.0 : points.first.seconds;
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1];
    final b = points[i];
    final step = metresBetween(a, b);
    while (step > 0 && metres + step >= next) {
      final share = (next - metres) / step;
      final at = a.seconds + (b.seconds - a.seconds) * share;
      splits.add((at - last) / 60);
      last = at;
      next += 1000;
    }
    metres += step;
  }
  return splits;
}

/// The metres [points] climb and descend, or null where fewer than two of
/// them have an altitude. The altitude is evened out over its neighbours,
/// and only a change of [_climbStep] metres counts: a watch's altitude
/// wavers by more than a path does.
({int ascent, int descent})? routeClimb(List<RoutePoint> points) {
  final heights = [for (final point in points) ?point.altitude];
  if (heights.length < 2) return null;
  const reach = 2;
  final even = [
    for (var i = 0; i < heights.length; i++)
      () {
        final from = math.max(0, i - reach);
        final to = math.min(heights.length - 1, i + reach);
        var sum = 0.0;
        for (var j = from; j <= to; j++) {
          sum += heights[j];
        }
        return sum / (to - from + 1);
      }(),
  ];
  var up = 0.0;
  var down = 0.0;
  var held = even.first;
  for (final height in even) {
    final change = height - held;
    if (change.abs() < _climbStep) continue;
    if (change > 0) {
      up += change;
    } else {
      down -= change;
    }
    held = height;
  }
  return (ascent: up.round(), descent: down.round());
}

/// [points] with only the ones that shape the line, at most [atMost]: the
/// ones farthest from the straight way between their neighbours are kept
/// (Ramer–Douglas–Peucker), with a wider and wider margin until few
/// enough are left.
List<RoutePoint> simplifyRoute(
  List<RoutePoint> points, {
  int atMost = routePointsAtMost,
}) {
  if (points.length <= atMost) return points;
  // Metres on a plane around the first point; good enough for one workout.
  const rad = math.pi / 180;
  final scale = math.cos(points.first.latitude * rad);
  final xs = [
    for (final point in points)
      (point.longitude - points.first.longitude) * rad * scale * _earthRadius,
  ];
  final ys = [
    for (final point in points)
      (point.latitude - points.first.latitude) * rad * _earthRadius,
  ];

  double distance(int index, int from, int to) {
    final dx = xs[to] - xs[from];
    final dy = ys[to] - ys[from];
    final length = dx * dx + dy * dy;
    if (length == 0) {
      return math.sqrt(
        math.pow(xs[index] - xs[from], 2) + math.pow(ys[index] - ys[from], 2),
      );
    }
    final t =
        (((xs[index] - xs[from]) * dx + (ys[index] - ys[from]) * dy) / length)
            .clamp(0.0, 1.0);
    return math.sqrt(
      math.pow(xs[index] - xs[from] - t * dx, 2) +
          math.pow(ys[index] - ys[from] - t * dy, 2),
    );
  }

  List<int> kept(double margin) {
    final keep = List<bool>.filled(points.length, false)
      ..first = true
      ..last = true;
    final open = [(0, points.length - 1)];
    while (open.isNotEmpty) {
      final (from, to) = open.removeLast();
      var farthest = -1;
      var most = margin;
      for (var i = from + 1; i < to; i++) {
        final d = distance(i, from, to);
        if (d > most) {
          most = d;
          farthest = i;
        }
      }
      if (farthest < 0) continue;
      keep[farthest] = true;
      open
        ..add((from, farthest))
        ..add((farthest, to));
    }
    return [
      for (var i = 0; i < keep.length; i++)
        if (keep[i]) i,
    ];
  }

  var margin = 2.0;
  var indexes = kept(margin);
  while (indexes.length > atMost) {
    margin *= 1.5;
    indexes = kept(margin);
  }
  return [for (final index in indexes) points[index]];
}

/// The route of the full line [points], which begins at [start]. Null for
/// fewer than two points or a line that never leaves its place.
WorkoutRoute? routeOf(DateTime start, List<RoutePoint> points) {
  if (points.length < 2) return null;
  var metres = 0.0;
  for (var i = 1; i < points.length; i++) {
    metres += metresBetween(points[i - 1], points[i]);
  }
  if (metres < 10) return null;
  final climb = routeClimb(points);
  return WorkoutRoute(
    start: start,
    points: simplifyRoute(points),
    km: metres / 1000,
    splits: routeSplits(points),
    ascent: climb?.ascent,
    descent: climb?.descent,
  );
}

/// The route among [routes] that belongs to [workout]: the one that began
/// while it ran, give or take two minutes.
WorkoutRoute? routeFor(Workout workout, Iterable<WorkoutRoute> routes) {
  const slack = Duration(minutes: 2);
  final from = workout.start.subtract(slack);
  final to = workout.end.add(slack);
  WorkoutRoute? best;
  for (final route in routes) {
    if (route.start.isBefore(from) || route.start.isAfter(to)) continue;
    if (best == null ||
        route.start.difference(workout.start).abs() <
            best.start.difference(workout.start).abs()) {
      best = route;
    }
  }
  return best;
}

/// The speed along each stretch of [route], from 0 for the slowest to 1
/// for the fastest, evened out over its neighbours: one entry for each
/// point but the last. The slowest and fastest tenth do not set the scale,
/// so a stop at a traffic light does not flatten the rest.
List<double> routePace(WorkoutRoute route) {
  final points = route.points;
  final speeds = <double>[
    for (var i = 1; i < points.length; i++)
      () {
        final seconds = points[i].seconds - points[i - 1].seconds;
        return seconds <= 0
            ? double.nan
            : metresBetween(points[i - 1], points[i]) / seconds;
      }(),
  ];
  final known = [
    for (final speed in speeds)
      if (!speed.isNaN) speed,
  ]..sort();
  if (known.isEmpty) return List.filled(speeds.length, 0.5);
  final low = known[(known.length * 0.1).floor()];
  final high = known[math.min(known.length - 1, (known.length * 0.9).floor())];
  if (high - low < 1e-6) return List.filled(speeds.length, 0.5);
  final shares = [
    for (final speed in speeds)
      speed.isNaN ? 0.5 : ((speed - low) / (high - low)).clamp(0.0, 1.0),
  ];
  return [
    for (var i = 0; i < shares.length; i++)
      () {
        final from = math.max(0, i - 1);
        final to = math.min(shares.length - 1, i + 1);
        var sum = 0.0;
        for (var j = from; j <= to; j++) {
          sum += shares[j];
        }
        return sum / (to - from + 1);
      }(),
  ];
}

/// What a read of the routes of a stretch of time gave.
typedef RouteReading = ({
  List<WorkoutRoute> routes,

  /// The store's id of a workout whose route the user has to allow first;
  /// null where none asked for that.
  String? consentFor,
});

/// Keeps the route of every workout the app has read one for, a document
/// for each year: the store hands a route out only as long as it keeps
/// the workout, and reading it again means reading every point.
class RouteArchive {
  const RouteArchive(this._store);

  final JsonStore _store;

  static const int schemaVersion = 1;
  static const String prefix = 'routes-';

  static String _name(int year) => '$prefix$year';

  /// Every route kept, by the key of its workout. A workout the store had
  /// no route for is kept as null, so it is not asked for again.
  Future<Map<String, WorkoutRoute?>> load() async {
    final all = <String, WorkoutRoute?>{};
    for (final name in await _store.names()) {
      if (name.startsWith(prefix)) all.addAll(await _read(name));
    }
    return all;
  }

  Future<Map<String, WorkoutRoute?>> _read(String name) async {
    final json = await _store.read(name);
    if (json case {
      'version': schemaVersion,
      'routes': final Map<String, Object?> routes,
    }) {
      return {
        for (final MapEntry(:key, :value) in routes.entries)
          key: value == null ? null : WorkoutRoute.fromJson(value),
      };
    }
    return {};
  }

  /// Adds [found], by the keys of the workouts they belong to, to what is
  /// stored.
  Future<void> add(Map<String, WorkoutRoute?> found) async {
    final byYear = <int, Map<String, WorkoutRoute?>>{};
    for (final MapEntry(:key, value: route) in found.entries) {
      // A key ends with the start of its workout.
      final start = DateTime.tryParse(key.substring(key.indexOf('@') + 1));
      if (start == null) continue;
      byYear.putIfAbsent(start.year, () => {})[key] = route;
    }
    for (final MapEntry(key: year, value: routes) in byYear.entries) {
      final stored = await _read(_name(year))
        ..addAll(routes);
      await _store.write(_name(year), {
        'version': schemaVersion,
        'routes': {
          for (final MapEntry(:key, :value) in stored.entries)
            key: value?.toJson(),
        },
      });
    }
  }
}
