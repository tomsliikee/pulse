import 'dart:ui' show FontFeature, FontVariation, lerpDouble;

import 'package:material_ui/material_ui.dart';

import 'app_shapes.dart';
import 'page_accent.dart';

/// Switches on the type that uses the axes of the variable font. It sits
/// above the app, so every text follows the setting at once.
class FlexType extends InheritedWidget {
  const FlexType({super.key, required this.enabled, required super.child});

  final bool enabled;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FlexType>()?.enabled ?? false;

  @override
  bool updateShouldNotify(FlexType oldWidget) => oldWidget.enabled != enabled;
}

/// The roles text plays on a page. Each takes the style it would have as
/// plain type and, with [flex] on, sets the font's axes for the role: a
/// number is heavy and wide, its label narrow and light, an aside slanted.
/// With [flex] off every role returns the style it was given.
class AppType {
  const AppType({required this.flex, this.roundness = 100});

  /// The type of the page [context] is on: as round as the page's shapes.
  factory AppType.of(BuildContext context) => AppType(
    flex: FlexType.of(context),
    roundness: switch (PageAccent.of(context).family) {
      ShapeFamily.activity => 0,
      ShapeFamily.heart => 50,
      ShapeFamily.day || ShapeFamily.sleep => 100,
    },
  );

  final bool flex;

  /// The font's roundness axis, from 0 to 100.
  final double roundness;

  /// The one number a page or a large tile is about.
  TextStyle? hero(TextStyle? base) =>
      _vary(base, weight: 800, width: 112, figures: true);

  /// A number among others.
  TextStyle? figure(TextStyle? base) =>
      _vary(base, weight: 700, width: 106, figures: true);

  /// What a number is, beside or under it.
  TextStyle? label(TextStyle? base) => _vary(base, weight: 450, width: 88);

  /// The title of a section.
  TextStyle? title(TextStyle? base) => _vary(base, weight: 750, width: 108);

  /// What stands out in a line of text.
  TextStyle? strong(TextStyle? base) => _vary(base, weight: 700);

  /// A note beside the matter: a hint, a date, a remark.
  TextStyle? aside(TextStyle? base) => _vary(base, slant: -10);

  /// [style] on its way: lighter while a number is still counting up to
  /// [settled] = 1, and a grade bolder while the tile is [pressed].
  TextStyle? moving(
    TextStyle? style, {
    double settled = 1,
    double pressed = 0,
  }) {
    if (!flex || style == null) return style;
    final weight = weightOf(style);
    return _vary(
      style,
      weight: _stepped(
        lerpDouble(weight * 0.55, weight, settled.clamp(0, 1))!,
        20,
        end: weight,
      ),
      grade: _stepped(100 * pressed.clamp(0, 1), 20),
    );
  }

  /// [value] on a grid of [step], or [end] where that is nearer than a
  /// step. Every value of an axis is a font of its own to the engine, which
  /// shapes and draws it from nothing; an axis that moved freely would ask
  /// for a new font with every frame, and that is what a page stuttered on.
  /// On a grid this fine no step is seen, and the fonts are met again.
  static double _stepped(double value, double step, {double? end}) {
    if (end != null && (end - value).abs() < step) return end;
    return (value / step).round() * step;
  }

  /// The label of a tab: the nearer it is to [selected] = 1, the heavier
  /// and wider.
  TextStyle? tab(TextStyle? style, double selected) {
    final t = selected.clamp(0.0, 1.0);
    return _vary(
      style,
      weight: _stepped(lerpDouble(500, 800, t)!, 20),
      width: _stepped(lerpDouble(96, 112, t)!, 2),
    );
  }

  /// The weight [style] is drawn in.
  static double weightOf(TextStyle style) {
    for (final variation in style.fontVariations ?? const <FontVariation>[]) {
      if (variation.axis == 'wght') return variation.value;
    }
    return (style.fontWeight ?? FontWeight.w400).value.toDouble();
  }

  TextStyle? _vary(
    TextStyle? base, {
    double? weight,
    double? width,
    double? slant,
    double? grade,
    bool figures = false,
  }) {
    if (!flex || base == null) return base;
    final axes = <String, double>{
      for (final variation in base.fontVariations ?? const <FontVariation>[])
        variation.axis: variation.value,
      'ROND': roundness,
      'opsz': ?base.fontSize?.clamp(6, 144).toDouble(),
      'wght': ?weight,
      'wdth': ?width,
      'slnt': ?slant,
      'GRAD': ?grade,
    };
    return base.copyWith(
      // The nearest named weight, for where the axis is not honoured.
      fontWeight: weight == null
          ? null
          : FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
      fontVariations: [
        for (final MapEntry(:key, :value) in axes.entries)
          FontVariation(key, value),
      ],
      // Digits of one width, so a number that counts does not shake.
      fontFeatures: figures ? const [FontFeature.tabularFigures()] : null,
    );
  }
}
