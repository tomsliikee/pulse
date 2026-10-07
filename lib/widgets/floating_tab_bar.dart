import 'dart:ui' show lerpDouble;

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../app/haptics.dart';
import '../theme/app_motion.dart';
import 'glass_bar.dart';
import 'glass_scope.dart';

/// A floating toolbar of text tabs for the bottom of a page, in the look of
/// the app's navigation bar. The selected tab is a pill that slides to the
/// next one and can be dragged along the bar to another tab.
class FloatingTabBar extends StatefulWidget {
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

  /// Draws the bar and its pill as liquid glass that bends the page
  /// scrolling under it. The pill turns into a lens while it is dragged.
  final bool glass;

  static const double height = 64;

  @override
  State<FloatingTabBar> createState() => _FloatingTabBarState();
}

class _FloatingTabBarState extends State<FloatingTabBar> {
  static const double _itemHeight = 48;
  static const double _padding = 8;

  /// Space on each side of a label; it shrinks on a narrow screen.
  static const double _maxInset = 14;
  static const double _minInset = 6;

  /// The glass lens the pill becomes while dragged is taller than the bar.
  static const double _lensHeight = 80;
  static const double _lensExtraWidth = 28;

  /// Where the finger holds the pill, in tabs; null when it rests.
  double? _dragged;

  /// The middle of each tab, measured from the left edge of the first.
  List<double> _centres = const [];

  List<String> get labels => widget.labels;
  int get selectedIndex => widget.selectedIndex;

  /// The tab under [dx], with the way to its neighbour as the fraction.
  /// Tabs are as wide as their labels, so this goes by their middles.
  double _tabAt(double dx) {
    final centres = _centres;
    if (dx <= centres.first) return 0;
    for (var i = 0; i < centres.length - 1; i++) {
      if (dx < centres[i + 1]) {
        return i + (dx - centres[i]) / (centres[i + 1] - centres[i]);
      }
    }
    return centres.length - 1;
  }

  void _dragTo(double dx) {
    if (_centres.isEmpty) return;
    final position = _tabAt(dx);
    final before = (_dragged ?? selectedIndex).round();
    if (position.round() != before) Haptics.selection();
    setState(() => _dragged = position);
  }

  void _drop() {
    final dragged = _dragged;
    if (dragged == null) return;
    setState(() => _dragged = null);
    final index = dragged.round();
    if (index != selectedIndex) widget.onSelected(index);
  }

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
        _centres = [
          for (var i = 0; i < widths.length; i++) lefts[i] + widths[i] / 2,
        ];
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: SingleMotionBuilder(
            value: _dragged == null ? 0 : 1,
            motion: AppMotion.effects,
            builder: (context, lift, _) => SingleMotionBuilder(
              value: _dragged ?? selectedIndex.toDouble(),
              motion: AppMotion.spatialFast,
              builder: (context, position, _) => _bar(
                scheme,
                labelStyle,
                widths,
                lefts,
                total,
                // The springs overshoot; the geometry must stay valid.
                position.clamp(0.0, labels.length - 1.0),
                lift,
              ),
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
    double lift,
  ) {
    final glass = widget.glass;
    final lifted = glass ? lift.clamp(0.0, 1.0) : 0.0;
    final last = labels.length - 1;
    final from = at.floor().clamp(0, last);
    final to = from == last ? from : from + 1;
    final between = at - from;
    final pillLeft = lerpDouble(lefts[from], lefts[to], between)!;
    final pillWidth = lerpDouble(widths[from], widths[to], between)!;
    // The glass pill is tinted while it rests and clear as a lens.
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
          children: [
            if (!glass)
              Positioned(
                left: pillLeft,
                width: pillWidth,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: scheme.primary,
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
                          onPill,
                          (1 - (at - i).abs()).clamp(0.0, 1.0),
                        ),
                      ),
                      onTap: () {
                        if (i == selectedIndex) return;
                        Haptics.selection();
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
          containerSize: FloatingTabBar.height,
        ),
        content: content,
      );
    }
    // The lens reaches past the bar's edge and bends the labels under it.
    final lensHeight = lerpDouble(_itemHeight, _lensHeight, lifted)!;
    final lensExtra = _lensExtraWidth * lifted;
    return GlassBar(
      height: FloatingTabBar.height,
      padding: _padding,
      pill: Rect.fromLTWH(
        _padding + pillLeft - lensExtra / 2,
        (FloatingTabBar.height - lensHeight) / 2,
        pillWidth + lensExtra,
        lensHeight,
      ),
      // On a page without colour a clear pill can hardly be seen.
      pillTint: GlassScope.pillPrimary(scheme),
      lifted: lifted,
      child: content,
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
