import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/container_route.dart';
import '../../app/formatters.dart';
import '../../app/layout.dart';
import '../../data/health_controller.dart';
import '../../data/links.dart';
import '../../theme/app_type.dart';
import '../../theme/page_accent.dart';
import '../../widgets/entrance.dart';
import '../../widgets/page_header.dart';
import '../../widgets/segment_group.dart';
import '../../widgets/shape_badge.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/sub_page.dart';
import '../week/week_page.dart';
import 'link_card.dart';
import 'link_format.dart';

/// Opens the page of all connections, growing it out of [origin].
void openLinks(BuildContext context, Rect origin) {
  Navigator.of(context).push(
    ContainerRoute<void>(
      origin: origin,
      originColor: Theme.of(context).colorScheme.surfaceBright,
      builder: (_) => const LinksPage(),
    ),
  );
}

/// What goes together in the user's own numbers: every connection that
/// passes the app's rule, by what is set against what.
class LinksPage extends StatelessWidget {
  const LinksPage({super.key});

  /// Nights the page asks for before it says that nothing stands out.
  static const int _nightsAtLeast = linkDaysAtLeast * 2;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    final settings = scope.settings;
    return ListenableBuilder(
      listenable: Listenable.merge([health, settings, scope.supplements]),
      builder: (context, _) {
        final formats = Formats.of(context);
        final l10n = formats.l10n;
        return PageAccent.day(
          child: SubPage(
            title: l10n.linksTitle,
            glass: settings.liquidGlass,
            child: health.status != HealthStatus.ready
                ? const SizedBox(
                    height: 240,
                    child: Center(child: M3ELoadingIndicator()),
                  )
                : Builder(
                    builder: (context) {
                      final links = linksOf(
                        health,
                        settings,
                        scope.supplements.data,
                      );
                      final nights = linkNights(health.nights, health.today);
                      final sections = <Widget>[
                        OpenRow(
                          icon: Icons.calendar_view_week_rounded,
                          title: l10n.weekLatest,
                          onTap: (origin) => openWeek(context, origin: origin),
                        ),
                        if (links.isEmpty)
                          SurfaceCard(
                            child: EmptyNote(
                              nights < _nightsAtLeast
                                  ? l10n.linksEmptyFew(nights)
                                  : l10n.linksEmptyNone,
                            ),
                          ),
                        for (final kind in LinkKind.values)
                          if (links.any((link) => link.kind == kind))
                            TitledSection(
                              title: kind.label(l10n),
                              note: kind == LinkKind.weeks
                                  ? l10n.linksWeeksNote
                                  : null,
                              child: SegmentGroup(
                                children: [
                                  for (final link in links)
                                    if (link.kind == kind) LinkCard(link: link),
                                ],
                              ),
                            ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                          child: Text(
                            l10n.linksPageNote,
                            style: AppType.of(context).aside(
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 12,
                        children: [
                          for (final (i, section) in sections.indexed)
                            Entrance(order: i, child: section),
                        ],
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}

/// A row of its own that opens a page: an icon on a shape, a title and,
/// where given, a line below it.
class OpenRow extends StatelessWidget {
  const OpenRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final void Function(Rect origin) onTap;

  static const double height = 72;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = PageAccent.colorsOf(context);
    final subtitle = this.subtitle;
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: Builder(
          builder: (context) => InkWell(
            onTap: () {
              final origin = globalRectOf(context);
              if (origin != null) onTap(origin);
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: height),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    ShapeBadge(
                      shape: Shapes.l4LeafClover,
                      icon: icon,
                      size: 40,
                      color: accent.container,
                      iconColor: accent.onContainer,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.of(context)
                                .strong(theme.textTheme.titleSmall),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
