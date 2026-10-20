import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_type.dart';

/// The one sentence that says how a day, a night or a workout compares:
/// a strong line in [color], or in the expressive rework a tinted chip
/// with [icon] before it.
class Headline extends StatelessWidget {
  const Headline(
    this.text, {
    super.key,
    required this.color,
    required this.icon,
    this.large = false,
    this.maxLines,
  });

  final String text;
  final Color color;
  final IconData icon;

  /// A page's own head, not a tile's.
  final bool large;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final type = AppType.of(context);
    final theme = context.emphasizedTextTheme;
    final base = large ? theme.titleMedium : theme.titleSmall;
    final style = type.strong(base?.copyWith(color: color));
    if (!type.expressive) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: style,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          color: Color.lerp(scheme.surfaceContainerHighest, color, 0.12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 5, 16, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Icon(icon, size: 18, color: color),
              Flexible(
                child: Text(
                  text,
                  // One line on a tile, whose height is fixed and the chip
                  // taller than the text it holds; two on a page's head.
                  maxLines: large ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
