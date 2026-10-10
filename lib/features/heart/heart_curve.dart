import 'package:flutter/gestures.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../app/haptics.dart';
import '../../data/heart_day.dart';
import '../../data/models.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_type.dart';
import '../../theme/page_accent.dart';
import '../../widgets/floating_surface.dart';
import '../../widgets/line_chart.dart';

/// The heart rate of a day from its first measurement to its last, reaching
/// the edges of the surface it is on, with the full hours written along its
/// foot. Tapped, it shows a bar at the measurement there, and a pill above
/// the surface says the rate and the time; both stay until the same place
/// is tapped again. Held, the bar follows the finger from measurement to
/// measurement and goes when the finger lifts.
class HeartCurve extends StatefulWidget {
  const HeartCurve({super.key, required this.samples, required this.day});

  /// At least two, in the order of the day.
  final List<HeartSample> samples;

  /// The line draws in again when this changes.
  final DateTime day;

  /// Room above the line, so a peak stays clear of the surface's corners
  /// and of the half of the pill that hangs into the surface.
  static const double _head = 16 + _Pill._sink;

  /// Room to leave free above the curve's surface for the other half of
  /// the pill, so it covers nothing that is written there.
  static const double pillRoom = FloatingSurface.height - _Pill._sink - 8;

  /// Room below the line for the hours.
  static const double _foot = 30;

  /// How long a finger rests before the bar follows it: short enough to
  /// feel direct, long enough for a scroll to have started first.
  static const Duration _hold = Duration(milliseconds: 300);

  @override
  State<HeartCurve> createState() => _HeartCurveState();
}

/// What the bar is on: the sample, where it is across the overlay, and
/// where the curve starts in the overlay and how wide that is.
typedef _Pick = ({int index, double x, double left, double width});

class _HeartCurveState extends State<HeartCurve> {
  final _overlay = OverlayPortalController();
  final _link = LayerLink();

  /// Kept after the bar goes, so the pill leaves with its text.
  final _pick = ValueNotifier<_Pick?>(null);
  final _shown = ValueNotifier<bool>(false);

  /// Whether the bar stays without a finger on it.
  bool _pinned = false;

  late List<double> _positions = curvePositions(widget.samples);

  @override
  void didUpdateWidget(HeartCurve oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.samples != widget.samples) {
      _positions = curvePositions(widget.samples);
      // The sample under the bar may be gone.
      _pinned = false;
      _shown.value = false;
      _pick.value = null;
    }
  }

  @override
  void dispose() {
    _pick.dispose();
    _shown.dispose();
    super.dispose();
  }

  /// Puts the bar on the sample nearest to [dx] and says whether it moved.
  bool _move(double dx) {
    final box = context.findRenderObject();
    final overlay = Overlay.of(context).context.findRenderObject();
    if (box is! RenderBox || overlay is! RenderBox || !box.hasSize) {
      return false;
    }
    final samples = widget.samples;
    final index = indexNear(samples, dx / box.size.width);
    if (index == _pick.value?.index && _shown.value) return false;
    final left = box.localToGlobal(Offset.zero, ancestor: overlay).dx;
    _pick.value = (
      index: index,
      x: left + _positions[index] * box.size.width,
      left: left,
      width: overlay.size.width,
    );
    _overlay.show();
    _shown.value = true;
    // Felt by how high the rate there is within the day.
    final summary = heartSummary(samples)!;
    final range = summary.high - summary.low;
    Haptics.scaled(
      range == 0 ? 0.5 : (samples[index].bpm - summary.low) / range,
    );
    return true;
  }

  void _tap(TapUpDetails details) {
    final moved = _move(details.localPosition.dx);
    if (!moved && _pinned) {
      // The same place again takes the bar away.
      _pinned = false;
      _shown.value = false;
    } else {
      _pinned = true;
    }
  }

  void _start(LongPressStartDetails details) {
    _pinned = false;
    _move(details.localPosition.dx);
  }

  void _end() {
    if (!_pinned) _shown.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = PageAccent.colorsOf(context).accent;
    final samples = widget.samples;
    final labelStyle = AppType.of(context).label(
      theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
    );
    final first = samples.first.minuteOfDay;
    final span = samples.last.minuteOfDay - first;
    final summary = heartSummary(samples);
    // The pill is above every page, so it goes at once when another one
    // covers this: nothing here moves any more to take it away. Asked
    // before a bar is there, so the curve hears of the other page.
    final covered = !(ModalRoute.isCurrentOf(context) ?? true);
    if (_pinned && covered) {
      _pinned = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _pinned) return;
        _shown.value = false;
        _pick.value = null;
      });
    }

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
                  shown: _shown,
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
      overlayChildBuilder: (_) => Positioned(
        left: 0,
        top: 0,
        // On the curve's top edge, wherever the page scrolls it to.
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          followerAnchor: Alignment.bottomLeft,
          offset: const Offset(0, _Pill._sink),
          child: _Pill(pick: _pick, shown: _shown, samples: samples),
        ),
      ),
      child: CompositedTransformTarget(
        link: _link,
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  TapGestureRecognizer.new,
                  (recognizer) => recognizer.onTapUp = _tap,
                ),
            // Only after the hold does this take the finger, so a scroll
            // that starts on the curve stays a scroll.
            LongPressGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  LongPressGestureRecognizer
                >(
                  () => LongPressGestureRecognizer(duration: HeartCurve._hold),
                  (recognizer) => recognizer
                    ..onLongPressStart = _start
                    ..onLongPressMoveUpdate = ((details) =>
                        _move(details.localPosition.dx))
                    ..onLongPressEnd = ((_) => _end())
                    ..onLongPressCancel = _end,
                ),
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
    required this.shown,
    required this.bar,
    required this.dot,
    required this.ring,
  }) : super(repaint: Listenable.merge([pick, shown]));

  final List<HeartSample> samples;
  final List<double> positions;
  final int low;
  final int high;
  final ValueNotifier<_Pick?> pick;
  final ValueNotifier<bool> shown;
  final Color bar;
  final Color dot;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final index = pick.value?.index;
    if (!shown.value || index == null || index >= samples.length) return;
    final foot = size.height - HeartCurve._foot;
    // A hair inside, so the bar of the first and the last sample is whole.
    final x = (positions[index] * size.width).clamp(1.0, size.width - 1);
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
        Offset(x, _Pill._sink),
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

/// The rate and time at the bar, in a pill that pops up above the curve and
/// follows the bar. Hidden, it is not built at all.
class _Pill extends StatelessWidget {
  const _Pill({required this.pick, required this.shown, required this.samples});

  final ValueNotifier<_Pick?> pick;
  final ValueNotifier<bool> shown;
  final List<HeartSample> samples;

  /// How far the pill hangs over the top edge into the surface, like the
  /// mark of a hero over its scene.
  static const double _sink = FloatingSurface.height / 2;

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
      listenable: Listenable.merge([pick, shown]),
      builder: (context, _) {
        final picked = pick.value;
        if (picked == null || picked.index >= samples.length) {
          return const SizedBox.shrink();
        }
        final shown = this.shown.value;
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
        // A strip as wide as the screen, so the pill can leave the curve's
        // sides but not the screen's.
        return Transform.translate(
          offset: Offset(-picked.left, 0),
          child: SizedBox(
            width: picked.width,
            height: FloatingSurface.height,
            child: CustomSingleChildLayout(
              delegate: _PillPlace(picked.x),
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
            ),
          ),
        );
      },
    );
  }
}

/// Puts the pill over [x], centred on it as far as the screen allows.
class _PillPlace extends SingleChildLayoutDelegate {
  const _PillPlace(this.x);

  final double x;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final most = size.width - _Pill._margin - childSize.width;
    final left = x - childSize.width / 2;
    return Offset(
      most < _Pill._margin ? _Pill._margin : left.clamp(_Pill._margin, most),
      size.height - childSize.height,
    );
  }

  @override
  bool shouldRelayout(_PillPlace oldDelegate) => oldDelegate.x != x;
}
