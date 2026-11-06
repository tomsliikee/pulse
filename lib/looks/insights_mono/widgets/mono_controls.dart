import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/haptics.dart';
import '../theme/mono_tokens.dart';
import '../theme/mono_type.dart';
import 'mono_motion.dart';

/// A round action: solid where it is active or the main action, fill where
/// it is not. It squashes while pressed.
class MonoRoundButton extends StatelessWidget {
  const MonoRoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.size = 62,
    this.showLabel = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? t.solid : t.fill,
      ),
      child: Icon(icon, size: 26, color: active ? t.onSolid : t.ink),
    );
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: MonoPress(
          onTap: onTap == null
              ? null
              : () {
                  Haptics.tap();
                  onTap!();
                },
          squash: 0.06,
          child: showLabel
              ? SizedBox(
                  width: size + 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      circle,
                      const SizedBox(height: 8),
                      Text(
                        label,
                        style: MonoType.label(t),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : circle,
        ),
      ),
    );
  }
}

/// A segmented control with a thumb that slides to the chosen segment. The
/// thumb can also be dragged: it lifts while held, follows the finger and
/// springs to the nearest segment when let go.
class MonoSegmented extends StatefulWidget {
  const MonoSegmented({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  State<MonoSegmented> createState() => _MonoSegmentedState();
}

class _MonoSegmentedState extends State<MonoSegmented>
    with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
    value: widget.selected.toDouble(),
  );
  late final AnimationController _lift = AnimationController.unbounded(
    vsync: this,
  );
  bool _dragging = false;
  int _near = 0;

  void _spring(AnimationController c, double target) {
    if (monoStill(context)) {
      c.value = target;
      return;
    }
    c.animateWith(SpringSimulation(monoSpring, c.value, target, c.velocity));
  }

  @override
  void didUpdateWidget(MonoSegmented old) {
    super.didUpdateWidget(old);
    if (old.selected == widget.selected || _dragging) return;
    _spring(_c, widget.selected.toDouble());
  }

  void _start(double x, double w) {
    _dragging = true;
    _near = widget.selected;
    _spring(_lift, 1);
    _move(x, w);
  }

  void _move(double x, double w) {
    final n = widget.labels.length;
    _c.value = (x / w - 0.5).clamp(0.0, n - 1.0);
    final near = _c.value.round();
    if (near != _near) {
      _near = near;
      Haptics.selection();
    }
  }

  void _end() {
    if (!_dragging) return;
    _dragging = false;
    _spring(_lift, 0);
    final i = _c.value.round();
    _spring(_c, i.toDouble());
    if (i != widget.selected) widget.onChanged(i);
  }

  @override
  void dispose() {
    _c.dispose();
    _lift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final n = widget.labels.length;
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / n;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (d) => _start(d.localPosition.dx, w),
            onHorizontalDragUpdate: (d) => _move(d.localPosition.dx, w),
            onHorizontalDragEnd: (_) => _end(),
            onHorizontalDragCancel: _end,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([_c, _lift]),
                  builder: (context, _) {
                    final lift = _lift.value.clamp(0.0, 1.2);
                    return Positioned(
                      left: w * _c.value,
                      top: 0,
                      bottom: 0,
                      width: w,
                      child: Transform.scale(
                        scale: 1 + 0.08 * lift,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: t.card,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: 0.12 + 0.12 * lift,
                                ),
                                blurRadius: 3 + 12 * lift,
                                offset: Offset(0, 1 + 4 * lift),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Row(
                  children: [
                    for (var i = 0; i < n; i++)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: i == widget.selected,
                          label: widget.labels[i],
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (i == widget.selected) return;
                              Haptics.selection();
                              widget.onChanged(i);
                            },
                            child: Center(
                              child: Text(
                                widget.labels[i],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MonoType.inter(
                                  14,
                                  18,
                                  FontWeight.w600,
                                  i == widget.selected ? t.ink : t.ink2,
                                ),
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
        },
      ),
    );
  }
}

/// A round icon button of a page header.
class MonoCircleButton extends StatelessWidget {
  const MonoCircleButton({
    super.key,
    required this.icon,
    required this.label,
    required this.fill,
    required this.color,
    required this.onTap,
    this.size = 48,
  });

  final IconData icon;
  final String label;
  final Color fill;
  final Color color;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: MonoPress(
          onTap: () {
            Haptics.tap();
            onTap();
          },
          squash: 0.08,
          child: AnimatedContainer(
            duration: monoStill(context)
                ? Duration.zero
                : const Duration(milliseconds: 240),
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: fill),
            child: Icon(icon, size: size / 2, color: color),
          ),
        ),
      ),
    );
  }
}
