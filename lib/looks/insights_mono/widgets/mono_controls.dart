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

/// An on/off switch in the look: a capsule that fills with ink when on and
/// a round knob that springs across. Draggable and tappable.
class MonoSwitch extends StatefulWidget {
  const MonoSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// For the screen reader, where the switch stands without a text beside
  /// it.
  final String? label;

  @override
  State<MonoSwitch> createState() => _MonoSwitchState();
}

class _MonoSwitchState extends State<MonoSwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
    value: widget.value ? 1 : 0,
  );
  double? _drag;

  static const double _w = 52;
  static const double _h = 32;
  static const double _knob = 24;

  @override
  void didUpdateWidget(MonoSwitch old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _drag == null) _go(widget.value);
  }

  void _go(bool on) {
    final target = on ? 1.0 : 0.0;
    if (monoStill(context)) {
      _c.value = target;
      return;
    }
    _c.animateWith(SpringSimulation(monoSpring, _c.value, target, _c.velocity));
  }

  void _set(bool on) {
    final change = widget.onChanged;
    if (change == null) return;
    _go(on);
    if (on != widget.value) change(on);
    // After the change, so switching the haptics on is felt.
    Haptics.selection();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final enabled = widget.onChanged != null;
    return Semantics(
      toggled: widget.value,
      enabled: enabled,
      label: widget.label,
      onTap: enabled ? () => _set(!widget.value) : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => _set(!widget.value) : null,
          onHorizontalDragStart: enabled
              ? (_) => _drag = _c.value.clamp(0.0, 1.0)
              : null,
          onHorizontalDragUpdate: enabled
              ? (d) {
                  _drag = ((_drag ?? 0) + d.delta.dx / (_w - _h)).clamp(0, 1);
                  _c.value = _drag!;
                }
              : null,
          onHorizontalDragEnd: enabled
              ? (_) {
                  final on = (_drag ?? 0) > 0.5;
                  _drag = null;
                  _set(on);
                }
              : null,
          child: SizedBox(
            width: _w + 4,
            height: 48,
            child: Center(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final p = _c.value;
                  final f = p.clamp(0.0, 1.0);
                  final squash = _drag != null ? 1.18 : 1.0;
                  return Opacity(
                    opacity: enabled ? 1 : 0.4,
                    child: Container(
                      width: _w,
                      height: _h,
                      padding: const EdgeInsets.all((_h - _knob) / 2),
                      decoration: BoxDecoration(
                        color: Color.lerp(t.fill, t.solid, f),
                        borderRadius: BorderRadius.circular(_h / 2),
                      ),
                      child: Align(
                        alignment: Alignment(-1 + 2 * p, 0),
                        child: Container(
                          width: _knob * squash,
                          height: _knob,
                          decoration: BoxDecoration(
                            color: Color.lerp(t.card, t.onSolid, f),
                            borderRadius: BorderRadius.circular(_knob / 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.16),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
