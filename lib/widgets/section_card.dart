import 'package:material_ui/material_ui.dart';

import '../theme/app_type.dart';
import '../theme/page_accent.dart';
import 'page_header.dart';
import 'stat_tile.dart';

/// A section whose content is one thing, such as a chart: its title free
/// above, the content alone on a surface.
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

  /// A short figure at the end of the title's line.
  final String? trailing;

  /// For content that reaches the surface's edges.
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: SectionTitle(title)),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 4, 14),
                child: Text(
                  trailing,
                  style: AppType.of(context).figure(
                    Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: PageAccent.colorsOf(context).accent),
                  ),
                ),
              ),
          ],
        ),
        SurfaceCard(padding: padding, child: child),
      ],
    );
  }
}
