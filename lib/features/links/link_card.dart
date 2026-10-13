import 'dart:math' as math;

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../../app/formatters.dart';
import '../../data/links.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_type.dart';
import '../../theme/page_accent.dart';
import 'link_format.dart';

/// One connection: its sentence, and below it the two sides as bars, each
/// with its mean and how many days, nights or weeks stand behind it.
class LinkCard extends StatelessWidget {
  const LinkCard({super.key, required this.link, this.plain = false});

  final Link link;

  /// Whether the bars stand without their values and counts, and the
  /// sentence keeps to three lines.
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formats = Formats.of(context);
    final accent = PageAccent.colorsOf(context);
    final sides = linkSides(formats.l10n, link);
    final from = linkBarFrom(link.effect);
    final most = math.max(link.withMean, link.withoutMean) - from;
    double share(double value) =>
        most <= 0 ? 0 : ((value - from) / most).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          linkSentence(formats, link),
          maxLines: plain ? 3 : null,
          overflow: plain ? TextOverflow.ellipsis : null,
          style: AppType.of(context).strong(theme.textTheme.titleSmall),
        ),
        const SizedBox(height: 14),
        _Side(
          label: sides.with_,
          count: plain ? null : link.countWith,
          value: plain ? null : linkValue(formats, link.effect, link.withMean),
          share: share(link.withMean),
          color: accent.accent,
        ),
        const SizedBox(height: 10),
        _Side(
          label: sides.without,
          count: plain ? null : link.countWithout,
          value: plain
              ? null
              : linkValue(formats, link.effect, link.withoutMean),
          share: share(link.withoutMean),
          color: scheme.outline,
        ),
      ],
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.label,
    required this.count,
    required this.value,
    required this.share,
    required this.color,
  });

  final String label;

  /// Null leaves it out.
  final int? count;

  /// Null leaves it out.
  final String? value;
  final double share;
  final Color color;

  static const double _bar = 10;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final type = AppType.of(context);
    final l10n = Formats.of(context).l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                switch (count) {
                  final count? => '$label · ${l10n.linkCount(count)}',
                  null => label,
                },
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.label(
                  theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            if (value case final value?) ...[
              const SizedBox(width: 12),
              Text(
                value,
                style: type.figure(context.emphasizedTextTheme.labelLarge),
              ),
            ],
          ],
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(_bar / 2),
          child: ColoredBox(
            color: scheme.surfaceContainerHighest,
            child: SingleMotionBuilder(
              from: 0,
              value: share,
              // An effects spring: a bar that overshoots would show more
              // than is.
              motion: AppMotion.effectsSlow,
              builder: (context, current, _) => FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: current.clamp(0.0, 1.0).toDouble(),
                child: Container(
                  height: _bar,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(_bar / 2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
