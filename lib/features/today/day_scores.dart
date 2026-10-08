import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../../app/formatters.dart';
import '../../data/day_insights.dart';
import '../../data/recovery.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_type.dart';
import '../../theme/page_accent.dart';
import '../../widgets/animated_count.dart';
import '../../widgets/morphing_shape.dart';

/// The hour from which a day that is still running shows its score.
const int dayScoreFromHour = 21;

/// Whether the score of [day] is shown beside its recovery: for a day that
/// is over, and for today in the evening.
bool showsDayScore(DateTime day, DateTime now) =>
    day != DateTime(now.year, now.month, now.day) ||
    now.hour >= dayScoreFromHour;

/// The recovery of a day on a shape in the colour of its zone, on the left
/// like the main number of every page. With [withDay] the score of the day
/// comes in beside it, in the middle, on a shape of the same size.
class DayScores extends StatelessWidget {
  const DayScores({
    super.key,
    required this.insights,
    required this.withDay,
    required this.size,
    required this.style,
  });

  final DayInsights insights;
  final bool withDay;

  /// The size of each shape.
  final double size;

  /// The style of the numbers, without their colour.
  final TextStyle? style;

  /// What the caption below a shape needs.
  static const double captionHeight = 24;

  /// How far in from the left the recovery stands, and the least room
  /// between the two shapes on a narrow phone.
  static const double _inset = 16;
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = Formats.of(context).l10n;
    final type = AppType.of(context);
    final accent = PageAccent.colorsOf(context);
    final family = PageAccent.of(context).family;
    final recovery = insights.recovery.total;
    final zone = recoveryColors(scheme, insights.recovery.zone);
    final score = insights.score.total;
    final caption = type.label(
      theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
    );

    Widget item(Widget shape, String label) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        shape,
        SizedBox(
          height: captionHeight,
          child: Align(
            // As wide as its text, so the column is as wide as the shape.
            widthFactor: 1,
            alignment: Alignment.bottomCenter,
            child: Text(label, maxLines: 1, style: caption),
          ),
        ),
      ],
    );

    final recoveryStyle = style?.copyWith(color: zone.onFill);
    final dayStyle = style?.copyWith(color: accent.onAccent);
    return SizedBox(
      height: size + captionHeight,
      child: LayoutBuilder(
        builder: (context, box) {
          // The middle, or as near to it as the recovery leaves room.
          final dayLeft = ((box.maxWidth - size) / 2).clamp(
            _inset + size + _gap,
            double.infinity,
          );
          return SingleMotionBuilder(
            from: withDay ? 1 : 0,
            value: withDay ? 1 : 0,
            motion: AppMotion.spatial,
            builder: (context, t, _) => Stack(
              clipBehavior: Clip.none,
              children: [
                if (t > 0.01)
                  Positioned(
                    left: dayLeft,
                    top: 0,
                    child: Opacity(
                      opacity: t.clamp(0, 1).toDouble(),
                      child: Transform.scale(
                        scale: 0.8 + 0.2 * t,
                        child: item(
                          MorphingShape(
                            key: const ValueKey('dayScore'),
                            shape: AppShapes.of(family, score),
                            color: accent.accent,
                            size: size,
                            child: score == null
                                ? Text('–', style: dayStyle)
                                : AnimatedCount(value: score, style: dayStyle),
                          ),
                          l10n.dayShort,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: _inset,
                  top: 0,
                  child: Semantics(
                    label: switch (insights.recovery.zone) {
                      RecoveryZone.green => l10n.recoveryGreen,
                      RecoveryZone.yellow => l10n.recoveryYellow,
                      RecoveryZone.red => l10n.recoveryRed,
                      null => null,
                    },
                    child: item(
                      MorphingShape(
                        key: const ValueKey('recovery'),
                        shape: AppShapes.of(family, recovery),
                        color: zone.fill,
                        size: size,
                        child: recovery == null
                            ? Text('–', style: recoveryStyle)
                            : AnimatedCount(
                                value: recovery,
                                style: recoveryStyle,
                                format: (value) => '$value%',
                              ),
                      ),
                      l10n.recovery,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
