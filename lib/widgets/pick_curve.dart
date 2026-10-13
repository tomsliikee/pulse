import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../app/app_scope.dart';
import '../app/haptics.dart';
import '../theme/app_motion.dart';
import '../theme/app_type.dart';
import '../theme/page_accent.dart';
import 'floating_surface.dart';
import 'line_chart.dart';

/// A line through values with labels written along its foot, filling the
/// height it is given. Tapped, it shows a bar at the value there, and a pill
/// above the surface says what [labelOf] gives for it; both stay until the
/// same place is tapped again. Held, the bar follows the finger from value
/// to value and goes when the finger lifts.
class PickCurve extends StatefulWidget {
  const PickCurve({
    super.key,
    required this.values,
    required this.positions,
    required this.drawKey,
    required this.labelOf,
    this.marks = const [],
    this.guide,
    this.guideLabel,
    this.dots = false,
  });

  /// At least one, in the order of [positions].
  final List<double> values;

  /// Where each value sits across the width, from 0 to 1, rising.
  final List<double> positions;

  /// The line draws in again when this changes.
  final Object drawKey;

  /// What the pill says at the value of an index.
  final String Function(int index) labelOf;

  /// Labels along the foot, each centred on its place from 0 to 1.
  final List<(double, String)> marks;

  /// A value to draw a dashed line across at, such as a goal. The chart
  /// reaches as far as it.
  final double? guide;
  final String? guideLabel;

  /// Whether every value has a dot, for a line of few.
  final bool dots;

  /// Room above the line, so a peak stays clear of the surface's corners
  /// and of the half of the pill that hangs into the surface.
  static const double _head = 16 + _Pill._sink;

  /// Room to leave free above the curve's surface for the other half of
  /// the pill, so it covers nothing that is written there.
  static const double pillRoom = FloatingSurface.height - _Pill._sink - 8;

  /// Room below the line for the labels.
  static const double _foot = 30;

  /// How long a finger rests before the bar follows it: short enough to
  /// feel direct, long enough for a scroll to have started first.
  static const Duration _hold = Duration(milliseconds: 300);

  @override
  State<PickCurve> createState() => _PickCurveState();
}

/// What the bar is on: the value, where it is across the overlay, and
/// where the curve starts in the overlay and how wide that is.
typedef _Pick = ({int index, double x, double left, double width});

class _PickCurveState extends State<PickCurve> {
  final _overlay = OverlayPortalController();
  final _link = LayerLink();

  /// Kept after the bar goes, so the pill leaves with its text.
  final _pick = ValueNotifier<_Pick?>(null);
  final _shown = ValueNotifier<bool>(false);

  /// Whether the bar stays without a finger on it.
  bool _pinned = false;

  @override
  void didUpdateWidget(PickCurve oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.values, widget.values) ||
        !listEquals(oldWidget.positions, widget.positions)) {
      // The value under the bar may be gone.
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

  /// The lowest and the highest the chart reaches, the guide among them.
  (double, double) get _range {
    var low = widget.guide ?? widget.values.first;
    var high = low;
    for (final value in widget.values) {
      if (value < low) low = value;
      if (value > high) high = value;
    }
    return (low, high);
  }

  /// Puts the bar on the value nearest to [dx] and says whether it moved.
  bool _move(double dx) {
    final box = context.findRenderObject();
    final overlay = Overlay.of(context).context.findRenderObject();
    if (box is! RenderBox || overlay is! RenderBox || !box.hasSize) {
      return false;
    }
    final PickCurve(:values, :positions) = widget;
    final at = dx / box.size.width;
    var index = 0;
    for (var i = 1; i < positions.length; i++) {
      if ((positions[i] - at).abs() < (positions[index] - at).abs()) index = i;
    }
    if (index == _pick.value?.index && _shown.value) return false;
    final left = box.localToGlobal(Offset.zero, ancestor: overlay).dx;
    _pick.value = (
      index: index,
      x: left + positions[index] * box.size.width,
      left: left,
      width: overlay.size.width,
    );
    _overlay.show();
    _shown.value = true;
    // Felt by how high the value there is within the line.
    var low = values.first;
    var high = low;
    for (final value in values) {
      if (value < low) low = value;
      if (value > high) high = value;
    }
    Haptics.scaled(high == low ? 0.5 : (values[index] - low) / (high - low));
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
    final PickCurve(:values, :positions) = widget;
    final labelStyle = AppType.of(context).label(
      theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
    );
    final (low, high) = _range;
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
        if (widget.guide case final guide?)
          Positioned.fill(
            child: CustomPaint(
              painter: _GuidePainter(
                guide: guide,
                label: widget.guideLabel,
                low: low,
                high: high,
                color: scheme.outline,
                style: labelStyle,
                direction: Directionality.of(context),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(
            top: PickCurve._head,
            bottom: PickCurve._foot,
          ),
          child: LineChart(
            key: ValueKey(widget.drawKey),
            values: values,
            positions: positions,
            low: low,
            high: high,
            color: accent,
            height: null,
          ),
        ),
        // Each label centred on where it is on the line.
        for (final (at, label) in widget.marks)
          Align(
            alignment: Alignment(2 * at - 1, 1),
            child: FractionalTranslation(
              // Align keeps the label inside; this puts its middle on the
              // place instead.
              translation: Offset(at - 0.5, 0),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(label, style: labelStyle),
              ),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _BarPainter(
                values: values,
                positions: positions,
                low: low,
                high: high,
                dots: widget.dots,
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
          child: _Pill(
            pick: _pick,
            shown: _shown,
            count: values.length,
            labelOf: widget.labelOf,
          ),
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
                  () => LongPressGestureRecognizer(duration: PickCurve._hold),
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

/// How far down [value] is drawn in a curve of [size].
double _yOf(double value, double low, double high, Size size) =>
    PickCurve._head +
    LineChart.yOf(
      value,
      low: low,
      high: high,
      height: size.height - PickCurve._foot - PickCurve._head,
    );

/// The dashed line of the guide value, named at its end.
class _GuidePainter extends CustomPainter {
  const _GuidePainter({
    required this.guide,
    required this.label,
    required this.low,
    required this.high,
    required this.color,
    required this.style,
    required this.direction,
  });

  final double guide;
  final String? label;
  final double low;
  final double high;
  final Color color;
  final TextStyle? style;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final y = _yOf(guide, low, high, size);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var x = 1.0; x < size.width; x += 10) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + 4).clamp(0, size.width), y),
        paint,
      );
    }
    final label = this.label;
    if (label == null) return;
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: style?.copyWith(color: color),
      ),
      textDirection: direction,
      maxLines: 1,
    )..layout();
    // Above the line where the line is at the foot, below it otherwise.
    final above = y - text.height - 4;
    text.paint(
      canvas,
      Offset(size.width - text.width, above >= _Pill._sink ? above : y + 4),
    );
    text.dispose();
  }

  @override
  bool shouldRepaint(_GuidePainter oldDelegate) =>
      oldDelegate.guide != guide ||
      oldDelegate.label != label ||
      oldDelegate.low != low ||
      oldDelegate.high != high ||
      oldDelegate.color != color ||
      oldDelegate.style != style;
}

/// The dots of the values, the bar under the finger and the dot where it
/// meets the line.
class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.values,
    required this.positions,
    required this.low,
    required this.high,
    required this.dots,
    required this.pick,
    required this.shown,
    required this.bar,
    required this.dot,
    required this.ring,
  }) : super(repaint: Listenable.merge([pick, shown]));

  final List<double> values;
  final List<double> positions;
  final double low;
  final double high;
  final bool dots;
  final ValueNotifier<_Pick?> pick;
  final ValueNotifier<bool> shown;
  final Color bar;
  final Color dot;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    // A hair inside, so the bar of the first and the last value is whole.
    Offset place(int i) => Offset(
      (positions[i] * size.width).clamp(1.0, size.width - 1),
      _yOf(values[i], low, high, size),
    );
    if (dots) {
      for (var i = 0; i < values.length; i++) {
        canvas
          ..drawCircle(place(i), 6, Paint()..color = ring)
          ..drawCircle(place(i), 4, Paint()..color = dot);
      }
    }
    final index = pick.value?.index;
    if (!shown.value || index == null || index >= values.length) return;
    final at = place(index);
    canvas
      ..drawLine(
        Offset(at.dx, _Pill._sink),
        Offset(at.dx, size.height - PickCurve._foot),
        Paint()
          ..color = bar
          ..strokeWidth = 2,
      )
      ..drawCircle(at, 8, Paint()..color = ring)
      ..drawCircle(at, 5, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_BarPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.positions != positions ||
      oldDelegate.low != low ||
      oldDelegate.high != high ||
      oldDelegate.dots != dots ||
      oldDelegate.bar != bar ||
      oldDelegate.dot != dot ||
      oldDelegate.ring != ring;
}

/// What the curve says at the bar, in a pill that pops up above the curve
/// and follows the bar. Hidden, it is not built at all.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.pick,
    required this.shown,
    required this.count,
    required this.labelOf,
  });

  final ValueNotifier<_Pick?> pick;
  final ValueNotifier<bool> shown;

  /// How many values the curve has.
  final int count;
  final String Function(int index) labelOf;

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
        if (picked == null || picked.index >= count) {
          return const SizedBox.shrink();
        }
        final shown = this.shown.value;
        final pill = IgnorePointer(
          child: FloatingSurface(
            glass: glass,
            // Above a tile, not only above the page.
            elevation: _elevation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                widthFactor: 1,
                child: Text(labelOf(picked.index), maxLines: 1, style: style),
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
