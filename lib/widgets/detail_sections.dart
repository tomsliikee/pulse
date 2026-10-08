import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_type.dart';
import '../theme/page_accent.dart';
import 'page_header.dart';
import 'segment_group.dart';
import 'shape_badge.dart';
import 'stat_tile.dart';

/// The head of a page about one night or workout: its scene as the one
/// container, a mark that hangs over the scene's edge with a label beside
/// it, and below them, free, what [child] says.
class SceneSummary extends StatelessWidget {
  const SceneSummary({
    super.key,
    required this.scene,
    required this.mark,
    required this.label,
    required this.child,
  });

  final Widget scene;

  /// [markSize] in both directions.
  final Widget mark;
  final String label;
  final Widget child;

  static const double sceneHeight = 160;
  static const double markSize = 116;
  static const double _overlap = 52;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = AppType.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SurfaceCard(padding: EdgeInsets.zero, child: scene),
            SizedBox(
              height: markSize - _overlap,
              child: Padding(
                padding: const EdgeInsets.only(left: markSize + 28, right: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: type.label(
                      theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
              child: child,
            ),
          ],
        ),
        Positioned(left: 16, top: sceneHeight - _overlap, child: mark),
      ],
    );
  }
}

/// Sentences as segments under a free title, each with the same icon on a
/// shape, and a quiet note below.
class NoteSegments extends StatelessWidget {
  const NoteSegments({
    super.key,
    required this.title,
    required this.icon,
    required this.sentences,
    this.shape = Shapes.softBurst,
    this.note,
  });

  final String title;
  final IconData icon;
  final Shapes shape;
  final List<String> sentences;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = PageAccent.colorsOf(context);
    return TitledSection(
      title: title,
      note: note,
      child: SegmentGroup(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          for (final sentence in sentences)
            Row(
              children: [
                ShapeBadge(
                  shape: shape,
                  icon: icon,
                  size: 40,
                  color: accent.container,
                  iconColor: accent.onContainer,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(sentence, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// A table of differences as segments: a line of column heads, then a row
/// for each thing compared, its name first and a cell under each head.
class ComparisonSegments extends StatelessWidget {
  const ComparisonSegments({
    super.key,
    required this.title,
    required this.heads,
    required this.rows,
  });

  final String title;
  final List<String> heads;
  final List<({String label, List<Widget> cells})> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = AppType.of(context);
    final head = type.label(
      theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    return TitledSection(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                const Expanded(flex: 5, child: SizedBox.shrink()),
                for (final text in heads)
                  Expanded(
                    flex: 4,
                    child: Text(
                      text,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: head,
                    ),
                  ),
              ],
            ),
          ),
          SegmentGroup(
            from: 1,
            children: [
              for (final row in rows)
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        row.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.strong(theme.textTheme.titleSmall),
                      ),
                    ),
                    for (final cell in row.cells)
                      Expanded(flex: 4, child: cell),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// How one number differs from another, coloured by whether that is good.
class DifferenceText extends StatelessWidget {
  const DifferenceText({super.key, required this.text, required this.good});

  /// With its sign, or '±0'.
  final String text;

  /// True for better, false for worse, null where it is neither.
  final bool? good;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      textAlign: TextAlign.end,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppType.of(context).figure(
        context.emphasizedTextTheme.labelLarge?.copyWith(
          color: switch (good) {
            true => scheme.primary,
            false => scheme.error,
            null => scheme.onSurfaceVariant,
          },
        ),
      ),
    );
  }
}
