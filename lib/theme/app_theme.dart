import 'package:material_ui/material_ui.dart';

/// The only place colours are defined. Everything else reads the scheme.
abstract final class AppTheme {
  static const Color _seed = Color(0xFF0F8F6F);
  static const String fontFamily = 'Google Sans Flex';

  /// The light rim of a surface drawn as glass.
  static const Color glassRim = Color(0x66FFFFFF);

  /// [system] is the palette the operating system derived from the
  /// wallpaper. Without it the app's own seed colour is used.
  static ThemeData light({ColorScheme? system}) =>
      _build(system ?? _seeded(Brightness.light));

  static ThemeData dark({ColorScheme? system}) =>
      _build(system ?? _seeded(Brightness.dark));

  static ColorScheme _seeded(Brightness brightness) => ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.expressive,
  );

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(
      colorScheme: scheme,
      fontFamily: fontFamily,
      useMaterial3: true,
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
