import 'package:flutter/gestures.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../app/layout.dart';
import '../../data/heart_day.dart';
import '../../data/models.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_type.dart';
import '../../theme/page_accent.dart';
import '../../widgets/floating_surface.dart';
import '../../widgets/line_chart.dart';

/// The heart rate of a day from its first measurement to its last, reaching
/// the edges of the surface it is on, with the full hours written along its
/// foot. Held, it shows a bar that follows the finger from measurement to
/// measurement, and a pill above the surface says the rate and the time
/// there.
class HeartCurve extends StatefulWidget {
  const HeartCurve({
    super.key,
    required this.samples,
    required this.day,
    this.onTap,
  });

  /// At least two, in the order of the day.
  final List<HeartSample> samples;

  /// The line draws in again when this changes.
  final DateTime day;

  /// Called with the curve's rectangle on screen when it is tapped.
  final void Function(Rect origin)? onTap;

  /// Room above the line, so a peak stays clear of the surface's corners.
  static const double _head = 16;

  /// Room below the line for the hours.
  static const double _foot = 30;

  /// How long a finger rests before the bar appears: short enough to feel
  /// direct, long enough for a scroll to have started first.
  static const Duration _hold = Duration(milliseconds: 300);

  @override
  State<HeartCurve> createState() => _HeartCurveState();
}

/// What the finger is on: the sample, and the point above it at the top of
/// the curve, in the overlay's coordinates.
typedef _Pick = ({int index, Offset anchor});

class _HeartCurveState extends State<HeartCurve> {
  final _overlay = OverlayPortalController();

  /// Kept after the finger lifts, so the pill leaves with its text.
  final _pick = ValueNotifier<_Pick?>(null);
  final _held = ValueNotifier<bool>(false);

  late List<double> _positions = curvePositions(widget.samples);

  @override
  void didUpdateWidget(HeartCurve oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.samples != widget.samples) {
      _positions = curvePositions(widget.samples);
      // The sample under the finger may be gone.
      _held.value = false;
      _pick.value = null;
    }
  }

  @override
  void dispose() {
    _pick.dispose();
    _held.dispose();
    super.dispose();
  }

  void _start(LongPressStartDetails details) {
    Haptics.lift();
    _overlay.show();
    _move(details.localPosition.dx, silent: true);
    _held.value = true;
  }

  void _move(double dx, {bool silent = false}) {
    final box = context.findRenderObject();
    final overlay = Overlay.of(context).context.findRenderObject();
    if (box is! RenderBox || overlay is! RenderBox || !box.hasSize) return;
    final index = indexNear(widget.samples, dx / box.size.width);
    if (index == _pick.value?.index) return;
    if (!silent) Haptics.selection();
    _pick.value = (
      index: index,
      anchor: box.localToGlobal(
        Offset(_positions[index] * box.size.width, 0),
        ancestor: overlay,
      ),
    );
  }

  void _end() => _held.value = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = PageAccent.colorsOf(context).accent;
    final samples = widget.samples;
    final onTap = widget.onTap;
    final labelStyle = AppType.of(context).label(
      theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
    );
    final first = samples.first.minuteOfDay;
    final span = samples.last.minuteOfDay - first;
    final summary = heartSummary(samples);

    final curve = Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: HeartCurve._head,
            bottom: HeartCurve._foot,
          ),
          child: LineChart(
            key: ValueKey(widget.day),
            values: [for (final sample in samples) sample.bpm.toDouble()],
            positions: _positions,
            color: accent,
            height: null,
          ),
        ),
        // Each hour centred on where it is on the line.
        for (final minute in hourMarks(first, samples.last.minuteOfDay))
          Align(
            alignment: Alignment(2 * (minute - first) / span - 1, 1),
            child: FractionalTranslation(
              // Align keeps the label inside; this puts its middle on the
              // hour instead.
              translation: Offset((minute - first) / span - 0.5, 0),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(formatClock(minute), style: labelStyle),
              ),
            ),
          ),
        if (summary != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _BarPainter(
                  samples: samples,
                  positions: _positions,
                  low: summary.low,
                  high: summary.high,
                  pick: _pick,
                  held: _held,
                  bar: scheme.onSurfaceVariant,
                  dot: accent,
                  ring: scheme.surfaceBright,
                ),
              ),
            ),
          ),
      ],
    );

    return OverlayPortal(
      controller: _overlay,
      overlayChildBuilder: (_) =>
          _Pill(pick: _pick, held: _held, samples: samples),
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          // Only after the hold does this take the finger, so a scroll that
          // starts on the curve stays a scroll.
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(duration: HeartCurve._hold),
                (recognizer) => recognizer
                  ..onLongPressStart = _start
                  ..onLongPressMoveUpdate = ((details) =>
                      _move(details.localPosition.dx))
                  ..onLongPressEnd = ((_) => _end())
                  ..onLongPressCancel = _end,
              ),
        },
        child: onTap == null
            ? curve
            : InkWell(
                onTap: () {
                  final origin = globalRectOf(context);
                  if (origin != null) onTap(origin);
                },
                child: curve,
              ),
      ),
    );
  }
}

/// The bar under the finger and the dot where it meets the line.
class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.samples,
    required this.positions,
    required this.low,
    required this.high,
    required this.pick,
    required this.held,
    required this.bar,
    required this.dot,
    required this.ring,
  }) : super(repaint: Listenable.merge([pick, held]));

  final List<HeartSample> samples;
  final List<double> positions;
  final int low;
  final int high;
  final ValueNotifier<_Pick?> pick;
  final ValueNotifier<bool> held;
  final Color bar;
  final Color dot;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final index = pick.value?.index;
    if (!held.value || index == null || index >= samples.length) return;
    final foot = size.height - HeartCurve._foot;
    final x = positions[index] * size.width;
    final y =
        HeartCurve._head +
        LineChart.yOf(
          samples[index].bpm.toDouble(),
          low: low.toDouble(),
          high: high.toDouble(),
          height: foot - HeartCurve._head,
        );
    canvas
      ..drawLine(
        Offset(x, 0),
        Offset(x, foot),
        Paint()
          ..color = bar
          ..strokeWidth = 2,
      )
      ..drawCircle(Offset(x, y), 8, Paint()..color = ring)
      ..drawCircle(Offset(x, y), 5, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_BarPainter oldDelegate) =>
      oldDelegate.samples != samples ||
      oldDelegate.low != low ||
      oldDelegate.high != high ||
      oldDelegate.bar != bar ||
      oldDelegate.dot != dot ||
      oldDelegate.ring != ring;
}

/// The rate and time under the finger, in a pill that pops up above the
/// curve and follows the bar. Hidden, it is not built at all.
class _Pill extends StatelessWidget {
  const _Pill({required this.pick, required this.held, required this.samples});

  final ValueNotifier<_Pick?> pick;
  final ValueNotifier<bool> held;
  final List<HeartSample> samples;

  /// Between the pill and the surface below it.
  static const double _gap = 8;

  /// Higher than the bars of the page, which rest at 3.
  static const double _elevation = 8;

  /// Kept free at the sides of the screen.
  static const double _margin = 16;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = Formats.of(context).l10n;
    final glass = AppScope.of(context).settings.liquidGlass;
    final style = AppType.of(context).figure(
      context.emphasizedTextTheme.titleMedium?.copyWith(
        color: scheme.onSurface,
      ),
    );
    final still = MediaQuery.disableAnimationsOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([pick, held]),
      builder: (context, _) {
        final picked = pick.value;
        if (picked == null || picked.index >= samples.length) {
          return const SizedBox.shrink();
        }
        final shown = held.value;
        final sample = samples[picked.index];
        final pill = IgnorePointer(
          child: FloatingSurface(
            glass: glass,
            // Above a tile, not only above the page.
            elevation: _elevation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                widthFactor: 1,
                child: Text(
                  l10n.pulseAtTime(sample.bpm, formatClock(sample.minuteOfDay)),
                  maxLines: 1,
                  style: style,
                ),
              ),
            ),
          ),
        );
        return CustomSingleChildLayout(
          delegate: _PillPlace(picked.anchor),
          child: still
              ? (shown ? pill : const SizedBox.shrink())
              : SingleMotionBuilder(
                  value: shown ? 1 : 0,
                  motion: AppMotion.spatialFast,
                  builder: (context, t, child) => t <= 0.001 && !shown
                      ? const SizedBox.shrink()
                      : Opacity(
                          opacity: t.clamp(0, 1).toDouble(),
                          child: Transform.scale(
                            scale: 0.8 + 0.2 * t,
                            alignment: Alignment.bottomCenter,
                            child: child,
                          ),
                        ),
                  child: pill,
                ),
        );
      },
    );
  }
}

/// Puts the pill above [anchor], centred on it as far as the screen allows.
class _PillPlace extends SingleChildLayoutDelegate {
  const _PillPlace(this.anchor);

  final Offset anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final most = size.width - _Pill._margin - childSize.width;
    final left = anchor.dx - childSize.width / 2;
    return Offset(
      most < _Pill._margin ? _Pill._margin : left.clamp(_Pill._margin, most),
      anchor.dy - _Pill._gap - childSize.height,
    );
  }

  @override
  bool shouldRelayout(_PillPlace oldDelegate) => oldDelegate.anchor != anchor;
}
