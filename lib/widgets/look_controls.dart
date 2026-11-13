import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../app/haptics.dart';
import '../looks/insights_mono/theme/mono_tokens.dart';
import '../looks/insights_mono/theme/mono_type.dart';
import '../looks/insights_mono/widgets/mono_controls.dart';
import '../looks/insights_mono/widgets/mono_motion.dart';
import '../theme/pulse_look.dart';

/// An on/off switch: Material's in the standard look, the look's own in the
/// Insights looks.
class LookSwitch extends StatelessWidget {
  const LookSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => PulseLook.monoOf(context)
      ? MonoSwitch(value: value, onChanged: onChanged)
      : Switch(value: value, onChanged: onChanged);
}

/// A slider of steps: the expressive one of the standard look, or in the
/// Insights looks a capsule track that fills with ink and a round thumb,
/// with a tick of haptics on every step.
class LookSlider extends StatelessWidget {
  const LookSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    if (!PulseLook.monoOf(context)) {
      return M3ESlider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        decoration: M3ESliderDecoration(
          haptic: Haptics.widget,
          hapticConfig: Haptics.slider,
        ),
        onChanged: onChanged,
      );
    }
    return _MonoSlider(
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      onChanged: onChanged,
    );
  }
}

class _MonoSlider extends StatefulWidget {
  const _MonoSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  State<_MonoSlider> createState() => _MonoSliderState();
}

class _MonoSliderState extends State<_MonoSlider> {
  bool _held = false;

  double _at(double dx, double width) {
    const pad = 14.0;
    final share = ((dx - pad) / (width - pad * 2)).clamp(0.0, 1.0);
    final steps = widget.divisions <= 0 ? 1 : widget.divisions;
    final step = (share * steps).round();
    return widget.min + (widget.max - widget.min) * step / steps;
  }

  void _move(double dx, double width) {
    final next = _at(dx, width);
    if (next == widget.value) return;
    Haptics.selection();
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = MonoTokens.of(context);
    final span = widget.max - widget.min;
    final share = span <= 0
        ? 0.0
        : ((widget.value - widget.min) / span).clamp(0.0, 1.0);
    final step = span / (widget.divisions <= 0 ? 1 : widget.divisions);
    String shown(double v) =>
        v.clamp(widget.min, widget.max).toStringAsFixed(0);
    return Semantics(
      slider: true,
      value: shown(widget.value),
      increasedValue: shown(widget.value + step),
      decreasedValue: shown(widget.value - step),
      onIncrease: () => widget.onChanged(
        (widget.value + span / widget.divisions).clamp(widget.min, widget.max),
      ),
      onDecrease: () => widget.onChanged(
        (widget.value - span / widget.divisions).clamp(widget.min, widget.max),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _move(d.localPosition.dx, width),
            onHorizontalDragStart: (d) {
              setState(() => _held = true);
              _move(d.localPosition.dx, width);
            },
            onHorizontalDragUpdate: (d) => _move(d.localPosition.dx, width),
            onHorizontalDragEnd: (_) => setState(() => _held = false),
            onHorizontalDragCancel: () => setState(() => _held = false),
            child: SizedBox(
              height: 48,
              width: width,
              child: CustomPaint(
                painter: _SliderPainter(
                  share: share,
                  fill: t.solid,
                  track: t.fill,
                  thumb: t.solid,
                  ring: t.card,
                  held: _held,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SliderPainter extends CustomPainter {
  const _SliderPainter({
    required this.share,
    required this.fill,
    required this.track,
    required this.thumb,
    required this.ring,
    required this.held,
  });

  final double share;
  final Color fill;
  final Color track;
  final Color thumb;
  final Color ring;
  final bool held;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 14.0;
    const h = 10.0;
    final y = size.height / 2;
    final left = pad;
    final right = size.width - pad;
    final x = left + (right - left) * share;
    canvas.drawRRect(
      RRect.fromLTRBR(
        left - 4,
        y - h / 2,
        right + 4,
        y + h / 2,
        const Radius.circular(h / 2),
      ),
      Paint()..color = track,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
        left - 4,
        y - h / 2,
        x,
        y + h / 2,
        const Radius.circular(h / 2),
      ),
      Paint()..color = fill,
    );
    final r = held ? 13.0 : 11.0;
    canvas.drawCircle(Offset(x, y), r + 3, Paint()..color = ring);
    canvas.drawCircle(Offset(x, y), r, Paint()..color = thumb);
  }

  @override
  bool shouldRepaint(_SliderPainter old) =>
      old.share != share ||
      old.held != held ||
      old.fill != fill ||
      old.track != track ||
      old.thumb != thumb ||
      old.ring != ring;
}

/// A list of choices: the segmented column of the standard look, or in the
/// Insights looks rows of the look on one card, separated by air.
class LookSegmentedColumn extends StatelessWidget {
  const LookSegmentedColumn({
    super.key,
    required this.children,
    this.onTap,
    this.color,
  });

  final List<M3EListItem> children;
  final void Function(int index)? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (!PulseLook.monoOf(context)) {
      return M3ESegmentedColumn(
        color: color,
        haptic: Haptics.widget,
        onTap: onTap,
        children: children,
      );
    }
    final t = MonoTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, item) in children.indexed)
            MonoPress(
              squash: 0.012,
              onTap: onTap == null
                  ? null
                  : () {
                      Haptics.selection();
                      onTap!(i);
                    },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  child: IconTheme.merge(
                    data: IconThemeData(color: t.ink, size: 22),
                    child: Row(
                      children: [
                        if (item.leading != null) ...[
                          item.leading!,
                          const SizedBox(width: 14),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DefaultTextStyle.merge(
                                style: MonoType.inter(
                                  16,
                                  22,
                                  FontWeight.w500,
                                  t.ink,
                                ),
                                child: item.headline,
                              ),
                              if (item.supportingText != null)
                                DefaultTextStyle.merge(
                                  style: MonoType.label(t),
                                  child: item.supportingText!,
                                ),
                            ],
                          ),
                        ),
                        if (item.trailing != null) ...[
                          const SizedBox(width: 12),
                          DefaultTextStyle.merge(
                            style: MonoType.inter(
                              15,
                              20,
                              FontWeight.w600,
                              t.ink,
                            ),
                            child: item.trailing!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
