import 'package:material_color_utilities/material_color_utilities.dart'
    show Blend, Hct;
import 'package:material_ui/material_ui.dart';

import '../../../theme/app_theme.dart';

/// The type a look of the family is set in: Insights Mono with Geist Serif
/// and Inter, Insights Flex with Google Sans Flex throughout.
enum MonoFace { mono, flex }

/// The colours of the Insights looks: black, white and grey, with a
/// recovery colour taken from the seed and a red for the heart. Tinted, the
/// greys lean faintly toward the seed.
@immutable
class MonoTokens extends ThemeExtension<MonoTokens> {
  const MonoTokens({
    required this.bg,
    required this.card,
    required this.fill,
    required this.line,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.solid,
    required this.onSolid,
    required this.bar,
    required this.barRim,
    required this.recovery,
    required this.recoveryBg,
    required this.heart,
    required this.heartBg,
    required this.up,
    required this.down,
    required this.dark,
    this.face = MonoFace.mono,
  });

  /// The tokens for [brightness], with the recovery colour in the hue of
  /// [seed] and the heart red pulled toward it. With [tint] the grounds
  /// carry a little of the seed.
  factory MonoTokens.from(
    Brightness brightness,
    Color seed, {
    bool tint = false,
    MonoFace face = MonoFace.mono,
  }) {
    final dark = brightness == Brightness.dark;
    final hue = Hct.fromInt(seed.toARGB32()).hue;
    Color tone(double chroma, double light, double darkTone) =>
        Color(Hct.from(hue, chroma, dark ? darkTone : light).toInt());
    final red = Blend.harmonize(0xFFFF2D55, seed.toARGB32());
    final redHct = Hct.fromInt(red);
    Color redTone(double light, double darkTone) => Color(
      Hct.from(redHct.hue, dark ? 56 : 62, dark ? darkTone : light).toInt(),
    );
    Color ground(Color plain, double chroma, double light, double darkTone) =>
        tint ? tone(chroma, light, darkTone) : plain;
    final bg = ground(
      dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      4,
      98.5,
      3,
    );
    return MonoTokens(
      bg: bg,
      card: ground(
        dark ? const Color(0xFF161618) : const Color(0xFFF4F4F6),
        7,
        95.5,
        10,
      ),
      fill: ground(
        dark ? const Color(0xFF26262A) : const Color(0xFFE6E6EA),
        9,
        90.5,
        17,
      ),
      line: ground(
        dark ? const Color(0xFF2C2C30) : const Color(0xFFE0E0E4),
        8,
        88,
        19,
      ),
      ink: dark ? const Color(0xFFF5F5F7) : const Color(0xFF0C0C0E),
      ink2: dark ? const Color(0xFFA1A1A6) : const Color(0xFF5E5E64),
      ink3: dark ? const Color(0xFF636366) : const Color(0xFFA3A3A8),
      solid: dark ? const Color(0xFFF5F5F7) : const Color(0xFF0C0C0E),
      onSolid: dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      // Thin enough that the blur behind is seen.
      bar: tint
          ? tone(6, 99, 14).withValues(alpha: dark ? 0.68 : 0.72)
          : dark
          ? const Color(0xAD1C1C1E)
          : const Color(0xB8FFFFFF),
      barRim: dark ? const Color(0x1FFFFFFF) : const Color(0x14000000),
      recovery: tone(48, 42, 80),
      recoveryBg: tone(26, 94, 24),
      heart: redTone(46, 76),
      heartBg: redTone(94, 24),
      up: dark ? const Color(0xFF7FD99A) : const Color(0xFF1F7A3D),
      down: dark ? const Color(0xFFFF8A80) : const Color(0xFFBA1A1A),
      dark: dark,
      face: face,
    );
  }

  final Color bg;
  final Color card;
  final Color fill;

  /// Only where a separator cannot be avoided.
  final Color line;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color solid;
  final Color onSolid;

  /// The glass of the floating bar, and its rim.
  final Color bar;
  final Color barRim;
  final Color recovery;
  final Color recoveryBg;
  final Color heart;
  final Color heartBg;

  /// Years gained and years lost; only in Longevity.
  final Color up;
  final Color down;
  final bool dark;
  final MonoFace face;

  /// The shadow of the floating bar: a wide soft one that lifts it off the
  /// page and a tight one under its edge. [lift] 1 is held up by a finger.
  List<BoxShadow> barShadowLifted(double lift) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: (dark ? 0.5 : 0.14) + 0.08 * lift),
      blurRadius: 32 + 12 * lift,
      spreadRadius: -2,
      offset: Offset(0, 12 + 6 * lift),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: dark ? 0.3 : 0.08),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  List<BoxShadow> get barShadow => barShadowLifted(0);

  /// The tokens of the theme around [context]; derived from its colour
  /// scheme where the look is not wrapped around it, as in a test.
  static MonoTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<MonoTokens>() ??
        MonoTokens.from(theme.brightness, theme.colorScheme.primary);
  }

  @override
  MonoTokens copyWith() => this;

  @override
  MonoTokens lerp(MonoTokens? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

/// [base] dressed in the look: the tokens, the page ground and the fonts.
/// Pages of the standard look that are pushed on top of it still read well.
ThemeData monoTheme(
  ThemeData base, {
  bool tint = false,
  MonoFace face = MonoFace.mono,
}) {
  final tokens = MonoTokens.from(
    base.brightness,
    base.colorScheme.primary,
    tint: tint,
    face: face,
  );
  final scheme = base.colorScheme.copyWith(
    surface: tokens.bg,
    surfaceBright: tokens.card,
    surfaceDim: tokens.bg,
    surfaceContainerLowest: tokens.bg,
    surfaceContainerLow: tokens.card,
    surfaceContainer: tokens.bg,
    surfaceContainerHigh: tokens.card,
    surfaceContainerHighest: tokens.fill,
    onSurface: tokens.ink,
    onSurfaceVariant: tokens.ink2,
    primary: tokens.solid,
    onPrimary: tokens.onSolid,
    secondary: tokens.ink2,
    onSecondary: tokens.bg,
    tertiary: tokens.recovery,
    onTertiary: tokens.bg,
    primaryContainer: tokens.fill,
    onPrimaryContainer: tokens.ink,
    secondaryContainer: tokens.fill,
    onSecondaryContainer: tokens.ink,
    tertiaryContainer: tokens.fill,
    onTertiaryContainer: tokens.ink,
    outlineVariant: tokens.line,
  );
  final text = base.textTheme.apply(
    fontFamily: face == MonoFace.flex ? AppTheme.fontFamily : 'Inter',
    fontFamilyFallback: face == MonoFace.flex ? null : const ['Inter Ext'],
    bodyColor: tokens.ink,
    displayColor: tokens.ink,
  );
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: tokens.bg,
    canvasColor: tokens.bg,
    textTheme: text,
    extensions: [...base.extensions.values, tokens],
  );
}
