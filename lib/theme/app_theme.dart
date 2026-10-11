import '../data/recovery.dart';

import 'package:material_ui/material_ui.dart';

import 'color_style.dart';

/// The only place colours are defined. Everything else reads the scheme.
abstract final class AppTheme {
  static const String fontFamily = 'Google Sans Flex';

  /// The light rim of a surface drawn as glass.
  static const Color glassRim = Color(0x66FFFFFF);

  /// [system] is the palette the operating system derived from the
  /// wallpaper; it is used by [ColorStyle.wallpaper], which falls back to
  /// the standard style without it.
  static ThemeData light({
    ColorStyle style = ColorStyle.standard,
    ColorScheme? system,
  }) => _themed(style, Brightness.light, system);

  static ThemeData dark({
    ColorStyle style = ColorStyle.standard,
    ColorScheme? system,
  }) => _themed(style, Brightness.dark, system);

  /// The style that is shown for [style]: the standard one where the
  /// wallpaper's colours are asked for and the system has none.
  static ColorStyle shown(ColorStyle style, {required bool hasSystem}) =>
      style == ColorStyle.wallpaper && !hasSystem ? ColorStyle.standard : style;

  // Built once per look, so asking again gives the same theme and nothing
  // animates from a theme to its equal.
  static final Map<(ColorStyle, Brightness, ColorScheme?), ThemeData> _themes =
      {};

  static ThemeData _themed(
    ColorStyle style,
    Brightness brightness,
    ColorScheme? system,
  ) {
    final shownStyle = shown(style, hasSystem: system != null);
    final palette = shownStyle == ColorStyle.wallpaper ? system : null;
    return _themes.putIfAbsent((shownStyle, brightness, palette), () {
      if (palette != null) return _build(palette);
      if (shownStyle == ColorStyle.colourful) {
        return PageSchemes._of(brightness).of(Tone.primary);
      }
      if (shownStyle == ColorStyle.mixed) return _build(_mixed(brightness));
      return _build(ColorStyle.schemeOf(shownStyle.seed!, brightness));
    });
  }

  /// The seeds of the four colours the pages and their elements are told
  /// apart by, each with the tone it is painted in.
  static final List<(Tone, Color)> _seeds = [
    (Tone.primary, ColorStyle.blue.seed!),
    (Tone.secondary, ColorStyle.green.seed!),
    (Tone.tertiary, ColorStyle.violet.seed!),
    (Tone.error, ColorStyle.heartSeed),
  ];

  /// One scheme whose roles are four colours instead of one family: the
  /// ground and the primary are the blue's, the other roles the primaries
  /// of the green, the violet and the red.
  static ColorScheme _mixed(Brightness brightness) {
    ColorScheme of(Tone tone) => ColorStyle.schemeOf(
      _seeds.firstWhere((entry) => entry.$1 == tone).$2,
      brightness,
    );
    final second = of(Tone.secondary);
    final third = of(Tone.tertiary);
    final heart = of(Tone.error);
    return of(Tone.primary).copyWith(
      secondary: second.primary,
      onSecondary: second.onPrimary,
      secondaryContainer: second.primaryContainer,
      onSecondaryContainer: second.onPrimaryContainer,
      secondaryFixed: second.primaryFixed,
      secondaryFixedDim: second.primaryFixedDim,
      onSecondaryFixed: second.onPrimaryFixed,
      onSecondaryFixedVariant: second.onPrimaryFixedVariant,
      tertiary: third.primary,
      onTertiary: third.onPrimary,
      tertiaryContainer: third.primaryContainer,
      onTertiaryContainer: third.onPrimaryContainer,
      tertiaryFixed: third.primaryFixed,
      tertiaryFixedDim: third.primaryFixedDim,
      onTertiaryFixed: third.onPrimaryFixed,
      onTertiaryFixedVariant: third.onPrimaryFixedVariant,
      error: heart.primary,
      onError: heart.onPrimary,
      errorContainer: heart.primaryContainer,
      onErrorContainer: heart.onPrimaryContainer,
    );
  }

  static ThemeData _build(ColorScheme scheme, {PageSchemes? pages}) {
    final base = ThemeData(
      colorScheme: scheme,
      fontFamily: fontFamily,
      useMaterial3: true,
      extensions: [?pages],
    );
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surfaceContainer,
      splashFactory: InkSparkle.splashFactory,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: const StadiumBorder(),
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
    );
  }
}

/// The themes of the colourful style, one per page. A theme carries them
/// only in that style; a page finds its own by the tone it is painted in.
class PageSchemes extends ThemeExtension<PageSchemes> {
  PageSchemes._of(Brightness brightness) {
    for (final (tone, seed) in AppTheme._seeds) {
      _themes[tone] = AppTheme._build(
        ColorStyle.schemeOf(seed, brightness),
        pages: this,
      );
    }
  }

  final Map<Tone, ThemeData> _themes = {};

  /// The theme of the page painted in [tone]; the day's for a tone that
  /// belongs to no page.
  ThemeData of(Tone tone) => _themes[tone] ?? _themes[Tone.primary]!;

  @override
  PageSchemes copyWith() => this;

  @override
  PageSchemes lerp(PageSchemes? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

/// The colour role a tile or chart is painted in.
enum Tone { primary, secondary, tertiary, error, neutral }

/// Resolved colours of a [Tone]: a container, the content on it, the
/// saturated accent used for the data mark itself and what is written on it.
typedef ToneColors = ({
  Color container,
  Color onContainer,
  Color accent,
  Color onAccent,
});

/// The fill of a recovery's shape and what is written on it: green, yellow
/// or red by its zone, and plain where there is no recovery. The three are
/// fixed colours, because they mean the same on every wallpaper.
({Color fill, Color onFill}) recoveryColors(
  ColorScheme scheme,
  RecoveryZone? zone,
) {
  final dark = scheme.brightness == Brightness.dark;
  return switch (zone) {
    RecoveryZone.green => (
      fill: dark ? const Color(0xFF7BD88F) : const Color(0xFF2E7D32),
      onFill: dark ? const Color(0xFF00390F) : const Color(0xFFFFFFFF),
    ),
    RecoveryZone.yellow => (
      fill: dark ? const Color(0xFFF5CC4A) : const Color(0xFFF2B600),
      onFill: const Color(0xFF3A2C00),
    ),
    RecoveryZone.red => (fill: scheme.error, onFill: scheme.onError),
    null => (
      fill: scheme.surfaceContainerHighest,
      onFill: scheme.onSurfaceVariant,
    ),
  };
}

extension ToneScheme on ColorScheme {
  ToneColors tone(Tone tone) => switch (tone) {
    Tone.primary => (
      container: primaryContainer,
      onContainer: onPrimaryContainer,
      accent: primary,
      onAccent: onPrimary,
    ),
    Tone.secondary => (
      container: secondaryContainer,
      onContainer: onSecondaryContainer,
      accent: secondary,
      onAccent: onSecondary,
    ),
    Tone.tertiary => (
      container: tertiaryContainer,
      onContainer: onTertiaryContainer,
      accent: tertiary,
      onAccent: onTertiary,
    ),
    Tone.error => (
      container: errorContainer,
      onContainer: onErrorContainer,
      accent: error,
      onAccent: onError,
    ),
    Tone.neutral => (
      container: surfaceBright,
      onContainer: onSurface,
      accent: primary,
      onAccent: onPrimary,
    ),
  };
}
