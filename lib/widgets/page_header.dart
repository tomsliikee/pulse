import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../app/haptics.dart';
import '../l10n/generated/app_localizations.dart';

/// The large emphasized title every top-level page starts with.
///
/// With [onToggleEditing] a small pencil sits next to the title; it turns
/// into a check mark while the page's tiles are being rearranged.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.editing = false,
    this.onToggleEditing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool editing;
  final VoidCallback? onToggleEditing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.emphasizedTextTheme.displaySmall
                            ?.copyWith(color: scheme.onSurface),
                      ),
                    ),
                    if (onToggleEditing != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          Haptics.tap();
                          onToggleEditing?.call();
                        },
                        tooltip: editing
                            ? AppLocalizations.of(context).done
                            : AppLocalizations.of(context).arrangeTiles,
                        iconSize: 18,
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          backgroundColor: editing
                              ? scheme.primary
                              : scheme.surfaceContainerHighest,
                          foregroundColor: editing
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant,
                        ),
                        icon: Icon(
                          editing ? Icons.check_rounded : Icons.edit_rounded,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Title of a group inside a page or a tile.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.padding});

  final String text;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(4, 28, 4, 12),
      child: Text(
        text,
        style: context.emphasizedTextTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// One quiet sentence where a chart or list has nothing to show.
class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
