import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature, lerpDouble;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_scope.dart';
import '../../../app/haptics.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../pages/training/live_page.dart';
import '../pages/training/training_text.dart';
import '../search/search_panel.dart';
import '../theme/mono_tokens.dart';
import '../theme/mono_type.dart';
import '../widgets/mono_floating_bar.dart';
import '../widgets/mono_icons.dart';
import '../widgets/mono_motion.dart';
import 'mono_dock_controller.dart';

/// The sizes of the dock at full size and shrunk.
abstract final class MonoDockSize {
  static const double bar = 56;
  static const double barSmall = 52;
  static const double search = 48;
  static const double searchSmall = 46;
  static const double gap = 10;
  static const double margin = 28;
  static const double marginSmall = 20;
  static const double pad = 4;
  static const double activeSmall = 110;
  static const double inactive = 64;
  static const double inactiveSmall = 62;

  /// The capsule of the three tabs at full size: the open one as a pill with
  /// its label, the others as icons.
  static const double tabs = 302;
  static const double tabsSmall = activeSmall + inactiveSmall * 2 + pad * 2;

  /// How far a page scrolls while the dock goes from one size to the other.
  static const double shrinkDistance = 90;

  static double row(double s) => lerpDouble(tabs, tabsSmall, s)!;

  /// The room a page leaves at its end so its last line can be scrolled
  /// above the dock.
  static double room(BuildContext context) =>
      margin + bar + gap + search + 20 + MediaQuery.paddingOf(context).bottom;

  /// Where the top of the search bar stands from the bottom of the screen
  /// while the search is open.
  static double openBarTop(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return (keyboard > 0
            ? keyboard + 12
            : margin + MediaQuery.paddingOf(context).bottom) +
        search;
  }
}

/// Puts the dock over [child], the navigator of the app, and hands its
/// controller to every page. The dock is above all pages, so it stays in
/// place when a page is pushed; it steps aside for sheets and dialogs.
class MonoDockHost extends StatefulWidget {
  const MonoDockHost({
    super.key,
    required this.controller,
    required this.navigator,
    required this.child,
  });

  final MonoDockController controller;
  final GlobalKey<NavigatorState> navigator;
  final Widget child;

  @override
  State<MonoDockHost> createState() => _MonoDockHostState();
}

class _MonoDockHostState extends State<MonoDockHost> {
  late final OverlayEntry _pages = OverlayEntry(
    maintainState: true,
    opaque: true,
    builder: (_) => _child,
  );
  late final OverlayEntry _dock = OverlayEntry(
    builder: (_) =>
        MonoDock(controller: widget.controller, navigator: widget.navigator),
  );
  late Widget _child = widget.child;

  @override
  void didUpdateWidget(MonoDockHost old) {
    super.didUpdateWidget(old);
    if (old.child != widget.child) {
      _child = widget.child;
      _pages.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _pages
      ..remove()
      ..dispose();
    _dock
      ..remove()
      ..dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    final c = widget.controller;
    if (n.metrics.axis != Axis.vertical || c.searchOpen) return false;
    final settings = AppScope.of(context).settings;
    if (!settings.dockShrink) {
      c.shrunk = false;
      return false;
    }
    final m = n.metrics;
    if (n is ScrollUpdateNotification) {
      final delta = n.scrollDelta ?? 0;
      if (m.pixels <= 24) {
        c.shrunk = false;
      } else if (m.pixels < m.maxScrollExtent || delta < 0) {
        // The dock follows the page: down makes it small, up big again.
        c.shrinkBy(delta / MonoDockSize.shrinkDistance);
      }
    } else if (n is ScrollEndNotification) {
      if (m.pixels <= 24) {
        c.shrunk = false;
      } else {
        c.settleShrink();
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return MonoDockScope(
      controller: widget.controller,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Overlay(initialEntries: [_pages, _dock]),
      ),
    );
  }
}

/// The dock: the search above, the bar of the tabs and the round + below,
/// and while a training runs a pill beside the search that leads back to
/// it. Open, the search widens and rides on the keyboard while the bar
/// steps away.
class MonoDock extends StatefulWidget {
  const MonoDock({
    super.key,
    required this.controller,
    required this.navigator,
  });

  final MonoDockController controller;
  final GlobalKey<NavigatorState> navigator;

  @override
  State<MonoDock> createState() => _MonoDockState();
}

class _MonoDockState extends State<MonoDock> with TickerProviderStateMixin {
  late final AnimationController _open = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _small = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _shown = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ValueNotifier<String> _query = ValueNotifier('');
  Route<void>? _searchRoute;

  MonoDockController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
    _c.shrinkChanges.addListener(_shrinkChanged);
    _small.value = _c.shrink;
    _c.openSearch = _openSearch;
    _focus.addListener(() {
      if (_focus.hasFocus) _openSearch();
    });
    _shown.value = _c.visible ? 1 : 0;
  }

  @override
  void dispose() {
    _c.removeListener(_changed);
    _c.shrinkChanges.removeListener(_shrinkChanged);
    if (_c.openSearch == _openSearch) _c.openSearch = null;
    _open.dispose();
    _small.dispose();
    _shown.dispose();
    _text.dispose();
    _focus.dispose();
    _query.dispose();
    super.dispose();
  }

  // Kept from the last build: the controller may call while the tree is
  // being taken down, when the context can no longer be asked.
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = monoStill(context);
  }

  void _spring(
    AnimationController c,
    double target, [
    SpringDescription spring = monoSpring,
  ]) {
    if (_still) {
      c.value = target;
      return;
    }
    c.animateWith(SpringSimulation(spring, c.value, target, c.velocity));
  }

  /// Where the search bar stands while closed, on the screen; kept from the
  /// last frame for the panel to shrink into.
  Rect _home = Rect.zero;

  /// Where the open search bar stood when a pull began. The keyboard goes
  /// down as the panel is pulled; the bar must not follow it below its place.
  double _openBottom = 0;
  double? _pullFrom;

  void _shrinkChanged() {
    if (!mounted) return;
    final target = _c.shrink;
    if (_c.shrinkSettling) {
      if (_small.value != target || _small.isAnimating) _spring(_small, target);
    } else {
      // Following the finger: no spring, the dock moves with the page.
      _small.value = target;
    }
  }

  void _changed() {
    if (!mounted) return;
    if (_still) {
      _shown.value = _c.visible ? 1 : 0;
    } else {
      _shown.animateTo(_c.visible ? 1 : 0, curve: Curves.easeOutCubic);
    }
    if (!_c.visible && _focus.hasFocus) _focus.unfocus();
    setState(() {});
  }

  NavigatorState? get _nav => widget.navigator.currentState;

  void _openSearch() {
    final nav = _nav;
    if (_searchRoute != null || nav == null) return;
    Haptics.tap();
    // Closed again, the dock is back at full size.
    _c.shrunk = false;
    final route = MonoSearchRoute(
      query: _query,
      onEdit: _focus.unfocus,
      openness: _open,
      home: () => _home,
      onDrag: _searchPulled,
      onRelease: _searchReleased,
    );
    _searchRoute = route;
    _pullFrom = null;
    _c.searchOpen = true;
    _spring(_open, 1, monoSettle);
    if (!_focus.hasFocus) _focus.requestFocus();
    nav.push(route).whenComplete(_searchClosed);
    // The route does not take the focus, but make sure the field keeps it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_searchRoute == route && !_focus.hasFocus) _focus.requestFocus();
    });
  }

  // The bar follows the panel as it is pulled down, back to its place.
  void _searchPulled(double share) {
    if (_still) return;
    _pullFrom ??= _openBottom;
    _open
      ..stop()
      ..value = 1 - share;
  }

  double _releaseVelocity = 0;

  void _searchReleased(bool closing, double velocity) {
    if (closing) {
      _releaseVelocity = -velocity;
    } else {
      _pullFrom = null;
      _spring(_open, 1, monoSettle);
    }
  }

  void _searchClosed() {
    _searchRoute = null;
    _text.clear();
    _query.value = '';
    _focus.unfocus();
    _c.searchOpen = false;
    if (mounted) {
      final v = _releaseVelocity;
      _releaseVelocity = 0;
      if (_still) {
        _open.value = 0;
      } else {
        // Critically damped: the panel goes into the bar and stops there.
        _open.animateWith(SpringSimulation(monoSettle, _open.value, 0, v));
      }
    }
  }

  void _closeSearch() {
    final route = _searchRoute;
    if (route == null) return;
    Haptics.tap();
    if (route.isCurrent) {
      _nav?.pop();
    } else {
      _nav?.removeRoute(route);
      _searchClosed();
    }
  }

  void _selectTab(int index) {
    final nav = _nav;
    if (nav != null && _c.depth > 0) {
      nav.popUntil((r) => r.isFirst);
    }
    _c.selectTab(index);
  }

  void _openLive() {
    final nav = _nav;
    if (nav == null) return;
    Haptics.tap();
    FocusManager.instance.primaryFocus?.unfocus();
    // Back to the live screen that is still in the stack, or a new one.
    final live = _c.liveRoute;
    if (live != null && live.isActive) {
      nav.popUntil((r) => r == live);
    } else {
      nav.push(MonoLiveRoute());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final training = AppScope.of(context).training;
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: Listenable.merge([_open, _small, _shown, training]),
        builder: (context, _) {
          final width = media.size.width;
          final open = _open.value;
          final o = open.clamp(0.0, 1.0);
          // The search open, the dock is at full size whatever the page.
          final s = (_small.value * (1 - o)).clamp(0.0, 1.05);
          final hide = 1 - _shown.value;
          final safe = media.padding.bottom;
          final keyboard = media.viewInsets.bottom;

          final bar = lerpDouble(MonoDockSize.bar, MonoDockSize.barSmall, s)!;
          final searchH = lerpDouble(
            MonoDockSize.search,
            MonoDockSize.searchSmall,
            s,
          )!;
          final margin = lerpDouble(
            MonoDockSize.margin,
            MonoDockSize.marginSmall,
            s,
          )!;
          final rowW = MonoDockSize.row(s);
          final rowLeft = (width - rowW) / 2;
          // Hidden, the whole dock goes below the edge, the search with it.
          final rowBottom =
              margin +
              safe -
              hide *
                  (margin +
                      safe +
                      bar +
                      MonoDockSize.gap +
                      searchH +
                      MonoDockSize.margin);

          final live = training.active != null && !_c.liveOnTop;
          final closedW = live ? (rowW - MonoDockSize.gap) / 2 : rowW;
          final openW = width - 24;
          final searchW = lerpDouble(closedW, openW, o)!;
          final closedBottom = rowBottom + bar + MonoDockSize.gap;
          _openBottom = keyboard > 0
              ? keyboard + 12
              : MonoDockSize.margin + safe;
          final openBottom = _pullFrom ?? _openBottom;
          final searchBottom = lerpDouble(closedBottom, openBottom, o)!;
          final searchLeft = lerpDouble(rowLeft, 12, o)!;
          _home = Rect.fromLTWH(
            rowLeft,
            media.size.height - closedBottom - searchH,
            closedW,
            searchH,
          );

          return Stack(
            children: [
              // The bar of the tabs, which steps away while the search is
              // open.
              Positioned(
                left: rowLeft,
                width: rowW,
                bottom: rowBottom - o * 40,
                height: bar,
                child: IgnorePointer(
                  ignoring: o > 0.05 || hide > 0.5,
                  child: Opacity(
                    opacity: (1 - o * 1.4).clamp(0.0, 1.0),
                    child: _Row(
                      small: s,
                      height: bar,
                      tabs: [
                        MonoTab(
                          const Icon(Icons.insights_rounded),
                          l10n.monoInsights,
                        ),
                        MonoTab(
                          const Icon(Icons.fitness_center_rounded),
                          l10n.navTraining,
                        ),
                        MonoTab(const MonoLongevityIcon(), l10n.monoLongevity),
                      ],
                      selected: _c.tab,
                      onSelected: _selectTab,
                      // A touch on the small dock makes it big again, once
                      // the finger is off: the bar keeps its size under it.
                      onReleased: () {
                        if (_c.shrunk) _c.shrunk = false;
                      },
                    ),
                  ),
                ),
              ),
              if (live && o < 1)
                Positioned(
                  left: rowLeft + closedW + MonoDockSize.gap,
                  width: closedW,
                  bottom: closedBottom,
                  height: searchH,
                  child: IgnorePointer(
                    ignoring: o > 0.05 || hide > 0.5,
                    child: Opacity(
                      opacity: (1 - o * 2).clamp(0.0, 1.0),
                      child: _LivePill(height: searchH, onTap: _openLive),
                    ),
                  ),
                ),
              Positioned(
                left: searchLeft,
                width: searchW,
                bottom: searchBottom,
                height: searchH,
                child: IgnorePointer(
                  ignoring: hide > 0.5,
                  child: _SearchBar(
                    text: _text,
                    focus: _focus,
                    height: searchH,
                    open: _c.searchOpen,
                    hint: l10n.monoSearch,
                    clearLabel: l10n.close,
                    tokens: t,
                    onChanged: (v) => _query.value = v,
                    onClose: _closeSearch,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The search field on the glass of the dock.
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.text,
    required this.focus,
    required this.height,
    required this.open,
    required this.hint,
    required this.clearLabel,
    required this.tokens,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController text;
  final FocusNode focus;
  final double height;
  final bool open;
  final String hint;
  final String clearLabel;
  final MonoTokens tokens;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return MonoGlass(
      radius: height / 2,
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(Icons.search_rounded, size: 21, color: t.ink2),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: text,
              focusNode: focus,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              textAlignVertical: TextAlignVertical.center,
              cursorColor: t.ink,
              style: MonoType.inter(16, 22, FontWeight.w400, t.ink),
              decoration: InputDecoration(
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                filled: false,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                hintText: hint,
                hintStyle: MonoType.inter(16, 22, FontWeight.w400, t.ink2),
              ),
            ),
          ),
          if (open)
            Semantics(
              button: true,
              label: clearLabel,
              child: ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClose,
                  child: SizedBox(
                    width: 48,
                    height: height,
                    child: Icon(Icons.close_rounded, size: 21, color: t.ink2),
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 16),
        ],
      ),
    );
  }
}

/// The capsule of the tabs, with its blur.
class _Row extends StatelessWidget {
  const _Row({
    required this.small,
    required this.height,
    required this.tabs,
    required this.selected,
    required this.onSelected,
    this.onReleased,
  });

  final double small;
  final double height;
  final List<MonoTab> tabs;
  final int selected;
  final ValueChanged<int> onSelected;
  final VoidCallback? onReleased;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    return Stack(
      children: [
        if (t.glass)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(height / 2),
              child: BackdropFilter(
                filter: MonoGlass.blur,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        MonoTabs(
          tabs: tabs,
          selected: selected,
          onSelected: onSelected,
          onReleased: onReleased,
          small: small,
          height: height,
        ),
      ],
    );
  }
}

/// The three tabs: the open one a solid pill with icon and label, the
/// others icons; shrunk, the pill keeps only its icon. One pill slides
/// under the icons: a finger held on the bar carries it, and on release it
/// lands on the nearest tab.
class MonoTabs extends StatefulWidget {
  const MonoTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
    this.small = 0,
    this.height = MonoDockSize.bar,
    this.onReleased,
  });

  final List<MonoTab> tabs;
  final int selected;
  final ValueChanged<int> onSelected;
  final double small;
  final double height;

  /// Called when a finger leaves the bar, after a tap or a slide.
  final VoidCallback? onReleased;

  @override
  State<MonoTabs> createState() => _MonoTabsState();
}

class _MonoTabsState extends State<MonoTabs> with TickerProviderStateMixin {
  late final AnimationController _lift = AnimationController.unbounded(
    vsync: this,
  );

  /// Where the pill stands, as a tab index that may fall between two.
  late final AnimationController _at = AnimationController.unbounded(
    vsync: this,
    value: widget.selected.toDouble(),
  );

  bool _dragging = false;

  /// Where the finger came down, and where the pill stood then: a slide
  /// moves the pill by as much as the finger moved.
  double _grab = 0;
  double _grabAt = 0;

  int get _last => widget.tabs.length - 1;

  double get _inactive => lerpDouble(
    MonoDockSize.inactive,
    MonoDockSize.inactiveSmall,
    widget.small,
  )!;

  bool get _still => monoStill(context);

  void _hold(bool on) {
    if (_still) {
      _lift.value = 0;
      return;
    }
    _lift.animateWith(
      SpringSimulation(monoSettle, _lift.value, on ? 1 : 0, _lift.velocity),
    );
  }

  void _settle(double target, [double velocity = 0]) {
    if (_still) {
      _at.value = target;
      return;
    }
    _at.animateWith(SpringSimulation(monoSettle, _at.value, target, velocity));
  }

  @override
  void didUpdateWidget(MonoTabs old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected && !_dragging) {
      _settle(widget.selected.toDouble());
    }
  }

  /// The tab under [x] as the bar stands now.
  int _indexAt(double x, double width) {
    final inactive = _inactive;
    final active = width - MonoDockSize.pad * 2 - inactive * _last;
    var left = MonoDockSize.pad;
    for (var i = 0; i < widget.tabs.length; i++) {
      final w = lerpDouble(inactive, active, _weight(i))!;
      if (x < left + w) return i;
      left += w;
    }
    return _last;
  }

  /// How much of the pill is over tab [i]: 1 under it, 0 one tab away.
  double _weight(int i) => (1 - (_at.value - i).abs()).clamp(0.0, 1.0);

  int _shownIndex() => _at.value.round().clamp(0, _last);

  void _down(double x, double width) {
    _at.stop();
    _hold(true);
    _grab = x;
    _grabAt = _at.value;
  }

  void _move(double x) {
    _dragging = true;
    final before = _shownIndex();
    _at.value = (_grabAt + (x - _grab) / _inactive).clamp(0.0, _last * 1.0);
    if (_shownIndex() != before) Haptics.selection();
  }

  void _end(double velocity) {
    final v = velocity / _inactive;
    // A flick carries the pill on by a little.
    final aim = (_at.value + v * 0.08).round().clamp(0, _last);
    _dragging = false;
    _hold(false);
    _settle(aim.toDouble(), v);
    widget.onReleased?.call();
    if (aim != widget.selected) widget.onSelected(aim);
  }

  void _tap(int i) {
    _dragging = false;
    _hold(false);
    _settle(i.toDouble());
    widget.onReleased?.call();
    if (i != widget.selected) {
      Haptics.selection();
      widget.onSelected(i);
    }
  }

  @override
  void dispose() {
    _lift.dispose();
    _at.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final slot = widget.height - MonoDockSize.pad * 2;
    final label = (1 - widget.small * 1.6).clamp(0.0, 1.0);
    final icon = lerpDouble(22, 24, widget.small.clamp(0.0, 1.0))!;
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final inactive = _inactive;
        final active = width - MonoDockSize.pad * 2 - inactive * _last;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // The slide counts from where the finger came down.
          dragStartBehavior: DragStartBehavior.down,
          onTapDown: (d) => _down(d.localPosition.dx, width),
          onTapUp: (d) => _tap(_indexAt(d.localPosition.dx, width)),
          onTapCancel: () {
            if (!_dragging) _hold(false);
          },
          onHorizontalDragStart: (d) => _down(d.localPosition.dx, width),
          onHorizontalDragUpdate: (d) => _move(d.localPosition.dx),
          onHorizontalDragEnd: (d) => _end(d.primaryVelocity ?? 0),
          onHorizontalDragCancel: () => _end(0),
          child: MonoGlass(
            backdrop: false,
            radius: widget.height / 2,
            child: Padding(
              padding: const EdgeInsets.all(MonoDockSize.pad),
              child: AnimatedBuilder(
                animation: Listenable.merge([_at, _lift]),
                builder: (context, _) {
                  final lift = _lift.value.clamp(0.0, 1.0);
                  // The pill keeps its width and slides; the tabs make room
                  // for it as it passes, so their widths always add up.
                  final pillLeft = _at.value.clamp(0.0, _last * 1.0) * inactive;
                  final grow = 1 + lift * 0.04;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: pillLeft,
                        top: 0,
                        width: active,
                        height: slot,
                        child: Transform.scale(
                          scale: grow,
                          child: DecoratedBox(
                            key: const ValueKey('mono-tab-pill'),
                            decoration: BoxDecoration(
                              color: t.solid,
                              borderRadius: BorderRadius.circular(slot / 2),
                              boxShadow: lift > 0.01
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.2 * lift,
                                        ),
                                        blurRadius: 16 * lift,
                                        offset: Offset(0, 4 * lift),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      Row(
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
                                  on: _weight(i),
                                  width: lerpDouble(
                                    inactive,
                                    active,
                                    _weight(i),
                                  )!,
                                  height: slot,
                                  label: label,
                                  icon: icon,
                                  tokens: t,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.tab,
    required this.on,
    required this.width,
    required this.height,
    required this.label,
    required this.icon,
    required this.tokens,
  });

  final MonoTab tab;

  /// How much of the pill is under this tab, 0 to 1.
  final double on;
  final double width;
  final double height;

  /// How much of the label shows: none once shrunk.
  final double label;
  final double icon;
  final MonoTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final color = Color.lerp(t.ink2, t.onSolid, on)!;
    // Only the tab the pill mostly covers shows its label, so two never
    // stand on the pill at once.
    final shown = label * ((on - 0.5) * 2).clamp(0.0, 1.0);
    return SizedBox(
      width: math.max(0, width),
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconTheme.merge(
              data: IconThemeData(size: icon, color: color),
              child: tab.icon,
            ),
            if (shown > 0.01) ...[
              SizedBox(width: 7 * shown),
              Flexible(
                child: Opacity(
                  opacity: shown,
                  child: Text(
                    tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: MonoType.inter(14, 18, FontWeight.w600, color),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Beside the search while a training runs: its time, or the rest with a
/// ring that runs down. A tap leads back to the training.
class _LivePill extends StatefulWidget {
  const _LivePill({required this.height, required this.onTap});

  final double height;
  final VoidCallback onTap;

  @override
  State<_LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<_LivePill> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final l10n = AppLocalizations.of(context);
    final training = AppScope.of(context).training;
    final session = training.active;
    if (session == null) return const SizedBox.shrink();
    final rest = training.restLeft;
    final elapsed = training.now.difference(session.start);
    final restTotal = rest == null
        ? null
        : math.max(
            training.restLength?.inMilliseconds ?? 0,
            rest.inMilliseconds,
          );
    final label = rest == null
        ? l10n.trainingLiveTime(clockText(elapsed))
        : l10n.trainingLiveRest(clockText(rest));
    return Semantics(
      container: true,
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: MonoPress(
          onTap: widget.onTap,
          squash: 0.04,
          child: MonoGlass(
            radius: widget.height / 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: 22,
                  child: rest == null
                      ? Icon(
                          Icons.fitness_center_rounded,
                          size: 19,
                          color: t.recovery,
                        )
                      : CustomPaint(
                          painter: _RestRing(
                            share: restTotal == null || restTotal == 0
                                ? 0
                                : rest.inMilliseconds / restTotal,
                            color: t.recovery,
                            track: t.fill,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Text(
                  clockText(rest ?? elapsed),
                  style: MonoType.inter(15, 20, FontWeight.w600, t.ink)
                      .copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestRing extends CustomPainter {
  const _RestRing({
    required this.share,
    required this.color,
    required this.track,
  });

  final double share;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * share.clamp(0.0, 1.0),
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_RestRing old) =>
      old.share != share || old.color != color || old.track != track;
}
