import 'dart:ui' show lerpDouble;

import 'package:flutter/services.dart' show SwipeEdge;
import 'package:material_ui/material_ui.dart';

import 'back_gesture.dart';

/// A container transform: the page grows out of [origin], the rectangle of
/// the tile that was tapped, and shrinks back into it on pop. During a back
/// swipe the page shrinks a little first, so the page beneath shows.
class ContainerRoute<T> extends PageRoute<T> with BackGestureRoute<T> {
  ContainerRoute({
    required this.builder,
    required this.origin,
    required this.originColor,
    this.originRadius = 28,
  });

  final WidgetBuilder builder;
  final Rect origin;
  final Color originColor;
  final double originRadius;

  /// How many of these pages lie open over all of the page they grew out
  /// of. That page stays in the tree beneath, since this route is not
  /// opaque, and reads the number to rest what moves on it unseen.
  static final ValueNotifier<int> covering = ValueNotifier(0);

  bool _covers = false;

  /// Open and at rest, the page hides what is beneath. While it opens,
  /// closes or follows a back swipe, that shows.
  void _tellCovering() {
    final covers =
        animation?.status == AnimationStatus.completed &&
        backProgress.value == 0;
    if (covers == _covers) return;
    _covers = covers;
    covering.value += covers ? 1 : -1;
  }

  @override
  void install() {
    super.install();
    animation?.addStatusListener((_) => _tellCovering());
    backProgress.addListener(_tellCovering);
  }

  @override
  void dispose() {
    if (_covers) covering.value--;
    _covers = false;
    super.dispose();
  }

  @override
  bool get opaque => false;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 500);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 350);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubicEmphasized,
      reverseCurve: Curves.easeInOutCubicEmphasized.flipped,
    );
    final contentFade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.3, 1),
    );
    return AnimatedBuilder(
      animation: Listenable.merge([curved, backProgress]),
      child: FadeTransition(opacity: contentFade, child: child),
      builder: (context, child) {
        final screen = MediaQuery.sizeOf(context);
        final t = curved.value;
        // Android's measures for a page that follows the back swipe: down
        // to 90 %, pushed away from the edge the finger came from.
        final back = backProgress.value;
        final scale = lerpDouble(1, 0.9, back)!;
        final shift = (screen.width / 20 - 8) * back;
        final open = Rect.fromCenter(
          center: screen.center(
            Offset(backEdge == SwipeEdge.left ? shift : -shift, 0),
          ),
          width: screen.width * scale,
          height: screen.height * scale,
        );
        final rect = Rect.lerp(origin, open, t)!;
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: scheme.scrim.withValues(alpha: 0.32 * animation.value),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: rect,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  lerpDouble(originRadius, originRadius * back, t)!,
                ),
                child: ColoredBox(
                  color: Color.lerp(
                    originColor,
                    Theme.of(context).scaffoldBackgroundColor,
                    t,
                  )!,
                  // The page keeps its final size and is revealed by the
                  // growing clip, so its layout never reflows mid-flight.
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minWidth: screen.width,
                    maxWidth: screen.width,
                    minHeight: screen.height,
                    maxHeight: screen.height,
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.topCenter,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
