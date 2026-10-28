import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../theme/app_motion.dart';

/// Lets [child] come in when it is first built: it appears, rises and grows
/// into place on a spring. [order] staggers neighbours, so a page wakes up
/// from the top down. Where the system asks for no animations the child is
/// simply there.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.order = 0,
    this.animate = true,
  });

  final Widget child;

  /// The place among the things that enter together; each waits a little
  /// longer than the one before it.
  final int order;

  /// False for something that is not new on the page, such as a row of a
  /// list that is built when it scrolls into view. Read once, when the
  /// widget is first built.
  final bool animate;

  /// How long each place waits for the one before it.
  static const Duration stagger = Duration(milliseconds: 45);

  /// Places after this one enter together with it, so the end of a long
  /// page does not come in seconds late.
  static const int staggered = 10;

  static const double _rise = 24;
  static const double _scale = 0.92;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> {
  Timer? _wait;
  bool _shown = false;
  late final bool _animate;

  /// The child moves along when a new visit restarts the spring, and keeps
  /// its state and its build on the way.
  final GlobalKey _child = GlobalKey();
  int? _visit;

  @override
  void initState() {
    super.initState();
    _animate = widget.animate;
    _start();
  }

  void _start() {
    final place = widget.order.clamp(0, Entrance.staggered);
    _wait?.cancel();
    if (place == 0 || !_animate) {
      _shown = true;
    } else {
      _shown = false;
      _wait = Timer(Entrance.stagger * place, () {
        if (mounted) setState(() => _shown = true);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visit = PageVisits.of(context);
    if (_visit != null && _visit != visit) _start();
    _visit = visit;
  }

  @override
  void dispose() {
    _wait?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Where nothing is to move, the child is there from the first frame.
    final still = !_animate || MediaQuery.disableAnimationsOf(context);
    return SingleMotionBuilder(
      key: ValueKey(_visit),
      from: still ? 1 : 0,
      value: _shown || still ? 1 : 0,
      motion: AppMotion.spatial,
      // The same widgets around the child all along, so it keeps its state
      // when it has arrived. It is hidden until its turn and then there at
      // once, rising and growing: an opacity in between would draw every
      // tile into a layer of its own in each frame, too much for a page of
      // them at the display's rate.
      builder: (context, t, child) => Opacity(
        opacity: t <= 0 ? 0 : 1,
        child: Transform.translate(
          offset: Offset(0, Entrance._rise * (1 - t)),
          child: Transform.scale(
            scale: Entrance._scale + (1 - Entrance._scale) * t,
            child: child,
          ),
        ),
      ),
      child: KeyedSubtree(key: _child, child: widget.child),
    );
  }
}

/// How often the page around has been opened. A page that is kept while
/// another is shown is not built anew when it comes back, so what comes in
/// from nothing on it, tiles, bars and numbers, starts over by this count.
class PageVisits extends InheritedWidget {
  const PageVisits({super.key, required this.visit, required super.child});

  final int visit;

  /// The count of the page around [context]; 0 outside a kept page.
  static int of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PageVisits>()?.visit ?? 0;

  @override
  bool updateShouldNotify(PageVisits oldWidget) => oldWidget.visit != visit;
}

/// [children] with an [Entrance] each, one after the other from [from] on.
List<Widget> staggered(Iterable<Widget> children, {int from = 0}) => [
  for (final (index, child) in children.indexed)
    Entrance(order: from + index, child: child),
];

/// Knows whether the page it wraps has just been opened. A long list uses
/// it to let the rows it starts with come in, and not the ones that are
/// built later while it scrolls.
class EntranceGate extends StatefulWidget {
  const EntranceGate({super.key, required this.builder});

  /// [opening] is true during the first frame of the page only.
  final Widget Function(BuildContext context, bool Function() opening) builder;

  @override
  State<EntranceGate> createState() => _EntranceGateState();
}

class _EntranceGateState extends State<EntranceGate> {
  bool _opening = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _opening = false);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, () => _opening);
}
