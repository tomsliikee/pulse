import 'package:material_ui/material_ui.dart';

import '../../../theme/app_theme.dart';
import 'mono_tokens.dart';

/// The type of the look: Geist Serif for titles and statements, Inter with
/// tabular figures for everything else. In Insights Flex both are Google
/// Sans Flex, the titles heavy and round.
abstract final class MonoType {
  static const String serif = 'Geist Serif';
  static const String sans = 'Inter';
  static const List<String> sansFallback = ['Inter Ext'];

  /// The face of the look the app wears; the app sets it before each build,
  /// as the styles here are asked for without a context.
  static MonoFace face = MonoFace.mono;

  static TextStyle inter(
    double size,
    double height,
    FontWeight weight,
    Color color, {
    double spacing = 0,
  }) => face == MonoFace.flex
      ? TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: size,
          height: height / size,
          fontWeight: weight,
          fontVariations: [
            FontVariation.weight(weight.value.toDouble()),
            FontVariation('opsz', size.clamp(6, 144).toDouble()),
            const FontVariation('ROND', 30),
          ],
          fontFeatures: const [FontFeature.tabularFigures()],
          letterSpacing: spacing * size * 0.5,
          color: color,
          decoration: TextDecoration.none,
        )
      : TextStyle(
          fontFamily: sans,
          fontFamilyFallback: sansFallback,
          fontSize: size,
          height: height / size,
          fontWeight: weight,
          fontVariations: [FontVariation.weight(weight.value.toDouble())],
          fontFeatures: const [FontFeature.tabularFigures()],
          letterSpacing: spacing * size,
          color: color,
          decoration: TextDecoration.none,
        );

  /// A title in Insights Flex: heavy, fully round and a touch wide.
  static TextStyle round(double size, double height, Color color) => TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontSize: size,
    height: height / size,
    fontWeight: FontWeight.w700,
    fontVariations: [
      const FontVariation('wght', 720),
      const FontVariation('ROND', 100),
      const FontVariation('wdth', 104),
      FontVariation('opsz', size.clamp(6, 144).toDouble()),
    ],
    letterSpacing: -0.01 * size,
    color: color,
    decoration: TextDecoration.none,
  );

  /// 32/36 w600, −2 %. [size] 44 is the gauge, 64 the body age.
  static TextStyle number(MonoTokens t, {double size = 32}) =>
      inter(size, size * 36 / 32, FontWeight.w600, t.ink, spacing: -0.02);

  /// 20/24 w600.
  static TextStyle numberSmall(MonoTokens t) =>
      inter(20, 24, FontWeight.w600, t.ink, spacing: -0.01);

  /// 22/27 w600: the statement inside a card, in Inter; serif is for headers.
  static TextStyle statement(MonoTokens t) =>
      inter(22, 27, FontWeight.w600, t.ink, spacing: -0.012);

  /// 14/18 w600, in the colour of the category.
  static TextStyle category(Color color) =>
      inter(14, 18, FontWeight.w600, color);

  /// 13/18 in ink2.
  static TextStyle time(MonoTokens t) => inter(13, 18, FontWeight.w400, t.ink2);

  /// 13/18 w500 in ink2, for labels.
  static TextStyle label(MonoTokens t) =>
      inter(13, 18, FontWeight.w500, t.ink2);

  /// 14/18 w500 in ink2, for units.
  static TextStyle unit(MonoTokens t) => inter(14, 18, FontWeight.w500, t.ink2);

  /// 15/21.
  static TextStyle body(MonoTokens t) => inter(15, 21, FontWeight.w400, t.ink);

  /// 15/20 in ink2.
  static TextStyle sub(MonoTokens t) => inter(15, 20, FontWeight.w400, t.ink2);

  static TextStyle _serif(
    double size,
    double height,
    double spacing,
    Color c,
  ) => TextStyle(
    fontFamily: serif,
    fontSize: size,
    height: height / size,
    letterSpacing: spacing * size,
    color: c,
    decoration: TextDecoration.none,
  );

  /// The serif styles as (size, line height, spacing, stroke).
  static const (double, double, double, double) titleSpec = (
    38,
    44,
    -0.02,
    1.2,
  );
  static const (double, double, double, double) h2Spec = (24, 30, -0.01, 1.0);
  static const (double, double, double, double) statementSpec = (
    22,
    27,
    -0.012,
    0.9,
  );
}

/// Serif text with the weight Geist Serif lacks: a stroke of the same colour
/// under the fill.
class MonoSerif extends StatelessWidget {
  const MonoSerif(
    this.text, {
    super.key,
    this.spec = MonoType.statementSpec,
    this.color,
    this.maxLines,
  });

  const MonoSerif.title(this.text, {super.key, this.color, this.maxLines})
    : spec = MonoType.titleSpec;

  const MonoSerif.heading(this.text, {super.key, this.color, this.maxLines})
    : spec = MonoType.h2Spec;

  final String text;
  final (double, double, double, double) spec;
  final Color? color;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final tokens = MonoTokens.of(context);
    final c = color ?? tokens.ink;
    final (size, height, spacing, stroke) = spec;
    if (tokens.face == MonoFace.flex) {
      return Text(
        text,
        maxLines: maxLines,
        style: MonoType.round(size, height, c),
      );
    }
    final fill = MonoType._serif(size, height, spacing, c);
    final outline = fill.copyWith(
      color: null,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round
        ..color = c,
    );
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Stack(
        children: [
          Text(text, style: outline, maxLines: maxLines),
          Text(text, style: fill, maxLines: maxLines),
        ],
      ),
    );
  }
}
