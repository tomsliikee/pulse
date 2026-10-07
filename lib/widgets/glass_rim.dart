import 'package:material_ui/material_ui.dart';

/// The light line along the edge of a piece of glass with corners of
/// [radius]: brightest at the top, faint at the sides, and back again at the
/// bottom. Painted by the app, because the renderer's own rim is jagged.
class GlassRim extends StatelessWidget {
  const GlassRim({super.key, required this.radius, this.strength = 1});

  final double radius;

  /// From 0, no rim, to 1.
  final double strength;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _RimPainter(radius, strength.clamp(0.0, 1.0)),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RimPainter extends CustomPainter {
  const _RimPainter(this.radius, this.strength);

  final double radius;
  final double strength;

  static const double _width = 1;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0 || size.isEmpty) return;
    final rect = (Offset.zero & size).deflate(_width / 2);
    Color white(double alpha) =>
        Colors.white.withValues(alpha: alpha * strength);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius - _width / 2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _width
        ..shader = LinearGradient(
          begin: const Alignment(-0.3, -1),
          end: const Alignment(0.3, 1),
          colors: [white(0.6), white(0.08), white(0.08), white(0.32)],
          stops: const [0, 0.4, 0.6, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RimPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.strength != strength;
}

/// The soft shadow a piece of glass with corners of [radius] throws. It is
/// painted only outside the shape: a shadow beneath it would be seen through
/// the glass and darken it.
class GlassShadow extends StatelessWidget {
  const GlassShadow({super.key, required this.radius, this.strength = 1});

  final double radius;

  /// From 0, no shadow, to 1.
  final double strength;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ShadowPainter(radius, strength.clamp(0.0, 1.0)),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ShadowPainter extends CustomPainter {
  const _ShadowPainter(this.radius, this.strength);

  final double radius;
  final double strength;

  static const double _blur = 12;
  static const Offset _offset = Offset(0, 4);

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0 || size.isEmpty) return;
    final shape = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect((Offset.zero & size).inflate(4 * _blur))
        ..addRRect(shape),
    );
    canvas.drawRRect(
      shape.shift(_offset),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.16 * strength)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _blur),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShadowPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.strength != strength;
}
