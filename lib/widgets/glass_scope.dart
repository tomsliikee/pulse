import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:material_ui/material_ui.dart';

/// Turns the surfaces below it into glass and paints soft colour fields
/// behind them, because the pages are otherwise one flat colour and glass
/// over a flat colour cannot be seen.
///
/// The tiles are translucent with a light rim and use no backdrop filter:
/// refraction and blur per tile both made scrolling stutter on a Pixel 10
/// Pro. Only the bars, their pills and the add button refract.
class GlassScope extends StatelessWidget {
  const GlassScope({super.key, required this.child});

  final Widget child;

  /// How opaque the colour of a surface stays when it becomes glass.
  static const double tintOpacity = 0.58;

  /// Clear glass that bends at its edge and is flat in the middle. Without
  /// the renderer's own light: it draws that as a jagged rim, and only while
  /// a shape rests, so it vanished when the add menu moved and came back
  /// late. [GlassRim] draws the rim instead.
  static const LiquidGlassSettings barSettings = LiquidGlassSettings(
    thickness: 20,
    blur: 0.8,
    chromaticAberration: 0,
    lightIntensity: 0,
    ambientStrength: 0,
    refractiveIndex: 1.5,
    saturation: 1.3,
  );

  /// The selected pill of a bar while it rests: a second, clearer piece of
  /// glass lying on the bar.
  static const LiquidGlassSettings pillSettings = LiquidGlassSettings(
    thickness: 8,
    blur: 0,
    chromaticAberration: 0,
    lightIntensity: 0,
    ambientStrength: 0,
    refractiveIndex: 1.5,
    saturation: 1.2,
  );

  /// The pill of the navigation bar while it is dragged.
  static const LiquidGlassSettings lensSettings = LiquidGlassSettings(
    thickness: 18,
    blur: 0,
    chromaticAberration: 0,
    lightIntensity: 1,
    ambientStrength: 0.3,
    refractiveIndex: 1.25,
  );

  /// The glass of a pill tinted with [tint] that is [lifted] from 0, resting
  /// on its bar, to 1, a lens under the finger. The lens has no tint.
  static LiquidGlassSettings pillAt(double lifted, Color tint) {
    const rest = pillSettings;
    const lens = lensSettings;
    return LiquidGlassSettings(
      glassColor: tint.withValues(alpha: tint.a * (1 - lifted)),
      thickness: lerpDouble(rest.thickness, lens.thickness, lifted)!,
      blur: 0,
      chromaticAberration: lerpDouble(
        rest.chromaticAberration,
        lens.chromaticAberration,
        lifted,
      )!,
      lightIntensity: lens.lightIntensity * lifted,
      ambientStrength: lens.ambientStrength * lifted,
      refractiveIndex: lerpDouble(
        rest.refractiveIndex,
        lens.refractiveIndex,
        lifted,
      )!,
      saturation: lerpDouble(rest.saturation, lens.saturation, lifted)!,
    );
  }

  /// The light veil over a bar, which keeps its content readable over any
  /// page.
  static Color barTint(ColorScheme scheme) => scheme.surface.withValues(
    alpha: scheme.brightness == Brightness.light ? 0.28 : 0.38,
  );

  /// The tint that makes a resting pill come out in the scheme's primary
  /// colour. The renderer doubles a dark tint before it multiplies, so the
  /// light theme hands it half the colour; a light tint is screened as it is.
  static Color pillPrimary(ColorScheme scheme) =>
      (scheme.brightness == Brightness.light
              ? Color.lerp(scheme.primary, Colors.black, 0.5)!
              : scheme.primary)
          .withValues(alpha: 0.85);

  /// The veil of a resting pill: lighter than its bar in both themes.
  static Color pillTint(ColorScheme scheme) => Colors.white.withValues(
    alpha: scheme.brightness == Brightness.light ? 0.4 : 0.14,
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
