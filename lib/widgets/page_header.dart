import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

/// The large emphasized title every top-level page starts with.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.reserved = 0,
  });

  final String title;
  final String subtitle;

  /// Room the title leaves free on its right for the buttons floating over
  /// the page.
  final double reserved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(right: reserved),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.emphasizedTextTheme.displaySmall?.copyWith(
                color: scheme.onSurface,
              ),
            ),
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
