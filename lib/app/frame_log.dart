import 'dart:developer' show Timeline;
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Reports the frames that took too long, each with what happened in the
/// app just before it, so a stutter that cannot be brought about on purpose
/// can still be traced. Read it with `adb logcat -s flutter`. It does
/// nothing in a release build.
///
/// Built with `--dart-define=FRAME_STATS=true` it also writes out every
/// frame, which `tool/perf.dart` reads to say how many kept the display's
/// rate.
class FrameLog {
  static const bool everyFrame = bool.fromEnvironment('FRAME_STATS');

  /// As many frames as fit a line of the device's log.
  static const int _perLine = 100;

  /// Two frames at 60 Hz; anything longer is seen as a stutter.
  static const Duration slow = Duration(milliseconds: 32);

  static const int _kept = 12;

  /// The latest events, oldest first, by the clock the frames are timed with.
  final List<({String name, int at})> _events = [];
  bool _running = false;

  void start() {
    if (kReleaseMode || _running) return;
    _running = true;
    SchedulerBinding.instance.addTimingsCallback(_report);
  }

  void stop() {
    if (!_running) return;
    _running = false;
    SchedulerBinding.instance.removeTimingsCallback(_report);
  }

  /// Notes that [name] happened now.
  void mark(String name) => markAt(name, Timeline.now);

  @visibleForTesting
  void markAt(String name, int microseconds) {
    if (kReleaseMode) return;
    _events.add((name: name, at: microseconds));
    if (_events.length > _kept) _events.removeAt(0);
  }

  void _report(List<FrameTiming> timings) {
    for (final timing in timings) {
      final line = describe(timing);
      if (line != null) debugPrint(line);
    }
    if (!everyFrame) return;
    final rate = SchedulerBinding
        .instance
        .platformDispatcher
        .views
        .firstOrNull
        ?.display
        .refreshRate;
    for (var i = 0; i < timings.length; i += _perLine) {
      final end = i + _perLine < timings.length ? i + _perLine : timings.length;
      debugPrint(list(timings.sublist(i, end), rate ?? 60));
    }
  }

  /// The frames of [timings] in one line: the display's [rate], the time of
  /// day the first one began in microseconds, and for each frame the
  /// milliseconds it was built and drawn in and how long after the first it
  /// began.
  @visibleForTesting
  static String list(List<FrameTiming> timings, double rate) {
    // A frame's phases are timed by a clock of the engine's own; only the
    // end of drawing is also known by the time of day.
    int began(FrameTiming timing) =>
        timing.timestampInMicroseconds(FramePhase.rasterFinishWallTime) -
        (timing.timestampInMicroseconds(FramePhase.rasterFinish) -
            timing.timestampInMicroseconds(FramePhase.vsyncStart));
    final first = began(timings.first);
    final frames = [
      for (final timing in timings)
        '${_ms(timing.buildDuration)}/${_ms(timing.rasterDuration)}'
            '@${((began(timing) - first) / 1000).toStringAsFixed(1)}',
    ];
    return 'frames ${rate.toStringAsFixed(1)} Hz from $first: '
        '${frames.join(' ')}';
  }

  /// The line about [timing], or null where the frame was fast enough.
  @visibleForTesting
  String? describe(FrameTiming timing) {
    final build = timing.buildDuration;
    final raster = timing.rasterDuration;
    if (build + raster < slow) return null;
    final began = timing.timestampInMicroseconds(FramePhase.buildStart);
    final ended = timing.timestampInMicroseconds(FramePhase.buildFinish);
    // What happened before the frame was built, or while it was.
    final before = [
      for (final event in _events)
        if (event.at <= ended) event,
    ];
    final after = before.isEmpty
        ? ''
        : ', ${((began - before.last.at) / 1000).round()} ms after '
              '${before.last.name}';
    return 'slow frame: build ${_ms(build)} ms, raster ${_ms(raster)} ms$after';
  }

  static String _ms(Duration duration) =>
      (duration.inMicroseconds / 1000).toStringAsFixed(1);
}
