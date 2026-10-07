import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import 'stat_tile.dart';

/// A titled card.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding,
  });

  final String title;
  final Widget child;
  final String? trailing;

  /// For content that reaches the card's edges; the title keeps its inset.
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trailing = this.trailing;
    final padding = this.padding;
    return SurfaceCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: padding == null ? 0 : 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: context.emphasizedTextTheme.titleMedium,
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing,
                    style: context.emphasizedTextTheme.labelLarge?.copyWith(
                      color: scheme.tertiary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
