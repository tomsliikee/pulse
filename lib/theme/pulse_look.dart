import 'package:material_ui/material_ui.dart';

/// The two looks the app can wear on top of its theme: the turtle in the
/// scenes and the expressive rework. It sits above the app, so pushed pages
/// follow the settings as well.
class PulseLook extends InheritedWidget {
  const PulseLook({
    super.key,
    this.mascot = false,
    this.expressive = false,
    this.calm = false,
    required super.child,
  });

  /// Whether the scenes show the turtle instead of the stick figure.
  final bool mascot;

  /// Whether pages wear the expressive rework.
  final bool expressive;

  /// Whether the scenes are left out.
  final bool calm;

  static PulseLook? _of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PulseLook>();

  static bool mascotOf(BuildContext context) => _of(context)?.mascot ?? false;

  static bool calmOf(BuildContext context) => _of(context)?.calm ?? false;

  static bool expressiveOf(BuildContext context) =>
      _of(context)?.expressive ?? false;

  @override
  bool updateShouldNotify(PulseLook oldWidget) =>
      oldWidget.mascot != mascot ||
      oldWidget.expressive != expressive ||
      oldWidget.calm != calm;
}
