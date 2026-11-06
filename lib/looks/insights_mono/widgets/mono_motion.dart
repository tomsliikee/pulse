import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

/// Whether effects are off: with reduce-motion on, values appear at once.
bool monoStill(BuildContext context) => MediaQuery.disableAnimationsOf(context);

/// The spring spatial things settle with; it overshoots a little.
const SpringDescription monoSpring = SpringDescription(
  mass: 1,
  stiffness: 520,
  damping: 17,
);

/// Plays once when first built: [builder] gets 0 to 1 over [duration] on
/// `easeOutCubic`, or 1 at once when effects are off.
class MonoDrawIn extends StatelessWidget {
  const MonoDrawIn({
    super.key,
    required this.builder,
    this.duration = const Duration(milliseconds: 1300),
    this.delay = Duration.zero,
  });

  final Widget Function(BuildContext context, double t) builder;
  final Duration duration;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (monoStill(context)) return builder(context, 1);
    return _Delayed(
      delay: delay,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => builder(context, t),
      ),
    );
  }
}

class _Delayed extends StatefulWidget {
  const _Delayed({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_Delayed> createState() => _DelayedState();
}

class _DelayedState extends State<_Delayed> {
  late bool _go = widget.delay == Duration.zero;

  @override
  void initState() {
    super.initState();
    if (!_go) {
      Future<void>.delayed(widget.delay, () {
        if (mounted) setState(() => _go = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) =>
      _go ? widget.child : Opacity(opacity: 0, child: widget.child);
}

/// The part of [t] that belongs to item [i] of [n] when they start one after
/// another: [stagger] is the share of the whole spent on the starts.
double monoStaggered(double t, int i, int n, {double stagger = 0.4}) {
  if (n <= 1) return t;
  final start = stagger * i / (n - 1);
  return ((t - start) / (1 - stagger)).clamp(0.0, 1.0);
}

/// Squashes its child while pressed and lets it spring back past its size.
class MonoPress extends StatefulWidget {
  const MonoPress({
    super.key,
    required this.child,
    this.onTap,
    this.squash = 0.03,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// How much wider the child gets; it gets about twice as much flatter.
  final double squash;

  @override
  State<MonoPress> createState() => _MonoPressState();
}

class _MonoPressState extends State<MonoPress>
    with SingleTickerProviderStateMixin {
  // 0 is at rest, 1 fully pressed.
  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );

  void _to(double target) {
    if (monoStill(context)) {
      _c.value = target;
      return;
    }
    _c.animateWith(SpringSimulation(monoSpring, _c.value, target, _c.velocity));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _to(1),
      onTapUp: widget.onTap == null ? null : (_) => _to(0),
      onTapCancel: widget.onTap == null ? null : () => _to(0),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) => Transform.scale(
          scaleX: 1 + widget.squash * _c.value,
          scaleY: 1 - widget.squash * 1.6 * _c.value,
          child: child,
        ),
      ),
    );
  }
}

/// Lets its child rise in with a stagger the first time the page is opened
/// in a session.
class MonoRise extends StatefulWidget {
  const MonoRise({
    super.key,
    required this.order,
    required this.page,
    required this.child,
  });

  final int order;

  /// Names the page; each page rises in once per session.
  final String page;
  final Widget child;

  static final Set<String> _seen = {};

  @override
  State<MonoRise> createState() => _MonoRiseState();
}

class _MonoRiseState extends State<MonoRise>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final bool _play = MonoRise._seen.add('${widget.page}#${widget.order}');
  bool _started = false;

  @override
  void initState() {
    super.initState();
    if (!_play) _c.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!_play || monoStill(context)) {
      _c.value = 1;
      return;
    }
    Future<void>.delayed(Duration(milliseconds: 40 * widget.order), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, 22 * (1 - curve.value)),
          child: child,
        ),
      ),
    );
  }
}
