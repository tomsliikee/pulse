import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

/// A route that keeps the dock in view above it: the search panel, which
/// belongs to the dock.
mixin MonoDockKeeps on Route<dynamic> {}

/// A page that hides the dock, such as the live screen of a training, which
/// has its own controls at the bottom.
mixin MonoNoDock on Route<dynamic> {}

/// The state of the dock of the Insights looks: which tab is open, whether
/// the search is open, how far it is shrunk, and whether the page on top
/// wants it at all. The dock floats above every page
/// of the navigator, so it lives above it as well.
class MonoDockController extends ChangeNotifier {
  int _tab = 0;
  int _homes = 0;
  bool _searchOpen = false;
  bool _routeShows = true;
  bool _liveOnTop = false;
  int _depth = 0;

  /// The page of the shell that is open: 0 Insights, 1 Training, 2 Longevity.
  int get tab => _tab;

  /// Whether the dock is shown: the shell is there, the page on top keeps it.
  bool get visible => _homes > 0 && _routeShows;
  bool get searchOpen => _searchOpen;

  /// How far the dock is shrunk, 0 to 1: while a page scrolls it follows
  /// the finger, when the scroll ends it settles on either end.
  double get shrink => _shrink;
  double _shrink = 0;

  /// Whether [shrink] is on its way to an end rather than following.
  bool get shrinkSettling => _settling;
  bool _settling = true;

  /// Tells the dock that [shrink] changed; apart from the other listeners,
  /// so a scroll does not rebuild every page that asks for the dock.
  Listenable get shrinkChanges => _shrinkChanges;
  final ValueNotifier<int> _shrinkChanges = ValueNotifier(0);

  /// Whether the dock is small or on its way there.
  bool get shrunk => _shrink >= 0.5;

  /// Whether the live screen of a training is the page on top.
  bool get liveOnTop => _liveOnTop;

  /// The live screen, where it lies somewhere in the stack.
  Route<dynamic>? get liveRoute => _liveRoute;
  Route<dynamic>? _liveRoute;

  /// How many pages lie on the shell; zero on the shell itself.
  int get depth => _depth;

  /// Opens the search, from wherever: set by the dock.
  VoidCallback? openSearch;

  bool _notifyPending = false;

  /// Changes and tells the listeners; while a frame is being built, as when
  /// the navigator pushes its first route, only after it.
  void _set(VoidCallback change) {
    change();
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase != SchedulerPhase.persistentCallbacks) {
      notifyListeners();
      return;
    }
    if (_notifyPending) return;
    _notifyPending = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyPending = false;
      if (!_disposed) notifyListeners();
    });
  }

  void selectTab(int index) {
    if (index == _tab) return;
    _set(() => _tab = index);
  }

  void attachHome() => _set(() => _homes++);
  void detachHome() => _set(() => _homes--);

  set searchOpen(bool value) {
    if (value == _searchOpen) return;
    _set(() => _searchOpen = value);
  }

  /// Settles the dock small or at full size.
  set shrunk(bool value) {
    final target = value ? 1.0 : 0.0;
    if (target == _shrink && _settling) return;
    _shrink = target;
    _settling = true;
    _shrinkChanges.value++;
  }

  /// Follows a scroll of [delta], a share of the way between the sizes.
  void shrinkBy(double delta) {
    final next = (_shrink + delta).clamp(0.0, 1.0);
    if (next == _shrink && !_settling) return;
    _shrink = next;
    _settling = false;
    _shrinkChanges.value++;
  }

  /// Settles on the end the dock is nearer to, when a scroll ends.
  void settleShrink() {
    if (_settling) return;
    shrunk = _shrink >= 0.5;
  }

  void _top(Route<dynamic>? route, int depth, Route<dynamic>? liveRoute) {
    _liveRoute = liveRoute;
    final shows =
        route == null ||
        route is MonoDockKeeps ||
        (route is PageRoute && route is! MonoNoDock);
    final live = route is MonoNoDock;
    if (shows == _routeShows && live == _liveOnTop && depth == _depth) return;
    // A page that comes or goes starts with the dock at full size.
    shrunk = false;
    _set(() {
      _routeShows = shows;
      _liveOnTop = live;
      _depth = depth;
    });
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _shrinkChanges.dispose();
    super.dispose();
  }
}

/// Tells the dock which route is on top of the navigator.
class MonoDockObserver extends NavigatorObserver {
  MonoDockObserver(this.controller);

  final MonoDockController controller;
  final List<Route<dynamic>> _stack = [];

  void _changed() {
    final pages = _stack.where((r) => r is PageRoute && r is! MonoDockKeeps);
    controller._top(
      _stack.lastOrNull,
      pages.isEmpty ? 0 : pages.length - 1,
      _stack.whereType<MonoNoDock>().lastOrNull,
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route);
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final at = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (at >= 0 && newRoute != null) {
      _stack[at] = newRoute;
    } else if (newRoute != null) {
      _stack.add(newRoute);
    }
    _changed();
  }
}

/// Hands the controller of the dock to the pages beneath it.
class MonoDockScope extends InheritedNotifier<MonoDockController> {
  const MonoDockScope({
    super.key,
    required MonoDockController controller,
    required super.child,
  }) : super(notifier: controller);

  /// The controller, or null outside the Insights looks.
  static MonoDockController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MonoDockScope>()?.notifier;

  /// The controller without listening to it.
  static MonoDockController? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<MonoDockScope>()?.notifier;
}
