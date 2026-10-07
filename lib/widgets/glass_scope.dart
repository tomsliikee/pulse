import 'dart:math' as math;

import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:material_ui/material_ui.dart';

/// Turns the surfaces below it into glass and paints soft colour fields
/// behind them, because the pages are otherwise one flat colour and glass
/// over a flat colour cannot be seen.
///
/// The tiles are translucent with a light rim and use no backdrop filter:
/// refraction and blur per tile both made scrolling stutter on a Pixel 10
/// Pro. Only the navigation bar refracts.
class GlassScope extends StatelessWidget {
  const GlassScope({super.key, required this.child});

  final Widget child;

  /// How opaque the colour of a surface stays when it becomes glass.
  static const double tintOpacity = 0.58;

  static const LiquidGlassSettings barSettings = LiquidGlassSettings(
    thickness: 22,
    blur: 8,
    lightIntensity: 0.8,
    ambientStrength: 0.2,
    saturation: 1.4,
  );

  /// The pill of the navigation bar while it is dragged.
  static const LiquidGlassSettings lensSettings = LiquidGlassSettings(
    thickness: 26,
    blur: 0,
    chromaticAberration: 0.06,
    lightIntensity: 1,
    ambientStrength: 0.3,
    refractiveIndex: 1.5,
  );

  /// Whether the surfaces at [context] are drawn as glass.
  static bool isOn(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GlassMarker>() != null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: CustomPaint(painter: _ColourFields(scheme))),
        _GlassMarker(child: child),
      ],
    );
  }
}

class _GlassMarker extends InheritedWidget {
  const _GlassMarker({required super.child});

  @override
  bool updateShouldNotify(_GlassMarker oldWidget) => false;
}

class _ColourFields extends CustomPainter {
  const _ColourFields(this.scheme);

  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = scheme.surface);
    final radius = math.max(size.width, size.height) * 0.55;
    for (final (alignment, color) in [
      (const Alignment(-0.9, -0.8), scheme.primary),
      (const Alignment(1.0, -0.15), scheme.tertiary),
      (const Alignment(-0.7, 0.55), scheme.secondary),
      (const Alignment(0.8, 1.0), scheme.primary),
    ]) {
      final center = alignment.alongSize(size);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: 0.5), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_ColourFields oldDelegate) => oldDelegate.scheme != scheme;
}
