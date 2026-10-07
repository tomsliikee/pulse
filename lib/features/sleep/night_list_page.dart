import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../data/models.dart';
import '../../theme/app_shapes.dart';
import '../../widgets/page_header.dart';
import '../../widgets/sub_page.dart';
import '../../widgets/tile_surface.dart';
import 'night_tiles.dart';

/// Every night the app knows, newest first and month by month.
class NightListPage extends StatelessWidget {
  const NightListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    return ListenableBuilder(
      listenable: Listenable.merge([health, scope.settings]),
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final formats = Formats.of(context);

        // A month's heading, then its nights.
        final rows = <Object>[];
        DateTime? month;
        for (final night in health.nights.reversed) {
          final start = DateTime(night.date.year, night.date.month);
          if (start != month) rows.add(month = start);
          rows.add(night);
        }

        return SubPage(
          title: formats.l10n.allNights,
          glass: scope.settings.liquidGlass,
          slivers: [
            SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) => switch (rows[index]) {
                final DateTime month => SectionTitle(
                  formats.month(month),
                  padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                ),
                final SleepNight night => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TileSurface(
                    color: scheme.surfaceBright,
                    radius: AppRadii.extraLarge,
                    child: SizedBox(height: 72, child: NightRow(night: night)),
                  ),
                ),
                _ => const SizedBox.shrink(),
              },
            ),
          ],
        );
      },
    );
  }
}
