import 'dart:developer' show Timeline;
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Reports the frames that took too long, each with what happened in the
/// app just before it, so a stutter that cannot be brought about on purpose
/// can still be traced. Read it with `adb logcat -s flutter`. It does
/// nothing in a release build.
class FrameLog {
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
