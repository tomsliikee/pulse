import 'package:material_ui/material_ui.dart';

import '../theme/app_shapes.dart';
import '../theme/page_accent.dart';
import 'entrance.dart';
import 'tile_surface.dart';

/// Rows that belong together, each a surface of its own: a hair apart, with
/// strong corners where the group ends and weak ones where two rows meet.
/// The rows come in one after the other.
class SegmentGroup extends StatelessWidget {
  const SegmentGroup({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    this.from = 0,
    this.loud,
  });

  final List<Widget> children;

  /// Around each row; zero for rows that bring their own ink and insets.
  final EdgeInsetsGeometry padding;

  /// The place of the first row among what enters with the group.
  final int from;

  /// The row painted in the page's accent, where one stands out.
  final int? loud;

  static const double gap = 3;

  /// The corners of row [index] of [count].
  static BorderRadius cornersOf(int index, int count) {
    const outer = Radius.circular(AppRadii.extraLarge);
    const inner = Radius.circular(AppRadii.small);
    return BorderRadius.vertical(
      top: index == 0 ? outer : inner,
      bottom: index == count - 1 ? outer : inner,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceBright;
    final accent = PageAccent.colorsOf(context).container;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: [
        for (final (index, child) in children.indexed)
          Entrance(
            order: from + index,
            child: TileSurface(
              color: index == loud ? accent : color,
              opaque: index == loud,
              radius: AppRadii.extraLarge,
              corners: cornersOf(index, children.length),
              padding: padding,
              child: child,
            ),
          ),
      ],
    );
  }
}

/// One row of a list that is built as it scrolls, looking like a row of a
/// [SegmentGroup]: [first] and [last] say where its group begins and ends.
class ListSegment extends StatelessWidget {
  const ListSegment({
    super.key,
    required this.first,
    required this.last,
    required this.child,
  });

  final bool first;
  final bool last;
  final Widget child;

  static const double height = 72;

  @override
  Widget build(BuildContext context) {
    const outer = Radius.circular(AppRadii.extraLarge);
    const inner = Radius.circular(AppRadii.small);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : SegmentGroup.gap),
      child: TileSurface(
        color: Theme.of(context).colorScheme.surfaceBright,
        radius: AppRadii.extraLarge,
        corners: BorderRadius.vertical(
          top: first ? outer : inner,
          bottom: last ? outer : inner,
        ),
        child: SizedBox(height: height, child: child),
      ),
    );
  }
}
