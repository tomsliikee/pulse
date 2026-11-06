import 'dart:math' as math;
import 'dart:ui' show FontFeature, PathMetric;

import 'package:material_ui/material_ui.dart';

import '../../../data/models.dart';
import '../theme/mono_tokens.dart';
import 'mono_motion.dart';

/// Bars that grow in with a small stagger. The one at [highlight] is full
/// [accent]; earlier ones are ink at 55 % on the card.
class MonoBars extends StatelessWidget {
  const MonoBars({
    super.key,
    required this.values,
    required this.semantics,
    this.highlight,
    this.accent,
    this.height = 64,
    this.goal,
    this.radius = 3,
    this.max,
    this.gap = 4,
  });

  /// Null for a slot without value; it shows as a small stub of fill.
  final List<double?> values;
  final String semantics;
  final int? highlight;
  final Color? accent;
  final double height;

  /// A dashed line at this value.
  final double? goal;
  final double radius;
  final double? max;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    return Semantics(
      label: semantics,
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: MonoDrawIn(
            builder: (context, p) => CustomPaint(
              painter: _BarsPainter(
                values: values,
                highlight: highlight,
                accent: accent ?? t.ink,
                past: Color.alphaBlend(t.ink.withValues(alpha: 0.55), t.card),
                stub: t.fill,
                goalColor: t.ink3,
                goal: goal,
                radius: radius,
                max: max,
                gap: gap,
                t: p,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.values,
    required this.highlight,
    required this.accent,
    required this.past,
    required this.stub,
    required this.goalColor,
    required this.goal,
    required this.radius,
    required this.max,
    required this.gap,
    required this.t,
  });

  final List<double?> values;
  final int? highlight;
  final Color accent;
  final Color past;
  final Color stub;
  final Color goalColor;
  final double? goal;
  final double radius;
  final double? max;
  final double gap;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n == 0) return;
    var top = max ?? 0;
    if (max == null) {
      for (final v in values) {
        if (v != null && v > top) top = v;
      }
      if (goal != null && goal! > top) top = goal!;
    }
    if (top <= 0) top = 1;
    final w = (size.width - gap * (n - 1)) / n;
    for (var i = 0; i < n; i++) {
      final v = values[i];
      final k = Curves.easeOutCubic.transform(monoStaggered(t, i, n));
      final h = v == null || v <= 0
          ? 3.0
          : math.max(4.0, size.height * (v / top).clamp(0.0, 1.0)) * k;
      final x = i * (w + gap);
      final color = v == null || v <= 0
          ? stub
          : (i == (highlight ?? n - 1) ? accent : past);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - math.max(h, 3), w, math.max(h, 3)),
          Radius.circular(radius),
        ),
        Paint()..color = color,
      );
    }
    if (goal != null) {
      final y = size.height * (1 - (goal! / top).clamp(0.0, 1.0));
      _dashed(canvas, Offset(0, y), Offset(size.width, y), goalColor);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.t != t || old.values != values || old.accent != accent;
}

void _dashed(Canvas canvas, Offset a, Offset b, Color color) {
  final paint = Paint()
    ..color = color
    ..strokeWidth = 1.4
    ..strokeCap = StrokeCap.round;
  const dash = 5.0, space = 4.0;
  final length = (b - a).distance;
  final dir = (b - a) / length;
  for (var d = 0.0; d < length; d += dash + space) {
    canvas.drawLine(a + dir * d, a + dir * math.min(d + dash, length), paint);
  }
}

/// A smooth line that draws itself and ends in a round dot.
class MonoLine extends StatelessWidget {
  const MonoLine({
    super.key,
    required this.values,
    required this.semantics,
    this.color,
    this.height = 64,
    this.goal,
    this.min,
    this.max,
  });

  /// Null where nothing was measured; the line stops there.
  final List<double?> values;
  final String semantics;
  final Color? color;
  final double height;
  final double? goal;
  final double? min;
  final double? max;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    return Semantics(
      label: semantics,
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: MonoDrawIn(
            builder: (context, p) => CustomPaint(
              painter: _LinePainter(
                values: values,
                color: color ?? t.ink,
                goalColor: t.ink3,
                card: t.card,
                goal: goal,
                lo: min,
                hi: max,
                t: p,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.color,
    required this.goalColor,
    required this.card,
    required this.goal,
    required this.lo,
    required this.hi,
    required this.t,
  });

  final List<double?> values;
  final Color color;
  final Color goalColor;
  final Color card;
  final double? goal;
  final double? lo;
  final double? hi;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final known = [
      for (var i = 0; i < values.length; i++)
        if (values[i] != null) (i, values[i]!),
    ];
    if (known.isEmpty) return;
    var low = lo ?? known.map((e) => e.$2).reduce(math.min);
    var high = hi ?? known.map((e) => e.$2).reduce(math.max);
    if (goal != null) {
      low = math.min(low, goal!);
      high = math.max(high, goal!);
    }
    if (high - low < 1e-6) {
      high += 1;
      low -= 1;
    }
    const pad = 6.0;
    double y(double v) =>
        pad + (size.height - 2 * pad) * (1 - (v - low) / (high - low));
    final steps = math.max(values.length - 1, 1);
    Offset p((int, double) e) => Offset(size.width * e.$1 / steps, y(e.$2));
    if (goal != null) {
      _dashed(
        canvas,
        Offset(0, y(goal!)),
        Offset(size.width, y(goal!)),
        goalColor,
      );
    }
    final points = [for (final e in known) p(e)];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      final mx = (a.dx + b.dx) / 2;
      path.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    var end = points.last;
    if (t < 1) {
      final metrics = path.computeMetrics().toList();
      final total = metrics.fold<double>(0, (s, m) => s + m.length);
      var left = total * t;
      final drawn = Path();
      for (final PathMetric m in metrics) {
        if (left <= 0) break;
        drawn.addPath(m.extractPath(0, math.min(left, m.length)), Offset.zero);
        final tangent = m.getTangentForOffset(math.min(left, m.length));
        if (tangent != null) end = tangent.position;
        left -= m.length;
      }
      canvas.drawPath(drawn, paint);
    } else {
      canvas.drawPath(path, paint);
    }
    canvas.drawCircle(end, 5.5, Paint()..color = card);
    canvas.drawCircle(end, 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.t != t || old.values != values || old.color != color;
}

/// A night in four lanes: awake, REM, light and deep.
class MonoHypnogram extends StatelessWidget {
  const MonoHypnogram({
    super.key,
    required this.segments,
    required this.totalMinutes,
    required this.semantics,
    this.height = 64,
  });

  final List<SleepSegment> segments;
  final int totalMinutes;
  final String semantics;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    return Semantics(
      label: semantics,
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: MonoDrawIn(
            builder: (context, p) => CustomPaint(
              painter: _HypnoPainter(
                segments: segments,
                total: math.max(totalMinutes, 1),
                colors: {
                  SleepStage.awake: t.ink2,
                  SleepStage.rem: t.heart,
                  SleepStage.light: t.ink3,
                  SleepStage.deep: t.ink,
                },
                t: p,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HypnoPainter extends CustomPainter {
  _HypnoPainter({
    required this.segments,
    required this.total,
    required this.colors,
    required this.t,
  });

  final List<SleepSegment> segments;
  final int total;
  final Map<SleepStage, Color> colors;
  final double t;

  static const _lanes = {
    SleepStage.awake: 0,
    SleepStage.rem: 1,
    SleepStage.light: 2,
    SleepStage.deep: 3,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final laneH = size.height / 4;
    final barH = math.max(laneH - 3, 3.0);
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      final k = Curves.easeOutCubic.transform(
        monoStaggered(t, i, segments.length, stagger: 0.5),
      );
      final x = size.width * s.startMinute / total;
      final w = math.max(size.width * s.minutes / total - 1, 1.5) * k;
      final y = _lanes[s.stage]! * laneH;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, barH),
          const Radius.circular(3),
        ),
        Paint()..color = colors[s.stage]!,
      );
    }
  }

  @override
  bool shouldRepaint(_HypnoPainter old) =>
      old.t != t || old.segments != segments;
}

/// One bar split into parts, such as the macros of a day.
class MonoStackBar extends StatelessWidget {
  const MonoStackBar({
    super.key,
    required this.parts,
    required this.colors,
    required this.semantics,
    this.height = 12,
  });

  final List<double> parts;
  final List<Color> colors;
  final String semantics;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final total = parts.fold<double>(0, (s, v) => s + v);
    return Semantics(
      label: semantics,
      image: true,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: SizedBox(
            height: height,
            child: MonoDrawIn(
              builder: (context, p) => total <= 0
                  ? ColoredBox(color: t.fill)
                  : FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: p,
                      // Stretched: a coloured box alone takes no height.
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < parts.length; i++)
                            if (parts[i] > 0)
                              Expanded(
                                flex: (parts[i] / total * 1000).round().clamp(
                                  1,
                                  1000,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: i < parts.length - 1 ? 2 : 0,
                                  ),
                                  child: ColoredBox(color: colors[i]),
                                ),
                              ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A thin progress bar on a fill track.
class MonoTrack extends StatelessWidget {
  const MonoTrack({
    super.key,
    required this.value,
    this.color,
    this.height = 8,
    this.semantics,
  });

  final double value;
  final Color? color;
  final double height;
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    return Semantics(
      label: semantics,
      excludeSemantics: semantics != null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: SizedBox(
          height: height,
          child: MonoDrawIn(
            builder: (context, p) => Stack(
              children: [
                ColoredBox(color: t.fill, child: const SizedBox.expand()),
                FractionallySizedBox(
                  widthFactor: (value * p).clamp(0.0, 1.0),
                  child: ColoredBox(
                    color: color ?? t.ink,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bars that go left of a centre line for years gained and right for years
/// lost, with the value above.
class MonoFactorBars extends StatelessWidget {
  const MonoFactorBars({super.key, required this.rows, this.maxYears = 3});

  /// (label, value text, years); negative years are gained.
  final List<(String, String, double?)> rows;
  final double maxYears;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 18),
          _FactorRow(
            label: rows[i].$1,
            value: rows[i].$2,
            years: rows[i].$3,
            maxYears: maxYears,
            tokens: t,
          ),
        ],
      ],
    );
  }
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({
    required this.label,
    required this.value,
    required this.years,
    required this.maxYears,
    required this.tokens,
  });

  final String label;
  final String value;
  final double? years;
  final double maxYears;
  final MonoTokens tokens;

  @override
  Widget build(BuildContext context) {
    final y = years;
    final gained = y != null && y < 0;
    return Semantics(
      container: true,
      label: '$label, $value',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: tokens.ink2,
              ),
            ),
            const SizedBox(height: 3),
            Align(
              alignment: gained
                  ? Alignment.centerLeft
                  : (y == null ? Alignment.center : Alignment.centerRight),
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 10,
              child: MonoDrawIn(
                builder: (context, p) => CustomPaint(
                  size: const Size.fromHeight(10),
                  painter: _FactorPainter(
                    share: y == null ? 0 : (y.abs() / maxYears).clamp(0.0, 1.0),
                    gained: gained,
                    color: gained ? tokens.up : tokens.down,
                    track: tokens.fill,
                    centre: tokens.ink3,
                    t: p,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactorPainter extends CustomPainter {
  _FactorPainter({
    required this.share,
    required this.gained,
    required this.color,
    required this.track,
    required this.centre,
    required this.t,
  });

  final double share;
  final bool gained;
  final Color color;
  final Color track;
  final Color centre;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.width / 2;
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, r),
      Paint()..color = track,
    );
    final w = (mid - 2) * share * t;
    if (w > 0) {
      final rect = gained
          ? Rect.fromLTWH(mid - w, 0, w, size.height)
          : Rect.fromLTWH(mid, 0, w, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, r),
        Paint()..color = color,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(mid - 1, -2, 2, size.height + 4),
      Paint()..color = centre,
    );
  }

  @override
  bool shouldRepaint(_FactorPainter old) =>
      old.t != t || old.share != share || old.color != color;
}

/// Twelve small markers, one per week, coloured by how the week was.
class MonoWeekMarkers extends StatelessWidget {
  const MonoWeekMarkers({super.key, required this.states, this.semantics});

  /// −1 favourable, 0 typical, 1 needs attention, null no data.
  final List<int?> states;
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    Color of(int? s) => switch (s) {
      null => t.fill,
      < 0 => t.recovery,
      0 => t.ink3,
      _ => t.heart,
    };
    return Semantics(
      label: semantics,
      image: true,
      excludeSemantics: semantics != null,
      child: Row(
        children: [
          for (var i = 0; i < states.length; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            Expanded(
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: of(states[i]),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
