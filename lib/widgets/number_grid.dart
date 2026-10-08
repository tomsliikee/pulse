import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_shapes.dart';
import '../theme/app_theme.dart';
import '../theme/app_type.dart';
import '../theme/page_accent.dart';
import 'tile_surface.dart';

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

/// Numbers on surfaces of different shapes instead of a grid of equal
/// boxes. An odd count starts with one wide pill in the page's colour; the
/// rest stand in pairs of a circle and a wide surface that swap sides from
/// row to row, the wide one by turns a squircle and a pill. So every row is
/// full, whatever the count.
class NumberGrid extends StatelessWidget {
  const NumberGrid({super.key, required this.cells});

  final List<NumberCell> cells;

  static const double gap = 12;

  /// The diameter of a circle and with it the height of a row of two.
  static const double circle = 108;
  static const double leadHeight = 96;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = PageAccent.colorsOf(context);
    // The circles take the scheme's containers in turn; the page's own
    // comes first where no wide pill has it.
    final rounds = [
      if (cells.length.isEven) (accent.container, accent.onContainer),
      for (final tone in [Tone.tertiary, Tone.secondary, Tone.primary])
        if (scheme.tone(tone).container != accent.container)
          (scheme.tone(tone).container, scheme.tone(tone).onContainer),
    ];
    final lead = cells.length.isOdd ? cells.first : null;
    final paired = lead == null ? cells : cells.sublist(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: [
        if (lead != null)
          SizedBox(
            height: leadHeight,
            child: TileSurface(
              color: accent.container,
              radius: leadHeight / 2,
              opaque: true,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: _Lead(cell: lead, color: accent.onContainer),
            ),
          ),
        for (var row = 0; row * 2 < paired.length; row++)
          SizedBox(
            height: circle,
            child: _pair(
              context,
              paired[row * 2],
              paired[row * 2 + 1],
              row: row,
              colors: rounds[row % rounds.length],
            ),
          ),
      ],
    );
  }

  Widget _pair(
    BuildContext context,
    NumberCell first,
    NumberCell second, {
    required int row,
    required (Color, Color) colors,
  }) {
    final scheme = Theme.of(context).colorScheme;
    // The circle is small: it takes the shorter name, and never a footer.
    final secondRound = first.footer != null
        ? true
        : second.footer != null
        ? false
        : second.label.length < first.label.length;
    final round = secondRound ? second : first;
    final wide = secondRound ? first : second;
    final children = [
      SizedBox.square(
        dimension: circle,
        child: TileSurface(
          color: colors.$1,
          radius: circle / 2,
          opaque: true,
          padding: const EdgeInsets.all(14),
          child: _Round(cell: round, color: colors.$2),
        ),
      ),
      const SizedBox(width: gap),
      Expanded(
        child: TileSurface(
          color: scheme.surfaceBright,
          radius: row.isEven ? AppRadii.extraLargeIncreased : circle / 2,
          padding: EdgeInsets.symmetric(
            horizontal: row.isEven ? 20 : 28,
            vertical: 16,
          ),
          child: _Wide(cell: wide),
        ),
      ),
    ];
    return Row(children: row.isEven ? children : children.reversed.toList());
  }
}

TextStyle? _muted(BuildContext context, TextStyle? base, Color color) =>
    AppType.of(context)
        .label(base?.copyWith(color: color.withValues(alpha: 0.72)));

class _Lead extends StatelessWidget {
  const _Lead({required this.cell, required this.color});

  final NumberCell cell;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: DefaultTextStyle.merge(
                  style: AppType.of(context).hero(
                    context.emphasizedTextTheme.headlineLarge?.copyWith(
                      color: color,
                      height: 1.1,
                    ),
                  ),
                  maxLines: 1,
                  child: cell.value,
                ),
              ),
              Text(
                cell.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _muted(context, theme.textTheme.labelLarge, color),
              ),
            ],
          ),
        ),
        ?cell.trailing,
      ],
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.cell, required this.color});

  final NumberCell cell;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ?cell.trailing,
        FittedBox(
          fit: BoxFit.scaleDown,
          child: DefaultTextStyle.merge(
            style: AppType.of(context).figure(
              context.emphasizedTextTheme.titleLarge?.copyWith(color: color),
            ),
            maxLines: 1,
            child: cell.value,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            cell.label,
            maxLines: 1,
            style: _muted(context, theme.textTheme.labelMedium, color),
          ),
        ),
      ],
    );
  }
}

class _Wide extends StatelessWidget {
  const _Wide({required this.cell});

  final NumberCell cell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                cell.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _muted(context, theme.textTheme.labelLarge, color),
              ),
            ),
            ?cell.trailing,
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: DefaultTextStyle.merge(
            style: AppType.of(context).figure(
              context.emphasizedTextTheme.headlineSmall?.copyWith(color: color),
            ),
            maxLines: 1,
            child: cell.value,
          ),
        ),
        ?cell.footer,
      ],
    );
  }
}
