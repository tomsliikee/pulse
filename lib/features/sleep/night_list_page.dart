import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/formatters.dart';
import '../../data/models.dart';
import '../../widgets/segment_group.dart';
import '../../widgets/entrance.dart';
import '../../widgets/page_header.dart';
import '../../widgets/sub_page.dart';
import 'night_tiles.dart';

/// Every night the app knows, newest first and month by month.
class NightListPage extends StatelessWidget {
  const NightListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final health = scope.health;
    // The rows the list starts with come in; the ones scrolled to do not.
    return EntranceGate(
      builder: (context, opening) => ListenableBuilder(
        listenable: Listenable.merge([health, scope.settings]),
        builder: (context, _) {
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
                itemBuilder: (context, index) => Entrance(
                  order: index,
                  animate: index < Entrance.staggered && opening(),
                  child: switch (rows[index]) {
                    final DateTime month => SectionTitle(
                      formats.month(month),
                      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                    ),
                    // The nights of a month are one group of segments.
                    final SleepNight night => ListSegment(
                      first: rows[index - 1] is DateTime,
                      last:
                          index == rows.length - 1 ||
                          rows[index + 1] is DateTime,
                      child: NightRow(night: night),
                    ),
                    _ => const SizedBox.shrink(),
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
