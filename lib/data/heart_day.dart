import 'models.dart';

/// The minutes one stored heart-rate sample stands for.
const int heartBucketMinutes = 10;

/// The rate each zone starts at: rest, light, cardio, peak.
const List<int> heartZoneFloors = [0, 70, 115, 140];

/// Where each sample sits between the first and the last of the day, from 0
/// to 1 and true to time: an hour without samples stays an hour wide.
List<double> curvePositions(List<HeartSample> samples) {
  if (samples.isEmpty) return const [];
  final first = samples.first.minuteOfDay;
  final span = samples.last.minuteOfDay - first;
  return [
    for (final sample in samples)
      span == 0 ? 0 : (sample.minuteOfDay - first) / span,
  ];
}

/// The index of the sample nearest to [fraction] of the way from the first
/// to the last. [samples] must not be empty.
int indexNear(List<HeartSample> samples, double fraction) {
  final first = samples.first.minuteOfDay;
  final minute =
      first + fraction.clamp(0, 1) * (samples.last.minuteOfDay - first);
  var nearest = 0;
  for (var i = 1; i < samples.length; i++) {
    if ((samples[i].minuteOfDay - minute).abs() <
        (samples[nearest].minuteOfDay - minute).abs()) {
      nearest = i;
    }
  }
  return nearest;
}

/// The full hours, as minutes of the day, to write under a curve from
/// [firstMinute] to [lastMinute]: as few as say something, at least two
/// where the span allows, none nearer to an end than [edge] of the span, so
/// a label centred on its hour stays inside.
List<int> hourMarks(int firstMinute, int lastMinute, {double edge = 0.08}) {
  final span = lastMinute - firstMinute;
  if (span <= 0) return const [];
  var marks = const <int>[];
  for (final step in const [360, 180, 120, 60]) {
    final found = [
      for (
        var minute = (firstMinute ~/ step + 1) * step;
        minute < lastMinute;
        minute += step
      )
        if ((minute - firstMinute) / span >= edge &&
            (lastMinute - minute) / span >= edge)
          minute,
    ];
    if (found.length >= 2) return found;
    if (marks.isEmpty) marks = found;
  }
  return marks;
}

/// The lowest, highest and mean rate of [samples]; null without any.
({int low, int high, int average})? heartSummary(List<HeartSample> samples) {
  if (samples.isEmpty) return null;
  var low = samples.first.bpm;
  var high = low;
  var sum = 0;
  for (final sample in samples) {
    if (sample.bpm < low) low = sample.bpm;
    if (sample.bpm > high) high = sample.bpm;
    sum += sample.bpm;
  }
  return (low: low, high: high, average: (sum / samples.length).round());
}

/// The minutes spent in each zone of [heartZoneFloors].
List<int> zoneMinutes(List<HeartSample> samples) {
  final minutes = List<int>.filled(heartZoneFloors.length, 0);
  for (final sample in samples) {
    final zone = heartZoneFloors.lastIndexWhere((from) => sample.bpm >= from);
    if (zone >= 0) minutes[zone] += heartBucketMinutes;
  }
  return minutes;
}

/// One hour of a day's heart rate.
class HeartHour {
  const HeartHour({
    required this.hour,
    required this.low,
    required this.high,
    required this.average,
  });

  /// 0 to 23.
  final int hour;
  final int low;
  final int high;
  final int average;
}

/// The hours of the day that have samples, in order.
List<HeartHour> heartHours(List<HeartSample> samples) {
  final byHour = <int, List<HeartSample>>{};
  for (final sample in samples) {
    byHour.putIfAbsent(sample.minuteOfDay ~/ 60, () => []).add(sample);
  }
  return [
    for (final hour in byHour.keys.toList()..sort())
      if (heartSummary(byHour[hour]!) case final summary?)
        HeartHour(
          hour: hour,
          low: summary.low,
          high: summary.high,
          average: summary.average,
        ),
  ];
}
