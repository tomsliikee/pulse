import 'package:material_ui/material_ui.dart';

import '../../app/haptics.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/color_style.dart';
import '../../theme/system_palette.dart';

extension ColorStyleLabel on ColorStyle {
  String label(AppLocalizations l10n) => switch (this) {
    ColorStyle.wallpaper => l10n.colorWallpaper,
    ColorStyle.blue => l10n.colorBlue,
    ColorStyle.violet => l10n.colorViolet,
    ColorStyle.green => l10n.colorGreen,
    ColorStyle.orange => l10n.colorOrange,
    ColorStyle.pink => l10n.colorPink,
    ColorStyle.colourful => l10n.colorColourful,
    ColorStyle.mixed => l10n.colorMixed,
  };
}

/// The colour styles as a row of dots to choose from, the chosen one named
/// beside the title.
class ColorStyleRow extends StatelessWidget {
  const ColorStyleRow({
    super.key,
    required this.selected,
    required this.system,
    required this.onSelected,
  });

  final ColorStyle selected;

  /// The wallpaper's palette; without one its dot is not offered.
  final SystemPalette? system;
  final ValueChanged<ColorStyle> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shown = AppTheme.shown(selected, hasSystem: system != null);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.colorsTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                shown.label(l10n),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final style in ColorStyle.values)
                if (style != ColorStyle.wallpaper || system != null)
                  _Dot(
                    style: style,
                    label: style.label(l10n),
                    colors: _colors(style, scheme.brightness),
                    selected: style == shown,
                    onTap: () {
                      Haptics.selection();
                      onSelected(style);
                    },
                  ),
            ],
          ),
        ],
      ),
    );
  }

  /// What a dot is filled with: the style's primary, or its four colours.
  List<Color> _colors(ColorStyle style, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final theme = dark
        ? AppTheme.dark(style: style)
        : AppTheme.light(style: style);
    final scheme = theme.colorScheme;
    final pages = theme.extension<PageSchemes>();
    return switch (style) {
      ColorStyle.wallpaper => [(dark ? system!.dark : system!.light).primary],
      ColorStyle.colourful => [
        for (final tone in const [
          Tone.primary,
          Tone.secondary,
          Tone.error,
          Tone.tertiary,
        ])
          pages!.of(tone).colorScheme.primary,
      ],
      ColorStyle.mixed => [
        scheme.primary,
        scheme.secondary,
        scheme.error,
        scheme.tertiary,
      ],
      _ => [scheme.primary],
    };
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.style,
    required this.label,
    required this.colors,
    required this.selected,
    required this.onTap,
  });

  final ColorStyle style;
  final String label;
  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;

  static const double _size = 40;

  /// The pages' colours lie under each other like pages; the mixed ones
  /// share the dot as quarters.
  Gradient _gradient({
    required List<Color> colors,
    required List<double> stops,
  }) => style == ColorStyle.colourful
      ? LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: stops,
        )
      : SweepGradient(colors: colors, stops: stops);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mark =
        ThemeData.estimateBrightnessForColor(colors.first) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: _size / 2 + 4,
        child: Container(
          width: _size,
          height: _size,
          // The ring of the chosen dot stands off it by a gap.
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              width: 2,
              color: selected ? scheme.onSurface : Colors.transparent,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.length == 1 ? colors.first : null,
              gradient: colors.length == 1
                  ? null
                  : _gradient(
                      colors: [
                        for (final color in colors) ...[color, color],
                      ],
                      stops: [
                        for (var i = 0; i < colors.length; i++) ...[
                          i / colors.length,
                          (i + 1) / colors.length,
                        ],
                      ],
                    ),
            ),
            child: switch (style) {
              _ when selected => Icon(
                Icons.check_rounded,
                size: 18,
                color: mark,
              ),
              ColorStyle.wallpaper => Icon(
                Icons.wallpaper_rounded,
                size: 16,
                color: mark,
              ),
              _ => null,
            },
          ),
        ),
      ),
    );
  }
}
