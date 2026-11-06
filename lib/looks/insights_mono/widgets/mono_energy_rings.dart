import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../app/haptics.dart';
import '../theme/mono_tokens.dart';
import 'mono_motion.dart';

/// One ring of [MonoEnergyRings]: its parts in order from the top, each in
/// its colour, against [goal].
class MonoRingData {
  const MonoRingData({
    required this.parts,
    required this.colors,
    required this.goal,
    this.total,
  });

  final List<double> parts;
  final List<Color> colors;
  final double goal;

  /// The whole, where it is more than the parts tell; the rest is drawn in
  /// the last colour.
  final double? total;

  double get sum {
    final parts = this.parts.fold(0.0, (a, b) => a + b);
    return math.max(parts, total ?? 0);
  }

  bool get reached => goal > 0 && sum >= goal;
}

/// Two rings, one inside the other: burned outside, eaten inside. Each is
/// split into its parts with air between them, like the age ring. When both
/// close, a gleam runs round them once and the phone ticks — once a day in
/// a session, and not at all with reduce-motion.
class MonoEnergyRings extends StatefulWidget {
  const MonoEnergyRings({
    super.key,
    required this.outer,
    required this.inner,
    required this.day,
    required this.semantics,
    this.size = 164,
  });

  final MonoRingData outer;
  final MonoRingData inner;

  /// The day shown; the gleam is played once for each.
  final DateTime day;
  final String semantics;
  final double size;

  static final Set<String> _celebrated = {};

  @override
  State<MonoEnergyRings> createState() => _MonoEnergyRingsState();
}

class _MonoEnergyRingsState extends State<MonoEnergyRings>
    with TickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  late final AnimationController _gleam = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _started = false;

  String get _key => '${widget.day.year}-${widget.day.month}-${widget.day.day}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (monoStill(context)) {
      _draw.value = 1;
      return;
    }
    _draw.forward().whenComplete(_maybeCelebrate);
  }

  @override
  void didUpdateWidget(MonoEnergyRings old) {
    super.didUpdateWidget(old);
    if (_draw.isCompleted) _maybeCelebrate();
  }

  void _maybeCelebrate() {
    if (!mounted || monoStill(context)) return;
    if (!widget.outer.reached || !widget.inner.reached) return;
    if (!MonoEnergyRings._celebrated.add(_key)) return;
    Haptics.confirm();
    _gleam.forward(from: 0);
  }

  @override
  void dispose() {
    _draw.dispose();
    _gleam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    return Semantics(
      label: widget.semantics,
      image: true,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(
            animation: Listenable.merge([_draw, _gleam]),
            builder: (context, _) {
              final gleam = _gleam.value;
              // The rings swell a little while the gleam passes.
              final swell = math.sin(gleam * math.pi) * 0.04;
              return Transform.scale(
                scale: 1 + swell,
                child: CustomPaint(
                  painter: _RingsPainter(
                    outer: widget.outer,
                    inner: widget.inner,
                    track: t.fill,
                    gleamColor: const Color(0xFFFFFFFF),
                    draw: Curves.easeOutCubic.transform(_draw.value),
                    gleam: _gleam.isAnimating ? gleam : null,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({
    required this.outer,
    required this.inner,
    required this.track,
    required this.gleamColor,
    required this.draw,
    required this.gleam,
  });

  final MonoRingData outer;
  final MonoRingData inner;
  final Color track;
  final Color gleamColor;
  final double draw;
  final double? gleam;

  static const double stroke = 16;
  static const double gap = 0.07;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r1 = size.width / 2 - stroke / 2;
    final r2 = r1 - stroke - 6;
    _ring(canvas, c, r1, outer);
    _ring(canvas, c, r2, inner);
    final g = gleam;
    if (g != null) {
      for (final r in [r1, r2]) {
        final rect = Rect.fromCircle(center: c, radius: r);
        final head = -math.pi / 2 + 2 * math.pi * Curves.easeInOut.transform(g);
        canvas.drawArc(
          rect,
          head - 0.9,
          0.9,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke * 0.55
            ..strokeCap = StrokeCap.round
            ..shader = SweepGradient(
              endAngle: 0.9,
              colors: [
                gleamColor.withValues(alpha: 0),
                gleamColor.withValues(alpha: 0.75 * math.sin(g * math.pi)),
              ],
              transform: GradientRotation(head - 0.9),
            ).createShader(rect),
        );
      }
    }
  }

  void _ring(Canvas canvas, Offset c, double r, MonoRingData ring) {
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (ring.goal <= 0) return;
    final parts = [...ring.parts];
    final told = parts.fold(0.0, (a, b) => a + b);
    if (ring.total != null && ring.total! > told) {
      parts.add(ring.total! - told);
    }
    final sum = parts.fold(0.0, (a, b) => a + b);
    if (sum <= 0) return;
    final shown = parts.where((p) => p > 0).length;
    final cap = stroke / r;
    // Past the goal the ring is closed and its parts share the whole round.
    final whole = 2 * math.pi * math.min(1.0, sum / ring.goal);
    final closed = sum >= ring.goal;
    final air = gap * (closed ? shown : math.max(0, shown - 1));
    final room = math.max(0.0, whole - air) * draw;
    var start = -math.pi / 2 + cap / 2;
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] <= 0) continue;
      // A part too small for an arc still shows as a dot of its own.
      final share = math.max(parts[i] / sum * room, cap * draw);
      final sweep = share - cap;
      final color = ring.colors[math.min(i, ring.colors.length - 1)];
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color;
      if (sweep > 0) {
        canvas.drawArc(rect, start, sweep, false, paint);
      } else {
        // Too small for an arc: a dot.
        final a = start + share / 2 - cap / 2;
        canvas.drawCircle(
          c + Offset(math.cos(a), math.sin(a)) * r,
          stroke / 2,
          Paint()..color = color,
        );
      }
      start += share + gap * draw;
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.draw != draw ||
      old.gleam != gleam ||
      old.outer != outer ||
      old.inner != inner ||
      old.track != track;
}
