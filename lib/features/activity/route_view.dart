import 'dart:math' as math;

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/formatters.dart';
import '../../data/models.dart';
import '../../data/routes.dart';
import '../../data/workout_insights.dart';
import '../../theme/page_accent.dart';
import '../../widgets/page_header.dart';
import '../../widgets/stat_tile.dart';
import 'workout_format.dart';

/// The line of [route], north up, as large as it fits. With [pace], each
/// stretch is tinted by how fast it was, from [color] for the slowest to
/// [fast] for the fastest, and the start and the end are marked.
class RouteLine extends StatelessWidget {
  const RouteLine({
    super.key,
    required this.route,
    required this.color,
    this.fast,
    this.pace = false,
    this.stroke = 2,
  });

  final WorkoutRoute route;
  final Color color;
  final Color? fast;
  final bool pace;
  final double stroke;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _LinePainter(
      route: route,
      color: color,
      fast: fast ?? color,
      pace: pace,
      stroke: stroke,
      surface: Theme.of(context).colorScheme.surfaceBright,
    ),
    size: Size.infinite,
  );
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.route,
    required this.color,
    required this.fast,
    required this.pace,
    required this.stroke,
    required this.surface,
  });

  final WorkoutRoute route;
  final Color color;
  final Color fast;
  final bool pace;
  final double stroke;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final points = route.points;
    if (size.isEmpty || points.length < 2) return;
    // Degrees of longitude are shorter than those of latitude away from
    // the equator.
    final squeeze = math.cos(points.first.latitude * math.pi / 180);
    var west = double.infinity, east = -double.infinity;
    var south = double.infinity, north = -double.infinity;
    for (final point in points) {
      west = math.min(west, point.longitude * squeeze);
      east = math.max(east, point.longitude * squeeze);
      south = math.min(south, point.latitude);
      north = math.max(north, point.latitude);
    }
    final inset = stroke * (pace ? 3 : 1);
    final width = size.width - 2 * inset;
    final height = size.height - 2 * inset;
    final spanX = math.max(east - west, 1e-9);
    final spanY = math.max(north - south, 1e-9);
    final scale = math.min(width / spanX, height / spanY);
    final left = inset + (width - spanX * scale) / 2;
    final top = inset + (height - spanY * scale) / 2;
    Offset at(RoutePoint point) => Offset(
      left + (point.longitude * squeeze - west) * scale,
      top + (north - point.latitude) * scale,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (!pace) {
      final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
      for (final point in points.skip(1)) {
        final offset = at(point);
        path.lineTo(offset.dx, offset.dy);
      }
      canvas.drawPath(path, paint..color = color);
      return;
    }
    final shares = routePace(route);
    for (var i = 1; i < points.length; i++) {
      canvas.drawLine(
        at(points[i - 1]),
        at(points[i]),
        paint..color = Color.lerp(color, fast, shares[i - 1])!,
      );
    }
    void mark(Offset centre, {required bool filled}) {
      canvas
        ..drawCircle(centre, stroke * 2.2, Paint()..color = surface)
        ..drawCircle(
          centre,
          stroke * (filled ? 1.5 : 1.3),
          Paint()
            ..color = fast
            ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
            ..strokeWidth = stroke * 0.7,
        );
    }

    mark(at(points.first), filled: false);
    mark(at(points.last), filled: true);
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.route != route ||
      old.color != color ||
      old.fast != fast ||
      old.pace != pace ||
      old.stroke != stroke ||
      old.surface != surface;
}

/// The line of a route in a small round field, for a row or a tile.
class RouteThumb extends StatelessWidget {
  const RouteThumb({super.key, required this.route, this.size = 44});

  final WorkoutRoute route;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.2),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          shape: BoxShape.circle,
        ),
        child: RouteLine(route: route, color: scheme.onSurface, stroke: 1.6),
      ),
    );
  }
}

/// Shown in place of the route while the store holds the routes back: what
/// to choose in its dialog, and the button that opens it.
class RouteConsentSection extends StatelessWidget {
  const RouteConsentSection({super.key, required this.onAllow});

  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = Formats.of(context).l10n;
    return TitledSection(
      title: l10n.routeTitle,
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.routeConsentNote,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            M3EFilledButton.tonal(
              onPressed: onAllow,
              child: Text(l10n.routeAllow),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the workout went: the line of its route, tinted by its speed.
class RouteSection extends StatelessWidget {
  const RouteSection({super.key, required this.route});

  final WorkoutRoute route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = Formats.of(context).l10n;
    final accent = PageAccent.colorsOf(context);
    final slow = Color.lerp(accent.accent, scheme.surfaceBright, 0.65)!;
    final label = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return TitledSection(
      title: l10n.routeTitle,
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 220,
              child: RouteLine(
                route: route,
                color: slow,
                fast: accent.accent,
                pace: true,
                stroke: 4,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(l10n.routeSlow, style: label),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(colors: [slow, accent.accent]),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(l10n.routeFast, style: label),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The time each kilometre took, as bars: the faster, the longer. A long
/// way is shown in stretches of five or ten kilometres.
class SplitsSection extends StatelessWidget {
  const SplitsSection({super.key, required this.route, required this.type});

  final WorkoutRoute route;
  final WorkoutType type;

  /// The rows the section has at most before kilometres are put together.
  static const int rowsAtMost = 20;

  /// The kilometres one row stands for, and the minutes per kilometre of
  /// each row.
  static (int, List<double>) rows(List<double> splits) {
    final step = splits.length <= rowsAtMost
        ? 1
        : splits.length <= rowsAtMost * 5
        ? 5
        : 10;
    return (
      step,
      [
        for (var i = 0; i + step <= splits.length; i += step)
          splits.sublist(i, i + step).reduce((a, b) => a + b) / step,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final accent = PageAccent.colorsOf(context);
    final (step, rows) = SplitsSection.rows(route.splits);
    final fastest = rows.reduce(math.min);
    final best = rows.length < 2 ? -1 : rows.indexOf(fastest);
    String text(double minutes) => type.rolls
        ? WorkoutMeasure.speed.format(formats, type, 60 / minutes)
        : WorkoutMeasure.pace.format(formats, type, minutes);
    return TitledSection(
      title: type.rolls
          ? formats.l10n.routeSpeedPerKm
          : formats.l10n.routeSplitsSwitch,
      child: SurfaceCard(
        child: Column(
          spacing: 8,
          children: [
            for (final (index, minutes) in rows.indexed)
              Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${(index + 1) * step}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        // The slowest keeps a stub to stand on.
                        widthFactor: (fastest / minutes).clamp(0.08, 1.0),
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: index == best
                                ? accent.accent
                                : scheme.onSurface.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 96,
                    child: Text(
                      text(minutes),
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: index == best ? accent.accent : null,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// What the workout climbed and descended, over the line of its altitude.
class ElevationSection extends StatelessWidget {
  const ElevationSection({super.key, required this.route});

  final WorkoutRoute route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final l10n = formats.l10n;
    final accent = PageAccent.colorsOf(context);
    Widget number(String label, int? metres, IconData icon) => Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$label ${formats.integer(metres ?? 0)} m',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
    return TitledSection(
      title: l10n.routeElevation,
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 96,
              child: CustomPaint(
                painter: _ElevationPainter(
                  route: route,
                  line: accent.accent,
                  fill: accent.accent.withValues(alpha: 0.18),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                number(
                  l10n.routeAscent,
                  route.ascent,
                  Icons.north_east_rounded,
                ),
                const SizedBox(width: 12),
                number(
                  l10n.routeDescent,
                  route.descent,
                  Icons.south_east_rounded,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ElevationPainter extends CustomPainter {
  _ElevationPainter({
    required this.route,
    required this.line,
    required this.fill,
  });

  final WorkoutRoute route;
  final Color line;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    // Each point with an altitude, by how far along the way it lies.
    final along = <double>[];
    final heights = <double>[];
    var metres = 0.0;
    for (var i = 0; i < route.points.length; i++) {
      if (i > 0) metres += metresBetween(route.points[i - 1], route.points[i]);
      final altitude = route.points[i].altitude;
      if (altitude == null) continue;
      along.add(metres);
      heights.add(altitude);
    }
    if (size.isEmpty || heights.length < 2 || metres <= 0) return;
    final low = heights.reduce(math.min);
    // A flat way stays a flat line, not a mountain of noise.
    final span = math.max(heights.reduce(math.max) - low, 20.0);
    Offset at(int i) => Offset(
      along[i] / metres * size.width,
      size.height - 2 - (heights[i] - low) / span * (size.height - 4),
    );
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < heights.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas
      ..drawPath(
        Path.from(path)
          ..lineTo(at(heights.length - 1).dx, size.height)
          ..lineTo(at(0).dx, size.height)
          ..close(),
        Paint()..color = fill,
      )
      ..drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(_ElevationPainter old) =>
      old.route != route || old.line != line || old.fill != fill;
}
