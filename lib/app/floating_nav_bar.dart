import 'dart:ui' show lerpDouble;

import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../theme/app_motion.dart';
import '../widgets/glass_scope.dart';
import 'haptics.dart';

@immutable
class NavDestination {
  const NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// The app's navigation: an expressive floating toolbar whose selected
/// destination is a labelled pill. The pill can be dragged along the bar to
/// another destination.
class FloatingNavBar extends StatefulWidget {
  const FloatingNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.showLabel = true,
    this.glass = false,
  });

  final List<NavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Narrow screens keep the selected pill icon-only.
  final bool showLabel;

  /// Draws the bar as liquid glass that bends the page scrolling under it.
  /// The pill turns into a glass lens while it is dragged.
  final bool glass;

  @override
  State<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<FloatingNavBar> {
  static const double _height = 64;
  static const double _itemHeight = 48;

  /// Width of a destination that shows only its icon.
  static const double _collapsedWidth = 52;
  static const double _labelGap = 8;

  static const double _padding = 8;

  /// The glass lens the pill becomes while dragged is taller than the bar.
  static const double _lensHeight = 80;
  static const double _lensExtraWidth = 28;

  /// Where the finger holds the pill, in destinations; null when it rests.
  double? _dragged;
  double _contentWidth = 0;

  int get _last => widget.destinations.length - 1;

  void _dragTo(double dx) {
    if (_contentWidth <= 0) return;
    final count = widget.destinations.length;
    final position = (dx / _contentWidth * count - 0.5).clamp(0.0, _last * 1.0);
    final before = (_dragged ?? widget.selectedIndex).round();
    if (position.round() != before) Haptics.selection();
    setState(() => _dragged = position);
  }

  void _drop() {
    final dragged = _dragged;
    if (dragged == null) return;
    setState(() => _dragged = null);
    final index = dragged.round();
    if (index != widget.selectedIndex) widget.onSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = context.emphasizedTextTheme.labelLarge;
    final scaler = MediaQuery.textScalerOf(context);
    final labelWidths = [
      for (final destination in widget.destinations)
        if (widget.showLabel)
          (TextPainter(
            text: TextSpan(text: destination.label, style: labelStyle),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
            maxLines: 1,
          )..layout()).width.ceilToDouble()
        else
          0.0,
    ];

    return SingleMotionBuilder(
      value: _dragged == null ? 0 : 1,
      motion: AppMotion.effects,
      builder: (context, lift, _) => SingleMotionBuilder(
        value: _dragged ?? widget.selectedIndex.toDouble(),
        motion: AppMotion.spatialFast,
        builder: (context, position, _) =>
            _buildBar(scheme, labelStyle, labelWidths, position, lift),
      ),
    );
  }

  Widget _buildBar(
    ColorScheme scheme,
    TextStyle? labelStyle,
    List<double> labelWidths,
    double position,
    double lift,
  ) {
    final glass = widget.glass;
    // The springs overshoot; geometry and colour factors must stay valid.
    final at = position.clamp(0.0, _last * 1.0);
    final lifted = glass ? lift.clamp(0.0, 1.0) : 0.0;

    // How much of the pill each destination holds, from 0 to 1.
    final shares = [
      for (var i = 0; i < widget.destinations.length; i++)
        (1 - (at - i).abs()).clamp(0.0, 1.0),
    ];
    final widths = [
      for (var i = 0; i < shares.length; i++)
        _collapsedWidth +
            shares[i] *
                (_labelGap +
                    (widget.showLabel ? _labelGap + labelWidths[i] : 0)),
    ];
    final lefts = <double>[];
    var total = 0.0;
    for (final width in widths) {
      lefts.add(total);
      total += width;
    }
    _contentWidth = total;

    final from = at.floor().clamp(0, _last);
    final to = from == _last ? from : from + 1;
    final between = at - from;
    final pillLeft = lerpDouble(lefts[from], lefts[to], between)!;
    final pillWidth = lerpDouble(widths[from], widths[to], between)!;
    // Under the lens the content is seen through glass, not on the pill.
    final onPill = Color.lerp(scheme.onPrimary, scheme.primary, lifted)!;

    final content = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (details) => _dragTo(details.localPosition.dx),
      onHorizontalDragUpdate: (details) => _dragTo(details.localPosition.dx),
      onHorizontalDragEnd: (_) => _drop(),
      onHorizontalDragCancel: _drop,
      child: SizedBox(
        width: total,
        height: _itemHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: pillLeft,
              width: pillWidth,
              top: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: scheme.primary.withValues(alpha: 1 - lifted),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < widget.destinations.length; i++)
                  SizedBox(
                    width: widths[i],
                    child: _NavItem(
                      destination: widget.destinations[i],
                      share: shares[i],
                      selected: i == widget.selectedIndex,
                      showLabel: widget.showLabel,
                      color: Color.lerp(
                        scheme.onSurfaceVariant,
                        onPill,
                        shares[i],
                      )!,
                      labelStyle: labelStyle,
                      onTap: () {
                        if (i != widget.selectedIndex) Haptics.selection();
                        widget.onSelected(i);
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    if (!glass) {
      return M3EHorizontalFloatingToolbar(
        expanded: true,
        decoration: M3EFloatingToolbarDecoration(
          colors: M3EFloatingToolbarColors(
            toolbarContainerColor: scheme.surfaceContainerHighest,
            toolbarContentColor: scheme.onSurfaceVariant,
            fabContainerColor: scheme.primaryContainer,
            fabContentColor: scheme.onPrimaryContainer,
          ),
          contentPadding: const EdgeInsets.all(_padding),
          expandedShadowElevation: 3,
          containerSize: _height,
        ),
        content: content,
      );
    }

    // Pills are rounded rectangles: a superellipse with a radius of half
    // its height is a squircle, not a pill.
    // The lens is a sibling of the bar and not inside it: it has to reach
    // past the bar's edge, and it bends the icons painted before it.
    final lensHeight = lerpDouble(_itemHeight, _lensHeight, lifted)!;
    final lensExtra = _lensExtraWidth * lifted;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        LiquidGlass.withOwnLayer(
          settings: GlassScope.barSettings,
          shape: const LiquidRoundedRectangle(borderRadius: _height / 2),
          child: Material(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(_padding),
              child: content,
            ),
          ),
        ),
        if (lifted > 0.01)
          Positioned(
            left: _padding + pillLeft - lensExtra / 2,
            width: pillWidth + lensExtra,
            top: (_height - lensHeight) / 2,
            height: lensHeight,
            child: IgnorePointer(
              child: LiquidGlass.withOwnLayer(
                settings: GlassScope.lensSettings.copyWith(visibility: lifted),
                shape: LiquidRoundedRectangle(borderRadius: lensHeight / 2),
                child: const SizedBox.expand(),
              ),
            ),
          ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.share,
    required this.selected,
    required this.showLabel,
    required this.color,
    required this.labelStyle,
    required this.onTap,
  });

  final NavDestination destination;

  /// How much of the pill is on this destination, from 0 to 1.
  final double share;
  final bool selected;
  final bool showLabel;
  final Color color;
  final TextStyle? labelStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: destination.label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                share > 0.5 ? destination.selectedIcon : destination.icon,
                size: 24,
                color: color,
              ),
              if (showLabel)
                ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: share,
                    child: Opacity(
                      opacity: share,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          destination.label,
                          maxLines: 1,
                          softWrap: false,
                          style: labelStyle?.copyWith(color: color),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
