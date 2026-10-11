import 'package:material_ui/material_ui.dart';

import 'app_shapes.dart';
import 'app_theme.dart';

/// What sets a page apart from the others: the colour role its one loud
/// tile and its marks are painted in, and the family of shapes its scores
/// are shown on. A page puts it around its content; what is below reads it.
/// In the colourful style it also puts the page's own theme around it.
class PageAccent extends StatelessWidget {
  const PageAccent({
    super.key,
    required this.tone,
    required this.family,
    required this.child,
  });

  const PageAccent.day({super.key, required this.child})
    : tone = Tone.primary,
      family = ShapeFamily.day;

  const PageAccent.sleep({super.key, required this.child})
    : tone = Tone.tertiary,
      family = ShapeFamily.sleep;

  const PageAccent.activity({super.key, required this.child})
    : tone = Tone.secondary,
      family = ShapeFamily.activity;

  const PageAccent.heart({super.key, required this.child})
    : tone = Tone.error,
      family = ShapeFamily.heart;

  final Tone tone;
  final ShapeFamily family;
  final Widget child;

  /// The accent of the page [context] is on; the day's where none is set.
  static ({Tone tone, ShapeFamily family}) of(BuildContext context) {
    final accent = context.dependOnInheritedWidgetOfExactType<_AccentScope>();
    return (
      tone: accent?.tone ?? Tone.primary,
      family: accent?.family ?? ShapeFamily.day,
    );
  }

  /// The colours of the page's accent. Where every page has a theme of its
  /// own, the accent is that theme's primary.
  static ToneColors colorsOf(BuildContext context) {
    final tone = of(context).tone;
    final theme = Theme.of(context);
    final own = theme.extension<PageSchemes>()?.of(tone);
    if (own == null) return theme.colorScheme.tone(tone);
    return own.colorScheme.tone(
      tone == Tone.neutral ? Tone.neutral : Tone.primary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = _AccentScope(tone: tone, family: family, child: child);
    final own = Theme.of(context).extension<PageSchemes>()?.of(tone);
    return own == null ? scope : Theme(data: own, child: scope);
  }
}

class _AccentScope extends InheritedWidget {
  const _AccentScope({
    required this.tone,
    required this.family,
    required super.child,
  });

  final Tone tone;
  final ShapeFamily family;

  @override
  bool updateShouldNotify(_AccentScope oldWidget) =>
      oldWidget.tone != tone || oldWidget.family != family;
}
