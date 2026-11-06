import 'package:material_ui/material_ui.dart';

import '../../../data/health_controller.dart';
import '../../../data/links.dart';
import '../../../features/links/link_card.dart';
import '../../../features/links/link_format.dart';
import '../data/mono_data.dart';
import '../theme/mono_type.dart';
import '../widgets/mono_blocks.dart';
import '../widgets/mono_card.dart';
import '../widgets/mono_category.dart';
import '../widgets/mono_page.dart';
import 'week_page.dart';

/// What goes together in the person's own numbers, by what is set against
/// what: every connection that passes the app's rule.
class MonoLinksPage extends StatelessWidget {
  const MonoLinksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = MonoCtx.of(context).scope;
    return ListenableBuilder(
      listenable: Listenable.merge([
        scope.health,
        scope.settings,
        scope.supplements,
      ]),
      builder: (context, _) {
        final c = MonoCtx.of(context);
        final l10n = c.l10n;
        final ready = c.health.status == HealthStatus.ready;
        final links = ready
            ? linksOf(c.health, c.settings, c.scope.supplements.data)
            : const <Link>[];
        final nights = linkNights(c.health.nights, c.health.today);
        return MonoSubPage(
          category: MonoCategory.recovery,
          icon: Icons.link_rounded,
          categoryLabel: l10n.linksTitle,
          backLabel: l10n.monoInsights,
          statement: links.isEmpty
              ? (nights < linkDaysAtLeast * 2
                    ? l10n.linksEmptyFew(nights)
                    : l10n.linksEmptyNone)
              : l10n.linksNote,
          children: [
            MonoSurface(
              onTap: () => c.push(const MonoWeekPage()),
              child: MonoRow(
                title: l10n.weekLatest,
                leading: Icon(Icons.calendar_view_week_rounded, color: c.t.ink),
              ),
            ),
            for (final kind in LinkKind.values)
              if (links.any((link) => link.kind == kind))
                MonoBlock(
                  title: kind.label(l10n),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final link in links)
                        if (link.kind == kind)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: MonoSurface(child: LinkCard(link: link)),
                          ),
                      if (kind == LinkKind.weeks) MonoNote(l10n.linksWeeksNote),
                    ],
                  ),
                ),
            Text(l10n.linksPageNote, style: MonoType.time(c.t)),
          ],
        );
      },
    );
  }
}
