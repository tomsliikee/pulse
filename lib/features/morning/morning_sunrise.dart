import 'dart:math' as math;

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/formatters.dart';
import '../../theme/app_type.dart';
import 'morning_format.dart';
import 'morning_scene.dart';

/// What the morning begins with when it opens by itself: the night gives way
/// and the sun comes up over the whole screen, while the app reads what the
/// watch wrote since. Stands at its end where nothing may move.
class MorningSunrise extends StatefulWidget {
  const MorningSunrise({
    super.key,
    required this.name,
    required this.syncing,
    required this.onRisen,
  });

  final String? name;

  /// Whether the read is still running, which the lower edge then says.
  final bool syncing;

  /// Called once, when the sun is up.
  final VoidCallback onRisen;

  /// How long the sun takes.
  static const Duration lasts = Duration(milliseconds: 2600);

  @override
  State<MorningSunrise> createState() => _MorningSunriseState();
}

class _MorningSunriseState extends State<MorningSunrise>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rise =
      AnimationController(
        vsync: this,
        duration: MorningSunrise.lasts,
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_standing) widget.onRisen();
      });
  late final Animation<double> _risen = CurvedAnimation(
    parent: _rise,
    // Slow at first, so the night is seen before it goes.
    curve: Curves.easeInOutCubic,
  );

  /// The writing comes with the light: on the night it could not be read.
  late final Animation<double> _lit = CurvedAnimation(
    parent: _rise,
    curve: const Interval(0.55, 1, curve: Curves.easeOut),
  );
  bool _begun = false;
  bool _standing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_begun) return;
    _begun = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      // The page above cannot take the word while it is being built, so the
      // listener is passed over and the word follows the frame.
      _standing = true;
      _rise.value = 1;
      _standing = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onRisen();
      });
    } else {
      _rise.forward();
    }
  }

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = Formats.of(context).l10n;
    final type = AppType.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _SunrisePainter(risen: _risen, scheme: scheme),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
            child: Column(
              children: [
                FadeTransition(
                  opacity: _lit,
                  child: Text(
                    morningGreeting(l10n, widget.name),
                    textAlign: TextAlign.center,
                    style: type.title(
                      context.emphasizedTextTheme.displaySmall?.copyWith(
                        color: _SunrisePainter.ink,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                AnimatedOpacity(
                  opacity: widget.syncing ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: FadeTransition(
                    opacity: _lit,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 12,
                      children: [
                        M3ELoadingIndicator(
                          color: scheme.primary,
                          constraints: BoxConstraints.tight(const Size(28, 28)),
                        ),
                        Flexible(
                          child: Text(
                            l10n.morningSyncing,
                            style: type.label(
                              theme.textTheme.labelLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SunrisePainter extends CustomPainter {
  _SunrisePainter({required this.risen, required this.scheme})
    : super(repaint: risen);

  /// From 0, the night, to 1, the sun up.
  final Animation<double> risen;
  final ColorScheme scheme;

  static const Color _nightHigh = Color(0xFF141B33);
  static const Color _nightLow = Color(0xFF3B3557);

  /// The writing on the morning's sky, which is light under any theme.
  static const Color ink = Color(0xFF1B2440);

  /// How much of the height the land in front takes.
  static const double _land = 0.16;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = risen.value;
    final u = size.width / 100;
    final area = Offset.zero & size;
    canvas.drawRect(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(_nightHigh, Dawn.high, t)!,
            Color.lerp(_nightLow, Dawn.low, t)!,
          ],
        ).createShader(area),
    );

    // The stars go first.
    final stars = (1 - t * 2.5).clamp(0.0, 1.0);
    if (stars > 0) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.8 * stars);
      for (var i = 0; i < 24; i++) {
        canvas.drawCircle(
          Offset(
            (i * 73.0 + 11) % 100 * u,
            (i * 41.0 + 7) % 60 / 100 * size.height,
          ),
          (0.3 + i % 3 * 0.15) * u,
          paint,
        );
      }
    }

    final ground = size.height * (1 - _land);
    // From behind the hills to well above them.
    final sun = Offset(
      size.width / 2,
      ground + 14 * u - (ground + 14 * u - size.height * 0.4) * t,
    );
    // The light spreads from the sun and thins out into the sky.
    final reach = (45 + 55 * t) * u;
    canvas
      ..drawCircle(
        sun,
        reach,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Dawn.sunlight.withValues(alpha: 0.2 + 0.5 * t),
              Dawn.sunlight.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: sun, radius: reach)),
      )
      ..drawCircle(sun, 15 * u, Paint()..color = Dawn.sunlight);

    // The land comes out of the dark as the light reaches it.
    const dark = Color(0xFF1D2338);
    final light = math.min(1.0, t * 1.3);
    canvas
      ..drawPath(
        Dawn.hills(size, ground, u),
        Paint()
          ..color = Color.lerp(
            dark,
            Color.lerp(scheme.primaryContainer, Dawn.low, 0.35),
            light,
          )!,
      )
      ..drawRect(
        Rect.fromLTRB(0, ground, size.width, size.height),
        Paint()
          ..color = Color.lerp(dark, scheme.surfaceContainerHighest, light)!,
      );
  }

  @override
  bool shouldRepaint(_SunrisePainter oldDelegate) =>
      oldDelegate.risen != risen || oldDelegate.scheme != scheme;
}
