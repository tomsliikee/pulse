import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/haptics.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shape_badge.dart';

/// The icon and the shape supplements go by.
const IconData supplementIcon = Icons.medication_rounded;
const Shapes supplementShape = Shapes.pill;

/// One supplement in a list: its name, a line below, and what a tap does.
class SupplementRow extends StatelessWidget {
  const SupplementRow({
    super.key,
    required this.title,
    required this.onTap,
    this.line,
    this.trailing = Icons.add_rounded,
    this.onTrailing,
    this.trailingLabel,
  });

  final String title;
  final String? line;
  final VoidCallback onTap;
  final IconData trailing;

  /// What a tap on the icon at the end does, where that is not [onTap].
  final VoidCallback? onTrailing;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = scheme.tone(Tone.tertiary);
    final line = this.line;
    final onTrailing = this.onTrailing;
    return InkWell(
      onTap: () {
        Haptics.tap();
        onTap();
      },
      child: Padding(
        padding: EdgeInsets.only(left: 20, right: onTrailing == null ? 20 : 8),
        child: Row(
          children: [
            ShapeBadge(
              shape: supplementShape,
              icon: supplementIcon,
              size: 44,
              color: tone.container,
              iconColor: tone.onContainer,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (line != null)
                    Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (onTrailing == null)
              Icon(trailing, color: scheme.onSurfaceVariant)
            else
              IconButton(
                tooltip: trailingLabel,
                onPressed: () {
                  Haptics.tap();
                  onTrailing();
                },
                icon: Icon(trailing, color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}
