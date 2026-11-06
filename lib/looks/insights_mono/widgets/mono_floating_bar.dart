import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/haptics.dart';
import '../../../app/layout.dart';
import '../theme/mono_tokens.dart';
import '../theme/mono_type.dart';
import 'mono_motion.dart';

/// One tab of the floating bar.
class MonoTab {
  const MonoTab(this.icon, this.label);

  final Widget icon;
  final String label;
}

/// Frosted glass in the shape of a capsule: the shadow outside the clip so
/// it falls soft on every side, the blur and a thin rim inside. Every
/// floating element of the look stands on it. With the glass setting off it
/// is the same capsule, opaque and without the blur.
class MonoGlass extends StatelessWidget {
  const MonoGlass({
    super.key,
    required this.child,
    this.radius = 30,
    this.lift = 0,
    this.opacity = 1,
    this.backdrop = true,
  });

  final Widget child;
  final double radius;

  /// Fades the fill, rim and shadow, for a pill that comes in: the blur
  /// behind stays, so no layer has to be made to fade it.
  final double opacity;

  /// Whether this glass blurs what is behind it itself. Glass that shares
  /// the blur of a group, or that is moving, leaves it out.
  final bool backdrop;

  /// 0 resting, 1 held up: a deeper shadow.
  final double lift;

  /// One filter for all of them: a new instance on every build would make the
  /// engine set the blur up again each frame.
  static final ImageFilter blur = ImageFilter.blur(sigmaX: 16, sigmaY: 16);

  Color _fade(Color c) =>
      opacity >= 1 ? c : c.withValues(alpha: c.a * opacity.clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final shape = BorderRadius.circular(radius);
    final face = DecoratedBox(
      decoration: BoxDecoration(
        color: _fade(t.floatFill),
        borderRadius: shape,
        border: Border.all(color: _fade(t.barRim), width: 0.8),
      ),
      child: child,
    );
    return RepaintBoundary(
      child: CustomPaint(
        painter: _OuterShadow(
          radius: radius,
          shadows: [
            for (final s in t.barShadowLifted(lift))
              BoxShadow(
                color: _fade(s.color),
                blurRadius: s.blurRadius,
                spreadRadius: s.spreadRadius,
                offset: s.offset,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: shape,
          child: t.glass && backdrop
              ? BackdropFilter(filter: blur, child: face)
              : face,
        ),
      ),
    );
  }
}

/// The shadow of a capsule, drawn only outside it. A box shadow also falls
/// under the box, and through a see-through glass that shows as a grey patch.
class _OuterShadow extends CustomPainter {
  const _OuterShadow({required this.radius, required this.shadows});

  final double radius;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect((Offset.zero & size).inflate(400))
        ..addRRect(shape),
    );
    for (final shadow in shadows) {
      canvas.drawRRect(
        shape.shift(shadow.offset).inflate(shadow.spreadRadius),
        shadow.toPaint(),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OuterShadow old) =>
      old.radius != radius || !listEquals(old.shadows, shadows);
}

/// The capsule at the bottom: the open page as a solid pill with icon and
/// label, the others as icons, and a round + beside it. A finger can slide
/// along the capsule; the pill lifts while it is held and follows it.
class MonoFloatingBar extends StatelessWidget {
  const MonoFloatingBar({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
    required this.addLabel,
    required this.onAdd,
  });

  final List<MonoTab> tabs;
  final int selected;
  final ValueChanged<int> onSelected;
  final String addLabel;
  final VoidCallback onAdd;

  static const double height = 60;

  /// The capsule of the tabs, and the bar as a whole with its + beside it;
  /// the bar stands in the middle of the screen.
  static const double tabsWidth = 236;
  static const double gap = 12;
  static const double width = tabsWidth + gap + height;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    // One blur behind the capsule and the +: two separate ones would blur
    // the same strip of the page twice.
    return SizedBox(
      height: height,
      width: width,
      child: Stack(
        children: [
          if (t.glass)
            Positioned.fill(
              child: ClipPath(
                clipper: const _BarShape(),
                child: BackdropFilter(
                  filter: MonoGlass.blur,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          Row(
            children: [
              SizedBox(
                width: tabsWidth,
                child: _Tabs(
                  tabs: tabs,
                  selected: selected,
                  onSelected: onSelected,
                ),
              ),
              const SizedBox(width: gap),
              Semantics(
                button: true,
                label: addLabel,
                child: ExcludeSemantics(
                  child: MonoPress(
                    onTap: () {
                      Haptics.tap();
                      onAdd();
                    },
                    squash: 0.08,
                    child: MonoGlass(
                      backdrop: false,
                      child: SizedBox.square(
                        dimension: height,
                        child: Icon(Icons.add_rounded, size: 30, color: t.ink),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The two capsules of the bar, for the one blur behind them.
class _BarShape extends CustomClipper<Path> {
  const _BarShape();

  @override
  Path getClip(Size size) {
    const r = Radius.circular(MonoFloatingBar.height / 2);
    return Path()
      ..addRRect(
        RRect.fromLTRBR(0, 0, MonoFloatingBar.tabsWidth, size.height, r),
      )
      ..addRRect(
        RRect.fromLTRBR(
          MonoFloatingBar.tabsWidth + MonoFloatingBar.gap,
          0,
          size.width,
          size.height,
          r,
        ),
      );
  }

  @override
  bool shouldReclip(_BarShape old) => false;
}

class _Tabs extends StatefulWidget {
  const _Tabs({
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<MonoTab> tabs;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> with SingleTickerProviderStateMixin {
  late final AnimationController _lift = AnimationController.unbounded(
    vsync: this,
  );
  static const double _inactive = 48;
  static const double _pad = 5;

  // The tab the finger is over while it slides; shown before it is chosen.
  int? _under;

  void _hold(bool on) {
    final target = on ? 1.0 : 0.0;
    if (monoStill(context)) {
      _lift.value = 0;
      return;
    }
    _lift.animateWith(
      SpringSimulation(monoSpring, _lift.value, target, _lift.velocity),
    );
  }

  int _indexAt(double x, double width) {
    final shown = _under ?? widget.selected;
    final active = width - _pad * 2 - _inactive * (widget.tabs.length - 1);
    var left = _pad;
    for (var i = 0; i < widget.tabs.length; i++) {
      final w = i == shown ? active : _inactive;
      if (x < left + w) return i;
      left += w;
    }
    return widget.tabs.length - 1;
  }

  void _slide(double x, double width) {
    final i = _indexAt(x, width);
    if (i == (_under ?? widget.selected)) return;
    Haptics.selection();
    setState(() => _under = i);
  }

  void _release() {
    final chosen = _under;
    setState(() => _under = null);
    _hold(false);
    if (chosen != null && chosen != widget.selected) widget.onSelected(chosen);
  }

  @override
  void dispose() {
    _lift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final shown = _under ?? widget.selected;
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final active = width - _pad * 2 - _inactive * (widget.tabs.length - 1);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            _hold(true);
            _slide(d.localPosition.dx, width);
          },
          onTapUp: (_) => _release(),
          onTapCancel: () {
            // A slide takes over from the tap; the hold stays.
            if (_under == null) _hold(false);
          },
          onHorizontalDragStart: (d) {
            _hold(true);
            _slide(d.localPosition.dx, width);
          },
          onHorizontalDragUpdate: (d) => _slide(d.localPosition.dx, width),
          onHorizontalDragEnd: (_) => _release(),
          onHorizontalDragCancel: _release,
          child: AnimatedBuilder(
            animation: _lift,
            builder: (context, _) {
              final lift = _lift.value;
              return MonoGlass(
                backdrop: false,
                lift: lift.clamp(0.0, 1.0),
                child: Padding(
                  padding: const EdgeInsets.all(_pad),
                  child: Row(
                    children: [
                      for (var i = 0; i < widget.tabs.length; i++)
                        Semantics(
                          button: true,
                          selected: i == widget.selected,
                          label: widget.tabs[i].label,
                          onTap: () => widget.onSelected(i),
                          child: ExcludeSemantics(
                            child: _Slot(
                              tab: widget.tabs[i],
                              chosen: i == shown,
                              width: i == shown ? active : _inactive,
                              lift: i == shown ? lift : 0,
                              tokens: t,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.tab,
    required this.chosen,
    required this.width,
    required this.lift,
    required this.tokens,
  });

  final MonoTab tab;
  final bool chosen;
  final double width;
  final double lift;
  final MonoTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final color = chosen ? t.onSolid : t.ink2;
    return AnimatedContainer(
      duration: monoStill(context)
          ? Duration.zero
          : const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      width: width,
      height: 50,
      transformAlignment: Alignment.center,
      transform: Matrix4.diagonal3Values(1 + lift * 0.1, 1 + lift * 0.1, 1),
      decoration: BoxDecoration(
        color: chosen ? t.solid : Colors.transparent,
        borderRadius: BorderRadius.circular(25),
        boxShadow: chosen && lift > 0.01
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22 * lift),
                  blurRadius: 18 * lift,
                  offset: Offset(0, 6 * lift),
                ),
              ]
            : null,
      ),
      child: ClipRect(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconTheme.merge(
              data: IconThemeData(size: 22, color: color),
              child: tab.icon,
            ),
            if (chosen) ...[
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                  style: MonoType.inter(14, 18, FontWeight.w600, color),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The search of Browse: a pill that floats above the bar and rides up on
/// the keyboard while it is open. It gives its focus away for good when a
/// page is pushed on top, so coming back never brings the keyboard.
class MonoSearchPill extends StatefulWidget {
  const MonoSearchPill({
    super.key,
    required this.query,
    required this.hint,
    required this.clearLabel,
  });

  final ValueNotifier<String> query;
  final String hint;
  final String clearLabel;

  @override
  State<MonoSearchPill> createState() => _MonoSearchPillState();
}

class _MonoSearchPillState extends State<MonoSearchPill> with RouteAware {
  late final TextEditingController _text = TextEditingController(
    text: widget.query.value,
  );
  final FocusNode _focus = FocusNode();
  ModalRoute<void>? _route;

  // While the keyboard slides the pill goes without its blur: the page moves
  // under it and the blur would be made again every frame.
  double? _inset;
  bool _sliding = false;
  Timer? _settle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (_inset != null && inset != _inset) {
      _sliding = true;
      _settle?.cancel();
      _settle = Timer(const Duration(milliseconds: 120), () {
        if (mounted) setState(() => _sliding = false);
      });
    }
    _inset = inset;
    final route = ModalRoute.of(context);
    if (route != _route) {
      if (_route != null) appRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    _focus
      ..unfocus()
      ..canRequestFocus = false;
  }

  @override
  void didPopNext() => _focus.canRequestFocus = true;

  @override
  void dispose() {
    _settle?.cancel();
    appRouteObserver.unsubscribe(this);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    return MonoGlass(
      radius: 26,
      backdrop: !_sliding,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            const SizedBox(width: 18),
            Icon(Icons.search_rounded, size: 22, color: t.ink2),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _text,
                focusNode: _focus,
                onChanged: (v) {
                  widget.query.value = v;
                  setState(() {});
                },
                onTapOutside: (_) => _focus.unfocus(),
                textInputAction: TextInputAction.search,
                cursorColor: t.ink,
                style: MonoType.inter(16, 22, FontWeight.w400, t.ink),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintText: widget.hint,
                  hintStyle: MonoType.inter(16, 22, FontWeight.w400, t.ink3),
                ),
              ),
            ),
            if (_text.text.isNotEmpty)
              Semantics(
                button: true,
                label: widget.clearLabel,
                child: ExcludeSemantics(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Haptics.tap();
                      _text.clear();
                      widget.query.value = '';
                      setState(() {});
                    },
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: Icon(Icons.close_rounded, size: 22, color: t.ink2),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 18),
          ],
        ),
      ),
    );
  }
}
