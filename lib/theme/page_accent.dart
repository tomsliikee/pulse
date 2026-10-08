import 'package:material_ui/material_ui.dart';

import 'app_shapes.dart';
import 'app_theme.dart';

/// What sets a page apart from the others: the colour role its one loud
/// tile and its marks are painted in, and the family of shapes its scores
/// are shown on. A page puts it around its content; what is below reads it.
class PageAccent extends InheritedWidget {
  const PageAccent({
    super.key,
    required this.tone,
    required this.family,
    required super.child,
  });

  const PageAccent.day({super.key, required super.child})
    : tone = Tone.primary,
      family = ShapeFamily.day;

  const PageAccent.sleep({super.key, required super.child})
    : tone = Tone.tertiary,
      family = ShapeFamily.sleep;

  const PageAccent.activity({super.key, required super.child})
    : tone = Tone.secondary,
      family = ShapeFamily.activity;

  const PageAccent.heart({super.key, required super.child})
    : tone = Tone.error,
      family = ShapeFamily.heart;

  final Tone tone;
  final ShapeFamily family;

  /// The accent of the page [context] is on; the day's where none is set.
  static ({Tone tone, ShapeFamily family}) of(BuildContext context) {
    final accent = context.dependOnInheritedWidgetOfExactType<PageAccent>();
    return (
      tone: accent?.tone ?? Tone.primary,
      family: accent?.family ?? ShapeFamily.day,
    );
  }

  /// The colours of the page's accent.
  static ToneColors colorsOf(BuildContext context) =>
      Theme.of(context).colorScheme.tone(of(context).tone);

  @override
  bool updateShouldNotify(PageAccent oldWidget) =>
      oldWidget.tone != tone || oldWidget.family != family;
}
