import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

import '../theme/mono_tokens.dart';

/// One tab of the floating bar.
class MonoTab {
  const MonoTab(this.icon, this.label);

  final Widget icon;
  final String label;
}

/// Frosted glass in the shape of a capsule: the shadow outside the clip so
/// it falls soft on every side, the blur and a thin rim inside. Every
/// floating element of the look stands on it. With the glass setting off it
/// is the same capsule, opaque and without the blur.
class MonoGlass extends StatelessWidget {
  const MonoGlass({
    super.key,
    required this.child,
    this.radius = 30,
    this.lift = 0,
    this.opacity = 1,
    this.backdrop = true,
    this.shadow = true,
  });

  final Widget child;

  /// Whether it casts a shadow. A large sheet goes without: over the page
  /// its shadow reads as a dark smear.
  final bool shadow;
  final double radius;

  /// Fades the fill, rim and shadow, for a pill that comes in: the blur
  /// behind stays, so no layer has to be made to fade it.
  final double opacity;

  /// Whether this glass blurs what is behind it itself. Glass that shares
  /// the blur of a group, or that is moving, leaves it out.
  final bool backdrop;

  /// 0 resting, 1 held up: a deeper shadow.
  final double lift;

  /// One filter for all of them: a new instance on every build would make the
  /// engine set the blur up again each frame.
  static final ImageFilter blur = ImageFilter.blur(sigmaX: 16, sigmaY: 16);

  Color _fade(Color c) =>
      opacity >= 1 ? c : c.withValues(alpha: c.a * opacity.clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final shape = BorderRadius.circular(radius);
    final face = DecoratedBox(
      decoration: BoxDecoration(
        color: _fade(t.floatFill),
        borderRadius: shape,
        border: Border.all(color: _fade(t.barRim), width: 0.8),
      ),
      child: child,
    );
    final clipped = ClipRRect(
      borderRadius: shape,
      // The filter stays in the tree when it is off: taking it out
      // would build what is inside anew, a text field with it.
      child: t.glass
          ? BackdropFilter(filter: blur, enabled: backdrop, child: face)
          : face,
    );
    if (!shadow) return RepaintBoundary(child: clipped);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _OuterShadow(
          radius: radius,
          shadows: [
            for (final s in t.barShadowLifted(lift))
              BoxShadow(
                color: _fade(s.color),
                blurRadius: s.blurRadius,
                spreadRadius: s.spreadRadius,
                offset: s.offset,
              ),
          ],
        ),
        child: clipped,
      ),
    );
  }
}

/// The shadow of a capsule, drawn only outside it. A box shadow also falls
/// under the box, and through a see-through glass that shows as a grey patch.
class _OuterShadow extends CustomPainter {
  const _OuterShadow({required this.radius, required this.shadows});

  final double radius;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect((Offset.zero & size).inflate(400))
        ..addRRect(shape),
    );
    for (final shadow in shadows) {
      canvas.drawRRect(
        shape.shift(shadow.offset).inflate(shadow.spreadRadius),
        shadow.toPaint(),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OuterShadow old) =>
      old.radius != radius || !listEquals(old.shadows, shadows);
}
