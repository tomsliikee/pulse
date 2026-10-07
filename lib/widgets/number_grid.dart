import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import 'stat_tile.dart';

/// One number of a [NumberGrid]: what it is, and the number itself.
class NumberCell {
  const NumberCell({
    required this.label,
    required this.value,
    this.trailing,
    this.footer,
  });

  final String label;

  /// The number, usually a text or a count; it is given the grid's type.
  final Widget value;

  /// Sits at the end of the label's row, such as a mark for a best.
  final Widget? trailing;

  /// A line under the number.
  final Widget? footer;
}

/// Numbers as cards, two to a row. With an odd count the last card takes
/// the whole row, so no card stands alone beside a gap.
class NumberGrid extends StatelessWidget {
  const NumberGrid({super.key, required this.cells, this.cellHeight = 92});

  final List<NumberCell> cells;
  final double cellHeight;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, box) => Wrap(
        spacing: _gap,
        runSpacing: _gap,
        children: [
          for (final (index, cell) in cells.indexed)
            SizedBox(
              width: cells.length.isOdd && index == cells.length - 1
                  ? box.maxWidth
                  : (box.maxWidth - _gap) / 2,
              height: cellHeight,
              child: SurfaceCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cell.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        ?cell.trailing,
                      ],
                    ),
                    const Spacer(),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: DefaultTextStyle.merge(
                        style: context.emphasizedTextTheme.titleLarge,
                        maxLines: 1,
                        child: cell.value,
                      ),
                    ),
                    ?cell.footer,
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
