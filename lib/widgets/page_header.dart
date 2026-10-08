import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_type.dart';
import '../theme/page_accent.dart';

/// The large emphasized title every top-level page starts with.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.reserved = 0,
    this.ink,
  });

  final String title;
  final String subtitle;

  /// The colour of both lines where they stand on a picture instead of the
  /// page; the theme's when null.
  final Color? ink;

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
                color: ink ?? scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.titleMedium?.copyWith(
              color: ink?.withValues(alpha: 0.8) ?? scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The title of a section: free above it, large and heavy.
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
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppType.of(context).title(
          context.emphasizedTextTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// A section under its free title, with an optional quiet note below.
class TitledSection extends StatelessWidget {
  const TitledSection({
    super.key,
    required this.title,
    required this.child,
    this.note,
  });

  final String title;
  final Widget child;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = this.note;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(title),
        child,
        if (note != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Text(
              note,
              style: AppType.of(context).aside(
                theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// What a board tile shows under a free title: the title, and [child] in
/// the room that is left.
class TitledTile extends StatelessWidget {
  const TitledTile({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;

  /// A short figure at the end of the title's line.
  final String? trailing;

  /// The room the title takes of the tile's height.
  static const double titleHeight = 48;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: titleHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SectionTitle(
                  title,
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                ),
              ),
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 4, 0),
                  child: Text(
                    trailing,
                    style: AppType.of(context).figure(
                      context.emphasizedTextTheme.titleMedium?.copyWith(
                        color: PageAccent.colorsOf(context).accent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
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
