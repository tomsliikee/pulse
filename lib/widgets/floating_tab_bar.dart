import 'dart:ui' show lerpDouble;

import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../app/haptics.dart';
import '../theme/app_motion.dart';
import 'glass_scope.dart';

/// A floating toolbar of text tabs for the bottom of a page. The selected tab
/// is a tonal pill that slides to the next one.
class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.glass = false,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Draws the bar as liquid glass that bends the page scrolling under it.
  final bool glass;

  static const double height = 64;
  static const double _itemHeight = 48;
  static const double _padding = 8;

  /// Space on each side of a label; it shrinks on a narrow screen.
  static const double _maxInset = 14;
  static const double _minInset = 6;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = context.emphasizedTextTheme.labelLarge;
    final scaler = MediaQuery.textScalerOf(context);
    final labelWidths = [
      for (final label in labels)
        (TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          maxLines: 1,
        )..layout()).width.ceilToDouble(),
    ];
    final labelsWidth = labelWidths.fold(0.0, (sum, width) => sum + width);

    return LayoutBuilder(
      builder: (context, constraints) {
        final room = constraints.maxWidth - 2 * _padding - labelsWidth;
        final inset = (room / (2 * labels.length)).clamp(_minInset, _maxInset);
        final widths = [for (final width in labelWidths) width + 2 * inset];
        final lefts = <double>[];
        var total = 0.0;
        for (final width in widths) {
          lefts.add(total);
          total += width;
        }
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: SingleMotionBuilder(
            value: selectedIndex.toDouble(),
            motion: AppMotion.spatialFast,
            builder: (context, position, _) => _bar(
              scheme,
              labelStyle,
              widths,
              lefts,
              total,
              // The spring overshoots; the geometry must stay valid.
              position.clamp(0.0, labels.length - 1.0),
            ),
          ),
        );
      },
    );
  }

  Widget _bar(
    ColorScheme scheme,
    TextStyle? labelStyle,
    List<double> widths,
    List<double> lefts,
    double total,
    double at,
  ) {
    final last = labels.length - 1;
    final from = at.floor().clamp(0, last);
    final to = from == last ? from : from + 1;
    final between = at - from;

    final content = SizedBox(
      width: total,
      height: _itemHeight,
      child: Stack(
        children: [
          Positioned(
            left: lerpDouble(lefts[from], lefts[to], between),
            width: lerpDouble(widths[from], widths[to], between),
            top: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: scheme.secondaryContainer,
                shape: const StadiumBorder(),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                SizedBox(
                  width: widths[i],
                  height: _itemHeight,
                  child: _Tab(
                    label: labels[i],
                    selected: i == selectedIndex,
                    style: labelStyle?.copyWith(
                      color: Color.lerp(
                        scheme.onSurfaceVariant,
                        scheme.onSecondaryContainer,
                        (1 - (at - i).abs()).clamp(0.0, 1.0),
                      ),
                    ),
                    onTap: () {
                      if (i == selectedIndex) return;
                      Haptics.selection();
                      onSelected(i);
                    },
                  ),
                ),
            ],
          ),
        ],
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
          containerSize: height,
        ),
        content: content,
      );
    }
    return LiquidGlass.withOwnLayer(
      settings: GlassScope.barSettings,
      shape: const LiquidRoundedRectangle(borderRadius: height / 2),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        child: Padding(padding: const EdgeInsets.all(_padding), child: content),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.style,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final TextStyle? style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(label, maxLines: 1, softWrap: false, style: style),
          ),
        ),
      ),
    );
  }
}
