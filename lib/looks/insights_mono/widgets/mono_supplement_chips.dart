import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/haptics.dart';
import '../theme/mono_tokens.dart';
import '../theme/mono_type.dart';
import 'mono_motion.dart';

/// One supplement for [MonoSupplementBoard].
class MonoSupplementEntry {
  const MonoSupplementEntry({
    required this.key,
    required this.name,
    required this.taken,
    required this.onToggle,
    this.detail,
  });

  final String key;
  final String name;

  /// The dose and the time of day, under the name.
  final String? detail;
  final bool taken;
  final VoidCallback onToggle;
}

/// The supplements of today: a ring that fills with each one taken and
/// says how many, and a chip per supplement with its name. A tap fills the
/// chip from where the finger was, draws a check, springs the ring on and
/// gives a light knock; the last one gives a stronger one and a gleam runs
/// round the ring.
class MonoSupplementBoard extends StatefulWidget {
  const MonoSupplementBoard({
    super.key,
    required this.entries,
    required this.countLabel,
  });

  final List<MonoSupplementEntry> entries;

  /// "3 of 5", for the screen reader and under the ring.
  final String countLabel;

  @override
  State<MonoSupplementBoard> createState() => _MonoSupplementBoardState();
}

class _MonoSupplementBoardState extends State<MonoSupplementBoard>
    with TickerProviderStateMixin {
  late final AnimationController _ring = AnimationController.unbounded(
    vsync: this,
    value: _share,
  );
  late final AnimationController _gleam = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  double get _share {
    final n = widget.entries.length;
    if (n == 0) return 0;
    return widget.entries.where((e) => e.taken).length / n;
  }

  @override
  void didUpdateWidget(MonoSupplementBoard old) {
    super.didUpdateWidget(old);
    final target = _share;
    if ((target - _ring.value).abs() < 0.001) return;
    final wasFull = old.entries.isNotEmpty && old.entries.every((e) => e.taken);
    final isFull =
        widget.entries.isNotEmpty && widget.entries.every((e) => e.taken);
    if (monoStill(context)) {
      _ring.value = target;
      return;
    }
    _ring.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 260, damping: 14),
        _ring.value,
        target,
        _ring.velocity,
      ),
    );
    if (isFull && !wasFull) {
      Haptics.scaled(1);
      _gleam.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ring.dispose();
    _gleam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final done = widget.entries.where((e) => e.taken).length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: widget.countLabel,
          child: ExcludeSemantics(
            child: SizedBox.square(
              dimension: 92,
              child: AnimatedBuilder(
                animation: Listenable.merge([_ring, _gleam]),
                builder: (context, _) => CustomPaint(
                  painter: _RingPainter(
                    share: _ring.value,
                    gleam: _gleam.isAnimating ? _gleam.value : null,
                    color: t.recovery,
                    track: t.fill,
                  ),
                  child: Center(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$done',
                            style: MonoType.inter(
                              26,
                              30,
                              FontWeight.w600,
                              t.ink,
                            ),
                          ),
                          TextSpan(
                            text: '/${widget.entries.length}',
                            style: MonoType.inter(
                              15,
                              30,
                              FontWeight.w500,
                              t.ink3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in widget.entries)
                _Chip(key: ValueKey(e.key), entry: e, tokens: t),
            ],
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.share,
    required this.gleam,
    required this.color,
    required this.track,
  });

  final double share;
  final double? gleam;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final rect = (Offset.zero & size).deflate(stroke / 2 + 1);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    final sweep = math.pi * 2 * share.clamp(0.0, 1.04);
    if (sweep > 0.01) {
      canvas.drawArc(rect, -math.pi / 2, sweep, false, paint..color = color);
    }
    final g = gleam;
    if (g != null) {
      // A bright spot runs once round the full ring and fades.
      final angle =
          -math.pi / 2 + math.pi * 2 * Curves.easeInOutCubic.transform(g);
      final fade = math.sin(g * math.pi);
      canvas.drawArc(
        rect,
        angle - 0.5,
        0.5,
        false,
        paint
          ..color = Colors.white.withValues(alpha: 0.7 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        rect.center,
        rect.width / 2 + stroke * (0.4 + g),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 0.35 * (1 - g)),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.share != share ||
      old.gleam != gleam ||
      old.color != color ||
      old.track != track;
}

class _Chip extends StatefulWidget {
  const _Chip({super.key, required this.entry, required this.tokens});

  final MonoSupplementEntry entry;
  final MonoTokens tokens;

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: widget.entry.taken ? 1 : 0,
  );
  Offset _from = Offset.zero;

  @override
  void didUpdateWidget(_Chip old) {
    super.didUpdateWidget(old);
    if (old.entry.taken == widget.entry.taken) return;
    if (monoStill(context)) {
      _fill.value = widget.entry.taken ? 1 : 0;
    } else if (widget.entry.taken) {
      _fill.forward();
    } else {
      _fill.reverse();
    }
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final e = widget.entry;
    return Semantics(
      button: true,
      toggled: e.taken,
      label: [e.name, ?e.detail].join(', '),
      child: ExcludeSemantics(
        child: GestureDetector(
          onTapDown: (d) => _from = d.localPosition,
          child: MonoPress(
            squash: 0.06,
            onTap: () {
              e.onToggle();
            },
            child: AnimatedBuilder(
              animation: _fill,
              builder: (context, _) {
                final p = Curves.easeOutCubic.transform(_fill.value);
                final ink = Color.lerp(t.ink, t.onSolid, p)!;
                return CustomPaint(
                  painter: _FillPainter(
                    from: _from,
                    share: p,
                    fill: t.fill,
                    solid: t.solid,
                  ),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.fromLTRB(6, 5, 14, 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox.square(
                          dimension: 30,
                          child: CustomPaint(
                            painter: _CheckPainter(
                              share: _fill.value,
                              color: t.onSolid,
                              ring: t.ink3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                e.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MonoType.inter(
                                  14,
                                  18,
                                  FontWeight.w600,
                                  ink,
                                ),
                              ),
                              if (e.detail != null)
                                Text(
                                  e.detail!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: MonoType.inter(
                                    11,
                                    14,
                                    FontWeight.w500,
                                    Color.lerp(
                                      t.ink2,
                                      t.onSolid,
                                      p,
                                    )!.withValues(alpha: 0.85),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The chip's ground: fill, with solid ink growing as a circle from where it
/// was tapped.
class _FillPainter extends CustomPainter {
  const _FillPainter({
    required this.from,
    required this.share,
    required this.fill,
    required this.solid,
  });

  final Offset from;
  final double share;
  final Color fill;
  final Color solid;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    canvas.drawRRect(shape, Paint()..color = fill);
    if (share <= 0) return;
    canvas.save();
    canvas.clipRRect(shape);
    final origin = share >= 1 || from == Offset.zero
        ? size.center(Offset.zero)
        : from;
    final reach = [
      origin.distance,
      (origin - Offset(size.width, 0)).distance,
      (origin - Offset(0, size.height)).distance,
      (origin - Offset(size.width, size.height)).distance,
    ].reduce(math.max);
    canvas.drawCircle(origin, reach * share, Paint()..color = solid);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FillPainter old) =>
      old.share != share ||
      old.from != from ||
      old.fill != fill ||
      old.solid != solid;
}

/// An empty circle that becomes a check as [share] goes to 1.
class _CheckPainter extends CustomPainter {
  const _CheckPainter({
    required this.share,
    required this.color,
    required this.ring,
  });

  final double share;
  final Color color;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    if (share < 0.5) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = ring.withValues(alpha: 1 - share * 2),
      );
    }
    final p = ((share - 0.35) / 0.65).clamp(0.0, 1.0);
    if (p <= 0) return;
    final a = c + Offset(-r * 0.5, 0);
    final b = c + Offset(-r * 0.12, r * 0.4);
    final d = c + Offset(r * 0.55, -r * 0.4);
    final first = (b - a).distance;
    final second = (d - b).distance;
    final drawn = (first + second) * p;
    final path = Path()..moveTo(a.dx, a.dy);
    if (drawn <= first) {
      final q = a + (b - a) * (drawn / first);
      path.lineTo(q.dx, q.dy);
    } else {
      path.lineTo(b.dx, b.dy);
      final q = b + (d - b) * ((drawn - first) / second);
      path.lineTo(q.dx, q.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.share != share || old.color != color || old.ring != ring;
}
