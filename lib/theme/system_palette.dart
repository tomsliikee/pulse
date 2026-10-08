import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// The colour schemes the operating system derived from the wallpaper
/// (Material You).
@immutable
class SystemPalette {
  const SystemPalette({required this.light, required this.dark});

  final ColorScheme light;
  final ColorScheme dark;

  // Equal by its colours, so loading the same wallpaper's palette again
  // changes nothing.
  @override
  bool operator ==(Object other) =>
      other is SystemPalette && other.light == light && other.dark == dark;

  @override
  int get hashCode => Object.hash(light, dark);
}

typedef SystemPaletteLoader = Future<SystemPalette?> Function();

/// Null on systems without dynamic colour (before Android 12, desktop).
Future<SystemPalette?> loadSystemPalette() async {
  try {
    final palette = await DynamicColorPlugin.getCorePalette();
    if (palette == null) return null;
    return SystemPalette(
      light: palette.toColorScheme(),
      dark: palette.toColorScheme(brightness: Brightness.dark),
    );
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}
