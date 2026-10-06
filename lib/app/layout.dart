import 'package:material_ui/material_ui.dart';

/// Space a scrolling page leaves free at its end so the floating navigation
/// never covers the last tile.
const double kFloatingNavClearance = 112;

/// Padding of a top-level page that scrolls under the floating navigation.
EdgeInsets pagePadding(BuildContext context) => EdgeInsets.fromLTRB(
  16,
  8,
  16,
  kFloatingNavClearance + MediaQuery.paddingOf(context).bottom,
);

/// The rectangle [context]'s widget occupies on screen, if it is laid out.
Rect? globalRectOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
