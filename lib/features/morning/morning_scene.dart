import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/weather.dart';
import '../../widgets/scene_kit.dart';

/// The morning: the sun comes up behind the hills and the figure of the
/// other scenes stretches. The sky shows the weather of the day, where the
/// app knows it; without it the morning is clear.
class MorningScene extends StatelessWidget {
  const MorningScene({super.key, this.sky, this.height = 160});

  final Sky? sky;
  final double height;

  @override
  Widget build(BuildContext context) => SceneClock(
    builder: (context, seconds) => CustomPaint(
      size: Size(double.infinity, height),
      painter: _MorningPainter(
        sky: sky ?? Sky.clear,
        scheme: Theme.of(context).colorScheme,
        seconds: seconds,
      ),
    ),
  );
}

class _MorningPainter extends CustomPainter {
  _MorningPainter({
    required this.sky,
    required this.scheme,
    required this.seconds,
  }) : super(repaint: seconds);

  final Sky sky;
  final ColorScheme scheme;
  final ValueListenable<double> seconds;

  static const double _tau = 2 * math.pi;

  /// The dawn is warm under any theme; the theme only tints the land.
  static const Color _high = Color(0xFF8FB8E8);
  static const Color _low = Color(0xFFFFD9A8);
  static const Color _sunlight = Color(0xFFFFC55A);
  static const Color _grey = Color(0xFF9AA3B2);

  /// How much of the sky the clouds take, from 0 to 1.
  double get _cover => switch (sky) {
    Sky.clear => 0,
    Sky.partlyCloudy => 0.35,
    Sky.fog => 0.5,
    Sky.cloudy => 0.75,
    Sky.rain || Sky.snow || Sky.thunder => 1,
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final time = seconds.value;
    final u = size.height / 100;
    final cover = _cover;

    // An overcast morning is greyer from top to bottom.
    final top = Color.lerp(_high, _grey, cover * 0.7)!;
    final bottom = Color.lerp(_low, const Color(0xFFD5D9E0), cover * 0.75)!;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(Offset.zero & size),
    );

    final ground = size.height - 16 * u;
    // The sun rises a little and comes back, so it never leaves the hills.
    final rise = 0.5 + 0.5 * math.sin(time * _tau / 14);
    final sun = Offset(size.width * 0.68, ground - (10 + 8 * rise) * u);
    final glow = 1 - cover * 0.8;
    canvas
      ..drawCircle(
        sun,
        30 * u,
        Paint()..color = _sunlight.withValues(alpha: 0.22 * glow),
      )
      ..drawCircle(
        sun,
        13 * u,
        Paint()..color = Color.lerp(_sunlight, Colors.white, cover * 0.6)!,
      );

    _clouds(canvas, size, u, time, cover);

    // Far hills, then the ground the figure stands on.
    final hills = Path()..moveTo(0, ground);
    for (var x = 0.0; x <= size.width; x += 6) {
      hills.lineTo(
        x,
        ground - (9 + 6 * math.sin(x / size.width * _tau * 1.5 + 1)) * u,
      );
    }
    hills
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas
      ..drawPath(
        hills,
        Paint()..color = Color.lerp(scheme.primaryContainer, bottom, 0.35)!,
      )
      ..drawRect(
        Rect.fromLTRB(0, ground, size.width, size.height),
        Paint()..color = scheme.surfaceContainerHighest,
      );

    _figure(canvas, Offset(size.width * 0.3, ground), u, time);

    switch (sky) {
      case Sky.rain || Sky.thunder:
        _rain(canvas, size, u, time);
      case Sky.snow:
        _snow(canvas, size, u, time);
      case Sky.fog:
        _fog(canvas, size, u, time);
      default:
    }
  }

  void _clouds(Canvas canvas, Size size, double u, double time, double cover) {
    if (cover == 0) return;
    final count = (2 + cover * 4).round();
    final paint = Paint()
      ..color = Color.lerp(
        Colors.white,
        _grey,
        cover * 0.6,
      )!.withValues(alpha: 0.9);
    for (var i = 0; i < count; i++) {
      // Each drifts at its own pace and comes in again on the left.
      final span = size.width + 60 * u;
      final x = (i * span / count + time * (1.2 + i % 3) * u) % span - 30 * u;
      final y = (12 + (i * 37) % 26) * u;
      final r = (7 + (i * 13) % 5) * u;
      canvas
        ..drawCircle(Offset(x, y), r, paint)
        ..drawCircle(Offset(x + r * 1.1, y + r * 0.2), r * 0.8, paint)
        ..drawCircle(Offset(x - r * 1.1, y + r * 0.25), r * 0.7, paint);
    }
  }

  /// Standing, both arms up and a little apart: a stretch that breathes.
  void _figure(Canvas canvas, Offset feet, double u, double time) {
    final pen = FigurePen(canvas, scheme, u);
    final breath = math.sin(time * _tau / 4);
    final hip = feet + Offset(0, -24 * u);
    final neck = hip + Offset(0, -(20 + breath) * u);
    final near = pen.limb();
    final far = pen.limb(far: true);
    for (final (side, paint) in [(-1.0, far), (1.0, near)]) {
      pen
        ..line(paint, [hip, feet + Offset(side * 4 * u, 0)])
        ..line(paint, [
          neck + Offset(0, 2 * u),
          neck + Offset(side * 10 * u, -(4 + breath) * u),
          neck + Offset(side * (15 + breath) * u, -(17 + 2 * breath) * u),
        ]);
    }
    pen
      ..line(near, [hip, neck])
      ..head(neck + Offset(0, -9 * u));
  }

  void _rain(Canvas canvas, Size size, double u, double time) {
    final paint = Paint()
      ..color = const Color(0xFF5B7FB8).withValues(alpha: 0.55)
      ..strokeWidth = 1.2 * u
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 26; i++) {
      final x = (i * 53.0) % size.width;
      final y = ((i * 29.0) + time * 90 * u) % size.height;
      canvas.drawLine(Offset(x, y), Offset(x - 2 * u, y + 6 * u), paint);
    }
  }

  void _snow(Canvas canvas, Size size, double u, double time) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    for (var i = 0; i < 30; i++) {
      final x = (i * 47.0 + math.sin(time + i) * 4 * u) % size.width;
      final y = ((i * 31.0) + time * 14 * u) % size.height;
      canvas.drawCircle(Offset(x, y), (1 + i % 3 * 0.5) * u, paint);
    }
  }

  void _fog(Canvas canvas, Size size, double u, double time) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.35);
    for (var i = 0; i < 3; i++) {
      final shift = math.sin(time / 5 + i) * 10 * u;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            -20 * u + shift,
            (38 + i * 16) * u,
            size.width + 40 * u,
            9 * u,
          ),
          Radius.circular(5 * u),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MorningPainter oldDelegate) =>
      oldDelegate.sky != sky || oldDelegate.scheme != scheme;
}
