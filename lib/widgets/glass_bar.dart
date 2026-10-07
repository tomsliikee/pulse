import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:material_ui/material_ui.dart';

import 'glass_rim.dart';
import 'glass_scope.dart';

/// A floating bar of liquid glass that bends the page scrolling under it.
/// Its selected pill is a second piece of glass lying on the bar; the
/// [child] is painted over both and stays sharp.
class GlassBar extends StatelessWidget {
  const GlassBar({
    super.key,
    required this.height,
    required this.padding,
    required this.pill,
    this.pillTint,
    this.lifted = 0,
    required this.child,
  });

  final double height;

  /// Space between the edge of the bar and the [child].
  final double padding;

  /// Where the pill is, measured from the bar's top left corner. It may
  /// reach past the bar.
  final Rect pill;

  /// The colour of the resting pill's glass; a light veil when null.
  final Color? pillTint;

  /// From 0, the pill rests, to 1, it is a lens under the finger. A lifted
  /// pill is painted over the [child], which is then seen through it.
  final double lifted;

  final Widget child;

  // The pill changes sides of the content when it is lifted. Without keys
  // both would be built anew, and the drag that lifts the pill would end.
  static const Key _pillKey = ValueKey('pill');
  static const Key _contentKey = ValueKey('content');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lifted = this.lifted.clamp(0.0, 1.0);
    final radius = height / 2;
    final pillRadius = pill.height / 2;

    // Pills are rounded rectangles: a superellipse with a radius of half
    // its height is a squircle, not a pill.
    final glassPill = Positioned.fromRect(
      key: _pillKey,
      rect: pill,
      child: IgnorePointer(
        child: LiquidGlass.withOwnLayer(
          settings: GlassScope.pillAt(
            lifted,
            pillTint ?? GlassScope.pillTint(scheme),
          ),
          shape: LiquidRoundedRectangle(borderRadius: pillRadius),
          child: GlassRim(radius: pillRadius),
        ),
      ),
    );
    final above = lifted > 0.01;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: GlassShadow(radius: radius)),
        Positioned.fill(
          child: LiquidGlass.withOwnLayer(
            settings: GlassScope.barSettings.copyWith(
              glassColor: GlassScope.barTint(scheme),
            ),
            shape: LiquidRoundedRectangle(borderRadius: radius),
            // A touch between the entries must not reach the page.
            child: AbsorbPointer(child: GlassRim(radius: radius)),
          ),
        ),
        if (!above) glassPill,
        Material(
          key: _contentKey,
          type: MaterialType.transparency,
          child: Padding(padding: EdgeInsets.all(padding), child: child),
        ),
        if (above) glassPill,
      ],
    );
  }
}
