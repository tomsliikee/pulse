import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/mono_tokens.dart';
import '../theme/mono_type.dart';
import 'mono_motion.dart';

/// How an area of the body compares with people of the same age.
enum MonoStatus { favorable, typical, attention, none }

/// The ring of seven areas with the body age in the middle. A small dot on
/// the inner ring marks the real age.
class MonoAgeRing extends StatelessWidget {
  const MonoAgeRing({
    super.key,
    required this.statuses,
    required this.bodyAge,
    required this.realAge,
    required this.unit,
    required this.semantics,
  });

  /// Seven statuses, Heart first.
  final List<MonoStatus> statuses;
  final double? bodyAge;
  final double realAge;
  final String unit;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    return Semantics(
      label: semantics,
      image: true,
      child: ExcludeSemantics(
        child: Center(
          child: SizedBox(
            width: 276,
            height: 276,
            child: MonoDrawIn(
              builder: (context, p) => Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RingPainter(
                        statuses: statuses,
                        real: realAge,
                        tokens: t,
                        t: p,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        bodyAge == null ? '–' : '${(bodyAge! * p).round()}',
                        style: MonoType.number(t, size: 64),
                      ),
                      Text(unit, style: MonoType.unit(t)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.statuses,
    required this.real,
    required this.tokens,
    required this.t,
  });

  final List<MonoStatus> statuses;
  final double real;
  final MonoTokens tokens;
  final double t;

  Color _of(MonoStatus s) => switch (s) {
    MonoStatus.favorable => tokens.recovery,
    MonoStatus.typical => tokens.ink3,
    MonoStatus.attention => tokens.heart,
    MonoStatus.none => tokens.fill,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const stroke = 18.0;
    final outer = size.width / 2 - stroke / 2;
    final n = statuses.length;
    // The round caps reach half a stroke past each end of an arc; the arc is
    // shortened by that, so [gap] is the air seen between two segments.
    final cap = stroke / outer;
    final gap = 0.1;
    final sweep = (2 * math.pi - gap * n) / n - cap;
    for (var i = 0; i < n; i++) {
      final k = Curves.easeOutCubic.transform(monoStaggered(t, i, n));
      if (k <= 0) continue;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: outer),
        -math.pi / 2 + gap / 2 + cap / 2 + i * (sweep + cap + gap),
        sweep * k,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = _of(statuses[i]),
      );
    }
    final inner = outer - 26;
    canvas.drawCircle(
      c,
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = tokens.fill,
    );
    final fraction = ((real - 20) / 30).clamp(0.0, 1.0);
    final angle = -math.pi / 2 + 2 * math.pi * fraction;
    final dot = c + Offset(math.cos(angle), math.sin(angle)) * inner;
    final pop = ((t - 0.7) / 0.3).clamp(0.0, 1.0);
    final scale = Curves.elasticOut.transform(pop);
    canvas.drawCircle(dot, 7 * scale, Paint()..color = tokens.card);
    canvas.drawCircle(dot, 5 * scale, Paint()..color = tokens.solid);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.t != t || old.statuses != statuses || old.real != real;
}

/// The age scale from 20 to 50 with a marker for the body age and a line for
/// the real age.
class MonoAgeScale extends StatelessWidget {
  const MonoAgeScale({
    super.key,
    required this.bodyAge,
    required this.realAge,
    required this.bodyLabel,
    required this.realLabel,
  });

  final double? bodyAge;
  final double realAge;
  final String bodyLabel;
  final String realLabel;

  static const double from = 20, to = 50;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    double at(double v, double w) =>
        w * ((v - from) / (to - from)).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        return SizedBox(
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 20,
                height: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.fill,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Positioned(
                left: at(realAge, w) - 1,
                top: 14,
                width: 2,
                height: 20,
                child: ColoredBox(color: t.ink),
              ),
              if (bodyAge != null)
                Positioned(
                  left: at(bodyAge!, w) - 9,
                  top: 15,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.recovery,
                      border: Border.all(color: t.card, width: 3),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                top: 44,
                child: Text('${from.round()}', style: MonoType.label(t)),
              ),
              Positioned(
                right: 0,
                top: 44,
                child: Text('${to.round()}', style: MonoType.label(t)),
              ),
              Positioned(
                left: (at(realAge, w) - 40).clamp(0.0, w - 80),
                width: 80,
                top: 0,
                child: Text(
                  realLabel,
                  textAlign: TextAlign.center,
                  style: MonoType.label(t),
                ),
              ),
              if (bodyAge != null)
                Positioned(
                  left: (at(bodyAge!, w) - 40).clamp(0.0, w - 80),
                  width: 80,
                  top: 36,
                  child: Text(
                    bodyLabel,
                    textAlign: TextAlign.center,
                    style: MonoType.inter(13, 18, FontWeight.w600, t.recovery),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
