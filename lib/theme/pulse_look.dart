import 'package:material_ui/material_ui.dart';

/// The looks the app can be drawn in as a whole.
enum AppLook {
  /// The app as it has always been.
  standard,

  /// Black, white and grey with its own pages: Insights, Longevity, Browse.
  insightsMono,

  /// The pages of Insights Mono, set in Google Sans Flex with round titles.
  insightsFlex;

  /// Whether the look brings its own pages and colours.
  bool get isInsights => this != standard;
}

/// The two looks the app can wear on top of its theme: the turtle in the
/// scenes and the expressive rework. It sits above the app, so pushed pages
/// follow the settings as well.
class PulseLook extends InheritedWidget {
  const PulseLook({
    super.key,
    this.mascot = false,
    this.expressive = false,
    this.calm = false,
    this.look = AppLook.standard,
    required super.child,
  });

  /// Whether the scenes show the turtle instead of the stick figure.
  final bool mascot;

  /// Whether pages wear the expressive rework.
  final bool expressive;

  /// Whether the scenes are left out.
  final bool calm;

  /// The look the whole app is drawn in.
  final AppLook look;

  static PulseLook? _of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PulseLook>();

  static AppLook lookOf(BuildContext context) =>
      _of(context)?.look ?? AppLook.standard;

  /// Whether one of the Insights looks is worn; the shared pages of the
  /// standard look leave out their scenes and shapes then.
  static bool monoOf(BuildContext context) => lookOf(context).isInsights;

  static bool mascotOf(BuildContext context) => _of(context)?.mascot ?? false;

  static bool calmOf(BuildContext context) => _of(context)?.calm ?? false;

  static bool expressiveOf(BuildContext context) =>
      _of(context)?.expressive ?? false;

  @override
  bool updateShouldNotify(PulseLook oldWidget) =>
      oldWidget.mascot != mascot ||
      oldWidget.expressive != expressive ||
      oldWidget.calm != calm ||
      oldWidget.look != look;
}
