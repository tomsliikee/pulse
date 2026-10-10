// Drives Pulse on an attached phone through fixed gestures and says how many
// frames kept the display's rate in each of them.
//
//   dart run tool/perf.dart            measure the installed build
//   dart run tool/perf.dart --install  build a profile APK that lists its
//                                      frames, install it, then measure
//
// The phone has to be unlocked. The gestures are made for 1280x2856 with the
// navigation bar's labels shown, and start from the Today page. Nothing that
// is tapped writes anything.

import 'dart:io';

const _package = 'at.haiden.pulse';
const _width = 1280;

/// The destinations of the navigation bar, each where it is while the one
/// before it is selected.
const _tabs = [('activity', 540), ('sleep', 700), ('heart', 852)];
const _todayFromHeart = 220;
const _barY = 2640;

late final String _adb;

Future<String> _run(String program, List<String> arguments) async {
  final result = await Process.run(program, arguments);
  if (result.exitCode != 0) {
    stderr.writeln('$program ${arguments.join(' ')}\n${result.stderr}');
    exit(1);
  }
  return result.stdout as String;
}

Future<String> _device(List<String> arguments) => _run(_adb, arguments);

Future<void> _wait(int milliseconds) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

/// The phone's time of day in microseconds, which the app's frames carry.
Future<int> _now() async {
  final nanoseconds = await _device(['shell', 'date', '+%s%N']);
  return int.parse(nanoseconds.trim()) ~/ 1000;
}

Future<void> _tap(int x, int y) =>
    _device(['shell', 'input', 'tap', '$x', '$y']);

Future<void> _swipe(int fromY, int toY) => _device([
  'shell',
  'input',
  'swipe',
  '${_width ~/ 2}',
  '$fromY',
  '${_width ~/ 2}',
  '$toY',
  '250',
]);

final List<({String name, int from, int to})> _sections = [];

Future<void> _section(String name, Future<void> Function() gestures) async {
  final from = await _now();
  await gestures();
  _sections.add((name: name, from: from, to: await _now()));
  await _wait(400);
}

/// Slow enough that the page does not fly far, and up further than down,
/// so it never reaches its top again: there a pull would reload the data
/// and the stretch of the edge would be measured in place of the page.
Future<void> _scroll() async {
  for (final (from, to) in const [
    (2000, 1100),
    (2000, 1100),
    (1200, 1900),
    (1900, 1200),
    (1200, 1900),
    (1900, 1200),
    (1200, 1900),
  ]) {
    await _swipe(from, to);
    await _wait(900);
  }
}

typedef _Frame = ({int began, double build, double raster});

/// The frames of the lines `frames 120.0 Hz from 17…: 3.0/2.0@0.0 …`.
(double rate, List<_Frame> frames) _read(String log) {
  final line = RegExp(r'frames ([\d.]+) Hz from (\d+): (.*)$');
  var rate = 60.0;
  final frames = <_Frame>[];
  for (final text in log.split('\n')) {
    final match = line.firstMatch(text.trimRight());
    if (match == null) continue;
    rate = double.parse(match[1]!);
    final first = int.parse(match[2]!);
    for (final frame in match[3]!.split(' ')) {
      final parts = frame.split(RegExp('[/@]'));
      frames.add((
        began: first + (double.parse(parts[2]) * 1000).round(),
        build: double.parse(parts[0]),
        raster: double.parse(parts[1]),
      ));
    }
  }
  frames.sort((a, b) => a.began.compareTo(b.began));
  return (rate, frames);
}

double _percentile(List<double> sorted, double share) =>
    sorted[((sorted.length - 1) * share).round()];

String _cell(Object value, int width) => '$value'.padLeft(width);

void _report(double rate, List<_Frame> frames) {
  final budget = 1000 / rate;
  stdout
    ..writeln(
      'Display ${rate.toStringAsFixed(0)} Hz, '
      '${budget.toStringAsFixed(1)} ms a frame. A frame is late when it was '
      'built or drawn for longer than that.',
    )
    ..writeln(
      '${'section'.padRight(18)}${_cell('frames', 7)}${_cell('fps', 6)}'
      '${_cell('late', 7)}${_cell('>2x', 6)}${_cell('gaps', 6)}'
      '${_cell('build p50/p90/p99/max', 26)}'
      '${_cell('raster p50/p90/p99/max', 26)}',
    );
  for (final section in _sections) {
    final own = [
      for (final frame in frames)
        if (frame.began >= section.from && frame.began <= section.to) frame,
    ];
    if (own.isEmpty) {
      stdout.writeln('${section.name.padRight(18)}  no frames');
      continue;
    }
    final builds = [for (final frame in own) frame.build]..sort();
    final rasters = [for (final frame in own) frame.raster]..sort();
    final late = own.where((f) => f.build > budget || f.raster > budget);
    final twice = own.where(
      (f) => f.build > 2 * budget || f.raster > 2 * budget,
    );
    // Display frames that passed without one of the app's, while it was
    // drawing without a pause before and after.
    var gaps = 0;
    for (var i = 1; i < own.length; i++) {
      final passed = ((own[i].began - own[i - 1].began) / 1000 / budget)
          .round();
      if (passed > 1 && passed < 12) gaps += passed - 1;
    }
    String spread(List<double> sorted) => [
      _percentile(sorted, 0.5),
      _percentile(sorted, 0.9),
      _percentile(sorted, 0.99),
      sorted.last,
    ].map((ms) => ms.toStringAsFixed(1)).join('/');
    final seconds = (section.to - section.from) / 1e6;
    stdout.writeln(
      '${section.name.padRight(18)}${_cell(own.length, 7)}'
      '${_cell((own.length / seconds).round(), 6)}'
      '${_cell('${(100 * late.length / own.length).toStringAsFixed(1)}%', 7)}'
      '${_cell(twice.length, 6)}${_cell(gaps, 6)}'
      '${_cell(spread(builds), 26)}${_cell(spread(rasters), 26)}',
    );
  }
}

Future<void> main(List<String> arguments) async {
  final home = Platform.environment['HOME'];
  final bundled = '$home/Android/Sdk/platform-tools/adb';
  _adb = File(bundled).existsSync() ? bundled : 'adb';

  if (arguments.contains('--install')) {
    stdout.writeln('Building …');
    await _run('flutter', [
      'build',
      'apk',
      '--profile',
      '--dart-define=FRAME_STATS=true',
    ]);
    await _device([
      'install',
      '-r',
      'build/app/outputs/flutter-apk/app-profile.apk',
    ]);
  }

  // A start from nothing, so every run begins on Today at its top.
  await _device(['shell', 'am', 'kill', _package]);
  await _device(['shell', 'input', 'keyevent', 'KEYCODE_HOME']);
  await _wait(500);
  await _device(['shell', 'am', 'kill', _package]);
  await _device(['logcat', '-c']);
  await _section('cold start', () async {
    await _device(['shell', 'am', 'start', '-n', '$_package/.MainActivity']);
    await _wait(6000);
  });

  await _section('today at rest', () => _wait(3000));
  await _section('today scroll', _scroll);
  for (final (name, x) in _tabs) {
    await _section('to $name', () async {
      await _tap(x, _barY);
      await _wait(1500);
    });
    await _section('$name scroll', _scroll);
  }
  await _section('to today', () async {
    await _tap(_todayFromHeart, _barY);
    await _wait(1500);
  });
  await _section('open the day', () async {
    await _tap(840, 1240);
    await _wait(1500);
  });
  await _section('day scroll', _scroll);
  await _section('back to today', () async {
    await _device(['shell', 'input', 'keyevent', 'KEYCODE_BACK']);
    await _wait(1500);
  });

  // The app hands its frames over about once a second.
  await _wait(2500);
  final log = await _device(['logcat', '-d', '-s', 'flutter']);
  File('build/perf.log').writeAsStringSync(
    [
      for (final section in _sections)
        'section ${section.name} ${section.from} ${section.to}',
      log,
    ].join('\n'),
  );
  final (rate, frames) = _read(log);
  if (frames.isEmpty) {
    stderr.writeln(
      'The app listed no frames. Install a build that does: --install',
    );
    exit(1);
  }
  _report(rate, frames);
}
