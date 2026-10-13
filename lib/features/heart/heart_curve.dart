import 'package:material_ui/material_ui.dart';

import '../../app/formatters.dart';
import '../../data/heart_day.dart';
import '../../data/models.dart';
import '../../widgets/pick_curve.dart';

/// The heart rate of a day from its first measurement to its last, reaching
/// the edges of the surface it is on, with the full hours written along its
/// foot. Tapped or held, it says the rate and the time of a measurement, as
/// [PickCurve] does.
class HeartCurve extends StatefulWidget {
  const HeartCurve({super.key, required this.samples, required this.day});

  /// At least two, in the order of the day.
  final List<HeartSample> samples;

  /// The line draws in again when this changes.
  final DateTime day;

  /// Room to leave free above the curve's surface for the pill.
  static const double pillRoom = PickCurve.pillRoom;

  @override
  State<HeartCurve> createState() => _HeartCurveState();
}

class _HeartCurveState extends State<HeartCurve> {
  // Kept, so the curve only sees new lists when the samples are new.
  late List<double> _values = _valuesOf(widget.samples);
  late List<double> _positions = curvePositions(widget.samples);

  static List<double> _valuesOf(List<HeartSample> samples) => [
    for (final sample in samples) sample.bpm.toDouble(),
  ];

  @override
  void didUpdateWidget(HeartCurve oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.samples != widget.samples) {
      _values = _valuesOf(widget.samples);
      _positions = curvePositions(widget.samples);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = Formats.of(context).l10n;
    final samples = widget.samples;
    final first = samples.first.minuteOfDay;
    final span = samples.last.minuteOfDay - first;
    return PickCurve(
      values: _values,
      positions: _positions,
      drawKey: widget.day,
      labelOf: (index) => l10n.pulseAtTime(
        samples[index].bpm,
        formatClock(samples[index].minuteOfDay),
      ),
      marks: [
        for (final minute in hourMarks(first, samples.last.minuteOfDay))
          ((minute - first) / span, formatClock(minute)),
      ],
    );
  }
}
