import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../theme/app_motion.dart';
import '../widgets/glass_scope.dart';
import 'haptics.dart';
import 'layout.dart';

@immutable
class GlassFabMenuItem {
  const GlassFabMenuItem({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

/// The add button as liquid glass. Its entries flow out of the button as
/// drops of the same glass and merge back into it when the menu closes.
class GlassFabMenu extends StatefulWidget {
  const GlassFabMenu({super.key, required this.items});

  final List<GlassFabMenuItem> items;

  static const double size = 64;

  @override
  State<GlassFabMenu> createState() => _GlassFabMenuState();
}

class _GlassFabMenuState extends State<GlassFabMenu> {
  static const double _itemHeight = 56;
  static const double _gap = 12;

  /// How much smaller than the button a drop is when it leaves it.
  static const double _inset = 10;

  /// How far apart drops still pull together while the menu moves.
  static const double _blend = 40;

  final OverlayPortalController _portal = OverlayPortalController();
  bool _open = false;

  /// Where the button is on screen while the menu is shown.
  Rect _anchor = Rect.zero;

  void _toggle() {
    Haptics.tap();
    if (!_open) {
      final anchor = globalRectOf(context);
      if (anchor == null) return;
      _anchor = anchor;
      _portal.show();
    }
    setState(() => _open = !_open);
  }

  void _choose(GlassFabMenuItem item) {
    Haptics.tap();
    setState(() => _open = false);
    item.onPressed();
  }

  void _settled(AnimationStatus status) {
    if (_open || status.isAnimating || !_portal.isShowing) return;
    _portal.hide();
    setState(() {});
  }

  LiquidGlassSettings _settings(ColorScheme scheme) => GlassScope.barSettings
      .copyWith(glassColor: scheme.tertiaryContainer.withValues(alpha: 0.45));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _buildMenu,
      // While the menu is shown the button is drawn there, in one layer
      // with its entries, so that they can merge.
      child: Visibility.maintain(
        visible: !_portal.isShowing,
        child: LiquidGlass.withOwnLayer(
          settings: _settings(scheme),
          shape: const LiquidOval(),
          child: _Button(turn: 0, onTap: _toggle),
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = context.emphasizedTextTheme.titleMedium?.copyWith(
      color: scheme.onTertiaryContainer,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final widths = [
      for (final item in widget.items)
        // Icon, gap and padding around the label.
        (TextPainter(
              text: TextSpan(text: item.label, style: labelStyle),
              textDirection: TextDirection.ltr,
              textScaler: scaler,
              maxLines: 1,
            )..layout()).width.ceilToDouble() +
            24 +
            12 +
            2 * 20,
    ];

    return SingleMotionBuilder(
      from: 0,
      value: _open ? 1 : 0,
      motion: AppMotion.spatial,
      onAnimationStatusChanged: _settled,
      builder: (context, t, _) {
        final shown = t.clamp(0.0, 1.0);
        return Stack(
          children: [
            if (_open)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
                ),
              ),
            Positioned.fill(
              child: LiquidGlassLayer(
                settings: _settings(scheme),
                child: LiquidGlassBlendGroup(
                  // Strongest half way. With the drops still inside the button
                  // any pull would bulge it into a box.
                  blend: _blend * math.sin(math.pi * shown),
                  child: Stack(
                    children: [
                      for (var i = 0; i < widget.items.length; i++)
                        if (_leaves(i, t) > 0)
                          _buildItem(i, widths[i], t, labelStyle, scheme),
                      Positioned.fromRect(
                        rect: _anchor,
                        child: LiquidGlass.grouped(
                          shape: const LiquidOval(),
                          child: _Button(turn: shown, onTap: _toggle),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// How far entry [index] has left the button, 0 while it is still inside.
  /// Entries further from the button leave a little later. The spring
  /// overshoots, which is what lets a drop stretch past its place.
  static double _leaves(int index, double t) {
    final own = t * (1 + 0.25 * index) - 0.25 * index;
    return own < 0 ? 0 : own;
  }

  Widget _buildItem(
    int index,
    double width,
    double t,
    TextStyle? labelStyle,
    ColorScheme scheme,
  ) {
    final item = widget.items[index];
    final moved = _leaves(index, t);
    final bottom = _anchor.top - _gap - index * (_itemHeight + _gap);
    final place = Rect.fromLTWH(
      _anchor.right - width,
      bottom - _itemHeight,
      width,
      _itemHeight,
    );
    // A drop starts inside the button, so the button keeps its outline.
    final rect = Rect.lerp(_anchor.deflate(_inset), place, moved)!;
    final radius =
        lerpDouble(GlassFabMenu.size - 2 * _inset, _itemHeight, moved)! / 2;
    final shown = moved.clamp(0.0, 1.0);
    return Positioned.fromRect(
      rect: rect,
      child: LiquidGlass.grouped(
        shape: LiquidRoundedRectangle(borderRadius: radius),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: _open ? () => _choose(item) : null,
            child: Opacity(
              opacity: shown,
              // The content keeps its size while the drop grows around it.
              child: OverflowBox(
                minWidth: width,
                maxWidth: width,
                minHeight: _itemHeight,
                maxHeight: _itemHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.icon,
                      size: 24,
                      color: scheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Text(item.label, maxLines: 1, style: labelStyle),
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

class _Button extends StatelessWidget {
  const _Button({required this.turn, required this.onTap});

  /// 0 shows a plus, 1 has turned it into a cross.
  final double turn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      button: true,
      label: turn > 0.5 ? 'Schliessen' : 'Eintrag hinzufügen',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: GlassFabMenu.size,
            child: Transform.rotate(
              angle: turn * 0.785398,
              child: Icon(
                Icons.add_rounded,
                size: 28,
                color: scheme.onTertiaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
