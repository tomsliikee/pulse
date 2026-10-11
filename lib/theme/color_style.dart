import 'package:material_ui/material_ui.dart';

/// The colours the app is painted in: the wallpaper's, one of the app's own
/// or a different one on every page.
enum ColorStyle {
  /// The palette the system derived from the wallpaper (Material You).
  wallpaper,
  blue(Color(0xFF3F5BD9)),
  violet(Color(0xFF7B4BD6)),
  green(Color(0xFF2E9E4F)),
  orange(Color(0xFFF26B3A)),
  pink(Color(0xFFE0407B)),

  /// Every page in a colour of its own.
  colourful,

  /// Every element in a colour of its own, the same on every page.
  mixed;

  const ColorStyle([this.seed]);

  /// The colour the scheme is derived from; null where the style has more
  /// than one or takes them from the system.
  final Color? seed;

  /// The style used where none was chosen and the system has no palette.
  static const ColorStyle standard = blue;

  /// The seed of the Herz page in the colourful style.
  static const Color heartSeed = Color(0xFFD93A3A);

  /// The scheme of [seed]. The variant keeps the primary at the seed's hue
  /// and takes the other roles from its neighbours, so a style stays one
  /// family of colours.
  static ColorScheme schemeOf(Color seed, Brightness brightness) =>
      ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
      );
}
