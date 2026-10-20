import 'package:material_ui/material_ui.dart';

/// The colours of the turtle. They are its own and do not follow the
/// theme's palette: a turtle is green whatever the wallpaper.
class MascotColors {
  const MascotColors._({
    required this.shell,
    required this.plates,
    required this.rim,
    required this.skin,
    required this.farSkin,
    required this.belly,
    required this.eye,
    required this.pupil,
    required this.cheek,
  });

  factory MascotColors.of(Brightness brightness) =>
      brightness == Brightness.light ? _light : _dark;

  static const _light = MascotColors._(
    shell: Color(0xFF3F9A4E),
    plates: Color(0xFF6CC071),
    rim: Color(0xFF2B6E37),
    skin: Color(0xFF94DB86),
    farSkin: Color(0xFF6DB865),
    belly: Color(0xFFD9F2C4),
    eye: Color(0xFFFFFFFF),
    pupil: Color(0xFF1B2230),
    cheek: Color(0x99FF8FA3),
  );

  static const _dark = MascotColors._(
    shell: Color(0xFF358A44),
    plates: Color(0xFF5BAE61),
    rim: Color(0xFF225A2D),
    skin: Color(0xFF84C978),
    farSkin: Color(0xFF5E9F57),
    belly: Color(0xFFC3DFAF),
    eye: Color(0xFFF4F4F4),
    pupil: Color(0xFF141821),
    cheek: Color(0x88F07F95),
  );

  /// The dome of the shell.
  final Color shell;

  /// The plates on the dome.
  final Color plates;

  /// The round scales along the shell's edge.
  final Color rim;

  /// Head, arms and legs on the near side.
  final Color skin;

  /// Arms and legs on the far side.
  final Color farSkin;

  /// The plate in front of the belly.
  final Color belly;
  final Color eye;
  final Color pupil;
  final Color cheek;
}
