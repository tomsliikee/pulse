import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app/frame_log.dart';
import 'package:pulse/theme/system_palette.dart';

FrameTiming _frame({required int start, required int build, int raster = 2}) {
  final built = start + build * 1000;
  return FrameTiming(
    vsyncStart: start,
    buildStart: start,
    buildFinish: built,
    rasterStart: built,
    rasterFinish: built + raster * 1000,
    rasterFinishWallTime: built + raster * 1000,
  );
}

void main() {
  group('the report of slow frames', () {
    test('says nothing about a frame that was fast enough', () {
      final log = FrameLog()..markAt('health', 0);
      expect(log.describe(_frame(start: 5000, build: 8)), isNull);
    });

    test('names what happened last before a slow frame, and how long '
        'before', () {
      final log = FrameLog()
        ..markAt('resumed', 1000)
        ..markAt('health', 40000)
        // After the frame, so it cannot be its cause.
        ..markAt('settings', 900000);
      expect(
        log.describe(_frame(start: 52000, build: 41)),
        'slow frame: build 41.0 ms, raster 2.0 ms, 12 ms after health',
      );
    });

    test('reports a slow frame with nothing before it', () {
      expect(
        FrameLog().describe(_frame(start: 0, build: 10, raster: 30)),
        'slow frame: build 10.0 ms, raster 30.0 ms',
      );
    });
  });

  test('the same palette loaded again changes nothing', () {
    SystemPalette load(Color seed) => SystemPalette(
      light: ColorScheme.fromSeed(seedColor: seed),
      dark: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
    );
    final palette = ValueNotifier<SystemPalette?>(load(Colors.teal));
    var changes = 0;
    palette
      ..addListener(() => changes++)
      ..value = load(Colors.teal);
    expect(changes, 0);
    palette.value = load(Colors.red);
    expect(changes, 1);
  });
}
